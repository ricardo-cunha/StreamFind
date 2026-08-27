use streamfind_rust_mass_spec::reader::{Format, Reader};

#[test]
fn opens_agilent_masshunter_through_public_reader() {
    let path = std::path::Path::new(
        r"E:\example_files\raw_vendor_files\agilent_mass_hunter\022_Aceton_Uracil_Mix1_10-r001.d",
    );
    let reader = Reader::open(path).unwrap();
    assert_eq!(reader.format(), Format::AgilentMassHunterD);
    assert_eq!(reader.spectra().len(), 7870);
    assert_eq!(reader.spectra()[0].scan, 182612);
    assert_eq!(reader.spectra()[0].array_length, 165344);
    let summary = reader.summary();
    assert!(summary.min_mz > 0.0 && summary.min_mz < 50.0);
    assert!((summary.max_mz - 1199.3268).abs() < 1e-3);
    let spectrum = reader.spectrum_data(0).unwrap();
    assert_eq!(spectrum.mz.len(), 165344);
    assert_eq!(spectrum.intensity.len(), 165344);
    assert_eq!(spectrum.intensity.iter().copied().fold(0.0, f32::max), 302.0);
}
