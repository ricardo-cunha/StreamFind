#![cfg(feature = "reader-interface-tests")]

use streamfind_rust_mass_spec::reader::{Format, Reader};

#[test]
fn opens_ion_mobility_spectra_with_native_mobility() {
    let Ok(path) = std::env::var("STREAMFIND_AGILENT_IMS_FIXTURE") else {
        return;
    };
    let reader = Reader::open(path).expect("public MassHunter ion-mobility reader");
    assert_eq!(reader.format(), Format::AgilentMassHunterD);
    assert_eq!(reader.spectra().len(), 37_801);
    assert_eq!(reader.chromatograms().len(), 15);
    assert_eq!(reader.spectra()[0].mobility, 0.0);
    assert!((reader.spectra()[1].mobility - 0.163904).abs() < 1e-6);
    let spectrum = reader.spectrum_data(1).expect("native IMS spectrum");
    assert_eq!(spectrum.array_length, 179_808);
    assert!((spectrum.mobility - 0.163904).abs() < 1e-6);
    assert_eq!(spectrum.mz.len(), spectrum.intensity.len());
    assert!((spectrum.mz[52369] - 364.51714).abs() < 1e-3);
    assert_eq!(spectrum.intensity[52369], 1.0);
}
