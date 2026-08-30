#![cfg(feature = "reader-interface-tests")]

use streamfind_rust_mass_spec::reader_bruker::{self, Family};

#[test]
fn reads_bruker_tsf_metadata_with_duckdb_sqlite_extension() {
    let path = std::path::Path::new(
        r"E:\example_files\ms_merck\Beispieldaten Routine\ACC1_28127_1_blank_P1-A-1_1_2022_13602.d",
    );
    assert_eq!(reader_bruker::detect_family(path), Family::Tsf);
    let frames = reader_bruker::read_tsf_frames(path).unwrap();
    assert_eq!(frames.len(), 4451);
    assert_eq!(frames[0].id, 1);
    assert_eq!(frames[0].polarity, "+");
    assert!((frames[0].retention_time - 0.5966953).abs() < 1e-7);
    assert_eq!(frames[0].num_peaks, 1561);
    assert_eq!(frames[0].summed_intensities, 47320.0);
    let msms = reader_bruker::read_tsf_msms_info(path).unwrap();
    assert_eq!(msms.len(), 2556);
    assert_eq!(msms[0].frame, 98);
    assert_eq!(msms[0].parent, 97);
    assert!((msms[0].trigger_mass - 922.0137960978609).abs() < 1e-9);
    assert_eq!(msms[0].precursor_charge, 1);
    let calibration = reader_bruker::read_tsf_calibration(path, &frames[0]).unwrap();
    assert_eq!(calibration.id, 1);
    assert_eq!(calibration.model_type, 1);
    assert_eq!(calibration.tof_max, 513299);
    assert_eq!(calibration.mz_min, 100.0);
    assert_eq!(calibration.mz_max, 2500.0);
    assert!(calibration.c1 > 154000.0);
    let mz = reader_bruker::tsf_tof_to_mz(&calibration, &[0.0, 344.7142857142857, 513299.0]);
    assert!((mz[0] - 95.0).abs() < 1e-12);
    assert!((mz[1] - 95.52835104408595).abs() < 1e-9);
    assert!((mz[2] - 2505.0).abs() < 1e-9);
    for (frame_index, expected_count, expected_max, expected_tof) in
        [(0, 1561, 908.0, 344.7142857142857), (1, 1414, 692.0, 455.0),
         (2, 1570, 642.0, 39.0), (97, 1521, 44732.0, 133.94230769230768),
         (99, 786, 2270.0, 678.5135135135135), (4450, 3087, 280.0, 121.0)]
    {
        let line = reader_bruker::read_tsf_line_spectrum(path, &frames[frame_index]).unwrap();
        assert_eq!(line.tof.len(), expected_count);
        assert_eq!(line.intensity.len(), expected_count);
        assert!((line.tof[0] - expected_tof).abs() < 1e-12);
        assert_eq!(line.intensity.iter().copied().fold(0.0, f64::max), expected_max);
    }
}
