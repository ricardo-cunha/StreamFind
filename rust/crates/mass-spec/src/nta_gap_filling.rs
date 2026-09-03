//! Feature gap filling for non-target analysis projects.
//!
//! Ported from `core/domains/mass_spec/src/nta_gap_filling.cpp`
//! (`nta::gap_filling`): feature-group gap analysis, EIC extraction,
//! peak picking and `fill_features_impl`. Keep every numeric operation
//! identical to the C++ source; only the plumbing (Rust types, spectra
//! access) is adapted. The C++ debug logging (`debugFG` / `debug`) is
//! dropped.

use std::collections::{BTreeMap, BTreeSet, HashMap};

use crate::nta::{
    get_spectra_targets, NtaFeatureRow, NtaFeatures, ProjectNonTargetAnalysis, TargetPoint,
    TargetSpec,
};
use crate::nta_utils::{
    calculate_area, calculate_asymmetry, calculate_fwhm_combined, calculate_fwhm_rt,
    calculate_gaussian_rsquared, calculate_jaggedness, calculate_modality, calculate_sharpness,
    calculate_theoretical_plates, encode_floats_base64, fit_gaussian, get_sort_indices_float,
    reorder_multiple_vectors4, smooth_intensity_savitzky_golay,
};
use crate::reader::Spectrum;

/// Information about one feature group and its gaps across analyses
/// (mirrors `nta::gap_filling::FEATURE_GROUP_INFO`).
#[derive(Debug, Clone)]
pub struct FeatureGroupInfo {
    pub feature_group: String,
    pub median_rt: f32,
    pub median_mz: f32,
    pub median_mass: f32,
    pub rt_range: f32,
    pub min_rtmin: f32,
    pub max_rtmax: f32,
    pub min_mzmin: f32,
    pub max_mzmax: f32,
    pub present_analyses: Vec<String>,
    pub missing_analyses: Vec<String>,
    pub total_features: i32,
}

/// Extracted ion chromatogram data for one target
/// (mirrors `nta::gap_filling::EIC_DATA`).
#[derive(Debug, Clone, Default)]
pub struct EicData {
    pub rt: Vec<f32>,
    pub mz: Vec<f32>,
    pub intensity: Vec<f32>,
    pub noise: Vec<f32>,
    pub size: i32,
    pub valid: bool,
}

/// Peak-picking result for a filled feature
/// (mirrors `nta::gap_filling::FILLED_FEATURE_INFO`).
#[derive(Debug, Clone, Default)]
pub struct FilledFeatureInfo {
    pub analysis: String,
    pub feature_group: String,
    pub original_feature: String,
    pub adduct: String,
    pub rt: f32,
    pub mz: f32,
    pub mass: f32,
    pub intensity: f32,
    pub area: f32,
    pub noise: f32,
    pub sn: f32,
    pub rtmin: f32,
    pub rtmax: f32,
    pub width: f32,
    pub mzmin: f32,
    pub mzmax: f32,
    pub ppm: f32,
    pub fwhm_rt: f32,
    pub fwhm_mz: f32,
    pub gaussian_A: f32,
    pub gaussian_mu: f32,
    pub gaussian_sigma: f32,
    pub gaussian_r2: f32,
    pub jaggedness: f32,
    pub sharpness: f32,
    pub asymmetry: f32,
    pub modality: f32,
    pub plates: f32,
    pub polarity: i32,
    pub filled: bool,
    pub correction: f32,
    pub eic_size: i32,
    pub eic_rt: String,
    pub eic_mz: String,
    pub eic_intensity: String,
    pub eic_baseline: String,
    pub eic_smoothed: String,
}

/// Total-order wrapper for `f32` so RT keys can live in a `BTreeMap`
/// (mirrors the `std::map<float, ...>` ordering of the C++ source for
/// non-NaN values).
#[derive(Debug, Clone, Copy, PartialEq)]
struct TotalF32(f32);

impl Eq for TotalF32 {}

impl PartialOrd for TotalF32 {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for TotalF32 {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        self.0.total_cmp(&other.0)
    }
}

impl From<f32> for TotalF32 {
    fn from(value: f32) -> Self {
        TotalF32(value)
    }
}

/// `nta::gap_filling::analyze_feature_groups` — identify which analyses are
/// missing each feature group, optionally restricted to replicates that
/// already contain the group.
pub fn analyze_feature_groups(
    features: &[NtaFeatures],
    analyses: &[String],
    replicates: &[String],
    within_replicate: bool,
    min_samples: i32,
) -> Vec<FeatureGroupInfo> {
    // Build analysis to replicate map
    let mut analysis_replicate_map: HashMap<String, String> = HashMap::new();
    for (i, analysis) in analyses.iter().enumerate() {
        analysis_replicate_map.insert(
            analysis.clone(),
            replicates.get(i).cloned().unwrap_or_default(),
        );
    }

    // Build a map of feature groups
    let mut group_map: HashMap<String, Vec<(String, f32, f32, f32)>> = HashMap::new();

    for fts in features {
        for i in 0..fts.size() {
            let fg = fts.feature_group[i].clone();
            if fg.is_empty() {
                continue;
            }
            group_map.entry(fg).or_default().push((
                fts.analysis.clone(),
                fts.rt[i],
                fts.mz[i],
                fts.mass[i],
            ));
        }
    }

    // Analyze each group
    let mut group_infos = Vec::new();

    for (fg, group_features) in &group_map {
        if (group_features.len() as i32) < min_samples {
            continue;
        }

        let mut info = FeatureGroupInfo {
            feature_group: fg.clone(),
            total_features: group_features.len() as i32,
            median_rt: 0.0,
            median_mz: 0.0,
            median_mass: 0.0,
            rt_range: 0.0,
            min_rtmin: 0.0,
            max_rtmax: 0.0,
            min_mzmin: 0.0,
            max_mzmax: 0.0,
            present_analyses: Vec::new(),
            missing_analyses: Vec::new(),
        };

        // Calculate median values and collect RT/m/z ranges
        let mut rts: Vec<f32> = Vec::new();
        let mut mzs: Vec<f32> = Vec::new();
        let mut masses: Vec<f32> = Vec::new();
        let mut rtmins: Vec<f32> = Vec::new();
        let mut rtmaxs: Vec<f32> = Vec::new();
        let mut mzmins: Vec<f32> = Vec::new();
        let mut mzmaxs: Vec<f32> = Vec::new();
        let mut present_set: BTreeSet<String> = BTreeSet::new();

        // Need to get full feature data to extract rtmin, rtmax, mzmin, mzmax
        for fts in features {
            for i in 0..fts.size() {
                if fts.feature_group[i] == *fg {
                    rts.push(fts.rt[i]);
                    mzs.push(fts.mz[i]);
                    masses.push(fts.mass[i]);
                    rtmins.push(fts.rtmin[i]);
                    rtmaxs.push(fts.rtmax[i]);
                    mzmins.push(fts.mzmin[i]);
                    mzmaxs.push(fts.mzmax[i]);
                    present_set.insert(fts.analysis.clone());
                }
            }
        }

        if rts.is_empty() {
            continue;
        }

        // Calculate medians
        rts.sort_by(f32::total_cmp);
        mzs.sort_by(f32::total_cmp);
        masses.sort_by(f32::total_cmp);

        let mid = rts.len() / 2;
        info.median_rt = if rts.len() % 2 == 0 {
            (rts[mid - 1] + rts[mid]) / 2.0
        } else {
            rts[mid]
        };
        info.median_mz = if mzs.len() % 2 == 0 {
            (mzs[mid - 1] + mzs[mid]) / 2.0
        } else {
            mzs[mid]
        };
        info.median_mass = if masses.len() % 2 == 0 {
            (masses[mid - 1] + masses[mid]) / 2.0
        } else {
            masses[mid]
        };

        // Calculate RT range
        info.rt_range = rts[rts.len() - 1] - rts[0];

        // Calculate min/max ranges from feature boundaries
        info.min_rtmin = rtmins.iter().copied().fold(f32::INFINITY, f32::min);
        info.max_rtmax = rtmaxs.iter().copied().fold(f32::NEG_INFINITY, f32::max);
        info.min_mzmin = mzmins.iter().copied().fold(f32::INFINITY, f32::min);
        info.max_mzmax = mzmaxs.iter().copied().fold(f32::NEG_INFINITY, f32::max);

        // If withinReplicate is true, only consider gaps within replicates that have the feature
        if within_replicate {
            // Build set of replicates that have this feature group
            let mut replicates_with_feature: BTreeSet<String> = BTreeSet::new();
            for analysis in &present_set {
                if let Some(replicate) = analysis_replicate_map.get(analysis) {
                    replicates_with_feature.insert(replicate.clone());
                }
            }

            // Identify present and missing analyses only within replicates that have the feature
            for analysis in analyses {
                let Some(replicate) = analysis_replicate_map.get(analysis) else {
                    continue;
                };

                // Only consider this analysis if its replicate has the feature group
                if !replicates_with_feature.contains(replicate) {
                    continue;
                }

                if present_set.contains(analysis) {
                    info.present_analyses.push(analysis.clone());
                } else {
                    info.missing_analyses.push(analysis.clone());
                }
            }
        } else {
            // Identify present and missing analyses across all analyses
            for analysis in analyses {
                if present_set.contains(analysis) {
                    info.present_analyses.push(analysis.clone());
                } else {
                    info.missing_analyses.push(analysis.clone());
                }
            }
        }

        // Only add groups that have missing analyses
        if !info.missing_analyses.is_empty() {
            group_infos.push(info);
        }
    }

    group_infos
}

/// `nta::gap_filling::extract_eic_for_gap_filling` — build an EIC for one
/// target m/z within an RT window. Plumbing adaptation: the C++ takes an
/// `MS_FILE` + `MS_SPECTRA_HEADERS` and calls `get_spectra({idx})` per scan
/// index; here the already-read `spectra` slice replaces both, with every
/// header field mapped to the matching `Spectrum` field.
pub fn extract_eic_for_gap_filling(
    spectra: &[Spectrum],
    target_mz: f32,
    target_rt: f32,
    mz_expand: f32,
    rt_expand: f32,
    min_traces_intensity: f32,
    ppm_threshold: f32,
) -> EicData {
    let mut eic = EicData::default();
    eic.valid = false;
    eic.size = 0;

    // ppmThreshold is accepted for API parity but unused in the C++ body.
    let _ = ppm_threshold;

    // Define RT and m/z windows
    let rt_min = target_rt - rt_expand;
    let rt_max = target_rt + rt_expand;
    let mz_min = target_mz - mz_expand;
    let mz_max = target_mz + mz_expand;

    // Find spectra within RT window
    let mut spec_indices: Vec<usize> = Vec::new();
    for (i, spec) in spectra.iter().enumerate() {
        if spec.level == 1 && spec.retention_time >= rt_min && spec.retention_time <= rt_max {
            spec_indices.push(i);
        }
    }

    if spec_indices.is_empty() {
        return eic;
    }

    // Extract traces within m/z window
    for &idx in &spec_indices {
        let spec = &spectra[idx];
        let rt = spec.retention_time;

        if spec.mz.len() < 2 {
            continue;
        }

        for i in 0..spec.mz.len() {
            if spec.mz[i] >= mz_min
                && spec.mz[i] <= mz_max
                && spec.intensity[i] >= min_traces_intensity
            {
                eic.rt.push(rt);
                eic.mz.push(spec.mz[i]);
                eic.intensity.push(spec.intensity[i]);
                eic.noise.push(min_traces_intensity); // Placeholder noise
            }
        }
    }

    eic.size = eic.rt.len() as i32;
    eic.valid = eic.size > 0;

    eic
}

/// `nta::gap_filling::pick_peak_from_eic` — aggregate, smooth and pick the
/// peak from one EIC; returns a fully populated `FilledFeatureInfo` with
/// defaults when the peak is rejected. The C++ `debug` flag only gated
/// logging and is dropped.
#[allow(clippy::too_many_arguments)]
pub fn pick_peak_from_eic(
    eic_data: &EicData,
    analysis: &str,
    feature_group: &str,
    original_feature: &str,
    target_rt: f32,
    target_mz: f32,
    target_mass: f32,
    polarity: i32,
    rt_apex_deviation: f32,
    min_snr: f32,
    min_traces: i32,
    max_width: f32,
    min_gaussian_fit: f32,
) -> FilledFeatureInfo {
    let mut filled_feature = FilledFeatureInfo::default();
    filled_feature.analysis = analysis.to_string();
    filled_feature.feature_group = feature_group.to_string();
    filled_feature.original_feature = original_feature.to_string();
    filled_feature.filled = true;
    filled_feature.polarity = polarity;

    // Default values
    filled_feature.rt = target_rt;
    filled_feature.mz = target_mz;
    filled_feature.mass = target_mass;
    filled_feature.intensity = 0.0;
    filled_feature.area = 0.0;
    filled_feature.noise = 0.0;
    filled_feature.sn = 0.0;
    filled_feature.rtmin = target_rt;
    filled_feature.rtmax = target_rt;
    filled_feature.width = 0.0;
    filled_feature.mzmin = target_mz;
    filled_feature.mzmax = target_mz;
    filled_feature.ppm = 0.0;
    filled_feature.fwhm_rt = 0.0;
    filled_feature.gaussian_A = 0.0;
    filled_feature.gaussian_mu = target_rt;
    filled_feature.gaussian_sigma = 0.0;
    filled_feature.gaussian_r2 = 0.0;
    filled_feature.correction = 1.0;
    filled_feature.eic_size = 0;

    if !eic_data.valid || eic_data.size < min_traces {
        return filled_feature;
    }

    // Sort by RT
    let mut sorted_rt = eic_data.rt.clone();
    let mut sorted_mz = eic_data.mz.clone();
    let mut sorted_intensity = eic_data.intensity.clone();
    let mut sorted_noise = eic_data.noise.clone();

    let sort_indices = get_sort_indices_float(&sorted_rt);
    reorder_multiple_vectors4(
        &sort_indices,
        &mut sorted_rt,
        &mut sorted_mz,
        &mut sorted_intensity,
        &mut sorted_noise,
    );

    // Aggregate intensity by RT (sum intensities at same RT) and keep max m/z
    let mut rt_intensity_map: BTreeMap<TotalF32, f32> = BTreeMap::new();
    let mut rt_mz_map: BTreeMap<TotalF32, f32> = BTreeMap::new();
    for i in 0..sorted_rt.len() {
        let rt = TotalF32::from(sorted_rt[i]);
        *rt_intensity_map.entry(rt).or_insert(0.0) += sorted_intensity[i];
        // Keep the maximum m/z value for each RT
        let entry = rt_mz_map.entry(rt).or_insert(0.0);
        if sorted_mz[i] > *entry {
            *entry = sorted_mz[i];
        }
    }

    let mut unique_rt: Vec<f32> = Vec::new();
    let mut unique_intensity: Vec<f32> = Vec::new();
    let mut unique_mz: Vec<f32> = Vec::new();
    for (rt, intensity) in &rt_intensity_map {
        unique_rt.push(rt.0);
        unique_intensity.push(*intensity);
        unique_mz.push(rt_mz_map[rt]);
    }

    if (unique_rt.len() as i32) < min_traces {
        return filled_feature;
    }

    // Degenerate empty EIC (C++ is UB here); never a real peak.
    if unique_rt.is_empty() {
        return filled_feature;
    }

    // Baseline is the minimum intensity (noise level)
    let baseline_level = unique_intensity
        .iter()
        .copied()
        .fold(f32::INFINITY, f32::min);

    // Only smooth if we have enough points (>= 5), using small window to preserve peak shape
    let smoothed: Vec<f32> = if unique_rt.len() >= 5 {
        // Use window=3 and order=1 (linear) for minimal smoothing that preserves peak shape
        smooth_intensity_savitzky_golay(&unique_intensity, 3)
    } else {
        unique_intensity.clone() // Use raw intensity for very small EICs
    };

    // Find apex as maximum intensity (first occurrence, as std::max_element)
    let max_smoothed = smoothed.iter().copied().fold(f32::NEG_INFINITY, f32::max);
    let apex_idx = smoothed
        .iter()
        .position(|&x| x == max_smoothed)
        .unwrap_or(0);
    let apex_rt = unique_rt[apex_idx];
    let apex_intensity = smoothed[apex_idx];

    // Check if apex is within search window
    if (apex_rt - target_rt).abs() > rt_apex_deviation {
        return filled_feature;
    }

    // Find FWHM boundaries
    let half_max = (apex_intensity + baseline_level) / 2.0;
    let mut left_bound = apex_idx;
    let mut right_bound = apex_idx;

    // Find left boundary
    let mut i = apex_idx;
    while i > 0 {
        i -= 1;
        if smoothed[i] <= half_max {
            left_bound = i;
            break;
        }
        left_bound = i;
    }

    // Find right boundary
    for i in (apex_idx + 1)..smoothed.len() {
        if smoothed[i] <= half_max {
            right_bound = i;
            break;
        }
        right_bound = i;
    }

    // Ensure minimum width
    let width_count = (right_bound - left_bound + 1) as i32;
    if width_count < min_traces {
        let expand = (min_traces - width_count) / 2;
        left_bound = left_bound.saturating_sub(expand.max(0) as usize);
        right_bound = (right_bound + expand.max(0) as usize).min(unique_rt.len() - 1);
    }

    // Ensure maximum width
    let mut peak_width = unique_rt[right_bound] - unique_rt[left_bound];
    if peak_width > max_width {
        // Shrink from edges
        while peak_width > max_width && left_bound < apex_idx {
            left_bound += 1;
            peak_width = unique_rt[right_bound] - unique_rt[left_bound];
        }
        while peak_width > max_width && right_bound > apex_idx {
            right_bound -= 1;
            peak_width = unique_rt[right_bound] - unique_rt[left_bound];
        }
    }

    // Extract peak data
    let peak_rt = unique_rt[left_bound..=right_bound].to_vec();
    let peak_intensity = unique_intensity[left_bound..=right_bound].to_vec();
    let peak_mz = unique_mz[left_bound..=right_bound].to_vec();
    let peak_baseline = vec![baseline_level; peak_rt.len()];

    // Calculate peak metrics
    let max_intensity = peak_intensity
        .iter()
        .copied()
        .fold(f32::NEG_INFINITY, f32::max);
    // S/N = (signal - baseline) / baseline
    let signal_above_baseline = max_intensity - baseline_level;
    let peak_sn = if baseline_level > 0.0 {
        signal_above_baseline / baseline_level
    } else {
        0.0
    };

    if peak_sn < min_snr {
        return filled_feature;
    }

    // Calculate area (trapezoidal rule)
    let mut area = 0.0f32;
    for i in 1..peak_rt.len() {
        let dt = peak_rt[i] - peak_rt[i - 1];
        let avg_int = (peak_intensity[i] + peak_intensity[i - 1]) / 2.0;
        area += avg_int * dt;
    }

    // Calculate FWHM (both RT and m/z) - do this before Gaussian fit as it's more reliable
    let fwhm = calculate_fwhm_rt(&peak_rt, &peak_intensity);
    let (fwhm_rt_calc, fwhm_mz_calc, _mean_mz_fwhm) =
        calculate_fwhm_combined(&peak_rt, &peak_mz, &peak_intensity);

    // Calculate average m/z in peak window
    let avg_mz = if peak_mz.is_empty() {
        0.0
    } else {
        peak_mz.iter().sum::<f32>() / peak_mz.len() as f32
    };

    // Calculate quality metrics using raw vectors (before encoding)
    let peak_area_val = calculate_area(&peak_rt, &peak_intensity);
    let jaggedness_val = calculate_jaggedness(&peak_intensity);
    let sharpness_val = calculate_sharpness(&peak_rt, &peak_intensity, peak_area_val);
    let asymmetry_val = calculate_asymmetry(&peak_rt, &peak_intensity);
    // For modality, use smoothed data if we smoothed earlier
    let smoothed_for_modality: Vec<f32> = if peak_rt.len() >= 5 {
        smooth_intensity_savitzky_golay(&peak_intensity, 3)
    } else {
        peak_intensity.clone()
    };
    let modality_val = calculate_modality(&smoothed_for_modality, 0.1);
    let plates_val = calculate_theoretical_plates(apex_rt, fwhm);

    // Fit Gaussian - provide initial values for optimization
    let mut gaussian_baseline = peak_intensity[0].min(*peak_intensity.last().unwrap_or(&0.0));
    let mut gaussian_A = max_intensity - gaussian_baseline;
    let mut gaussian_mu = apex_rt;
    let mut gaussian_sigma = fwhm / 2.355; // FWHM = 2.355 * sigma for Gaussian
    if gaussian_sigma <= 0.0 {
        gaussian_sigma = (peak_rt[peak_rt.len() - 1] - peak_rt[0]) / 4.0;
    }

    let (fit_a, fit_mu, fit_sigma, fit_base) = fit_gaussian(
        &peak_rt,
        &peak_intensity,
        gaussian_A,
        gaussian_mu,
        gaussian_sigma,
        gaussian_baseline,
    );
    gaussian_A = fit_a;
    gaussian_mu = fit_mu;
    gaussian_sigma = fit_sigma;
    gaussian_baseline = fit_base;

    // Calculate R² for the fit
    let gaussian_r2 = calculate_gaussian_rsquared(
        &peak_rt,
        &peak_intensity,
        gaussian_A,
        gaussian_mu,
        gaussian_sigma,
        gaussian_baseline,
    );

    // Calculate mass based on polarity and adduct
    let proton_mass: f32 = 1.007276;
    let mass;
    let adduct;
    if polarity > 0 {
        // Positive mode: [M+H]+
        mass = avg_mz - proton_mass;
        adduct = "[M+H]+";
    } else if polarity < 0 {
        // Negative mode: [M-H]-
        mass = avg_mz + proton_mass;
        adduct = "[M-H]-";
    } else {
        // Unknown polarity
        mass = avg_mz;
        adduct = "";
    }

    // Fill in feature info - use apex_rt (actual maximum) as RT
    filled_feature.rt = apex_rt;
    filled_feature.mz = avg_mz;
    filled_feature.mass = mass;
    filled_feature.adduct = adduct.to_string();
    filled_feature.intensity = max_intensity;
    filled_feature.area = area;
    filled_feature.noise = baseline_level;
    filled_feature.sn = peak_sn;
    filled_feature.rtmin = peak_rt[0];
    filled_feature.rtmax = peak_rt[peak_rt.len() - 1];
    filled_feature.width = peak_rt[peak_rt.len() - 1] - peak_rt[0];
    filled_feature.mzmin = peak_mz.iter().copied().fold(f32::INFINITY, f32::min);
    filled_feature.mzmax = peak_mz.iter().copied().fold(f32::NEG_INFINITY, f32::max);
    filled_feature.ppm = (avg_mz - target_mz).abs() / target_mz * 1e6;
    filled_feature.fwhm_rt = fwhm;
    filled_feature.fwhm_mz = fwhm_mz_calc;
    filled_feature.gaussian_A = gaussian_A;
    filled_feature.gaussian_mu = gaussian_mu;
    filled_feature.gaussian_sigma = gaussian_sigma;
    filled_feature.gaussian_r2 = gaussian_r2;
    filled_feature.jaggedness = jaggedness_val;
    filled_feature.sharpness = sharpness_val;
    filled_feature.asymmetry = asymmetry_val;
    filled_feature.modality = modality_val as f32;
    filled_feature.plates = plates_val;
    filled_feature.eic_size = peak_rt.len() as i32;

    // Encode EIC data
    filled_feature.eic_rt = encode_floats_base64(&peak_rt);
    filled_feature.eic_mz = encode_floats_base64(&peak_mz);
    filled_feature.eic_intensity = encode_floats_base64(&peak_intensity);
    filled_feature.eic_baseline = encode_floats_base64(&peak_baseline);
    filled_feature.eic_smoothed = encode_floats_base64(&peak_intensity);

    let _ = (fwhm_rt_calc, min_gaussian_fit);

    filled_feature
}

/// One gap to fill in one analysis (local analogue of the C++ `GAP_INFO`).
struct GapInfo {
    analysis: String,
    analysis_idx: usize,
    feature_group: String,
    target_id: String,
    median_rt: f32,
    median_mz: f32,
    median_mass: f32,
    polarity: i32,
}

/// Observed feature-group boundaries (local analogue of the C++ `GROUP_RANGES`).
#[allow(dead_code)]
struct GroupRanges {
    min_rtmin: f32,
    max_rtmax: f32,
    min_mzmin: f32,
    max_mzmax: f32,
    polarity: i32,
}

/// `nta::gap_filling::fill_features_impl` — analyze feature groups, extract
/// EICs for every gap analysis with `get_spectra_targets`, pick peaks and
/// append filled features. Plumbing adaptation: spectra come from
/// `ProjectNonTargetAnalysis::spectra(analysis_idx)` instead of an opened
/// `MS_FILE` + `spectra_headers_at`.
#[allow(clippy::too_many_arguments)]
pub fn fill_features_impl(
    nta_data: &mut ProjectNonTargetAnalysis,
    within_replicate: bool,
    filtered: bool,
    rt_expand: f32,
    mz_expand: f32,
    max_peak_width: f32,
    min_traces_intensity: f32,
    min_number_traces: i32,
    min_intensity: f32,
    rt_apex_deviation: f32,
    min_signal_to_noise_ratio: f32,
    min_gaussian_fit: f32,
) -> streamfind_rust_core::Result<()> {
    let analyses: Vec<String> = nta_data.analysis_names().to_vec();
    let replicates: Vec<String> = nta_data.replicate_names().to_vec();
    let file_paths: Vec<String> = nta_data.file_paths().to_vec();

    // Analyze feature groups to identify gaps
    let group_infos = analyze_feature_groups(
        &nta_data.feature_buffers,
        &analyses,
        &replicates,
        within_replicate,
        1,
    ); // minSamples = 1

    if group_infos.is_empty() {
        return Ok(());
    }

    // Track filled features
    let mut total_gaps: i32 = 0;
    let mut filled_gaps: i32 = 0;

    // Track filled features count per analysis for feature naming
    let mut filled_features_count: HashMap<String, i32> = HashMap::new();

    // Build analysis file map
    let mut analysis_file_map: HashMap<String, String> = HashMap::new();
    for (i, analysis) in analyses.iter().enumerate() {
        analysis_file_map.insert(
            analysis.clone(),
            file_paths.get(i).cloned().unwrap_or_default(),
        );
    }

    // Build analysis index map
    let mut analysis_index_map: HashMap<String, usize> = HashMap::new();
    for (i, analysis) in analyses.iter().enumerate() {
        analysis_index_map.insert(analysis.clone(), i);
    }

    let mut group_ranges_map: HashMap<String, GroupRanges> = HashMap::new();
    let mut gaps_by_file: HashMap<String, Vec<GapInfo>> = HashMap::new();

    for group_info in &group_infos {
        // Determine polarity from existing features
        let mut polarity = 0;
        for fts in &nta_data.feature_buffers {
            for j in 0..fts.size() {
                if fts.feature_group[j] == group_info.feature_group {
                    polarity = fts.polarity[j];
                    break;
                }
            }
            if polarity != 0 {
                break;
            }
        }

        // Store ranges for this feature group
        group_ranges_map.insert(
            group_info.feature_group.clone(),
            GroupRanges {
                min_rtmin: group_info.min_rtmin,
                max_rtmax: group_info.max_rtmax,
                min_mzmin: group_info.min_mzmin,
                max_mzmax: group_info.max_mzmax,
                polarity,
            },
        );

        // Group by file
        for missing_analysis in &group_info.missing_analyses {
            let Some(file_path) = analysis_file_map.get(missing_analysis) else {
                continue;
            };
            let Some(&analysis_idx) = analysis_index_map.get(missing_analysis) else {
                continue;
            };
            if analysis_idx >= nta_data.size() {
                continue;
            }

            let target_id = format!("GAP_{}_{}", group_info.feature_group, missing_analysis);

            gaps_by_file
                .entry(file_path.clone())
                .or_default()
                .push(GapInfo {
                    analysis: missing_analysis.clone(),
                    analysis_idx,
                    feature_group: group_info.feature_group.clone(),
                    target_id,
                    median_rt: group_info.median_rt,
                    median_mz: group_info.median_mz,
                    median_mass: group_info.median_mass,
                    polarity,
                });
            total_gaps += 1;
        }
    }

    // Process each analysis/file
    for gaps in gaps_by_file.values() {
        if gaps.is_empty() {
            continue;
        }

        // Open MS file once per analysis (spectra are cached by the project)
        let spectra = nta_data.spectra(gaps[0].analysis_idx)?;

        // Build MS_TARGETS for all gaps in this file, but skip those already present as filtered features
        let mut targets: Vec<TargetSpec> = Vec::new();

        for gap in gaps {
            let ranges = &group_ranges_map[&gap.feature_group];
            let analysis_features = &mut nta_data.feature_buffers[gap.analysis_idx];
            let mut found_filtered_feature = false;

            for j in 0..analysis_features.size() {
                if analysis_features.filtered[j]
                    && analysis_features.rt[j] >= ranges.min_rtmin
                    && analysis_features.rt[j] <= ranges.max_rtmax
                    && analysis_features.mz[j] >= ranges.min_mzmin
                    && analysis_features.mz[j] <= ranges.max_mzmax
                    && analysis_features.polarity[j] == gap.polarity
                {
                    // Unfilter this feature
                    analysis_features.filtered[j] = false;
                    analysis_features.filter[j] = String::new();
                    analysis_features.feature_group[j] = gap.feature_group.clone();
                    filled_gaps += 1;
                    found_filtered_feature = true;
                    break;
                }
            }

            if !found_filtered_feature {
                // Only add to targets if not already recovered (this is the
                // exact "shrunk_targets" outcome: only valid gaps are kept)
                targets.push(TargetSpec {
                    id: gap.target_id.clone(),
                    level: 1,
                    polarity: gap.polarity,
                    precursor: false,
                    mz: gap.median_mz,
                    mzmin: ranges.min_mzmin - mz_expand,
                    mzmax: ranges.max_mzmax + mz_expand,
                    rt: gap.median_rt,
                    rtmin: ranges.min_rtmin - rt_expand,
                    rtmax: ranges.max_rtmax + rt_expand,
                    mobility: 0.0,
                });
            }
        }

        // Extract all EICs in one batch call (uses OpenMP internally)
        let all_eics = get_spectra_targets(&spectra, &targets, min_traces_intensity, 0.0);

        // Process each gap using extracted EICs
        for gap in gaps {
            // Get EIC for this specific target (all_eics is keyed by target id)
            let eic_points: Vec<&TargetPoint> = all_eics
                .iter()
                .filter(|point| point.id == gap.target_id)
                .collect();

            if (eic_points.len() as i32) < min_number_traces {
                continue;
            }

            // Build EIC_DATA from MS_TARGETS_SPECTRA
            let mut eic_data = EicData::default();
            eic_data.rt = eic_points.iter().map(|point| point.rt).collect();
            eic_data.mz = eic_points.iter().map(|point| point.mz).collect();
            eic_data.intensity = eic_points.iter().map(|point| point.intensity).collect();
            eic_data.noise = vec![min_traces_intensity; eic_points.len()];
            eic_data.size = eic_points.len() as i32;
            eic_data.valid = eic_data.size > 0;

            if !eic_data.valid {
                continue;
            }

            // Pick peak from EIC
            let filled_feature = pick_peak_from_eic(
                &eic_data,
                &gap.analysis,
                &gap.feature_group,
                "", // No original feature for filled
                gap.median_rt,
                gap.median_mz,
                gap.median_mass,
                gap.polarity,
                rt_apex_deviation,
                min_signal_to_noise_ratio,
                min_number_traces,
                max_peak_width,
                min_gaussian_fit,
            );

            // Check if filling was successful
            if filled_feature.intensity < min_intensity {
                continue;
            }

            // Create FEATURE from FILLED_FEATURE_INFO
            let mut new_feature = NtaFeatureRow::default();
            new_feature.analysis = filled_feature.analysis.clone();

            // Increment filled feature count for this analysis
            *filled_features_count
                .entry(gap.analysis.clone())
                .or_insert(0) += 1;
            let feature_number = filled_features_count[&gap.analysis];

            let polarity_suffix = if filled_feature.polarity > 0 {
                "POS"
            } else {
                "NEG"
            };
            new_feature.feature = format!(
                "FL{}_MZ{}_RT{}_{}",
                feature_number,
                filled_feature.mz.round() as i32,
                filled_feature.rt.round() as i32,
                polarity_suffix
            );

            new_feature.feature_group = filled_feature.feature_group.clone();
            new_feature.feature_component = String::new();
            new_feature.adduct = filled_feature.adduct.clone();
            new_feature.rt = filled_feature.rt as f64;
            new_feature.mz = filled_feature.mz as f64;
            new_feature.mass = filled_feature.mass as f64;
            new_feature.intensity = filled_feature.intensity as f64;
            new_feature.noise = filled_feature.noise as f64;
            new_feature.sn = filled_feature.sn as f64;
            new_feature.area = filled_feature.area as f64;
            new_feature.rtmin = filled_feature.rtmin as f64;
            new_feature.rtmax = filled_feature.rtmax as f64;
            new_feature.width = filled_feature.width as f64;
            new_feature.mzmin = filled_feature.mzmin as f64;
            new_feature.mzmax = filled_feature.mzmax as f64;
            new_feature.ppm = filled_feature.ppm as f64;
            new_feature.fwhm_rt = filled_feature.fwhm_rt as f64;
            new_feature.fwhm_mz = filled_feature.fwhm_mz as f64;
            new_feature.gaussian_A = filled_feature.gaussian_A as f64;
            new_feature.gaussian_mu = filled_feature.gaussian_mu as f64;
            new_feature.gaussian_sigma = filled_feature.gaussian_sigma as f64;
            new_feature.gaussian_r2 = filled_feature.gaussian_r2 as f64;
            new_feature.jaggedness = filled_feature.jaggedness as f64;
            new_feature.sharpness = filled_feature.sharpness as f64;
            new_feature.asymmetry = filled_feature.asymmetry as f64;
            new_feature.modality = filled_feature.modality as i32;
            new_feature.plates = filled_feature.plates as f64;

            new_feature.polarity = filled_feature.polarity;
            new_feature.filtered = false;
            new_feature.filter = String::new();
            new_feature.filled = true;
            new_feature.correction = filled_feature.correction as f64;
            new_feature.eic_size = filled_feature.eic_size;
            new_feature.eic_rt = filled_feature.eic_rt.clone();
            new_feature.eic_mz = filled_feature.eic_mz.clone();
            new_feature.eic_intensity = filled_feature.eic_intensity.clone();
            new_feature.eic_baseline = filled_feature.eic_baseline.clone();
            new_feature.eic_smoothed = filled_feature.eic_smoothed.clone();
            new_feature.ms1_size = 0;
            new_feature.ms1_mz = String::new();
            new_feature.ms1_intensity = String::new();
            new_feature.ms2_size = 0;
            new_feature.ms2_mz = String::new();
            new_feature.ms2_intensity = String::new();

            // Add to features
            nta_data.feature_buffers[gap.analysis_idx].append_feature(&new_feature);
            filled_gaps += 1;
        }
    }

    let _ = (total_gaps, filled_gaps, filtered);

    Ok(())
}
