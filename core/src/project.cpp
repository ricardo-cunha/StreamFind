/**
 * @file project.cpp
 * @brief Project persistence, method metadata, workflow execution, and cache storage.
 */

#include "streamfind/project.hpp"

#include <algorithm>
#include <chrono>
#include <fstream>
#include <iomanip>
#include <mutex>
#include <sstream>
#include <stdexcept>
#include <unordered_map>

#include <duckdb.h>

namespace streamfind {
namespace detail {

using Statement = duckdb_prepared_statement;

std::string db_error(duckdb_result &result) {
    const char *message = duckdb_result_error(&result);
    return message ? message : "DuckDB operation failed";
}

void check(duckdb_state state, const std::string &context) {
    if (state == DuckDBError) {
        throw Error(ErrorCode::DatabaseError, context);
    }
}

class ResultGuard {
public:
    explicit ResultGuard(duckdb_result &result) : result_(result) {}
    ~ResultGuard() { duckdb_destroy_result(&result_); }
    ResultGuard(const ResultGuard &) = delete;
    ResultGuard &operator=(const ResultGuard &) = delete;

private:
    duckdb_result &result_;
};

class StatementGuard {
public:
    explicit StatementGuard(Statement statement) : statement_(statement) {}
    ~StatementGuard() {
        if (statement_) duckdb_destroy_prepare(&statement_);
    }
    StatementGuard(const StatementGuard &) = delete;
    StatementGuard &operator=(const StatementGuard &) = delete;

private:
    Statement statement_;
};

void query(duckdb_connection connection, const std::string &sql,
           const std::string &context) {
    duckdb_result result{};
    if (duckdb_query(connection, sql.c_str(), &result) == DuckDBError) {
        const std::string message = context + ": " + db_error(result);
        duckdb_destroy_result(&result);
        throw Error(ErrorCode::DatabaseError, message);
    }
    duckdb_destroy_result(&result);
}

template <typename Bind, typename Read>
void prepared(duckdb_connection connection, const std::string &sql,
              const std::string &context, Bind bind, Read read) {
    Statement statement = nullptr;
    if (duckdb_prepare(connection, sql.c_str(), &statement) == DuckDBError) {
        const char *message = statement ? duckdb_prepare_error(statement) : nullptr;
        const std::string error = context + ": " + (message ? message : "prepare failed");
        if (statement) duckdb_destroy_prepare(&statement);
        throw Error(ErrorCode::DatabaseError, error);
    }
    StatementGuard statement_guard(statement);
    bind(statement);
    duckdb_result result{};
    if (duckdb_execute_prepared(statement, &result) == DuckDBError) {
        const std::string message = context + ": " + db_error(result);
        duckdb_destroy_result(&result);
        throw Error(ErrorCode::DatabaseError, message);
    }
    ResultGuard result_guard(result);
    read(result);
}

std::string value_string(duckdb_result &result, idx_t column, idx_t row) {
    char *value = duckdb_value_varchar(&result, column, row);
    if (!value) return {};
    std::string output(value);
    duckdb_free(value);
    return output;
}

Json parse_json(const std::string &value, const char *context) {
    if (value.empty()) return Json::object();
    try {
        return Json::parse(value);
    } catch (const std::exception &error) {
        throw Error(ErrorCode::SchemaMismatch,
                    std::string(context) + ": invalid JSON: " + error.what());
    }
}

std::string json_text(const Json &value) {
    return value.is_null() ? "null" : value.dump();
}

std::string hash_text(const std::string &value) {
    std::uint64_t hash = 1469598103934665603ULL;
    for (unsigned char byte : value) {
        hash ^= byte;
        hash *= 1099511628211ULL;
    }
    std::ostringstream output;
    output << std::hex << std::setfill('0') << std::setw(16) << hash;
    return output.str();
}

void bind_text(Statement statement, idx_t index, const std::string &value) {
    duckdb_bind_varchar(statement, index, value.c_str());
}

bool has_column(duckdb_connection connection, const char *table, const char *column) {
    Statement statement = nullptr;
    const std::string sql = "SELECT 1 FROM information_schema.columns WHERE table_name = ? AND column_name = ? LIMIT 1";
    if (duckdb_prepare(connection, sql.c_str(), &statement) == DuckDBError) {
        if (statement) duckdb_destroy_prepare(&statement);
        throw Error(ErrorCode::DatabaseError, "inspect schema");
    }
    StatementGuard guard(statement);
    bind_text(statement, 1, table);
    bind_text(statement, 2, column);
    duckdb_result result{};
    if (duckdb_execute_prepared(statement, &result) == DuckDBError) {
        const std::string message = db_error(result);
        duckdb_destroy_result(&result);
        throw Error(ErrorCode::DatabaseError, "inspect schema: " + message);
    }
    ResultGuard result_guard(result);
    return duckdb_row_count(&result) != 0;
}

void ensure_schema(duckdb_connection connection,
                   const ProjectOptions &options) {
    query(connection,
          "CREATE TABLE IF NOT EXISTS PROJECT (project_id VARCHAR NOT NULL PRIMARY KEY, domain VARCHAR, metadata JSON, workflow JSON, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, schema_version INTEGER NOT NULL DEFAULT 1, framework_version VARCHAR NOT NULL DEFAULT '0.1.0')",
          "create PROJECT table");
    if (!has_column(connection, "PROJECT", "schema_version")) {
        query(connection, "ALTER TABLE PROJECT ADD COLUMN schema_version INTEGER DEFAULT 1", "upgrade PROJECT schema");
    }
    if (!has_column(connection, "PROJECT", "framework_version")) {
        query(connection, "ALTER TABLE PROJECT ADD COLUMN framework_version VARCHAR DEFAULT '0.1.0'", "upgrade PROJECT schema");
    }
    query(connection,
          "CREATE TABLE IF NOT EXISTS CACHE (project_id VARCHAR NOT NULL, name VARCHAR NOT NULL, description VARCHAR NOT NULL, hash VARCHAR NOT NULL, data BLOB NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(project_id, hash))",
          "create CACHE table");
    query(connection,
          "CREATE TABLE IF NOT EXISTS AUDIT_TRAIL (project_id VARCHAR NOT NULL, operation_type VARCHAR NOT NULL, object_type VARCHAR NOT NULL, operation_details JSON, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)",
          "create AUDIT_TRAIL table");
}

std::string now_string() {
    return "current";
}

const char *parameter_type_name(ParameterType type) {
    switch (type) {
    case ParameterType::string: return "string";
    case ParameterType::integer: return "integer";
    case ParameterType::real: return "real";
    case ParameterType::boolean: return "boolean";
    case ParameterType::array: return "array";
    case ParameterType::object: return "object";
    case ParameterType::table: return "table";
    }
    return "unknown";
}

ParameterType parameter_type_from_name(const std::string &name) {
    if (name == "string") return ParameterType::string;
    if (name == "integer") return ParameterType::integer;
    if (name == "real") return ParameterType::real;
    if (name == "boolean") return ParameterType::boolean;
    if (name == "array") return ParameterType::array;
    if (name == "object") return ParameterType::object;
    if (name == "table") return ParameterType::table;
    throw Error(ErrorCode::InvalidArgument, "Unknown parameter type: " + name);
}

bool parameter_type_matches(ParameterType type, const Json &value) {
    switch (type) {
    case ParameterType::string: return value.is_string();
    case ParameterType::integer: return value.is_number_integer();
    case ParameterType::real: return value.is_number();
    case ParameterType::boolean: return value.is_boolean();
    case ParameterType::array: return value.is_array();
    case ParameterType::object: return value.is_object();
    case ParameterType::table: return value.is_object() && value.contains("columns");
    }
    return false;
}

} // namespace detail

using namespace detail;

Error::Error(ErrorCode code, std::string message)
    : std::runtime_error(std::move(message)), code_(code) {}

ErrorCode Error::code() const noexcept { return code_; }

void CancellationToken::cancel() noexcept { cancelled_.store(true); }
bool CancellationToken::is_cancelled() const noexcept { return cancelled_.load(); }

Json ExecutionResult::to_json() const {
    return {{"results", results}, {"cancelled", cancelled}};
}

Json TableColumnDefinition::to_json() const {
    return {{"name", name}, {"description", description},
            {"type", detail::parameter_type_name(type)}, {"required", required}};
}

TableColumnDefinition TableColumnDefinition::from_json(const Json &value) {
    if (!value.is_object() || !value.contains("name") || !value.contains("type")) {
        throw Error(ErrorCode::InvalidArgument, "Table column requires name and type");
    }
    return {value.at("name").get<std::string>(), value.value("description", ""),
            detail::parameter_type_from_name(value.at("type").get<std::string>()),
            value.value("required", true)};
}

Json TableSchema::to_json() const {
    Json output = Json::array();
    for (const auto &column : columns) output.push_back(column.to_json());
    return output;
}

TableSchema TableSchema::from_json(const Json &value) {
    if (!value.is_array()) throw Error(ErrorCode::InvalidArgument, "Table schema must be an array");
    TableSchema schema;
    for (const auto &column : value) schema.columns.push_back(TableColumnDefinition::from_json(column));
    return schema;
}

std::size_t Table::row_count() const {
    if (columns.empty()) return 0;
    return std::visit([](const auto &values) { return values.size(); }, columns.front().values);
}

void Table::validate(const std::optional<TableSchema> &schema) const {
    std::size_t rows = 0;
    bool first = true;
    for (const auto &column : columns) {
        if (column.name.empty()) throw Error(ErrorCode::WorkflowValidation, "Table column name must not be empty");
        const std::size_t length = std::visit([](const auto &values) { return values.size(); }, column.values);
        if (first) { rows = length; first = false; }
        if (length != rows) throw Error(ErrorCode::WorkflowValidation, "Table columns must have equal lengths");
        if (schema) {
            const auto it = std::find_if(schema->columns.begin(), schema->columns.end(),
                                         [&](const auto &definition) { return definition.name == column.name; });
            if (it == schema->columns.end() || it->type != column.type) {
                throw Error(ErrorCode::WorkflowValidation, "Table column does not match its schema: " + column.name);
            }
        }
    }
    if (schema) {
        for (const auto &definition : schema->columns) {
            const auto it = std::find_if(columns.begin(), columns.end(),
                                         [&](const auto &column) { return column.name == definition.name; });
            if (definition.required && it == columns.end()) {
                throw Error(ErrorCode::WorkflowValidation, "Missing required table column: " + definition.name);
            }
        }
    }
}

Json Table::to_json() const {
    Json output = Json::array();
    for (const auto &column : columns) {
        Json values = Json::array();
        std::visit([&](const auto &items) { for (const auto &item : items) values.push_back(item); }, column.values);
        output.push_back({{"name", column.name}, {"type", detail::parameter_type_name(column.type)}, {"values", values}});
    }
    return {{"columns", output}};
}

Table Table::from_json(const Json &value) {
    if (!value.is_object() || !value.at("columns").is_array()) {
        throw Error(ErrorCode::WorkflowValidation, "Table value requires a columns array");
    }
    Table table;
    for (const auto &item : value.at("columns")) {
        const auto type = detail::parameter_type_from_name(item.at("type").get<std::string>());
        const Json &values = item.at("values");
        if (!values.is_array()) throw Error(ErrorCode::WorkflowValidation, "Table column values must be arrays");
        TableColumn column;
        column.name = item.at("name").get<std::string>();
        column.type = type;
        switch (type) {
        case ParameterType::string: column.values = values.get<std::vector<std::string>>(); break;
        case ParameterType::integer: column.values = values.get<std::vector<std::int64_t>>(); break;
        case ParameterType::real: column.values = values.get<std::vector<double>>(); break;
        case ParameterType::boolean: column.values = values.get<std::vector<bool>>(); break;
        default: throw Error(ErrorCode::WorkflowValidation, "Table columns must be scalar types");
        }
        table.columns.push_back(std::move(column));
    }
    table.validate();
    return table;
}

Json TypeDescriptor::to_json() const {
    Json output = {{"type", detail::parameter_type_name(kind)}};
    if (kind == ParameterType::array) {
        if (!items) throw Error(ErrorCode::InvalidArgument, "Array type requires an items type");
        output["items"] = items->to_json();
    } else if (kind == ParameterType::table && table_schema) {
        output["columns"] = table_schema->to_json();
    }
    return output;
}

TypeDescriptor TypeDescriptor::from_json(const Json &value) {
    if (!value.is_object() || !value.contains("type")) {
        throw Error(ErrorCode::InvalidArgument, "Type descriptor requires a type");
    }
    TypeDescriptor descriptor;
    descriptor.kind = detail::parameter_type_from_name(value.at("type").get<std::string>());
    if (descriptor.kind == ParameterType::array) {
        if (!value.contains("items")) throw Error(ErrorCode::InvalidArgument, "Array type requires an items type");
        descriptor.items = std::make_shared<TypeDescriptor>(from_json(value.at("items")));
    } else if (descriptor.kind == ParameterType::table && value.contains("columns")) {
        descriptor.table_schema = TableSchema::from_json(value.at("columns"));
    }
    return descriptor;
}

void TypeDescriptor::validate(const Json &value) const {
    if (kind == ParameterType::array) {
        if (!items || !value.is_array()) throw Error(ErrorCode::WorkflowValidation, "Invalid array parameter");
        for (const auto &item : value) items->validate(item);
        return;
    }
    if (kind == ParameterType::table) {
        Table::from_json(value).validate(table_schema);
        return;
    }
    if (!parameter_type_matches(kind, value)) {
        throw Error(ErrorCode::WorkflowValidation,
                    std::string("Invalid parameter type; expected ") + detail::parameter_type_name(kind));
    }
}

Json ParameterDefinition::to_json() const {
    return {{"name", name}, {"description", description},
            {"type", type.to_json()}, {"default", default_value},
            {"required", required}, {"example", example}, {"constraints", constraints}, {"ui", ui}};
}

ParameterDefinition ParameterDefinition::from_json(const Json &value) {
    if (!value.is_object() || !value.contains("name") || !value.contains("type")) {
        throw Error(ErrorCode::InvalidArgument, "Parameter definition requires name and type");
    }
    ParameterDefinition definition;
    definition.name = value.at("name").get<std::string>();
    definition.description = value.value("description", "");
    definition.type = TypeDescriptor::from_json(value.at("type"));
    definition.default_value = value.value("default", Json(nullptr));
    definition.required = value.value("required", false);
    definition.example = value.value("example", Json(nullptr));
    definition.constraints = value.value("constraints", Json::object());
    definition.ui = value.value("ui", Json::object());
    return definition;
}

Json ParameterSchema::to_json() const {
    Json output = Json::array();
    for (const auto &definition : definitions) output.push_back(definition.to_json());
    return output;
}

ParameterSchema ParameterSchema::from_json(const Json &value) {
    if (!value.is_array()) throw Error(ErrorCode::InvalidArgument, "Parameter schema must be an array");
    ParameterSchema schema;
    for (const auto &item : value) schema.definitions.push_back(ParameterDefinition::from_json(item));
    return schema;
}

Json ParameterSchema::resolve_and_validate(const Json &values) const {
    if (!values.is_null() && !values.is_object()) {
        throw Error(ErrorCode::WorkflowValidation, "Method parameters must be an object");
    }
    Json resolved = Json::object();
    for (const auto &definition : definitions) {
        if (!definition.default_value.is_null()) resolved[definition.name] = definition.default_value;
        if (definition.required && definition.default_value.is_null() &&
            (!values.is_object() || !values.contains(definition.name))) {
            throw Error(ErrorCode::WorkflowValidation,
                        "Missing required parameter: " + definition.name);
        }
    }
    if (values.is_object()) {
        for (const auto &[name, value] : values.items()) {
            const auto it = std::find_if(definitions.begin(), definitions.end(),
                                         [&](const auto &definition) { return definition.name == name; });
            if (it == definitions.end()) {
                throw Error(ErrorCode::WorkflowValidation, "Unknown parameter: " + name);
            }
            resolved[name] = value;
        }
    }
    for (const auto &definition : definitions) {
        if (!resolved.contains(definition.name)) continue;
        definition.type.validate(resolved.at(definition.name));
    }
    return resolved;
}

Json ParameterValues::to_json() const { return values; }

ParameterValues ParameterValues::from_json(const Json &value) {
    if (!value.is_null() && !value.is_object()) {
        throw Error(ErrorCode::WorkflowValidation, "Parameter values must be an object");
    }
    return {value.is_null() ? Json::object() : value};
}

Method::Method(MethodDefinition definition, MethodExecutor executor,
               MethodValidator validator)
    : definition_(std::move(definition)), executor_(std::move(executor)),
      validator_(std::move(validator)) {
    if (definition_.id.empty()) {
        throw Error(ErrorCode::InvalidArgument, "Method id must not be empty");
    }
    std::vector<std::string> parameter_names;
    for (const auto &parameter : definition_.parameters.definitions) {
        if (parameter.name.empty() ||
            std::find(parameter_names.begin(), parameter_names.end(), parameter.name) != parameter_names.end()) {
            throw Error(ErrorCode::InvalidArgument, "Method parameter names must be unique and non-empty");
        }
        parameter_names.push_back(parameter.name);
    }
}

const MethodDefinition &Method::definition() const noexcept { return definition_; }

Json Method::to_json() const {
    return {
        {"id", definition_.id}, {"name", definition_.name},
        {"description", definition_.description},
        {"version", definition_.version}, {"domain", definition_.domain},
        {"required_methods", definition_.required_methods},
        {"max_occurrences", definition_.max_occurrences},
        {"developer", definition_.developer}, {"contact", definition_.contact},
        {"link", definition_.link}, {"doi", definition_.doi},
        {"parameters", definition_.parameters.to_json()},
        {"cacheable", definition_.cacheable}
    };
}

MethodDefinition Method::definition_from_json(const Json &value) {
    if (!value.is_object() || !value.contains("id")) {
        throw Error(ErrorCode::InvalidArgument, "Method metadata requires an id");
    }
    MethodDefinition definition;
    definition.id = value.at("id").get<std::string>();
    definition.name = value.value("name", definition.id);
    definition.description = value.value("description", "");
    definition.version = value.value("version", "1");
    definition.domain = value.value("domain", "");
    definition.required_methods = value.value("required_methods", std::vector<std::string>{});
    definition.max_occurrences = value.value("max_occurrences", std::numeric_limits<double>::infinity());
    definition.developer = value.value("developer", "");
    definition.contact = value.value("contact", "");
    definition.link = value.value("link", "");
    definition.doi = value.value("doi", "");
    definition.parameters = ParameterSchema::from_json(value.value("parameters", Json::array()));
    definition.cacheable = value.value("cacheable", false);
    return definition;
}

Json Method::resolve_parameters(const Json &value) const {
    Json resolved = definition_.parameters.resolve_and_validate(value);
    validate_parameters(resolved);
    return resolved;
}

void Method::validate_parameters(const Json &value) const {
    if (!validator_) return;
    try {
        validator_(value);
    } catch (const Error &) {
        throw;
    } catch (const std::exception &error) {
        throw Error(ErrorCode::WorkflowValidation,
                    definition_.id + ": invalid parameters: " + error.what());
    }
}

Json Method::run(Project &project, const Json &parameters) const {
    if (!executor_) {
        throw Error(ErrorCode::MethodExecution,
                    "Method has no implementation: " + definition_.id);
    }
    try {
        return executor_(project, resolve_parameters(parameters));
    } catch (const Error &) {
        throw;
    } catch (const std::exception &error) {
        throw Error(ErrorCode::MethodExecution,
                    definition_.id + ": " + error.what());
    }
}

void MethodRegistry::register_method(Method method) {
    if (find(method.definition().id)) {
        throw Error(ErrorCode::InvalidArgument,
                    "Method already registered: " + method.definition().id);
    }
    methods_.push_back(std::move(method));
}

const Method *MethodRegistry::find(const std::string &id) const noexcept {
    const auto it = std::find_if(methods_.begin(), methods_.end(),
                                 [&](const Method &method) { return method.definition().id == id; });
    return it == methods_.end() ? nullptr : &*it;
}

std::vector<MethodDefinition> MethodRegistry::list(const std::string &domain) const {
    std::vector<MethodDefinition> output;
    output.reserve(methods_.size());
    for (const auto &method : methods_) {
        if (domain.empty() || method.definition().domain == domain) output.push_back(method.definition());
    }
    return output;
}

Operation::Operation(OperationDefinition definition, OperationExecutor executor)
    : definition_(std::move(definition)), executor_(std::move(executor)) {
    if (definition_.id.empty()) throw Error(ErrorCode::InvalidArgument, "Operation id must not be empty");
}
const OperationDefinition &Operation::definition() const noexcept { return definition_; }
Json Operation::to_json() const {
    return {{"id", definition_.id}, {"name", definition_.name}, {"description", definition_.description}, {"domain", definition_.domain}, {"parameters", definition_.parameters.to_json()}};
}
Json Operation::resolve_parameters(const Json &value) const { return definition_.parameters.resolve_and_validate(value); }
Json Operation::run(Project &project, const Json &value) const {
    if (!executor_) throw Error(ErrorCode::MethodExecution, "Operation has no implementation: " + definition_.id);
    try { return executor_(project, resolve_parameters(value)); }
    catch (const Error &) { throw; }
    catch (const std::exception &error) { throw Error(ErrorCode::MethodExecution, definition_.id + ": " + error.what()); }
}
void OperationRegistry::register_operation(Operation operation) {
    if (find(operation.definition().id)) throw Error(ErrorCode::InvalidArgument, "Operation already registered: " + operation.definition().id);
    operations_.push_back(std::move(operation));
}
const Operation *OperationRegistry::find(const std::string &id) const noexcept {
    const auto it = std::find_if(operations_.begin(), operations_.end(), [&](const Operation &operation) { return operation.definition().id == id; });
    return it == operations_.end() ? nullptr : &*it;
}
std::vector<OperationDefinition> OperationRegistry::list(const std::string &domain) const {
    std::vector<OperationDefinition> output;
    for (const auto &operation : operations_) if (domain.empty() || operation.definition().domain == domain) output.push_back(operation.definition());
    return output;
}

MethodRegistry &methods() {
    static MethodRegistry registry;
    return registry;
}

Json WorkflowStep::to_json() const {
    return {{"method", method}, {"parameters", parameters.to_json()}};
}

WorkflowStep WorkflowStep::from_json(const Json &value) {
    if (!value.is_object() || (!value.contains("method") && !value.contains("id"))) {
        throw Error(ErrorCode::WorkflowValidation, "Workflow step requires a method");
    }
    WorkflowStep step;
    step.method = value.value("method", value.value("id", ""));
    step.parameters = ParameterValues::from_json(value.value("parameters", Json::object()));
    return step;
}

void Workflow::validate(const MethodRegistry &registry) const {
    std::unordered_map<std::string, std::size_t> counts;
    std::vector<std::string> prior;
    for (const auto &step : steps) {
        const Method *method = registry.find(step.method);
        if (!method) throw Error(ErrorCode::WorkflowValidation,
                                 "Unknown workflow method: " + step.method);
        const auto &definition = method->definition();
        if (!domain.empty() && !definition.domain.empty() && domain != definition.domain) {
            throw Error(ErrorCode::WorkflowValidation,
                        "Method domain does not match workflow domain: " + step.method);
        }
        for (const auto &required : definition.required_methods) {
            if (std::find(prior.begin(), prior.end(), required) == prior.end()) {
                throw Error(ErrorCode::WorkflowValidation,
                            "Required method is not earlier in workflow: " + required);
            }
        }
        if (++counts[step.method] > definition.max_occurrences) {
            throw Error(ErrorCode::WorkflowValidation,
                        "Method occurs too many times: " + step.method);
        }
        method->resolve_parameters(step.parameters.values);
        prior.push_back(step.method);
    }
}

Json Workflow::to_json() const {
    Json serialized_steps = Json::array();
    for (const auto &step : steps) serialized_steps.push_back(step.to_json());
    return serialized_steps;
}

Json Workflow::to_json(const MethodRegistry &registry) const {
    Json serialized = Json::array();
    for (const auto &step : steps) {
        const auto *method = registry.find(step.method);
        if (!method) throw Error(ErrorCode::WorkflowValidation, "Unknown workflow method: " + step.method);
        auto value = method->to_json();
        value["parameters"] = step.parameters.to_json();
        serialized.push_back(std::move(value));
    }
    return serialized;
}

Workflow Workflow::from_json(const Json &value) {
    if (value.is_null()) return {};
    Workflow workflow;
    if (value.is_array()) {
        for (const auto &item : value) workflow.steps.push_back(WorkflowStep::from_json(item));
        return workflow;
    }
    if (!value.is_object()) throw Error(ErrorCode::WorkflowValidation, "Workflow must be an object or array");
    workflow.name = value.value("name", "");
    workflow.version = value.value("version", 1);
    workflow.domain = value.value("domain", "");
    for (const auto &item : value.value("steps", Json::array())) {
        workflow.steps.push_back(WorkflowStep::from_json(item));
    }
    return workflow;
}

struct Project::Impl {
    ProjectOptions options;
    ProjectInfo info;
    mutable std::mutex mutex;
    bool closed{false};
};

class Connection {
public:
    Connection(const Project::Impl &impl) {
        duckdb_config config = nullptr;
        if (duckdb_create_config(&config) == DuckDBError) {
            throw Error(ErrorCode::DatabaseError, "create DuckDB config failed");
        }
        if (impl.options.read_only) duckdb_set_config(config, "access_mode", "READ_ONLY");
        char *error = nullptr;
        if (duckdb_open_ext(impl.options.database_path.string().c_str(), &database_, config, &error) != DuckDBSuccess) {
            const std::string message = error ? error : "open DuckDB database failed";
            if (error) duckdb_free(error);
            duckdb_destroy_config(&config);
            throw Error(ErrorCode::DatabaseError, message);
        }
        duckdb_destroy_config(&config);
        if (duckdb_connect(database_, &connection_) != DuckDBSuccess) {
            duckdb_close(&database_);
            throw Error(ErrorCode::DatabaseError, "connect DuckDB database failed");
        }
    }
    ~Connection() {
        if (connection_) duckdb_disconnect(&connection_);
        if (database_) duckdb_close(&database_);
    }
    duckdb_connection get() const noexcept { return connection_; }

private:
    duckdb_database database_{nullptr};
    duckdb_connection connection_{nullptr};
};

void ensure_active(const Project::Impl &impl) {
    if (impl.closed) throw Error(ErrorCode::InvalidArgument, "Project is closed");
}

ProjectInfo read_info(duckdb_connection connection, const std::string &id) {
    ProjectInfo info;
    prepared(connection,
             "SELECT project_id, domain, metadata, schema_version, framework_version, created_at FROM PROJECT WHERE project_id = ? LIMIT 1",
             "read PROJECT row",
             [&](Statement statement) { bind_text(statement, 1, id); },
             [&](duckdb_result &result) {
                 if (duckdb_row_count(&result) == 0) {
                     throw Error(ErrorCode::ProjectNotFound, "Project not found: " + id);
                 }
                 info.id = value_string(result, 0, 0);
                 info.domain = value_string(result, 1, 0);
                 info.metadata = parse_json(value_string(result, 2, 0), "PROJECT metadata");
                 info.schema_version = duckdb_value_int32(&result, 3, 0);
                 info.framework_version = value_string(result, 4, 0);
                 info.created_at = value_string(result, 5, 0);
             });
    return info;
}

void audit(duckdb_connection connection, const std::string &project_id,
           const std::string &operation, const std::string &object, const Json &details) {
    prepared(connection,
             "INSERT INTO AUDIT_TRAIL (project_id, operation_type, object_type, operation_details) VALUES (?, ?, ?, ?)",
             "write audit trail",
             [&](Statement statement) {
                 bind_text(statement, 1, project_id);
                 bind_text(statement, 2, operation);
                 bind_text(statement, 3, object);
                 bind_text(statement, 4, json_text(details));
             },
             [](duckdb_result &) {});
}

Project project_from_options(const ProjectOptions &options, bool creating) {
    if (options.database_path.empty() || options.project_id.empty()) {
        throw Error(ErrorCode::InvalidArgument, "Project database path and id are required");
    }
    const bool exists = options.database_path != ":memory:" && std::filesystem::exists(options.database_path);
    if (creating && exists) throw Error(ErrorCode::ProjectAlreadyExists, "Project database already exists");
    if (!creating && !exists && !options.create_if_missing) {
        throw Error(ErrorCode::ProjectNotFound, "Project database does not exist");
    }
    if (!exists && options.database_path != ":memory:") {
        const auto parent = options.database_path.parent_path();
        if (!parent.empty()) std::filesystem::create_directories(parent);
    }

    auto impl = std::make_shared<Project::Impl>();
    impl->options = options;
    Connection connection(*impl);
    if (options.read_only) {
        query(connection.get(), "SELECT project_id, domain, metadata, workflow, schema_version, framework_version FROM PROJECT LIMIT 0", "validate PROJECT schema");
    } else {
        ensure_schema(connection.get(), options);
    }
    if (!options.read_only) {
        prepared(connection.get(),
                  "INSERT INTO PROJECT (project_id, domain, metadata, workflow) VALUES (?, ?, '{}', '[]') ON CONFLICT(project_id) DO NOTHING",
                 "create PROJECT row",
                 [&](Statement statement) { bind_text(statement, 1, options.project_id); bind_text(statement, 2, options.domain); },
                 [](duckdb_result &) {});
    }
    impl->info = read_info(connection.get(), options.project_id);
    if (!options.read_only) {
        audit(connection.get(), options.project_id, creating ? "create" : "open", "project", Json::object());
    }
    return Project(std::move(impl));
}

Project::Project(std::shared_ptr<Impl> impl) : impl_(std::move(impl)) {}

Project Project::create(const ProjectOptions &options) { return project_from_options(options, true); }

Project Project::open(const ProjectOptions &options) {
    if (!std::filesystem::exists(options.database_path) && options.create_if_missing) {
        return project_from_options(options, true);
    }
    return project_from_options(options, false);
}

Project::Project(Project &&other) noexcept = default;
Project &Project::operator=(Project &&other) noexcept = default;
Project::~Project() { close(); }

const ProjectInfo &Project::info() const {
    std::lock_guard lock(impl_->mutex);
    ensure_active(*impl_);
    return impl_->info;
}

Json Project::get_metadata() const {
    std::lock_guard lock(impl_->mutex);
    ensure_active(*impl_);
    return impl_->info.metadata;
}

const std::filesystem::path &Project::get_database_path() const noexcept { return impl_->options.database_path; }
const std::string &Project::get_project_id() const noexcept { return impl_->options.project_id; }

std::string Project::get_domain() const {
    std::lock_guard lock(impl_->mutex);
    ensure_active(*impl_);
    return impl_->info.domain;
}

void Project::validate() const {
    std::lock_guard lock(impl_->mutex);
    ensure_active(*impl_);
    Connection connection(*impl_);
    query(connection.get(), "SELECT project_id, domain, metadata, workflow, schema_version, framework_version FROM PROJECT LIMIT 0", "validate PROJECT schema");
    read_info(connection.get(), get_project_id());
    query(connection.get(), "SELECT project_id, name, description, hash, data, created_at FROM CACHE LIMIT 0", "validate CACHE schema");
    query(connection.get(), "SELECT project_id, operation_type, object_type, operation_details, created_at FROM AUDIT_TRAIL LIMIT 0", "validate AUDIT_TRAIL schema");
}

void Project::set_metadata(Json metadata) {
    if (!metadata.is_object()) throw Error(ErrorCode::InvalidArgument, "Project metadata must be an object");
    for (const auto &[key, value] : metadata.items())
        if (value.is_object() || value.is_array())
            throw Error(ErrorCode::InvalidArgument, "Project metadata values must be scalar: " + key);
    std::lock_guard lock(impl_->mutex); ensure_active(*impl_);
    if (impl_->options.read_only) throw Error(ErrorCode::InvalidArgument, "Project is read-only");
    Connection connection(*impl_);
    prepared(connection.get(), "UPDATE PROJECT SET metadata = ? WHERE project_id = ?", "update metadata",
             [&](Statement statement) { bind_text(statement, 1, json_text(metadata)); bind_text(statement, 2, get_project_id()); },
             [](duckdb_result &) {});
    audit(connection.get(), get_project_id(), "update", "metadata", metadata);
    impl_->info.metadata = std::move(metadata);
}

Project Project::copy(const ProjectOptions &options) const {
    const auto workflow_value = get_workflow();
    ProjectOptions destination_options = options;
    destination_options.domain = impl_->info.domain;
    Project destination = Project::create(destination_options);
    destination.set_metadata(impl_->info.metadata);
    destination.set_workflow(workflow_value);
    for (const auto &entry : get_cache()) {
        destination.set_cache(entry.name, entry.description, entry.hash,
                              parse_json(std::string(entry.data.begin(), entry.data.end()), "cache entry"));
    }
    return destination;
}

Workflow Project::get_workflow() const {
    std::lock_guard lock(impl_->mutex); ensure_active(*impl_);
    Connection connection(*impl_);
    Json value;
    prepared(connection.get(), "SELECT workflow FROM PROJECT WHERE project_id = ?", "read workflow",
             [&](Statement statement) { bind_text(statement, 1, get_project_id()); },
             [&](duckdb_result &result) { if (duckdb_row_count(&result)) value = parse_json(value_string(result, 0, 0), "workflow"); });
    return Workflow::from_json(value);
}

void Project::set_workflow(Workflow workflow_value, const MethodRegistry &registry) {
    const Workflow previous = get_workflow();
    workflow_value.version = std::max(workflow_value.version, previous.version + 1);
    workflow_value.domain = workflow_value.domain.empty() ? impl_->info.domain : workflow_value.domain;
    workflow_value.validate(registry);
    std::lock_guard lock(impl_->mutex); ensure_active(*impl_);
    if (impl_->options.read_only) throw Error(ErrorCode::InvalidArgument, "Project is read-only");
    Connection connection(*impl_);
    prepared(connection.get(), "UPDATE PROJECT SET workflow = ? WHERE project_id = ?", "update workflow",
             [&](Statement statement) { bind_text(statement, 1, json_text(workflow_value.to_json(registry))); bind_text(statement, 2, get_project_id()); },
             [](duckdb_result &) {});
    audit(connection.get(), get_project_id(), "update", "workflow", workflow_value.to_json(registry));
}

std::vector<std::string> Project::list_tables() const {
    std::lock_guard lock(impl_->mutex); ensure_active(*impl_);
    Connection connection(*impl_);
    std::vector<std::string> output;
    query(connection.get(), "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main' ORDER BY table_name", "list tables");
    duckdb_result result{};
    if (duckdb_query(connection.get(), "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main' ORDER BY table_name", &result) == DuckDBError) {
        const std::string message = db_error(result); duckdb_destroy_result(&result); throw Error(ErrorCode::DatabaseError, message);
    }
    ResultGuard guard(result);
    for (idx_t row = 0; row < duckdb_row_count(&result); ++row) output.push_back(value_string(result, 0, row));
    return output;
}

void Project::execute_sql(const std::string &sql) const {
    std::lock_guard lock(impl_->mutex);
    ensure_active(*impl_);
    Connection connection(*impl_);
    query(connection.get(), sql, "execute project SQL");
}

Json Project::query_json(const std::string &sql) const {
    std::lock_guard lock(impl_->mutex);
    ensure_active(*impl_);
    Connection connection(*impl_);
    Json rows = Json::array();
    duckdb_result result;
    if (duckdb_query(connection.get(), sql.c_str(), &result) == DuckDBError) {
        const std::string message = duckdb_result_error(&result) ? duckdb_result_error(&result) : "query failed";
        duckdb_destroy_result(&result);
        throw Error(ErrorCode::DatabaseError, message);
    }
    const auto columns = duckdb_column_count(&result);
    const auto count = duckdb_row_count(&result);
    for (idx_t row = 0; row < count; ++row) {
        Json object = Json::object();
        for (idx_t column = 0; column < columns; ++column) {
            const auto name = duckdb_column_name(&result, column);
            if (duckdb_value_is_null(&result, column, row)) object[name] = nullptr;
            else {
                char *value = duckdb_value_varchar(&result, column, row);
                object[name] = value ? value : "";
                if (value) duckdb_free(value);
            }
        }
        rows.push_back(std::move(object));
    }
    duckdb_destroy_result(&result);
    return rows;
}

std::vector<CacheEntry> Project::get_cache() const {
    std::lock_guard lock(impl_->mutex); ensure_active(*impl_); Connection connection(*impl_);
    std::vector<CacheEntry> output;
    prepared(connection.get(), "SELECT name, description, hash, data, created_at FROM CACHE WHERE project_id = ? ORDER BY created_at DESC", "read cache",
             [&](Statement statement) { bind_text(statement, 1, get_project_id()); },
             [&](duckdb_result &result) {
                 for (idx_t row = 0; row < duckdb_row_count(&result); ++row) {
                     CacheEntry entry{value_string(result, 0, row), value_string(result, 1, row), value_string(result, 2, row), {}, value_string(result, 4, row)};
                     duckdb_blob blob = duckdb_value_blob(&result, 3, row);
                     if (blob.data && blob.size) entry.data.assign(static_cast<std::uint8_t *>(blob.data), static_cast<std::uint8_t *>(blob.data) + blob.size);
                     if (blob.data) duckdb_free(blob.data);
                     output.push_back(std::move(entry));
                 }
             });
    return output;
}

std::size_t Project::get_cache_size() const { return get_cache().size(); }

std::optional<CacheEntry> Project::get_cache_entry(const std::string &hash) const {
    for (auto &entry : get_cache()) if (entry.hash == hash) return entry;
    return std::nullopt;
}

void Project::set_cache(std::string name, std::string description, std::string hash, const Json &value) {
    std::lock_guard lock(impl_->mutex); ensure_active(*impl_);
    if (impl_->options.read_only) throw Error(ErrorCode::InvalidArgument, "Project is read-only");
    const std::string payload = json_text(value);
    Connection connection(*impl_);
    prepared(connection.get(), "INSERT INTO CACHE (project_id, name, description, hash, data) VALUES (?, ?, ?, ?, ?) ON CONFLICT(project_id, hash) DO UPDATE SET name = excluded.name, description = excluded.description, data = excluded.data",
             "write cache",
              [&](Statement statement) { bind_text(statement, 1, get_project_id()); bind_text(statement, 2, name); bind_text(statement, 3, description); bind_text(statement, 4, hash); duckdb_bind_blob(statement, 5, payload.data(), payload.size()); },
             [](duckdb_result &) {});
}

void Project::delete_cache() {
    std::lock_guard lock(impl_->mutex); ensure_active(*impl_);
    if (impl_->options.read_only) throw Error(ErrorCode::InvalidArgument, "Project is read-only");
    Connection connection(*impl_);
    prepared(connection.get(), "DELETE FROM CACHE WHERE project_id = ?", "delete cache",
             [&](Statement statement) { bind_text(statement, 1, get_project_id()); }, [](duckdb_result &) {});
    audit(connection.get(), get_project_id(), "delete", "cache", Json::object());
}

std::vector<AuditEntry> Project::get_audit_trail() const {
    std::lock_guard lock(impl_->mutex); ensure_active(*impl_); Connection connection(*impl_);
    std::vector<AuditEntry> output;
    prepared(connection.get(), "SELECT operation_type, object_type, operation_details, created_at FROM AUDIT_TRAIL WHERE project_id = ? ORDER BY created_at ASC", "read audit trail",
              [&](Statement statement) { bind_text(statement, 1, get_project_id()); },
             [&](duckdb_result &result) { for (idx_t row = 0; row < duckdb_row_count(&result); ++row) output.push_back({value_string(result, 0, row), value_string(result, 1, row), parse_json(value_string(result, 2, row), "audit details"), value_string(result, 3, row)}); });
    return output;
}

ExecutionResult Project::run_workflow(const MethodRegistry &registry, CancellationToken *cancellation, ProgressCallback progress) {
    Workflow current = get_workflow(); current.validate(registry);
    Json results = Json::array();
    std::size_t completed = 0;
    for (const auto &step : current.steps) {
        if (cancellation && cancellation->is_cancelled()) return {results, true};
        const Method *method = registry.find(step.method);
        const Json parameters = method->resolve_parameters(step.parameters.values);
        const auto &definition = method->definition();
    const std::string key = hash_text(get_project_id() + "\n" + definition.id + "\n" + definition.version + "\n" + parameters.dump());
        if (definition.cacheable) {
            if (auto cached = get_cache_entry(key)) {
                const Json result = parse_json(std::string(cached->data.begin(), cached->data.end()), "cached result");
                results.push_back(result);
                std::lock_guard lock(impl_->mutex); Connection connection(*impl_);
                audit(connection.get(), get_project_id(), "cache_hit", "workflow_step", Json{{"method", definition.id}, {"cache_key", key}});
                continue;
            }
            std::lock_guard lock(impl_->mutex); Connection connection(*impl_);
            audit(connection.get(), get_project_id(), "cache_miss", "workflow_step", Json{{"method", definition.id}, {"cache_key", key}});
        }
        {
            std::lock_guard lock(impl_->mutex); ensure_active(*impl_); Connection connection(*impl_);
            audit(connection.get(), get_project_id(), "start", "workflow_step", Json{{"method", definition.id}, {"cache_key", key}, {"parameters", parameters}});
        }
        try {
            Json result = method->run(*this, parameters);
            results.push_back(result);
             if (definition.cacheable) set_cache(definition.id, "workflow result", key, result);
            if (progress) progress({"workflow", ++completed, current.steps.size()});
            std::lock_guard lock(impl_->mutex); Connection connection(*impl_); audit(connection.get(), get_project_id(), "complete", "workflow_step", Json{{"method", definition.id}, {"cache_key", key}});
        } catch (const std::exception &error) {
            std::lock_guard lock(impl_->mutex); Connection connection(*impl_); audit(connection.get(), get_project_id(), "failed", "workflow_step", Json{{"method", definition.id}, {"error", error.what()}});
            throw;
        }
    }
    return {results, false};
}

Json Project::run_method(const std::string &method_id, const Json &parameters,
                         const MethodRegistry &registry) {
    const Method *method = registry.find(method_id);
    if (!method) throw Error(ErrorCode::WorkflowValidation, "Unknown method: " + method_id);
    Workflow workflow = get_workflow();
    workflow.domain = workflow.domain.empty() ? get_domain() : workflow.domain;
    workflow.steps.push_back({method_id, ParameterValues::from_json(parameters)});
    workflow.validate(registry);
    set_workflow(workflow, registry);
    const Json resolved = method->resolve_parameters(parameters);
    {
        std::lock_guard lock(impl_->mutex); ensure_active(*impl_); Connection connection(*impl_);
        audit(connection.get(), get_project_id(), "start", "method", Json{{"method", method_id}, {"parameters", resolved}});
    }
    const Json result = method->run(*this, resolved);
    {
        std::lock_guard lock(impl_->mutex); Connection connection(*impl_);
        audit(connection.get(), get_project_id(), "complete", "method", Json{{"method", method_id}});
    }
    return result;
}

Json Project::run_operation(const std::string &operation_id, const Json &parameters,
                            const OperationRegistry &registry) const {
    const Operation *operation = registry.find(operation_id);
    if (!operation) throw Error(ErrorCode::InvalidArgument, "Unknown operation: " + operation_id);
    Json input = parameters;
    input["database_path"] = get_database_path().string();
    input["project_id"] = get_project_id();
    const Json result = operation->run(const_cast<Project &>(*this), input);
    std::lock_guard lock(impl_->mutex); ensure_active(*impl_); Connection connection(*impl_);
    audit(connection.get(), get_project_id(), "complete", "operation", Json{{"operation", operation_id}});
    return result;
}

void Project::close() noexcept {
    if (impl_) {
        std::lock_guard lock(impl_->mutex);
        impl_->closed = true;
    }
}

} // namespace streamfind
