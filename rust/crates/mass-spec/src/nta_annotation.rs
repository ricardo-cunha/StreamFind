//! Isotope / adduct / fragment annotation of component features.
//!
//! Ported from `core/domains/mass_spec/src/nta_annotation.cpp` +
//! `core/domains/mass_spec/include/streamfind/mass_spec/nta_annotation.hpp`
//! (`nta::annotation`). Keep structs, method names, math, order and rounding
//! identical to the C++; only the plumbing (Rust types, method names) is
//! adapted.

use std::collections::{BTreeMap, BTreeSet, HashMap, HashSet};

use crate::nta::{NtaFeatureRow, NtaFeatures, ProjectNonTargetAnalysis};

// ---------------------------------------------------------------------------
// detail helpers (streamfind::nta_annotation_detail)
// ---------------------------------------------------------------------------

/// `std::fixed << std::setprecision(precision)` then strip trailing zeros and
/// any trailing '.' (fmt_num).
fn fmt_num(value: f64, precision: usize) -> String {
    let mut out = format!("{value:.precision$}");
    if out.contains('.') {
        while out.len() > 1 && out.ends_with('0') {
            out.pop();
        }
    }
    if !out.is_empty() && out.ends_with('.') {
        out.pop();
    }
    out
}

#[allow(dead_code)]
fn is_structured_cat(value: &str, cat: &str) -> bool {
    value.starts_with(&format!("cat={cat}"))
}

fn make_annotation_label(candidate: &AnnotationCandidate) -> String {
    format!(
        "cat={} | type={} | parent={} | element={} | ppm={} | rt={} | rel={}",
        candidate.cat,
        candidate.ty,
        candidate.parent_feature,
        candidate.element_or_delta,
        fmt_num(candidate.mass_error_ppm, 3),
        fmt_num(candidate.rt_error, 3),
        fmt_num(candidate.rel_intensity, 3)
    )
}

fn make_annotation_summary(candidate: &AnnotationCandidate) -> String {
    if candidate.cat.is_empty() || candidate.ty.is_empty() {
        String::new()
    } else {
        format!("{} {}", candidate.cat, candidate.ty)
    }
}

fn score_mass(mass_error_ppm: f64, ppm: f64) -> f64 {
    let denom = (ppm * 2.0).max(1.0);
    (1.0 - (mass_error_ppm / denom)).max(0.0)
}

fn score_rt(rt_error: f64) -> f64 {
    1.0 / (1.0 + rt_error)
}

fn isotope_effective_rt_error(rt_error: f64) -> f64 {
    const GRACE_WINDOW: f64 = 3.0;
    if rt_error <= GRACE_WINDOW {
        0.0
    } else {
        rt_error - GRACE_WINDOW
    }
}

fn score_rel(rel: f64, expected_min: f64, expected_max: f64) -> f64 {
    if expected_min <= 0.0 && expected_max <= 0.0 {
        if rel <= 0.0 {
            return 0.0;
        }
        return 1.0 / (1.0 + (rel - 1.0).abs());
    }
    if rel >= expected_min && rel <= expected_max {
        return 1.0;
    }
    let dist = if rel < expected_min {
        expected_min - rel
    } else {
        rel - expected_max
    };
    1.0 / (1.0 + dist * 5.0)
}

fn candidate_priority(cat: &str, ty: &str) -> i32 {
    if cat == "isotope" {
        return 4;
    }
    if cat == "adduct" {
        return if ty.contains("[2M+") || ty.contains("[2M-") {
            2
        } else {
            3
        };
    }
    if cat == "loss" {
        return 1;
    }
    0
}

fn candidate_score(candidate: &AnnotationCandidate, ppm: f64) -> f64 {
    if candidate.cat == "isotope" {
        let complexity = isotope_complexity(&candidate.element_or_delta);
        if candidate.mass_error_ppm > ppm {
            return -1.0;
        }
        let mut score = 0.68 * score_mass(candidate.mass_error_ppm, ppm)
            + 0.05 * score_rt(isotope_effective_rt_error(candidate.rt_error))
            + 0.17
                * score_rel(
                    candidate.rel_intensity,
                    candidate.expected_rel_intensity_min,
                    candidate.expected_rel_intensity_max,
                )
            + 0.10 * (candidate.priority as f64 / 4.0);
        score += 0.08 * isotope_priority_score(&candidate.element_or_delta);
        if complexity > 1 {
            score -= 0.08 * (complexity - 1) as f64;
            if complexity >= 3 {
                score -= 0.06;
            }
        }
        return score;
    }
    let mut score = 0.55 * score_mass(candidate.mass_error_ppm, ppm)
        + 0.20 * score_rt(candidate.rt_error)
        + 0.15
            * score_rel(
                candidate.rel_intensity,
                candidate.expected_rel_intensity_min,
                candidate.expected_rel_intensity_max,
            )
        + 0.10 * (candidate.priority as f64 / 4.0);
    if candidate.ty.contains("[2M+") || candidate.ty.contains("[2M-") {
        score -= 0.03;
    }
    score
}

fn candidate_better(lhs: &AnnotationCandidate, rhs: &AnnotationCandidate) -> bool {
    if lhs.score != rhs.score {
        return lhs.score > rhs.score;
    }
    if lhs.mass_error_ppm != rhs.mass_error_ppm {
        return lhs.mass_error_ppm < rhs.mass_error_ppm;
    }
    let lhs_rt_error = if lhs.cat == "isotope" {
        isotope_effective_rt_error(lhs.rt_error)
    } else {
        lhs.rt_error
    };
    let rhs_rt_error = if rhs.cat == "isotope" {
        isotope_effective_rt_error(rhs.rt_error)
    } else {
        rhs.rt_error
    };
    if lhs_rt_error != rhs_rt_error {
        return lhs_rt_error < rhs_rt_error;
    }
    if lhs.priority != rhs.priority {
        return lhs.priority > rhs.priority;
    }
    if lhs.cat == "isotope" && rhs.cat == "isotope" {
        let lhs_priority = isotope_priority_score(&lhs.element_or_delta);
        let rhs_priority = isotope_priority_score(&rhs.element_or_delta);
        if lhs_priority != rhs_priority {
            return lhs_priority > rhs_priority;
        }
        let lhs_complexity = isotope_complexity(&lhs.element_or_delta);
        let rhs_complexity = isotope_complexity(&rhs.element_or_delta);
        if lhs_complexity != rhs_complexity {
            return lhs_complexity < rhs_complexity;
        }
    }
    lhs.parent_index < rhs.parent_index
}

#[allow(dead_code)]
fn resolve_root_parent_feature(
    candidate: &AnnotationCandidate,
    best_candidate: &HashMap<i32, AnnotationCandidate>,
) -> String {
    if candidate.cat != "isotope" {
        return candidate.parent_feature.clone();
    }

    let mut resolved_parent = candidate.parent_feature.clone();
    let mut current_parent_index = candidate.parent_index;
    let mut visited: HashSet<i32> = HashSet::new();

    while current_parent_index >= 0 && visited.insert(current_parent_index) {
        let it = best_candidate.get(&current_parent_index);
        let it = match it {
            Some(it) => it,
            None => break,
        };
        resolved_parent = it.parent_feature.clone();
        if it.is_default || it.cat != "isotope" {
            break;
        }
        current_parent_index = it.parent_index;
    }

    resolved_parent
}

fn candidate_equals(lhs: &AnnotationCandidate, rhs: &AnnotationCandidate) -> bool {
    lhs.cat == rhs.cat
        && lhs.ty == rhs.ty
        && lhs.parent_feature == rhs.parent_feature
        && lhs.element_or_delta == rhs.element_or_delta
        && lhs.parent_index == rhs.parent_index
        && lhs.feature_index == rhs.feature_index
        && lhs.is_default == rhs.is_default
}

fn relation_candidate_creates_cycle(
    candidate: &AnnotationCandidate,
    state: &HashMap<i32, AnnotationCandidate>,
) -> bool {
    if candidate.is_default || candidate.parent_index < 0 {
        return false;
    }

    let origin = candidate.feature_index;
    let mut current = candidate.parent_index;
    let mut visited: HashSet<i32> = HashSet::new();

    while current >= 0 && visited.insert(current) {
        if current == origin {
            return true;
        }
        let it = state.get(&current);
        let it = match it {
            Some(it) => it,
            None => return false,
        };
        if it.is_default || it.parent_index < 0 || it.parent_index == current {
            return false;
        }
        current = it.parent_index;
    }

    false
}

fn relation_chain_reaches_root(
    feature_idx: i32,
    state: &HashMap<i32, AnnotationCandidate>,
    visited: &mut HashSet<i32>,
) -> bool {
    if !visited.insert(feature_idx) {
        return false;
    }

    let it = state.get(&feature_idx);
    let it = match it {
        Some(it) => it,
        None => return false,
    };
    let candidate = it;
    if candidate.is_default {
        return true;
    }
    if candidate.parent_index < 0 || candidate.parent_index == feature_idx {
        return false;
    }
    let parent_it = state.get(&candidate.parent_index);
    let parent_it = match parent_it {
        Some(parent_it) => parent_it,
        None => return false,
    };
    let parent = parent_it;
    if candidate.cat == "adduct" {
        return parent.is_default;
    }
    if candidate.cat == "loss" {
        if parent.is_default {
            return true;
        }
        if parent.cat != "loss" {
            return false;
        }
        return relation_chain_reaches_root(candidate.parent_index, state, visited);
    }
    false
}

fn relation_candidate_is_valid(
    candidate: &AnnotationCandidate,
    state: &HashMap<i32, AnnotationCandidate>,
) -> bool {
    if candidate.is_default {
        return true;
    }
    if candidate.parent_index < 0 || candidate.parent_index == candidate.feature_index {
        return false;
    }
    if relation_candidate_creates_cycle(candidate, state) {
        return false;
    }

    let parent_it = state.get(&candidate.parent_index);
    let parent_it = match parent_it {
        Some(parent_it) => parent_it,
        None => return false,
    };
    let parent = parent_it;
    if candidate.cat == "adduct" {
        return parent.is_default;
    }
    if candidate.cat == "loss" {
        if parent.is_default {
            return true;
        }
        if parent.cat != "loss" {
            return false;
        }
        let mut visited: HashSet<i32> = HashSet::new();
        return relation_chain_reaches_root(candidate.parent_index, state, &mut visited);
    }
    false
}

fn neutral_mass_from_base_ion(ft: &NtaFeatureRow) -> f64 {
    const PROTON: f64 = 1.007276;
    if ft.polarity == 1 {
        ft.mz - PROTON
    } else {
        ft.mz + PROTON
    }
}

fn theoretical_mz_from_adduct(neutral_mass: f64, adduct: &Adduct) -> f64 {
    (neutral_mass * adduct.multiplicity as f64) + adduct.mass_distance as f64
}

fn ppm_error(observed: f64, theoretical: f64) -> f64 {
    if theoretical == 0.0 {
        return f64::INFINITY;
    }
    (observed - theoretical).abs() / theoretical.abs() * 1e6
}

fn split_string(value: &str, delim: char) -> Vec<String> {
    let mut out = Vec::new();
    for item in value.split(delim) {
        if !item.is_empty() {
            out.push(item.to_string());
        }
    }
    out
}

fn trim_copy(value: &str) -> String {
    value.trim().to_string()
}

struct IsotopeElementSpec {
    elements: Vec<String>,
    ranges: HashMap<String, (i32, i32)>,
}

fn parse_isotope_element_specs(specs: &[String]) -> IsotopeElementSpec {
    let mut parsed = IsotopeElementSpec {
        elements: Vec::new(),
        ranges: HashMap::new(),
    };
    let mut seen: HashSet<String> = HashSet::new();

    for raw_spec in specs {
        let spec = trim_copy(raw_spec);
        if spec.is_empty() {
            continue;
        }

        let colon_pos = spec.find(':');
        let element = match colon_pos {
            Some(p) => spec[..p].to_string(),
            None => spec.clone(),
        };
        if seen.insert(element.clone()) {
            parsed.elements.push(element.clone());
        }

        let colon_pos = match colon_pos {
            Some(p) => p,
            None => continue,
        };

        let range = &spec[colon_pos + 1..];
        let dash_pos = range.find('-');
        let dash_pos = match dash_pos {
            Some(p) => p,
            None => continue,
        };

        let min_n: i32 = range[..dash_pos].parse().unwrap_or(0);
        let max_n: i32 = range[dash_pos + 1..].parse().unwrap_or(0);
        parsed.ranges.insert(element, (min_n, max_n));
    }

    parsed
}

fn isotope_complexity(element_label: &str) -> i32 {
    if element_label.is_empty() {
        return 0;
    }
    split_string(element_label, '/').len() as i32
}

fn isotope_priority_value(token: &str) -> f64 {
    match token {
        "13C" => 1.00,
        "37Cl" => 0.98,
        "81Br" => 0.98,
        "34S" => 0.92,
        "33S" => 0.82,
        "15N" => 0.78,
        "18O" => 0.62,
        "17O" => 0.40,
        "2H" => 0.35,
        "29Si" => 0.70,
        "30Si" => 0.62,
        "25Mg" => 0.45,
        "26Mg" => 0.48,
        "41K" => 0.40,
        "44Ca" => 0.32,
        "54Fe" => 0.30,
        "57Fe" => 0.34,
        "65Cu" => 0.28,
        "66Zn" => 0.30,
        "68Zn" => 0.26,
        "77Se" => 0.36,
        "78Se" => 0.42,
        "80Se" => 0.44,
        "10B" => 0.24,
        "36S" => 0.18,
        _ => 0.2,
    }
}

fn isotope_priority_score(element_label: &str) -> f64 {
    let tokens = split_string(element_label, '/');
    if tokens.is_empty() {
        return 0.0;
    }
    let mut score = 0.0;
    for token in &tokens {
        score += isotope_priority_value(token);
    }
    score / tokens.len() as f64
}

fn isotope_delta_value(token: &str) -> f64 {
    match token {
        "13C" => 1.0033548378,
        "2H" => 1.0062767,
        "10B" => 0.996809,
        "15N" => 0.9970349,
        "17O" => 1.004217,
        "18O" => 2.004246,
        "25Mg" => 0.999711,
        "26Mg" => 1.995796,
        "29Si" => 0.999568,
        "30Si" => 1.996844,
        "33S" => 0.999388,
        "34S" => 1.995796,
        "36S" => 3.995010,
        "37Cl" => 1.997050,
        "81Br" => 1.997953,
        "41K" => 1.998119,
        "44Ca" => 3.998159,
        "54Fe" => -1.004391,
        "57Fe" => 2.995294,
        "65Cu" => 1.998204,
        "66Zn" => 1.999059,
        "68Zn" => 3.995796,
        "77Se" => 0.997953,
        "78Se" => 1.996004,
        "80Se" => 3.995010,
        _ => 0.0,
    }
}

fn isotope_mass_delta(element_label: &str) -> f64 {
    let mut total = 0.0;
    for token in split_string(element_label, '/') {
        total += isotope_delta_value(&token);
    }
    total
}

fn extract_isotope_element(legacy_label: &str) -> String {
    let tokens = split_string(legacy_label, ' ');
    if tokens.len() >= 4 {
        tokens[2].clone()
    } else {
        String::new()
    }
}

fn extract_isotope_type(legacy_label: &str) -> String {
    let tokens = split_string(legacy_label, ' ');
    match tokens.last() {
        Some(last) => last.clone(),
        None => String::new(),
    }
}

// ---------------------------------------------------------------------------
// ISOTOPE
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct Isotope {
    pub element: String,
    pub isotope: String,
    pub mass_distance: f32,
    pub abundance: f32,
    pub abundance_monoisotopic: f32,
    pub min: i32,
    pub max: i32,
}

impl Isotope {
    fn new(e: &str, i: &str, md: f32, ab: f32, ab_mono: f32, mi: i32, ma: i32) -> Self {
        Self {
            element: e.to_string(),
            isotope: i.to_string(),
            mass_distance: md,
            abundance: ab,
            abundance_monoisotopic: ab_mono,
            min: mi,
            max: ma,
        }
    }
}

// ---------------------------------------------------------------------------
// ISOTOPE_SET
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct IsotopeSet {
    pub data: Vec<Isotope>,
}

impl Default for IsotopeSet {
    fn default() -> Self {
        Self {
            data: vec![
                Isotope::new("C", "13C", 1.0033548378, 0.01078, 0.988922, 1, 60),
                Isotope::new("H", "2H", 1.0062767, 0.00015574, 0.99984426, 0, 120),
                Isotope::new("B", "10B", 0.996809, 0.199, 0.801, 0, 2),
                Isotope::new("N", "15N", 0.9970349, 0.003663, 0.996337, 0, 10),
                Isotope::new("O", "17O", 1.004217, 0.00037, 0.99763, 0, 20),
                Isotope::new("O", "18O", 2.004246, 0.00200, 0.99763, 0, 20),
                Isotope::new("Mg", "25Mg", 0.999711, 0.10, 0.7899, 0, 2),
                Isotope::new("Mg", "26Mg", 1.995796, 0.1101, 0.7899, 0, 2),
                Isotope::new("Si", "29Si", 0.999568, 0.04683, 0.92230, 0, 6),
                Isotope::new("Si", "30Si", 1.996844, 0.03087, 0.92230, 0, 6),
                Isotope::new("S", "33S", 0.999388, 0.00750, 0.95018, 0, 4),
                Isotope::new("S", "34S", 1.995796, 0.04215, 0.95018, 0, 4),
                Isotope::new("S", "36S", 3.995010, 0.00017, 0.95018, 0, 4),
                Isotope::new("Cl", "37Cl", 1.997050, 0.24229, 0.75771, 0, 6),
                Isotope::new("Br", "81Br", 1.997953, 0.49314, 0.50686, 0, 4),
                Isotope::new("K", "41K", 1.998119, 0.0673, 0.9327, 0, 2),
                Isotope::new("Ca", "44Ca", 3.998159, 0.02086, 0.96941, 0, 2),
                Isotope::new("Fe", "54Fe", -1.004391, 0.05845, 0.91754, 0, 2),
                Isotope::new("Fe", "57Fe", 2.995294, 0.02119, 0.91754, 0, 2),
                Isotope::new("Cu", "65Cu", 1.998204, 0.3085, 0.6915, 0, 2),
                Isotope::new("Zn", "66Zn", 1.999059, 0.2773, 0.4917, 0, 2),
                Isotope::new("Zn", "68Zn", 3.995796, 0.1845, 0.4917, 0, 2),
                Isotope::new("Se", "77Se", 0.997953, 0.0763, 0.4961, 0, 2),
                Isotope::new("Se", "78Se", 1.996004, 0.2377, 0.4961, 0, 2),
                Isotope::new("Se", "80Se", 3.995010, 0.4961, 0.4961, 0, 2),
            ],
        }
    }
}

impl IsotopeSet {
    pub fn filter(&mut self, el: &[String]) {
        let el_set: HashSet<&String> = el.iter().collect();
        let mut data_filtered: Vec<Isotope> = Vec::new();
        for iso in &self.data {
            if el_set.contains(&iso.element) {
                data_filtered.push(iso.clone());
            }
        }
        self.data = data_filtered;
    }

    pub fn set_ranges(&mut self, ranges: &HashMap<String, (i32, i32)>) {
        for iso in &mut self.data {
            if let Some(range) = ranges.get(&iso.element) {
                iso.min = range.0;
                iso.max = range.1;
            }
        }
    }
}

// ---------------------------------------------------------------------------
// ISOTOPE_COMBINATIONS
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct IsotopeCombinations {
    pub step: Vec<i32>,
    pub isotopes_str: Vec<String>,
    pub abundances: Vec<f32>,
    pub abundances_monoisotopic: Vec<f32>,
    pub min: Vec<i32>,
    pub max: Vec<i32>,
    pub tensor_combinations: Vec<Vec<String>>,
    pub tensor_mass_distances: Vec<Vec<f32>>,
    pub tensor_abundances: Vec<Vec<f32>>,
    pub mass_distances: Vec<f32>,
    pub length: i32,
}

impl IsotopeCombinations {
    pub fn new(isotopes: &IsotopeSet, max_number_elements: i32) -> Self {
        let mut combinations_set: BTreeSet<Vec<String>> = BTreeSet::new();

        let mut isotopes_str: Vec<String> = Vec::new();
        let mut abundances: Vec<f32> = Vec::new();
        let mut abundances_monoisotopic: Vec<f32> = Vec::new();
        let mut min: Vec<i32> = Vec::new();
        let mut max: Vec<i32> = Vec::new();

        for iso in &isotopes.data {
            isotopes_str.push(iso.isotope.clone());
            abundances.push(iso.abundance);
            abundances_monoisotopic.push(iso.abundance_monoisotopic);
            min.push(iso.min);
            max.push(iso.max);
        }

        for iso in &isotopes_str {
            combinations_set.insert(vec![iso.clone()]);
        }

        for n in 1..=max_number_elements {
            let mut new_combinations_set: BTreeSet<Vec<String>> = BTreeSet::new();
            let existing: Vec<Vec<String>> = combinations_set.iter().cloned().collect();

            for mut combination in existing {
                if combination[0] == "2H" || combination[0] == "17O" {
                    continue;
                }
                if n > 1 && (combination[0] == "15N" || combination[0] == "33S") {
                    continue;
                }
                if combination.len() >= 2 && (combination[1] == "15N" || combination[1] == "33S") {
                    continue;
                }
                for iso in &isotopes_str {
                    if iso == "2H" || iso == "17O" {
                        continue;
                    }
                    if n > 1 && (iso == "15N" || iso == "33S") {
                        continue;
                    }
                    combination.push(iso.clone());
                    combination.sort();
                    new_combinations_set.insert(combination.clone());
                }
            }
            for c in new_combinations_set {
                combinations_set.insert(c);
            }
        }

        let tensor_combinations_unordered: Vec<Vec<String>> =
            combinations_set.iter().cloned().collect();
        let length = tensor_combinations_unordered.len() as i32;

        let isotopes_mass_distances: Vec<f32> =
            isotopes.data.iter().map(|iso| iso.mass_distance).collect();

        let mut tensor_mass_distances_unordered: Vec<Vec<f32>> = vec![Vec::new(); length as usize];
        let mut tensor_abundances_unordered: Vec<Vec<f32>> = vec![Vec::new(); length as usize];
        let mut mass_distances_unordered: Vec<f32> = vec![0.0; length as usize];

        for i in 0..length as usize {
            let combination = &tensor_combinations_unordered[i];
            let combination_length = combination.len();
            let mut md: Vec<f32> = vec![0.0; combination_length];
            let mut ab: Vec<f32> = vec![0.0; combination_length];
            for j in 0..combination_length {
                let iso = &combination[j];
                let idx = isotopes_str.iter().position(|x| x == iso).unwrap();
                md[j] = isotopes_mass_distances[idx];
                ab[j] = abundances[idx];
                mass_distances_unordered[i] =
                    mass_distances_unordered[i] + isotopes_mass_distances[idx];
            }
            tensor_mass_distances_unordered[i] = md;
            tensor_abundances_unordered[i] = ab;
        }

        let mut order_idx: Vec<usize> = (0..length as usize).collect();
        order_idx
            .sort_by(|&i, &j| mass_distances_unordered[i].total_cmp(&mass_distances_unordered[j]));

        let mut tensor_combinations: Vec<Vec<String>> = vec![Vec::new(); length as usize];
        let mut tensor_mass_distances: Vec<Vec<f32>> = vec![Vec::new(); length as usize];
        let mut tensor_abundances: Vec<Vec<f32>> = vec![Vec::new(); length as usize];
        let mut mass_distances: Vec<f32> = vec![0.0; length as usize];
        let mut step: Vec<i32> = vec![0; length as usize];

        for i in 0..length as usize {
            tensor_combinations[i] = tensor_combinations_unordered[order_idx[i]].clone();
            tensor_mass_distances[i] = tensor_mass_distances_unordered[order_idx[i]].clone();
            tensor_abundances[i] = tensor_abundances_unordered[order_idx[i]].clone();
            mass_distances[i] = mass_distances_unordered[order_idx[i]];
            step[i] = mass_distances[i].round() as i32;
        }

        Self {
            step,
            isotopes_str,
            abundances,
            abundances_monoisotopic,
            min,
            max,
            tensor_combinations,
            tensor_mass_distances,
            tensor_abundances,
            mass_distances,
            length,
        }
    }
}

// ---------------------------------------------------------------------------
// ISOTOPE_CHAIN
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct IsotopeChain {
    pub chain: Vec<NtaFeatureRow>,
    pub candidate_indices: Vec<i32>,
    pub charge: Vec<i32>,
    pub step: Vec<i32>,
    pub mz: Vec<f32>,
    pub rt: Vec<f32>,
    pub mzr: Vec<f32>,
    pub isotope: Vec<String>,
    pub mass_distance: Vec<f32>,
    pub theoretical_mass_distance: Vec<f32>,
    pub mass_distance_error: Vec<f32>,
    pub time_error: Vec<f32>,
    pub abundance: Vec<f32>,
    pub theoretical_abundance_min: Vec<f32>,
    pub theoretical_abundance_max: Vec<f32>,
    pub number_carbons: f32,
    pub length: i32,
}

impl IsotopeChain {
    pub fn new(z: i32, mono_ion: &NtaFeatureRow, mono_mzr: f32) -> Self {
        let mut chain: Vec<NtaFeatureRow> = Vec::new();
        chain.resize(1, NtaFeatureRow::default());
        let mut candidate_indices: Vec<i32> = Vec::new();
        candidate_indices.resize(1, 0);
        let mut charge: Vec<i32> = Vec::new();
        charge.resize(1, 0);
        let mut step: Vec<i32> = Vec::new();
        step.resize(1, 0);
        let mut mz: Vec<f32> = Vec::new();
        mz.resize(1, 0.0);
        let mut rt: Vec<f32> = Vec::new();
        rt.resize(1, 0.0);
        let mut mzr: Vec<f32> = Vec::new();
        mzr.resize(1, 0.0);
        let mut isotope: Vec<String> = Vec::new();
        isotope.resize(1, String::new());
        let mut mass_distance: Vec<f32> = Vec::new();
        mass_distance.resize(1, 0.0);
        let mut theoretical_mass_distance: Vec<f32> = Vec::new();
        theoretical_mass_distance.resize(1, 0.0);
        let mut mass_distance_error: Vec<f32> = Vec::new();
        mass_distance_error.resize(1, 0.0);
        let mut time_error: Vec<f32> = Vec::new();
        time_error.resize(1, 0.0);
        let mut abundance: Vec<f32> = Vec::new();
        abundance.resize(1, 0.0);
        let mut theoretical_abundance_min: Vec<f32> = Vec::new();
        theoretical_abundance_min.resize(1, 0.0);
        let mut theoretical_abundance_max: Vec<f32> = Vec::new();
        theoretical_abundance_max.resize(1, 0.0);

        chain[0] = mono_ion.clone();
        candidate_indices[0] = 0;
        charge[0] = z;
        step[0] = 0;
        mz[0] = mono_ion.mz as f32;
        rt[0] = mono_ion.rt as f32;
        mzr[0] = mono_mzr;
        isotope[0] = String::new();
        mass_distance[0] = 0.0;
        theoretical_mass_distance[0] = 0.0;
        mass_distance_error[0] = 0.0;
        time_error[0] = 0.0;
        abundance[0] = 1.0;
        theoretical_abundance_min[0] = 0.0;
        theoretical_abundance_max[0] = 0.0;

        Self {
            chain,
            candidate_indices,
            charge,
            step,
            mz,
            rt,
            mzr,
            isotope,
            mass_distance,
            theoretical_mass_distance,
            mass_distance_error,
            time_error,
            abundance,
            theoretical_abundance_min,
            theoretical_abundance_max,
            number_carbons: 0.0,
            length: 1,
        }
    }
}

// ---------------------------------------------------------------------------
// ADDUCT
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct Adduct {
    pub element: String,
    pub polarity: i32,
    pub cat: String,
    pub ty: String,
    pub charge: i32,
    pub multiplicity: i32,
    pub mass_distance: f32,
}

impl Adduct {
    fn new(e: &str, p: i32, c: &str, t: &str, md: f32, z: i32, m: i32) -> Self {
        Self {
            element: e.to_string(),
            polarity: p,
            cat: c.to_string(),
            ty: t.to_string(),
            charge: z,
            multiplicity: m,
            mass_distance: md,
        }
    }
}

// ---------------------------------------------------------------------------
// ADDUCT_SET
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct AdductSet {
    pub neutralizers: Vec<Adduct>,
    pub all_adducts: Vec<Adduct>,
}

impl Default for AdductSet {
    fn default() -> Self {
        Self {
            neutralizers: vec![
                Adduct::new("H", 1, "[M+H]+", "[M+H]+", -1.007276, 1, 1),
                Adduct::new("H", -1, "[M-H]-", "[M-H]-", 1.007276, 1, 1),
            ],
            all_adducts: vec![
                Adduct::new("H", 1, "adduct", "[M+H]+", 1.007276, 1, 1),
                Adduct::new("Na", 1, "adduct", "[M+Na]+", 22.989218, 1, 1),
                Adduct::new("K", 1, "adduct", "[M+K]+", 38.963158, 1, 1),
                Adduct::new("NH4", 1, "adduct", "[M+NH4]+", 18.033823, 1, 1),
                Adduct::new("ACN+H", 1, "adduct", "[M+ACN+H]+", 42.033823, 1, 1),
                Adduct::new("CH3OH+H", 1, "adduct", "[M+CH3OH+H]+", 33.033489, 1, 1),
                Adduct::new("2H", 1, "adduct", "[2M+H]+", 1.007276, 1, 2),
                Adduct::new("2Na", 1, "adduct", "[2M+Na]+", 22.989218, 1, 2),
                Adduct::new("2K", 1, "adduct", "[2M+K]+", 38.963158, 1, 2),
                Adduct::new("2NH4", 1, "adduct", "[2M+NH4]+", 18.033823, 1, 2),
                Adduct::new("-H", -1, "adduct", "[M-H]-", -1.007276, 1, 1),
                Adduct::new("Cl", -1, "adduct", "[M+Cl]-", 34.969402, 1, 1),
                Adduct::new("Br", -1, "adduct", "[M+Br]-", 78.918885, 1, 1),
                Adduct::new("CHO2", -1, "adduct", "[M+CHO2]-", 44.998201, 1, 1),
                Adduct::new("CH3COO", -1, "adduct", "[M+CH3COO]-", 59.013851, 1, 1),
                Adduct::new("FA-H", -1, "adduct", "[M+FA-H]-", 44.998201, 1, 1),
                Adduct::new("2-H", -1, "adduct", "[2M-H]-", -1.007276, 1, 2),
                Adduct::new("2Cl", -1, "adduct", "[2M+Cl]-", 34.969402, 1, 2),
                Adduct::new("2FA-H", -1, "adduct", "[2M+FA-H]-", 44.998201, 1, 2),
            ],
        }
    }
}

impl AdductSet {
    pub fn neutralizer(&self, pol: &i32) -> f32 {
        if *pol == 1 {
            self.neutralizers[0].mass_distance
        } else {
            self.neutralizers[1].mass_distance
        }
    }

    pub fn adducts(&self, pol: i32) -> Vec<Adduct> {
        let mut out: Vec<Adduct> = Vec::new();
        if pol == 1 {
            for a in &self.all_adducts {
                if a.polarity == 1 {
                    out.push(a.clone());
                }
            }
        }
        if pol == -1 {
            for a in &self.all_adducts {
                if a.polarity == -1 {
                    out.push(a.clone());
                }
            }
        }
        out
    }
}

// ---------------------------------------------------------------------------
// FRAGMENT_LOSS
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct FragmentLoss {
    pub name: String,
    pub formula: String,
    pub mass_loss: f32,
    pub polarity: i32,
}

impl FragmentLoss {
    fn new(n: &str, f: &str, ml: f32, p: i32) -> Self {
        Self {
            name: n.to_string(),
            formula: f.to_string(),
            mass_loss: ml,
            polarity: p,
        }
    }
}

// ---------------------------------------------------------------------------
// FRAGMENT_LOSS_SET
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct FragmentLossSet {
    pub all_losses: Vec<FragmentLoss>,
}

impl Default for FragmentLossSet {
    fn default() -> Self {
        Self {
            all_losses: vec![
                FragmentLoss::new("water", "H2O", 18.010565, 0),
                FragmentLoss::new("carbon dioxide", "CO2", 43.989829, 0),
                FragmentLoss::new("ammonia", "NH3", 17.026549, 1),
                FragmentLoss::new("carbon monoxide", "CO", 27.994915, 0),
                FragmentLoss::new("methyl", "CH3", 15.023475, 0),
                FragmentLoss::new("formic acid", "CH2O2", 46.005479, -1),
                FragmentLoss::new("hydrogen chloride", "HCl", 35.976678, 0),
                FragmentLoss::new("hydrogen fluoride", "HF", 20.006229, 0),
                FragmentLoss::new("sulfur dioxide", "SO2", 63.961901, 0),
                FragmentLoss::new("sulfur trioxide", "SO3", 79.956815, 0),
                FragmentLoss::new("sulfuric acid", "H2SO4", 97.967379, 0),
                FragmentLoss::new("methanol", "CH3OH", 32.026215, 0),
                FragmentLoss::new("ethylene", "C2H4", 28.031300, 0),
                FragmentLoss::new("acetylene", "C2H2", 26.015650, 0),
                FragmentLoss::new("nitric oxide", "NO", 29.997989, 0),
                FragmentLoss::new("nitrogen dioxide", "NO2", 45.992904, 0),
                FragmentLoss::new("nitrous acid", "HNO2", 46.005479, 0),
                FragmentLoss::new("nitric acid", "HNO3", 62.000394, 0),
                FragmentLoss::new("methylene", "CH2", 14.015650, 0),
                FragmentLoss::new("ethanol", "C2H6O", 46.041865, 0),
                FragmentLoss::new("phosphorous acid", "HPO3", 79.966331, 0),
                FragmentLoss::new("phosphoric acid", "H3PO4", 97.976896, 0),
            ],
        }
    }
}

impl FragmentLossSet {
    pub fn losses(&self, pol: i32) -> Vec<FragmentLoss> {
        let mut out: Vec<FragmentLoss> = Vec::new();
        for loss in &self.all_losses {
            if loss.polarity == 0 || loss.polarity == pol {
                out.push(loss.clone());
            }
        }
        out
    }
}

// ---------------------------------------------------------------------------
// CANDIDATE_CHAIN
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Default)]
pub struct CandidateChain {
    pub chain: Vec<NtaFeatureRow>,
    pub indices: Vec<i32>,
    pub isotope_theoretical_mass_distance: HashMap<i32, f32>,
    pub isotope_theoretical_abundance_min: HashMap<i32, f32>,
    pub isotope_theoretical_abundance_max: HashMap<i32, f32>,
}

impl CandidateChain {
    pub fn clear(&mut self) {
        self.chain.clear();
        self.indices.clear();
        self.isotope_theoretical_mass_distance.clear();
        self.isotope_theoretical_abundance_min.clear();
        self.isotope_theoretical_abundance_max.clear();
    }

    pub fn size(&self) -> usize {
        self.chain.len()
    }

    pub fn sort_by_mz(&mut self) {
        if self.chain.is_empty() {
            return;
        }

        let mut new_order: Vec<usize> = (0..self.chain.len()).collect();
        new_order.sort_by(|&i1, &i2| self.chain[i1].mz.total_cmp(&self.chain[i2].mz));

        let mut chain_sorted: Vec<NtaFeatureRow> = Vec::new();
        let mut indices_sorted: Vec<i32> = Vec::new();

        for i in 0..self.chain.len() {
            chain_sorted.push(self.chain[new_order[i]].clone());
            indices_sorted.push(new_order[i] as i32);
        }

        self.chain = chain_sorted;
        self.indices = indices_sorted;
    }

    pub fn get_chain_mzr(&self, _ppm: f32) -> Vec<f32> {
        if self.chain.is_empty() {
            return Vec::new();
        }

        let mut mzr: Vec<f32> = vec![0.0; self.chain.len()];
        const MIN_PPM: f32 = 10.0;

        for i in 0..self.chain.len() {
            let fwhm_mz = self.chain[i].fwhm_mz as f32;
            let mz = self.chain[i].mz as f32;
            let fwhm_ppm = (fwhm_mz / mz) * 1e6f32;

            if fwhm_ppm >= MIN_PPM {
                mzr[i] = fwhm_mz / 2.0;
            } else {
                mzr[i] = (MIN_PPM * mz) / 1e6f32;
            }
        }
        mzr
    }

    pub fn get_max_mzr(&self, ppm: f32) -> f32 {
        if self.chain.is_empty() {
            return 0.0;
        }
        let mzr = self.get_chain_mzr(ppm);
        mzr.iter().cloned().fold(f32::NEG_INFINITY, f32::max)
    }

    pub fn find_isotopic_candidates(
        &mut self,
        ft: &NtaFeatureRow,
        fts: &NtaFeatures,
        ft_index: i32,
        max_isotopes: i32,
        component_indices: Option<&Vec<i32>>,
        assigned_features: Option<&HashSet<i32>>,
    ) {
        let feature = ft.feature.clone();
        let polarity = ft.polarity;
        let mz = ft.mz as f32;
        let max_mz_chain = (mz + max_isotopes as f32) * 1.05;

        self.chain.push(ft.clone());
        self.indices.push(ft_index);

        let search_indices: Vec<i32> = match component_indices {
            Some(ci) => ci.clone(),
            None => (0..fts.size() as i32).collect(),
        };

        for z in search_indices {
            if let Some(assigned) = assigned_features {
                if assigned.contains(&z) {
                    continue;
                }
            }

            let zz = z as usize;
            let within_max_mz_chain = fts.mz[zz] > mz && fts.mz[zz] <= max_mz_chain;
            let same_polarity = fts.polarity[zz] == polarity;
            let not_main_ft = fts.feature[zz] != feature;

            if within_max_mz_chain && same_polarity && not_main_ft {
                self.chain.push(fts.get_feature(zz));
                self.indices.push(z);
            }
        }
    }

    pub fn annotate_isotopes(
        &mut self,
        combinations: &IsotopeCombinations,
        max_isotopes: i32,
        max_charge: i32,
        max_gaps: i32,
        ppm: f32,
    ) {
        let mut is_mplus = false;
        let mzr = self.get_max_mzr(ppm);
        let number_candidates = self.chain.len();
        let mono_ion = self.chain[0].clone();

        let mut isotopic_chains: Vec<IsotopeChain> = Vec::new();
        isotopic_chains.push(IsotopeChain::new(1, &mono_ion, mzr));
        if max_charge > 1 {
            for z in 2..=max_charge {
                isotopic_chains.push(IsotopeChain::new(z, &mono_ion, mzr));
            }
        }

        let number_charges = isotopic_chains.len();

        for z in 0..number_charges {
            let mut iso_chain = isotopic_chains[z].clone();
            let charge = iso_chain.charge[0];
            let number_steps = max_isotopes + 1;

            for s in 1..number_steps {
                if is_max_gap_reached(s, max_gaps, &iso_chain.step) {
                    break;
                }

                let mut which_combinations: Vec<usize> = Vec::new();
                for c in 0..combinations.length as usize {
                    if combinations.step[c] == s {
                        which_combinations.push(c);
                    }
                }

                let number_combinations = which_combinations.len();
                if number_combinations == 0 {
                    continue;
                }

                let mut mass_distances: Vec<f32> = vec![0.0; number_combinations];
                for c in 0..number_combinations {
                    mass_distances[c] =
                        combinations.mass_distances[which_combinations[c]] / charge as f32;
                }

                let mass_distance_max = mass_distances
                    .iter()
                    .cloned()
                    .fold(f32::NEG_INFINITY, f32::max);
                let mass_distance_min =
                    mass_distances.iter().cloned().fold(f32::INFINITY, f32::min);

                for candidate_idx in 1..number_candidates {
                    let candidate = self.chain[candidate_idx].clone();
                    let mz = candidate.mz as f32;
                    let rt = candidate.rt as f32;
                    let intensity = candidate.intensity as f32;

                    let candidate_mass_distance = mz - mono_ion.mz as f32;
                    let candidate_time_error = (rt - mono_ion.rt as f32).abs();
                    let candidate_mass_distance_min = candidate_mass_distance - mzr;
                    let candidate_mass_distance_max = candidate_mass_distance + mzr;

                    // M-ION check
                    if s == 1 {
                        if candidate_mass_distance_min < 1.007276f32
                            && candidate_mass_distance_max > 1.007276f32
                            && (intensity / mono_ion.intensity as f32) > 5.0
                        {
                            is_mplus = true;
                            break;
                        }
                    }

                    let mut combination_mass_error: f64 = 10.0;

                    if mass_distance_min - mzr < candidate_mass_distance
                        && mass_distance_max + mzr > candidate_mass_distance
                    {
                        for c in 0..number_combinations {
                            let candidate_mass_distance_error =
                                (mass_distances[c] - candidate_mass_distance).abs();
                            let combination =
                                &combinations.tensor_combinations[which_combinations[c]];

                            // Build combination string "a/b/c"
                            let mut concat_combination = combination[0].clone();
                            for e in 1..combination.len() {
                                concat_combination += "/";
                                concat_combination += &combination[e];
                            }

                            let mut min_rel_int: f32 = 1.0;
                            let mut max_rel_int: f32 = 1.0;

                            let mut isotope_map: BTreeMap<String, i32> = BTreeMap::new();
                            for e in 0..combination.len() {
                                *isotope_map.entry(combination[e].clone()).or_insert(0) += 1;
                            }

                            for (iso, iso_n) in &isotope_map {
                                let iso_idx = isotopes_str_index(&combinations.isotopes_str, iso);
                                let iso_ab = combinations.abundances[iso_idx];
                                let mono_ab = combinations.abundances_monoisotopic[iso_idx];
                                let mut min_el_num = combinations.min[iso_idx] as f32;
                                let mut max_el_num = combinations.max[iso_idx] as f32;

                                // Special handling for carbon isotopes
                                if *iso_n == 1 && iso == "13C" && s == 1 {
                                    iso_chain.number_carbons =
                                        intensity / (iso_ab * mono_ion.intensity as f32);
                                    min_el_num = iso_chain.number_carbons * 0.8;
                                    max_el_num = iso_chain.number_carbons * 1.2;
                                }

                                if iso == "13C" && s > 1 && iso_chain.number_carbons > 0.0 {
                                    min_el_num = iso_chain.number_carbons * 0.8;
                                    max_el_num = iso_chain.number_carbons * 1.2;
                                }

                                // Halogen isotopes in combination with other isotopes
                                if (iso == "37Cl" || iso == "81Br") && isotope_map.len() > 1 {
                                    min_el_num = 1.0;
                                    max_el_num = 2.0;
                                }

                                if *iso_n == 1 {
                                    let min_coef = ((min_el_num
                                        * mono_ab.powf(min_el_num - *iso_n as f32)
                                        * iso_ab)
                                        / mono_ab.powf(min_el_num))
                                        as f64;
                                    let max_coef = ((max_el_num
                                        * mono_ab.powf(max_el_num - *iso_n as f32)
                                        * iso_ab)
                                        / mono_ab.powf(max_el_num))
                                        as f64;

                                    min_rel_int = (min_rel_int as f64 * min_coef) as f32;
                                    max_rel_int = (max_rel_int as f64 * max_coef) as f32;
                                } else {
                                    let mut fact: u32 = 1;
                                    for a in 1..=*iso_n {
                                        fact = fact.wrapping_mul(a as u32);
                                    }

                                    let mut min_coef: f64 = ((mono_ab
                                        .powf(min_el_num - *iso_n as f32)
                                        * iso_ab.powi(*iso_n))
                                        / fact as f32)
                                        as f64;
                                    let mut max_coef: f64 = ((mono_ab
                                        .powf(max_el_num - *iso_n as f32)
                                        * iso_ab.powi(*iso_n))
                                        / fact as f32)
                                        as f64;

                                    min_coef = min_coef / mono_ab.powf(min_el_num) as f64;
                                    max_coef = max_coef / mono_ab.powf(max_el_num) as f64;

                                    min_coef =
                                        min_coef * min_el_num as f64 * (min_el_num - 1.0) as f64;
                                    max_coef =
                                        max_coef * max_el_num as f64 * (max_el_num - 1.0) as f64;

                                    for t in 2..=*iso_n - 1 {
                                        min_coef *= (min_el_num - t as f32) as f64;
                                        max_coef *= (max_el_num - t as f32) as f64;
                                    }

                                    min_rel_int = (min_rel_int as f64 * min_coef) as f32;
                                    max_rel_int = (max_rel_int as f64 * max_coef) as f32;
                                }
                            }

                            let rel_int = intensity / mono_ion.intensity as f32;

                            if (candidate_mass_distance_error as f64) < combination_mass_error
                                && candidate_mass_distance_error <= mzr * 1.3
                                && rel_int >= min_rel_int * 0.7
                                && rel_int <= max_rel_int * 1.3
                            {
                                combination_mass_error = candidate_mass_distance_error as f64;

                                let mut is_in_chain = false;
                                let mut is_in_chain_idx = 0usize;
                                for t in 1..iso_chain.chain.len() {
                                    if iso_chain.chain[t].feature == candidate.feature {
                                        is_in_chain = true;
                                        is_in_chain_idx = t;
                                        break;
                                    }
                                }

                                if is_in_chain {
                                    iso_chain.chain[is_in_chain_idx] = candidate.clone();
                                    iso_chain.candidate_indices[is_in_chain_idx] =
                                        candidate_idx as i32;
                                    iso_chain.charge[is_in_chain_idx] = charge;
                                    iso_chain.step[is_in_chain_idx] = s;
                                    iso_chain.mz[is_in_chain_idx] = mz;
                                    iso_chain.rt[is_in_chain_idx] = rt;
                                    iso_chain.mzr[is_in_chain_idx] = mzr;
                                    iso_chain.isotope[is_in_chain_idx] = concat_combination;
                                    iso_chain.mass_distance[is_in_chain_idx] =
                                        candidate_mass_distance;
                                    iso_chain.theoretical_mass_distance[is_in_chain_idx] =
                                        mass_distances[c];
                                    iso_chain.mass_distance_error[is_in_chain_idx] =
                                        candidate_mass_distance_error;
                                    iso_chain.time_error[is_in_chain_idx] = candidate_time_error;
                                    iso_chain.abundance[is_in_chain_idx] = rel_int;
                                    iso_chain.theoretical_abundance_min[is_in_chain_idx] =
                                        min_rel_int;
                                    iso_chain.theoretical_abundance_max[is_in_chain_idx] =
                                        max_rel_int;
                                } else {
                                    iso_chain.chain.push(candidate.clone());
                                    iso_chain.candidate_indices.push(candidate_idx as i32);
                                    iso_chain.charge.push(charge);
                                    iso_chain.step.push(s);
                                    iso_chain.mz.push(mz);
                                    iso_chain.rt.push(rt);
                                    iso_chain.mzr.push(mzr);
                                    iso_chain.isotope.push(concat_combination);
                                    iso_chain.mass_distance.push(candidate_mass_distance);
                                    iso_chain.theoretical_mass_distance.push(mass_distances[c]);
                                    iso_chain
                                        .mass_distance_error
                                        .push(candidate_mass_distance_error);
                                    iso_chain.time_error.push(candidate_time_error);
                                    iso_chain.abundance.push(rel_int);
                                    iso_chain.theoretical_abundance_min.push(min_rel_int);
                                    iso_chain.theoretical_abundance_max.push(max_rel_int);
                                    iso_chain.length += 1;
                                }
                            }
                        }
                    }
                }

                if is_mplus {
                    break;
                }
            }

            if is_mplus {
                break;
            }

            isotopic_chains[z] = iso_chain;
        }

        if !is_mplus {
            let mut best_chain = 0usize;
            for z in 0..number_charges {
                if isotopic_chains[z].length > isotopic_chains[best_chain].length {
                    best_chain = z;
                }
            }

            let sel_iso_chain = &isotopic_chains[best_chain];

            // Get monoisotopic m/z rounded to integer
            let mono_mz_rounded = (mono_ion.mz as f32).round() as i32;

            // Always assign [M+H]+ or [M-H]- to the monoisotopic ion (first in chain)
            let sel_charge = sel_iso_chain.charge[0];
            if self.chain[0].polarity == 1 {
                self.chain[0].adduct = if sel_charge > 1 {
                    format!("[M+H]{}+", sel_charge)
                } else {
                    "[M+H]+".to_string()
                };
            } else {
                self.chain[0].adduct = if sel_charge > 1 {
                    format!("[M-H]{}-", sel_charge)
                } else {
                    "[M-H]-".to_string()
                };
            }

            // Annotate isotopes if chain has more than just the monoisotopic ion
            if sel_iso_chain.length > 1 {
                for i in 1..sel_iso_chain.chain.len() {
                    let candidate_idx = sel_iso_chain.candidate_indices[i];
                    self.isotope_theoretical_mass_distance
                        .insert(candidate_idx, sel_iso_chain.theoretical_mass_distance[i]);
                    self.isotope_theoretical_abundance_min
                        .insert(candidate_idx, sel_iso_chain.theoretical_abundance_min[i]);
                    self.isotope_theoretical_abundance_max
                        .insert(candidate_idx, sel_iso_chain.theoretical_abundance_max[i]);

                    // Format: isotope MZXXX EL [M+n] where XXX=monoisotopic mass,
                    // EL=element, n=step
                    let label = format!(
                        "isotope MZ{} {} [M+{}]",
                        mono_mz_rounded, sel_iso_chain.isotope[i], sel_iso_chain.step[i]
                    );
                    self.chain[candidate_idx as usize].adduct = label;
                }
            }
        }
    }

    pub fn find_adduct_candidates(
        &mut self,
        ft: &NtaFeatureRow,
        fts: &NtaFeatures,
        ft_index: i32,
        component_indices: Option<&Vec<i32>>,
    ) {
        let feature = ft.feature.clone();
        let polarity = ft.polarity;
        let mz = ft.mz as f32;
        let max_mz_chain = mz + 100.0;

        self.chain.push(ft.clone());
        self.indices.push(ft_index);

        let search_indices: Vec<i32> = match component_indices {
            Some(ci) => ci.clone(),
            None => (0..fts.size() as i32).collect(),
        };

        for z in search_indices {
            let zz = z as usize;
            let within_max_mz_chain = fts.mz[zz] > mz && fts.mz[zz] <= max_mz_chain;
            let same_polarity = fts.polarity[zz] == polarity;
            let not_main_ft = fts.feature[zz] != feature;

            if within_max_mz_chain && same_polarity && not_main_ft {
                self.chain.push(fts.get_feature(zz));
                self.indices.push(z);
            }
        }
    }

    pub fn annotate_adducts(&mut self, ppm: f32) {
        let all_adducts = AdductSet::default();
        let pol = self.chain[0].polarity;
        let neutralizer = all_adducts.neutralizer(&pol);
        let adducts = all_adducts.adducts(pol);
        let number_candidates = self.chain.len();
        let mzr = self.get_chain_mzr(ppm);
        let mion_mz = self.chain[0].mz as f32;
        let mion_mzr = mzr[0];

        // Find the monoisotopic ion ([M+H]+ or [M-H]-) in the chain to reference
        // its mass
        let mut mh_index: i32 = -1;
        let mut mh_mz: f32 = 0.0;
        let base_adduct = if pol == 1 { "[M+H]+" } else { "[M-H]-" };

        for c in 0..number_candidates {
            if self.chain[c].adduct == base_adduct {
                mh_index = c as i32;
                mh_mz = self.chain[c].mz as f32;
                break;
            }
        }

        for a in 0..adducts.len() {
            let adduct_mass_distance = adducts[a].mass_distance;
            let adduct_type = adducts[a].ty.clone();

            for c in 1..number_candidates {
                // Skip if already annotated
                if self.chain[c].adduct != self.chain[0].adduct {
                    continue;
                }

                let mz = self.chain[c].mz as f32;
                let exp_mass_distance = mz - (mion_mz + neutralizer);
                let mass_error = (exp_mass_distance - adduct_mass_distance).abs();

                if mass_error < mion_mzr {
                    // If we found the monoisotopic ion in the chain and this is
                    // not that ion, format as adduct MZXXX [M+Element]
                    if mh_index >= 0 && adduct_type != base_adduct {
                        self.chain[c].adduct =
                            format!("adduct MZ{} {}", mh_mz.round(), adduct_type);
                    } else {
                        // Use the proper adduct notation from the adduct catalog
                        self.chain[c].adduct = adduct_type.clone();
                    }
                    break;
                }
            }
        }
    }

    pub fn find_fragment_candidates(
        &mut self,
        ft: &NtaFeatureRow,
        fts: &NtaFeatures,
        ft_index: i32,
        component_indices: Option<&Vec<i32>>,
    ) {
        let feature = ft.feature.clone();
        let polarity = ft.polarity;
        let mz = ft.mz as f32;
        // Search for fragments up to 100 Da lighter
        let min_mz_chain = if mz > 100.0 { mz - 100.0 } else { 0.0 };

        self.chain.push(ft.clone());
        self.indices.push(ft_index);

        let search_indices: Vec<i32> = match component_indices {
            Some(ci) => ci.clone(),
            None => (0..fts.size() as i32).collect(),
        };

        for z in search_indices {
            let zz = z as usize;
            let within_mz_range = fts.mz[zz] < mz && fts.mz[zz] >= min_mz_chain;
            let same_polarity = fts.polarity[zz] == polarity;
            let not_main_ft = fts.feature[zz] != feature;

            if within_mz_range && same_polarity && not_main_ft {
                self.chain.push(fts.get_feature(zz));
                self.indices.push(z);
            }
        }
    }

    pub fn annotate_fragments(&mut self, ppm: f32) {
        let all_losses = FragmentLossSet::default();
        let pol = self.chain[0].polarity;
        let losses = all_losses.losses(pol);
        let number_candidates = self.chain.len();
        let mzr = self.get_chain_mzr(ppm);
        let parent_mz = self.chain[0].mz as f32;
        let parent_mzr = mzr[0];

        for l in 0..losses.len() {
            let loss_mass = losses[l].mass_loss;
            let loss_formula = losses[l].formula.clone();

            for c in 1..number_candidates {
                // Skip if already annotated (not empty)
                if !self.chain[c].adduct.is_empty() {
                    continue;
                }

                let mz = self.chain[c].mz as f32;
                let exp_mass_loss = parent_mz - mz;
                let mass_error = (exp_mass_loss - loss_mass).abs();

                if mass_error < parent_mzr {
                    // Format as "loss MZXXX -Formula"
                    self.chain[c].adduct =
                        format!("loss MZ{} -{}", parent_mz.round(), loss_formula);
                    break;
                }
            }
        }
    }
}

fn isotopes_str_index(isotopes_str: &[String], iso: &str) -> usize {
    isotopes_str.iter().position(|x| x == iso).unwrap()
}

// ---------------------------------------------------------------------------
// ANNOTATION_CANDIDATE
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct AnnotationCandidate {
    pub cat: String,
    pub ty: String,
    pub parent_feature: String,
    pub element_or_delta: String,
    pub mass_error_da: f64,
    pub mass_error_ppm: f64,
    pub rt_error: f64,
    pub rel_intensity: f64,
    pub expected_rel_intensity_min: f64,
    pub expected_rel_intensity_max: f64,
    pub score: f64,
    pub parent_index: i32,
    pub feature_index: i32,
    pub priority: i32,
    pub is_default: bool,
    pub label: String,
}

impl Default for AnnotationCandidate {
    fn default() -> Self {
        Self {
            cat: String::new(),
            ty: String::new(),
            parent_feature: String::new(),
            element_or_delta: String::new(),
            mass_error_da: 0.0,
            mass_error_ppm: 0.0,
            rt_error: 0.0,
            rel_intensity: 0.0,
            expected_rel_intensity_min: 0.0,
            expected_rel_intensity_max: 0.0,
            score: 0.0,
            parent_index: -1,
            feature_index: -1,
            priority: 0,
            is_default: false,
            label: String::new(),
        }
    }
}

// ---------------------------------------------------------------------------
// is_max_gap_reached
// ---------------------------------------------------------------------------

pub fn is_max_gap_reached(current_step: i32, max_gaps: i32, steps: &[i32]) -> bool {
    if steps.is_empty() {
        return false;
    }

    let max_step = *steps.iter().max().unwrap();

    if max_step == 0 {
        return (current_step - 1) > max_gaps;
    }

    let gaps = current_step - max_step - 1;

    gaps > max_gaps
}

// ---------------------------------------------------------------------------
// ISOTOPE_CHAIN_ASSIGNMENT (local struct in annotate_components_impl)
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Default)]
struct IsotopeChainAssignment {
    anchor_idx: i32,
    children: Vec<AnnotationCandidate>,
    total_ppm: f64,
    total_rt: f64,
}

// ---------------------------------------------------------------------------
// annotate_components_impl
// ---------------------------------------------------------------------------

pub fn annotate_components_impl(
    nta_data: &mut ProjectNonTargetAnalysis,
    max_isotopes: i32,
    max_charge: i32,
    max_gaps: i32,
    ppm: f32,
    isotope_elements: &[String],
    debug_component: &str,
    debug_analysis: &str,
) -> streamfind_rust_core::Result<()> {
    let _ = (debug_component, debug_analysis);

    let mut isotopes = IsotopeSet::default();
    let default_elements: Vec<String> = ["C:1-60", "N:0-10", "O:0-20", "S:0-4", "Cl:0-6", "Br:0-4"]
        .iter()
        .map(|s| s.to_string())
        .collect();
    let used_elements: &[String] = if isotope_elements.is_empty() {
        &default_elements
    } else {
        isotope_elements
    };
    let parsed_specs = parse_isotope_element_specs(used_elements);
    isotopes.filter(&parsed_specs.elements);
    isotopes.set_ranges(&parsed_specs.ranges);

    let max_number_elements = 5;
    let combinations = IsotopeCombinations::new(&isotopes, max_number_elements);

    let feature_buffers = &mut nta_data.feature_buffers;
    let number_analyses = feature_buffers.len();

    if number_analyses == 0 {
        return Ok(());
    }

    let all_adducts = AdductSet::default();
    let all_losses = FragmentLossSet::default();

    for a in 0..number_analyses {
        let fts = &mut feature_buffers[a];
        let number_features = fts.size();
        if number_features == 0 {
            continue;
        }

        fts.sort_by_mz();

        let mut component_groups: BTreeMap<String, Vec<i32>> = BTreeMap::new();
        for f in 0..number_features {
            let ft = fts.get_feature(f);
            if !ft.feature_component.is_empty() {
                component_groups
                    .entry(ft.feature_component.clone())
                    .or_default()
                    .push(f as i32);
            }
        }

        for (component_id, component_indices) in &component_groups {
            if component_indices.is_empty() {
                continue;
            }

            for &idx in component_indices {
                let mut ft = fts.get_feature(idx as usize);
                ft.adduct.clear();
                fts.set_feature(idx as usize, &ft);
            }

            let mut sorted_indices: Vec<i32> = component_indices.clone();
            sorted_indices
                .sort_by(|&lhs, &rhs| fts.mz[lhs as usize].total_cmp(&fts.mz[rhs as usize]));

            let mut final_candidate: HashMap<i32, AnnotationCandidate> = HashMap::new();
            for &idx in &sorted_indices {
                let ft = fts.get_feature(idx as usize);
                let mut fallback = AnnotationCandidate::default();
                fallback.cat = "default".to_string();
                fallback.ty = if ft.polarity == 1 {
                    "[M+H]+".to_string()
                } else {
                    "[M-H]-".to_string()
                };
                fallback.parent_feature = ft.feature.clone();
                fallback.element_or_delta = if ft.polarity == 1 {
                    "H".to_string()
                } else {
                    "-H".to_string()
                };
                fallback.feature_index = idx;
                fallback.parent_index = idx;
                fallback.is_default = true;
                fallback.score = 0.01;
                fallback.priority = candidate_priority("default", &fallback.ty);
                fallback.label = fallback.ty.clone();
                final_candidate.insert(idx, fallback);
            }

            let mut isotope_assignments: Vec<IsotopeChainAssignment> = Vec::new();
            for &anchor_idx in &sorted_indices {
                let anchor = fts.get_feature(anchor_idx as usize);
                let mut isotope_chain = CandidateChain::default();
                isotope_chain.find_isotopic_candidates(
                    &anchor,
                    fts,
                    anchor_idx,
                    max_isotopes,
                    Some(&component_indices),
                    None,
                );
                if isotope_chain.size() > 1 {
                    isotope_chain.annotate_isotopes(
                        &combinations,
                        max_isotopes,
                        max_charge,
                        max_gaps,
                        ppm,
                    );
                    let mut assignment = IsotopeChainAssignment::default();
                    assignment.anchor_idx = anchor_idx;
                    for i in 1..isotope_chain.chain.len() {
                        let child_idx = isotope_chain.indices[i];
                        let child = isotope_chain.chain[i].clone();
                        if !child.adduct.starts_with("isotope ") {
                            continue;
                        }

                        let mut candidate = AnnotationCandidate::default();
                        candidate.cat = "isotope".to_string();
                        candidate.ty = extract_isotope_type(&child.adduct);
                        candidate.parent_feature = anchor.feature.clone();
                        candidate.element_or_delta = extract_isotope_element(&child.adduct);
                        candidate.feature_index = child_idx;
                        candidate.parent_index = anchor_idx;
                        let theoretical_mz = anchor.mz
                            + if isotope_chain
                                .isotope_theoretical_mass_distance
                                .contains_key(&child_idx)
                            {
                                isotope_chain.isotope_theoretical_mass_distance[&child_idx] as f64
                            } else {
                                isotope_mass_delta(&candidate.element_or_delta)
                            };
                        candidate.mass_error_da = (child.mz - theoretical_mz).abs();
                        candidate.mass_error_ppm = ppm_error(child.mz, theoretical_mz);
                        if candidate.mass_error_ppm > ppm as f64 {
                            continue;
                        }
                        candidate.rt_error = (child.rt - anchor.rt).abs();
                        candidate.rel_intensity = if anchor.intensity > 0.0 {
                            child.intensity / anchor.intensity
                        } else {
                            0.0
                        };
                        candidate.expected_rel_intensity_min = if isotope_chain
                            .isotope_theoretical_abundance_min
                            .contains_key(&child_idx)
                        {
                            isotope_chain.isotope_theoretical_abundance_min[&child_idx] as f64
                        } else {
                            0.0
                        };
                        candidate.expected_rel_intensity_max = if isotope_chain
                            .isotope_theoretical_abundance_max
                            .contains_key(&child_idx)
                        {
                            isotope_chain.isotope_theoretical_abundance_max[&child_idx] as f64
                        } else {
                            1.5
                        };
                        candidate.priority = candidate_priority(&candidate.cat, &candidate.ty);
                        candidate.score = candidate_score(&candidate, ppm as f64);
                        if candidate.score < 0.0 {
                            continue;
                        }
                        candidate.label = make_annotation_label(&candidate);
                        assignment.total_ppm += candidate.mass_error_ppm;
                        assignment.total_rt += candidate.rt_error;
                        assignment.children.push(candidate);
                    }

                    if !assignment.children.is_empty() {
                        isotope_assignments.push(assignment);
                    }
                }
            }

            isotope_assignments.sort_by(|lhs, rhs| {
                if lhs.children.len() != rhs.children.len() {
                    return lhs.children.len().cmp(&rhs.children.len()).reverse();
                }
                if lhs.total_ppm != rhs.total_ppm {
                    return lhs.total_ppm.total_cmp(&rhs.total_ppm);
                }
                if lhs.total_rt != rhs.total_rt {
                    return lhs.total_rt.total_cmp(&rhs.total_rt);
                }
                fts.mz[lhs.anchor_idx as usize].total_cmp(&fts.mz[rhs.anchor_idx as usize])
            });

            let mut isotope_anchor_children: HashSet<i32> = HashSet::new();
            for assignment in &isotope_assignments {
                for candidate in &assignment.children {
                    isotope_anchor_children.insert(candidate.feature_index);
                }
            }

            let mut isotope_children: HashSet<i32> = HashSet::new();
            let mut isotope_occupied: HashSet<i32> = HashSet::new();
            for assignment in &isotope_assignments {
                if isotope_anchor_children.contains(&assignment.anchor_idx) {
                    continue;
                }
                if isotope_occupied.contains(&assignment.anchor_idx) {
                    continue;
                }

                let mut conflict = false;
                for candidate in &assignment.children {
                    if isotope_occupied.contains(&candidate.feature_index) {
                        conflict = true;
                        break;
                    }
                }
                if conflict {
                    continue;
                }

                isotope_occupied.insert(assignment.anchor_idx);
                for candidate in &assignment.children {
                    isotope_occupied.insert(candidate.feature_index);
                    isotope_children.insert(candidate.feature_index);
                    final_candidate.insert(candidate.feature_index, candidate.clone());
                }
            }

            let mut non_isotope_indices: Vec<i32> = Vec::new();
            for &idx in &sorted_indices {
                if !isotope_children.contains(&idx) {
                    non_isotope_indices.push(idx);
                }
            }

            let mut relation_candidates: HashMap<i32, Vec<AnnotationCandidate>> = HashMap::new();
            for &anchor_idx in &non_isotope_indices {
                let anchor = fts.get_feature(anchor_idx as usize);
                let adducts = all_adducts.adducts(anchor.polarity);
                let losses = all_losses.losses(anchor.polarity);
                let neutral_mass = neutral_mass_from_base_ion(&anchor);

                for &idx in &non_isotope_indices {
                    if idx == anchor_idx {
                        continue;
                    }

                    let child = fts.get_feature(idx as usize);
                    let rt_error = (child.rt - anchor.rt).abs();
                    let rel_intensity = if anchor.intensity > 0.0 {
                        child.intensity / anchor.intensity
                    } else {
                        0.0
                    };

                    let base_adduct = if anchor.polarity == 1 {
                        "[M+H]+"
                    } else {
                        "[M-H]-"
                    };

                    for adduct in &adducts {
                        if adduct.ty == base_adduct {
                            continue;
                        }
                        let theoretical_mz = theoretical_mz_from_adduct(neutral_mass, adduct);
                        let mass_error_ppm_value = ppm_error(child.mz, theoretical_mz);
                        if mass_error_ppm_value > (10.0f64).max(ppm as f64 * 1.5) {
                            continue;
                        }

                        let mut candidate = AnnotationCandidate::default();
                        candidate.cat = "adduct".to_string();
                        candidate.ty = adduct.ty.clone();
                        candidate.parent_feature = anchor.feature.clone();
                        candidate.element_or_delta = adduct.element.clone();
                        candidate.feature_index = idx;
                        candidate.parent_index = anchor_idx;
                        candidate.mass_error_da = (child.mz - theoretical_mz).abs();
                        candidate.mass_error_ppm = mass_error_ppm_value;
                        candidate.rt_error = rt_error;
                        candidate.rel_intensity = rel_intensity;
                        candidate.expected_rel_intensity_min = 0.0;
                        candidate.expected_rel_intensity_max = 2.0;
                        candidate.priority = candidate_priority(&candidate.cat, &candidate.ty);
                        candidate.score = candidate_score(&candidate, ppm as f64);
                        candidate.label = make_annotation_label(&candidate);
                        relation_candidates.entry(idx).or_default().push(candidate);
                    }

                    for loss in &losses {
                        if child.mz >= anchor.mz {
                            continue;
                        }
                        let theoretical_mz = anchor.mz - loss.mass_loss as f64;
                        let mass_error_ppm_value = ppm_error(child.mz, theoretical_mz);
                        if mass_error_ppm_value > (10.0f64).max(ppm as f64 * 1.5) {
                            continue;
                        }

                        let mut candidate = AnnotationCandidate::default();
                        candidate.cat = "loss".to_string();
                        candidate.ty = format!("M-{}", loss.formula);
                        candidate.parent_feature = anchor.feature.clone();
                        candidate.element_or_delta = format!("-{}", loss.formula);
                        candidate.feature_index = idx;
                        candidate.parent_index = anchor_idx;
                        candidate.mass_error_da = (child.mz - theoretical_mz).abs();
                        candidate.mass_error_ppm = mass_error_ppm_value;
                        candidate.rt_error = rt_error;
                        candidate.rel_intensity = rel_intensity;
                        candidate.expected_rel_intensity_min = 0.0;
                        candidate.expected_rel_intensity_max = 1.0;
                        candidate.priority = candidate_priority(&candidate.cat, &candidate.ty);
                        candidate.score = candidate_score(&candidate, ppm as f64);
                        candidate.label = make_annotation_label(&candidate);
                        relation_candidates.entry(idx).or_default().push(candidate);
                    }
                }
            }

            let mut relation_state: HashMap<i32, AnnotationCandidate> = HashMap::new();
            for &idx in &non_isotope_indices {
                relation_state.insert(idx, final_candidate[&idx].clone());
            }

            let mut relation_update_order: Vec<i32> = non_isotope_indices.clone();
            relation_update_order.sort_by(|&lhs, &rhs| {
                if fts.mz[lhs as usize] != fts.mz[rhs as usize] {
                    return fts.mz[rhs as usize].total_cmp(&fts.mz[lhs as usize]);
                }
                lhs.cmp(&rhs)
            });

            let mut relation_changed = true;
            let max_relation_iterations = (non_isotope_indices.len() as i32).max(1);
            for _iter in 0..max_relation_iterations {
                if !relation_changed {
                    break;
                }
                relation_changed = false;
                let mut next_state = relation_state.clone();

                for &feature_idx in &relation_update_order {
                    let feature_candidates = match relation_candidates.get(&feature_idx) {
                        Some(fc) => fc,
                        None => continue,
                    };

                    let current_it = relation_state.get(&feature_idx);
                    let mut best = final_candidate[&feature_idx].clone();
                    if let Some(current) = current_it {
                        if relation_candidate_is_valid(current, &next_state) {
                            best = current.clone();
                        }
                    }

                    for candidate in feature_candidates {
                        if !relation_candidate_is_valid(candidate, &next_state) {
                            continue;
                        }
                        if best.is_default || candidate_better(candidate, &best) {
                            best = candidate.clone();
                        }
                    }

                    next_state.insert(feature_idx, best.clone());
                    if !candidate_equals(&best, &relation_state[&feature_idx]) {
                        relation_changed = true;
                    }
                }

                relation_state = next_state;
            }

            for (feature_idx, candidate) in &relation_state {
                final_candidate.insert(*feature_idx, candidate.clone());
            }

            let mut reserved_targets: HashSet<i32> = HashSet::new();
            for (feature_idx, candidate) in &final_candidate {
                if !candidate.is_default {
                    reserved_targets.insert(*feature_idx);
                }
            }

            let mut derived_anchor_indices: Vec<i32> = Vec::new();
            for (feature_idx, candidate) in &final_candidate {
                if !candidate.is_default && (candidate.cat == "adduct" || candidate.cat == "loss") {
                    let mut visited: HashSet<i32> = HashSet::new();
                    if relation_chain_reaches_root(*feature_idx, &final_candidate, &mut visited) {
                        derived_anchor_indices.push(*feature_idx);
                    }
                }
            }
            // C++ iterates an unordered_map here; sort for a deterministic
            // processing order (the C++ order is hash-order, not reproducible).
            derived_anchor_indices.sort_unstable();

            for &anchor_idx in &derived_anchor_indices {
                let anchor = fts.get_feature(anchor_idx as usize);
                let mut unavailable = reserved_targets.clone();
                unavailable.remove(&anchor_idx);

                let mut isotope_chain = CandidateChain::default();
                isotope_chain.find_isotopic_candidates(
                    &anchor,
                    fts,
                    anchor_idx,
                    max_isotopes,
                    Some(&component_indices),
                    Some(&unavailable),
                );
                if isotope_chain.size() <= 1 {
                    continue;
                }

                isotope_chain.annotate_isotopes(
                    &combinations,
                    max_isotopes,
                    max_charge,
                    max_gaps,
                    ppm,
                );
                for i in 1..isotope_chain.chain.len() {
                    let child_idx = isotope_chain.indices[i];
                    let child = isotope_chain.chain[i].clone();
                    if !child.adduct.starts_with("isotope ") {
                        continue;
                    }
                    if reserved_targets.contains(&child_idx) {
                        continue;
                    }

                    let mut candidate = AnnotationCandidate::default();
                    candidate.cat = "isotope".to_string();
                    candidate.ty = extract_isotope_type(&child.adduct);
                    candidate.parent_feature = anchor.feature.clone();
                    candidate.element_or_delta = extract_isotope_element(&child.adduct);
                    candidate.feature_index = child_idx;
                    candidate.parent_index = anchor_idx;
                    let theoretical_mz = anchor.mz
                        + if isotope_chain
                            .isotope_theoretical_mass_distance
                            .contains_key(&child_idx)
                        {
                            isotope_chain.isotope_theoretical_mass_distance[&child_idx] as f64
                        } else {
                            isotope_mass_delta(&candidate.element_or_delta)
                        };
                    candidate.mass_error_da = (child.mz - theoretical_mz).abs();
                    candidate.mass_error_ppm = ppm_error(child.mz, theoretical_mz);
                    if candidate.mass_error_ppm > ppm as f64 {
                        continue;
                    }
                    candidate.rt_error = (child.rt - anchor.rt).abs();
                    candidate.rel_intensity = if anchor.intensity > 0.0 {
                        child.intensity / anchor.intensity
                    } else {
                        0.0
                    };
                    candidate.expected_rel_intensity_min = if isotope_chain
                        .isotope_theoretical_abundance_min
                        .contains_key(&child_idx)
                    {
                        isotope_chain.isotope_theoretical_abundance_min[&child_idx] as f64
                    } else {
                        0.0
                    };
                    candidate.expected_rel_intensity_max = if isotope_chain
                        .isotope_theoretical_abundance_max
                        .contains_key(&child_idx)
                    {
                        isotope_chain.isotope_theoretical_abundance_max[&child_idx] as f64
                    } else {
                        1.5
                    };
                    candidate.priority = candidate_priority(&candidate.cat, &candidate.ty);
                    candidate.score = candidate_score(&candidate, ppm as f64);
                    if candidate.score < 0.0 {
                        continue;
                    }
                    candidate.label = make_annotation_label(&candidate);
                    final_candidate.insert(child_idx, candidate.clone());
                    reserved_targets.insert(child_idx);
                }
            }

            for &idx in &sorted_indices {
                let mut ft = fts.get_feature(idx as usize);
                let it = final_candidate.get(&idx);
                let is_default_or_missing = match it {
                    None => true,
                    Some(c) => c.is_default,
                };

                if is_default_or_missing {
                    ft.adduct = if ft.polarity == 1 {
                        "[M+H]+".to_string()
                    } else {
                        "[M-H]-".to_string()
                    };
                    ft.annotation_category.clear();
                    ft.annotation_type.clear();
                    ft.annotation_parent_feature.clear();
                    ft.annotation_element.clear();
                    ft.annotation_mass_error_da = 0.0;
                    ft.annotation_mass_error_ppm = 0.0;
                    ft.annotation_rt_error = 0.0;
                    ft.annotation_rel_intensity = 0.0;
                    ft.annotation_expected_rel_intensity_min = 0.0;
                    ft.annotation_expected_rel_intensity_max = 0.0;
                    ft.annotation_score = 0.0;
                } else {
                    let candidate = it.unwrap();
                    ft.adduct = make_annotation_summary(candidate);
                    ft.annotation_category = candidate.cat.clone();
                    ft.annotation_type = candidate.ty.clone();
                    ft.annotation_parent_feature = candidate.parent_feature.clone();
                    ft.annotation_element = candidate.element_or_delta.clone();
                    ft.annotation_mass_error_da = candidate.mass_error_da;
                    ft.annotation_mass_error_ppm = candidate.mass_error_ppm;
                    ft.annotation_rt_error = candidate.rt_error;
                    ft.annotation_rel_intensity = candidate.rel_intensity;
                    ft.annotation_expected_rel_intensity_min = candidate.expected_rel_intensity_min;
                    ft.annotation_expected_rel_intensity_max = candidate.expected_rel_intensity_max;
                    ft.annotation_score = candidate.score;
                }
                fts.set_feature(idx as usize, &ft);
            }

            let _ = component_id;
        }
    }

    Ok(())
}
