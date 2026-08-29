use streamfind_rust_mass_spec::reader::{Format, Reader};
use streamfind_rust_mass_spec::reader_agilent_chemstation;

#[test]
fn reads_chemstation_uv_matrix_fixture() {
    let Ok(path) = std::env::var("STREAMFIND_AGILENT_UV_FIXTURE") else {
        return;
    };
    let chromatograms = reader_agilent_chemstation::read_chromatograms(
        std::path::Path::new(&path).parent().expect("DAD directory"),
    )
    .expect("ChemStation UV chromatograms");
    let uv = chromatograms
        .iter()
        .filter(|value| value.channel == "DAD1.UV")
        .collect::<Vec<_>>();
    assert_eq!(uv.len(), 106);
    assert_eq!(uv[0].time.len(), 12003);

    assert!((uv[0].time[0] - 0.0002).abs() < 1e-7);
    assert!((uv[0].time[12002] - 10.0018667).abs() < 1e-6);
    assert!((uv[0].intensity[0] - (-4.0359497)).abs() < 1e-5);

    assert!((uv[1].intensity[0] - (-32.4840546)).abs() < 1e-5);

    let reader = Reader::open(std::path::Path::new(&path).parent().expect("DAD directory"))
        .expect("public ChemStation chromatogram-only reader");
    assert_eq!(reader.format(), Format::AgilentChemStationD);
    assert!(reader.spectra().is_empty());
    assert_eq!(reader.chromatograms().len(), 110);
}
