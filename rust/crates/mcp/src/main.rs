use std::io::{self, BufRead, Write};
use streamfind_rust_core::MethodRegistry;

fn main() {
    let registry = MethodRegistry::default();
    let mut session = streamfind_rust_mcp::Session::new(&registry);
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
