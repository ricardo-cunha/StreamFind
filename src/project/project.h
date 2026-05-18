#pragma once

#include <memory>
#include <optional>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>
#include <algorithm>
#include <cctype>
#include <cstdint>
#include <filesystem>
#include <sstream>
#include <functional>
#include <iomanip>
#include <type_traits>

#include <duckdb.h>
#include <../external/nlohmann/json.hpp>

namespace project
{
  using json = nlohmann::json;

  namespace api { struct CONTEXT; }
  namespace audit_trail { struct AUDIT_TRAIL_ROW; }
  namespace cache { struct CACHE_TABLE; }

  namespace error
  {

    /** Error categories used by the project layer. */
    enum class ERROR_CODE
    {
      DuckDB,
      InvalidArgument,
      SchemaMismatch,
      NotFound,
      Io,
      Unknown
    };

    /** Exception type thrown by project operations. */
    class ERROR : public std::runtime_error
    {
    public:
      /** Create an error with a category and message. */
      ERROR(ERROR_CODE code, std::string message);
      /** Return the error category. */
      ERROR_CODE code() const noexcept;
      /** Convert an ERROR_CODE to a short string. */
      static std::string error_code_to_string(ERROR_CODE code);

    private:
      ERROR_CODE code_;
    };
  } // namespace error

  namespace db
  {

    struct COLUMN_SPEC
    {
      const char *name;
      const char *type;
      bool not_null;
    };

    struct COLUMN_INFO
    {
      std::string name;
      std::string type;
      bool not_null;
    };

    struct CONNECTION_GUARD
    {
      explicit CONNECTION_GUARD(const std::shared_ptr<project::api::CONTEXT> &ctx);

      ~CONNECTION_GUARD();

      CONNECTION_GUARD(const CONNECTION_GUARD &) = delete;
      CONNECTION_GUARD &operator=(const CONNECTION_GUARD &) = delete;

      CONNECTION_GUARD(CONNECTION_GUARD &&other) noexcept;

      CONNECTION_GUARD &operator=(CONNECTION_GUARD &&other) noexcept;

      duckdb_connection get() const noexcept;

    private:
      duckdb_database db_ = nullptr;
      duckdb_connection con_ = nullptr;
    };

    struct RESULT_GUARD
    {
      explicit RESULT_GUARD(duckdb_result *result);
      ~RESULT_GUARD();

      RESULT_GUARD(const RESULT_GUARD &) = delete;
      RESULT_GUARD &operator=(const RESULT_GUARD &) = delete;

      RESULT_GUARD(RESULT_GUARD &&other) noexcept;

      RESULT_GUARD &operator=(RESULT_GUARD &&other) noexcept;

    private:
      duckdb_result *result_;
    };

    struct PREPARE_GUARD
    {
      explicit PREPARE_GUARD(duckdb_prepared_statement *statement);
      ~PREPARE_GUARD();

      PREPARE_GUARD(const PREPARE_GUARD &) = delete;
      PREPARE_GUARD &operator=(const PREPARE_GUARD &) = delete;

      PREPARE_GUARD(PREPARE_GUARD &&other) noexcept;

      PREPARE_GUARD &operator=(PREPARE_GUARD &&other) noexcept;

    private:
      duckdb_prepared_statement *statement_;
    };

    std::string result_error(duckdb_result *result);

    std::string result_varchar(duckdb_result *result, idx_t col, idx_t row);

    std::vector<std::uint8_t> result_blob(duckdb_result *result, idx_t col, idx_t row);

    void bind_optional_varchar(duckdb_prepared_statement statement, idx_t index, const std::string &value);

    template <typename Reader>
    auto rows_from_result(duckdb_result *result, Reader &&reader)
    {
      using RowT = decltype(reader(idx_t{}));
      const idx_t count = duckdb_row_count(result);
      std::vector<RowT> rows;
      rows.reserve(static_cast<std::size_t>(count));
      for (idx_t row = 0; row < count; ++row)
      {
        rows.push_back(reader(row));
      }
      return rows;
    }

    template <typename Binder, typename Consumer>
    inline void run_prepared(duckdb_connection con,
                             const std::string &sql,
                             const char *context,
                             Binder &&binder,
                             Consumer &&consumer)
    {
      duckdb_prepared_statement statement = nullptr;
      if (duckdb_prepare(con, sql.c_str(), &statement) == DuckDBError)
      {
        std::string message = statement ? duckdb_prepare_error(statement) : std::string("prepare failed");
        if (statement)
        {
          duckdb_destroy_prepare(&statement);
        }
        throw error::ERROR(error::ERROR_CODE::DuckDB, std::string(context) + ": " + message);
      }

      PREPARE_GUARD statement_guard(&statement);
      binder(statement);

      duckdb_result result{};
      if (duckdb_execute_prepared(statement, &result) == DuckDBError)
      {
        std::string message = result_error(&result);
        duckdb_destroy_result(&result);
        throw error::ERROR(error::ERROR_CODE::DuckDB, std::string(context) + ": " + message);
      }

      RESULT_GUARD result_guard(&result);
      consumer(result);
    }

    void run_sql(duckdb_connection con, const std::string &sql, const char *context);

    void validate_columns(duckdb_connection con,
                          const char *table_name,
                          const std::vector<COLUMN_SPEC> &expected);

    std::vector<COLUMN_INFO> table_columns(duckdb_connection con, const char *table_name);

    void validate_columns_present(duckdb_connection con,
                                  const char *table_name,
                                  const std::vector<COLUMN_SPEC> &expected);

    std::string placeholders(std::size_t count);

    double nullable_double(double value);

    int nullable_int(int value);

  } // namespace db

  namespace utils
  {

    std::string upper_copy(std::string value);

    bool same_text(const std::string &lhs, const char *rhs);

    std::string json_to_text(const json &value);

    json json_from_text(const std::string &value);

    std::filesystem::path normalized_path(const std::string &value);

    std::string normalize_domain(std::string value);

    void validate_domain_code(const std::string &value);

    template <typename T>
    inline std::vector<std::uint8_t> serialize_object(const T &value)
    {
      std::ostringstream oss;
      oss << value;
      if (!oss)
      {
        throw error::ERROR(error::ERROR_CODE::Unknown, "Failed to serialize cached object");
      }
      const std::string payload = oss.str();
      return std::vector<std::uint8_t>(payload.begin(), payload.end());
    }

    template <typename T>
    inline T deserialize_object(const std::vector<std::uint8_t> &bytes)
    {
      std::string payload(bytes.begin(), bytes.end());
      std::istringstream iss(payload);
      T value{};
      iss >> value;
      if (!iss)
      {
        throw error::ERROR(error::ERROR_CODE::Unknown, "Failed to deserialize cached object");
      }
      return value;
    }

  } // namespace utils

  namespace api
  {
    /** Shared project state for an open DuckDB-backed project. */
    struct CONTEXT
    {
      /** Absolute path to the DuckDB file. */
      std::string db_path;
      /** Active project identifier within the database. */
      std::string project_id;
    };

    /** Common base row fields shared by project-scoped tables. */
    struct ROW
    {
      /** Primary key for the owning project. */
      std::string project_id;
      /** Creation time stored by DuckDB. */
      std::string created_at;
    };

    /** Row representation of the `PROJECT` table, extending Row with JSON columns. */
    struct PROJECT_ROW : public ROW
    {
      /** Domain code stored for this project, such as MS or RAMAN. */
      std::string domain;
      /** Project metadata stored as JSON. */
      json metadata;
      /** Project workflow stored as JSON. */
      json workflow;
    };

    /** Minimal base class for typed table wrappers. */
    template <typename RowT>
    class TABLE_BASE
    {
    public:
      using ROW_TYPE = RowT;

      virtual ~TABLE_BASE() = default;

      /** Return all rows in the table. */
      virtual std::vector<ROW_TYPE> all() const = 0;

      /** Return the table as JSON. */
      json json_all() const { return all(); }
      /** Return the row count. */
      std::size_t size() const { return all().size(); }
      /** Return true when the table has no rows. */
      bool empty() const { return size() == 0; }

    protected:
      /** Store the shared project context. */
      explicit TABLE_BASE(std::shared_ptr<CONTEXT> ctx) : ctx_(std::move(ctx)) {}

      /** Access the shared project context. */
      const std::shared_ptr<CONTEXT> &context() const noexcept { return ctx_; }

      std::shared_ptr<CONTEXT> ctx_;
    };

      // Helper to call project functions from non-R contexts. This converts
      // project::error::ERROR into std::runtime_error so callers (including
      // Rcpp) can translate errors at their boundary.
      template <typename Fn>
      inline auto project_call(Fn &&fn)
      {
        try
        {
          return fn();
        }
        catch (const project::error::ERROR &e)
        {
          throw std::runtime_error(std::string("Project error [") + std::to_string(static_cast<int>(e.code())) + "]: " + e.what());
        }
        catch (const std::exception &)
        {
          throw;
        }
      }

    /** Open and manage a single DuckDB-backed StreamFind project. */
    class PROJECT
    {
    public:
      /** Open or create a project database for the given project id. */
      explicit PROJECT(std::string db_path, std::string project_id);
      /** Close the database handle and release owned table wrappers. */
      ~PROJECT();

      PROJECT(const PROJECT &) = delete;
      PROJECT &operator=(const PROJECT &) = delete;
      PROJECT(PROJECT &&) = delete;
      PROJECT &operator=(PROJECT &&) = delete;

      /** Return the database file path. */
      const std::string &db_path() const noexcept;
      /** Return the active project id. */
      const std::string &project_id() const noexcept;
      /** Return the shared context used by project-scoped wrappers. */
      const std::shared_ptr<api::CONTEXT> &context() const noexcept;

      /** Load the current project row. */
      api::PROJECT_ROW row() const;
      /** Replace the current project row. */
      void set_row(const api::PROJECT_ROW &row);

      /** Return the project metadata JSON. */
      json metadata() const;
      /** Return the project domain code. */
      std::string domain() const;
      /** Replace the project metadata JSON. */
      void set_metadata(const json &value);
      /** Set the project domain code. */
      void set_domain(const std::string &value);

      /** Return the project workflow JSON. */
      json workflow() const;
      /** Replace the project workflow JSON. */
      void set_workflow(const json &value);

      /** Validate schema and ensure the project row exists. */
      void validate() const;
      /** List tables present in the database. */
      std::vector<std::string> list_tables() const;

      /** Return audit rows for the active project. */
      std::vector<audit_trail::AUDIT_TRAIL_ROW> get_audit() const;
      /** Return the number of cache rows for the active project. */
      std::size_t get_cache_size() const;
      /** Return all cache rows for the active project. */
      cache::CACHE_TABLE get_cache() const;
      /** Delete all cache rows, or only rows with a matching name. */
      void delete_cache(const std::string &name = std::string());

      /** Copy the project into another database and/or project id. */
      PROJECT *copy(std::string db_path, std::string project_id) const;

    private:
      /** Create the PROJECT table schema if needed. */
      static void create_schema(const std::shared_ptr<api::CONTEXT> &ctx);
      /** Validate the PROJECT table schema. */
      static void validate_schema(const std::shared_ptr<api::CONTEXT> &ctx);
      /** Insert a default project row when none exists. */
      static void ensure_row_exists(const std::shared_ptr<api::CONTEXT> &ctx);
      /** Read the current project row. */
      static api::PROJECT_ROW read_row(const std::shared_ptr<api::CONTEXT> &ctx);
      /** Persist an updated project row. */
      static void update_row(const std::shared_ptr<api::CONTEXT> &ctx, const api::PROJECT_ROW &row);

      std::shared_ptr<api::CONTEXT> ctx_;
    };

  } // namespace api

  using PROJECT = api::PROJECT;

  namespace cache
  {
    struct BINARY_READER
    {
      explicit BINARY_READER(const std::vector<std::uint8_t> &bytes);

      void read_bytes(void *destination, std::size_t count);

      [[nodiscard]] bool empty() const noexcept;

      [[nodiscard]] std::size_t remaining() const noexcept;

    private:
      const std::vector<std::uint8_t> &bytes_;
      std::size_t offset_ = 0;
    };

    void append_bytes(std::vector<std::uint8_t> &out,
                      const void *data,
                      std::size_t count);

    void write_string(std::vector<std::uint8_t> &out,
                      const std::string &value);

    std::string read_string(BINARY_READER &reader);

    void write_vector(std::vector<std::uint8_t> &out,
                      const std::vector<std::string> &values);

    void read_vector(BINARY_READER &reader,
                     std::vector<std::string> &values);

    void write_vector(std::vector<std::uint8_t> &out,
                      const std::vector<float> &values);

    void read_vector(BINARY_READER &reader,
                     std::vector<float> &values);

    void write_vector(std::vector<std::uint8_t> &out,
                      const std::vector<double> &values);

    void read_vector(BINARY_READER &reader,
                     std::vector<double> &values);

    void write_vector(std::vector<std::uint8_t> &out,
                      const std::vector<bool> &values);

    void read_vector(BINARY_READER &reader,
                     std::vector<bool> &values);

    template <typename T>
    inline std::enable_if_t<std::is_arithmetic_v<T> && !std::is_same_v<T, bool>, void>
    write_scalar(std::vector<std::uint8_t> &out, const T &value)
    {
      append_bytes(out, &value, sizeof(T));
    }

    template <typename T>
    inline std::enable_if_t<std::is_arithmetic_v<T> && !std::is_same_v<T, bool>, T>
    read_scalar(BINARY_READER &reader)
    {
      T value{};
      reader.read_bytes(&value, sizeof(T));
      return value;
    }

    template <typename T>
    inline std::enable_if_t<std::is_integral_v<T> && !std::is_same_v<T, bool>, void>
    write_vector(std::vector<std::uint8_t> &out,
                 const std::vector<T> &values)
    {
      write_scalar<std::uint64_t>(out, static_cast<std::uint64_t>(values.size()));
      if (values.empty())
      {
        return;
      }
      append_bytes(out, values.data(), values.size() * sizeof(T));
    }

    template <typename T>
    inline std::enable_if_t<std::is_integral_v<T> && !std::is_same_v<T, bool>, void>
    read_vector(BINARY_READER &reader,
                std::vector<T> &values)
    {
      const std::uint64_t count = read_scalar<std::uint64_t>(reader);
      values.resize(static_cast<std::size_t>(count));
      if (values.empty())
      {
        return;
      }
      reader.read_bytes(values.data(), values.size() * sizeof(T));
    }

    // CACHE row and wrapper declarations
    struct CACHE_ROW : public project::api::ROW
    {
      std::string name;
      std::string description;
      std::string hash;
      std::vector<std::uint8_t> data;
    };

    struct CACHE_TABLE
    {
      std::vector<std::string> project_id;
      std::vector<std::string> name;
      std::vector<std::string> description;
      std::vector<std::string> hash;
      std::vector<std::vector<std::uint8_t>> data;
      std::vector<std::string> created_at;
    };

    class CACHE : public project::api::TABLE_BASE<CACHE_ROW>
    {
    public:
      using ROW_TYPE = CACHE_ROW;

      explicit CACHE(std::shared_ptr<project::api::CONTEXT> ctx);

      static void create_schema(const std::shared_ptr<project::api::CONTEXT> &ctx);
      static void validate_schema(const std::shared_ptr<project::api::CONTEXT> &ctx);

      std::vector<ROW_TYPE> all() const override;
      std::optional<ROW_TYPE> get(const std::string &hash) const;
      std::optional<ROW_TYPE> get(duckdb_connection con, const std::string &hash) const;
      std::optional<std::vector<std::uint8_t>> get_bytes(const std::string &hash) const;
      std::optional<std::vector<std::uint8_t>> get_bytes(duckdb_connection con, const std::string &hash) const;
      void put(const ROW_TYPE &row);
      void put(const std::string &name,
               const std::string &hash,
               const std::string &description,
               const std::vector<std::uint8_t> &data);
      void put(duckdb_connection con,
           const std::string &name,
           const std::string &hash,
           const std::string &description,
           const std::vector<std::uint8_t> &data);
      template <typename T>
      void put_object(const std::string &name,
                      const std::string &hash,
                      const std::string &description,
                      const T &value)
      {
        std::vector<std::uint8_t> bytes = value.serialize_object();
        put(name, hash, description, bytes);
      }
      template <typename T>
      void put_object(duckdb_connection con,
                      const std::string &name,
                      const std::string &hash,
                      const std::string &description,
                      const T &value)
      {
        std::vector<std::uint8_t> bytes = value.serialize_object();
        put(con, name, hash, description, bytes);
      }
      template <typename T>
      std::optional<T> get_object(const std::string &hash) const
      {
        auto bytes = get_bytes(hash);
        if (!bytes || bytes->empty())
        {
          return std::nullopt;
        }

        return T::deserialize_object(*bytes);
      }
      template <typename T>
      std::optional<T> get_object(duckdb_connection con, const std::string &hash) const
      {
        auto bytes = get_bytes(con, hash);
        if (!bytes || bytes->empty())
        {
          return std::nullopt;
        }

        return T::deserialize_object(*bytes);
      }
      void remove(const std::string &hash);
      void clear();

    private:
      static constexpr const char *table_name() { return "CACHE"; }
    };
  } // namespace cache

  namespace audit_trail
  {
    // AUDIT_TRAIL declarations
    struct AUDIT_TRAIL_ROW : public project::api::ROW
    {
      std::string operation_type;
      std::string object_type;
      json operation_details = json::object();
      std::string created_at;
    };

    void to_json(json &j, const AUDIT_TRAIL_ROW &x);
    void from_json(const json &j, AUDIT_TRAIL_ROW &x);

    class AUDIT_TRAIL : public project::api::TABLE_BASE<AUDIT_TRAIL_ROW>
    {
    public:
      using ROW_TYPE = AUDIT_TRAIL_ROW;

      explicit AUDIT_TRAIL(std::shared_ptr<project::api::CONTEXT> ctx);

      static void create_schema(const std::shared_ptr<project::api::CONTEXT> &ctx);
      static void validate_schema(const std::shared_ptr<project::api::CONTEXT> &ctx);

      std::vector<ROW_TYPE> all() const override;
      void add(const std::string &operation_type,
               const std::string &object_type,
               const json &details = json::object());
      void clear();

    private:
      static constexpr const char *table_name() { return "AUDIT_TRAIL"; }
    };
  } // namespace audit_trail
} // namespace project
