use std::io::{self, BufRead, Write};
use streamfind_rust_core::{MethodRegistry, OperationRegistry};

fn main() {
    let mut registry = MethodRegistry::default();
    let mut operations = OperationRegistry::default();
    streamfind_rust_mass_spec::register_operations(&mut operations).unwrap();
    streamfind_rust_raman::register_methods(&mut registry).unwrap();
    streamfind_rust_sensors::register_methods(&mut registry).unwrap();
    let mut session = streamfind_rust_mcp::Session::new(&registry, &operations);
    for line in io::stdin().lock().lines() {
        let response = match line {
            Ok(line) => session.handle(&serde_json::from_str(&line).unwrap_or_default()),
            Err(error) => {
                serde_json::json!({"jsonrpc":"2.0","error":{"code":-32700,"message":error.to_string()}})
            }
        };
        println!("{}", response);
        io::stdout().flush().unwrap();
    }
}
