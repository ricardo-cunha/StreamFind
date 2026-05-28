#include "project.h"

#include "mass_spec/reader.h"

#include <cstring>
#include <filesystem>
#include <limits>
#include <utility>

namespace project
{

  // Utility helpers (paths, string/JSON helpers)
  namespace utils
  {

    std::filesystem::path normalized_path(const std::string &value)
    {
      return std::filesystem::absolute(std::filesystem::path(value)).lexically_normal();
    }

    std::string upper_copy(std::string value)
    {
      std::transform(value.begin(), value.end(), value.begin(), [](unsigned char ch)
                     { return static_cast<char>(std::toupper(ch)); });
      return value;
    }

    bool same_text(const std::string &lhs, const char *rhs)
    {
      return upper_copy(lhs) == upper_copy(rhs ? std::string(rhs) : std::string());
    }

    std::string json_to_text(const json &value)
    {
      return value.dump();
    }

    json json_from_text(const std::string &value)
    {
      if (value.empty())
      {
        return json();
      }
      try
      {
        return json::parse(value);
      }
      catch (const std::exception &e)
      {
        throw error::ERROR(error::ERROR_CODE::SchemaMismatch, std::string("Invalid JSON payload: ") + e.what());
      }
    }

    std::string normalize_domain(std::string value)
    {
      if (value.empty())
      {
        return value;
      }
      std::transform(value.begin(), value.end(), value.begin(), [](unsigned char ch)
                     { return static_cast<char>(std::tolower(ch)); });
      return value;
    }

    void validate_domain_code(const std::string &value)
    {
      const std::string domain = normalize_domain(value);
      if (domain.empty())
      {
        throw error::ERROR(error::ERROR_CODE::InvalidArgument, "Project domain must not be empty");
      }
      if (domain != "ms" &&
          domain != "raman" &&
          domain != "stat" &&
          domain != "mass_spec_spectra" &&
          domain != "mass_spec_chromatograms" &&
          domain != "mass_spec_nts")
      {
        throw error::ERROR(error::ERROR_CODE::InvalidArgument, "Unsupported project domain: " + value);
      }
    }

  } // namespace utils

  // Database helpers and RAII guards
  namespace db
  {

    static std::shared_ptr<project::api::CONTEXT> require_context(const std::shared_ptr<project::api::CONTEXT> &ctx)
    {
      if (!ctx || ctx->db_path.empty() || ctx->project_id.empty())
      {
        throw error::ERROR(error::ERROR_CODE::InvalidArgument, "Project context is not initialized");
      }
      return ctx;
    }

    static project::db::CONNECTION_GUARD connect(const std::shared_ptr<project::api::CONTEXT> &ctx)
    {
      return project::db::CONNECTION_GUARD(require_context(ctx));
    }

    static void ensure_json_extension(duckdb_connection con)
    {
      duckdb_result result{};
      if (duckdb_query(con, "INSTALL json", &result) == DuckDBError)
      {
        const char *err = duckdb_result_error(&result);
        const std::string message = err ? std::string(err) : std::string("unknown DuckDB error");
        duckdb_destroy_result(&result);
        throw error::ERROR(error::ERROR_CODE::DuckDB, "install json extension: " + message);
      }
      duckdb_destroy_result(&result);

      if (duckdb_query(con, "LOAD json", &result) == DuckDBError)
      {
        const char *err = duckdb_result_error(&result);
        const std::string message = err ? std::string(err) : std::string("unknown DuckDB error");
        duckdb_destroy_result(&result);
        throw error::ERROR(error::ERROR_CODE::DuckDB, "load json extension: " + message);
      }
      duckdb_destroy_result(&result);
    }

    // CONNECTION_GUARD implementation
    CONNECTION_GUARD::CONNECTION_GUARD(const std::shared_ptr<project::api::CONTEXT> &ctx)
    {
      if (!ctx || ctx->db_path.empty())
      {
        throw error::ERROR(error::ERROR_CODE::InvalidArgument, "Project context is not initialized");
      }
      try
      {
        char *open_error = nullptr;
        if (duckdb_open_ext(ctx->db_path.c_str(), &db_, nullptr, &open_error) != DuckDBSuccess)
        {
          const std::string message = open_error ? std::string(open_error) : std::string("Failed to open DuckDB database");
          if (open_error)
          {
            duckdb_free(open_error);
          }
          throw error::ERROR(error::ERROR_CODE::DuckDB, message);
        }
        if (duckdb_connect(db_, &con_) != DuckDBSuccess)
        {
          throw error::ERROR(error::ERROR_CODE::DuckDB, "Failed to connect to DuckDB database");
        }
        ensure_json_extension(con_);
      }
      catch (...)
      {
        if (con_)
        {
          duckdb_disconnect(&con_);
        }
        if (db_)
        {
          duckdb_close(&db_);
        }
        db_ = nullptr;
        con_ = nullptr;
        throw;
      }
    }

    CONNECTION_GUARD::~CONNECTION_GUARD()
    {
      if (con_)
      {
        duckdb_disconnect(&con_);
      }
      if (db_)
      {
        duckdb_close(&db_);
      }
    }

    CONNECTION_GUARD::CONNECTION_GUARD(CONNECTION_GUARD &&other) noexcept : db_(other.db_), con_(other.con_)
    {
      other.db_ = nullptr;
      other.con_ = nullptr;
    }

    CONNECTION_GUARD &CONNECTION_GUARD::operator=(CONNECTION_GUARD &&other) noexcept
    {
      if (this != &other)
      {
        if (con_)
        {
          duckdb_disconnect(&con_);
        }
        if (db_)
        {
          duckdb_close(&db_);
        }
        db_ = other.db_;
        con_ = other.con_;
        other.db_ = nullptr;
        other.con_ = nullptr;
      }
      return *this;
    }

    duckdb_connection CONNECTION_GUARD::get() const noexcept { return con_; }

    // RESULT_GUARD implementation
    RESULT_GUARD::RESULT_GUARD(duckdb_result *result) : result_(result) {}

    RESULT_GUARD::~RESULT_GUARD()
    {
      if (result_)
      {
        duckdb_destroy_result(result_);
      }
    }

    RESULT_GUARD::RESULT_GUARD(RESULT_GUARD &&other) noexcept : result_(other.result_)
    {
      other.result_ = nullptr;
    }

    RESULT_GUARD &RESULT_GUARD::operator=(RESULT_GUARD &&other) noexcept
    {
      if (this != &other)
      {
        if (result_)
        {
          duckdb_destroy_result(result_);
        }
        result_ = other.result_;
        other.result_ = nullptr;
      }
      return *this;
    }

    // PREPARE_GUARD implementation
    PREPARE_GUARD::PREPARE_GUARD(duckdb_prepared_statement *statement) : statement_(statement) {}

    PREPARE_GUARD::~PREPARE_GUARD()
    {
      if (statement_ && *statement_)
      {
        duckdb_destroy_prepare(statement_);
      }
    }

    PREPARE_GUARD::PREPARE_GUARD(PREPARE_GUARD &&other) noexcept : statement_(other.statement_)
    {
      other.statement_ = nullptr;
    }

    PREPARE_GUARD &PREPARE_GUARD::operator=(PREPARE_GUARD &&other) noexcept
    {
      if (this != &other)
      {
        if (statement_ && *statement_)
        {
          duckdb_destroy_prepare(statement_);
        }
        statement_ = other.statement_;
        other.statement_ = nullptr;
      }
      return *this;
    }

    static void ensure_database_domain_compatible(const std::shared_ptr<project::api::CONTEXT> &ctx, const std::string &value)
    {
      const std::string domain = project::utils::normalize_domain(value);
      if (domain.empty())
      {
        return;
      }

      auto guard = db::connect(ctx);
      std::optional<std::string> existing;
      project::db::run_prepared(guard.get(), "SELECT domain FROM PROJECT WHERE domain IS NOT NULL AND domain <> '' GROUP BY domain ORDER BY domain LIMIT 1", "load database domain", [](duckdb_prepared_statement) {}, [&](duckdb_result &result)
                                {
                                  if (duckdb_row_count(&result) == 0) {
                                    return;
                                  }
                                  existing = project::utils::normalize_domain(project::db::result_varchar(&result, 0, 0)); });
      if (existing && *existing != domain)
      {
        throw error::ERROR(error::ERROR_CODE::InvalidArgument,
                           "Database domain is already set to " + *existing + " and cannot be changed to " + domain);
      }
    }

    std::string result_error(duckdb_result *result)
    {
      const char *err = duckdb_result_error(result);
      return err ? std::string(err) : std::string("unknown DuckDB error");
    }

    std::string result_varchar(duckdb_result *result, idx_t col, idx_t row)
    {
      char *value = duckdb_value_varchar(result, col, row);
      if (!value)
      {
        return {};
      }
      std::string out(value);
      duckdb_free(value);
      return out;
    }

    std::vector<std::uint8_t> result_blob(duckdb_result *result, idx_t col, idx_t row)
    {
      duckdb_blob blob = duckdb_value_blob(result, col, row);
      if (!blob.data || blob.size == 0)
      {
        if (blob.data)
        {
          duckdb_free(blob.data);
        }
        return {};
      }

      auto *bytes = static_cast<std::uint8_t *>(blob.data);
      std::vector<std::uint8_t> out(bytes, bytes + blob.size);
      duckdb_free(blob.data);
      return out;
    }

    void bind_optional_varchar(duckdb_prepared_statement statement, idx_t index, const std::string &value)
    {
      if (value.empty())
      {
        duckdb_bind_null(statement, index);
      }
      else
      {
        duckdb_bind_varchar(statement, index, value.c_str());
      }
    }

    void run_sql(duckdb_connection con, const std::string &sql, const char *context)
    {
      duckdb_result result{};
      if (duckdb_query(con, sql.c_str(), &result) == DuckDBError)
      {
        std::string message = result_error(&result);
        duckdb_destroy_result(&result);
        throw error::ERROR(error::ERROR_CODE::DuckDB, std::string(context) + ": " + message);
      }
      duckdb_destroy_result(&result);
    }

    void validate_columns(duckdb_connection con,
                          const char *table_name,
                          const std::vector<COLUMN_SPEC> &expected)
    {
      std::ostringstream sql;
      sql << "PRAGMA table_info('" << table_name << "')";

      duckdb_result result{};
      if (duckdb_query(con, sql.str().c_str(), &result) == DuckDBError)
      {
        std::string message = result_error(&result);
        duckdb_destroy_result(&result);
        throw error::ERROR(error::ERROR_CODE::SchemaMismatch, std::string("Schema check failed for ") + table_name + ": " + message);
      }
      RESULT_GUARD guard(&result);

      const idx_t count = duckdb_row_count(&result);
      if (count != expected.size())
      {
        throw error::ERROR(error::ERROR_CODE::SchemaMismatch,
                           std::string("Schema mismatch for ") + table_name + ": unexpected column count");
      }

      for (idx_t row = 0; row < count; ++row)
      {
        const std::string name = result_varchar(&result, 1, row);
        const std::string type = result_varchar(&result, 2, row);
        const bool not_null = duckdb_value_int32(&result, 3, row) != 0;
        const auto &spec = expected[static_cast<std::size_t>(row)];
        if (name != spec.name || !project::utils::same_text(type, spec.type) || not_null != spec.not_null)
        {
          throw error::ERROR(error::ERROR_CODE::SchemaMismatch,
                             std::string("Schema mismatch for ") + table_name + ": column " + spec.name + " does not match");
        }
      }
    }

    std::vector<COLUMN_INFO> table_columns(duckdb_connection con, const char *table_name)
    {
      std::ostringstream sql;
      sql << "PRAGMA table_info('" << table_name << "')";

      duckdb_result result{};
      if (duckdb_query(con, sql.str().c_str(), &result) == DuckDBError)
      {
        std::string message = result_error(&result);
        duckdb_destroy_result(&result);
        throw error::ERROR(error::ERROR_CODE::SchemaMismatch, std::string("Schema check failed for ") + table_name + ": " + message);
      }
      RESULT_GUARD guard(&result);

      const idx_t count = duckdb_row_count(&result);
      std::vector<COLUMN_INFO> out;
      out.reserve(static_cast<std::size_t>(count));
      for (idx_t row = 0; row < count; ++row)
      {
        out.push_back(COLUMN_INFO{result_varchar(&result, 1, row),
                                  result_varchar(&result, 2, row),
                                  duckdb_value_int32(&result, 3, row) != 0});
      }
      return out;
    }

    void validate_columns_present(duckdb_connection con,
                                  const char *table_name,
                                  const std::vector<COLUMN_SPEC> &expected)
    {
      const auto actual = table_columns(con, table_name);
      for (const auto &spec : expected)
      {
        const auto it = std::find_if(actual.begin(), actual.end(), [&](const COLUMN_INFO &info)
                                     { return info.name == spec.name; });
        if (it == actual.end())
        {
          throw error::ERROR(error::ERROR_CODE::SchemaMismatch,
                             std::string("Schema mismatch for ") + table_name + ": missing column " + spec.name);
        }
        if (!project::utils::same_text(it->type, spec.type) || it->not_null != spec.not_null)
        {
          throw error::ERROR(error::ERROR_CODE::SchemaMismatch,
                             std::string("Schema mismatch for ") + table_name + ": column " + spec.name + " does not match");
        }
      }
    };

    /// @brief Generate a comma-separated list of placeholders for SQL queries.
    std::string placeholders(std::size_t count)
    {
      std::string sql;
      sql.reserve(count * 3);
      for (std::size_t i = 0; i < count; ++i)
      {
        if (i > 0)
        {
          sql += ", ";
        }
        sql += "?";
      }
      return sql;
    };

    double nullable_double(double value) { return value; }

    int nullable_int(int value) { return value; }

  } // namespace db

  // CACHE implementation
  namespace cache
  {

    constexpr const char *kInvalidCachePayload = "Invalid cached binary payload";

    static std::size_t checked_size(std::uint64_t value, std::size_t unit_size, const char *context)
    {
      if (value > static_cast<std::uint64_t>(std::numeric_limits<std::size_t>::max()))
      {
        throw error::ERROR(error::ERROR_CODE::SchemaMismatch, std::string(context) + ": size is too large");
      }

      const std::size_t out = static_cast<std::size_t>(value);
      if (unit_size > 0 && out > std::numeric_limits<std::size_t>::max() / unit_size)
      {
        throw error::ERROR(error::ERROR_CODE::SchemaMismatch, std::string(context) + ": byte size overflows");
      }
      return out;
    }

    static void ensure_fully_consumed(BINARY_READER &reader, const char *context)
    {
      if (!reader.empty())
      {
        throw error::ERROR(error::ERROR_CODE::SchemaMismatch, std::string(context) + ": trailing bytes remain");
      }
    }

    BINARY_READER::BINARY_READER(const std::vector<std::uint8_t> &bytes) : bytes_(bytes) {}

    void BINARY_READER::read_bytes(void *destination, std::size_t count)
    {
      if (count == 0)
      {
        return;
      }
      if (count > remaining())
      {
        throw error::ERROR(error::ERROR_CODE::SchemaMismatch, kInvalidCachePayload);
      }
      std::memcpy(destination, bytes_.data() + offset_, count);
      offset_ += count;
    }

    bool BINARY_READER::empty() const noexcept
    {
      return offset_ >= bytes_.size();
    }

    std::size_t BINARY_READER::remaining() const noexcept
    {
      return bytes_.size() - offset_;
    }

    void append_bytes(std::vector<std::uint8_t> &out,
                      const void *data,
                      std::size_t count)
    {
      if (count == 0)
      {
        return;
      }
      const auto *begin = static_cast<const std::uint8_t *>(data);
      out.insert(out.end(), begin, begin + count);
    }

    void write_string(std::vector<std::uint8_t> &out,
                      const std::string &value)
    {
      write_scalar<std::uint64_t>(out, static_cast<std::uint64_t>(value.size()));
      append_bytes(out, value.data(), value.size());
    }

    std::string read_string(BINARY_READER &reader)
    {
      const std::size_t count = checked_size(read_scalar<std::uint64_t>(reader), sizeof(char), "read string");
      std::string value(count, '\0');
      if (!value.empty())
      {
        reader.read_bytes(value.data(), value.size());
      }
      return value;
    }

    void write_vector(std::vector<std::uint8_t> &out,
                      const std::vector<std::string> &values)
    {
      write_scalar<std::uint64_t>(out, static_cast<std::uint64_t>(values.size()));
      for (const auto &value : values)
      {
        write_string(out, value);
      }
    }

    void read_vector(BINARY_READER &reader,
                     std::vector<std::string> &values)
    {
      const std::size_t count = checked_size(read_scalar<std::uint64_t>(reader), sizeof(std::string), "read string vector");
      values.clear();
      values.reserve(count);
      for (std::size_t index = 0; index < count; ++index)
      {
        values.push_back(read_string(reader));
      }
    }

    void write_vector(std::vector<std::uint8_t> &out,
                      const std::vector<float> &values)
    {
      write_scalar<std::uint64_t>(out, static_cast<std::uint64_t>(values.size()));
      if (values.empty())
      {
        return;
      }
      const std::string encoded = mass_spec::reader::utils::encode_little_endian_from_float(values, 4);
      append_bytes(out, encoded.data(), encoded.size());
    }

    void read_vector(BINARY_READER &reader,
                     std::vector<float> &values)
    {
      const std::size_t count = checked_size(read_scalar<std::uint64_t>(reader), sizeof(float), "read float vector");
      if (count == 0)
      {
        values.clear();
        return;
      }

      std::string encoded(count * sizeof(float), '\0');
      reader.read_bytes(encoded.data(), encoded.size());
      values = mass_spec::reader::utils::decode_little_endian_to_float(encoded, 4);
      if (values.size() != count)
      {
        throw error::ERROR(error::ERROR_CODE::SchemaMismatch, "read float vector: decoded size mismatch");
      }
    }

    void write_vector(std::vector<std::uint8_t> &out,
                      const std::vector<double> &values)
    {
      write_scalar<std::uint64_t>(out, static_cast<std::uint64_t>(values.size()));
      if (values.empty())
      {
        return;
      }
      const std::string encoded = mass_spec::reader::utils::encode_little_endian_from_double(values, 8);
      append_bytes(out, encoded.data(), encoded.size());
    }

    void read_vector(BINARY_READER &reader,
                     std::vector<double> &values)
    {
      const std::size_t count = checked_size(read_scalar<std::uint64_t>(reader), sizeof(double), "read double vector");
      if (count == 0)
      {
        values.clear();
        return;
      }

      std::string encoded(count * sizeof(double), '\0');
      reader.read_bytes(encoded.data(), encoded.size());
      values = mass_spec::reader::utils::decode_little_endian_to_double(encoded, 8);
      if (values.size() != count)
      {
        throw error::ERROR(error::ERROR_CODE::SchemaMismatch, "read double vector: decoded size mismatch");
      }
    }

    void write_vector(std::vector<std::uint8_t> &out,
                      const std::vector<bool> &values)
    {
      write_scalar<std::uint64_t>(out, static_cast<std::uint64_t>(values.size()));
      for (bool value : values)
      {
        const std::uint8_t encoded = value ? 1U : 0U;
        append_bytes(out, &encoded, sizeof(encoded));
      }
    }

    void read_vector(BINARY_READER &reader,
                     std::vector<bool> &values)
    {
      const std::size_t count = checked_size(read_scalar<std::uint64_t>(reader), sizeof(std::uint8_t), "read bool vector");
      values.clear();
      values.reserve(count);
      for (std::size_t index = 0; index < count; ++index)
      {
        const std::uint8_t encoded = read_scalar<std::uint8_t>(reader);
        values.push_back(encoded != 0);
      }
    }

    CACHE::CACHE(std::shared_ptr<project::api::CONTEXT> ctx)
        : project::api::TABLE_BASE<project::cache::CACHE_ROW>(std::move(ctx)) {}

    void CACHE::create_schema(const std::shared_ptr<project::api::CONTEXT> &ctx)
    {
      auto guard = project::db::CONNECTION_GUARD(ctx);
      project::db::run_sql(guard.get(),
                           "CREATE TABLE IF NOT EXISTS CACHE (project_id VARCHAR NOT NULL, name VARCHAR NOT NULL, description VARCHAR NOT NULL, hash VARCHAR NOT NULL, data BLOB NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(project_id, hash))",
                           "create CACHE table");
    }

    void CACHE::validate_schema(const std::shared_ptr<project::api::CONTEXT> &ctx)
    {
      auto guard = project::db::CONNECTION_GUARD(ctx);
      project::db::validate_columns_present(guard.get(), table_name(), {{"project_id", "VARCHAR", true}, {"name", "VARCHAR", true}, {"description", "VARCHAR", true}, {"hash", "VARCHAR", true}, {"data", "BLOB", true}, {"created_at", "TIMESTAMP", false}});
    }

    std::vector<CACHE::ROW_TYPE> CACHE::all() const
    {
      auto guard = project::db::CONNECTION_GUARD(context());
      std::vector<ROW_TYPE> out;
      project::db::run_prepared(guard.get(), "SELECT project_id, name, description, hash, data, created_at FROM CACHE WHERE project_id = ? ORDER BY created_at DESC", "query CACHE", [&](duckdb_prepared_statement statement)
                                { duckdb_bind_varchar(statement, 1, context()->project_id.c_str()); }, [&](duckdb_result &result)
                                { out = project::db::rows_from_result(&result, [&](idx_t row)
                                                                      {
          ROW_TYPE value;
          value.project_id = project::db::result_varchar(&result, 0, row);
          value.name = project::db::result_varchar(&result, 1, row);
          value.description = project::db::result_varchar(&result, 2, row);
          value.hash = project::db::result_varchar(&result, 3, row);
          value.data = project::db::result_blob(&result, 4, row);
          value.created_at = project::db::result_varchar(&result, 5, row);
          return value; }); });
      return out;
    }

    std::optional<CACHE::ROW_TYPE> CACHE::get(const std::string &hash) const
    {
      auto guard = project::db::CONNECTION_GUARD(context());
      return get(guard.get(), hash);
    }

    std::optional<CACHE::ROW_TYPE> CACHE::get(duckdb_connection con, const std::string &hash) const
    {
      std::optional<ROW_TYPE> out;
      project::db::run_prepared(con, "SELECT project_id, name, description, hash, data, created_at FROM CACHE WHERE project_id = ? AND hash = ? LIMIT 1", "get CACHE row", [&](duckdb_prepared_statement statement)
                                {
                 duckdb_bind_varchar(statement, 1, context()->project_id.c_str());
                 duckdb_bind_varchar(statement, 2, hash.c_str()); }, [&](duckdb_result &result)
                                {
                 if (duckdb_row_count(&result) == 0) return;
                 ROW_TYPE value;
                 value.project_id = project::db::result_varchar(&result, 0, 0);
                 value.name = project::db::result_varchar(&result, 1, 0);
                 value.description = project::db::result_varchar(&result, 2, 0);
                 value.hash = project::db::result_varchar(&result, 3, 0);
                 value.data = project::db::result_blob(&result, 4, 0);
                 value.created_at = project::db::result_varchar(&result, 5, 0);
                 out = std::move(value); });
      return out;
    }

    std::optional<std::vector<std::uint8_t>> CACHE::get_bytes(const std::string &hash) const
    {
      auto guard = project::db::CONNECTION_GUARD(context());
      return get_bytes(guard.get(), hash);
    }

    std::optional<std::vector<std::uint8_t>> CACHE::get_bytes(duckdb_connection con, const std::string &hash) const
    {
      std::optional<std::vector<std::uint8_t>> out;
      project::db::run_prepared(con, "SELECT data FROM CACHE WHERE project_id = ? AND hash = ? LIMIT 1", "get CACHE bytes", [&](duckdb_prepared_statement statement)
                                {
                 duckdb_bind_varchar(statement, 1, context()->project_id.c_str());
                 duckdb_bind_varchar(statement, 2, hash.c_str()); }, [&](duckdb_result &result)
                                {
                 if (duckdb_row_count(&result) == 0) return;
                 out = project::db::result_blob(&result, 0, 0); });
      return out;
    }

    void CACHE::put(const ROW_TYPE &row)
    {
      put(row.name, row.hash, row.description, row.data);
    }

    void CACHE::put(const std::string &name,
                    const std::string &hash,
                    const std::string &description,
                    const std::vector<std::uint8_t> &data)
    {
      auto guard = project::db::CONNECTION_GUARD(context());
      put(guard.get(), name, hash, description, data);
    }

    void CACHE::put(duckdb_connection con,
                    const std::string &name,
                    const std::string &hash,
                    const std::string &description,
                    const std::vector<std::uint8_t> &data)
    {
      project::db::run_prepared(con, "INSERT INTO CACHE (project_id, name, description, hash, data) VALUES (?, ?, ?, ?, ?) ON CONFLICT(project_id, hash) DO UPDATE SET name = excluded.name, description = excluded.description, data = excluded.data", "put CACHE row", [&](duckdb_prepared_statement statement)
                                {
                 duckdb_bind_varchar(statement, 1, context()->project_id.c_str());
                 duckdb_bind_varchar(statement, 2, name.c_str());
                 duckdb_bind_varchar(statement, 3, description.c_str());
                 duckdb_bind_varchar(statement, 4, hash.c_str());
                 if (data.empty()) {
                   duckdb_bind_null(statement, 5);
                 } else {
                   duckdb_bind_blob(statement, 5, const_cast<void*>(static_cast<const void*>(data.data())), static_cast<uint32_t>(data.size()));
                 } }, [](duckdb_result &) {});
    }

    void CACHE::remove(const std::string &hash)
    {
      auto guard = project::db::CONNECTION_GUARD(context());
      project::db::run_prepared(guard.get(), "DELETE FROM CACHE WHERE project_id = ? AND hash = ?", "delete CACHE row", [&](duckdb_prepared_statement statement)
                                {
                 duckdb_bind_varchar(statement, 1, context()->project_id.c_str());
                 duckdb_bind_varchar(statement, 2, hash.c_str()); }, [](duckdb_result &) {});
    }

    void CACHE::clear()
    {
      auto guard = project::db::CONNECTION_GUARD(context());
      project::db::run_prepared(guard.get(), "DELETE FROM CACHE WHERE project_id = ?", "clear CACHE", [&](duckdb_prepared_statement statement)
                                { duckdb_bind_varchar(statement, 1, context()->project_id.c_str()); }, [](duckdb_result &) {});
    }

  } // namespace cache

  // AUDIT_TRAIL implementation
  namespace audit_trail
  {

    void to_json(json &j, const AUDIT_TRAIL_ROW &x)
    {
      j = json::object();
      j["project_id"] = x.project_id;
      j["operation_type"] = x.operation_type;
      j["object_type"] = x.object_type;
      j["operation_details"] = x.operation_details;
      j["created_at"] = x.created_at;
    }

    void from_json(const json &j, AUDIT_TRAIL_ROW &x)
    {
      if (j.contains("project_id"))
        x.project_id = j.at("project_id").get<std::string>();
      if (j.contains("operation_type"))
        x.operation_type = j.at("operation_type").get<std::string>();
      if (j.contains("object_type"))
        x.object_type = j.at("object_type").get<std::string>();
      if (j.contains("operation_details"))
        x.operation_details = project::utils::json_from_text(j.at("operation_details").get<std::string>());
      if (j.contains("created_at"))
        x.created_at = j.at("created_at").get<std::string>();
    }

    AUDIT_TRAIL::AUDIT_TRAIL(std::shared_ptr<project::api::CONTEXT> ctx)
        : project::api::TABLE_BASE<project::audit_trail::AUDIT_TRAIL_ROW>(std::move(ctx)) {}

    void AUDIT_TRAIL::create_schema(const std::shared_ptr<project::api::CONTEXT> &ctx)
    {
      auto guard = project::db::CONNECTION_GUARD(ctx);
      project::db::run_sql(guard.get(),
                           "CREATE TABLE IF NOT EXISTS AUDIT_TRAIL (project_id VARCHAR NOT NULL, operation_type VARCHAR NOT NULL, object_type VARCHAR NOT NULL, operation_details JSON, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)",
                           "create AUDIT_TRAIL table");
    }

    void AUDIT_TRAIL::validate_schema(const std::shared_ptr<project::api::CONTEXT> &ctx)
    {
      auto guard = project::db::CONNECTION_GUARD(ctx);
      project::db::validate_columns_present(guard.get(), "AUDIT_TRAIL", {{"project_id", "VARCHAR", true}, {"operation_type", "VARCHAR", true}, {"object_type", "VARCHAR", true}, {"operation_details", "JSON", false}, {"created_at", "TIMESTAMP", false}});
    }

    std::vector<AUDIT_TRAIL::ROW_TYPE> AUDIT_TRAIL::all() const
    {
      auto guard = project::db::CONNECTION_GUARD(context());
      std::vector<ROW_TYPE> out;
      project::db::run_prepared(guard.get(), "SELECT project_id, operation_type, object_type, operation_details, created_at FROM AUDIT_TRAIL WHERE project_id = ? ORDER BY created_at DESC", "query AUDIT_TRAIL", [&](duckdb_prepared_statement statement)
                                { duckdb_bind_varchar(statement, 1, context()->project_id.c_str()); }, [&](duckdb_result &result)
                                { out = project::db::rows_from_result(&result, [&](idx_t row)
                                                                      {
                   ROW_TYPE value;
                   value.project_id = project::db::result_varchar(&result, 0, row);
                   value.operation_type = project::db::result_varchar(&result, 1, row);
                   value.object_type = project::db::result_varchar(&result, 2, row);
                   value.operation_details = project::utils::json_from_text(project::db::result_varchar(&result, 3, row));
                   value.created_at = project::db::result_varchar(&result, 4, row);
                   return value; }); });
      return out;
    }

    void AUDIT_TRAIL::add(const std::string &operation_type,
                          const std::string &object_type,
                          const json &details)
    {
      auto guard = project::db::CONNECTION_GUARD(context());
      const std::string txt = project::utils::json_to_text(details);
      project::db::run_prepared(guard.get(), "INSERT INTO AUDIT_TRAIL (project_id, operation_type, object_type, operation_details) VALUES (?, ?, ?, ?)", "insert AUDIT_TRAIL row", [&](duckdb_prepared_statement statement)
                                {
                 duckdb_bind_varchar(statement, 1, context()->project_id.c_str());
                 duckdb_bind_varchar(statement, 2, operation_type.c_str());
                 duckdb_bind_varchar(statement, 3, object_type.c_str());
                 duckdb_bind_varchar(statement, 4, txt.c_str()); }, [](duckdb_result &) {});
    }

    void AUDIT_TRAIL::clear()
    {
      auto guard = project::db::CONNECTION_GUARD(context());
      project::db::run_prepared(guard.get(), "DELETE FROM AUDIT_TRAIL WHERE project_id = ?", "clear AUDIT_TRAIL", [&](duckdb_prepared_statement statement)
                                { duckdb_bind_varchar(statement, 1, context()->project_id.c_str()); }, [](duckdb_result &) {});
    }
  } // namespace audit_trail

  // Error implementations
  namespace error
  {

    ERROR::ERROR(ERROR_CODE code, std::string message) : std::runtime_error(std::move(message)), code_(code) {}

    ERROR_CODE ERROR::code() const noexcept
    {
      return code_;
    }

    std::string ERROR::error_code_to_string(ERROR_CODE code)
    {
      switch (code)
      {
      case ERROR_CODE::DuckDB:
        return "DuckDB";
      case ERROR_CODE::InvalidArgument:
        return "InvalidArgument";
      case ERROR_CODE::SchemaMismatch:
        return "SchemaMismatch";
      case ERROR_CODE::NotFound:
        return "NotFound";
      case ERROR_CODE::Io:
        return "Io";
      case ERROR_CODE::Unknown:
      default:
        return "Unknown";
      }
    }

  } // namespace error

  // API (PROJECT) implementations
  namespace api
  {

    void PROJECT::create_schema(const std::shared_ptr<CONTEXT> &ctx)
    {
      auto guard = project::db::connect(ctx);
      project::db::run_sql(guard.get(),
                           "CREATE TABLE IF NOT EXISTS PROJECT (project_id VARCHAR NOT NULL PRIMARY KEY, domain VARCHAR, metadata JSON, workflow JSON, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)",
                           "create PROJECT table");
      const auto columns = project::db::table_columns(guard.get(), "PROJECT");
      const auto has_domain = std::find_if(columns.begin(), columns.end(), [](const project::db::COLUMN_INFO &info)
                                           { return info.name == "domain"; });
      if (has_domain == columns.end())
      {
        project::db::run_sql(guard.get(), "ALTER TABLE PROJECT ADD COLUMN domain VARCHAR", "add PROJECT domain column");
      }
    }

    void PROJECT::validate_schema(const std::shared_ptr<project::api::CONTEXT> &ctx)
    {
      auto guard = project::db::connect(ctx);
      project::db::validate_columns_present(guard.get(), "PROJECT", {{"project_id", "VARCHAR", true}, {"domain", "VARCHAR", false}, {"metadata", "JSON", false}, {"workflow", "JSON", false}, {"created_at", "TIMESTAMP", false}});
    }

    void PROJECT::ensure_row_exists(const std::shared_ptr<project::api::CONTEXT> &ctx)
    {
      auto guard = project::db::connect(ctx);
      project::db::run_prepared(guard.get(), "INSERT INTO PROJECT (project_id, domain, metadata, workflow) VALUES (?, ?, ?, ?) ON CONFLICT(project_id) DO NOTHING", "insert PROJECT row", [&](duckdb_prepared_statement statement)
                                {
                  duckdb_bind_varchar(statement, 1, ctx->project_id.c_str());
                  duckdb_bind_null(statement, 2);
                  const std::string metadata = project::utils::json_to_text(json::object());
                  const std::string workflow = project::utils::json_to_text(json::array());
                  duckdb_bind_varchar(statement, 3, metadata.c_str());
                  duckdb_bind_varchar(statement, 4, workflow.c_str()); }, [](duckdb_result &) {});
    }

    project::api::PROJECT_ROW PROJECT::read_row(const std::shared_ptr<project::api::CONTEXT> &ctx)
    {
      auto guard = project::db::connect(ctx);
      std::optional<project::api::PROJECT_ROW> out;
      project::db::run_prepared(guard.get(), "SELECT project_id, domain, metadata, workflow, created_at FROM PROJECT WHERE project_id = ? LIMIT 1", "load PROJECT row", [&](duckdb_prepared_statement statement)
                                { duckdb_bind_varchar(statement, 1, ctx->project_id.c_str()); }, [&](duckdb_result &result)
                                {
                                  if (duckdb_row_count(&result) == 0) {
                                    return;
                                  }
                                  project::api::PROJECT_ROW row;
                                  row.project_id = project::db::result_varchar(&result, 0, 0);
                                  row.domain = project::utils::normalize_domain(project::db::result_varchar(&result, 1, 0));
                                  row.metadata = project::utils::json_from_text(project::db::result_varchar(&result, 2, 0));
                                  row.workflow = project::utils::json_from_text(project::db::result_varchar(&result, 3, 0));
                                  row.created_at = project::db::result_varchar(&result, 4, 0);
                                  out = std::move(row); });
      if (!out)
      {
        throw error::ERROR(error::ERROR_CODE::NotFound, "Project row not found: " + ctx->project_id);
      }
      return *out;
    }

    void PROJECT::update_row(const std::shared_ptr<project::api::CONTEXT> &ctx, const project::api::PROJECT_ROW &row)
    {
      if (row.project_id != ctx->project_id)
      {
        throw error::ERROR(error::ERROR_CODE::InvalidArgument, "Project row id does not match the active project");
      }
      project::api::PROJECT_ROW value = row;
      value.domain = project::utils::normalize_domain(value.domain);
      if (!value.domain.empty())
      {
        project::utils::validate_domain_code(value.domain);
      }

      auto guard = project::db::connect(ctx);
      project::db::run_prepared(guard.get(), "INSERT INTO PROJECT (project_id, domain, metadata, workflow) VALUES (?, ?, ?, ?) ON CONFLICT(project_id) DO UPDATE SET domain = excluded.domain, metadata = excluded.metadata, workflow = excluded.workflow", "update PROJECT row", [&](duckdb_prepared_statement statement)
                                {
                  duckdb_bind_varchar(statement, 1, value.project_id.c_str());
                  if (value.domain.empty()) {
                    duckdb_bind_null(statement, 2);
                  } else {
                    duckdb_bind_varchar(statement, 2, value.domain.c_str());
                  }
                  const std::string metadata = project::utils::json_to_text(value.metadata);
                  const std::string workflow = project::utils::json_to_text(value.workflow);
                  duckdb_bind_varchar(statement, 3, metadata.c_str());
                  duckdb_bind_varchar(statement, 4, workflow.c_str()); }, [](duckdb_result &) {});
    }

    PROJECT::PROJECT(std::string db_path, std::string project_id)
        : ctx_(std::make_shared<CONTEXT>())
    {
      if (db_path.empty())
      {
        throw error::ERROR(error::ERROR_CODE::InvalidArgument, "Project requires a database path");
      }
      if (project_id.empty())
      {
        throw error::ERROR(error::ERROR_CODE::InvalidArgument, "Project requires a project_id");
      }

      try
      {
        const auto normalized_db_path = project::utils::normalized_path(db_path);
        db_path = normalized_db_path.string();
        const auto parent = normalized_db_path.parent_path();
        if (!parent.empty())
        {
          std::filesystem::create_directories(parent);
        }
      }
      catch (const std::filesystem::filesystem_error &e)
      {
        throw error::ERROR(error::ERROR_CODE::Io, std::string("Failed to prepare database directory: ") + e.what());
      }

      ctx_->db_path = std::move(db_path);
      ctx_->project_id = std::move(project_id);

      auto guard = project::db::connect(ctx_);
      project::db::run_sql(guard.get(),
                           "CREATE TABLE IF NOT EXISTS PROJECT (project_id VARCHAR NOT NULL PRIMARY KEY, domain VARCHAR, metadata JSON, workflow JSON, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)",
                           "create PROJECT table");
      const auto columns = project::db::table_columns(guard.get(), "PROJECT");
      const auto has_domain = std::find_if(columns.begin(), columns.end(), [](const project::db::COLUMN_INFO &info)
                                           { return info.name == "domain"; });
      if (has_domain == columns.end())
      {
        project::db::run_sql(guard.get(), "ALTER TABLE PROJECT ADD COLUMN domain VARCHAR", "add PROJECT domain column");
      }
      project::db::run_sql(guard.get(),
                           "CREATE TABLE IF NOT EXISTS CACHE (project_id VARCHAR NOT NULL, name VARCHAR NOT NULL, description VARCHAR NOT NULL, hash VARCHAR NOT NULL, data BLOB NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(project_id, hash))",
                           "create CACHE table");
      project::db::run_sql(guard.get(),
                           "CREATE TABLE IF NOT EXISTS AUDIT_TRAIL (project_id VARCHAR NOT NULL, operation_type VARCHAR NOT NULL, object_type VARCHAR NOT NULL, operation_details JSON, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)",
                           "create AUDIT_TRAIL table");

      project::db::run_prepared(guard.get(), "INSERT INTO PROJECT (project_id, domain, metadata, workflow) VALUES (?, ?, ?, ?) ON CONFLICT(project_id) DO NOTHING", "insert PROJECT row", [&](duckdb_prepared_statement statement)
                                {
                  duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str());
                  duckdb_bind_null(statement, 2);
                  const std::string metadata = project::utils::json_to_text(json::object());
                  const std::string workflow = project::utils::json_to_text(json::array());
                  duckdb_bind_varchar(statement, 3, metadata.c_str());
                  duckdb_bind_varchar(statement, 4, workflow.c_str()); }, [](duckdb_result &) {});
    }

    PROJECT::PROJECT(std::shared_ptr<project::api::CONTEXT> ctx)
        : ctx_(std::move(ctx))
    {
      if (!ctx_ || ctx_->db_path.empty())
      {
        throw error::ERROR(error::ERROR_CODE::InvalidArgument, "Project context is not initialized");
      }
      if (ctx_->project_id.empty())
      {
        throw error::ERROR(error::ERROR_CODE::InvalidArgument, "Project context requires a project_id");
      }

      create_schema(ctx_);
      ensure_row_exists(ctx_);
    }

    PROJECT::~PROJECT()
    {
    }

    const std::string &PROJECT::db_path() const noexcept
    {
      return ctx_->db_path;
    }

    const std::string &PROJECT::project_id() const noexcept
    {
      return ctx_->project_id;
    }

    const std::shared_ptr<project::api::CONTEXT> &PROJECT::context() const noexcept
    {
      return ctx_;
    }

    project::api::PROJECT_ROW PROJECT::row() const
    {
      create_schema(ctx_);
      ensure_row_exists(ctx_);
      return read_row(ctx_);
    }

    void PROJECT::set_row(const project::api::PROJECT_ROW &row)
    {
      create_schema(ctx_);
      project::api::PROJECT_ROW value = row;
      if (value.project_id.empty())
      {
        value.project_id = ctx_->project_id;
      }
      if (value.project_id != ctx_->project_id)
      {
        throw error::ERROR(error::ERROR_CODE::InvalidArgument, "Project row id does not match the active project");
      }
      ensure_row_exists(ctx_);
      update_row(ctx_, value);
    }

    json PROJECT::metadata() const
    {
      create_schema(ctx_);
      return row().metadata;
    }

    std::string PROJECT::domain() const
    {
      create_schema(ctx_);
      return row().domain;
    }

    void PROJECT::set_metadata(const json &value)
    {
      create_schema(ctx_);
      project::api::PROJECT_ROW current = row();
      current.metadata = value;
      update_row(ctx_, current);
    }

    void PROJECT::set_domain(const std::string &value)
    {
      create_schema(ctx_);
      const std::string normalized = project::utils::normalize_domain(value);
      project::utils::validate_domain_code(normalized);
      project::db::ensure_database_domain_compatible(ctx_, normalized);
      project::api::PROJECT_ROW current = row();
      if (!current.domain.empty() && current.domain != normalized)
      {
        throw error::ERROR(error::ERROR_CODE::InvalidArgument,
                           "Project domain is already set to " + current.domain + " and cannot be changed to " + normalized);
      }
      current.domain = normalized;
      update_row(ctx_, current);
    }

    json PROJECT::workflow() const
    {
      create_schema(ctx_);
      return row().workflow;
    }

    void PROJECT::set_workflow(const json &value)
    {
      create_schema(ctx_);
      project::api::PROJECT_ROW current = row();
      current.workflow = value;
      update_row(ctx_, current);
    }

    void PROJECT::validate() const
    {
      create_schema(ctx_);
      validate_schema(ctx_);
      ensure_row_exists(ctx_);
      const project::api::PROJECT_ROW current = row();
      if (!current.domain.empty())
      {
        project::utils::validate_domain_code(current.domain);
        project::db::ensure_database_domain_compatible(ctx_, current.domain);
      }
    }

    void PROJECT::close()
    {
      return;
    }

    std::vector<std::string> PROJECT::list_tables() const
    {
      auto guard = project::db::connect(ctx_);
      duckdb_result result{};
      if (duckdb_query(guard.get(),
                       "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main' AND table_type = 'BASE TABLE' ORDER BY table_name",
                       &result) == DuckDBError)
      {
        std::string message = project::db::result_error(&result);
        duckdb_destroy_result(&result);
        throw error::ERROR(error::ERROR_CODE::DuckDB, std::string("list tables: ") + message);
      }
      project::db::RESULT_GUARD result_guard(&result);

      std::vector<std::string> tables;
      const idx_t count = duckdb_row_count(&result);
      tables.reserve(static_cast<std::size_t>(count));
      for (idx_t row = 0; row < count; ++row)
      {
        tables.push_back(project::db::result_varchar(&result, 0, row));
      }
      return tables;
    }

    std::vector<project::audit_trail::AUDIT_TRAIL_ROW> PROJECT::get_audit() const
    {
      auto guard = project::db::connect(ctx_);
      std::vector<project::audit_trail::AUDIT_TRAIL_ROW> out;
      project::db::run_prepared(guard.get(), "SELECT project_id, operation_type, object_type, operation_details, created_at FROM AUDIT_TRAIL WHERE project_id = ? ORDER BY created_at DESC", "query AUDIT_TRAIL", [&](duckdb_prepared_statement statement)
                                { duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str()); }, [&](duckdb_result &result)
                                { out = project::db::rows_from_result(&result, [&](idx_t row)
                                                                      {
                    project::audit_trail::AUDIT_TRAIL_ROW value;
                   value.project_id = project::db::result_varchar(&result, 0, row);
                   value.operation_type = project::db::result_varchar(&result, 1, row);
                   value.object_type = project::db::result_varchar(&result, 2, row);
                   value.operation_details = project::utils::json_from_text(project::db::result_varchar(&result, 3, row));
                   value.created_at = project::db::result_varchar(&result, 4, row);
                   return value; }); });
      return out;
    }

    std::size_t PROJECT::get_cache_size() const
    {
      auto guard = project::db::connect(ctx_);
      std::size_t out = 0;
      project::db::run_prepared(guard.get(), "SELECT COUNT(*) FROM CACHE WHERE project_id = ?", "query CACHE size", [&](duckdb_prepared_statement statement)
                                { duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str()); }, [&](duckdb_result &result)
                                {
                                  if (duckdb_row_count(&result) == 0)
                                  {
                                    return;
                                  }
                                  out = static_cast<std::size_t>(duckdb_value_int64(&result, 0, 0));
                                });
      return out;
    }

    project::cache::CACHE_TABLE PROJECT::get_cache() const
    {
      const project::cache::CACHE cache(ctx_);
      const auto rows = cache.all();
      project::cache::CACHE_TABLE out;
      out.project_id.reserve(rows.size());
      out.name.reserve(rows.size());
      out.description.reserve(rows.size());
      out.hash.reserve(rows.size());
      out.data.reserve(rows.size());
      out.created_at.reserve(rows.size());
      for (const auto &row : rows)
      {
        out.project_id.push_back(row.project_id);
        out.name.push_back(row.name);
        out.description.push_back(row.description);
        out.hash.push_back(row.hash);
        out.data.push_back(row.data);
        out.created_at.push_back(row.created_at);
      }
      return out;
    }

    void PROJECT::delete_cache(const std::string &name)
    {
      auto guard = project::db::connect(ctx_);
      if (name.empty())
      {
        project::db::run_prepared(guard.get(), "DELETE FROM CACHE WHERE project_id = ?", "delete CACHE rows", [&](duckdb_prepared_statement statement)
                                  { duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str()); }, [](duckdb_result &) {});
        return;
      }

      project::db::run_prepared(guard.get(), "DELETE FROM CACHE WHERE project_id = ? AND name = ?", "delete CACHE rows by name", [&](duckdb_prepared_statement statement)
                                {
                                  duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str());
                                  duckdb_bind_varchar(statement, 2, name.c_str());
                                }, [](duckdb_result &) {});
    }

    PROJECT *PROJECT::copy(std::string db_path, std::string project_id) const
    {
      if (db_path.empty())
      {
        throw error::ERROR(error::ERROR_CODE::InvalidArgument, "Project copy requires a database path");
      }
      if (project_id.empty())
      {
        throw error::ERROR(error::ERROR_CODE::InvalidArgument, "Project copy requires a project_id");
      }

      const auto source_path = project::utils::normalized_path(ctx_->db_path);
      const auto target_path = project::utils::normalized_path(db_path);
      if (source_path == target_path && project_id == ctx_->project_id)
      {
        throw error::ERROR(error::ERROR_CODE::InvalidArgument, "Project copy requires a different database path or project_id");
      }

      auto target = std::make_unique<PROJECT>(std::move(db_path), std::move(project_id));

      const project::api::PROJECT_ROW source_row = row();
      if (!source_row.domain.empty())
      {
        target->set_domain(source_row.domain);
      }
      target->set_metadata(source_row.metadata);
      target->set_workflow(source_row.workflow);

      // Use existing CACHE wrapper behavior by using the CACHE wrapper
      project::cache::CACHE source_cache(ctx_);
      project::cache::CACHE target_cache(target->ctx_);
      target_cache.clear();
      for (const auto &entry : source_cache.all())
      {
        project::cache::CACHE::ROW_TYPE copy = entry;
        copy.project_id = target->project_id();
        target_cache.put(copy);
      }

      // AUDIT_TRAIL implementation
      project::audit_trail::AUDIT_TRAIL source_audit(ctx_);
      project::audit_trail::AUDIT_TRAIL target_audit(target->ctx_);
      target_audit.clear();
      for (const auto &entry : source_audit.all())
      {
        target_audit.add(entry.operation_type, entry.object_type, entry.operation_details);
      }

      return target.release();
    }

  } // namespace api

} // namespace project

// end of project.cpp
