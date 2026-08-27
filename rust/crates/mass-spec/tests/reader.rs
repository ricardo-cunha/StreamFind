use std::{
    fs,
    time::{SystemTime, UNIX_EPOCH},
};
use streamfind_rust_mass_spec::reader::{Format, Reader};

#[test]
fn reads_mzxml_peak_arrays_and_summary() {
    let path = streamfind_rust_test_support::tmp_projects_dir().join(format!(
        "streamfind-mass-spec-{}.mzXML",
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let xml = r#"<?xml version="1.0"?><mzXML><msRun><scan num="7" peaksCount="2" msLevel="2" polarity="+" lowMz="100" highMz="200" retentionTime="PT3S"><peaks precision="32" byteOrder="network" pairOrder="m/z-int">QsgAAEEgAABDSAAAQaAAAA==</peaks></scan></msRun></mzXML>"#;
    fs::write(&path, xml).unwrap();

    let reader = Reader::open(&path).unwrap();
    let spectrum = reader.spectrum(0).unwrap();
    assert_eq!(reader.format(), Format::MzXml);
    assert_eq!(spectrum.scan, 7);
    assert_eq!(spectrum.mz.len(), 2);
    assert_eq!(spectrum.intensity.len(), 2);
    assert_eq!(reader.summary().number_spectra, 1);
    let _ = fs::remove_file(path);
}

#[test]
fn reads_shimadzu_lcd_chromatograms() {
    let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../..")
        .join("tests/data/mass_spec/shimadzu/adc.lcd");
    let mut reader = Reader::open(path).unwrap();
    assert_eq!(reader.format(), Format::ShimadzuLcd);
    assert_eq!(reader.analysis_catalog().len(), 1);
    assert_eq!(reader.analysis_catalog()[0].analysis_index, 0);
    assert_eq!(reader.analysis_catalog()[0].analysis_count, 1);
    reader.select_analysis(0).unwrap();
    assert_eq!(reader.selected_analysis_index(), 0);
    assert!(reader.select_analysis(1).is_err());
    assert_eq!(reader.summary().number_spectra, 0);
    assert!(reader.summary().number_chromatograms >= 2);
    assert!(reader.chromatograms().iter().any(|c| c.id == "AD1"));
    assert!(reader.chromatograms().iter().all(|c| !c.time.is_empty()));
}

#[test]
fn reads_shimadzu_lcd_tlm_spectra() {
    let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../..")
        .join("tests/data/mass_spec/shimadzu/karl.lcd");
    let reader = Reader::open(path).unwrap();
    assert_eq!(reader.format(), Format::ShimadzuLcd);
    assert!(reader.summary().number_spectra > 0);
    let spectrum = reader.spectrum(0).unwrap();
    assert_eq!(spectrum.level, 2);
    assert!(!spectrum.mz.is_empty());
    assert_eq!(spectrum.mz.len(), spectrum.intensity.len());
}

#[test]
fn opens_pac_wiff_with_native_chromatograms() {
    let path = std::path::Path::new("E:/example_files/raw_vendor_files/sciex/201023_Pac.wiff");
    if !path.exists() {
        return;
    }
    let reader = Reader::open(path).unwrap();
    assert_eq!(reader.format(), Format::SciexWiff);
    assert_eq!(reader.chromatograms().len(), 4);
    assert_eq!(reader.chromatograms()[0].id, "TIC");
    assert_eq!(reader.chromatograms()[1].id, "BPC");
    assert_eq!(reader.chromatograms()[2].id, "Pac 569");
    assert_eq!(reader.chromatograms()[3].id, "Pac 286");
    assert_eq!(reader.chromatograms()[2].precursor_mz, Some(854.233));
    assert_eq!(reader.chromatograms()[2].product_mz, Some(569.1));
    assert_eq!(reader.chromatograms()[2].time.len(), 1091);
}

#[test]
fn opens_multi_experiment_sciex_wiff_with_native_chromatograms() {
    let path = std::path::Path::new("E:/example_files/raw_vendor_files/sciex/201209_MM_2.wiff");
    if !path.exists() {
        return;
    }
    let reader = Reader::open(path).unwrap();
    assert_eq!(reader.format(), Format::SciexWiff);
    assert_eq!(reader.chromatograms().len(), 16);
    assert_eq!(reader.chromatograms()[0].id, "TIC");
    assert_eq!(reader.chromatograms()[1].id, "BPC");
    assert_eq!(reader.chromatograms()[2].time.len(), 800);
    assert_eq!(reader.chromatograms()[12].time.len(), 900);
}
