//! EIC Pearson-correlation component clustering.
//!
//! Ported from `core/domains/mass_spec/src/nta_componentization.cpp`
//! (`nta::componentization::create_components_impl` and its helpers). The
//! algorithm groups the features of each analysis into connected components
//! of an RT-window + Pearson-correlation graph (per polarity), then annotates
//! every feature row with the `feature_component` / `component_*` columns.
//!
//! The C++ `debugRT` / `debugAnalysis` parameters gate logging only; they are
//! dropped together with all `DEBUG_LOG` / `DEBUG_OUT` statements.

use std::cmp::Ordering;
use std::collections::{BTreeMap, HashMap};

use crate::nta::ProjectNonTargetAnalysis;
use crate::nta_utils::decode_floats_base64;

/// Helper function to decode base64-encoded EIC data.
pub fn decode_eic_base64(base64_str: &str) -> Vec<f32> {
    decode_floats_base64(base64_str)
}

/// Helper function to calculate Pearson correlation between two aligned EIC
/// vectors.
pub fn calculate_pearson_correlation(x: &[f32], y: &[f32]) -> f32 {
    let n = x.len().min(y.len());
    if n < 3 {
        return 0.0; // Need at least 3 points
    }

    // Calculate means
    let mut mean_x = 0.0f32;
    let mut mean_y = 0.0f32;
    for i in 0..n {
        mean_x += x[i];
        mean_y += y[i];
    }
    mean_x /= n as f32;
    mean_y /= n as f32;

    // Calculate correlation
    let mut numerator = 0.0f32;
    let mut denom_x = 0.0f32;
    let mut denom_y = 0.0f32;
    for i in 0..n {
        let dx = x[i] - mean_x;
        let dy = y[i] - mean_y;
        numerator += dx * dy;
        denom_x += dx * dx;
        denom_y += dy * dy;
    }

    if denom_x < 1e-10 || denom_y < 1e-10 {
        return 0.0;
    }
    numerator / (denom_x * denom_y).sqrt()
}

/// Helper function to align two EICs by their RT values (not shifted by apex).
/// This preserves temporal information so time-shifted peaks show poor
/// correlation.
pub fn align_eics_by_rt(
    rt1: &[f32],
    int1: &[f32],
    rt2: &[f32],
    int2: &[f32],
) -> (Vec<f32>, Vec<f32>) {
    let mut aligned1 = Vec::new();
    let mut aligned2 = Vec::new();

    if rt1.is_empty() || rt2.is_empty() || int1.is_empty() || int2.is_empty() {
        return (aligned1, aligned2);
    }

    if rt1.len() != int1.len() || rt2.len() != int2.len() {
        return (aligned1, aligned2);
    }

    // Find overlapping RT range
    let rt1_min = rt1.iter().copied().fold(f32::INFINITY, f32::min);
    let rt1_max = rt1.iter().copied().fold(f32::NEG_INFINITY, f32::max);
    let rt2_min = rt2.iter().copied().fold(f32::INFINITY, f32::min);
    let rt2_max = rt2.iter().copied().fold(f32::NEG_INFINITY, f32::max);

    let overlap_start = rt1_min.max(rt2_min);
    let overlap_end = rt1_max.min(rt2_max);

    if overlap_start >= overlap_end {
        return (aligned1, aligned2); // No overlap
    }

    // For each RT point in EIC1 within overlap, find closest match in EIC2
    aligned1.reserve(rt1.len());
    aligned2.reserve(rt1.len());

    for i in 0..rt1.len() {
        let rt_val = rt1[i];

        // Skip if outside overlap range
        if rt_val < overlap_start || rt_val > overlap_end {
            continue;
        }

        // Find closest RT in EIC2
        let mut best_idx = 0usize;
        let mut min_diff = (rt2[0] - rt_val).abs();

        for j in 1..rt2.len() {
            let diff = (rt2[j] - rt_val).abs();
            if diff < min_diff {
                min_diff = diff;
                best_idx = j;
            }
        }

        // Only include if RT values are reasonably close (within 0.5 seconds)
        if min_diff <= 0.5 {
            aligned1.push(int1[i]);
            aligned2.push(int2[best_idx]);
        }
    }

    (aligned1, aligned2)
}

/// Feature (global index, RT, intensity) before EIC decoding.
/// `rt` mirrors the C++ `FeatureIntensity::rt`, which is likewise stored but
/// unused after the intensity sort.
#[allow(dead_code)]
struct FeatureIntensity {
    idx: usize,
    rt: f32,
    intensity: f32,
}

/// Feature with its decoded EIC arrays.
struct FeatureEIC {
    idx: usize,
    rt: f32,
    intensity: f32,
    eic_rt: Vec<f32>,
    eic_int: Vec<f32>,
}

/// One connected component of the correlation graph.
struct ComponentMembers {
    members: Vec<usize>,
    mean_rt: f32,
    max_intensity: f32,
}

/// Tarjan articulation-point DFS state (per component).
struct ArtState {
    disc: Vec<i32>,
    low: Vec<i32>,
    parent: Vec<i32>,
    time_counter: i32,
    flags: Vec<bool>,
}

impl ArtState {
    fn new(n: usize) -> Self {
        ArtState {
            disc: vec![-1; n],
            low: vec![-1; n],
            parent: vec![-1; n],
            time_counter: 0,
            flags: vec![false; n],
        }
    }

    fn dfs(
        &mut self,
        u: usize,
        members: &[usize],
        adjacency: &[Vec<usize>],
        local_index: &HashMap<usize, usize>,
    ) {
        self.disc[u] = self.time_counter;
        self.low[u] = self.time_counter;
        self.time_counter += 1;
        let mut children = 0;
        let member = members[u];
        for &neighbor_member in &adjacency[member] {
            let Some(&v) = local_index.get(&neighbor_member) else {
                continue;
            };
            if self.disc[v] == -1 {
                self.parent[v] = u as i32;
                children += 1;
                self.dfs(v, members, adjacency, local_index);
                self.low[u] = self.low[u].min(self.low[v]);
                if (self.parent[u] == -1 && children > 1)
                    || (self.parent[u] != -1 && self.low[v] >= self.disc[u])
                {
                    self.flags[u] = true;
                }
            } else if v as i32 != self.parent[u] {
                self.low[u] = self.low[u].min(self.disc[v]);
            }
        }
    }
}

/// Main implementation of component creation.
///
/// Mirrors `nta::componentization::create_components_impl` (debug-only
/// `debugRT`/`debugAnalysis` parameters dropped). The C++ function never
/// fails; this returns `Result<()>` for pipeline uniformity.
pub fn create_components_impl(
    nta_data: &mut ProjectNonTargetAnalysis,
    rt_window: &[f32],
    min_correlation: f32,
) -> streamfind_rust_core::Result<()> {
    let left_offset = if rt_window.len() >= 1 {
        rt_window[0]
    } else {
        0.0
    };
    let right_offset = if rt_window.len() >= 2 {
        rt_window[1]
    } else {
        0.0
    };

    for i in 0..nta_data.feature_buffers.len() {
        let fts = &mut nta_data.feature_buffers[i];
        let n = fts.size();

        if n == 0 {
            continue;
        }

        let mut polarity_groups: BTreeMap<i32, Vec<usize>> = BTreeMap::new();
        for j in 0..n {
            let ft = fts.get_feature(j);
            polarity_groups.entry(ft.polarity).or_default().push(j);
        }

        for (polarity, feature_indices) in polarity_groups {
            if feature_indices.is_empty() {
                continue;
            }

            let mut component_counter = 1i32;

            // Determine polarity suffix
            let polarity_suffix = if polarity > 0 {
                "_POS"
            } else if polarity < 0 {
                "_NEG"
            } else {
                ""
            };

            let mut sorted_features: Vec<FeatureIntensity> =
                Vec::with_capacity(feature_indices.len());
            for &j in &feature_indices {
                let ft = fts.get_feature(j);
                sorted_features.push(FeatureIntensity {
                    idx: j,
                    rt: ft.rt as f32,
                    intensity: ft.intensity as f32,
                });
            }

            // Sort by descending intensity
            sorted_features.sort_by(|a, b| {
                b.intensity
                    .partial_cmp(&a.intensity)
                    .unwrap_or(Ordering::Equal)
            });

            let mut feature_eics: Vec<FeatureEIC> = Vec::with_capacity(sorted_features.len());
            for sf in &sorted_features {
                let ft = fts.get_feature(sf.idx);
                feature_eics.push(FeatureEIC {
                    idx: sf.idx,
                    rt: ft.rt as f32,
                    intensity: ft.intensity as f32,
                    eic_rt: decode_eic_base64(&ft.eic_rt),
                    eic_int: decode_eic_base64(&ft.eic_intensity),
                });
            }

            feature_eics.sort_by(|a, b| {
                if a.rt != b.rt {
                    return if a.rt < b.rt {
                        Ordering::Less
                    } else {
                        Ordering::Greater
                    };
                }
                if a.intensity != b.intensity {
                    return if a.intensity > b.intensity {
                        Ordering::Less
                    } else {
                        Ordering::Greater
                    };
                }
                a.idx.cmp(&b.idx)
            });

            let feature_count = feature_eics.len();
            let max_rt_gap = left_offset.abs().max(right_offset.abs());
            let rt_compatible = |rt_a: f32, rt_b: f32| {
                (rt_b >= rt_a + left_offset && rt_b <= rt_a + right_offset)
                    || (rt_a >= rt_b + left_offset && rt_a <= rt_b + right_offset)
            };

            let mut adjacency: Vec<Vec<usize>> = vec![Vec::new(); feature_count];
            let mut correlation_matrix = vec![vec![f32::NAN; feature_count]; feature_count];
            for a in 0..feature_count {
                correlation_matrix[a][a] = 1.0;
            }
            for a in 0..feature_count {
                for b in a + 1..feature_count {
                    let rt_delta = feature_eics[b].rt - feature_eics[a].rt;
                    if rt_delta > max_rt_gap {
                        break;
                    }
                    if !rt_compatible(feature_eics[a].rt, feature_eics[b].rt) {
                        continue;
                    }
                    if min_correlation <= 0.0 {
                        adjacency[a].push(b);
                        adjacency[b].push(a);
                        continue;
                    }
                    if feature_eics[a].eic_rt.is_empty()
                        || feature_eics[a].eic_int.is_empty()
                        || feature_eics[b].eic_rt.is_empty()
                        || feature_eics[b].eic_int.is_empty()
                    {
                        continue;
                    }

                    let (aligned1, aligned2) = align_eics_by_rt(
                        &feature_eics[a].eic_rt,
                        &feature_eics[a].eic_int,
                        &feature_eics[b].eic_rt,
                        &feature_eics[b].eic_int,
                    );

                    if aligned1.len() < 3 {
                        continue;
                    }

                    let corr = calculate_pearson_correlation(&aligned1, &aligned2);
                    correlation_matrix[a][b] = corr;
                    correlation_matrix[b][a] = corr;
                    if corr >= min_correlation {
                        adjacency[a].push(b);
                        adjacency[b].push(a);
                    }
                }
            }

            let mut visited = vec![false; feature_count];
            let mut components: Vec<ComponentMembers> = Vec::new();

            for start in 0..feature_count {
                if visited[start] {
                    continue;
                }

                let mut stack = vec![start];
                visited[start] = true;
                let mut members = Vec::new();
                let mut rt_sum = 0.0f32;
                let mut max_intensity = 0.0f32;

                while let Some(node) = stack.pop() {
                    members.push(node);
                    rt_sum += feature_eics[node].rt;
                    max_intensity = max_intensity.max(feature_eics[node].intensity);

                    for &neighbor in &adjacency[node] {
                        if !visited[neighbor] {
                            visited[neighbor] = true;
                            stack.push(neighbor);
                        }
                    }
                }

                let mean_rt = rt_sum / members.len() as f32;
                members.sort_by(|&lhs, &rhs| {
                    let ft_lhs = fts.get_feature(feature_eics[lhs].idx);
                    let ft_rhs = fts.get_feature(feature_eics[rhs].idx);
                    if ft_lhs.mz != ft_rhs.mz {
                        return if ft_lhs.mz < ft_rhs.mz {
                            Ordering::Less
                        } else {
                            Ordering::Greater
                        };
                    }
                    if ft_lhs.rt != ft_rhs.rt {
                        return if ft_lhs.rt < ft_rhs.rt {
                            Ordering::Less
                        } else {
                            Ordering::Greater
                        };
                    }
                    feature_eics[lhs].idx.cmp(&feature_eics[rhs].idx)
                });
                components.push(ComponentMembers {
                    members,
                    mean_rt,
                    max_intensity,
                });
            }

            components.sort_by(|a, b| {
                if a.max_intensity != b.max_intensity {
                    return if a.max_intensity > b.max_intensity {
                        Ordering::Less
                    } else {
                        Ordering::Greater
                    };
                }
                if a.mean_rt != b.mean_rt {
                    return if a.mean_rt < b.mean_rt {
                        Ordering::Less
                    } else {
                        Ordering::Greater
                    };
                }
                a.members[0].cmp(&b.members[0])
            });

            for component in &components {
                let member_count = component.members.len();
                let component_rt_center = component.mean_rt;
                let mut rt_min = f32::MAX;
                let mut rt_max = -f32::MAX;
                for &member in &component.members {
                    rt_min = rt_min.min(feature_eics[member].rt);
                    rt_max = rt_max.max(feature_eics[member].rt);
                }
                let component_rt_spread = if member_count > 0 {
                    rt_max - rt_min
                } else {
                    0.0
                };

                let possible_pairs = if member_count > 1 {
                    member_count * (member_count - 1) / 2
                } else {
                    0
                };
                let mut edge_count = 0usize;
                let mut valid_corr_pairs = 0usize;
                let mut corr_sum = 0.0f32;
                let mut local_index: HashMap<usize, usize> = HashMap::with_capacity(member_count);
                for (mi, &member) in component.members.iter().enumerate() {
                    local_index.insert(member, mi);
                }

                for mi in 0..member_count {
                    let member_a = component.members[mi];
                    for mj in mi + 1..member_count {
                        let member_b = component.members[mj];
                        let corr = correlation_matrix[member_a][member_b];
                        if !corr.is_nan() {
                            corr_sum += corr;
                            valid_corr_pairs += 1;
                        }
                        if adjacency[member_a].contains(&member_b) {
                            edge_count += 1;
                        }
                    }
                }

                let component_density = if possible_pairs > 0 {
                    edge_count as f32 / possible_pairs as f32
                } else {
                    0.0
                };
                let component_mean_corr = if valid_corr_pairs > 0 {
                    corr_sum / valid_corr_pairs as f32
                } else {
                    0.0
                };

                let mut component_degrees = vec![0i32; member_count];
                let mut articulation_flags = vec![false; member_count];
                for (mi, &member) in component.members.iter().enumerate() {
                    for &neighbor in &adjacency[member] {
                        if local_index.contains_key(&neighbor) {
                            component_degrees[mi] += 1;
                        }
                    }
                }

                if member_count > 2 {
                    let mut art = ArtState::new(member_count);
                    for mi in 0..member_count {
                        if art.disc[mi] == -1 {
                            art.dfs(mi, &component.members, &adjacency, &local_index);
                        }
                    }
                    articulation_flags = art.flags;
                }

                let mut degree_sorted = component_degrees.clone();
                degree_sorted.sort_unstable();
                let median_degree = if degree_sorted.is_empty() {
                    0
                } else {
                    degree_sorted[degree_sorted.len() / 2]
                };

                let component_id = format!(
                    "FC{}_{:.0}{}",
                    component_counter, component.mean_rt, polarity_suffix
                );
                component_counter += 1;

                for mi in 0..member_count {
                    let member = component.members[mi];
                    let feature_idx = feature_eics[member].idx;
                    let mut ft = fts.get_feature(feature_idx);
                    let mut feature_corr_sum = 0.0f32;
                    let mut feature_corr_count = 0usize;
                    let mut feature_max_corr = 0.0f32;
                    let mut best_partner = String::new();

                    for mj in 0..member_count {
                        if mi == mj {
                            continue;
                        }
                        let other_member = component.members[mj];
                        let corr = correlation_matrix[member][other_member];
                        if corr.is_nan() {
                            continue;
                        }
                        feature_corr_sum += corr;
                        feature_corr_count += 1;
                        if best_partner.is_empty() || corr > feature_max_corr {
                            feature_max_corr = corr;
                            let other_ft = fts.get_feature(feature_eics[other_member].idx);
                            best_partner = other_ft.feature;
                        }
                    }

                    let feature_mean_corr = if feature_corr_count > 0 {
                        feature_corr_sum / feature_corr_count as f32
                    } else {
                        0.0
                    };
                    let membership_score = feature_mean_corr.max(0.0) * component_density;

                    ft.feature_component = component_id.clone();
                    ft.component_size = member_count as i32;
                    ft.component_rt_center = component_rt_center as f64;
                    ft.component_rt_spread = component_rt_spread as f64;
                    ft.component_density = component_density as f64;
                    ft.component_mean_correlation = component_mean_corr as f64;
                    ft.component_best_partner = best_partner;
                    ft.component_max_correlation = feature_max_corr as f64;
                    ft.component_mean_correlation_to_component = feature_mean_corr as f64;
                    ft.component_membership_score = membership_score as f64;
                    ft.component_is_core = (component_degrees[mi] >= median_degree)
                        && (feature_mean_corr >= component_mean_corr);
                    ft.component_bridge_flag = articulation_flags[mi];
                    fts.set_feature(feature_idx, &ft);
                }
            }
        }
    }

    Ok(())
}
