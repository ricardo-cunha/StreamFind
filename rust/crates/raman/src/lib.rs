use streamfind_rust_core::{
    Error, ErrorCode, Method, MethodRegistry, ParameterDefinition, ParameterSchema, ParameterType,
    Result, TypeDescriptor,
};

pub fn register_methods(registry: &mut MethodRegistry) -> Result<()> {
    for id in ["raman.add_analyses", "raman.remove_analyses"] {
        let parameter = if id.ends_with("remove_analyses") {
            "analysis_names"
        } else {
            "analyses"
        };
        registry.register(
            Method::new(
                id,
                id,
                "Placeholder Raman analysis operation",
                "raman",
                ParameterSchema {
                    definitions: vec![ParameterDefinition {
                        name: parameter.into(),
                        description: "Analysis file records or names".into(),
                        kind: TypeDescriptor::scalar(ParameterType::Array),
                        default: None,
                        required: true,
                        example: None,
                    }],
                },
                Box::new(|_, _| {
                    Err(Error::new(
                        ErrorCode::MethodExecution,
                        "raman analysis operation is not implemented",
                    ))
                }),
            )
            .unimplemented(),
        )?;
    }
    Ok(())
}
