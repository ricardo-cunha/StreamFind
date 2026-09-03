//! Matrix-suppression correction algorithms for NTA.
//!
//! Ported from `core/domains/mass_spec/src/nta_correction_algorithms.cpp`
//! (`nta::correction_algorithms`). Keep every operation identical: TIC profile
//! construction, mean intensity in window, sample/blank aggregation, `mp`
//! points, `tichri = ((blank_mean / sample_mean) - 1) * (-1)`, the linear
//! regression of `tichri ~ mp` support points, and the correction factors
//! written into the features' `correction` column via the internal-standard
//! profile. Only the plumbing is adapted: the C++ `spectra_headers_at(i)`
//! (columnar `hd.rt[i]` / `hd.tic[i]`) becomes `nta_data.spectra(i)?`
//! (per-spectrum `retention_time` / `tic` fields).

use std::collections::{HashMap, HashSet};

use crate::nta::ProjectNonTargetAnalysis;

/// Port of `nta::correction_algorithms::TIC_MATRIX_SUPPRESSION_ROW`.
#[derive(Debug, Clone)]
pub struct TicMatrixSuppressionRow {
    pub analysis: String,
    pub replicate: String,
    pub polarity: i32,
    pub level: i32,
    pub rt: f64,
    pub intensity: f64,
    pub mp: f64,
}

impl Default for TicMatrixSuppressionRow {
    fn default() -> Self {
        Self {
            analysis: String::new(),
            replicate: String::new(),
            polarity: 0,
            level: 1,
            rt: 0.0,
            intensity: 0.0,
            mp: 0.0,
        }
    }
}

/// Port of `nta::correction_algorithms::ISTD_MATRIX_SUPPRESSION_ROW`.
#[derive(Debug, Clone, Default)]
pub struct IstdMatrixSuppressionRow {
    pub analysis: String,
    pub replicate: String,
    pub name: String,
    pub rt: f64,
    pub intensity: f64,
    pub matrix_effect: f64,
    pub mp: f64,
    pub tichri: f64,
}

type Profile = Vec<TicMatrixSuppressionRow>;

/// Port of `nta_correction_detail::SupportPoint`.
#[derive(Debug, Clone)]
struct SupportPoint {
    replicate: String,
    name: String,
    rt: f64,
    mp: f64,
    tichri: f64,
}

impl Default for SupportPoint {
    fn default() -> Self {
        Self {
            replicate: String::new(),
            name: String::new(),
            rt: 0.0,
            mp: f64::NAN,
            tichri: f64::NAN,
        }
    }
}

type BlankLookup = Vec<Vec<usize>>;

/// `is_missing_blank` — empty or "NA".
fn is_missing_blank(value: &str) -> bool {
    value.is_empty() || value == "NA"
}

/// `join_key` — replicate + name composite key (unit separator 0x1f).
fn join_key(lhs: &str, rhs: &str) -> String {
    format!("{lhs}\x1f{rhs}")
}

/// `contains_analysis` — empty selection matches everything.
fn contains_analysis(selected: &HashSet<String>, analysis: &str) -> bool {
    selected.is_empty() || selected.contains(analysis)
}

/// `resolve_blank_indices` — for every analysis, the analysis indices whose
/// replicate is a blank of that analysis (override replicate wins when given).
fn resolve_blank_indices(
    nta_data: &ProjectNonTargetAnalysis,
    ref_blank_replicate: &str,
) -> BlankLookup {
    let analysis_names = nta_data.analysis_names();
    let replicate_names = nta_data.replicate_names();
    let blank_names = nta_data.blank_names();

    let mut replicate_to_indices: HashMap<String, Vec<usize>> = HashMap::new();
    for (i, replicate) in replicate_names.iter().enumerate() {
        replicate_to_indices
            .entry(replicate.clone())
            .or_default()
            .push(i);
    }

    let mut override_blank_replicates: Vec<String> = Vec::new();
    if !ref_blank_replicate.is_empty() {
        for i in 0..analysis_names.len() {
            if replicate_names[i] == ref_blank_replicate && !is_missing_blank(&blank_names[i]) {
                override_blank_replicates.push(blank_names[i].clone());
            }
        }
        override_blank_replicates.sort();
        override_blank_replicates.dedup();
    }

    let mut out: BlankLookup = Vec::with_capacity(analysis_names.len());
    for i in 0..analysis_names.len() {
        let mut blank_replicates: Vec<String> = Vec::new();
        if !override_blank_replicates.is_empty() {
            blank_replicates = override_blank_replicates.clone();
        } else if !is_missing_blank(&blank_names[i]) {
            blank_replicates.push(blank_names[i].clone());
        }

        let mut blank_indices: Vec<usize> = Vec::new();
        for blank_replicate in blank_replicates {
            if let Some(indices) = replicate_to_indices.get(&blank_replicate) {
                blank_indices.extend(indices.iter().copied());
            }
        }
        blank_indices.sort();
        blank_indices.dedup();
        out.push(blank_indices);
    }

    out
}

/// `build_tic_profile` — level-1 spectra rows with finite rt/tic, as
/// `TIC_MATRIX_SUPPRESSION_ROW`s (`mp` starts as NaN).
///
/// Plumbing adaptation: the C++ columnar `spectra_headers_at` arrays
/// (`hd.rt`, `hd.tic`, `hd.level`, `hd.polarity`, with defensive bounds
/// checks) map 1:1 onto the per-spectrum `Spectrum` fields, which are always
/// present; the only effective row filter is `level != 1`, and the remaining
/// filter is non-finite `rt`/`tic`.
fn build_tic_profile(
    nta_data: &ProjectNonTargetAnalysis,
    analysis_index: usize,
) -> streamfind_rust_core::Result<Profile> {
    let spectra = nta_data.spectra(analysis_index)?;
    let analysis_names = nta_data.analysis_names();
    let replicate_names = nta_data.replicate_names();

    let mut profile: Profile = Vec::new();
    for spectrum in spectra.iter() {
        if spectrum.level != 1 {
            continue;
        }
        let rt = spectrum.retention_time;
        let intensity = spectrum.tic;
        if !rt.is_finite() || !intensity.is_finite() {
            continue;
        }
        profile.push(TicMatrixSuppressionRow {
            analysis: analysis_names[analysis_index].clone(),
            replicate: replicate_names[analysis_index].clone(),
            polarity: spectrum.polarity,
            level: 1,
            rt: rt as f64,
            intensity: intensity as f64,
            mp: f64::NAN,
        });
    }

    Ok(profile)
}

/// `mean_intensity_in_window` — mean of `mp` or `intensity` over rows whose
/// rt is within `[rtmin, rtmax]`; NaN when no row qualifies.
fn mean_intensity_in_window(profile: &Profile, rtmin: f64, rtmax: f64, use_mp: bool) -> f64 {
    let mut sum = 0.0;
    let mut count = 0usize;
    for row in profile {
        if row.rt < rtmin || row.rt > rtmax {
            continue;
        }
        let value = if use_mp { row.mp } else { row.intensity };
        if !value.is_finite() {
            continue;
        }
        sum += value;
        count += 1;
    }
    if count == 0 {
        return f64::NAN;
    }
    sum / count as f64
}

/// `build_matrix_profiles` — per-analysis TIC profiles with per-row `mp`
/// points: `-(sample_mean / blank_mean)` with `-1.0` when no blank window.
fn build_matrix_profiles(
    nta_data: &ProjectNonTargetAnalysis,
    analyses: &[String],
    rt_window: f32,
    ref_blank_replicate: &str,
) -> streamfind_rust_core::Result<HashMap<String, Profile>> {
    let analysis_names = nta_data.analysis_names();
    let selected_analyses: HashSet<String> = analyses.iter().cloned().collect();
    let blank_lookup = resolve_blank_indices(nta_data, ref_blank_replicate);

    let mut raw_profiles: Vec<Profile> = Vec::with_capacity(analysis_names.len());
    raw_profiles.resize_with(analysis_names.len(), Vec::new);
    for i in 0..analysis_names.len() {
        if !contains_analysis(&selected_analyses, &analysis_names[i]) {
            continue;
        }
        raw_profiles[i] = build_tic_profile(nta_data, i)?;
    }

    let mut out: HashMap<String, Profile> = HashMap::new();
    for i in 0..analysis_names.len() {
        if !contains_analysis(&selected_analyses, &analysis_names[i]) {
            continue;
        }

        // C++ moves raw_profiles[i] into `profile` (leaving an empty slot that
        // is lazily rebuilt below when an analysis doubles as its own blank).
        let mut profile = std::mem::take(&mut raw_profiles[i]);
        let blank_indices = &blank_lookup[i];

        for row_index in 0..profile.len() {
            if blank_indices.is_empty() {
                profile[row_index].mp = -1.0;
                continue;
            }

            let row_rt = profile[row_index].rt;
            let rtmin = row_rt - rt_window as f64;
            let rtmax = row_rt + rt_window as f64;
            let sample_mean = mean_intensity_in_window(&profile, rtmin, rtmax, false);
            if !sample_mean.is_finite() {
                profile[row_index].mp = -1.0;
                continue;
            }

            let mut blank_sum = 0.0;
            let mut blank_count = 0usize;
            for &blank_index in blank_indices {
                if blank_index >= raw_profiles.len() {
                    continue;
                }
                if raw_profiles[blank_index].is_empty() {
                    raw_profiles[blank_index] = build_tic_profile(nta_data, blank_index)?;
                }
                let blank_mean =
                    mean_intensity_in_window(&raw_profiles[blank_index], rtmin, rtmax, false);
                if !blank_mean.is_finite() || blank_mean <= 0.0 {
                    continue;
                }
                blank_sum += blank_mean;
                blank_count += 1;
            }

            if blank_count == 0 {
                profile[row_index].mp = -1.0;
                continue;
            }

            let blank_mean = blank_sum / blank_count as f64;
            profile[row_index].mp = if blank_mean > 0.0 {
                (sample_mean / blank_mean) * -1.0
            } else {
                -1.0
            };
        }

        out.insert(analysis_names[i].clone(), profile);
    }

    Ok(out)
}

/// `build_internal_standard_support` — ISTD support points (replicate, name,
/// rt, mp, tichri) from internal-standard intensities vs blank intensities and
/// the matrix profiles.
fn build_internal_standard_support(
    nta_data: &ProjectNonTargetAnalysis,
    matrix_profiles: &HashMap<String, Profile>,
    rt_window: f32,
    ref_blank_replicate: &str,
) -> streamfind_rust_core::Result<Vec<SupportPoint>> {
    let analysis_names = nta_data.analysis_names();
    let replicate_names = nta_data.replicate_names();
    let buffers = &nta_data.internal_standard_buffers;
    let blank_lookup = resolve_blank_indices(nta_data, ref_blank_replicate);

    let mut blank_intensities_by_key: HashMap<String, Vec<f64>> = HashMap::new();
    let mut sample_rows_by_key: HashMap<String, Vec<(usize, i32)>> = HashMap::new();

    for analysis_index in 0..buffers.len() {
        let buffer = &buffers[analysis_index];
        let buffer_size = buffer.size();
        for row in 0..buffer_size as i32 {
            let row_index = row as usize;
            let key = join_key(&replicate_names[analysis_index], &buffer.name[row_index]);
            sample_rows_by_key
                .entry(key.clone())
                .or_default()
                .push((analysis_index, row));

            for &blank_index in &blank_lookup[analysis_index] {
                if blank_index >= buffers.len() {
                    continue;
                }
                let blank_buffer = &buffers[blank_index];
                for blank_row in 0..blank_buffer.size() {
                    if blank_buffer.name[blank_row] != buffer.name[row_index] {
                        continue;
                    }
                    let blank_intensity = blank_buffer.intensity[blank_row];
                    if blank_intensity.is_finite() && blank_intensity > 0.0 {
                        blank_intensities_by_key
                            .entry(key.clone())
                            .or_default()
                            .push(blank_intensity);
                    }
                }
            }
        }
    }

    let mut support: Vec<SupportPoint> = Vec::new();
    for (key, rows) in sample_rows_by_key.iter() {
        let blank_intensities = match blank_intensities_by_key.get(key) {
            Some(values) if !values.is_empty() => values,
            _ => continue,
        };

        let mut sample_intensity_sum = 0.0;
        let mut sample_rt_sum = 0.0;
        let mut sample_mp_sum = 0.0;
        let mut sample_count = 0usize;
        let mut sample_mp_count = 0usize;

        for &(analysis_index, row) in rows {
            let buffer = &buffers[analysis_index];
            let sample_intensity = buffer.intensity[row as usize];
            if sample_intensity.is_finite() && sample_intensity > 0.0 {
                sample_intensity_sum += sample_intensity;
                sample_count += 1;
            }
            let sample_rt = buffer.exp_rt[row as usize];
            if sample_rt.is_finite() {
                sample_rt_sum += sample_rt;
            }
            let profile = match matrix_profiles.get(&analysis_names[analysis_index]) {
                Some(profile) => profile,
                None => continue,
            };
            let mp_mean = mean_intensity_in_window(
                profile,
                sample_rt - rt_window as f64,
                sample_rt + rt_window as f64,
                true,
            );
            if mp_mean.is_finite() {
                sample_mp_sum += mp_mean;
                sample_mp_count += 1;
            }
        }

        if sample_count == 0 {
            continue;
        }

        let blank_sum: f64 = blank_intensities.iter().sum();
        let blank_mean = blank_sum / blank_intensities.len() as f64;
        let sample_mean = sample_intensity_sum / sample_count as f64;
        if !blank_mean.is_finite()
            || blank_mean <= 0.0
            || !sample_mean.is_finite()
            || sample_mean <= 0.0
        {
            continue;
        }

        let (replicate, name) = match key.split_once('\x1f') {
            Some((replicate, name)) => (replicate.to_owned(), name.to_owned()),
            None => (key.clone(), String::new()),
        };
        let point = SupportPoint {
            replicate,
            name,
            rt: sample_rt_sum / rows.len() as f64,
            mp: if sample_mp_count > 0 {
                sample_mp_sum / sample_mp_count as f64
            } else {
                f64::NAN
            },
            tichri: ((blank_mean / sample_mean) - 1.0) * (-1.0),
        };
        if !point.mp.is_finite() {
            continue;
        }
        support.push(point);
    }

    Ok(support)
}

/// `select_support_points` — up to two support points bracketing the feature
/// rt (closest before/after), padded by rt distance up to two points.
fn select_support_points(
    support: &[SupportPoint],
    replicate: &str,
    feature_rt: f64,
) -> Vec<SupportPoint> {
    let mut replicate_points: Vec<SupportPoint> = support
        .iter()
        .filter(|point| {
            point.replicate == replicate && point.mp.is_finite() && point.tichri.is_finite()
        })
        .cloned()
        .collect();

    if replicate_points.is_empty() {
        return Vec::new();
    }

    replicate_points.sort_by(|lhs, rhs| {
        if lhs.rt != rhs.rt {
            if lhs.rt < rhs.rt {
                std::cmp::Ordering::Less
            } else {
                std::cmp::Ordering::Greater
            }
        } else if lhs.name < rhs.name {
            std::cmp::Ordering::Less
        } else if lhs.name > rhs.name {
            std::cmp::Ordering::Greater
        } else {
            std::cmp::Ordering::Equal
        }
    });

    let mut selected: Vec<SupportPoint> = Vec::new();
    let mut has_before = false;
    let mut has_after = false;
    let mut best_before: Option<SupportPoint> = None;
    let mut best_after: Option<SupportPoint> = None;
    let mut before_distance = f64::INFINITY;
    let mut after_distance = f64::INFINITY;

    for point in &replicate_points {
        let distance = (point.rt - feature_rt).abs();
        if point.rt <= feature_rt && distance < before_distance {
            best_before = Some(point.clone());
            before_distance = distance;
            has_before = true;
        }
        if point.rt >= feature_rt && distance < after_distance {
            best_after = Some(point.clone());
            after_distance = distance;
            has_after = true;
        }
    }

    // C++ pushes best_before first, then best_after unless it duplicates it.
    let mut push_after = true;
    if has_after {
        if let (Some(after), Some(before)) = (best_after.as_ref(), best_before.as_ref()) {
            if has_before && after.name == before.name && after.rt == before.rt {
                push_after = false;
            }
        }
    }
    if has_before {
        selected.push(best_before.unwrap());
    }
    if has_after && push_after {
        selected.push(best_after.unwrap());
    }

    if selected.len() < 2 && replicate_points.len() > selected.len() {
        replicate_points.sort_by(|lhs, rhs| {
            (lhs.rt - feature_rt)
                .abs()
                .partial_cmp(&(rhs.rt - feature_rt).abs())
                .unwrap_or(std::cmp::Ordering::Equal)
        });
        for point in replicate_points {
            let duplicate = selected
                .iter()
                .any(|existing| existing.name == point.name && existing.rt == point.rt);
            if !duplicate {
                selected.push(point);
            }
            if selected.len() >= 2 {
                break;
            }
        }
    }

    selected
}

/// `predict_scaled_suppression` — single-point ratio or least-squares
/// regression of `tichri ~ mp` evaluated at `mp_feature`.
fn predict_scaled_suppression(mp_feature: f64, selected_points: &[SupportPoint]) -> f64 {
    if !mp_feature.is_finite() || selected_points.is_empty() {
        return f64::NAN;
    }

    if selected_points.len() == 1 {
        let point = &selected_points[0];
        if !point.mp.is_finite() || point.mp.abs() < 1e-12 {
            return f64::NAN;
        }
        return mp_feature * (point.tichri / point.mp);
    }

    let mut x_mean = 0.0;
    let mut y_mean = 0.0;
    for point in selected_points {
        x_mean += point.mp;
        y_mean += point.tichri;
    }
    x_mean /= selected_points.len() as f64;
    y_mean /= selected_points.len() as f64;

    let mut numerator = 0.0;
    let mut denominator = 0.0;
    for point in selected_points {
        numerator += (point.mp - x_mean) * (point.tichri - y_mean);
        denominator += (point.mp - x_mean) * (point.mp - x_mean);
    }

    if denominator.abs() < 1e-12 {
        if x_mean.abs() < 1e-12 {
            return f64::NAN;
        }
        return mp_feature * (y_mean / x_mean);
    }

    let slope = numerator / denominator;
    let intercept = y_mean - (slope * x_mean);
    intercept + (slope * mp_feature)
}

/// `get_matrix_suppression_impl` — the per-analysis TIC matrix-suppression
/// rows (analysis, replicate, polarity, level, rt, intensity, mp) for the
/// selected analyses, sorted by analysis then rt.
pub fn get_matrix_suppression_impl(
    nta_data: &ProjectNonTargetAnalysis,
    analyses: &[String],
    rt_window: f32,
    ref_blank_replicate: &str,
) -> streamfind_rust_core::Result<Vec<TicMatrixSuppressionRow>> {
    let profiles = build_matrix_profiles(nta_data, analyses, rt_window, ref_blank_replicate)?;
    let mut out: Vec<TicMatrixSuppressionRow> = Vec::new();
    for profile in profiles.values() {
        out.extend(profile.iter().cloned());
    }
    out.sort_by(|lhs, rhs| {
        if lhs.analysis != rhs.analysis {
            lhs.analysis.cmp(&rhs.analysis)
        } else {
            match lhs.rt.partial_cmp(&rhs.rt) {
                Some(ordering) => ordering,
                None => std::cmp::Ordering::Equal,
            }
        }
    });
    Ok(out)
}

/// `correct_matrix_suppression_impl` — writes the matrix-suppression
/// correction factor into every feature's `correction` column.
pub fn correct_matrix_suppression_impl(
    nta_data: &mut ProjectNonTargetAnalysis,
    mp_rt_window: f32,
    ref_blank_replicate: &str,
) -> streamfind_rust_core::Result<()> {
    let analyses = nta_data.analysis_names().to_vec();
    let profiles = build_matrix_profiles(nta_data, &analyses, mp_rt_window, ref_blank_replicate)?;
    let support_points =
        build_internal_standard_support(nta_data, &profiles, mp_rt_window, ref_blank_replicate)?;
    let analysis_names = nta_data.analysis_names().to_vec();
    let replicate_names = nta_data.replicate_names().to_vec();
    let feature_buffers = &mut nta_data.feature_buffers;

    for analysis_index in 0..feature_buffers.len() {
        let profile = match profiles.get(&analysis_names[analysis_index]) {
            Some(profile) => profile,
            None => continue,
        };
        let replicate = &replicate_names[analysis_index];

        let features = &mut feature_buffers[analysis_index];
        for row in 0..features.size() {
            let rtmin = features.rtmin[row] as f64 - mp_rt_window as f64;
            let rtmax = features.rtmax[row] as f64 + mp_rt_window as f64;
            let mp_feature = mean_intensity_in_window(profile, rtmin, rtmax, true);

            let mut correction = f64::NAN;
            let selected_points =
                select_support_points(&support_points, replicate, features.rt[row] as f64);
            if !selected_points.is_empty() {
                let scaled_suppression = predict_scaled_suppression(mp_feature, &selected_points);
                if scaled_suppression.is_finite() {
                    correction = 1.0 - scaled_suppression;
                }
            }

            if !correction.is_finite() {
                correction = if mp_feature.is_finite() {
                    1.0 - mp_feature
                } else {
                    1.0
                };
            }

            features.correction[row] = correction as f32;
        }
    }

    Ok(())
}
