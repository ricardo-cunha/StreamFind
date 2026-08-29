use streamfind_rust_mass_spec::reader_agilent_ims;

#[test]
fn reads_masshunter_ion_mobility_frame_metadata() {
    let Ok(path) = std::env::var("STREAMFIND_AGILENT_IMS_FIXTURE") else {
        return;
    };
    assert!(reader_agilent_ims::is_agilent_ion_mobility_directory(
        std::path::Path::new(&path)
    ));
    let frames = reader_agilent_ims::read_frame_records(&path).expect("IMS frame records");
    assert_eq!(frames.len(), 103);
    assert_eq!(frames.first().unwrap().frame_id, 1);
    assert_eq!(frames.last().unwrap().frame_id, 103);
    let first = &frames[0];
    assert_eq!(first.frame_method_id, 1);
    assert_eq!(first.time_segment_id, 1);
    assert_eq!(first.first_nonzero_drift_bin, 1);
    assert_eq!(first.frame_base_abundance, 55227.0);
    assert_eq!(first.frame_base_drift_bin, 152);
    assert_eq!(first.frame_base_ms_bin, 145591);
    assert!((first.frame_scan_time_minutes - 0.05143333333333333).abs() < 1e-12);
    assert_eq!(first.frame_tic, 15541141.0);
    assert!((first.ims_pressure - 3.94).abs() < 1e-6);
    assert_eq!(first.ims_temperature, 26.0);
    assert_eq!(first.ims_trap_time, 20000.0);
    assert_eq!(first.last_nonzero_drift_bin, 366);
    assert_eq!(first.num_transients, 19);
}
