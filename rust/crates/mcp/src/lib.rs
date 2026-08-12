//! Minimal MCP JSON-RPC adapter for the Rust Streamfind core.

use serde_json::{json, Value};
use streamfind_rust_core::{api, MethodRegistry};

pub struct Session<'a> {
    registry: &'a MethodRegistry,
    project: Option<Value>,
    domain: String,
}

impl<'a> Session<'a> {
    pub fn new(registry: &'a MethodRegistry) -> Self {
        Self {
            registry,
            project: None,
            domain: String::new(),
        }
    }

    pub fn handle(&mut self, request: &Value) -> Value {
        let id = request.get("id").cloned().unwrap_or(Value::Null);
        let method = request
            .get("method")
            .and_then(Value::as_str)
            .unwrap_or_default();
        if method == "tools/list" {
            let mut catalogue = tools().as_array().cloned().unwrap_or_default();
            for definition in self.registry.list(&self.domain) {
                let parameters = definition["parameters"]
                    .as_array()
                    .cloned()
                    .unwrap_or_default();
                let properties =
                    parameters
                        .iter()
                        .fold(serde_json::Map::new(), |mut properties, parameter| {
                            if let Some(name) = parameter["name"].as_str() {
                                properties.insert(name.into(), parameter["type"].clone());
                            }
                            properties
                        });
                let required = parameters
                    .iter()
                    .filter_map(|p| {
                        (p["required"].as_bool() == Some(true))
                            .then(|| p["name"].as_str())
                            .flatten()
                    })
                    .collect::<Vec<_>>();
                catalogue.push(json!({"name": definition["id"], "description": definition["description"], "inputSchema": {"type": "object", "properties": properties, "required": required}}));
            }
            return json!({"jsonrpc":"2.0","id":id,"result":{"tools":catalogue}});
        }
        if method == "tools/call" {
            let params = request.get("params").cloned().unwrap_or_else(|| json!({}));
            let name = params
                .get("name")
                .and_then(Value::as_str)
                .unwrap_or_default();
            if name == "project_connect" {
                let args = params.get("arguments").unwrap_or(&Value::Null);
                return match api::get_domain(args) {
                    Ok(domain) => {
                        self.domain = domain.as_str().unwrap_or_default().into();
                        self.project = Some(args.clone());
                        response(id, json!({"domain": self.domain}))
                    }
                    Err(error) => error_response(id, error.to_string()),
                };
            }
            if !tools()
                .as_array()
                .unwrap()
                .iter()
                .any(|tool| tool["name"] == name)
                && self
                    .registry
                    .list(&self.domain)
                    .iter()
                    .any(|tool| tool["id"] == name)
            {
                let mut args = self.project.clone().unwrap_or_else(|| json!({}));
                args["method"] = json!(name);
                args["parameters"] = params
                    .get("arguments")
                    .cloned()
                    .unwrap_or_else(|| json!({}));
                return match api::run_method(&args, self.registry) {
                    Ok(value) => response(id, value),
                    Err(error) => error_response(id, error.to_string()),
                };
            }
        }
        handle(request, self.registry)
    }
}

pub fn tools() -> Value {
    let project = json!({"type": "string"});
    let metadata = json!({"type": "object"});
    let workflow = json!({"type": "object"});
    let base = json!({"database_path": project, "project_id": project});
    let required = ["database_path", "project_id"];
    [
        ("project_create", "Create a project"),
        ("project_connect", "Connect this MCP session to a project"),
        ("project_describe", "Describe a project"),
        ("project_validate", "Validate a project"),
        ("project_get_domain", "Read the project domain"),
        ("project_get_metadata", "Read project metadata"),
        ("project_set_metadata", "Set project metadata"),
        ("project_get_workflow", "Read the project workflow"),
        ("project_set_workflow", "Set the project workflow"),
        ("project_validate_workflow", "Validate a workflow"),
        ("project_run_workflow", "Run the project workflow"),
        ("project_get_cache", "Read project cache"),
        ("project_get_cache_size", "Read project cache size"),
        ("project_delete_cache", "Delete project cache"),
        ("project_get_audit_trail", "Read project audit events"),
        (
            "get_available_methods",
            "List methods registered for a domain",
        ),
        ("project_run_method", "Append and run a workflow method"),
        ("project_copy", "Copy a project"),
        ("project_close", "Close a project handle"),
    ]
    .iter()
    .map(|(name, description)| {
        let mut properties = base.clone();
        let mut required = required.to_vec();
        match *name {
            "project_validate_workflow" => {
                properties = json!({"workflow": workflow});
                required = vec!["workflow"];
            }
            "project_create" => {
                properties["domain"] = project.clone();
                required.push("domain");
            }
            "project_set_metadata" => {
                properties["metadata"] = metadata.clone();
                required.push("metadata");
            }
            "project_set_workflow" => {
                properties["workflow"] = workflow.clone();
                required.push("workflow");
            }
            "get_available_methods" => {
                properties = json!({"domain": project});
                required = vec!["domain"];
            }
            "project_run_method" => {
                properties["method"] = project.clone();
                properties["parameters"] = json!({"type": "object"});
                required.push("method");
            }
            "project_copy" => {
                properties["destination_database_path"] = project.clone();
                properties["destination_project_id"] = project.clone();
                required.extend(["destination_database_path", "destination_project_id"]);
            }
            _ => {}
        }
        json!({
            "name": name,
            "description": description,
            "inputSchema": {"type": "object", "properties": properties, "required": required}
        })
    })
    .collect()
}

pub fn handle(request: &Value, _registry: &MethodRegistry) -> Value {
    let id = request.get("id").cloned().unwrap_or(Value::Null);
    let method = request
        .get("method")
        .and_then(Value::as_str)
        .unwrap_or_default();
    if method == "initialize" {
        return json!({"jsonrpc":"2.0","id":id,"result":{"protocolVersion":"2025-03-26","capabilities":{"tools":{}},"serverInfo":{"name":"streamfind-rust","version":"0.1.0"}}});
    }
    if method == "tools/list" {
        return json!({"jsonrpc":"2.0","id":id,"result":{"tools":tools()}});
    }
    if method != "tools/call" {
        return json!({"jsonrpc":"2.0","id":id,"error":{"code":-32601,"message":"Unsupported MCP method"}});
    }
    let params = request.get("params").cloned().unwrap_or_else(|| json!({}));
    let name = params
        .get("name")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let args = params.get("arguments").unwrap_or(&Value::Null);
    let result = match name {
        "project_create" => api::create(args),
        "project_describe" => api::describe(args),
        "project_validate" => api::validate(args),
        "project_get_domain" => api::get_domain(args),
        "project_get_metadata" => api::get_metadata(args),
        "project_set_metadata" => api::set_metadata(args),
        "project_get_workflow" => api::get_workflow(args),
        "project_set_workflow" => api::set_workflow(args, _registry),
        "project_validate_workflow" => api::validate_workflow(args, _registry),
        "project_run_workflow" => api::run_workflow(args, _registry),
        "project_get_cache" => api::get_cache(args),
        "project_get_cache_size" => api::get_cache_size(args),
        "project_delete_cache" => api::delete_cache(args),
        "project_get_audit_trail" => api::get_audit_trail(args),
        "get_available_methods" => api::get_available_methods(args, _registry),
        "project_run_method" => api::run_method(args, _registry),
        "project_copy" => api::copy(args),
        "project_close" => api::close(args),
        _ => {
            return json!({"jsonrpc":"2.0","id":id,"error":{"code":-32602,"message":"Unknown MCP tool"}})
        }
    };
    match result {
        Ok(value) => {
            json!({"jsonrpc":"2.0","id":id,"result":{"content":[{"type":"text","text":value.to_string()}]}})
        }
        Err(error) => {
            json!({"jsonrpc":"2.0","id":id,"result":{"isError":true,"content":[{"type":"text","text":error.to_string()}]}})
        }
    }
}

fn response(id: Value, value: Value) -> Value {
    json!({"jsonrpc":"2.0","id":id,"result":{"content":[{"type":"text","text":value.to_string()}]}})
}

fn error_response(id: Value, error: String) -> Value {
    json!({"jsonrpc":"2.0","id":id,"result":{"isError":true,"content":[{"type":"text","text":error}]}})
}
