use streamfind_rust_core::{MethodRegistry, OperationRegistry};

#[test]
fn composes_all_starting_domains_without_fake_methods() {
    let mut registry = MethodRegistry::default();
    let mut operations = OperationRegistry::default();
    streamfind_rust_mass_spec::register_operations(&mut operations).unwrap();
    streamfind_rust_raman::register_methods(&mut registry).unwrap();
    streamfind_rust_sensors::register_methods(&mut registry).unwrap();
    assert_eq!(operations.list("mass_spec").len(), 3);
    assert_eq!(registry.list("raman").len(), 2);
    assert!(registry.list("sensors").is_empty());
}
