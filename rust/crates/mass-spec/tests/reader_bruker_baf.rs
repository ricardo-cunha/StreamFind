#![cfg(feature = "reader-interface-tests")]

use streamfind_rust_mass_spec::reader_bruker::{self, Family};

#[test]
fn reads_native_baf_line_spectrum_blocks() {
    let path = std::path::Path::new(
        r"E:\example_files\ms_merck\Beispieldaten Routine\ACC1_24890_1_P1-B-8_1_2022_7707.d",
    );
    assert_eq!(reader_bruker::detect_family(path), Family::Baf);
    let ms1 = reader_bruker::read_baf_line_spectrum(path, 0x1600_0000_0001_b1a4).unwrap();
    assert_eq!(ms1.coordinate.len(), 1410);
    assert_eq!(ms1.intensity.len(), 1410);
    assert_eq!(ms1.width.len(), 1410);
    assert!((ms1.coordinate[0] - 33.0).abs() < 1e-12);
    assert_eq!(ms1.intensity[0], 16.0);
    assert_eq!(ms1.intensity.iter().copied().fold(0.0, f64::max), 2140.0);
    let ms2 = reader_bruker::read_baf_line_spectrum(path, 0x1600_0000_0227_0bad).unwrap();
    assert_eq!(ms2.coordinate.len(), 2114);
    assert_eq!(ms2.intensity.len(), 2114);
    assert_eq!(ms2.width.len(), 2114);
    assert!((ms2.coordinate[0] - 15.846153846153847).abs() < 1e-12);
    assert_eq!(ms2.intensity[0], 56.0);
    assert_eq!(ms2.intensity.iter().copied().fold(0.0, f64::max), 101370.0);
    let profile = reader_bruker::read_baf_profile_spectrum(path, 0x4200_0000_0001_8475).unwrap();
    assert_eq!(profile.intensity.len(), 513287);
    assert_eq!(profile.intensity[33], 16);
    assert_eq!(profile.intensity[166..169], [42, 60, 40]);
    assert_eq!(profile.intensity[432..435], [30, 48, 38]);
    assert_eq!(profile.intensity.iter().filter(|value| **value != 0).count(), 3499);
    assert_eq!(profile.intensity.iter().copied().max(), Some(2140));
}
