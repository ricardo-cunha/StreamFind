#pragma once

#include <filesystem>
#include <functional>
#include <memory>
#include <optional>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

#include <nlohmann/json-schema.hpp>
#include <nlohmann/json.hpp>

namespace json_core {

using json = nlohmann::json;

namespace detail {
class SaxIndexBuilder;
}

/** Error categories raised by the generic JSON helpers. */
enum class ErrorCode {
  Io,
  Parse,
  Validation,
  NotFound,
  Unknown
};

/** Exception that carries a JSON-layer error code. */
class Error : public std::runtime_error {
 public:
  /** Construct a JSON-layer error. */
  Error(ErrorCode code, std::string message);

  /** Return the error category. */
  ErrorCode code() const noexcept;

 private:
  ErrorCode code_;
};

/** Load a JSON document from disk without an intermediate text copy. */
json load_json_file(const std::filesystem::path& path);

/** Write JSON to disk using either compact or pretty formatting. */
void write_json_file(const std::filesystem::path& path, const json& value, int indent = 2);

/** Decode a JSON Pointer token from RFC 6901 form. */
std::string unescape_pointer_token(const std::string& token);

/** Walk a JSON document using a JSON Pointer path and return the pointed node. */
const json* descend_json_pointer(const json& root, const std::string& path);

/** Return the immediate child keys or array indices for a JSON node. */
std::vector<std::string> json_child_paths(const json& node);

/** Node types recorded by the SAX indexer. */
enum class NodeKind {
  Object,
  Array,
  String,
  Number,
  Boolean,
  Null,
  Unknown
};

/** Metadata captured for one JSON pointer. */
struct NodeInfo {
  std::string path;
  std::string key;
  std::string parent_path;
  NodeKind kind = NodeKind::Unknown;
  std::size_t child_count = 0;
  bool is_leaf = false;
};

class Index;

/** SAX-built index over one JSON document. */
class Index {
 public:
  /** Create an index tied to a source file. */
  explicit Index(std::filesystem::path file_path);

  /** Parse the file and populate the node map. */
  void build();
  /** Return whether a JSON pointer exists in the index. */
  bool exists(const std::string& path) const;
  /** Look up metadata for a JSON pointer. */
  const NodeInfo* find(const std::string& path) const;
  /** Return direct child pointers for a JSON pointer. */
  std::vector<std::string> children(const std::string& path) const;

  /** Return the model name inferred from the file. */
  const std::string& model_name() const noexcept;
  /** Return the manifest URI if one was recorded. */
  const std::string& manifest_uri() const noexcept;

 private:
  friend class detail::SaxIndexBuilder;

  /** SAX stack frame used while walking the JSON document. */
  struct Frame {
    std::string path;
    bool is_array = false;
    std::size_t next_index = 0;
    std::optional<std::string> pending_key;
  };

  /** Escape one JSON Pointer token. */
  static std::string escape_pointer_token(const std::string& token);
  /** Join a parent pointer with one child token. */
  static std::string join_path(const std::string& parent, const std::string& token);
  /** Build a child pointer for an object key. */
  static std::string child_path_for_object(const std::string& parent, const std::string& key);
  /** Build a child pointer for an array index. */
  static std::string child_path_for_array(const std::string& parent, std::size_t index);
  /** Add one indexed node and link it to its parent. */
  void add_node(const std::string& path,
                const std::string& key,
                const std::string& parent_path,
                NodeKind kind,
                bool is_leaf);

  std::filesystem::path file_path_;
  std::unordered_map<std::string, NodeInfo> nodes_;
  std::unordered_map<std::string, std::vector<std::string>> children_;
  std::string model_name_;
  std::string manifest_uri_;
};

/** Handle for one indexed JSON pointer in a JSON file. */
class JSON_NODE {
 public:
  /** Bind the node handle to a file and index. */
  JSON_NODE(std::filesystem::path file_path,
            std::string path,
            std::shared_ptr<const Index> index);

  /** Return whether the path exists in the index. */
  bool exists() const;
  /** Return node metadata. */
  NodeInfo info() const;
  /** Return child node handles. */
  std::vector<JSON_NODE> children() const;
  /** Materialize the pointed-to JSON subtree. */
  json to_json() const;

  /** Materialize and convert the subtree to `T`. */
  template <typename T>
  T get() const {
    return to_json().get<T>();
  }

 private:
  std::filesystem::path file_path_;
  std::string path_;
  std::shared_ptr<const Index> index_;
};

/** Generic indexed JSON file reader and writer. This is the main json_core interface. */
class JSON_FILE {
 public:
  /** Bind the reader to one JSON file. */
  explicit JSON_FILE(std::filesystem::path file_path);

  /** Build the SAX index for the file. */
  void build_index();

  /** Return a handle for a JSON pointer path. */
  JSON_NODE node(const std::string& path) const;
  /** Return the root node handle. */
  JSON_NODE root() const;
  /** Read the entire JSON document. */
  json read() const;
  /** Read an arbitrary subtree by JSON pointer. */
  json read_subtree(const std::string& path) const;
  /** Write a JSON document to disk. */
  void write(const json& value, int indent = 2) const;

  /** Return the built index. */
  const Index& index() const;
  /** Return the source file path. */
  const std::filesystem::path& file_path() const noexcept;
  /** Return the model name inferred from the file. */
  std::string model_name() const;

 private:
  std::filesystem::path file_path_;
  std::shared_ptr<Index> index_;
};

/** Cached JSON-schema validator for repeated instance validation. */
class JSON_SCHEMA_VALIDATOR {
 public:
  /** Build a validator from an already parsed schema. */
  JSON_SCHEMA_VALIDATOR(const json& schema, std::filesystem::path root_dir = {});
  /** Build a validator by loading a schema file. */
  JSON_SCHEMA_VALIDATOR(const std::filesystem::path& schema_path,
                        std::filesystem::path root_dir = {});

  /** Replace the compiled schema. */
  void set_schema(const json& schema);

  /** Validate an instance and throw on failure. */
  void validate(const json& instance) const;

  /** Return the current schema JSON. */
  const json& schema() const noexcept;

 private:
  using SchemaIndex = std::unordered_map<std::string, std::filesystem::path>;

  static SchemaIndex build_schema_index(const std::filesystem::path& root_dir);
  static void index_schema_file(SchemaIndex& index, const std::filesystem::path& path);
  static nlohmann::json_schema::schema_loader make_loader(const SchemaIndex& index,
                                                          const std::filesystem::path& root_dir);
  static std::filesystem::path resolve_schema_file(const SchemaIndex& index,
                                                   const std::filesystem::path& root_dir,
                                                   const nlohmann::json_uri& id);

  std::filesystem::path root_dir_;
  SchemaIndex schema_index_;
  nlohmann::json_schema::schema_loader loader_;
  json schema_;
  nlohmann::json_schema::json_validator validator_;
};

}  // namespace json_core
