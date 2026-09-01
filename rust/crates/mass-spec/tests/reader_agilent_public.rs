#![cfg(feature = "reader-interface-tests")]

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
    assert_eq!(
        spectrum.intensity.iter().copied().fold(0.0, f32::max),
        302.0
    );
}

#[test]
fn reads_masshunter_positive_and_negative_method_polarity() {
    for (path, expected) in [
        (
            r"E:\example_files\raw_vendor_files\agilent_mass_hunter\06_pos_Blank-r001.d",
            1,
        ),
        (
            r"E:\example_files\raw_vendor_files\agilent_mass_hunter\06_neg_Blank-r001.d",
            -1,
        ),
    ] {
        let path = std::path::Path::new(path);
        if !path.exists() {
            return;
        }
        let reader = Reader::open(path).unwrap();
        assert_eq!(reader.spectra()[0].polarity, expected);
        if expected == 1 {
            assert!((reader.spectra()[0].retention_time - 182.502).abs() < 0.001);
        } else {
            assert!(reader.spectra()[0].retention_time > 100.0);
        }
        assert_eq!(reader.spectrum_data(0).unwrap().polarity, expected);
        assert!(reader.spectrum_data(0).unwrap().retention_time > 100.0);
    }
}

#[test]
fn reads_masshunter_dda_precursor_from_periodic_actuals() {
    let path = std::path::Path::new(
        r"E:\example_files\raw_vendor_files\agilent_mass_hunter\06_pos_Blank-r001.d",
    );
    if !path.exists() {
        return;
    }
    let reader = Reader::open(path).unwrap();
    assert_eq!(reader.spectra()[26].level, 2);
    assert!((reader.spectra()[26].precursor_mz - 237.0522).abs() < 0.001);
    assert!((reader.spectra()[26].collision_energy - 10.0).abs() < 0.001);
    assert!((reader.spectra()[26].precursor_intensity - 528.0).abs() < 0.001);
    assert!((reader.spectrum_data(26).unwrap().precursor_mz - 237.0522).abs() < 0.001);
    assert!((reader.spectrum_data(26).unwrap().precursor_intensity - 528.0).abs() < 0.001);
}
