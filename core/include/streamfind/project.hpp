#pragma once

#include <filesystem>
#include <functional>
#include <limits>
#include <memory>
#include <optional>
#include <cstdint>
#include <stdexcept>
#include <variant>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

#include "streamfind/export.hpp"
/** @brief Public streamfind core Project, workflow, and method API. */
namespace streamfind {

/** @brief JSON value used by the public core API. */
using Json = nlohmann::json;

class Project;

/** @brief Primitive and container types supported by method parameters. */
enum class STREAMFIND_CORE_API ParameterType {
    string,
    integer,
    real,
    boolean,
    array,
    object,
    table,
};

/** @brief Documentation and validation rules for one table column. */
struct STREAMFIND_CORE_API TableColumnDefinition {
    /// Stable column name used in JSON and table lookups.
    std::string name;
    /// Human-readable column documentation.
    std::string description;
    /// Scalar type stored in the column.
    ParameterType type{ParameterType::string};
    /// Whether the column must be present in a value.
    bool required{true};

    /** @brief Export this column definition as JSON. */
    Json to_json() const;
    /** @brief Construct a column definition from JSON. */
    static TableColumnDefinition from_json(const Json &value);
};

/** @brief Ordered schema for a typed table parameter. */
struct STREAMFIND_CORE_API TableSchema {
    /// Columns in their documented and serialized order.
    std::vector<TableColumnDefinition> columns;

    /** @brief Export this table schema as JSON. */
    Json to_json() const;
    /** @brief Construct a table schema from JSON. */
    static TableSchema from_json(const Json &value);
};

/** @brief One typed, column-oriented table value. */
struct STREAMFIND_CORE_API TableColumn {
    /// Column name.
    std::string name;
    /// Type of every value in the column.
    ParameterType type{ParameterType::string};
    /// Homogeneous values for this column.
    std::variant<std::vector<std::string>, std::vector<std::int64_t>,
                 std::vector<double>, std::vector<bool>> values;
};

/** @brief Columnar table value accepted by table-typed method parameters. */
struct STREAMFIND_CORE_API Table {
    /// Columns with equal row counts.
    std::vector<TableColumn> columns;

    /** @brief Return the number of rows, or zero for an empty table. */
    std::size_t row_count() const;
    /** @brief Validate column names, types, lengths, and an optional schema. */
    void validate(const std::optional<TableSchema> &schema = std::nullopt) const;
    /** @brief Export the table using the public columnar JSON format. */
    Json to_json() const;
    /** @brief Parse and validate a columnar JSON table. */
    static Table from_json(const Json &value);
};

/** @brief Recursive type description for scalar, array, and table values. */
struct STREAMFIND_CORE_API TypeDescriptor {
    /// The value kind described by this object.
    ParameterType kind{ParameterType::string};
    /// Element type for an array descriptor.
    std::shared_ptr<TypeDescriptor> items;
    /// Optional column schema for a table descriptor.
    std::optional<TableSchema> table_schema;

    /** @brief Export this type, including array items or table columns, as JSON. */
    Json to_json() const;
    /** @brief Parse a recursive type description from JSON. */
    static TypeDescriptor from_json(const Json &value);
    /** @brief Validate a JSON value against this type description. */
    void validate(const Json &value) const;
};

/** @brief Documentation, defaults, and validation metadata for one parameter. */
struct STREAMFIND_CORE_API ParameterDefinition {
    /// Stable parameter name.
    std::string name;
    /// Documentation shown to users and generated UI.
    std::string description;
    /// Recursive type and table/array shape information.
    TypeDescriptor type;
    /// Default value applied when the parameter is omitted.
    Json default_value{nullptr};
    /// Whether a value is required when no default exists.
    bool required{false};
    /// Machine-readable validation constraints.
    Json constraints{Json::object()};
    /// UI hints that do not affect execution semantics.
    Json ui{Json::object()};

    /** @brief Export this parameter definition as JSON. */
    Json to_json() const;
    /** @brief Construct a parameter definition from JSON. */
    static ParameterDefinition from_json(const Json &value);
};

/** @brief Ordered definitions for all parameters accepted by a method. */
struct STREAMFIND_CORE_API ParameterSchema {
    /// Parameters in the order used for documentation and UI rendering.
    std::vector<ParameterDefinition> definitions;

    /** @brief Export the schema as a JSON array. */
    Json to_json() const;
    /** @brief Construct a schema from a JSON array. */
    static ParameterSchema from_json(const Json &value);
    /** @brief Apply defaults and validate supplied values. */
    Json resolve_and_validate(const Json &values) const;
};

/** @brief Runtime parameter values without documentation metadata. */
struct STREAMFIND_CORE_API ParameterValues {
    /// Runtime values only; definitions live in MethodDefinition.
    Json values{Json::object()};

    /** @brief Export the runtime values as a JSON object. */
    Json to_json() const;
    /** @brief Parse runtime values from a JSON object. */
    static ParameterValues from_json(const Json &value);
};

/** @brief Complete documented and executable description of a method. */
struct STREAMFIND_CORE_API MethodDefinition {
    /// Stable registry and persisted workflow identifier.
    std::string id;
    /// Short display name.
    std::string name;
    /// Human-readable method documentation.
    std::string description;
    std::string version{"1"};
    std::string domain;
    std::vector<std::string> required_methods;
    double max_occurrences{std::numeric_limits<double>::infinity()};
    std::string developer;
    std::string contact;
    std::string link;
    std::string doi;
    ParameterSchema parameters;
    bool cacheable{false};
};

/** @brief Callback that executes a method against its owning Project. */
using MethodExecutor = std::function<Json(Project &, const Json &)>;
/** @brief Callback for method-specific and cross-parameter validation. */
using MethodValidator = std::function<void(const Json &)>;

/** @brief Executable method definition registered with a Project workflow. */
class STREAMFIND_CORE_API Method {
public:
    /** @brief Construct a method with execution and optional validation callbacks. */
    Method(MethodDefinition definition, MethodExecutor executor = {},
           MethodValidator validator = {});

    /** @brief Return immutable method metadata. */
    const MethodDefinition &definition() const noexcept;
    /** @brief Export method metadata and its parameter schema as JSON. */
    Json to_json() const;
    /** @brief Parse method metadata without an executable callback. */
    static MethodDefinition definition_from_json(const Json &value);
    /** @brief Run the method-specific validator for supplied values. */
    void validate_parameters(const Json &value) const;
    /** @brief Apply defaults and validate values against the method schema. */
    Json resolve_parameters(const Json &value) const;
    /** @brief Execute the method against a Project. */
    Json run(Project &project, const Json &parameters) const;

private:
    MethodDefinition definition_;
    MethodExecutor executor_;
    MethodValidator validator_;
};

/** @brief Registry of executable methods addressed by stable method id. */
class STREAMFIND_CORE_API MethodRegistry {
public:
    /** @brief Register a method; duplicate ids are rejected. */
    void register_method(Method method);
    /** @brief Find a method by id, or return nullptr. */
    const Method *find(const std::string &id) const noexcept;
    /** @brief Return metadata for all registered methods. */
    std::vector<MethodDefinition> list() const;

private:
    std::vector<Method> methods_;
};

/** @brief Return the process-wide default method registry. */
STREAMFIND_CORE_API MethodRegistry &methods();

/** @brief One ordered method invocation in a workflow. */
struct STREAMFIND_CORE_API WorkflowStep {
    /// Registered method identifier.
    std::string method;
    /// Values passed to that method.
    ParameterValues parameters;

    /** @brief Export the step method id and values as JSON. */
    Json to_json() const;
    /** @brief Parse a workflow step from JSON. */
    static WorkflowStep from_json(const Json &value);
};

/** @brief Ordered, versioned method workflow owned by a Project. */
class STREAMFIND_CORE_API Workflow {
public:
    /// Display name of the workflow.
    std::string name;
    /// Incremented whenever a Project stores a new workflow definition.
    int version{1};
    /// Domain this workflow belongs to.
    std::string domain;
    /// Ordered method invocations.
    std::vector<WorkflowStep> steps;

    /** @brief Validate method ids, ordering, domains, occurrences, and values. */
    void validate(const MethodRegistry &registry) const;
    /** @brief Export the workflow definition as JSON. */
    Json to_json() const;
    /** @brief Parse a workflow object or legacy ordered array from JSON. */
    static Workflow from_json(const Json &value);
};

/** @brief Categories raised by Project and workflow operations. */
enum class STREAMFIND_CORE_API ErrorCode {
    InvalidArgument,
    ProjectNotFound,
    ProjectAlreadyExists,
    SchemaMismatch,
    DatabaseError,
    WorkflowValidation,
    MethodExecution,
};

/** @brief Typed exception raised by the streamfind core API. */
class STREAMFIND_CORE_API Error : public std::runtime_error {
public:
    /** @brief Construct an error with a stable category and message. */
    Error(ErrorCode code, std::string message);
    /** @brief Return the stable error category. */
    ErrorCode code() const noexcept;

private:
    ErrorCode code_;
};

/** @brief Options used when creating or opening a Project database. */
struct STREAMFIND_CORE_API ProjectOptions {
    /// DuckDB file to create or open.
    std::filesystem::path database_path;
    /// Logical project row selected in the database.
    std::string project_id;
    /// Optional creation profile identifier.
    std::optional<std::string> profile_id;
    bool create_if_missing{false};
    bool read_only{false};
    /// Domain assigned once when a project is created.
    std::string domain;
};

/** @brief Persisted identity and metadata for an open Project. */
struct STREAMFIND_CORE_API ProjectInfo {
    /// Logical project identifier.
    std::string id;
    /// Domain selected for the project.
    std::string domain;
    /// Project-owned metadata.
    Json metadata{Json::object()};
    int schema_version{1};
    std::string framework_version;
    std::string created_at;
};

/** @brief One serialized entry in the Project CACHE table. */
struct STREAMFIND_CORE_API CacheEntry {
    /// Cache operation/name label.
    std::string name;
    /// Human-readable cache description.
    std::string description;
    /// Deterministic cache key.
    std::string hash;
    std::vector<std::uint8_t> data;
    std::string created_at;
};

/** @brief One processing event from the Project AUDIT_TRAIL table. */
struct STREAMFIND_CORE_API AuditEntry {
    /// Event operation, such as `start`, `complete`, or `cache_hit`.
    std::string operation_type;
    /// Audited object category.
    std::string object_type;
    /// Structured event details.
    Json details{Json::object()};
    std::string created_at;
};

/** @brief RAII handle for a DuckDB-backed streamfind Project. */
class STREAMFIND_CORE_API Project {
public:
    /** @internal Implementation state shared by the Project handle. */
    struct Impl;
    /** @internal Construct from initialized implementation state. */
    explicit Project(std::shared_ptr<Impl> impl);

    /** @brief Create a new Project database and project row. */
    static Project create(const ProjectOptions &options);
    /** @brief Open an existing Project database. */
    static Project open(const ProjectOptions &options);

    Project(Project &&) noexcept;
    Project &operator=(Project &&) noexcept;
    ~Project();
    Project(const Project &) = delete;
    Project &operator=(const Project &) = delete;

    /** @brief Return the current Project identity and metadata. */
    const ProjectInfo &info() const;
    /** @brief Return a copy of the project metadata. */
    Json get_metadata() const;
    /** @brief Return the backing DuckDB path. */
    const std::filesystem::path &database_path() const noexcept;
    /** @brief Return the backing DuckDB path. */
    const std::filesystem::path &get_database_path() const noexcept;
    /** @brief Return the logical project id. */
    const std::string &id() const noexcept;
    /** @brief Return the logical project id. */
    const std::string &get_project_id() const noexcept;
    /** @brief Replace project metadata. */
    void set_metadata(Json metadata);
    /** @brief Return the project domain. */
    std::string get_domain() const;
    /** @brief Validate the project schema and persisted row state. */
    void validate() const;
    /** @brief Load the persisted workflow. */
    Workflow workflow() const;
    /** @brief Validate and persist a new workflow version. */
    void update_workflow(Workflow workflow, const MethodRegistry &registry = methods());
    /** @brief Return the persisted workflow. */
    Workflow get_workflow() const;
    /** @brief Persist a workflow using the supplied method registry. */
    void set_workflow(Workflow workflow, const MethodRegistry &registry = methods());
    /** @brief Copy this project to a new database and project id. */
    Project copy(const ProjectOptions &options) const;
    /** @brief List tables visible in the project database. */
    std::vector<std::string> list_tables() const;

    /** @brief Return all cache entries for this project. */
    std::vector<CacheEntry> cache() const;
    /** @brief Return all cache entries for this project. */
    std::vector<CacheEntry> get_cache() const;
    /** @brief Return the number of cache entries for this project. */
    std::size_t get_cache_size() const;
    /** @brief Find a cache entry by deterministic hash. */
    std::optional<CacheEntry> cache_get(const std::string &hash) const;
    /** @brief Insert or replace a JSON value in the project cache. */
    void cache_put(std::string name, std::string description,
                   std::string hash, const Json &value);
    /** @brief Clear all cache entries or entries with a matching name. */
    void clear_cache(const std::optional<std::string> &name = std::nullopt);
    /** @brief Delete all cache entries for this project. */
    void delete_cache();
    /** @brief Return processing and cache audit events in time order. */
    std::vector<AuditEntry> audit_trail() const;
    /** @brief Return processing and cache audit events in time order. */
    std::vector<AuditEntry> get_audit_trail() const;

    /** @brief Execute the persisted workflow using a method registry. */
    Json execute(const MethodRegistry &registry = methods());
    /** @brief Execute one registered method with supplied parameters. */
    Json run_method(const std::string &method_id, const Json &parameters,
                    const MethodRegistry &registry = methods());
    /** @brief Mark the Project closed; subsequent operations fail. */
    void close() noexcept;

private:
    std::shared_ptr<Impl> impl_;
};

}
