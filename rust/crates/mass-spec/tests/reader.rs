use std::{
    fs,
    time::{SystemTime, UNIX_EPOCH},
};
use streamfind_rust_mass_spec::reader::{Format, Reader};

#[test]
fn reads_mzxml_peak_arrays_and_summary() {
    let path = std::env::temp_dir().join(format!(
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
    let reader = Reader::open(path).unwrap();
    assert_eq!(reader.format(), Format::ShimadzuLcd);
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
