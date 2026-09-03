#![cfg(feature = "reader-interface-tests")]

use streamfind_rust_mass_spec::reader::{Format, Reader};
use streamfind_rust_mass_spec::reader_agilent;

#[test]
fn reads_masshunter_wide_profile_fixture() {
    let Ok(path) = std::env::var("STREAMFIND_AGILENT_WIDE_FIXTURE") else {
        return;
    };
    let records = reader_agilent::read_scan_records(&path).expect("MassHunter wide scan records");
    assert_eq!(records.len(), 677);
    let first = &records[0];
    assert_eq!(first.scan_id, 123_482);
    assert_eq!(first.spectrum_format_id, 1);
    assert_eq!(first.spectrum_point_count, 449_536);
    assert_eq!(first.spectrum_byte_count, 58_607);
    assert_eq!(first.spectrum_uncompressed_byte_count, 1_798_160);
    assert_eq!(first.centroid_format_id, 2);
    assert_eq!(first.centroid_offset, 68);
    assert_eq!(first.centroid_byte_count, 564);
    assert_eq!(first.centroid_point_count, 47);

    let centroid =
        reader_agilent::read_centroid_spectrum(&path, first).expect("MassHunter wide centroid");
    assert_eq!(centroid.mz.len(), 47);
    assert!((centroid.mz[0] - 517.379673).abs() < 1e-3);
    assert_eq!(centroid.intensity[0], 285.0);

    let profile =
        reader_agilent::read_profile_spectrum(&path, first).expect("MassHunter wide profile");
    assert_eq!(profile.mz.len(), 449_536);
    assert_eq!(profile.intensity.len(), profile.mz.len());
    assert!((profile.mz[0] - 499.9938).abs() < 1e-3);
    assert!((profile.mz[profile.mz.len() - 1] - 5000.0127).abs() < 1e-3);
    assert_eq!(
        profile.intensity.iter().copied().fold(0.0, f32::max),
        8615.0
    );
    assert!((profile.intensity.iter().sum::<f32>() - 464_469.0).abs() < 0.5);

    let reader = Reader::open(path).expect("public MassHunter wide reader");
    assert_eq!(reader.format(), Format::AgilentMassHunterD);
    assert_eq!(reader.spectra().len(), 677);
    assert_eq!(reader.chromatograms().len(), 16);
    assert_eq!(reader.chromatograms()[0].id, "DAD1A");
    assert_eq!(reader.chromatograms()[0].units, "mAU");
    assert_eq!(reader.chromatograms()[0].time.len(), 1501);
    assert!((reader.chromatograms()[0].intensity[0] - 0.97894669).abs() < 1e-5);
    let spectrum = reader
        .spectrum_data(0)
        .expect("public MassHunter wide profile");
    assert_eq!(spectrum.array_length, 47);
    assert_eq!(spectrum.mz.len(), 47);
    assert_eq!(
        spectrum.intensity.iter().copied().fold(0.0, f32::max),
        8616.0
    );
}
