use streamfind_rust_core::MethodRegistry;

#[test]
fn nta_interface_registers_catalogue_methods_without_data_files() {
    let entries = streamfind_rust_test_support::catalogue_entries();
    let expected = entries
        .iter()
        .filter(|entry| {
            entry["kind"] == "method"
                && entry["domain"] == "mass_spec"
                && entry["canonical_id"]
                    .as_str()
                    .is_some_and(|id| id.starts_with("mass_spec."))
        })
        .count();

    let mut methods = MethodRegistry::default();
    streamfind_rust_mass_spec::register_methods(&mut methods).unwrap();
    let registered = methods.list("mass_spec");
    assert_eq!(
        registered
            .iter()
            .filter(|method| {
                method["id"]
                    .as_str()
                    .is_some_and(|id| id.starts_with("mass_spec."))
            })
            .count(),
        expected
    );

    for id in [
        "mass_spec.find_features",
        "mass_spec.load_features_ms1",
        "mass_spec.load_features_ms2",
        "mass_spec.create_components",
        "mass_spec.annotate_components",
        "mass_spec.group_features",
        "mass_spec.fill_features",
        "mass_spec.subtract_blank",
        "mass_spec.correct_matrix_suppression",
        "mass_spec.filter_features",
        "mass_spec.suspect_screening",
        "mass_spec.find_internal_standards",
        "mass_spec.filter_suspects",
        "mass_spec.filter_internal_standards",
        "mass_spec.filter_features_ms2",
        "mass_spec.metfrag_screening",
        "mass_spec.assign_transformation_products",
    ] {
        assert!(methods.get(id).is_ok(), "missing NTA method {id}");
        let entry = entries
            .iter()
            .find(|entry| entry["canonical_id"] == id)
            .unwrap_or_else(|| panic!("missing catalogue entry for {id}"));
        assert_eq!(entry["kind"], "method");
        assert_eq!(entry["domain"], "mass_spec");
    }

    let find_features = methods.get("mass_spec.find_features").unwrap();
    assert!(find_features.cacheable);
    assert!(find_features.single_occurrence);
    assert!(find_features.required_methods.is_empty());
}
