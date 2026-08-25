#!/usr/bin/env python
"""Cross-backend feature overlap analysis: core C++ quantized DB vs Rust quantized DB."""
import duckdb
import math
import statistics
from collections import Counter

CPP_DB = r"C:\Users\cunha\AppData\Local\Temp\streamfind-nta-wastewater-quantized.duckdb"
RUST_DB = r"C:\Users\cunha\AppData\Local\Temp\streamfind-rust-nta-ww.duckdb"

PPM = 10.0     # mz window (workflow ppm)
SEC = 5.0      # rt window (group_features rt_deviation)

def load(db, project_id):
    con = duckdb.connect(db, read_only=True)
    rows = con.execute(
        "SELECT analysis, feature, polarity, mz, rt, intensity, area, sn, width, "
        "rtmin, rtmax, mzmin, mzmax, filtered FROM MASS_SPEC_NTA_FEATURES "
        "WHERE project_id = ? ORDER BY analysis, mz", [project_id]).fetchall()
    con.close()
    cols = ["analysis", "feature", "polarity", "mz", "rt", "intensity", "area",
            "sn", "width", "rtmin", "rtmax", "mzmin", "mzmax", "filtered"]
    return [{k: v for k, v in zip(cols, r)} for r in rows]

def greedy_match(cpp, rust):
    """1:1 nearest-neighbour matching per (analysis, polarity) within ppm/sec windows."""
    used = set()
    pairs = []  # (cpp_idx, rust_idx, mz_diff_ppm, rt_diff_s)
    for ci, c in enumerate(cpp):
        tol = c["mz"] * PPM / 1e6
        best, best_d = None, None
        for ri, r in enumerate(rust):
            if ri in used:
                continue
            if r["mz"] < c["mz"] - tol - 1e-6:
                continue
            if r["mz"] > c["mz"] + tol + 1e-6:
                break  # both lists sorted by mz
            if abs(r["rt"] - c["rt"]) > SEC:
                continue
            dmz = abs(r["mz"] - c["mz"]) / c["mz"] * 1e6
            d = dmz + 10.0 * abs(r["rt"] - c["rt"])
            if best_d is None or d < best_d:
                best, best_d = ri, d
        if best is not None:
            used.add(best)
            dmz = abs(rust[best]["mz"] - c["mz"]) / c["mz"] * 1e6
            drt = abs(rust[best]["rt"] - c["rt"])
            pairs.append((ci, best, dmz, drt))
    return pairs

def main():
    cpp = load(CPP_DB, "ww-conformance")
    rust = load(RUST_DB, "rust-nta-ww")
    print(f"rows: cpp={len(cpp)} rust={len(rust)}")

    def group(rows):
        g = {}
        for r in rows:
            g.setdefault((r["analysis"], r["polarity"]), []).append(r)
        return g
    cg, rg = group(cpp), group(rust)
    keys = sorted(set(cg) | set(rg))

    total_matched = 0
    c_used_ids, r_used_ids = set(), set()
    dmzs, drts, int_ratios, area_ratios = [], [], [], []
    print("per (analysis, matched, cpp-only, rust-only, n_cpp, n_rust):")
    for k in keys:
        cl, rl = cg.get(k, []), rg.get(k, [])
        pairs = greedy_match(cl, rl)
        total_matched += len(pairs)
        for (ci, ri, dmz, drt) in pairs:
            c_used_ids.add(id(cl[ci])); r_used_ids.add(id(rl[ri]))
            dmzs.append(dmz); drts.append(drt)
            c, r = cl[ci], rl[ri]
            if r["intensity"] > 0 and c["intensity"] > 0:
                int_ratios.append(r["intensity"] / c["intensity"])
            if r["area"] > 0 and c["area"] > 0:
                area_ratios.append(r["area"] / c["area"])
        n_cpp, n_rust = len(cl), len(rl)
        print(f"  {k[0][:40]:42} matched={len(pairs):4d}  cpp-only={n_cpp - len(pairs):4d}  "
              f"rust-only={n_rust - len(pairs):4d}  (cpp={n_cpp}, rust={n_rust}, pol={k[1]:+d})")

    n_cpp, n_rust = len(cpp), len(rust)
    only_cpp = n_cpp - total_matched
    only_rust = n_rust - total_matched
    union = n_cpp + n_rust - total_matched
    print(f"\nTOTAL   matched={total_matched}  cpp-only={only_cpp}  rust-only={only_rust}")
    print(f"overlap rate (matched / min(n_cpp, n_rust)) = {total_matched / min(n_cpp, n_rust):.1%}")
    print(f"Jaccard   (matched / union)                 = {total_matched / union:.1%}")
    print(f"coverage of cpp by rust (matched / n_cpp)   = {total_matched / n_cpp:.1%}")
    print(f"coverage of rust by cpp (matched / n_rust)  = {total_matched / n_rust:.1%}")

    if dmzs:
        print(f"\nmatched-pair |dmz| ppm:  median={statistics.median(dmzs):.3f}  "
              f"p90={sorted(dmzs)[int(len(dmzs) * 0.9) - 1]:.3f}  max={max(dmzs):.3f}")
        print(f"matched-pair |drt| sec:  median={statistics.median(drts):.3f}  "
              f"p90={sorted(drts)[int(len(drts) * 0.9) - 1]:.3f}  max={max(drts):.3f}")
    if int_ratios:
        gmean = math.exp(statistics.mean(math.log(x) for x in int_ratios))
        print(f"intensity ratio (rust/cpp): median={statistics.median(int_ratios):.3f}  geo-mean={gmean:.3f}")
    if area_ratios:
        print(f"area ratio (rust/cpp):      median={statistics.median(area_ratios):.3f}")

    print("\nexamples cpp-only (strongest 8):")
    for c in sorted((r for r in cpp if id(r) not in c_used_ids), key=lambda r: -r["intensity"])[:8]:
        print(f"  {c['analysis'][:30]:32} mz={c['mz']:.4f} rt={c['rt']:.2f} int={c['intensity']:.0f} "
              f"pol={c['polarity']:+d} filt={c['filtered']}")
    print("examples rust-only (strongest 8):")
    for r in sorted((r for r in rust if id(r) not in r_used_ids), key=lambda r: -r["intensity"])[:8]:
        print(f"  {r['analysis'][:30]:32} mz={r['mz']:.4f} rt={r['rt']:.2f} int={r['intensity']:.0f} "
              f"pol={r['polarity']:+d} filt={r['filtered']}")

    cf = sum(1 for c in cpp if id(c) not in c_used_ids and c["filtered"])
    rf = sum(1 for r in rust if id(r) not in r_used_ids and r["filtered"])
    print(f"\nunmatched that ended filtered: cpp-only {cf}/{only_cpp}, rust-only {rf}/{only_rust}")
    print(f"unmatched that kept a feature_group: "
          f"cpp-only {sum(1 for c in cpp if id(c) not in c_used_ids and c['feature'])}/NA")
    # correlation of matched intensities
    if len(int_ratios) > 2:
        print(f"matched intensity pairs: n={len(int_ratios)}")

if __name__ == "__main__":
    main()