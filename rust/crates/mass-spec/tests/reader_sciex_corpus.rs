use std::{env, fs, path::PathBuf};

use streamfind_rust_mass_spec::reader::{Format, Reader};

#[test]
#[ignore = "requires a locally configured SCIEX fixture corpus"]
fn opens_every_configured_sciex_wiff_with_consistent_native_surface() {
    let root = PathBuf::from(
        env::var("STREAMFIND_SCIEX_CORPUS_ROOT")
            .expect("STREAMFIND_SCIEX_CORPUS_ROOT must point to a directory of .wiff files"),
    );
    let filters = env::var("STREAMFIND_SCIEX_CORPUS_FILTER")
        .ok()
        .map(|value| value.split(',').map(str::to_owned).collect::<Vec<_>>())
        .unwrap_or_default();
    let mut paths = fs::read_dir(&root)
        .expect("SCIEX corpus root must be readable")
        .filter_map(Result::ok)
        .map(|entry| entry.path())
        .filter(|path| {
            path.extension()
                .and_then(|extension| extension.to_str())
                .is_some_and(|extension| extension.eq_ignore_ascii_case("wiff"))
        })
        .filter(|path| {
            filters.is_empty()
                || filters.iter().any(|filter| {
                    path.file_name()
                        .and_then(|name| name.to_str())
                        .is_some_and(|name| name.contains(filter))
                })
        })
        .collect::<Vec<_>>();
    paths.sort();
    assert!(!paths.is_empty(), "SCIEX corpus has no WIFF files");

    for path in paths {
        let reader = Reader::open(&path)
            .unwrap_or_else(|error| panic!("{}: {error}", path.display()));
        assert_eq!(reader.format(), Format::SciexWiff, "{}", path.display());
        assert!(!reader.analysis_catalog().is_empty(), "{}", path.display());
        assert!(reader
            .analysis_catalog()
            .iter()
            .enumerate()
            .all(|(index, analysis)| analysis.analysis_index == index), "{}", path.display());

        if reader.spectra().is_empty() {
            assert!(reader.chromatograms().len() >= 2, "{}", path.display());
            assert!(reader.chromatograms().iter().all(|trace| {
                trace.time.len() == trace.intensity.len()
            }), "{}", path.display());
        } else {
            assert!(reader.chromatograms().is_empty(), "{}", path.display());
            assert!(reader.spectra().iter().all(|spectrum| {
                spectrum.mz.len() == spectrum.intensity.len()
                    && spectrum.mz.iter().all(|mz| mz.is_finite())
                    && spectrum.intensity.iter().all(|intensity| *intensity >= 0.0)
            }), "{}", path.display());
        }
    }
}
