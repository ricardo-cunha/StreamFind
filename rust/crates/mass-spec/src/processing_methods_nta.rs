use base64::{engine::general_purpose::STANDARD, Engine as _};
use serde_json::{json, Value};
use streamfind_rust_core::{Error, ErrorCode, Project, Result};

use crate::reader::Reader;

fn invalid(s: impl Into<String>) -> Error {
    Error::new(ErrorCode::InvalidArgument, s)
}
fn sql(s: &str) -> String {
    format!("'{}'", s.replace('\'', "''"))
}
fn q(v: &[f32], p: f32) -> f32 {
    if v.is_empty() {
        return 0.0;
    }
    let mut x = v.to_vec();
    x.sort_by(f32::total_cmp);
    x[((x.len() - 1) as f32 * p.clamp(0., 1.)) as usize]
}
fn noise_levels(intensities: &[f32], noise_threshold: f32, base_quantile: f32) -> Vec<f32> {
    let nonzero: Vec<_> = intensities.iter().copied().filter(|x| *x > 0.).collect();
    let values = if nonzero.is_empty() {
        intensities
    } else {
        &nonzero
    };
    let m = mean(values);
    let cv = sd(values, m) / m.max(1e-8);
    let snr = if q(values, 0.25) > 0. {
        q(values, 0.9) / q(values, 0.25)
    } else {
        0.
    };
    let mut quantile = if cv > 2. {
        base_quantile * 0.5
    } else if cv > 1. {
        base_quantile
    } else {
        base_quantile * 2.
    };
    let multiplier = if snr > 100. {
        quantile *= 0.5;
        1.2
    } else if snr < 10. {
        quantile *= 1.5;
        0.8
    } else {
        1.
    };
    quantile = quantile.clamp(0.01, (base_quantile * 1.2).max(0.30));
    let n = intensities.len();
    let mut bins = ((n as f32).sqrt() * 1.5).clamp(10., 200.) as usize;
    let sparsity = n as f32 / bins as f32;
    if sparsity < 5. {
        bins = (n / 5).max(5);
    } else if sparsity > 50. {
        bins = (n / 20).min(200);
    }
    let mut data = vec![Vec::new(); bins];
    for (i, value) in intensities.iter().enumerate() {
        data[(i * bins / n.max(1)).min(bins - 1)].push(*value);
    }
    let levels: Vec<_> = data
        .iter()
        .map(|v| (q(v, quantile) * multiplier).max(noise_threshold))
        .collect();
    intensities
        .iter()
        .enumerate()
        .map(|(i, _)| levels[(i * bins / n.max(1)).min(bins - 1)])
        .collect()
}
fn mean(v: &[f32]) -> f32 {
    if v.is_empty() {
        0.
    } else {
        v.iter().sum::<f32>() / v.len() as f32
    }
}
fn sd(v: &[f32], m: f32) -> f32 {
    if v.is_empty() {
        0.
    } else {
        (v.iter().map(|x| (x - m).powi(2)).sum::<f32>() / v.len() as f32).sqrt()
    }
}
fn clusters(v: &[f32], ppm: f32) -> Vec<i32> {
    let mut out = vec![0; v.len()];
    for i in 1..v.len() {
        out[i] = out[i - 1] + (v[i] - v[i - 1] > v[i] * ppm / 1e6) as i32;
    }
    out
}
fn encode(v: &[f32]) -> String {
    let mut bytes = Vec::with_capacity(v.len() * 4);
    for x in v {
        bytes.extend(x.to_le_bytes());
    }
    STANDARD.encode(bytes)
}

#[derive(Clone)]
struct Point {
    rt: f32,
    mz: f32,
    intensity: f32,
    noise: f32,
    cluster: i32,
}
#[derive(Default)]
struct Feature {
    analysis: String,
    feature: String,
    adduct: String,
    rt: f32,
    mz: f32,
    mass: f32,
    intensity: f32,
    noise: f32,
    sn: f32,
    area: f32,
    rtmin: f32,
    rtmax: f32,
    width: f32,
    mzmin: f32,
    mzmax: f32,
    ppm: f32,
    fwhm_rt: f32,
    fwhm_mz: f32,
    ga: f32,
    gmu: f32,
    gs: f32,
    r2: f32,
    jag: f32,
    sharp: f32,
    asym: f32,
    modality: i32,
    plates: f32,
    polarity: i32,
    eic: Vec<(String, String)>,
}

fn baseline(y: &[f32], w: usize) -> Vec<f32> {
    let mut b = vec![0.; y.len()];
    for i in 0..y.len() {
        let a = i.saturating_sub(w);
        let z = (i + w).min(y.len() - 1);
        b[i] = y[a..=z].iter().copied().fold(f32::INFINITY, f32::min);
    }
    if y.len() > 2 {
        for i in 1..y.len() - 1 {
            b[i] = (b[i - 1] + b[i] + b[i + 1]) / 3.;
        }
    }
    b
}
fn smooth(y: &[f32]) -> Vec<f32> {
    let mut z = vec![0.; y.len()];
    for i in 0..y.len() {
        let a = i.saturating_sub(2);
        let b = (i + 2).min(y.len() - 1);
        z[i] = mean(&y[a..=b]);
    }
    z
}
fn fwhm(x: &[f32], y: &[f32]) -> f32 {
    if x.is_empty() {
        return 0.;
    }
    let k = y
        .iter()
        .enumerate()
        .max_by(|a, b| a.1.total_cmp(b.1))
        .unwrap()
        .0;
    let h = y[k] / 2.;
    let mut l = k;
    while l > 0 && y[l] > h {
        l -= 1
    }
    let mut r = k;
    while r + 1 < y.len() && y[r] > h {
        r += 1
    }
    if l < r {
        x[r] - x[l]
    } else {
        x[x.len() - 1] - x[0]
    }
}
fn fit(
    x: &[f32],
    y: &[f32],
    mut a: f32,
    mut mu: f32,
    mut sig: f32,
    mut base: f32,
) -> (f32, f32, f32, f32) {
    let (mut ma, mut va, mut mm, mut vm, mut ms, mut vs, mut mb, mut vb) =
        (0., 0., 0., 0., 0., 0., 0., 0.);
    for it in 1..=500 {
        let (mut ga, mut gm, mut gs, mut gb) = (0., 0., 0., 0.);
        for (&xx, &yy) in x.iter().zip(y) {
            let e = (-(xx - mu).powi(2) / (2. * sig * sig)).exp();
            let er = yy - (base + a * e);
            ga += -2. * er * e;
            gm += -2. * er * a * e * (xx - mu) / (sig * sig);
            gs += -2. * er * a * e * (xx - mu).powi(2) / (sig.powi(3));
            gb += -2. * er;
        }
        fn u(g: &mut f32, m: &mut f32, v: &mut f32, p: &mut f32, it: f32) {
            *m = 0.9 * *m + 0.1 * *g;
            *v = 0.999 * *v + 0.001 * (*g) * (*g);
            *p -= 0.01 * (*m / (1. - 0.9f32.powf(it)))
                / ((*v / (1. - 0.999f32.powf(it))).sqrt() + 1e-8);
        }
        let i = it as f32;
        u(&mut ga, &mut ma, &mut va, &mut a, i);
        a = a.max(0.1);
        u(&mut gm, &mut mm, &mut vm, &mut mu, i);
        u(&mut gs, &mut ms, &mut vs, &mut sig, i);
        sig = sig.clamp(0.1, 100.);
        u(&mut gb, &mut mb, &mut vb, &mut base, i);
        base = base.max(0.);
    }
    (a, mu, sig, base)
}
fn r2(x: &[f32], y: &[f32], a: f32, mu: f32, s: f32, b: f32) -> f32 {
    let m = mean(y);
    let (mut t, mut r) = (0., 0.);
    for (&xx, &yy) in x.iter().zip(y) {
        let p = b + a * (-(xx - mu).powi(2) / (2. * s * s)).exp();
        t += (yy - m).powi(2);
        r += (yy - p).powi(2);
    }
    if t > 0. {
        1. - r / t
    } else {
        0.
    }
}
fn area(x: &[f32], y: &[f32]) -> f32 {
    x.windows(2)
        .zip(y.windows(2))
        .map(|(a, b)| (a[1] - a[0]) * (b[1] + b[0]) / 2.)
        .sum::<f32>()
        .max(0.)
}
fn metrics(x: &[f32], y: &[f32], ar: f32) -> (f32, f32, f32, i32, f32) {
    let m = y.iter().copied().fold(0., f32::max);
    let jag = if y.len() > 2 {
        y[1..y.len() - 1]
            .iter()
            .enumerate()
            .map(|(i, v)| (v - (y[i] + y[i + 2]) / 2.).abs())
            .sum::<f32>()
            / ((y.len() - 2) as f32 * m.max(1.))
    } else {
        0.
    };
    let sharp = if ar != 0. {
        m / ((x[x.len() - 1] - x[0]) * ar.abs().sqrt())
    } else {
        0.
    };
    let k = y
        .iter()
        .enumerate()
        .max_by(|a, b| a.1.total_cmp(b.1))
        .unwrap()
        .0;
    let base = y[0].min(*y.last().unwrap());
    let level = base + (m - base) * 0.1;
    let l = (0..=k).rev().find(|&i| y[i] <= level).unwrap_or(0);
    let r = (k..y.len()).find(|&i| y[i] <= level).unwrap_or(y.len() - 1);
    let asym = if l < k && r > k {
        (x[r] - x[k]) / (x[k] - x[l])
    } else {
        1.
    };
    let modality = (1..y.len().saturating_sub(1))
        .filter(|&i| y[i] > y[i - 1] && y[i] > y[i + 1] && y[i] >= m * 0.1)
        .count()
        .max(1) as i32;
    let plates = if x[x.len() - 1] != 0. {
        5.54 * (x[k] / (x[x.len() - 1] - x[0])).powi(2)
    } else {
        0.
    };
    (jag, sharp, asym, modality, plates)
}

fn make_feature(
    analysis: &str,
    polarity: i32,
    cluster: i32,
    apex: usize,
    left: usize,
    right: usize,
    rt: &[f32],
    mz: &[f32],
    raw: &[f32],
    base: &[f32],
    sm: &[f32],
    adduct: &str,
    correction: f32,
) -> Feature {
    let x = &rt[left..=right];
    let mm = &mz[left..=right];
    let y = &raw[left..=right];
    let sy = &sm[left..=right];
    let by = &base[left..=right];
    let ai = apex - left;
    let max = y.iter().copied().fold(0., f32::max);
    let noise = if sy.len() >= 4 {
        (sy[0].min(sy[1]) + sy[sy.len() - 2].min(*sy.last().unwrap())) / 2.
    } else {
        sy.iter().copied().fold(f32::INFINITY, f32::min)
    };
    let (fwhm_rt, fwhm_mz) = {
        let h = max / 2.;
        let k = y
            .iter()
            .enumerate()
            .max_by(|a, b| a.1.total_cmp(b.1))
            .unwrap()
            .0;
        let mut l = k;
        while l > 0 && y[l] > h {
            l -= 1
        }
        let mut r = k;
        while r + 1 < y.len() && y[r] > h {
            r += 1
        }
        (
            (x[r] - x[l]),
            mm[l..=r].iter().copied().fold(f32::NEG_INFINITY, f32::max)
                - mm[l..=r].iter().copied().fold(f32::INFINITY, f32::min),
        )
    };
    let mzmean = mm.iter().sum::<f32>() / mm.len() as f32;
    let ga0 = max - sy[0].min(*sy.last().unwrap());
    let (ga, gmu, gs, gb) = fit(
        x,
        sy,
        ga0,
        x[ai],
        fwhm(x, sy) / 2.355,
        sy[0].min(*sy.last().unwrap()),
    );
    let ar = area(x, y);
    let (jag, sharp, asym, modality, plates) = metrics(x, y, ar);
    Feature {
        analysis: analysis.into(),
        feature: format!(
            "CL{}_PK{}_MZ{}_RT{}_{}",
            cluster,
            apex,
            mz[apex].round() as i32,
            rt[apex].round() as i32,
            if polarity > 0 { "POS" } else { "NEG" }
        ),
        adduct: adduct.into(),
        rt: rt[apex],
        mz: mzmean,
        mass: mzmean + correction,
        intensity: max,
        noise,
        sn: if noise > 0. { max / noise } else { 0. },
        area: ar,
        rtmin: x[0],
        rtmax: *x.last().unwrap(),
        width: x[x.len() - 1] - x[0],
        mzmin: mm.iter().copied().fold(f32::INFINITY, f32::min),
        mzmax: mm.iter().copied().fold(f32::NEG_INFINITY, f32::max),
        ppm: (mm.iter().copied().fold(f32::NEG_INFINITY, f32::max)
            - mm.iter().copied().fold(f32::INFINITY, f32::min))
            / mzmean
            * 1e6,
        fwhm_rt,
        fwhm_mz,
        ga,
        gmu,
        gs,
        r2: r2(x, sy, ga, gmu, gs, gb),
        jag,
        sharp,
        asym,
        modality,
        plates,
        polarity,
        eic: vec![
            ("eic_rt".into(), encode(x)),
            ("eic_mz".into(), encode(mm)),
            ("eic_intensity".into(), encode(y)),
            ("eic_baseline".into(), encode(by)),
            ("eic_smoothed".into(), encode(sy)),
        ],
    }
}

fn valid_peaks(sm: &[f32], d: &[f32]) -> Vec<usize> {
    let mut out = Vec::new();
    for i in 1..d.len() {
        if d[i - 1] <= 0. || d[i] > 0. || i < 2 || i >= sm.len() - 2 {
            continue;
        }
        let half = sm[i] * 0.5;
        let mut left = i - 1;
        let mut rises = 0;
        while sm[left] >= half {
            if left > 0 && sm[left] < sm[left - 1] {
                rises += 1;
                if rises >= 2 {
                    break;
                }
            } else {
                rises = 0;
            }
            if left == 0 {
                break;
            }
            left -= 1;
        }
        let mut right = i + 1;
        rises = 0;
        while right < sm.len() && sm[right] >= half {
            if right + 1 < sm.len() && sm[right] < sm[right + 1] {
                rises += 1;
                if rises >= 2 {
                    break;
                }
            } else {
                rises = 0;
            }
            right += 1;
        }
        let pre = mean(&d[left..i]);
        let post = mean(&d[i..=right.min(d.len() - 1)]);
        let pre_apex = (left..i).any(|j| sm[j] > sm[i]);
        let post_apex = (i + 1..=right.min(sm.len() - 1)).any(|j| sm[j] > sm[i]);
        if pre > 0. && post < 0. && !pre_apex && !post_apex {
            out.push(i);
        }
    }
    out
}

fn boundaries(
    peak: usize,
    rt: &[f32],
    sm: &[f32],
    base: &[f32],
    half_width: f32,
) -> (usize, usize) {
    let apex = sm[peak];
    let minimum = apex * 0.01;
    let mut left = peak;
    for i in (0..peak).rev() {
        if (i + 1 < peak && rt[i + 1] - rt[i] > half_width) || rt[peak] - rt[i] > half_width {
            left = i + 1;
            break;
        }
        if sm[i] <= base[i] * 1.1 || sm[i] > apex * 1.2 || sm[i] <= minimum {
            left = i;
            break;
        }
        if i >= 2 && sm[i - 1] > sm[i] && sm[i - 2] > sm[i - 1] {
            left = i;
            break;
        }
        left = i;
    }
    let mut right = peak;
    for i in peak + 1..rt.len() {
        if (i > peak + 1 && rt[i] - rt[i - 1] > half_width) || rt[i] - rt[peak] > half_width {
            right = i - 1;
            break;
        }
        if sm[i] <= base[i] * 1.1 || sm[i] > apex * 1.2 || sm[i] <= minimum {
            right = i;
            break;
        }
        if i + 2 < rt.len() && sm[i + 1] > sm[i] && sm[i + 2] > sm[i + 1] {
            right = i;
            break;
        }
        right = i;
    }
    (left, right)
}

fn detect(
    analysis: &str,
    points: &mut Vec<Point>,
    min_traces: usize,
    min_snr: f32,
    baseline_window: f32,
    max_width: f32,
    polarity: i32,
    ppm: f32,
) -> Vec<Feature> {
    points.sort_by(|a, b| a.mz.total_cmp(&b.mz));
    let cs = clusters(&points.iter().map(|p| p.mz).collect::<Vec<_>>(), ppm);
    for (i, p) in points.iter_mut().enumerate() {
        p.cluster = cs[i];
    }
    let mut groups = std::collections::BTreeMap::<i32, Vec<Point>>::new();
    for p in points.drain(..) {
        groups.entry(p.cluster).or_default().push(p)
    }
    let mut out = Vec::new();
    for (c, g) in groups {
        let snr = g.iter().map(|p| p.intensity).fold(0., f32::max)
            / g.iter()
                .map(|p| p.intensity)
                .fold(f32::INFINITY, f32::min)
                .max(1e-8);
        if g.len() <= min_traces || snr <= min_snr {
            continue;
        }
        let mut g = g;
        g.sort_by(|a, b| a.rt.total_cmp(&b.rt));
        let (rt, mz, y): (Vec<_>, Vec<_>, Vec<_>) =
            g.iter().map(|p| (p.rt, p.mz, p.intensity)).unzip3();
        let b = baseline(
            &y,
            (baseline_window
                / (if rt.len() > 1 {
                    (rt[1] - rt[0]).abs()
                } else {
                    1.
                }))
            .max(min_traces as f32) as usize
                / 2,
        );
        let sm = smooth(&y);
        let d: Vec<_> = sm.windows(2).map(|w| w[1] - w[0]).collect();
        let mut peaks = Vec::new();
        for i in valid_peaks(&sm, &d) {
            if i < min_traces / 2 || i >= rt.len() - min_traces / 2 {
                continue;
            }
            // C++ currently receives max_feature_width as max_width and falls back to 30.
            let (left, right) = boundaries(i, &rt, &sm, &b, max_width.min(30.) / 2.);
            if left < right {
                peaks.push((i, left, right));
            }
        }
        let mut merged = true;
        while merged {
            merged = false;
            'outer: for i in 0..peaks.len() {
                for j in i + 1..peaks.len() {
                    let (_, left_i, right_i) = peaks[i];
                    let (_, left_j, right_j) = peaks[j];
                    let overlaps = !(rt[right_i] < rt[left_j] || rt[right_j] < rt[left_i]);
                    let width_i = rt[right_i] - rt[left_i];
                    let width_j = rt[right_j] - rt[left_j];
                    let apex_distance = (rt[peaks[j].0] - rt[peaks[i].0]).abs();
                    let close = apex_distance < (width_i + width_j) * 0.15;
                    let start = peaks[i].0.min(peaks[j].0);
                    let end = peaks[i].0.max(peaks[j].0);
                    let valley = (start..=end).map(|k| sm[k]).fold(f32::INFINITY, f32::min)
                        < sm[peaks[i].0].min(sm[peaks[j].0]) * 0.70;
                    if overlaps && close && !valley {
                        let keep = if y[peaks[i].0] > y[peaks[j].0] { i } else { j };
                        let remove = if keep == i { j } else { i };
                        peaks[keep].1 = peaks[keep].1.min(peaks[remove].1);
                        peaks[keep].2 = peaks[keep].2.max(peaks[remove].2);
                        peaks.remove(remove);
                        merged = true;
                        break 'outer;
                    }
                }
            }
        }
        for (i, left, right) in peaks {
            let center = rt[i];
            let allowed_width = (rt[right] - rt[left]) * 0.5;
            let peak_max = (left..=right)
                .filter(|&j| (rt[j] - center).abs() <= allowed_width)
                .map(|j| y[j])
                .fold(0., f32::max);
            let peak_noise = if right - left + 1 >= 4 {
                (sm[left].min(sm[left + 1]) + sm[right - 1].min(sm[right])) / 2.
            } else {
                (left..=right).map(|j| sm[j]).fold(f32::INFINITY, f32::min)
            };
            if peak_noise > 0. && peak_max / peak_noise < min_snr {
                continue;
            }
            let f = make_feature(
                analysis,
                polarity,
                c,
                i,
                left,
                right,
                &rt,
                &mz,
                &y,
                &b,
                &sm,
                if polarity > 0 { "[M+H]+" } else { "[M-H]-" },
                if polarity > 0 { -1.007276 } else { 1.007276 },
            );
            if f.sn >= min_snr && f.r2 > -1. {
                out.push(f);
            }
        }
    }
    out
}

trait Unzip3<A, B, C> {
    fn unzip3(self) -> (Vec<A>, Vec<B>, Vec<C>);
}
impl<I, A, B, C> Unzip3<A, B, C> for I
where
    I: Iterator<Item = (A, B, C)>,
{
    fn unzip3(self) -> (Vec<A>, Vec<B>, Vec<C>) {
        let mut a = Vec::new();
        let mut b = Vec::new();
        let mut c = Vec::new();
        for (x, y, z) in self {
            a.push(x);
            b.push(y);
            c.push(z)
        }
        (a, b, c)
    }
}

fn row_sql(project: &str, f: &Feature) -> String {
    let mut vals = vec![
        sql(project),
        sql(&f.analysis),
        sql(&f.feature),
        "NULL".into(),
        "NULL".into(),
        sql(&f.adduct),
    ];
    let nums = [
        f.rt,
        f.mz,
        f.mass,
        f.intensity,
        f.noise,
        f.sn,
        f.area,
        STANDARD.decode(&f.eic[0].1).map_or(0, |bytes| bytes.len() / 4) as f32,
        f.rtmin,
        f.rtmax,
        f.width,
        f.mzmin,
        f.mzmax,
        f.ppm,
        f.fwhm_rt,
        f.fwhm_mz,
        f.ga,
        f.gmu,
        f.gs,
        f.r2,
        f.jag,
        f.sharp,
        f.asym,
    ];
    vals.extend(nums.iter().map(|x| {
        if x.is_finite() {
            x.to_string()
        } else {
            "0".into()
        }
    }));
    vals.extend([f.modality.to_string(), f.plates.to_string()]);
    vals.extend([
        f.polarity.to_string(),
        "FALSE".into(),
        "NULL".into(),
        "FALSE".into(),
        "1.0".into(),
        STANDARD.decode(&f.eic[0].1).map_or(0, |bytes| bytes.len() / 4).to_string(),
    ]);
    for (_, v) in &f.eic {
        vals.push(sql(v));
    }
    vals.extend([
        "0".into(),
        "NULL".into(),
        "NULL".into(),
        "0".into(),
        "NULL".into(),
        "NULL".into(),
        "NULL".into(),
        "NULL".into(),
        "0".into(),
        "0".into(),
        "0".into(),
        "0".into(),
        "0".into(),
        "0".into(),
        "0".into(),
        "0".into(),
        "0".into(),
        "0".into(),
        "0".into(),
        "0".into(),
        "NULL".into(),
        "0".into(),
        "0".into(),
        "0".into(),
        "FALSE".into(),
        "FALSE".into(),
    ]);
    vals.join(",")
}

pub fn find_features(project: &mut Project, p: &Value) -> Result<Value> {
    let mins = p
        .get("rt_windows_min")
        .and_then(Value::as_array)
        .ok_or_else(|| invalid("rt_windows_min is required"))?;
    let maxs = p
        .get("rt_windows_max")
        .and_then(Value::as_array)
        .ok_or_else(|| invalid("rt_windows_max is required"))?;
    if mins.len() != maxs.len() {
        return Err(invalid(
            "rt_windows_min and rt_windows_max must have equal lengths.",
        ));
    }
    let ppm = p
        .get("ppm_threshold")
        .and_then(Value::as_f64)
        .unwrap_or(15.) as f32;
    let noise = p
        .get("noise_threshold")
        .and_then(Value::as_f64)
        .unwrap_or(15.) as f32;
    let min_snr = p.get("min_snr").and_then(Value::as_f64).unwrap_or(3.) as f32;
    let min_traces = p.get("min_traces").and_then(Value::as_u64).unwrap_or(3) as usize;
    let bw = p
        .get("baseline_window")
        .and_then(Value::as_f64)
        .unwrap_or(30.) as f32;
    let mw = p
        .get("max_feature_width")
        .and_then(Value::as_f64)
        .unwrap_or(30.) as f32;
    let base_quantile = p
        .get("base_quantile")
        .and_then(Value::as_f64)
        .unwrap_or(0.1) as f32;
    let project_id = project.get_project_id();
     let schema="CREATE TABLE IF NOT EXISTS MASS_SPEC_NTA_FEATURES (project_id VARCHAR NOT NULL, analysis VARCHAR NOT NULL, feature VARCHAR NOT NULL, feature_component VARCHAR, feature_group VARCHAR, adduct VARCHAR, rt DOUBLE, mz DOUBLE, mass DOUBLE, intensity DOUBLE, noise DOUBLE, sn DOUBLE, area DOUBLE, trace_count INTEGER, rtmin DOUBLE, rtmax DOUBLE, width DOUBLE, mzmin DOUBLE, mzmax DOUBLE, ppm DOUBLE, fwhm_rt DOUBLE, fwhm_mz DOUBLE, gaussian_A DOUBLE, gaussian_mu DOUBLE, gaussian_sigma DOUBLE, gaussian_r2 DOUBLE, jaggedness DOUBLE, sharpness DOUBLE, asymmetry DOUBLE, modality INTEGER, plates DOUBLE, polarity INTEGER, filtered BOOLEAN, filter VARCHAR, filled BOOLEAN, correction DOUBLE, eic_size INTEGER, eic_rt VARCHAR, eic_mz VARCHAR, eic_intensity VARCHAR, eic_baseline VARCHAR, eic_smoothed VARCHAR, ms1_size INTEGER, ms1_mz VARCHAR, ms1_intensity VARCHAR, ms2_size INTEGER, ms2_mz VARCHAR, ms2_intensity VARCHAR, annotation_category VARCHAR, annotation_type VARCHAR, annotation_parent_feature VARCHAR, annotation_element VARCHAR, annotation_mass_error_da DOUBLE, annotation_mass_error_ppm DOUBLE, annotation_rt_error DOUBLE, annotation_rel_intensity DOUBLE, annotation_expected_rel_intensity_min DOUBLE, annotation_expected_rel_intensity_max DOUBLE, annotation_score DOUBLE, component_size INTEGER, component_rt_center DOUBLE, component_rt_spread DOUBLE, component_density DOUBLE, component_mean_correlation DOUBLE, component_best_partner VARCHAR, component_max_correlation DOUBLE, component_mean_correlation_to_component DOUBLE, component_membership_score DOUBLE, component_is_core BOOLEAN, component_bridge_flag BOOLEAN, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(project_id, analysis, feature))";
    project.execute_sql(schema)?;
    project.execute_sql(&format!(
        "DELETE FROM MASS_SPEC_NTA_FEATURES WHERE project_id={}",
        sql(&project_id)
    ))?;
    let wanted = p
        .get("analysis_names")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let rows = project.query_json(&format!(
        "SELECT analysis,file_path FROM MASS_SPEC_ANALYSES WHERE project_id={} ORDER BY analysis",
        sql(&project_id)
    ))?;
    for row in rows.as_array().into_iter().flatten() {
        let name = row["analysis"].as_str().unwrap_or_default();
        if !wanted.is_empty() && !wanted.iter().any(|x| x.as_str() == Some(name)) {
            continue;
        }
        let file = Reader::open(row["file_path"].as_str().unwrap_or_default())
            .map_err(|e| invalid(e.to_string()))?;
        for polarity in [-1, 1] {
            let mut points = Vec::new();
            for s in file
                .spectra()
                .iter()
                .filter(|s| s.level == 1 && s.polarity == polarity)
            {
                if !mins.is_empty()
                    && !mins.iter().zip(maxs).any(|(lo, hi)| {
                        s.retention_time >= lo.as_f64().unwrap_or(f32::NEG_INFINITY as f64) as f32
                            && s.retention_time
                                <= hi.as_f64().unwrap_or(f32::INFINITY as f64) as f32
                    })
                {
                    continue;
                }
                if s.mz.len() < min_traces {
                    continue;
                }
                let n = noise_levels(&s.intensity, noise, base_quantile);
                let mut valid =
                    s.mz.iter()
                        .zip(&s.intensity)
                        .zip(&n)
                        .filter(|((_, i), threshold)| **i > **threshold)
                        .map(|((mz, intensity), threshold)| (*mz, *intensity, *threshold))
                        .collect::<Vec<_>>();
                valid.sort_by(|a, b| a.0.total_cmp(&b.0));
                let mut merged: Vec<(f32, f32, f32)> = Vec::new();
                for point in valid {
                    if let Some(last) = merged.last_mut() {
                        if point.0 - last.0 <= point.0 * ppm / 1e6 {
                            if point.1 > last.1 {
                                *last = point;
                            }
                            continue;
                        }
                    }
                    merged.push(point);
                }
                for (mz, i, point_noise) in merged {
                    points.push(Point {
                        rt: s.retention_time,
                        mz,
                        intensity: i,
                        noise: point_noise,
                        cluster: 0,
                    })
                }
            }
            for f in detect(
                name,
                &mut points,
                min_traces,
                min_snr,
                bw,
                mw,
                polarity,
                ppm,
            ) {
                project.execute_sql(&format!(
                    "INSERT INTO MASS_SPEC_NTA_FEATURES VALUES ({}, NULL, NULL, CURRENT_TIMESTAMP)",
                    row_sql(&project_id, &f)
                ))?
            }
        }
    }
    Ok(json!({"status":"finished","info":"Features detected."}))
}
