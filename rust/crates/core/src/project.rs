use duckdb::{params, types::Value as DuckValue, Config, Connection, OptionalExt};
use serde::Serialize;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::fmt;
use std::fs;
use std::path::{Path, PathBuf};

pub type Json = Value;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ErrorCode {
    InvalidArgument,
    ProjectNotFound,
    ProjectAlreadyExists,
    SchemaMismatch,
    DatabaseError,
    WorkflowValidation,
    MethodExecution,
    ProjectClosed,
    Cancelled,
}

#[derive(Debug)]
pub struct Error {
    pub code: ErrorCode,
    pub message: String,
}

impl Error {
    pub fn new(code: ErrorCode, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }
}

impl fmt::Display for Error {
    fn fmt(&self, output: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(output, "{:?}: {}", self.code, self.message)
    }
}

impl std::error::Error for Error {}

impl From<duckdb::Error> for Error {
    fn from(error: duckdb::Error) -> Self {
        Self::new(ErrorCode::DatabaseError, error.to_string())
    }
}

pub type Result<T> = std::result::Result<T, Error>;

/// Cooperative cancellation state for long-running operations.
#[derive(Default)]
pub struct CancellationToken {
    cancelled: std::sync::atomic::AtomicBool,
}

impl CancellationToken {
    pub fn cancel(&self) {
        self.cancelled
            .store(true, std::sync::atomic::Ordering::Relaxed);
    }
    pub fn is_cancelled(&self) -> bool {
        self.cancelled.load(std::sync::atomic::Ordering::Relaxed)
    }
}

/// Progress snapshot emitted during workflow execution.
#[derive(Debug, Clone)]
pub struct ProgressEvent {
    pub operation: String,
    pub completed: usize,
    pub total: usize,
}

/// Stable result envelope for workflow execution.
#[derive(Debug, Clone, Serialize)]
pub struct ExecutionResult {
    pub results: Json,
    pub cancelled: bool,
}

impl ExecutionResult {
    pub fn to_json(&self) -> Json {
        json!({"results": self.results, "cancelled": self.cancelled})
    }
}

pub type ProgressCallback = Box<dyn Fn(&ProgressEvent) + Send + Sync>;

fn cache_key(project_id: &str, method: &str, parameters: &Json) -> String {
    let mut hash: u64 = 1469598103934665603;
    for byte in format!("{project_id}\n{method}\n{}", parameters).bytes() {
        hash ^= u64::from(byte);
        hash = hash.wrapping_mul(1099511628211);
    }
    format!("{hash:016x}")
}

fn duck_value_to_json(value: DuckValue) -> Json {
    match value {
        DuckValue::Null => Json::Null,
        DuckValue::Boolean(value) => json!(value),
        DuckValue::TinyInt(value) => json!(value),
        DuckValue::SmallInt(value) => json!(value),
        DuckValue::Int(value) => json!(value),
        DuckValue::BigInt(value) => json!(value),
        DuckValue::HugeInt(value) => json!(value.to_string()),
        DuckValue::UTinyInt(value) => json!(value),
        DuckValue::USmallInt(value) => json!(value),
        DuckValue::UInt(value) => json!(value),
        DuckValue::UBigInt(value) => json!(value),
        DuckValue::Float(value) => json!(value),
        DuckValue::Double(value) => json!(value),
        DuckValue::Decimal(value) => value
            .to_string()
            .parse::<f64>()
            .map(|value| json!(value))
            .unwrap_or_else(|_| json!(value.to_string())),
        DuckValue::Text(value) => Json::String(value),
        DuckValue::Blob(value) => json!(value),
        DuckValue::Timestamp(_, value) => json!(value),
        DuckValue::Date32(value) => json!(value),
        DuckValue::Time64(_, value) => json!(value),
        DuckValue::Interval {
            months,
            days,
            nanos,
        } => json!({"months": months, "days": days, "nanos": nanos}),
        DuckValue::List(values) | DuckValue::Array(values) => {
            Json::Array(values.into_iter().map(duck_value_to_json).collect())
        }
        DuckValue::Enum(value) => Json::String(value),
        DuckValue::Struct(values) => Json::Object(
            values
                .iter()
                .map(|(name, value)| (name.clone(), duck_value_to_json(value.clone())))
                .collect(),
        ),
        DuckValue::Map(values) => Json::Array(
            values
                .iter()
                .map(|(key, value)| {
                    json!([
                        duck_value_to_json(key.clone()),
                        duck_value_to_json(value.clone())
                    ])
                })
                .collect(),
        ),
        DuckValue::Union(value) => duck_value_to_json(*value),
    }
}

#[derive(Debug, Clone)]
/// Options used to create or open a project database.
pub struct ProjectOptions {
    pub database_path: PathBuf,
    pub project_id: String,
    pub domain: String,
    pub create_if_missing: bool,
    pub read_only: bool,
}

#[derive(Debug, Clone)]
/// Metadata loaded from the `PROJECT` table.
pub struct ProjectInfo {
    pub id: String,
    pub domain: String,
    pub metadata: Json,
    pub schema_version: i32,
    pub framework_version: String,
    pub created_at: String,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ParameterType {
    String,
    Integer,
    Real,
    Boolean,
    Array,
    Object,
    Table,
}

impl ParameterType {
    fn as_str(&self) -> &'static str {
        match self {
            Self::String => "string",
            Self::Integer => "integer",
            Self::Real => "real",
            Self::Boolean => "boolean",
            Self::Array => "array",
            Self::Object => "object",
            Self::Table => "table",
        }
    }

    fn parse(value: &str) -> Result<Self> {
        match value {
            "string" => Ok(Self::String),
            "integer" => Ok(Self::Integer),
            "real" => Ok(Self::Real),
            "boolean" => Ok(Self::Boolean),
            "array" => Ok(Self::Array),
            "object" => Ok(Self::Object),
            "table" => Ok(Self::Table),
            _ => Err(Error::new(
                ErrorCode::InvalidArgument,
                format!("unknown parameter type: {value}"),
            )),
        }
    }
}

#[derive(Debug, Clone)]
pub struct TypeDescriptor {
    pub kind: ParameterType,
    pub items: Option<Box<TypeDescriptor>>,
    pub table_schema: Option<TableSchema>,
}

impl TypeDescriptor {
    pub fn scalar(kind: ParameterType) -> Self {
        Self {
            kind,
            items: None,
            table_schema: None,
        }
    }

    pub fn array(items: TypeDescriptor) -> Self {
        Self {
            kind: ParameterType::Array,
            items: Some(Box::new(items)),
            table_schema: None,
        }
    }

    pub fn to_json(&self) -> Json {
        let mut output = json!({"type": self.kind.as_str()});
        if let Some(items) = &self.items {
            output["items"] = items.to_json();
        }
        if let Some(schema) = &self.table_schema {
            output["columns"] = schema.to_json();
        }
        output
    }

    pub fn from_json(value: &Json) -> Result<Self> {
        let kind =
            ParameterType::parse(value.get("type").and_then(Value::as_str).ok_or_else(|| {
                Error::new(ErrorCode::InvalidArgument, "type descriptor requires type")
            })?)?;
        let items = if kind == ParameterType::Array {
            Some(Box::new(Self::from_json(value.get("items").ok_or_else(
                || Error::new(ErrorCode::InvalidArgument, "array type requires items"),
            )?)?))
        } else {
            None
        };
        let table_schema = if kind == ParameterType::Table && value.get("columns").is_some() {
            Some(TableSchema::from_json(value.get("columns").unwrap())?)
        } else {
            None
        };
        Ok(Self {
            kind,
            items,
            table_schema,
        })
    }

    pub fn validate(&self, value: &Json) -> Result<()> {
        match self.kind {
            ParameterType::String if value.is_string() => Ok(()),
            ParameterType::Integer if value.as_i64().is_some() => Ok(()),
            ParameterType::Real if value.is_number() => Ok(()),
            ParameterType::Boolean if value.is_boolean() => Ok(()),
            ParameterType::Object if value.is_object() => Ok(()),
            ParameterType::Array => {
                let items = self.items.as_ref().ok_or_else(|| {
                    Error::new(ErrorCode::WorkflowValidation, "array type requires items")
                })?;
                value
                    .as_array()
                    .ok_or_else(|| Error::new(ErrorCode::WorkflowValidation, "expected array"))?
                    .iter()
                    .try_for_each(|item| items.validate(item))
            }
            ParameterType::Table => Table::from_json(value)?.validate(self.table_schema.as_ref()),
            _ => Err(Error::new(
                ErrorCode::WorkflowValidation,
                format!("expected {}", self.kind.as_str()),
            )),
        }
    }
}

#[derive(Debug, Clone)]
pub struct TableColumnDefinition {
    pub name: String,
    pub description: String,
    pub kind: ParameterType,
    pub required: bool,
}

#[derive(Debug, Clone)]
pub struct TableSchema {
    pub columns: Vec<TableColumnDefinition>,
}

impl TableSchema {
    pub fn to_json(&self) -> Json {
        Json::Array(self.columns.iter().map(|column| json!({"name": column.name, "description": column.description, "type": column.kind.as_str(), "required": column.required})).collect())
    }

    pub fn from_json(value: &Json) -> Result<Self> {
        let columns = value
            .as_array()
            .ok_or_else(|| Error::new(ErrorCode::InvalidArgument, "table schema must be an array"))?
            .iter()
            .map(|item| {
                Ok(TableColumnDefinition {
                    name: item
                        .get("name")
                        .and_then(Value::as_str)
                        .ok_or_else(|| {
                            Error::new(ErrorCode::InvalidArgument, "table column requires name")
                        })?
                        .to_owned(),
                    description: item
                        .get("description")
                        .and_then(Value::as_str)
                        .unwrap_or_default()
                        .to_owned(),
                    kind: ParameterType::parse(
                        item.get("type").and_then(Value::as_str).ok_or_else(|| {
                            Error::new(ErrorCode::InvalidArgument, "table column requires type")
                        })?,
                    )?,
                    required: item
                        .get("required")
                        .and_then(Value::as_bool)
                        .unwrap_or(true),
                })
            })
            .collect::<Result<Vec<_>>>()?;
        Ok(Self { columns })
    }
}

#[derive(Debug, Clone)]
pub struct Table {
    pub columns: Vec<TableColumn>,
}

#[derive(Debug, Clone)]
pub struct TableColumn {
    pub name: String,
    pub kind: ParameterType,
    pub values: Vec<Json>,
}

impl Table {
    pub fn from_json(value: &Json) -> Result<Self> {
        let columns = value
            .get("columns")
            .and_then(Value::as_array)
            .ok_or_else(|| Error::new(ErrorCode::WorkflowValidation, "table requires columns"))?
            .iter()
            .map(|item| {
                Ok(TableColumn {
                    name: item
                        .get("name")
                        .and_then(Value::as_str)
                        .ok_or_else(|| {
                            Error::new(ErrorCode::WorkflowValidation, "table column requires name")
                        })?
                        .to_owned(),
                    kind: ParameterType::parse(
                        item.get("type").and_then(Value::as_str).ok_or_else(|| {
                            Error::new(ErrorCode::WorkflowValidation, "table column requires type")
                        })?,
                    )?,
                    values: item
                        .get("values")
                        .and_then(Value::as_array)
                        .ok_or_else(|| {
                            Error::new(
                                ErrorCode::WorkflowValidation,
                                "table column requires values",
                            )
                        })?
                        .clone(),
                })
            })
            .collect::<Result<Vec<_>>>()?;
        let table = Self { columns };
        table.validate(None)?;
        Ok(table)
    }

    pub fn row_count(&self) -> usize {
        self.columns.first().map_or(0, |column| column.values.len())
    }

    pub fn validate(&self, schema: Option<&TableSchema>) -> Result<()> {
        let rows = self.row_count();
        let mut names = HashMap::new();
        for column in &self.columns {
            if names.insert(column.name.clone(), ()).is_some() {
                return Err(Error::new(
                    ErrorCode::WorkflowValidation,
                    "duplicate table column",
                ));
            }
            if column.values.len() != rows {
                return Err(Error::new(
                    ErrorCode::WorkflowValidation,
                    "table columns must have equal lengths",
                ));
            }
            if let Some(schema) = schema {
                let definition = schema
                    .columns
                    .iter()
                    .find(|definition| definition.name == column.name)
                    .ok_or_else(|| {
                        Error::new(ErrorCode::WorkflowValidation, "unexpected table column")
                    })?;
                if definition.kind != column.kind {
                    return Err(Error::new(
                        ErrorCode::WorkflowValidation,
                        "table column type mismatch",
                    ));
                }
            }
        }
        if let Some(schema) = schema {
            for definition in &schema.columns {
                if definition.required && !names.contains_key(&definition.name) {
                    return Err(Error::new(
                        ErrorCode::WorkflowValidation,
                        format!("missing table column: {}", definition.name),
                    ));
                }
            }
        }
        Ok(())
    }

    pub fn to_json(&self) -> Json {
        json!({"columns": self.columns.iter().map(|column| json!({"name": column.name, "type": column.kind.as_str(), "values": column.values})).collect::<Vec<_>>()})
    }
}

#[derive(Debug, Clone)]
pub struct ParameterDefinition {
    pub name: String,
    pub description: String,
    pub kind: TypeDescriptor,
    pub default: Option<Json>,
    pub required: bool,
}

#[derive(Debug, Clone, Default)]
pub struct ParameterSchema {
    pub definitions: Vec<ParameterDefinition>,
}

impl ParameterSchema {
    pub fn resolve(&self, values: &Json) -> Result<Json> {
        let input = values.as_object().ok_or_else(|| {
            Error::new(
                ErrorCode::WorkflowValidation,
                "parameters must be an object",
            )
        })?;
        let mut output = serde_json::Map::new();
        for definition in &self.definitions {
            if let Some(default) = &definition.default {
                output.insert(definition.name.clone(), default.clone());
            }
            if definition.required
                && definition.default.is_none()
                && !input.contains_key(&definition.name)
            {
                return Err(Error::new(
                    ErrorCode::WorkflowValidation,
                    format!("missing parameter: {}", definition.name),
                ));
            }
        }
        for (name, value) in input {
            let definition = self
                .definitions
                .iter()
                .find(|definition| definition.name == *name)
                .ok_or_else(|| {
                    Error::new(
                        ErrorCode::WorkflowValidation,
                        format!("unknown parameter: {name}"),
                    )
                })?;
            definition.kind.validate(value)?;
            output.insert(name.clone(), value.clone());
        }
        Ok(Json::Object(output))
    }
}

pub type MethodExecutor = Box<dyn Fn(&mut Project, &Json) -> Result<Json> + Send + Sync>;
pub type MethodValidator = Box<dyn Fn(&Json) -> Result<()> + Send + Sync>;

pub struct Method {
    pub id: String,
    pub name: String,
    pub description: String,
    pub domain: String,
    pub parameters: ParameterSchema,
    pub cacheable: bool,
    pub required_methods: Vec<String>,
    pub max_occurrences: usize,
    executor: MethodExecutor,
    validator: Option<MethodValidator>,
}

impl Method {
    pub fn new(
        id: impl Into<String>,
        name: impl Into<String>,
        description: impl Into<String>,
        domain: impl Into<String>,
        parameters: ParameterSchema,
        executor: MethodExecutor,
    ) -> Self {
        Self {
            id: id.into(),
            name: name.into(),
            description: description.into(),
            domain: domain.into(),
            parameters,
            cacheable: false,
            required_methods: Vec::new(),
            max_occurrences: 0,
            executor,
            validator: None,
        }
    }

    pub fn to_json(&self) -> Json {
        json!({
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "domain": self.domain,
            "required": self.required_methods,
            "number_permitted": self.max_occurrences,
            "parameters": self.parameters.definitions.iter().map(|definition| json!({
                "name": definition.name,
                "description": definition.description,
                "type": definition.kind.to_json(),
                "default": definition.default,
                "required": definition.required
            })).collect::<Vec<_>>(),
            "cacheable": self.cacheable
        })
    }
    pub fn resolve(&self, values: &Json) -> Result<Json> {
        let resolved = self.parameters.resolve(values)?;
        if let Some(validator) = &self.validator {
            validator(&resolved)?;
        }
        Ok(resolved)
    }
    pub fn run(&self, project: &mut Project, values: &Json) -> Result<Json> {
        (self.executor)(project, &self.resolve(values)?)
    }
}

#[derive(Default)]
pub struct MethodRegistry {
    methods: HashMap<String, Method>,
}

pub type OperationExecutor = Box<dyn Fn(&mut Project, &Json) -> Result<Json> + Send + Sync>;

pub struct Operation {
    pub id: String,
    pub name: String,
    pub description: String,
    pub domain: String,
    pub parameters: ParameterSchema,
    executor: OperationExecutor,
}

impl Operation {
    pub fn new(
        id: impl Into<String>,
        name: impl Into<String>,
        description: impl Into<String>,
        domain: impl Into<String>,
        parameters: ParameterSchema,
        executor: OperationExecutor,
    ) -> Self {
        Self {
            id: id.into(),
            name: name.into(),
            description: description.into(),
            domain: domain.into(),
            parameters,
            executor,
        }
    }
    pub fn to_json(&self) -> Json {
        json!({"id": self.id, "name": self.name, "description": self.description, "domain": self.domain, "parameters": self.parameters.definitions.iter().map(|d| json!({"name": d.name, "description": d.description, "type": d.kind.to_json(), "default": d.default, "required": d.required})).collect::<Vec<_>>()})
    }
    pub fn run(&self, project: &mut Project, values: &Json) -> Result<Json> {
        (self.executor)(project, &self.parameters.resolve(values)?)
    }
}

#[derive(Default)]
pub struct OperationRegistry {
    operations: HashMap<String, Operation>,
}

impl OperationRegistry {
    pub fn register(&mut self, operation: Operation) -> Result<()> {
        if self
            .operations
            .insert(operation.id.clone(), operation)
            .is_some()
        {
            return Err(Error::new(
                ErrorCode::InvalidArgument,
                "duplicate operation",
            ));
        }
        Ok(())
    }
    pub fn get(&self, id: &str) -> Result<&Operation> {
        self.operations.get(id).ok_or_else(|| {
            Error::new(
                ErrorCode::InvalidArgument,
                format!("unknown operation: {id}"),
            )
        })
    }
    pub fn list(&self, domain: &str) -> Vec<Json> {
        self.operations
            .values()
            .filter(|o| domain.is_empty() || o.domain == domain)
            .map(Operation::to_json)
            .collect()
    }
}

impl MethodRegistry {
    pub fn register(&mut self, method: Method) -> Result<()> {
        if self.methods.insert(method.id.clone(), method).is_some() {
            return Err(Error::new(ErrorCode::InvalidArgument, "duplicate method"));
        }
        Ok(())
    }
    pub fn get(&self, id: &str) -> Result<&Method> {
        self.methods.get(id).ok_or_else(|| {
            Error::new(
                ErrorCode::WorkflowValidation,
                format!("unknown method: {id}"),
            )
        })
    }
    pub fn list(&self, domain: &str) -> Vec<Json> {
        self.methods
            .values()
            .filter(|method| domain.is_empty() || method.domain == domain)
            .map(Method::to_json)
            .collect()
    }
}

#[derive(Debug, Clone)]
pub struct WorkflowStep {
    pub method: String,
    pub parameters: Json,
}

#[derive(Debug, Clone, Default)]
pub struct Workflow {
    pub name: String,
    pub version: i32,
    pub domain: String,
    pub steps: Vec<WorkflowStep>,
}

impl Workflow {
    pub fn to_json(&self) -> Json {
        json!({"name": self.name, "version": self.version, "domain": self.domain, "steps": self.steps.iter().map(|step| json!({"method": step.method, "parameters": step.parameters})).collect::<Vec<_>>()})
    }
    pub fn from_json(value: &Json) -> Result<Self> {
        let object = value.as_object().ok_or_else(|| {
            Error::new(ErrorCode::WorkflowValidation, "workflow must be an object")
        })?;
        let steps = object
            .get("steps")
            .and_then(Value::as_array)
            .ok_or_else(|| Error::new(ErrorCode::WorkflowValidation, "workflow requires steps"))?
            .iter()
            .map(|item| {
                Ok(WorkflowStep {
                    method: item
                        .get("method")
                        .and_then(Value::as_str)
                        .ok_or_else(|| {
                            Error::new(ErrorCode::WorkflowValidation, "step requires method")
                        })?
                        .to_owned(),
                    parameters: item.get("parameters").cloned().unwrap_or_else(|| json!({})),
                })
            })
            .collect::<Result<Vec<_>>>()?;
        Ok(Self {
            name: object
                .get("name")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_owned(),
            version: object.get("version").and_then(Value::as_i64).unwrap_or(1) as i32,
            domain: object
                .get("domain")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_owned(),
            steps,
        })
    }
    pub fn validate(&self, registry: &MethodRegistry) -> Result<()> {
        let mut prior = Vec::new();
        let mut counts = HashMap::new();
        for step in &self.steps {
            let method = registry.get(&step.method)?;
            if !self.domain.is_empty() && !method.domain.is_empty() && self.domain != method.domain
            {
                return Err(Error::new(
                    ErrorCode::WorkflowValidation,
                    "workflow domain mismatch",
                ));
            }
            for required in &method.required_methods {
                if !prior.contains(required) {
                    return Err(Error::new(
                        ErrorCode::WorkflowValidation,
                        format!("required method is not earlier in workflow: {required}"),
                    ));
                }
            }
            let count = counts.entry(step.method.clone()).or_insert(0);
            *count += 1;
            if method.max_occurrences > 0 && *count > method.max_occurrences {
                return Err(Error::new(
                    ErrorCode::WorkflowValidation,
                    format!("method occurs too many times: {}", step.method),
                ));
            }
            method.resolve(&step.parameters)?;
            prior.push(step.method.clone());
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct CacheEntry {
    pub name: String,
    pub description: String,
    pub hash: String,
    pub data: Vec<u8>,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct AuditEntry {
    pub operation_type: String,
    pub object_type: String,
    pub details: Json,
    pub created_at: String,
}

/// DuckDB-backed project and its workflow state.
pub struct Project {
    options: ProjectOptions,
    info: ProjectInfo,
}

impl Project {
    /// Creates a new project database and initializes its schema.
    pub fn create(options: ProjectOptions) -> Result<Self> {
        if options.database_path.exists() {
            return Err(Error::new(
                ErrorCode::ProjectAlreadyExists,
                "database already exists",
            ));
        }
        if let Some(parent) = options.database_path.parent() {
            if !parent.as_os_str().is_empty() {
                fs::create_dir_all(parent)
                    .map_err(|error| Error::new(ErrorCode::DatabaseError, error.to_string()))?;
            }
        }
        let project = Self::initialize(options)?;
        project.audit("create", "project", json!({}))?;
        Ok(project)
    }

    /// Opens an existing project database.
    pub fn open(options: ProjectOptions) -> Result<Self> {
        if !options.database_path.exists() {
            if options.create_if_missing {
                return Self::create(options);
            }
            return Err(Error::new(
                ErrorCode::ProjectNotFound,
                "database does not exist",
            ));
        }
        Self::initialize(options)
    }

    fn initialize(options: ProjectOptions) -> Result<Self> {
        let mut project = Self {
            options,
            info: ProjectInfo {
                id: String::new(),
                domain: String::new(),
                metadata: json!({}),
                schema_version: 1,
                framework_version: "0.1.0".into(),
                created_at: String::new(),
            },
        };
        let connection = project.connection()?;
        if !project.options.read_only {
            connection.execute_batch("CREATE TABLE IF NOT EXISTS PROJECT (project_id VARCHAR NOT NULL PRIMARY KEY, domain VARCHAR, metadata JSON, workflow JSON, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, schema_version INTEGER NOT NULL DEFAULT 1, framework_version VARCHAR NOT NULL DEFAULT '0.1.0'); CREATE TABLE IF NOT EXISTS CACHE (project_id VARCHAR NOT NULL, name VARCHAR NOT NULL, description VARCHAR NOT NULL, hash VARCHAR NOT NULL, data BLOB NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(project_id, hash)); CREATE TABLE IF NOT EXISTS AUDIT_TRAIL (project_id VARCHAR NOT NULL, operation_type VARCHAR NOT NULL, object_type VARCHAR NOT NULL, operation_details JSON, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);")?;
            connection.execute("INSERT INTO PROJECT (project_id, domain, metadata, workflow) VALUES (?1, ?2, '{}', '{\"name\":\"\",\"version\":1,\"domain\":\"\",\"steps\":[]}') ON CONFLICT(project_id) DO NOTHING", params![project.options.project_id, project.options.domain])?;
        }
        let row = connection.query_row("SELECT project_id, COALESCE(domain, ''), COALESCE(metadata, '{}'), schema_version, framework_version, CAST(created_at AS VARCHAR) FROM PROJECT WHERE project_id = ?1", params![project.options.project_id], |row| Ok(ProjectInfo { id: row.get(0)?, domain: row.get(1)?, metadata: serde_json::from_str(&row.get::<_, String>(2)?).unwrap_or_else(|_| json!({})), schema_version: row.get(3)?, framework_version: row.get(4)?, created_at: row.get(5)? }))?;
        project.info = row;
        Ok(project)
    }

    fn connection(&self) -> Result<Connection> {
        let extension_directory = self
            .options
            .database_path
            .parent()
            .unwrap_or_else(|| Path::new("."))
            .join(".streamfind-duckdb-extensions")
            .join(
                self.options
                    .database_path
                    .file_name()
                    .unwrap_or_else(|| std::ffi::OsStr::new("default")),
            );
        fs::create_dir_all(&extension_directory)
            .map_err(|error| Error::new(ErrorCode::DatabaseError, error.to_string()))?;
        let config = Config::default().with(
            "extension_directory",
            extension_directory.to_string_lossy().as_ref(),
        )?;
        Ok(Connection::open_with_flags(
            &self.options.database_path,
            config,
        )?)
    }

    pub fn execute_sql(&self, sql: &str) -> Result<()> {
        if self.options.read_only {
            return Err(Error::new(
                ErrorCode::InvalidArgument,
                "project is read-only",
            ));
        }
        self.connection()?.execute_batch(sql)?;
        Ok(())
    }

    pub fn query_json(&self, sql: &str) -> Result<Json> {
        let connection = self.connection()?;
        let mut metadata_statement = connection.prepare(sql)?;
        let _ = metadata_statement.query([])?;
        let columns = metadata_statement.column_count();
        let names: Vec<String> = (0..columns)
            .map(|i| {
                metadata_statement
                    .column_name(i)
                    .map(String::clone)
                    .unwrap_or_default()
            })
            .collect();
        let mut statement = connection.prepare(sql)?;
        let mut rows = statement.query([])?;
        let mut output = Vec::new();
        while let Some(row) = rows.next()? {
            let mut object = serde_json::Map::new();
            for (i, name) in names.iter().enumerate() {
                object.insert(name.clone(), duck_value_to_json(row.get(i)?));
            }
            output.push(Json::Object(object));
        }
        Ok(Json::Array(output))
    }

    pub fn info(&self) -> &ProjectInfo {
        &self.info
    }
    /// Returns a copy of the project metadata.
    pub fn get_metadata(&self) -> Json {
        self.info.metadata.clone()
    }
    pub fn get_database_path(&self) -> &Path {
        &self.options.database_path
    }
    pub fn get_project_id(&self) -> &str {
        &self.options.project_id
    }
    pub fn get_domain(&self) -> String {
        self.info.domain.clone()
    }
    pub fn validate(&self) -> Result<()> {
        let tables = self.list_tables()?;
        for required in ["PROJECT", "CACHE", "AUDIT_TRAIL"] {
            if !tables.iter().any(|table| table == required) {
                return Err(Error::new(
                    ErrorCode::SchemaMismatch,
                    format!("missing required table: {required}"),
                ));
            }
        }
        self.get_workflow()?;
        Ok(())
    }
    pub fn list_tables(&self) -> Result<Vec<String>> {
        let connection = self.connection()?;
        let mut statement = connection.prepare("SELECT table_name FROM information_schema.tables WHERE table_schema = 'main' ORDER BY table_name")?;
        Ok(statement
            .query_map([], |row| row.get(0))?
            .collect::<std::result::Result<Vec<String>, _>>()?)
    }
    pub fn set_metadata(&mut self, metadata: Json) -> Result<()> {
        self.connection()?.execute(
            "UPDATE PROJECT SET metadata = ?1 WHERE project_id = ?2",
            params![metadata.to_string(), self.get_project_id()],
        )?;
        self.info.metadata = metadata;
        Ok(())
    }
    pub fn get_workflow(&self) -> Result<Workflow> {
        let text: String = self.connection()?.query_row(
            "SELECT workflow FROM PROJECT WHERE project_id = ?1",
            params![self.get_project_id()],
            |row| row.get(0),
        )?;
        Workflow::from_json(
            &serde_json::from_str(&text)
                .map_err(|error| Error::new(ErrorCode::SchemaMismatch, error.to_string()))?,
        )
    }
    pub fn set_workflow(
        &mut self,
        mut workflow: Workflow,
        registry: &MethodRegistry,
    ) -> Result<()> {
        let previous = self.get_workflow()?;
        workflow.version = workflow.version.max(previous.version + 1);
        workflow.validate(registry)?;
        self.connection()?.execute(
            "UPDATE PROJECT SET workflow = ?1 WHERE project_id = ?2",
            params![workflow.to_json().to_string(), self.get_project_id()],
        )?;
        Ok(())
    }
    pub fn copy(&self, options: ProjectOptions) -> Result<Self> {
        let workflow = self.get_workflow()?.to_json();
        let mut destination_options = options;
        destination_options.domain = self.info.domain.clone();
        let mut destination = Self::create(destination_options)?;
        destination.set_metadata(self.info.metadata.clone())?;
        destination.connection()?.execute(
            "UPDATE PROJECT SET workflow = ?1 WHERE project_id = ?2",
            params![workflow.to_string(), destination.get_project_id()],
        )?;
        for entry in self.get_cache()? {
            let value = serde_json::from_slice(&entry.data)
                .map_err(|error| Error::new(ErrorCode::SchemaMismatch, error.to_string()))?;
            destination.set_cache(&entry.name, &entry.description, &entry.hash, &value)?;
        }
        Ok(destination)
    }
    pub fn get_cache(&self) -> Result<Vec<CacheEntry>> {
        let connection = self.connection()?;
        let mut statement = connection.prepare("SELECT name, description, hash, data, CAST(created_at AS VARCHAR) FROM CACHE WHERE project_id = ?1 ORDER BY created_at DESC")?;
        let rows = statement
            .query_map(params![self.get_project_id()], |row| {
                Ok(CacheEntry {
                    name: row.get(0)?,
                    description: row.get(1)?,
                    hash: row.get(2)?,
                    data: row.get(3)?,
                    created_at: row.get(4)?,
                })
            })?
            .collect::<std::result::Result<Vec<_>, _>>()?;
        Ok(rows)
    }
    pub fn get_cache_size(&self) -> Result<usize> {
        Ok(self.get_cache()?.len())
    }
    pub fn get_cache_entry(&self, hash: &str) -> Result<Option<CacheEntry>> {
        Ok(self.connection()?.query_row("SELECT name, description, hash, data, CAST(created_at AS VARCHAR) FROM CACHE WHERE project_id = ?1 AND hash = ?2", params![self.get_project_id(), hash], |row| Ok(CacheEntry { name: row.get(0)?, description: row.get(1)?, hash: row.get(2)?, data: row.get(3)?, created_at: row.get(4)? })).optional()?)
    }
    pub fn set_cache(
        &mut self,
        name: &str,
        description: &str,
        hash: &str,
        value: &Json,
    ) -> Result<()> {
        self.connection()?.execute("INSERT INTO CACHE (project_id, name, description, hash, data) VALUES (?1, ?2, ?3, ?4, ?5) ON CONFLICT(project_id, hash) DO UPDATE SET name = excluded.name, description = excluded.description, data = excluded.data", params![self.get_project_id(), name, description, hash, value.to_string().into_bytes()])?;
        Ok(())
    }
    pub fn delete_cache(&mut self) -> Result<()> {
        self.connection()?.execute(
            "DELETE FROM CACHE WHERE project_id = ?1",
            params![self.get_project_id()],
        )?;
        self.audit("delete", "cache", json!({}))
    }
    pub fn get_audit_trail(&self) -> Result<Vec<AuditEntry>> {
        let connection = self.connection()?;
        let mut statement = connection.prepare("SELECT operation_type, object_type, COALESCE(operation_details, '{}'), CAST(created_at AS VARCHAR) FROM AUDIT_TRAIL WHERE project_id = ?1 ORDER BY created_at ASC")?;
        let rows = statement
            .query_map(params![self.get_project_id()], |row| {
                Ok(AuditEntry {
                    operation_type: row.get(0)?,
                    object_type: row.get(1)?,
                    details: serde_json::from_str(&row.get::<_, String>(2)?)
                        .unwrap_or_else(|_| json!({})),
                    created_at: row.get(3)?,
                })
            })?
            .collect::<std::result::Result<Vec<_>, _>>()?;
        Ok(rows)
    }
    pub fn run_method(
        &mut self,
        method_id: &str,
        parameters: &Json,
        registry: &MethodRegistry,
    ) -> Result<Json> {
        let method = registry.get(method_id)?;
        let mut workflow = self.get_workflow()?;
        workflow.domain = if workflow.domain.is_empty() {
            self.get_domain()
        } else {
            workflow.domain
        };
        workflow.steps.push(WorkflowStep {
            method: method_id.into(),
            parameters: parameters.clone(),
        });
        self.set_workflow(workflow, registry)?;
        let resolved = method.resolve(parameters)?;
        self.audit(
            "start",
            "method",
            json!({"method": method_id, "parameters": resolved}),
        )?;
        let result = method.run(self, &resolved)?;
        self.audit("complete", "method", json!({"method": method_id}))?;
        Ok(result)
    }
    pub fn run_operation(
        &mut self,
        operation_id: &str,
        parameters: &Json,
        registry: &OperationRegistry,
    ) -> Result<Json> {
        let operation = registry.get(operation_id)?;
        operation.run(self, parameters)
    }
    pub fn close(self) {}
    pub fn run_workflow(
        &mut self,
        workflow: &Workflow,
        registry: &MethodRegistry,
        cancellation: Option<&CancellationToken>,
        progress: Option<&dyn Fn(&ProgressEvent)>,
    ) -> Result<ExecutionResult> {
        workflow.validate(registry)?;
        let mut results = Vec::new();
        for (index, step) in workflow.steps.iter().enumerate() {
            if cancellation.is_some_and(CancellationToken::is_cancelled) {
                return Ok(ExecutionResult {
                    results: Json::Array(results),
                    cancelled: true,
                });
            }
            let method = registry.get(&step.method)?;
            let parameters = method.resolve(&step.parameters)?;
            let key = cache_key(self.get_project_id(), &method.id, &parameters);
            if method.cacheable {
                if let Some(entry) = self.get_cache_entry(&key)? {
                    results.push(serde_json::from_slice(&entry.data).map_err(|error| {
                        Error::new(ErrorCode::SchemaMismatch, error.to_string())
                    })?);
                    self.audit(
                        "cache_hit",
                        "workflow_step",
                        json!({"method": method.id, "cache_key": key}),
                    )?;
                    continue;
                }
                self.audit(
                    "cache_miss",
                    "workflow_step",
                    json!({"method": method.id, "cache_key": key}),
                )?;
            }
            self.audit("start", "workflow_step", json!({"method": method.id}))?;
            let result = method.run(self, &parameters)?;
            if method.cacheable {
                self.set_cache(&method.id, "workflow result", &key, &result)?;
            }
            results.push(result);
            if let Some(progress) = progress {
                progress(&ProgressEvent {
                    operation: "workflow".into(),
                    completed: index + 1,
                    total: workflow.steps.len(),
                });
            }
            self.audit(
                "complete",
                "workflow_step",
                json!({"method": method.id, "cache_key": key}),
            )?;
        }
        Ok(ExecutionResult {
            results: Json::Array(results),
            cancelled: false,
        })
    }
    fn audit(&self, operation: &str, object: &str, details: Json) -> Result<()> {
        if self.options.read_only {
            return Ok(());
        }
        self.connection()?.execute("INSERT INTO AUDIT_TRAIL (project_id, operation_type, object_type, operation_details) VALUES (?1, ?2, ?3, ?4)", params![self.get_project_id(), operation, object, details.to_string()])?;
        Ok(())
    }
}
