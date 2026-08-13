use streamfind_rust_core::{
    MethodRegistry, Operation, OperationRegistry, ParameterDefinition, ParameterSchema, ParameterType,
    Result, TypeDescriptor,
};

pub fn register_methods(registry: &mut MethodRegistry) -> Result<()> {
    let _ = registry;
    Ok(())
}

pub fn register_operations(registry: &mut OperationRegistry) -> Result<()> {
    for id in ["mass_spec.add_analyses", "mass_spec.remove_analyses", "mass_spec.get_analyses_info"] {
        if id.ends_with("get_analyses_info") {
            registry.register(Operation::new(id, id, "Mass spectrometry analysis information", "mass_spec", ParameterSchema { definitions: vec![] }, Box::new(|_, _| Ok(serde_json::json!([])))))?;
            continue;
        }
        let parameter = if id.ends_with("remove_analyses") {
            "analysis_names"
        } else {
            "analyses"
        };
        registry.register(Operation::new(
            id,
            id,
            "Placeholder mass spectrometry analysis operation",
            "mass_spec",
            ParameterSchema {
                definitions: vec![ParameterDefinition {
                    name: parameter.into(),
                    description: "Analysis file records or names".into(),
                    kind: TypeDescriptor::array(if id.ends_with("remove_analyses") { TypeDescriptor::scalar(ParameterType::String) } else { TypeDescriptor::scalar(ParameterType::Object) }),
                    default: None,
                    required: true,
                }],
            },
            Box::new(|_, _| Ok(serde_json::json!([]))),
        ))?;
    }
    Ok(())
}
