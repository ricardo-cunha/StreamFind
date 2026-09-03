#![cfg(feature = "reader-interface-tests")]

use streamfind_rust_mass_spec::reader::{Format, Reader};

#[test]
fn bruker_tsf_public_reader_matches_native_contract() {
    let path = std::env::var("STREAMFIND_BRUKER_TSF_FIXTURE").unwrap_or_else(|_| {
        "E:/example_files/ms_merck/Beispieldaten Routine/ACC1_28127_1_blank_P1-A-1_1_2022_13602.d".into()
    });
    let reader = Reader::open(path).expect("Bruker TSF reader");
    assert_eq!(reader.format(), Format::BrukerTsf);
    assert_eq!(reader.spectra().len(), 4451);
    let header = reader.spectrum(0).expect("TSF header");
    assert_eq!(header.scan, 1);
    assert_eq!(header.level, 1);
    assert_eq!(header.array_length, 1561);
    let spectrum = reader.spectrum_data(0).expect("TSF spectrum");
    assert_eq!(spectrum.mz.len(), 1561);
    assert_eq!(spectrum.intensity.len(), 1561);
    assert!((spectrum.mz[0] - 95.528351).abs() < 1e-4);
    assert_eq!(spectrum.intensity[0], 50.0);
}

#[test]
fn bruker_baf_public_reader_matches_native_contract() {
    let path = std::env::var("STREAMFIND_BRUKER_BAF_FIXTURE").unwrap_or_else(|_| {
        "E:/example_files/ms_merck/Beispieldaten Routine/ACC1_24890_1_P1-B-8_1_2022_7707.d".into()
    });
    let reader = Reader::open(path).expect("Bruker BAF reader");
    assert_eq!(reader.format(), Format::BrukerBaf);
    assert!(!reader.spectra().is_empty());
    let header = reader.spectrum(0).expect("BAF header");
    assert_eq!(header.scan, 1);
    assert_eq!(header.array_length, 513287);
    let spectrum = reader.spectrum_data(0).expect("BAF spectrum");
    assert_eq!(spectrum.mz.len(), 513287);
    assert_eq!(spectrum.intensity.len(), 513287);
    assert!(spectrum.base_peak_mz >= spectrum.low_mz && spectrum.base_peak_mz <= spectrum.high_mz);
    assert!(spectrum.tic > 0.0 && spectrum.base_peak_intensity > 0.0);
    assert_eq!(spectrum.intensity[33], 16.0);
    let variant = reader.spectrum_data(25).expect("BAF profile variant");
    assert_eq!(variant.mz.len(), 513287);
    assert_eq!(variant.intensity.len(), 513287);
}
