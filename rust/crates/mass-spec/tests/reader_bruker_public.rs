use streamfind_rust_mass_spec::reader::{Format, Reader};

#[test]
fn opens_bruker_tsf_through_public_reader() {
    let path = std::path::Path::new(
        r"E:\example_files\ms_merck\Beispieldaten Routine\ACC1_28127_1_blank_P1-A-1_1_2022_13602.d",
    );
    let reader = Reader::open(path).unwrap();
    assert_eq!(reader.format(), Format::BrukerTsf);
    assert_eq!(reader.spectra().len(), 4451);
    let spectrum = reader.spectrum(0).unwrap();
    assert_eq!(spectrum.array_length, 1561);
    assert_eq!(spectrum.mz.len(), 1561);
    assert_eq!(spectrum.intensity.len(), 1561);
    assert!((spectrum.mz[0] - 95.528351).abs() < 1e-4);
    assert_eq!(spectrum.intensity[0], 50.0);
    assert_eq!(spectrum.base_peak_intensity, 908.0);
    assert_eq!(spectrum.level, 1);
}
