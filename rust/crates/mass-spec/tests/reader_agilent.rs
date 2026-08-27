use streamfind_rust_mass_spec::reader_agilent;

#[test]
fn reads_agilent_masshunter_scan_index() {
    let path = std::path::Path::new(
        r"E:\example_files\raw_vendor_files\agilent_mass_hunter\022_Aceton_Uracil_Mix1_10-r001.d",
    );
    assert!(reader_agilent::is_agilent_mass_hunter_directory(path));
    let records = reader_agilent::read_scan_records(path).unwrap();
    assert_eq!(records.len(), 7870);
    assert_eq!(records[0].scan_id, 182612);
    assert_eq!(records[1].scan_id, 182812);
    assert!((records[0].scan_time_minutes - 3.0434).abs() < 1e-9);
    assert!((records[1].scan_time_minutes - 3.04673333333333).abs() < 1e-9);
    assert_eq!(records[0].ms_level, 1);
    assert_eq!(records[0].tic, 29486.0);
    assert!((records[0].base_peak_mz - 959.961571698238).abs() < 1e-9);
    assert_eq!(records[0].base_peak_value, 302.0);
    assert_eq!(records[0].spectrum_format_id, 1);
    assert_eq!(records[0].spectrum_offset, 68);
    assert_eq!(records[0].spectrum_byte_count, 18814);
    assert_eq!(records[0].spectrum_point_count, 165344);
    assert_eq!(records[0].spectrum_uncompressed_byte_count, 661392);
    assert!((records[0].spectrum_min_x - 50.00131445032414).abs() < 1e-9);
    assert!((records[0].spectrum_max_x - 1199.3268123619305).abs() < 1e-9);
    let profile = reader_agilent::read_profile_spectrum(path, &records[0]).unwrap();
    assert_eq!(profile.mz.len(), 165344);
    assert_eq!(profile.intensity.len(), profile.mz.len());
    assert!((profile.mz[0] - 50.00131445032414).abs() < 1e-5);
    assert!((profile.mz.last().unwrap() - 1199.3268123619305).abs() < 1e-4);
    assert_eq!(profile.intensity.iter().sum::<f32>(), 29486.0);
    assert_eq!(profile.intensity.iter().copied().fold(0.0, f32::max), 302.0);
    for record in &records[..3] {
        let check = reader_agilent::read_profile_spectrum(path, record).unwrap();
        assert!((check.intensity.iter().map(|value| *value as f64).sum::<f64>() - record.tic).abs() < 0.5);
        assert!((check.intensity.iter().copied().fold(0.0, f32::max) as f64 - record.base_peak_value).abs() < 0.5);
    }
}
