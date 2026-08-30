#![cfg(feature = "reader-interface-tests")]

use std::path::Path;
use streamfind_rust_mass_spec::reader_sciex::{
    decode_intensity_groups, decode_scan_payload, read_analysis_catalog, read_compact_mrm_pairs,
    read_event_records, read_idx_event_records, read_idx_float_records, read_idx_records, read_scan_blocks,
    read_scan_points, read_tagged_mrm_series, read_transitions, build_compact_mrm_series, ScanPoint,
};

#[test]
fn decodes_sciex_byte_tokens() {
    assert_eq!(decode_scan_payload(&[0x29, 0x81, 0xfd, 0x55, 0x01, 0xff, 0xff, 0xff, 0xff]), vec![
        ScanPoint { raw_mz_bin: 41, raw_intensity: 1 },
        ScanPoint { raw_mz_bin: 41, raw_intensity: 341 },
    ]);
}

#[test]
fn reads_sciex_catalog_transitions_and_event_groups() {
    let path = Path::new(r"E:\example_files\raw_vendor_files\sciex\250414_Mix1.wiff");
    if !path.exists() {
        return;
    }
    let catalog = read_analysis_catalog(path).unwrap();
    assert_eq!(catalog.len(), 37);
    assert_eq!(catalog[3].name, "0.009");
    assert_eq!(catalog[9].name, "0.9");
    assert_eq!(catalog[28].name, "0.9");

    let blocks = read_scan_blocks(path).unwrap();
    assert_eq!(blocks.len(), 37);
    assert_eq!(blocks[3].sample_number, 4);

    let idx = read_idx_records(path, 4).unwrap();
    assert!(!idx.is_empty());
    assert!(idx.windows(2).all(|pair| pair[0].scan_offset <= pair[1].scan_offset));
    assert!((idx[0].retention_time_minutes - 0.7005).abs() < 0.00001);
    let points = read_scan_points(path, &idx[0], idx.get(1));
    assert!(!points.unwrap().is_empty());
    let fragments = read_idx_float_records(path, 4).unwrap();
    assert_eq!(fragments.len(), 3421);
    assert!(fragments.iter().any(|record| record.fields.iter().any(|value| (*value + 59.01).abs() < 0.001)));
    let indexed_events = read_idx_event_records(path, 4).unwrap();
    assert!(indexed_events.len() > 3400);
    assert!(indexed_events.iter().all(|event| event.retention_time_minutes > 0.0));

    let transitions = read_transitions(path, 4).unwrap();
    assert_eq!(transitions.len(), 59);
    assert_eq!(transitions[0].name, "1H-Benzotriazol_1");
    assert!((transitions[0].start_time - 1.54082).abs() < 0.0001);
    assert!((transitions[0].end_time - 2.54402).abs() < 0.0001);

    let events = read_event_records(&blocks[3]).unwrap();
    assert_eq!(events.len(), 3427);
    let groups = decode_intensity_groups(&events[149]);
    assert_eq!(groups.len(), 2);
    assert_eq!(groups[0].field_code, -22);
    assert_eq!(groups[0].intensities, vec![68.0, 1155.0]);
    assert_eq!(groups[1].field_code, -14);
    assert_eq!(groups[1].intensities, vec![3245.0, 113.0]);
    let tagged = read_tagged_mrm_series(path, 4).unwrap();
    assert_eq!(tagged.transitions.len(), 59);
    assert_eq!(tagged.intensities[38].len(), 3421);
    assert!((tagged.retention_times[38][8] - 0.708483).abs() < 0.00001);
    assert_eq!(tagged.intensities[38][8], 3943.0);
    assert_eq!(tagged.intensities[39][8], 203.0);
}

#[test]
fn reads_pac_compact_mrm_metadata() {
    let path = Path::new(r"E:\example_files\raw_vendor_files\sciex\201023_Pac.wiff");
    if !path.exists() {
        return;
    }
    let transitions = read_transitions(path, 4).unwrap();
    assert_eq!(transitions.len(), 2);
    assert_eq!(transitions[0].name, "Pac 569");
    assert_eq!(transitions[1].name, "Pac 286");
}

#[test]
fn builds_pac_native_series_with_approximate_time_grid() {
    let path = Path::new(r"E:\example_files\raw_vendor_files\sciex\201023_Pac.wiff");
    if !path.exists() {
        return;
    }
    let transitions = read_transitions(path, 4).unwrap();
    let pairs = read_compact_mrm_pairs(path, 4).unwrap();
    let series = build_compact_mrm_series(0, transitions, &pairs).unwrap();
    assert_eq!(series.intensities.len(), 2);
    assert_eq!(series.intensities[0].len(), 1091);
    assert_eq!(series.intensities[1].len(), 1091);
    assert_eq!(series.retention_times[0].len(), 1091);
    assert!((series.retention_times[0][1] - 0.110 / 60.0).abs() < 1e-6);
}
