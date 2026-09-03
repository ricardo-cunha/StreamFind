#![cfg(feature = "reader-interface-tests")]

use streamfind_rust_mass_spec::reader::{Format, Reader};
use streamfind_rust_mass_spec::reader_agilent_chemstation;

#[test]
fn reads_chemstation_msd1_fixture() {
    let Ok(file) = std::env::var("STREAMFIND_AGILENT_CHEMSTATION_MS_FIXTURE") else {
        return;
    };
    let data = reader_agilent_chemstation::read_data_file(&file).expect("ChemStation header/index");
    assert_eq!(data.record_count, 672);
    assert_eq!(data.index.len(), 672);
    assert_eq!(data.retention_time_start_ms, 4602);
    assert_eq!(data.retention_time_end_ms, 418_140);

    let first = reader_agilent_chemstation::read_spectrum(&data, 0).expect("ChemStation spectrum");
    assert_eq!(first.mz.len(), 20);
    assert_eq!(first.retention_time_ms, 4602);
    assert!((first.mz[0] - 120.1).abs() < 1e-6);
    assert_eq!(first.intensity[0], 3091.0);

    let directory = std::path::Path::new(&file)
        .parent()
        .expect("ChemStation directory");
    let reader = Reader::open(directory).expect("public ChemStation reader");
    assert_eq!(reader.format(), Format::AgilentChemStationD);
    assert_eq!(reader.spectra().len(), 672);
    let public = reader
        .spectrum_data(0)
        .expect("public ChemStation spectrum");
    assert_eq!(public.array_length, 20);
    assert_eq!(public.intensity[0], 3091.0);
}
