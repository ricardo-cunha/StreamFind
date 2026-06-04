// Consolidated Rcpp test entry points for JSON, schema validation, ASM, and
// DuckDB integration checks.
#include <Rcpp.h>

#include "asm/file.h"
#include "asm/reader.h"

extern "C" {
#include "duckdb.h"
}

#include <filesystem>

#include <nlohmann/json-schema.hpp>
#include <nlohmann/json.hpp>

using namespace Rcpp;

using json = nlohmann::json;
using json_validator = nlohmann::json_schema::json_validator;

namespace {

const auto json_error_prefix = "JSON error";

std::string node_kind_to_string(json_core::NodeKind kind) {
  switch (kind) {
    case json_core::NodeKind::Object: return "object";
    case json_core::NodeKind::Array: return "array";
    case json_core::NodeKind::String: return "string";
    case json_core::NodeKind::Number: return "number";
    case json_core::NodeKind::Boolean: return "boolean";
    case json_core::NodeKind::Null: return "null";
    default: return "unknown";
  }
}

template <typename Fn>
auto asm_call(Fn&& fn) {
  try {
    return fn();
  } catch (const json_core::Error& e) {
    stop(std::string("ASM error: ") + e.what());
  } catch (const std::exception& e) {
    stop(std::string("ASM error [Unknown]: ") + e.what());
  }
}

template <typename Fn>
auto json_call(Fn&& fn) {
  try {
    return fn();
  } catch (const std::exception& e) {
    stop(std::string(json_error_prefix) + ": " + e.what());
  }
}

void collect_index_rows(const json_core::JSON_NODE& node,
                        std::vector<std::string>& path,
                        std::vector<std::string>& key,
                        std::vector<std::string>& kind,
                        std::vector<int>& child_count,
                        std::vector<std::string>& parent_path,
                        std::vector<int>& is_leaf) {
  const auto info = node.info();
  path.push_back(info.path);
  key.push_back(info.key);
  kind.push_back(node_kind_to_string(info.kind));
  child_count.push_back(static_cast<int>(info.child_count));
  parent_path.push_back(info.parent_path);
  is_leaf.push_back(info.is_leaf ? 1 : 0);

  for (const auto& child : node.children()) {
    collect_index_rows(child, path, key, kind, child_count, parent_path, is_leaf);
  }
}

json make_schema() {
  return R"({
      "$schema": "http://json-schema.org/draft-07/schema#",
      "type": "object",
      "required": ["name", "version"],
      "properties": {
          "name": {"type": "string"},
          "version": {"type": "integer", "minimum": 1}
      }
  })"_json;
}

}  // namespace

// JSON tests

// [[Rcpp::export]]
std::string rcpp_json_make_example() {
  json j;
  j["name"] = "StreamFind";
  j["version"] = 1;
  j["features"] = {"search", "filter", "cluster"};
  return j.dump();
}

// [[Rcpp::export]]
Rcpp::List rcpp_json_parse(const std::string& s) {
  json j = json::parse(s);
  Rcpp::List out;
  out["name"] = j.value("name", "");
  out["version"] = j.value("version", 0);

  std::vector<std::string> feats;
  if (j.contains("features") && j["features"].is_array()) {
    for (const auto& it : j["features"]) {
      feats.push_back(it.get<std::string>());
    }
  }
  out["features"] = feats;
  return out;
}

// [[Rcpp::export]]
std::string rcpp_json_read_file(std::string file_path) {
  return json_call([&]() {
    json_core::JSON_FILE file{std::filesystem::path(file_path)};
    return file.read().dump();
  });
}

// [[Rcpp::export]]
std::string rcpp_json_read_subtree(std::string file_path, std::string path) {
  return json_call([&]() {
    json_core::JSON_FILE file{std::filesystem::path(file_path)};
    return file.read_subtree(path).dump();
  });
}

// [[Rcpp::export]]
Rcpp::CharacterVector rcpp_json_list_children(std::string file_path, std::string path = "") {
  return json_call([&]() {
    json_core::JSON_FILE file{std::filesystem::path(file_path)};
    file.build_index();
    auto children = file.node(path).children();
    Rcpp::CharacterVector out(children.size());
    for (R_xlen_t i = 0; i < out.size(); ++i) {
      out[i] = children[static_cast<std::size_t>(i)].info().path;
    }
    return out;
  });
}

// JSON schema validation tests

// [[Rcpp::export]]
bool rcpp_json_schema_validation_ok() {
  const json schema = make_schema();
  const json instance = R"({"name":"StreamFind","version":1})"_json;

  json_validator validator;
  validator.set_root_schema(schema);
  validator.validate(instance);
  return true;
}

// [[Rcpp::export]]
std::string rcpp_json_schema_validation_error() {
  const json schema = make_schema();
  const json instance = R"({"name":"StreamFind","version":0})"_json;

  json_validator validator;
  validator.set_root_schema(schema);

  try {
    validator.validate(instance);
    return "unexpected success";
  } catch (const std::exception& e) {
    return e.what();
  }
}

// ASM tests

// [[Rcpp::export]]
std::string rcpp_asm_read_file(std::string file_path) {
  return rcpp_json_read_file(std::move(file_path));
}

// [[Rcpp::export]]
Rcpp::DataFrame rcpp_asm_index_table(std::string file_path) {
  return asm_call([&]() {
    asm_json::ASM_FILE file{std::filesystem::path(file_path)};
    file.build_index();

    const auto root = file.root();
    std::vector<std::string> path;
    std::vector<std::string> key;
    std::vector<std::string> kind;
    std::vector<int> child_count;
    std::vector<std::string> parent_path;
    std::vector<int> is_leaf;

    collect_index_rows(root, path, key, kind, child_count, parent_path, is_leaf);

    CharacterVector path_vec(path.begin(), path.end());
    CharacterVector key_vec(key.begin(), key.end());
    CharacterVector kind_vec(kind.begin(), kind.end());
    IntegerVector child_count_vec(child_count.begin(), child_count.end());
    CharacterVector parent_path_vec(parent_path.begin(), parent_path.end());
    LogicalVector is_leaf_vec(is_leaf.begin(), is_leaf.end());

    return DataFrame::create(
      _["path"] = path_vec,
      _["key"] = key_vec,
      _["kind"] = kind_vec,
      _["child_count"] = child_count_vec,
      _["parent_path"] = parent_path_vec,
      _["is_leaf"] = is_leaf_vec,
      _["stringsAsFactors"] = false);
  });
}

// [[Rcpp::export]]
std::string rcpp_asm_read_subtree(std::string file_path, std::string path) {
  return asm_call([&]() {
    asm_json::ASM_FILE file{std::filesystem::path(file_path)};
    return file.read_subtree(path).dump();
  });
}

// [[Rcpp::export]]
std::string rcpp_asm_read_primary_data(std::string file_path) {
  return asm_call([&]() {
    asm_json::ASM_FILE file{std::filesystem::path(file_path)};
    file.build_index();
    return file.read_primary_data().dump();
  });
}

// [[Rcpp::export]]
Rcpp::CharacterVector rcpp_asm_list_children(std::string file_path, std::string path = "") {
  return asm_call([&]() {
    asm_json::ASM_FILE file{std::filesystem::path(file_path)};
    file.build_index();
    auto children = file.node(path).children();
    Rcpp::CharacterVector out(children.size());
    for (R_xlen_t i = 0; i < out.size(); ++i) {
      out[i] = children[static_cast<std::size_t>(i)].info().path;
    }
    return out;
  });
}

// [[Rcpp::export]]
bool rcpp_asm_validate_file(std::string json_file_path,
                            std::string schema_file,
                            std::string schema_root_dir = "") {
  return asm_call([&]() {
    return asm_json::validate_document(std::filesystem::path(json_file_path),
                                       std::filesystem::path(schema_file),
                                       std::filesystem::path(schema_root_dir));
  });
}

// DuckDB tests

// [[Rcpp::export]]
CharacterVector duckdb_list_tables(std::string db_path) {
  duckdb_database db = nullptr;
  duckdb_connection con = nullptr;
  duckdb_result res;
  std::vector<std::string> tables;
  bool opened = false, connected = false, queried = false;
  try {
    if (duckdb_open(db_path.c_str(), &db) != DuckDBSuccess) {
      stop("Failed to open DuckDB database");
    }
    opened = true;
    if (duckdb_connect(db, &con) != DuckDBSuccess) {
      stop("Failed to connect to DuckDB database");
    }
    connected = true;
    if (duckdb_query(
          con,
          "SELECT table_schema, table_name, table_type FROM information_schema.tables "
          "WHERE table_type = 'BASE TABLE' ORDER BY table_schema, table_name",
          &res) != DuckDBSuccess) {
      stop("Failed to query table names");
    }
    queried = true;
    idx_t n = duckdb_row_count(&res);
    idx_t col_count = duckdb_column_count(&res);
    Rcpp::Rcout << "duckdb_row_count: " << n << ", duckdb_column_count: " << col_count << std::endl;
    for (idx_t i = 0; i < n; ++i) {
      for (idx_t j = 0; j < col_count; ++j) {
        const char* val = duckdb_value_varchar(&res, j, i);
        Rcpp::Rcout << "row=" << i << ", col=" << j << ": " << (val ? val : "NULL") << " | ";
        if (val) {
          duckdb_free((void*)val);
        }
      }
      Rcpp::Rcout << std::endl;
    }
    for (idx_t i = 0; i < n; ++i) {
      const char* schema = duckdb_value_varchar(&res, 0, i);
      const char* tname = duckdb_value_varchar(&res, 1, i);
      const char* ttype = duckdb_value_varchar(&res, 2, i);
      if (schema && tname && ttype) {
        std::string item = std::string(schema) + "." + std::string(tname) + " (" + std::string(ttype) + ")";
        tables.push_back(item);
      }
      if (schema) {
        duckdb_free((void*)schema);
      }
      if (tname) {
        duckdb_free((void*)tname);
      }
      if (ttype) {
        duckdb_free((void*)ttype);
      }
    }
  } catch (std::exception& ex) {
    if (queried) {
      duckdb_destroy_result(&res);
    }
    if (connected) {
      duckdb_disconnect(&con);
    }
    if (opened) {
      duckdb_close(&db);
    }
    stop(ex.what());
  } catch (...) {
    if (queried) {
      duckdb_destroy_result(&res);
    }
    if (connected) {
      duckdb_disconnect(&con);
    }
    if (opened) {
      duckdb_close(&db);
    }
    stop("Unknown error in duckdb_list_tables");
  }
  if (queried) {
    duckdb_destroy_result(&res);
  }
  if (connected) {
    duckdb_disconnect(&con);
  }
  if (opened) {
    duckdb_close(&db);
  }
  return wrap(tables);
}

// [[Rcpp::export]]
List duckdb_json_extension_info(std::string db_path) {
  duckdb_database db = nullptr;
  duckdb_connection con = nullptr;
  duckdb_result res;
  std::vector<std::string> loaded_extensions;
  bool opened = false, connected = false;
  std::string install_status, load_status, json_query_status;
  try {
    if (duckdb_open(db_path.c_str(), &db) != DuckDBSuccess) {
      stop("Failed to open DuckDB database");
    }
    opened = true;
    if (duckdb_connect(db, &con) != DuckDBSuccess) {
      stop("Failed to connect to DuckDB database");
    }
    connected = true;
    if (duckdb_query(con, "INSTALL json;", &res) == DuckDBSuccess) {
      install_status = "json extension installed or already present";
    } else {
      install_status = std::string("INSTALL json error: ") + duckdb_result_error(&res);
    }
    duckdb_destroy_result(&res);
    if (duckdb_query(con, "LOAD json;", &res) == DuckDBSuccess) {
      load_status = "json extension loaded or already loaded";
    } else {
      load_status = std::string("LOAD json error: ") + duckdb_result_error(&res);
    }
    duckdb_destroy_result(&res);
    if (duckdb_query(con, "PRAGMA show_loaded_extensions;", &res) == DuckDBSuccess) {
      idx_t n = duckdb_row_count(&res);
      for (idx_t i = 0; i < n; ++i) {
        const char* ext = duckdb_value_varchar(&res, i, 0);
        if (ext) {
          loaded_extensions.push_back(std::string(ext));
          duckdb_free((void*)ext);
        }
      }
    }
    duckdb_destroy_result(&res);
    if (duckdb_query(con, "SELECT json('{\"foo\":42}') AS example_json;", &res) == DuckDBSuccess) {
      const char* v = duckdb_value_varchar(&res, 0, 0);
      json_query_status = std::string("OK: ") + (v ? v : "(NULL)");
      if (v) {
        duckdb_free((void*)v);
      }
    } else {
      json_query_status = std::string("JSON function error: ") + duckdb_result_error(&res);
    }
    duckdb_destroy_result(&res);
  } catch (std::exception& ex) {
    if (connected) {
      duckdb_disconnect(&con);
    }
    if (opened) {
      duckdb_close(&db);
    }
    stop(ex.what());
  } catch (...) {
    if (connected) {
      duckdb_disconnect(&con);
    }
    if (opened) {
      duckdb_close(&db);
    }
    stop("Unknown error in duckdb_json_extension_info");
  }
  if (connected) {
    duckdb_disconnect(&con);
  }
  if (opened) {
    duckdb_close(&db);
  }
  return List::create(
    _["install_status"] = install_status,
    _["load_status"] = load_status,
    _["loaded_extensions"] = wrap(loaded_extensions),
    _["json_query_status"] = json_query_status
  );
}
