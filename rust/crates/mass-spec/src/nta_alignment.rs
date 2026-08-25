//! Feature alignment and grouping for `ProjectNonTargetAnalysis`.
//!
//! Ported from `core/domains/mass_spec/src/nta_alignment.cpp` +
//! `include/streamfind/mass_spec/nta_alignment.hpp` (`nta::alignment`):
//! internal-standards and OBI-Warp RT-shift calculation with linear
//! interpolation and binned correction, plus tolerance-based feature
//! grouping. Math, ordering, and rounding are kept identical to the C++.

use std::collections::{BTreeMap, BTreeSet};

use crate::nta::ProjectNonTargetAnalysis;

/// Internal standard information (mirrors `nta::alignment::InternalStandard`).
#[derive(Debug, Clone, Default)]
pub struct InternalStandard {
    pub analysis: String,
    pub name: String,
    pub exp_rt: f32,
    pub avg_rt: f32,
    pub rt_shift: f32,
}

/// Feature information for alignment (mirrors `nta::alignment::AlignmentFeature`).
#[derive(Debug, Clone, Default)]
pub struct AlignmentFeature {
    pub analysis: String,
    pub feature: String,
    pub rt: f32,
    pub mass: f32,
    pub intensity: f32,
    pub polarity: i32,
    pub rt_corrected: f32,
    pub group_id: i32,
    pub feature_group: String,
}

/// Anchor point for OBI-Warp alignment (mirrors `nta::alignment::AnchorPoint`).
#[derive(Debug, Clone, Default)]
pub struct AnchorPoint {
    pub ref_rt: f32,
    pub target_rt: f32,
    pub rt_shift: f32,
    pub weight: f32,
}

/// Helper to interpolate the RT shift at a given RT.
///
/// Mirrors `nta::alignment::interpolate_rt_shift`: finds the surrounding
/// anchor points (lower = largest anchor RT <= feature_rt, upper = smallest
/// anchor RT >= feature_rt) and linearly interpolates between their shifts.
pub fn interpolate_rt_shift(feature_rt: f32, anchor_rts: &[f32], anchor_shifts: &[f32]) -> f32 {
    if anchor_rts.is_empty() {
        return 0.0;
    }

    let mut lower_idx: i32 = -1;
    let mut upper_idx: i32 = -1;

    for i in 0..anchor_rts.len() {
        if anchor_rts[i] <= feature_rt {
            lower_idx = i as i32;
        }
        if anchor_rts[i] >= feature_rt && upper_idx == -1 {
            upper_idx = i as i32;
        }
    }

    if lower_idx == -1 && upper_idx == -1 {
        return 0.0;
    } else if lower_idx == -1 {
        return anchor_shifts[upper_idx as usize];
    } else if upper_idx == -1 {
        return anchor_shifts[lower_idx as usize];
    } else if lower_idx == upper_idx {
        return anchor_shifts[lower_idx as usize];
    } else {
        let lower_rt = anchor_rts[lower_idx as usize];
        let lower_shift = anchor_shifts[lower_idx as usize];
        let upper_rt = anchor_rts[upper_idx as usize];
        let upper_shift = anchor_shifts[upper_idx as usize];

        let weight = (feature_rt - lower_rt) / (upper_rt - lower_rt);
        lower_shift + weight * (upper_shift - lower_shift)
    }
}

/// Calculate RT shifts using internal standards with linear interpolation.
///
/// Mirrors `nta::alignment::calculate_rt_shifts_istd`: groups standards by
/// analysis, computes a binned shift curve over the global feature RT range,
/// and applies `rt - shift` per feature.
pub fn calculate_rt_shifts_istd(
    features: &mut Vec<AlignmentFeature>,
    internal_standards: &[InternalStandard],
    bin_size: f32,
) {
    // Group internal standards by analysis.
    let mut istd_by_analysis: BTreeMap<String, Vec<InternalStandard>> = BTreeMap::new();
    for istd in internal_standards {
        istd_by_analysis
            .entry(istd.analysis.clone())
            .or_default()
            .push(istd.clone());
    }

    // Sort internal standards by RT for each analysis.
    for pair in istd_by_analysis.values_mut() {
        pair.sort_unstable_by(|a, b| a.exp_rt.total_cmp(&b.exp_rt));
    }

    // Find global RT range across all features.
    // (`std::numeric_limits<float>::min()` is the smallest positive normal.)
    let mut min_rt = f32::MAX;
    let mut max_rt = f32::MIN_POSITIVE;
    for feature in features.iter() {
        if feature.rt < min_rt {
            min_rt = feature.rt;
        }
        if feature.rt > max_rt {
            max_rt = feature.rt;
        }
    }

    // Create RT bins.
    let mut num_bins = ((max_rt - min_rt) / bin_size).ceil() as i32;
    if num_bins < 1 {
        num_bins = 1;
    }

    // Calculate shift for each bin per analysis.
    let mut bin_shifts_by_analysis: BTreeMap<String, Vec<f32>> = BTreeMap::new();
    for (analysis_name, istd_analysis) in &istd_by_analysis {
        let mut anchor_rts = Vec::with_capacity(istd_analysis.len());
        let mut anchor_shifts = Vec::with_capacity(istd_analysis.len());
        for istd in istd_analysis {
            anchor_rts.push(istd.exp_rt);
            anchor_shifts.push(istd.rt_shift);
        }

        // Calculate shift for each RT bin center.
        let mut bin_shifts = vec![0.0; num_bins as usize];
        for i in 0..num_bins as usize {
            let bin_center = min_rt + (i as f32 + 0.5) * bin_size;
            bin_shifts[i] = interpolate_rt_shift(bin_center, &anchor_rts, &anchor_shifts);
        }

        bin_shifts_by_analysis.insert(analysis_name.clone(), bin_shifts);
    }

    // Apply RT-dependent correction for each feature using binned shifts.
    for feature in features.iter_mut() {
        let shifts = match bin_shifts_by_analysis.get(&feature.analysis) {
            Some(s) => s,
            None => {
                // No internal standards for this analysis.
                feature.rt_corrected = feature.rt;
                continue;
            }
        };

        // Find the bin for this feature's RT.
        let mut bin_idx = ((feature.rt - min_rt) / bin_size) as i32;
        if bin_idx < 0 {
            bin_idx = 0;
        }
        if bin_idx >= num_bins {
            bin_idx = num_bins - 1;
        }

        let shift = shifts[bin_idx as usize];
        feature.rt_corrected = feature.rt - shift;
    }
}

/// Calculate RT shifts using OBI-Warp alignment.
///
/// Mirrors `nta::alignment::calculate_rt_shifts_obiwarp`: picks the analysis
/// with the most features as reference, finds anchor points by mass-matching
/// reference features to each target analysis (closest RT within
/// `3 * rt_deviation`), then applies binned `rt - shift` corrections.
pub fn calculate_rt_shifts_obiwarp(
    features: &mut Vec<AlignmentFeature>,
    ppm_threshold: f32,
    rt_deviation: f32,
    bin_size: f32,
) {
    // Find reference analysis (most features).
    let mut analysis_counts: BTreeMap<String, i32> = BTreeMap::new();
    for feature in features.iter() {
        *analysis_counts.entry(feature.analysis.clone()).or_insert(0) += 1;
    }

    let mut ref_analysis = String::new();
    let mut max_count: i32 = 0;
    for (name, count) in &analysis_counts {
        if *count > max_count {
            max_count = *count;
            ref_analysis = name.clone();
        }
    }

    if max_count < 10 {
        // Insufficient features for alignment.
        for feature in features.iter_mut() {
            feature.rt_corrected = feature.rt;
        }
        return;
    }

    // Get reference features.
    let ref_features: Vec<AlignmentFeature> = features
        .iter()
        .filter(|feature| feature.analysis == ref_analysis)
        .cloned()
        .collect();

    // Group features by analysis (indices into `features`, like the C++
    // `std::vector<AlignmentFeature *>`).
    let mut features_by_analysis: BTreeMap<String, Vec<usize>> = BTreeMap::new();
    for (i, feature) in features.iter().enumerate() {
        features_by_analysis
            .entry(feature.analysis.clone())
            .or_default()
            .push(i);
    }

    // Process each analysis.
    for (analysis_name, target_indices) in &features_by_analysis {
        if *analysis_name == ref_analysis {
            // Reference sample has no shift.
            for &idx in target_indices {
                features[idx].rt_corrected = features[idx].rt;
            }
            continue;
        }

        if target_indices.len() < 10 {
            // Insufficient features for alignment.
            for &idx in target_indices {
                features[idx].rt_corrected = features[idx].rt;
            }
            continue;
        }

        // Find matching features between reference and target based on mass.
        let mut anchor_points: Vec<AnchorPoint> = Vec::new();

        for ref_feature in &ref_features {
            let mass_tolerance = ref_feature.mass * ppm_threshold / 1e6;
            let mass_min = ref_feature.mass - mass_tolerance;
            let mass_max = ref_feature.mass + mass_tolerance;

            // Find target features with matching mass.
            let mut min_rt_diff = rt_deviation * 3.0;
            let mut best_match: Option<usize> = None;

            for &idx in target_indices {
                let target_feature = &features[idx];
                if target_feature.mass >= mass_min && target_feature.mass <= mass_max {
                    let rt_diff = (target_feature.rt - ref_feature.rt).abs();
                    if rt_diff < min_rt_diff {
                        min_rt_diff = rt_diff;
                        best_match = Some(idx);
                    }
                }
            }

            if let Some(idx) = best_match {
                let target_feature = &features[idx];
                anchor_points.push(AnchorPoint {
                    ref_rt: ref_feature.rt,
                    target_rt: target_feature.rt,
                    rt_shift: target_feature.rt - ref_feature.rt,
                    weight: (ref_feature.intensity * target_feature.intensity).sqrt(),
                });
            }
        }

        if anchor_points.len() < 5 {
            // Insufficient anchor points.
            for &idx in target_indices {
                features[idx].rt_corrected = features[idx].rt;
            }
            continue;
        }

        // Sort anchor points by target RT.
        anchor_points.sort_unstable_by(|a, b| a.target_rt.total_cmp(&b.target_rt));

        // Extract anchor RTs and shifts.
        let mut anchor_rts = Vec::with_capacity(anchor_points.len());
        let mut anchor_shifts = Vec::with_capacity(anchor_points.len());
        for anchor in &anchor_points {
            anchor_rts.push(anchor.target_rt);
            anchor_shifts.push(anchor.rt_shift);
        }

        // Find RT range for this analysis.
        let mut min_rt = f32::MAX;
        let mut max_rt = f32::MIN_POSITIVE;
        for &idx in target_indices {
            let rt = features[idx].rt;
            if rt < min_rt {
                min_rt = rt;
            }
            if rt > max_rt {
                max_rt = rt;
            }
        }

        // Create RT bins and calculate shift for each bin.
        let mut num_bins = ((max_rt - min_rt) / bin_size).ceil() as i32;
        if num_bins < 1 {
            num_bins = 1;
        }

        let mut bin_shifts = vec![0.0; num_bins as usize];
        for i in 0..num_bins as usize {
            let bin_center = min_rt + (i as f32 + 0.5) * bin_size;
            bin_shifts[i] = interpolate_rt_shift(bin_center, &anchor_rts, &anchor_shifts);
        }

        // Apply RT-dependent correction for each feature using binned shifts.
        for &idx in target_indices {
            let mut bin_idx = ((features[idx].rt - min_rt) / bin_size) as i32;
            if bin_idx < 0 {
                bin_idx = 0;
            }
            if bin_idx >= num_bins {
                bin_idx = num_bins - 1;
            }

            let shift = bin_shifts[bin_idx as usize];
            features[idx].rt_corrected = features[idx].rt - shift;
        }
    }
}

/// Group features based on mass and corrected RT using tolerance-based
/// clustering. Mirrors `nta::alignment::group_features`: sorts by polarity,
/// mass, RT; greedily seeds groups; computes representative (median)
/// mass/RT; builds `FG<id>_M<mass>_RT<rt>[_POS|_NEG]` names; optionally
/// filters groups by minimum distinct-analysis count.
pub fn group_features(
    features: &mut Vec<AlignmentFeature>,
    ppm_threshold: f32,
    rt_deviation: f32,
    min_samples: i32,
) {
    // Sort features by polarity, mass, and RT for efficient grouping.
    features.sort_unstable_by(|a, b| {
        let rt_a = if a.rt_corrected.is_nan() { a.rt } else { a.rt_corrected };
        let rt_b = if b.rt_corrected.is_nan() { b.rt } else { b.rt_corrected };
        a.polarity
            .cmp(&b.polarity)
            .then_with(|| a.mass.total_cmp(&b.mass))
            .then_with(|| rt_a.total_cmp(&rt_b))
    });

    // Group features iteratively.
    let mut group_counter: i32 = 0;
    for feature in features.iter_mut() {
        feature.group_id = 0;
    }

    let n = features.len();
    for i in 0..n {
        if features[i].group_id > 0 {
            continue;
        }

        // Start a new group.
        group_counter += 1;
        features[i].group_id = group_counter;

        // Get reference mass and RT.
        let ref_mass = features[i].mass;
        let ref_rt = if features[i].rt_corrected.is_nan() {
            features[i].rt
        } else {
            features[i].rt_corrected
        };

        let mass_tolerance = ref_mass * ppm_threshold / 1e6;
        let mass_min = ref_mass - mass_tolerance;
        let mass_max = ref_mass + mass_tolerance;
        let rt_min = ref_rt - rt_deviation;
        let rt_max = ref_rt + rt_deviation;

        // Assign features within tolerance to this group (same polarity).
        let polarity_i = features[i].polarity;
        for j in (i + 1)..n {
            if features[j].group_id > 0 {
                continue;
            }
            if features[j].polarity != polarity_i {
                break; // Different polarity, no more matches.
            }
            if features[j].mass > mass_max {
                break; // No more matches possible.
            }

            let feature_rt = if features[j].rt_corrected.is_nan() {
                features[j].rt
            } else {
                features[j].rt_corrected
            };
            if features[j].mass >= mass_min && feature_rt >= rt_min && feature_rt <= rt_max {
                features[j].group_id = group_counter;
            }
        }
    }

    // Calculate representative mass and RT for each group (median values).
    let mut group_masses: BTreeMap<i32, Vec<f32>> = BTreeMap::new();
    let mut group_rts: BTreeMap<i32, Vec<f32>> = BTreeMap::new();
    let mut group_polarities: BTreeMap<i32, i32> = BTreeMap::new();

    for feature in features.iter() {
        if feature.group_id > 0 {
            group_masses.entry(feature.group_id).or_default().push(feature.mass);
            // Use uncorrected RT if rt_corrected is NaN.
            let rt_value = if feature.rt_corrected.is_nan() {
                feature.rt
            } else {
                feature.rt_corrected
            };
            group_rts.entry(feature.group_id).or_default().push(rt_value);
            group_polarities.insert(feature.group_id, feature.polarity);
        }
    }

    let mut group_names: BTreeMap<i32, String> = BTreeMap::new();
    for (group_id, masses) in &group_masses {
        // C++ copies these vectors (`auto masses = pair.second; auto rts = group_rts[group_id];`).
        let mut masses = masses.clone();
        let mut rts = group_rts[group_id].clone();
        let polarity = group_polarities[group_id];

        masses.sort_unstable_by(f32::total_cmp);
        rts.sort_unstable_by(f32::total_cmp);

        let median_mass = masses[masses.len() / 2];
        let median_rt = rts[rts.len() / 2];

        let polarity_suffix = if polarity > 0 {
            "_POS"
        } else if polarity < 0 {
            "_NEG"
        } else {
            ""
        };

        let group_name = format!(
            "FG{group_id}_M{}_RT{}{}",
            (median_mass.round()) as i32,
            (median_rt.round()) as i32,
            polarity_suffix
        );
        group_names.insert(*group_id, group_name);
    }

    // Filter groups by minimum samples.
    if min_samples > 1 {
        let mut group_analyses: BTreeMap<i32, BTreeSet<String>> = BTreeMap::new();
        for feature in features.iter() {
            if feature.group_id > 0 {
                group_analyses
                    .entry(feature.group_id)
                    .or_default()
                    .insert(feature.analysis.clone());
            }
        }

        let mut valid_groups: BTreeSet<i32> = BTreeSet::new();
        for (group_id, analyses) in &group_analyses {
            if analyses.len() as i32 >= min_samples {
                valid_groups.insert(*group_id);
            }
        }

        // Assign feature group names (empty for invalid groups).
        for feature in features.iter_mut() {
            if feature.group_id > 0 && valid_groups.contains(&feature.group_id) {
                feature.feature_group = group_names.get(&feature.group_id).cloned().unwrap_or_default();
            } else {
                feature.feature_group = String::new();
            }
        }
    } else {
        // Assign all feature group names.
        for feature in features.iter_mut() {
            if feature.group_id > 0 {
                feature.feature_group = group_names.get(&feature.group_id).cloned().unwrap_or_default();
            } else {
                feature.feature_group = String::new();
            }
        }
    }
}

/// Entry point mirroring `nta::alignment::group_features_impl`: collects the
/// per-analysis feature columns, applies the requested RT alignment
/// (`"internal_standards"`, `"obi_warp"`, or none), runs tolerance-based
/// grouping, and writes the computed `feature_group` strings back into the
/// project's feature buffers.
///
/// The C++ `debug` / `debug_rt` parameters only gated file logging and did
/// not change algorithm behavior, so they are not carried over.
pub fn group_features_impl(
    nta_data: &mut ProjectNonTargetAnalysis,
    method: &str,
    rt_deviation: f32,
    ppm_threshold: f32,
    min_samples: i32,
    bin_size: f32,
) -> streamfind_rust_core::Result<()> {
    // Collect all features from all analyses.
    let analysis_names: Vec<String> = nta_data.analysis_names().to_vec();
    let feature_buffers = &mut nta_data.feature_buffers;
    let internal_standard_buffers = &mut nta_data.internal_standard_buffers;

    let mut all_features: Vec<AlignmentFeature> = Vec::new();
    for a in 0..analysis_names.len() {
        let fts = &feature_buffers[a];
        for i in 0..fts.size() {
            all_features.push(AlignmentFeature {
                analysis: analysis_names[a].clone(),
                feature: fts.feature[i].clone(),
                rt: fts.rt[i],
                mass: fts.mass[i],
                intensity: fts.intensity[i],
                polarity: fts.polarity[i],
                rt_corrected: fts.rt[i], // Will be updated by alignment.
                group_id: 0,
                feature_group: String::new(),
            });
        }
    }

    if all_features.is_empty() {
        return Ok(());
    }

    // Prepare internal standards for alignment if using internal_standards method.
    let mut internal_standards: Vec<InternalStandard> = Vec::new();
    if method == "internal_standards" && !internal_standard_buffers.is_empty() {
        // Calculate average RT for each internal standard name across all analyses.
        let mut istd_rts_by_name: BTreeMap<String, Vec<f32>> = BTreeMap::new();
        let mut istd_analyses_by_name: BTreeMap<String, Vec<String>> = BTreeMap::new();

        for a in 0..internal_standard_buffers.len() {
            let istd_data = &internal_standard_buffers[a];
            for i in 0..istd_data.size() {
                istd_rts_by_name
                    .entry(istd_data.name[i].clone())
                    .or_default()
                    .push(istd_data.exp_rt[i] as f32);
                istd_analyses_by_name
                    .entry(istd_data.name[i].clone())
                    .or_default()
                    .push(istd_data.analysis[i].clone());
            }
        }

        // Calculate average RT for each internal standard.
        let mut avg_rt_by_name: BTreeMap<String, f32> = BTreeMap::new();
        for (name, rts) in &istd_rts_by_name {
            let sum: f32 = rts.iter().sum();
            avg_rt_by_name.insert(name.clone(), sum / rts.len() as f32);
        }

        // Create alignment::InternalStandard vector with calculated shifts.
        for a in 0..internal_standard_buffers.len() {
            let istd_data = &internal_standard_buffers[a];
            for i in 0..istd_data.size() {
                let exp_rt = istd_data.exp_rt[i] as f32;
                let avg_rt = avg_rt_by_name.get(&istd_data.name[i]).copied().unwrap_or(0.0);
                internal_standards.push(InternalStandard {
                    analysis: istd_data.analysis[i].clone(),
                    name: istd_data.name[i].clone(),
                    exp_rt,
                    avg_rt,
                    rt_shift: exp_rt - avg_rt,
                });
            }
        }
    }

    // Perform RT alignment based on method.
    if method == "internal_standards" {
        if !internal_standards.is_empty() {
            calculate_rt_shifts_istd(&mut all_features, &internal_standards, bin_size);
        } else {
            // No internal standards provided, no RT correction applied.
            for feature in all_features.iter_mut() {
                feature.rt_corrected = feature.rt;
            }
        }
    } else if method == "obi_warp" {
        calculate_rt_shifts_obiwarp(&mut all_features, ppm_threshold, rt_deviation, bin_size);
    } else {
        // No alignment.
        for feature in all_features.iter_mut() {
            feature.rt_corrected = feature.rt;
        }
    }

    // Group features using tolerance-based clustering.
    group_features(&mut all_features, ppm_threshold, rt_deviation, min_samples);

    // Update feature_group in NTA_DATA.
    for af in &all_features {
        // Find the analysis and feature.
        for a in 0..analysis_names.len() {
            if analysis_names[a] == af.analysis {
                let fts = &mut feature_buffers[a];
                for i in 0..fts.size() {
                    if fts.feature[i] == af.feature {
                        fts.feature_group[i] = af.feature_group.clone();
                        break;
                    }
                }
                break;
            }
        }
    }

    Ok(())
}