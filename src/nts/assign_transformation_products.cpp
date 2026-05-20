// assign_transformation_products.cpp
// Implementation of the AssignTransformationProducts algorithm.
//
// Algorithm mirrors the R implementation in
// run.MassSpecMethod_AssignTransformationProducts_native:
//
//   1. Build SMILES → {feature_group, …} maps from the flat suspects.
//   2. For each transformation-product row, expand across all combinations
//      of (product_fg × precursor_fg × main_precursor_fg).
//   3. For each combination compute:
//        - RT plausibility  (sign(ΔlogP) * sign(ΔRT), ±1/0/NA)
//        - cosine similarity (best pair across matching suspects)

#include "assign_transformation_products.h"
#include "nts.h"

#include <algorithm>
#include <cmath>
#include <limits>
#include <unordered_map>

namespace nts::assign_transformation_products
{

  // ── Internal helpers ────────────────────────────────────────────────────────

  namespace
  {
    // Decode base64 + little-endian float32 → vector<double>.
    std::vector<double> decode_encoded(const std::string &encoded)
    {
      std::vector<double> out;
      if (encoded.empty()) return out;
      std::string raw       = mass_spec::reader::utils::decode_base64(encoded);
      std::vector<float> fv = mass_spec::reader::utils::decode_little_endian_to_float(raw, 4);
      out.reserve(fv.size());
      for (float f : fv) out.push_back(static_cast<double>(f));
      return out;
    }

    // Cosine similarity between two MS2 spectra using absolute m/z tolerance.
    double cosine_similarity(
        const std::vector<double> &mz1, const std::vector<double> &int1,
        const std::vector<double> &mz2, const std::vector<double> &int2,
        double tol)
    {
      if (mz1.empty() || mz2.empty())
        return std::numeric_limits<double>::quiet_NaN();

      // For each peak in spec2, find best-matching peak in spec1.
      std::vector<double> i1, i2;
      i1.reserve(mz2.size());
      i2.reserve(mz2.size());
      for (size_t j = 0; j < mz2.size(); ++j)
      {
        double best = 0.0;
        for (size_t k = 0; k < mz1.size(); ++k)
          if (std::abs(mz1[k] - mz2[j]) <= tol && int1[k] > best)
            best = int1[k];
        i1.push_back(best);
        i2.push_back(int2[j]);
      }

      double dot = 0.0, mag1 = 0.0, mag2 = 0.0;
      for (size_t j = 0; j < i1.size(); ++j)
      {
        dot  += i1[j] * i2[j];
        mag1 += i1[j] * i1[j];
        mag2 += i2[j] * i2[j];
      }
      if (mag1 <= 0.0 || mag2 <= 0.0) return 0.0;
      return dot / (std::sqrt(mag1) * std::sqrt(mag2));
    }

    // RT plausibility: +1, -1, 0, or NaN.
    double rt_plausibility(
        double prod_logp, double prec_logp,
        double prod_rt,   double prec_rt,
        const std::string &phase)
    {
      const double nan = std::numeric_limits<double>::quiet_NaN();
      if (std::isnan(prod_logp) || std::isnan(prec_logp) ||
          std::isnan(prod_rt)   || std::isnan(prec_rt))
        return nan;

      double dl = prod_logp - prec_logp;
      double dr = prod_rt   - prec_rt;
      double sl = (dl > 0.0) ? 1.0 : (dl < 0.0) ? -1.0 : 0.0;
      double sr = (dr > 0.0) ? 1.0 : (dr < 0.0) ? -1.0 : 0.0;

      if (phase == "reverse_phase") return sl * sr;
      if (phase == "hilic")         return -sl * sr;
      return nan;
    }

    // Mean of a double vector (ignoring NaN).
    double mean_rt(const std::vector<double> &v)
    {
      double s = 0.0; int n = 0;
      for (double x : v) if (!std::isnan(x)) { s += x; ++n; }
      return n > 0 ? s / n : std::numeric_limits<double>::quiet_NaN();
    }
  } // anonymous

  // ── Main implementation ─────────────────────────────────────────────────────

  nts::api::NTS_TRANSFORMATION_PRODUCTS assign_transformation_products_impl(
      const std::vector<nts::api::NTS_SUSPECT_ROW> &suspects,
      const std::vector<nts::api::NTS_TRANSFORMATION_PRODUCT_ROW> &tp_rows,
      const std::string &chromatographic_phase,
      double mzrMS2)
  {
    nts::api::NTS_TRANSFORMATION_PRODUCTS out;
    if (tp_rows.empty()) return out;

    const double nan = std::numeric_limits<double>::quiet_NaN();
    const std::vector<std::string> empty_fg = {""};

    // ── Build SMILES → unique feature_groups map ────────────────────────────
    std::unordered_map<std::string, std::vector<std::string>> fg_map;
    for (const auto &s : suspects)
    {
      if (s.SMILES.empty() || s.feature_group.empty()) continue;
      auto &v = fg_map[s.SMILES];
      if (std::find(v.begin(), v.end(), s.feature_group) == v.end())
        v.push_back(s.feature_group);
    }

    // ── Build (SMILES + '\0' + feature_group) → suspect indices ────────────
    // Used for fast lookup when computing metrics.
    std::unordered_map<std::string, std::vector<size_t>> sf_idx;
    for (size_t i = 0; i < suspects.size(); ++i)
    {
      const auto &s = suspects[i];
      if (s.SMILES.empty() || s.feature_group.empty()) continue;
      sf_idx[s.SMILES + '\0' + s.feature_group].push_back(i);
    }

    // ── Process each TP row ─────────────────────────────────────────────────
    for (const auto &tp : tp_rows)
    {
      // Resolve feature_group sets (fall back to {""} so we always get one row)
      auto it_prod = fg_map.find(tp.SMILES);
      auto it_prec = fg_map.find(tp.precursor_SMILES);
      auto it_main = fg_map.find(tp.main_precursor_SMILES);

      const std::vector<std::string> &prod_fgs =
          (it_prod != fg_map.end()) ? it_prod->second : empty_fg;
      const std::vector<std::string> &prec_fgs =
          (it_prec != fg_map.end()) ? it_prec->second : empty_fg;
      const std::vector<std::string> &main_fgs =
          (it_main != fg_map.end()) ? it_main->second : empty_fg;

      // ── Expand combinations ──────────────────────────────────────────────
      for (const auto &prod_fg : prod_fgs)
      {
        for (const auto &prec_fg : prec_fgs)
        {
          for (const auto &main_fg : main_fgs)
          {
            double cos_sim      = nan;
            double main_cos_sim = nan;
            double rt_plaus = nan;
            double main_rt_plaus = nan;

            // ── Product vs Precursor ────────────────────────────────────────
            if (!prod_fg.empty() && !prec_fg.empty())
            {
              auto it_ps = sf_idx.find(tp.SMILES + '\0' + prod_fg);
              auto it_qs = sf_idx.find(tp.precursor_SMILES + '\0' + prec_fg);

              if (it_ps != sf_idx.end() && it_qs != sf_idx.end())
              {
                // RT plausibility (mean RT of matching suspects)
                std::vector<double> prod_rts, prec_rts;
                for (size_t idx : it_ps->second) prod_rts.push_back(suspects[idx].exp_rt);
                for (size_t idx : it_qs->second) prec_rts.push_back(suspects[idx].exp_rt);
                rt_plaus = rt_plausibility(
                    tp.xLogP, tp.precursor_xLogP,
                    mean_rt(prod_rts), mean_rt(prec_rts),
                    chromatographic_phase);

                // Cosine similarity (best pair)
                double best = nan;
                for (size_t pi : it_ps->second)
                {
                  if (suspects[pi].exp_ms2_size <= 0) continue;
                  auto mz1 = decode_encoded(suspects[pi].exp_ms2_mz);
                  auto in1 = decode_encoded(suspects[pi].exp_ms2_intensity);
                  for (size_t qi : it_qs->second)
                  {
                    if (suspects[qi].exp_ms2_size <= 0) continue;
                    auto mz2 = decode_encoded(suspects[qi].exp_ms2_mz);
                    auto in2 = decode_encoded(suspects[qi].exp_ms2_intensity);
                    double v = cosine_similarity(mz1, in1, mz2, in2, mzrMS2);
                    if (!std::isnan(v) && (std::isnan(best) || v > best)) best = v;
                  }
                }
                cos_sim = best;
              }
            }

            // ── Product vs Main Precursor ───────────────────────────────────
            if (!prod_fg.empty() && !main_fg.empty() &&
                !tp.main_precursor_SMILES.empty())
            {
              auto it_ps = sf_idx.find(tp.SMILES + '\0' + prod_fg);
              auto it_ms = sf_idx.find(tp.main_precursor_SMILES + '\0' + main_fg);

              if (it_ps != sf_idx.end() && it_ms != sf_idx.end())
              {
                std::vector<double> prod_rts, main_rts;
                for (size_t idx : it_ps->second) prod_rts.push_back(suspects[idx].exp_rt);
                for (size_t idx : it_ms->second) main_rts.push_back(suspects[idx].exp_rt);
                main_rt_plaus = rt_plausibility(
                    tp.xLogP, tp.main_precursor_xLogP,
                    mean_rt(prod_rts), mean_rt(main_rts),
                    chromatographic_phase);

                double best = nan;
                for (size_t pi : it_ps->second)
                {
                  if (suspects[pi].exp_ms2_size <= 0) continue;
                  auto mz1 = decode_encoded(suspects[pi].exp_ms2_mz);
                  auto in1 = decode_encoded(suspects[pi].exp_ms2_intensity);
                  for (size_t mi : it_ms->second)
                  {
                    if (suspects[mi].exp_ms2_size <= 0) continue;
                    auto mz2 = decode_encoded(suspects[mi].exp_ms2_mz);
                    auto in2 = decode_encoded(suspects[mi].exp_ms2_intensity);
                    double v = cosine_similarity(mz1, in1, mz2, in2, mzrMS2);
                    if (!std::isnan(v) && (std::isnan(best) || v > best)) best = v;
                  }
                }
                main_cos_sim = best;
              }
            }

            nts::api::NTS_TRANSFORMATION_PRODUCT_ROW row;
            row.name = tp.name;
            row.formula = tp.formula;
            row.mass = tp.mass;
            row.SMILES = tp.SMILES;
            row.InChI = tp.InChI;
            row.InChIKey = tp.InChIKey;
            row.xLogP = tp.xLogP;
            row.transformation = tp.transformation;
            row.precursor_name = tp.precursor_name;
            row.precursor_formula = tp.precursor_formula;
            row.precursor_mass = tp.precursor_mass;
            row.precursor_SMILES = tp.precursor_SMILES;
            row.precursor_InChI = tp.precursor_InChI;
            row.precursor_InChIKey = tp.precursor_InChIKey;
            row.precursor_xLogP = tp.precursor_xLogP;
            row.main_precursor_name = tp.main_precursor_name;
            row.main_precursor_formula = tp.main_precursor_formula;
            row.main_precursor_mass = tp.main_precursor_mass;
            row.main_precursor_SMILES = tp.main_precursor_SMILES;
            row.main_precursor_InChI = tp.main_precursor_InChI;
            row.main_precursor_InChIKey = tp.main_precursor_InChIKey;
            row.main_precursor_xLogP = tp.main_precursor_xLogP;
            row.feature_group = prod_fg;
            row.precursor_feature_group = prec_fg;
            row.main_precursor_feature_group = main_fg;
            row.cosine_similarity = cos_sim;
            row.main_precursor_cosine_similarity = main_cos_sim;
            row.rt_plausibility = rt_plaus;
            row.main_precursor_rt_plausibility = main_rt_plaus;
            out.append(row);
          }
        }
      }
    }

    return out;
  }

} // namespace nts::assign_transformation_products
