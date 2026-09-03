//! Shared NTA numeric utilities.
//!
//! Ported from `core/domains/mass_spec/src/nta.cpp` (`nta::utils`) and the
//! base64 float-array codecs used by the NTA algorithms
//! (`mass_spec::reader::utils::encode_little_endian_from_float` /
//! `decode_little_endian_to_float` + base64). Keep these identical to the C++
//! operations — they are the numeric foundation every NTA algorithm relies on.

use base64::{engine::general_purpose::STANDARD, Engine as _};

/// nta::utils::mean — empty vector -> 0.
pub fn mean(v: &[f32]) -> f32 {
    if v.is_empty() {
        0.0
    } else {
        v.iter().sum::<f32>() / v.len() as f32
    }
}

/// nta::utils::standard_deviation — population SD around a precomputed mean.
pub fn standard_deviation(v: &[f32], m: f32) -> f32 {
    if v.is_empty() {
        return 0.0;
    }
    let s: f32 = v.iter().map(|x| (x - m) * (x - m)).sum();
    (s / v.len() as f32).sqrt()
}

/// nta::utils::quantile — `nth_element` semantics: the element that would sit
/// at index `(len-1)*q` in a sorted copy. Full sort yields the same element.
pub fn quantile(v: Vec<f32>, q: f32) -> f32 {
    if v.is_empty() {
        return 0.0;
    }
    let q = q.clamp(0.0, 1.0);
    let i = ((v.len() - 1) as f32 * q) as usize;
    let mut v = v;
    v.sort_by(f32::total_cmp);
    v[i]
}

/// `encode_floats_base64(input, 4)`: little-endian f32 bytes -> base64.
pub fn encode_floats_base64(input: &[f32]) -> String {
    let mut bytes = Vec::with_capacity(input.len() * 4);
    for x in input {
        bytes.extend(x.to_le_bytes());
    }
    STANDARD.encode(bytes)
}

/// base64 -> little-endian f32 array.
pub fn decode_floats_base64(encoded: &str) -> Vec<f32> {
    if encoded.is_empty() {
        return Vec::new();
    }
    match STANDARD.decode(encoded) {
        Ok(bytes) => bytes
            .chunks_exact(4)
            .map(|c| f32::from_le_bytes([c[0], c[1], c[2], c[3]]))
            .collect(),
        Err(_) => Vec::new(),
    }
}

/// nta::utils::get_sort_indices_float — stable index order by ascending value.
pub fn get_sort_indices_float(v: &[f32]) -> Vec<usize> {
    let mut idx: Vec<usize> = (0..v.len()).collect();
    idx.sort_by(|&a, &b| v[a].total_cmp(&v[b]));
    idx
}

fn reorder_float(v: &mut Vec<f32>, order: &[usize]) {
    let out: Vec<f32> = order.iter().map(|&i| v[i]).collect();
    *v = out;
}

fn reorder_int(v: &mut Vec<i32>, order: &[usize]) {
    let out: Vec<i32> = order.iter().map(|&i| v[i]).collect();
    *v = out;
}

/// nta::utils::reorder_multiple_vectors (3 float vectors).
pub fn reorder_multiple_vectors3(
    order: &[usize],
    a: &mut Vec<f32>,
    b: &mut Vec<f32>,
    c: &mut Vec<f32>,
) {
    reorder_float(a, order);
    reorder_float(b, order);
    reorder_float(c, order);
}

/// nta::utils::reorder_multiple_vectors (4 float vectors).
pub fn reorder_multiple_vectors4(
    order: &[usize],
    a: &mut Vec<f32>,
    b: &mut Vec<f32>,
    c: &mut Vec<f32>,
    d: &mut Vec<f32>,
) {
    reorder_float(a, order);
    reorder_float(b, order);
    reorder_float(c, order);
    reorder_float(d, order);
}

/// nta::utils::reorder_multiple_vectors (3 float vectors + 1 int vector).
pub fn reorder_multiple_vectors3_int(
    order: &[usize],
    a: &mut Vec<f32>,
    b: &mut Vec<f32>,
    c: &mut Vec<f32>,
    d: &mut Vec<f32>,
    e: &mut Vec<i32>,
) {
    reorder_float(a, order);
    reorder_float(b, order);
    reorder_float(c, order);
    reorder_float(d, order);
    reorder_int(e, order);
}

/// nta::utils::filter_above_threshold — indices where v[i] > t[i].
pub fn filter_above_threshold(v: &[f32], t: &[f32]) -> Vec<usize> {
    let mut out = Vec::new();
    for i in 0..v.len().min(t.len()) {
        if v[i] > t[i] {
            out.push(i);
        }
    }
    out
}

/// nta::utils::cluster_by_threshold_float — step when consecutive delta
/// exceeds the (clamped) threshold.
pub fn cluster_by_threshold_float(v: &[f32], t: &[f32]) -> Vec<i32> {
    let mut out = vec![0; v.len()];
    for i in 1..v.len() {
        let ti = t[i.min(t.len().saturating_sub(1))];
        out[i] = out[i - 1] + (v[i] - v[i - 1] > ti) as i32;
    }
    out
}

/// nta::utils::calculate_baseline — sliding window minimum then a 3-point
/// running average (endpoints untouched).
pub fn calculate_baseline(v: &[f32], w: usize) -> Vec<f32> {
    let mut out = vec![0.0; v.len()];
    for i in 0..v.len() {
        let a = i.saturating_sub(w);
        let b = (i + w).min(v.len() - 1);
        out[i] = v[a..=b].iter().copied().fold(f32::INFINITY, f32::min);
    }
    if v.len() > 2 {
        for i in 1..v.len() - 1 {
            out[i] = (out[i - 1] + out[i] + out[i + 1]) / 3.0;
        }
    }
    out
}

/// nta::utils::smooth_intensity_savitzky_golay — windowed moving average
/// (window/2 on each side), clamped at the edges.
pub fn smooth_intensity_savitzky_golay(v: &[f32], window: usize) -> Vec<f32> {
    let mut out = vec![0.0; v.len()];
    let half = window / 2;
    for i in 0..v.len() {
        let a = i.saturating_sub(half);
        let b = (i + half).min(v.len() - 1);
        let s: f32 = v[a..=b].iter().sum();
        out[i] = s / (b - a + 1) as f32;
    }
    out
}

/// nta::utils::calculate_derivatives — first and second finite differences.
pub fn calculate_derivatives(v: &[f32]) -> (Vec<f32>, Vec<f32>) {
    let mut d1 = Vec::new();
    let mut d2 = Vec::new();
    for i in 0..v.len().saturating_sub(1) {
        d1.push(v[i + 1] - v[i]);
    }
    for i in 0..d1.len().saturating_sub(1) {
        d2.push(d1[i + 1] - d1[i]);
    }
    (d1, d2)
}

/// nta::utils::gaussian_function_with_baseline.
pub fn gaussian_function_with_baseline(a: f32, mu: f32, sigma: f32, base: f32, x: f32) -> f32 {
    base + a * (-(x - mu) * (x - mu) / (2.0 * sigma * sigma)).exp()
}

/// nta::utils::fit_gaussian — RMSProp-style gradient descent over up to 500
/// iterations. Returns (A, mu, sigma, base).
pub fn fit_gaussian(
    x: &[f32],
    y: &[f32],
    mut a: f32,
    mut mu: f32,
    mut sigma: f32,
    mut base: f32,
) -> (f32, f32, f32, f32) {
    const ALPHA: f32 = 0.01;
    const BETA1: f32 = 0.9;
    const BETA2: f32 = 0.999;
    const EPSILON: f32 = 1e-8;
    let (mut ma, mut va) = (0.0, 0.0);
    let (mut mmu, mut vmu) = (0.0, 0.0);
    let (mut ms, mut vs) = (0.0, 0.0);
    let (mut mb, mut vb) = (0.0, 0.0);
    for iter in 1..=500 {
        let (mut ga, mut gmu, mut gs, mut gb) = (0.0, 0.0, 0.0, 0.0);
        for i in 0..x.len() {
            let e = (-(x[i] - mu) * (x[i] - mu) / (2.0 * sigma * sigma)).exp();
            let err = y[i] - (base + a * e);
            ga += -2.0 * err * e;
            gmu += -2.0 * err * a * e * (x[i] - mu) / (sigma * sigma);
            gs += -2.0 * err * a * e * (x[i] - mu) * (x[i] - mu) / (sigma * sigma * sigma);
            gb += -2.0 * err;
        }
        let update = |g: f32, m: &mut f32, v: &mut f32, p: &mut f32| {
            *m = BETA1 * *m + (1.0 - BETA1) * g;
            *v = BETA2 * *v + (1.0 - BETA2) * g * g;
            let mh = *m / (1.0 - BETA1.powf(iter as f32));
            let vh = *v / (1.0 - BETA2.powf(iter as f32));
            *p -= ALPHA * mh / (vh.sqrt() + EPSILON);
        };
        update(ga, &mut ma, &mut va, &mut a);
        a = a.max(0.1);
        update(gmu, &mut mmu, &mut vmu, &mut mu);
        update(gs, &mut ms, &mut vs, &mut sigma);
        sigma = sigma.clamp(0.1, 100.0);
        update(gb, &mut mb, &mut vb, &mut base);
        base = base.max(0.0);
    }
    (a, mu, sigma, base)
}

/// nta::utils::calculate_gaussian_rsquared.
pub fn calculate_gaussian_rsquared(
    x: &[f32],
    y: &[f32],
    a: f32,
    mu: f32,
    sigma: f32,
    base: f32,
) -> f32 {
    if y.is_empty() {
        return 0.0;
    }
    let m = mean(y);
    let mut total = 0.0;
    let mut resid = 0.0;
    for i in 0..y.len() {
        let p = gaussian_function_with_baseline(a, mu, sigma, base, x[i]);
        resid += (y[i] - p) * (y[i] - p);
        total += (y[i] - m) * (y[i] - m);
    }
    if total != 0.0 {
        1.0 - resid / total
    } else {
        0.0
    }
}

/// nta::utils::calculate_area — trapezoid, clamped at 0.
pub fn calculate_area(x: &[f32], y: &[f32]) -> f32 {
    let mut a = 0.0;
    for i in 1..x.len().min(y.len()) {
        a += (x[i] - x[i - 1]) * (y[i] + y[i - 1]) / 2.0;
    }
    a.max(0.0)
}

/// nta::utils::calculate_jaggedness.
pub fn calculate_jaggedness(v: &[f32]) -> f32 {
    if v.len() < 3 {
        return 0.0;
    }
    let m = v.iter().copied().fold(f32::NEG_INFINITY, f32::max);
    if m == 0.0 {
        return 0.0;
    }
    let mut a = 0.0;
    for i in 1..v.len() - 1 {
        a += (v[i] - (v[i - 1] + v[i + 1]) / 2.0).abs();
    }
    a / ((v.len() - 2) as f32 * m)
}

/// nta::utils::calculate_sharpness.
pub fn calculate_sharpness(x: &[f32], y: &[f32], area: f32) -> f32 {
    if x.is_empty() || area == 0.0 {
        return 0.0;
    }
    let m = y.iter().copied().fold(f32::NEG_INFINITY, f32::max);
    m / ((x[x.len() - 1] - x[0]) * area.abs().sqrt())
}

/// nta::utils::calculate_asymmetry.
pub fn calculate_asymmetry(x: &[f32], y: &[f32]) -> f32 {
    if x.len() < 3 {
        return 1.0;
    }
    let apex = y
        .iter()
        .enumerate()
        .max_by(|a, b| a.1.total_cmp(b.1))
        .map(|(i, _)| i)
        .unwrap_or(0);
    let maxv = y[apex];
    let base = y[0].min(*y.last().unwrap());
    let level = base + (maxv - base) * 0.1;
    let mut l = 0usize;
    let mut r = y.len() - 1;
    for j in (0..=apex).rev() {
        if y[j] <= level {
            l = j;
            break;
        }
    }
    for j in apex..y.len() {
        if y[j] <= level {
            r = j;
            break;
        }
    }
    if l >= apex || r <= apex {
        1.0
    } else {
        (x[r] - x[apex]) / (x[apex] - x[l])
    }
}

/// nta::utils::calculate_modality.
pub fn calculate_modality(v: &[f32], p: f32) -> i32 {
    if v.len() < 3 {
        return 1;
    }
    let m = v.iter().copied().fold(f32::NEG_INFINITY, f32::max);
    let mut n = 0;
    for i in 1..v.len() - 1 {
        if v[i] > v[i - 1] && v[i] > v[i + 1] && v[i] >= m * p {
            n += 1;
        }
    }
    n.max(1)
}

/// nta::utils::calculate_theoretical_plates.
pub fn calculate_theoretical_plates(rt: f32, width: f32) -> f32 {
    if width != 0.0 && rt != 0.0 {
        5.54 * (rt / width).powi(2)
    } else {
        0.0
    }
}

/// `nta::deconvolution::calculate_fwhm_rt` — RT full-width at half maximum.
pub fn calculate_fwhm_rt(rt: &[f32], intensity: &[f32]) -> f32 {
    if rt.is_empty() || intensity.is_empty() || rt.len() != intensity.len() {
        return 0.0;
    }
    let max_idx = intensity
        .iter()
        .enumerate()
        .max_by(|a, b| a.1.total_cmp(b.1))
        .map(|(i, _)| i)
        .unwrap_or(0);
    let half_max = intensity[max_idx] / 2.0;
    let mut left_idx = max_idx;
    let mut right_idx = max_idx;
    while left_idx > 0 && intensity[left_idx] > half_max {
        left_idx -= 1;
    }
    while right_idx < intensity.len() - 1 && intensity[right_idx] > half_max {
        right_idx += 1;
    }
    if left_idx < right_idx && right_idx < rt.len() {
        rt[right_idx] - rt[left_idx]
    } else {
        rt[rt.len() - 1] - rt[0]
    }
}

/// `nta::deconvolution::calculate_fwhm_combined` — (fwhm_rt, fwhm_mz, mean_mz_fwhm).
pub fn calculate_fwhm_combined(rt: &[f32], mz: &[f32], intensity: &[f32]) -> (f32, f32, f32) {
    if rt.len() != intensity.len() || mz.len() != intensity.len() || rt.is_empty() {
        return (0.0, 0.0, 0.0);
    }
    let max_idx = intensity
        .iter()
        .enumerate()
        .max_by(|a, b| a.1.total_cmp(b.1))
        .map(|(i, _)| i)
        .unwrap_or(0);
    let max_intensity = intensity[max_idx];
    let baseline = intensity[0].min(*intensity.last().unwrap());
    let peak_height = max_intensity - baseline;
    let half_max = baseline + (peak_height / 2.0);
    let mut left_idx = max_idx;
    let mut right_idx = max_idx;
    while left_idx > 0 && intensity[left_idx] > half_max {
        left_idx -= 1;
    }
    while right_idx < intensity.len() - 1 && intensity[right_idx] > half_max {
        right_idx += 1;
    }
    let fwhm_rt;
    let fwhm_mz;
    let mean_mz_fwhm;
    if left_idx < right_idx && right_idx < rt.len() {
        fwhm_rt = rt[right_idx] - rt[left_idx];
    } else {
        fwhm_rt = rt[rt.len() - 1] - rt[0];
    }
    if left_idx < right_idx && right_idx < mz.len() {
        let mut min_mz = mz[left_idx];
        let mut max_mz = mz[left_idx];
        let mut sum_mz = 0.0;
        let mut count = 0usize;
        for i in left_idx..=right_idx {
            min_mz = min_mz.min(mz[i]);
            max_mz = max_mz.max(mz[i]);
            sum_mz += mz[i];
            count += 1;
        }
        fwhm_mz = max_mz - min_mz;
        mean_mz_fwhm = if count > 0 {
            sum_mz / count as f32
        } else {
            mz[max_idx]
        };
    } else {
        fwhm_mz = mz[mz.len() - 1] - mz[0];
        mean_mz_fwhm = mz[max_idx];
    }
    (fwhm_rt, fwhm_mz, mean_mz_fwhm)
}
