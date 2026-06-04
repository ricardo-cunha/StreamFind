#include "json.h"

#include <cstddef>
#include <fstream>
#include <iterator>
#include <limits>
#include <tuple>
#include <utility>

namespace fs = std::filesystem;

namespace json_core {

namespace detail {

static bool has_suffix(const std::string& value, const std::string& suffix) {
  return value.size() >= suffix.size() &&
         value.compare(value.size() - suffix.size(), suffix.size(), suffix) == 0;
}

static std::string path_text(const std::filesystem::path& path) {
  return path.u8string();
}

static fs::path schema_candidate_path(const fs::path& root_dir, const std::string& name) {
  const fs::path direct = root_dir / name;
  if (fs::exists(direct)) {
    return direct;
  }

  const fs::path with_json = root_dir / (name + ".json");
  if (fs::exists(with_json)) {
    return with_json;
  }

  const fs::path stem_json = root_dir / (fs::path(name).filename().string() + ".json");
  if (fs::exists(stem_json)) {
    return stem_json;
  }

  return {};
}

static std::string json_string_or_empty(const json& value) {
  return value.is_string() ? value.get<std::string>() : std::string();
}

}  // namespace detail

Error::Error(ErrorCode code, std::string message)
    : std::runtime_error(std::move(message)), code_(code) {}

ErrorCode Error::code() const noexcept {
  return code_;
}

json load_json_file(const std::filesystem::path& path) {
  std::ifstream in(path, std::ios::binary);
  if (!in) {
    throw Error(ErrorCode::Io, "Failed to open JSON file: " + detail::path_text(path));
  }

  try {
    return json::parse(in);
  } catch (const std::exception& e) {
    throw Error(ErrorCode::Parse, "Failed to parse JSON file " + detail::path_text(path) + ": " + e.what());
  }
}

void write_json_file(const std::filesystem::path& path, const json& value, int indent) {
  std::ofstream out(path, std::ios::binary | std::ios::trunc);
  if (!out) {
    throw Error(ErrorCode::Io, "Failed to open JSON file for writing: " + detail::path_text(path));
  }

  out << value.dump(indent);
  if (!out) {
    throw Error(ErrorCode::Io, "Failed to write JSON file: " + detail::path_text(path));
  }
}

std::string unescape_pointer_token(const std::string& token) {
  std::string out;
  out.reserve(token.size());
  for (std::size_t i = 0; i < token.size(); ++i) {
    if (token[i] == '~' && i + 1 < token.size()) {
      if (token[i + 1] == '0') {
        out.push_back('~');
        ++i;
        continue;
      }
      if (token[i + 1] == '1') {
        out.push_back('/');
        ++i;
        continue;
      }
    }
    out.push_back(token[i]);
  }
  return out;
}

const json* descend_json_pointer(const json& root, const std::string& path) {
  if (path.empty() || path == "/") {
    return &root;
  }

  const json* current = &root;
  std::size_t pos = 0;
  while (pos < path.size()) {
    if (path[pos] != '/') {
      break;
    }
    ++pos;
    const std::size_t next = path.find('/', pos);
    std::string token = path.substr(pos, next == std::string::npos ? std::string::npos : next - pos);
    if (current->is_object()) {
      token = unescape_pointer_token(token);
      if (!current->contains(token)) {
        return nullptr;
      }
      current = &current->at(token);
    } else if (current->is_array()) {
      if (token.empty()) {
        return nullptr;
      }
      std::size_t consumed = 0;
      std::size_t idx = 0;
      try {
        idx = static_cast<std::size_t>(std::stoull(token, &consumed));
      } catch (const std::exception&) {
        return nullptr;
      }
      if (consumed != token.size()) {
        return nullptr;
      }
      if (idx >= current->size()) {
        return nullptr;
      }
      current = &(*current)[idx];
    } else {
      return nullptr;
    }
    if (next == std::string::npos) {
      break;
    }
    pos = next;
  }
  return current;
}

std::vector<std::string> json_child_paths(const json& node) {
  std::vector<std::string> out;
  if (node.is_object()) {
    out.reserve(node.size());
    for (const auto& item : node.items()) {
      out.push_back(item.key());
    }
  } else if (node.is_array()) {
    out.reserve(node.size());
    for (std::size_t i = 0; i < node.size(); ++i) {
      out.push_back(std::to_string(i));
    }
  }
  return out;
}

class detail::SaxIndexBuilder : public nlohmann::json_sax<json> {
 public:
  explicit SaxIndexBuilder(Index& index) : index_(index) {}

  bool null() override { return emit_scalar(NodeKind::Null); }
  bool boolean(bool) override { return emit_scalar(NodeKind::Boolean); }
  bool number_integer(number_integer_t) override { return emit_scalar(NodeKind::Number); }
  bool number_unsigned(number_unsigned_t) override { return emit_scalar(NodeKind::Number); }
  bool number_float(number_float_t, const string_t&) override { return emit_scalar(NodeKind::Number); }
  bool string(string_t& val) override {
    const auto [path, parent, key, ok] = resolve_current_path();
    if (!ok) {
      return false;
    }
    if (path == "/$asm.manifest") {
      index_.manifest_uri_ = val;
    }
    index_.add_node(path, key, parent, NodeKind::String, true);
    advance_parent();
    return true;
  }
  bool binary(binary_t&) override { return emit_scalar(NodeKind::Unknown); }

  bool start_object(std::size_t) override { return start_container(NodeKind::Object, false); }
  bool key(string_t& val) override {
    if (stack_.empty()) {
      return false;
    }
    stack_.back().pending_key = val;
    return true;
  }
  bool end_object() override { return end_container(); }

  bool start_array(std::size_t) override { return start_container(NodeKind::Array, true); }
  bool end_array() override { return end_container(); }

  bool parse_error(std::size_t, const std::string&, const nlohmann::detail::exception& ex) override {
    error_ = ex.what();
    return false;
  }

  const std::string& error() const noexcept { return error_; }

 private:
  bool emit_scalar(NodeKind kind) {
    const auto [path, parent, key, ok] = resolve_current_path();
    if (!ok) {
      return false;
    }
    index_.add_node(path, key, parent, kind, true);
    advance_parent();
    return true;
  }

  bool start_container(NodeKind kind, bool is_array) {
    const auto [path, parent, key, ok] = resolve_current_path();
    if (!ok) {
      return false;
    }
    index_.add_node(path, key, parent, kind, false);
    stack_.push_back(Index::Frame{path, is_array, 0, std::nullopt});
    return true;
  }

  bool end_container() {
    if (stack_.empty()) {
      return false;
    }
    stack_.pop_back();
    advance_parent();
    return true;
  }

  void advance_parent() {
    if (stack_.empty()) {
      return;
    }
    auto& parent = stack_.back();
    if (parent.is_array) {
      ++parent.next_index;
    } else {
      parent.pending_key.reset();
    }
  }

  std::tuple<std::string, std::string, std::string, bool> resolve_current_path() {
    if (stack_.empty()) {
      return {"", "", "", true};
    }
    auto& parent = stack_.back();
    std::string key;
    std::string path;
    if (parent.is_array) {
      key = std::to_string(parent.next_index);
      path = Index::child_path_for_array(parent.path, parent.next_index);
    } else {
      if (!parent.pending_key.has_value()) {
        return {"", "", "", false};
      }
      key = *parent.pending_key;
      path = Index::child_path_for_object(parent.path, key);
    }
    return {path, parent.path, key, true};
  }

  Index& index_;
  std::vector<Index::Frame> stack_;
  std::string error_;
};

Index::Index(std::filesystem::path file_path)
    : file_path_(std::move(file_path)) {}

void Index::build() {
  nodes_.clear();
  children_.clear();
  model_name_.clear();
  manifest_uri_.clear();

  std::ifstream in(file_path_);
  if (!in) {
    throw Error(ErrorCode::Io, "Failed to open ASM file for indexing: " + file_path_.string());
  }

  model_name_ = file_path_.stem().string();
  if (detail::has_suffix(model_name_, ".embed.schema")) {
    model_name_.resize(model_name_.size() - std::string(".embed.schema").size());
  } else if (detail::has_suffix(model_name_, ".schema")) {
    model_name_.resize(model_name_.size() - std::string(".schema").size());
  }

  detail::SaxIndexBuilder builder(*this);
  if (!json::sax_parse(in, &builder)) {
    throw Error(ErrorCode::Parse, "Failed to build ASM index: " + builder.error());
  }
}

bool Index::exists(const std::string& path) const {
  return nodes_.find(path) != nodes_.end();
}

const NodeInfo* Index::find(const std::string& path) const {
  const auto it = nodes_.find(path);
  return it == nodes_.end() ? nullptr : &it->second;
}

std::vector<std::string> Index::children(const std::string& path) const {
  const auto it = children_.find(path);
  return it == children_.end() ? std::vector<std::string>{} : it->second;
}

const std::string& Index::model_name() const noexcept { return model_name_; }
const std::string& Index::manifest_uri() const noexcept { return manifest_uri_; }

std::string Index::escape_pointer_token(const std::string& token) {
  std::string out;
  out.reserve(token.size());
  for (char ch : token) {
    if (ch == '~') {
      out += "~0";
    } else if (ch == '/') {
      out += "~1";
    } else {
      out.push_back(ch);
    }
  }
  return out;
}

std::string Index::join_path(const std::string& parent, const std::string& token) {
  return parent.empty() ? "/" + escape_pointer_token(token) : parent + "/" + escape_pointer_token(token);
}

std::string Index::child_path_for_object(const std::string& parent, const std::string& key) {
  return join_path(parent, key);
}

std::string Index::child_path_for_array(const std::string& parent, std::size_t index) {
  return join_path(parent, std::to_string(index));
}

void Index::add_node(const std::string& path,
                     const std::string& key,
                     const std::string& parent_path,
                     NodeKind kind,
                     bool is_leaf) {
  NodeInfo info{path, key, parent_path, kind, 0, is_leaf};
  nodes_[path] = info;
  if (!parent_path.empty() || !path.empty()) {
    children_[parent_path].push_back(path);
    nodes_[parent_path].child_count += 1;
  }
}

JSON_FILE::JSON_FILE(std::filesystem::path file_path)
    : file_path_(std::move(file_path)), index_(std::make_shared<Index>(file_path_)) {}

void JSON_FILE::build_index() {
  index_->build();
}

JSON_NODE JSON_FILE::node(const std::string& path) const {
  return JSON_NODE(file_path_, path, index_);
}

JSON_NODE JSON_FILE::root() const {
  return node("");
}

json JSON_FILE::read() const {
  return load_json_file(file_path_);
}

json JSON_FILE::read_subtree(const std::string& path) const {
  const json root = read();
  const json* node = descend_json_pointer(root, path);
  if (!node) {
    throw Error(ErrorCode::NotFound, "JSON node not found: " + path);
  }
  return *node;
}

void JSON_FILE::write(const json& value, int indent) const {
  write_json_file(file_path_, value, indent);
}

const Index& JSON_FILE::index() const { return *index_; }
const std::filesystem::path& JSON_FILE::file_path() const noexcept { return file_path_; }
std::string JSON_FILE::model_name() const { return index_->model_name(); }

JSON_NODE::JSON_NODE(std::filesystem::path file_path,
                     std::string path,
                     std::shared_ptr<const Index> index)
    : file_path_(std::move(file_path)), path_(std::move(path)), index_(std::move(index)) {}

bool JSON_NODE::exists() const {
  return index_ && index_->exists(path_);
}

NodeInfo JSON_NODE::info() const {
  const NodeInfo* info = index_ ? index_->find(path_) : nullptr;
  if (!info) {
    throw Error(ErrorCode::NotFound, "JSON node not found: " + path_);
  }
  return *info;
}

std::vector<JSON_NODE> JSON_NODE::children() const {
  std::vector<JSON_NODE> out;
  if (!index_) {
    return out;
  }
  for (const auto& child : index_->children(path_)) {
    out.emplace_back(file_path_, child, index_);
  }
  return out;
}

json JSON_NODE::to_json() const {
  const json root = load_json_file(file_path_);
  const json* node = descend_json_pointer(root, path_);
  if (!node) {
    throw Error(ErrorCode::NotFound, "JSON node not found: " + path_);
  }
  return *node;
}

JSON_SCHEMA_VALIDATOR::SchemaIndex JSON_SCHEMA_VALIDATOR::build_schema_index(const fs::path& root_dir) {
  SchemaIndex index;
  if (root_dir.empty() || !fs::exists(root_dir)) {
    return index;
  }

  for (const auto& entry : fs::recursive_directory_iterator(root_dir)) {
    if (!entry.is_regular_file()) {
      continue;
    }
    const auto name = entry.path().filename().string();
    if (name.size() >= 5 && name.substr(name.size() - 5) == ".json") {
      index_schema_file(index, entry.path());
    }
  }

  return index;
}

void JSON_SCHEMA_VALIDATOR::index_schema_file(SchemaIndex& index, const fs::path& path) {
  try {
    const json doc = load_json_file(path);
    if (doc.is_object() && doc.contains("$id")) {
      const std::string id = detail::json_string_or_empty(doc.at("$id"));
      if (!id.empty()) {
        index[id] = path;
      }
    }
    index[path.filename().string()] = path;
    index[path.stem().string()] = path;
  } catch (...) {
  }
}

nlohmann::json_schema::schema_loader JSON_SCHEMA_VALIDATOR::make_loader(
  const SchemaIndex& index,
  const fs::path& root_dir) {
  return [root_dir, index](const nlohmann::json_uri& id, json& value) {
    const fs::path path = resolve_schema_file(index, root_dir, id);
    if (path.empty()) {
      throw Error(ErrorCode::Validation, "Unresolved schema reference: " + id.location());
    }
    value = load_json_file(path);
  };
}

fs::path JSON_SCHEMA_VALIDATOR::resolve_schema_file(const SchemaIndex& index,
                                                    const fs::path& root_dir,
                                                    const nlohmann::json_uri& id) {
  const std::string location = id.location();
  if (location.empty()) {
    return {};
  }

  if (auto it = index.find(location); it != index.end()) {
    return it->second;
  }

  const auto hash_pos = location.find('#');
  const std::string base = hash_pos == std::string::npos ? location : location.substr(0, hash_pos);
  if (auto it = index.find(base); it != index.end()) {
    return it->second;
  }

  const auto slash_pos = base.find_last_of('/');
  const std::string filename = slash_pos == std::string::npos ? base : base.substr(slash_pos + 1);

  if (filename.empty()) {
    return {};
  }

  if (auto candidate = detail::schema_candidate_path(root_dir, filename); !candidate.empty()) {
    return candidate;
  }

  if (!detail::has_suffix(filename, ".json")) {
    if (auto candidate = detail::schema_candidate_path(root_dir, filename + ".json"); !candidate.empty()) {
      return candidate;
    }
  }

  return {};
}

JSON_SCHEMA_VALIDATOR::JSON_SCHEMA_VALIDATOR(const json& schema, std::filesystem::path root_dir)
    : root_dir_(std::move(root_dir)),
      schema_index_(build_schema_index(root_dir_)),
      loader_(make_loader(schema_index_, root_dir_)),
      validator_(loader_, nlohmann::json_schema::default_string_format_check, nullptr) {
  set_schema(schema);
}

JSON_SCHEMA_VALIDATOR::JSON_SCHEMA_VALIDATOR(const std::filesystem::path& schema_path,
                                             std::filesystem::path root_dir)
    : JSON_SCHEMA_VALIDATOR(load_json_file(schema_path), std::move(root_dir)) {}

void JSON_SCHEMA_VALIDATOR::set_schema(const json& schema) {
  schema_ = schema;
  validator_.set_root_schema(schema_);
}

void JSON_SCHEMA_VALIDATOR::validate(const json& instance) const {
  validator_.validate(instance);
}

const json& JSON_SCHEMA_VALIDATOR::schema() const noexcept {
  return schema_;
}

}  // namespace json_core
