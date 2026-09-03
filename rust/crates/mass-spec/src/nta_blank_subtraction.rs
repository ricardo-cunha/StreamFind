//! Feature blank subtraction for non-target analysis projects.
//!
//! Ported from `core/domains/mass_spec/src/nta_blank_subtraction.cpp`
//! (`nta::blank_subtraction::subtract_blank_impl`). Keep the algorithm
//! identical; only the plumbing (Rust types, spectra access) is adapted.

use std::collections::HashMap;

use crate::nta::{get_spectra_targets, ProjectNonTargetAnalysis, TargetSpec};

/// Subtract blank intensities from features.
///
/// For every analysis that names a blank replicate, the maximum extracted
/// intensity of each feature id is collected across all blank analyses of
/// that replicate; the average over blanks is the blank intensity. Features
/// whose own intensity is below `blank_intensity * blank_threshold` are
/// filtered with `filter = "blank_subtraction"`.
///
/// Mirrors `nta::blank_subtraction::subtract_blank_impl` from
/// `core/domains/mass_spec/src/nta_blank_subtraction.cpp`.
pub fn subtract_blank_impl(
    nta_data: &mut ProjectNonTargetAnalysis,
    blank_threshold: f32,
    rt_expand: f32,
    mz_expand: f32,
    min_traces_intensity: f32,
) -> streamfind_rust_core::Result<()> {
    let analysis_names: Vec<String> = nta_data.analysis_names().to_vec();
    let replicate_names: Vec<String> = nta_data.replicate_names().to_vec();
    let blank_names: Vec<String> = nta_data.blank_names().to_vec();
    let file_paths: Vec<String> = nta_data.file_paths().to_vec();

    if analysis_names.is_empty() {
        return Ok(());
    }

    // Map replicate -> analysis indices for blank lookup.
    let mut replicate_to_indices: HashMap<String, Vec<usize>> = HashMap::new();
    for (i, replicate) in replicate_names.iter().enumerate() {
        replicate_to_indices
            .entry(replicate.clone())
            .or_default()
            .push(i);
    }

    for a in 0..analysis_names.len() {
        let n_features = nta_data.feature_buffers[a].size();
        if n_features == 0 {
            continue;
        }

        let blank_rep = &blank_names[a];
        if blank_rep.is_empty() {
            continue;
        }

        let blank_indices = match replicate_to_indices.get(blank_rep) {
            Some(indices) => indices.clone(),
            None => continue,
        };
        if blank_indices.is_empty() {
            continue;
        }

        // Build targets for this analysis' features (shared snapshot).
        let (targets, id_to_indices) = {
            let fts = &nta_data.feature_buffers[a];
            let mut targets: Vec<TargetSpec> = Vec::with_capacity(n_features);
            let mut id_to_indices: HashMap<String, Vec<i32>> = HashMap::with_capacity(n_features);

            for i in 0..n_features {
                targets.push(TargetSpec {
                    id: fts.feature[i].clone(),
                    level: 1,
                    polarity: fts.polarity[i],
                    precursor: false,
                    mz: fts.mz[i],
                    mzmin: fts.mzmin[i] - mz_expand,
                    mzmax: fts.mzmax[i] + mz_expand,
                    rt: fts.rt[i],
                    rtmin: fts.rtmin[i] - rt_expand,
                    rtmax: fts.rtmax[i] + rt_expand,
                    mobility: 0.0,
                });
                id_to_indices
                    .entry(fts.feature[i].clone())
                    .or_default()
                    .push(i as i32);
            }
            (targets, id_to_indices)
        };

        // Accumulate max intensities per id across blanks.
        let mut sum_by_id: HashMap<String, f32> = HashMap::with_capacity(id_to_indices.len());
        let mut count_by_id: HashMap<String, i32> = HashMap::with_capacity(id_to_indices.len());

        for &blank_idx in &blank_indices {
            if blank_idx >= file_paths.len() {
                continue;
            }

            let spectra = nta_data.spectra(blank_idx)?;
            let eics = get_spectra_targets(&spectra, &targets, min_traces_intensity, 0.0);

            let mut max_by_id: HashMap<String, f32> = HashMap::with_capacity(id_to_indices.len());
            for row in &eics {
                let intensity = row.intensity;
                match max_by_id.get_mut(&row.id) {
                    Some(current) if intensity > *current => {
                        *current = intensity;
                    }
                    Some(_) => {}
                    None => {
                        max_by_id.insert(row.id.clone(), intensity);
                    }
                }
            }

            for (id, intensity) in max_by_id {
                *sum_by_id.entry(id.clone()).or_insert(0.0) += intensity;
                *count_by_id.entry(id).or_insert(0) += 1;
            }
        }

        // Apply blank subtraction filter.
        let fts = &mut nta_data.feature_buffers[a];
        for (id, indices) in &id_to_indices {
            let mut blank_intensity = 0.0f32;
            if let Some(&count) = count_by_id.get(id) {
                if count > 0 {
                    blank_intensity = sum_by_id[id] / count as f32;
                }
            }

            for &idx in indices {
                let idx = idx as usize;
                if fts.intensity[idx] < (blank_intensity * blank_threshold) {
                    fts.filtered[idx] = true;
                    fts.filter[idx] = "blank_subtraction".to_string();
                }
            }
        }
    }

    Ok(())
}
