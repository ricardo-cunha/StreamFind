use streamfind_rust_core::{MethodRegistry, OperationRegistry};
use streamfind_rust_test_support::catalogue_entries;

#[test]
fn composes_all_starting_domains_without_fake_methods() {
    let mut registry = MethodRegistry::default();
    let mut operations = OperationRegistry::default();
    streamfind_rust_mass_spec::register_operations(&mut operations).unwrap();
    streamfind_rust_mass_spec::register_methods(&mut registry).unwrap();
    streamfind_rust_raman::register_methods(&mut registry).unwrap();
    streamfind_rust_sensors::register_methods(&mut registry).unwrap();
    // Expectations are derived from the committed semantic catalogue (the same
    // contract the registries are generated from), so they adapt automatically
    // when operations/methods are added or removed.
    let entries = catalogue_entries();
    let mass_spec_operations = entries
        .iter()
        .filter(|entry| entry["kind"] == "operation" && entry["domain"] == "mass_spec")
        .count();
    let mass_spec_methods = entries
        .iter()
        .filter(|entry| entry["kind"] == "method" && entry["domain"] == "mass_spec")
        .count();
    let raman_methods = entries
        .iter()
        .filter(|entry| entry["kind"] == "method" && entry["domain"] == "raman")
        .count();
    let sensors_methods = entries
        .iter()
        .filter(|entry| entry["kind"] == "method" && entry["domain"] == "sensors")
        .count();
    assert_eq!(operations.list("mass_spec").len(), mass_spec_operations);
    assert_eq!(registry.list("raman").len(), raman_methods);
    assert_eq!(registry.list("mass_spec").len(), mass_spec_methods);
    assert_eq!(registry.list("sensors").len(), sensors_methods);
    // No fake methods: every registered method id must exist in the catalogue.
    for definition in registry.list("") {
        assert!(entries
            .iter()
            .any(|entry| entry["canonical_id"] == definition["id"]));
    }
}
