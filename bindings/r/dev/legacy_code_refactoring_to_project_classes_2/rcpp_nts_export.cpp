#include <vector>
#include <cctype>
#include <cstdlib>
#include <cmath>
#include <Rcpp.h>

#include "project/project.h"
#include "../src/mass_spec/project_mass_spec.h"
#include "nts/nts.h"
#include "nts/project_non_target_analysis.h"

using namespace Rcpp;

// Rcpp translator for this TU: wrap API-level calls and convert exceptions
// to R errors here so the project API remains pure C++.
namespace project
{
  template <typename Fn>
  inline auto project_call(Fn &&fn)
  {
    try
    {
      return project::api::project_call(std::forward<Fn>(fn));
    }
    catch (const std::exception &e)
    {
      Rcpp::stop(e.what());
    }
  }
} // namespace project

namespace
{
  std::vector<double> doubles_from_numeric_vector(const NumericVector& values)
  {
    std::vector<double> out(values.size());
    for (R_xlen_t i = 0; i < values.size(); ++i)
    {
      out[static_cast<std::size_t>(i)] = NumericVector::is_na(values[i]) ? 0.0 : static_cast<double>(values[i]);
    }
    return out;
  }

  std::vector<std::string> strings_from_character_vector(const CharacterVector& values)
  {
    std::vector<std::string> out(values.size());
    for (R_xlen_t i = 0; i < values.size(); ++i)
    {
      out[static_cast<std::size_t>(i)] = CharacterVector::is_na(values[i]) ? std::string() : as<std::string>(values[i]);
    }
    return out;
  }

  template <typename T>
  void assign_if_present(DataFrame df, const char* name, T& target);

  template <>
  void assign_if_present(DataFrame df, const char* name, std::vector<double>& target)
  {
    if (df.containsElementNamed(name))
    {
      target = doubles_from_numeric_vector(df[name]);
    }
  }

  template <>
  void assign_if_present(DataFrame df, const char* name, std::vector<std::string>& target)
  {
    if (df.containsElementNamed(name))
    {
      target = strings_from_character_vector(df[name]);
    }
  }

  mass_spec::MS_TARGETS_INPUT ms_targets_input_from_df(DataFrame df)
  {
    mass_spec::MS_TARGETS_INPUT out;
    out.size = static_cast<std::size_t>(df.nrows());
    if (out.size == 0)
    {
      return out;
    }
    assign_if_present(df, "id", out.id);
    assign_if_present(df, "analysis", out.analysis);
    assign_if_present(df, "polarity", out.polarity);
    assign_if_present(df, "mass", out.mass);
    assign_if_present(df, "min", out.mass_min);
    assign_if_present(df, "max", out.mass_max);
    assign_if_present(df, "mz", out.mz);
    assign_if_present(df, "mzmin", out.mzmin);
    assign_if_present(df, "mzmax", out.mzmax);
    assign_if_present(df, "rt", out.rt);
    assign_if_present(df, "rtmin", out.rtmin);
    assign_if_present(df, "rtmax", out.rtmax);
    assign_if_present(df, "mobility", out.mobility);
    assign_if_present(df, "mobilitymin", out.mobilitymin);
    assign_if_present(df, "mobilitymax", out.mobilitymax);
    if (df.containsElementNamed("name") && out.id.empty())
    {
      out.id = strings_from_character_vector(df["name"]);
    }
    return out;
  }

  mass_spec::MS_TARGETS_INPUT ms_targets_input_from_object(SEXP value)
  {
    if (Rf_isNull(value))
    {
      return {};
    }
    if (Rf_isNumeric(value) && !Rf_isMatrix(value))
    {
      DataFrame df = DataFrame::create(Named("mz") = NumericVector(value));
      return ms_targets_input_from_df(df);
    }
    if (Rf_isString(value) && !Rf_isObject(value))
    {
      return {};
    }
    if (Rf_inherits(value, "data.frame"))
    {
      return ms_targets_input_from_df(as<DataFrame>(value));
    }
    return {};
  }

  std::vector<std::string> as_character_selection(SEXP value, const std::string &column_a, const std::string &column_b = "")
  {
    if (Rf_isNull(value))
    {
      return {};
    }
    if (Rf_inherits(value, "data.frame"))
    {
      Rcpp::DataFrame df = Rcpp::as<Rcpp::DataFrame>(value);
      if (df.containsElementNamed(column_a.c_str()))
      {
        return Rcpp::as<std::vector<std::string>>(df[column_a]);
      }
      if (!column_b.empty() && df.containsElementNamed(column_b.c_str()))
      {
        return Rcpp::as<std::vector<std::string>>(df[column_b]);
      }
      Rcpp::stop("Selection data.frame must contain '%s'%s%s",
                 column_a.c_str(),
                 column_b.empty() ? "" : " or '",
                 column_b.empty() ? "" : column_b.c_str());
    }
    return Rcpp::as<std::vector<std::string>>(Rcpp::as<Rcpp::CharacterVector>(value));
  }



  ::project::api::PROJECT &project_from_xptr(SEXP extptr)
  {
    void *raw = R_ExternalPtrAddr(extptr);
    if (raw == nullptr)
    {
      stop("Project pointer is null");
    }
    return *reinterpret_cast<::project::api::PROJECT *>(raw);
  }

  nts::PROJECT_NON_TARGET_ANALYSIS &project_non_target_analysis_from_xptr(SEXP extptr)
  {
    Rcpp::XPtr<nts::PROJECT_NON_TARGET_ANALYSIS> ptr(extptr);
    if (ptr.get() == nullptr)
    {
      stop("Project Non-Target Analysis pointer is null");
    }
    return *ptr;
  }

  std::string trim_copy(const std::string &s)
  {
    size_t start = 0;
    while (start < s.size() && std::isspace(static_cast<unsigned char>(s[start])))
      ++start;
    size_t end = s.size();
    while (end > start && std::isspace(static_cast<unsigned char>(s[end - 1])))
      --end;
    return s.substr(start, end - start);
  }

  std::vector<std::string> split_string(const std::string &s, char delimiter)
  {
    std::vector<std::string> out;
    std::string cur;
    for (char c : s)
    {
      if (c == delimiter)
      {
        out.push_back(cur);
        cur.clear();
      }
      else
      {
        cur.push_back(c);
      }
    }
    out.push_back(cur);
    return out;
  }

  Rcpp::List get_empty_dt()
  {
    Rcpp::List out = Rcpp::List::create();
    out.attr("class") = Rcpp::CharacterVector::create("data.table", "data.frame");
    return out;
  }

  Rcpp::CharacterVector as_char_vector(const std::vector<std::string> &values, bool na_on_empty = false)
  {
    Rcpp::CharacterVector out(values.size());
    for (size_t i = 0; i < values.size(); ++i)
    {
      if (na_on_empty && values[i].empty())
      {
        out[i] = NA_STRING;
      }
      else
      {
        out[i] = values[i];
      }
    }
    return out;
  }

  Rcpp::NumericVector as_numeric_vector(const std::vector<double> &values, bool na_on_nan = true)
  {
    Rcpp::NumericVector out(values.size());
    for (size_t i = 0; i < values.size(); ++i)
    {
      if (na_on_nan && std::isnan(values[i]))
      {
        out[i] = NA_REAL;
      }
      else
      {
        out[i] = values[i];
      }
    }
    return out;
  }

  bool check_list_must_have_names(
      const Rcpp::List &list,
      const std::vector<std::string> &must_have_names)
  {
    std::vector<std::string> names_list = list.names();
    const int must_have_names_size = must_have_names.size();
    if (must_have_names_size == 0)
      return false;
    const int names_list_size = names_list.size();
    if (names_list_size == 0)
      return false;
    std::vector<bool> has_must_have_names(must_have_names_size, false);

    for (int i = 0; i < must_have_names_size; ++i)
    {
      for (int j = 0; j < names_list_size; ++j)
      {
        if (must_have_names[i] == names_list[j])
          has_must_have_names[i] = true;
      }
    }

    for (int i = 0; i < must_have_names_size; ++i)
    {
      if (!has_must_have_names[i])
      {
        return false;
      }
    }

    return true;
  }

  void validate_per_analysis_list(const Rcpp::List &info,
                                  const Rcpp::List &input,
                                  const std::string &arg_name)
  {
    if (!info.containsElementNamed("analysis"))
    {
      Rcpp::stop("validate_per_analysis_list: info is missing 'analysis' column");
    }

    std::vector<std::string> analyses = Rcpp::as<std::vector<std::string>>(info["analysis"]);
    const R_xlen_t expected = static_cast<R_xlen_t>(analyses.size());
    const R_xlen_t got = input.size();

    if (got != expected)
    {
      Rcpp::stop("%s size mismatch: expected %d entries (one per analysis), got %d",
                 arg_name.c_str(),
                 static_cast<int>(expected),
                 static_cast<int>(got));
    }

    Rcpp::CharacterVector nms = input.names();
    if (nms.size() != got)
    {
      Rcpp::stop("%s must be a named list with one entry per analysis", arg_name.c_str());
    }

    for (R_xlen_t i = 0; i < got; ++i)
    {
      if (nms[i] == NA_STRING)
      {
        Rcpp::stop("%s has missing name at position %d", arg_name.c_str(), static_cast<int>(i + 1));
      }

      std::string got_name = Rcpp::as<std::string>(nms[i]);
      const std::string &expected_name = analyses[static_cast<size_t>(i)];
      if (got_name != expected_name)
      {
        Rcpp::stop("%s name/order mismatch at position %d: expected '%s', got '%s'",
                   arg_name.c_str(),
                   static_cast<int>(i + 1),
                   expected_name.c_str(),
                   got_name.c_str());
      }
    }
  }

  nts::NTS_INFO as_nts_info(const Rcpp::List &info)
  {
    nts::NTS_INFO out;
    std::vector<std::string> info_must_have_names = {
        "analysis", "replicate", "blank", "file"};

    if (!check_list_must_have_names(info, info_must_have_names))
    {
      Rcpp::Rcout << "Error: NTS_DATA() - missing required names in the info list." << std::endl;
      return out;
    }

    out.analyses = Rcpp::as<std::vector<std::string>>(info["analysis"]);
    out.replicates = Rcpp::as<std::vector<std::string>>(info["replicate"]);
    out.blanks = Rcpp::as<std::vector<std::string>>(info["blank"]);
    out.files = Rcpp::as<std::vector<std::string>>(info["file"]);
    return out;
  }

  mass_spec::MS_SPECTRA_HEADERS as_MS_SPECTRA_HEADERS(const Rcpp::List &hd)
  {
    mass_spec::MS_SPECTRA_HEADERS headers;
    const std::vector<int> &hd_index = hd["index"];
    const std::vector<int> &hd_polarity = hd["polarity"];
    const std::vector<int> &hd_configuration = hd["configuration"];
    const std::vector<float> &hd_rt = hd["rt"];
    const std::vector<int> &hd_level = hd["level"];
    const std::vector<float> &hd_pre_mz = hd["pre_mz"];
    const std::vector<float> &hd_pre_mz_low = hd["pre_mzlow"];
    const std::vector<float> &hd_pre_mz_high = hd["pre_mzhigh"];
    const std::vector<float> &hd_pre_ce = hd["pre_ce"];
    const std::vector<float> &hd_mobility = hd["mobility"];
    const int number_spectra = hd_index.size();
    headers.resize_all(number_spectra);
    headers.index = hd_index;
    headers.rt = hd_rt;
    headers.polarity = hd_polarity;
    headers.configuration = hd_configuration;
    headers.level = hd_level;
    headers.precursor_mz = hd_pre_mz;
    headers.activation_ce = hd_pre_ce;
    headers.mobility = hd_mobility;
    return headers;
  }

  std::vector<mass_spec::MS_SPECTRA_HEADERS> as_spectra_headers(const Rcpp::List &spectra_headers)
  {
    std::vector<mass_spec::MS_SPECTRA_HEADERS> out;
    if (spectra_headers.size() == 0)
    {
      return out;
    }
    out.resize(spectra_headers.size());
    for (int i = 0; i < spectra_headers.size(); ++i)
    {
      const Rcpp::List &header_ref = Rcpp::as<Rcpp::List>(spectra_headers[i]);
      out[i] = as_MS_SPECTRA_HEADERS(header_ref);
    }
    return out;
  }

  nts::FEATURES features_from_list(const Rcpp::List &fts)
  {
    nts::FEATURES out;
    if (fts.size() == 0)
    {
      return out;
    }

    std::vector<std::string> must_have_names = {
        "feature", "feature_group", "feature_component", "adduct", "rt", "mz", "mass",
        "intensity", "noise", "sn", "area",
        "rtmin", "rtmax", "width",
        "mzmin", "mzmax", "ppm",
        "fwhm_rt", "fwhm_mz",
        "gaussian_A", "gaussian_mu", "gaussian_sigma", "gaussian_r2",
        "jaggedness", "sharpness", "asymmetry", "modality", "plates",
        "polarity", "filtered", "filter", "filled", "correction",
        "eic_size", "eic_rt", "eic_mz", "eic_intensity", "eic_baseline", "eic_smoothed",
        "ms1_size", "ms1_mz", "ms1_intensity",
        "ms2_size", "ms2_mz", "ms2_intensity"};

    if (!check_list_must_have_names(fts, must_have_names))
    {
      Rcpp::Rcout << "Error: FEATURES::import_from_list() - missing required names in the list." << std::endl;
      return out;
    }

    out.feature = Rcpp::as<std::vector<std::string>>(fts["feature"]);
    out.feature_group = Rcpp::as<std::vector<std::string>>(fts["feature_group"]);
    out.feature_component = Rcpp::as<std::vector<std::string>>(fts["feature_component"]);
    out.adduct = Rcpp::as<std::vector<std::string>>(fts["adduct"]);
    out.rt = Rcpp::as<std::vector<float>>(fts["rt"]);
    out.mz = Rcpp::as<std::vector<float>>(fts["mz"]);
    out.mass = Rcpp::as<std::vector<float>>(fts["mass"]);
    out.intensity = Rcpp::as<std::vector<float>>(fts["intensity"]);
    out.noise = Rcpp::as<std::vector<float>>(fts["noise"]);
    out.sn = Rcpp::as<std::vector<float>>(fts["sn"]);
    out.area = Rcpp::as<std::vector<float>>(fts["area"]);
    out.rtmin = Rcpp::as<std::vector<float>>(fts["rtmin"]);
    out.rtmax = Rcpp::as<std::vector<float>>(fts["rtmax"]);
    out.width = Rcpp::as<std::vector<float>>(fts["width"]);
    out.mzmin = Rcpp::as<std::vector<float>>(fts["mzmin"]);
    out.mzmax = Rcpp::as<std::vector<float>>(fts["mzmax"]);
    out.ppm = Rcpp::as<std::vector<float>>(fts["ppm"]);
    out.fwhm_rt = Rcpp::as<std::vector<float>>(fts["fwhm_rt"]);
    out.fwhm_mz = Rcpp::as<std::vector<float>>(fts["fwhm_mz"]);
    out.gaussian_A = Rcpp::as<std::vector<float>>(fts["gaussian_A"]);
    out.gaussian_mu = Rcpp::as<std::vector<float>>(fts["gaussian_mu"]);
    out.gaussian_sigma = Rcpp::as<std::vector<float>>(fts["gaussian_sigma"]);
    out.gaussian_r2 = Rcpp::as<std::vector<float>>(fts["gaussian_r2"]);
    out.jaggedness = Rcpp::as<std::vector<float>>(fts["jaggedness"]);
    out.sharpness = Rcpp::as<std::vector<float>>(fts["sharpness"]);
    out.asymmetry = Rcpp::as<std::vector<float>>(fts["asymmetry"]);
    out.modality = Rcpp::as<std::vector<int>>(fts["modality"]);
    out.plates = Rcpp::as<std::vector<float>>(fts["plates"]);
    out.polarity = Rcpp::as<std::vector<int>>(fts["polarity"]);
    out.filtered = Rcpp::as<std::vector<bool>>(fts["filtered"]);
    out.filter = Rcpp::as<std::vector<std::string>>(fts["filter"]);
    out.filled = Rcpp::as<std::vector<bool>>(fts["filled"]);
    out.correction = Rcpp::as<std::vector<float>>(fts["correction"]);
    out.eic_size = Rcpp::as<std::vector<int>>(fts["eic_size"]);
    out.eic_rt = Rcpp::as<std::vector<std::string>>(fts["eic_rt"]);
    out.eic_mz = Rcpp::as<std::vector<std::string>>(fts["eic_mz"]);
    out.eic_intensity = Rcpp::as<std::vector<std::string>>(fts["eic_intensity"]);
    out.eic_baseline = Rcpp::as<std::vector<std::string>>(fts["eic_baseline"]);
    out.eic_smoothed = Rcpp::as<std::vector<std::string>>(fts["eic_smoothed"]);
    out.ms1_size = Rcpp::as<std::vector<int>>(fts["ms1_size"]);
    out.ms1_mz = Rcpp::as<std::vector<std::string>>(fts["ms1_mz"]);
    out.ms1_intensity = Rcpp::as<std::vector<std::string>>(fts["ms1_intensity"]);
    out.ms2_size = Rcpp::as<std::vector<int>>(fts["ms2_size"]);
    out.ms2_mz = Rcpp::as<std::vector<std::string>>(fts["ms2_mz"]);
    out.ms2_intensity = Rcpp::as<std::vector<std::string>>(fts["ms2_intensity"]);

    const size_t n = out.feature.size();
    auto check_size = [&](const char *name, size_t sz) {
      if (sz != n)
      {
        Rcpp::stop(std::string("features_from_list: column '") + name +
                   "' length " + std::to_string(sz) +
                   " does not match feature length " + std::to_string(n));
      }
    };

    check_size("feature_group", out.feature_group.size());
    check_size("feature_component", out.feature_component.size());
    check_size("adduct", out.adduct.size());
    check_size("rt", out.rt.size());
    check_size("mz", out.mz.size());
    check_size("mass", out.mass.size());
    check_size("intensity", out.intensity.size());
    check_size("noise", out.noise.size());
    check_size("sn", out.sn.size());
    check_size("area", out.area.size());
    check_size("rtmin", out.rtmin.size());
    check_size("rtmax", out.rtmax.size());
    check_size("width", out.width.size());
    check_size("mzmin", out.mzmin.size());
    check_size("mzmax", out.mzmax.size());
    check_size("ppm", out.ppm.size());
    check_size("fwhm_rt", out.fwhm_rt.size());
    check_size("fwhm_mz", out.fwhm_mz.size());
    check_size("gaussian_A", out.gaussian_A.size());
    check_size("gaussian_mu", out.gaussian_mu.size());
    check_size("gaussian_sigma", out.gaussian_sigma.size());
    check_size("gaussian_r2", out.gaussian_r2.size());
    check_size("jaggedness", out.jaggedness.size());
    check_size("sharpness", out.sharpness.size());
    check_size("asymmetry", out.asymmetry.size());
    check_size("modality", out.modality.size());
    check_size("plates", out.plates.size());
    check_size("polarity", out.polarity.size());
    check_size("filtered", out.filtered.size());
    check_size("filter", out.filter.size());
    check_size("filled", out.filled.size());
    check_size("correction", out.correction.size());
    check_size("eic_size", out.eic_size.size());
    check_size("eic_rt", out.eic_rt.size());
    check_size("eic_mz", out.eic_mz.size());
    check_size("eic_intensity", out.eic_intensity.size());
    check_size("eic_baseline", out.eic_baseline.size());
    check_size("eic_smoothed", out.eic_smoothed.size());
    check_size("ms1_size", out.ms1_size.size());
    check_size("ms1_mz", out.ms1_mz.size());
    check_size("ms1_intensity", out.ms1_intensity.size());
    check_size("ms2_size", out.ms2_size.size());
    check_size("ms2_mz", out.ms2_mz.size());
    check_size("ms2_intensity", out.ms2_intensity.size());

    return out;
  }

  std::vector<nts::FEATURES> as_feature_list(const Rcpp::List &feature_list)
  {
    std::vector<nts::FEATURES> out;
    if (feature_list.size() == 0)
    {
      return out;
    }
    out.resize(feature_list.size());
    for (int i = 0; i < feature_list.size(); ++i)
    {
      const Rcpp::List &feature_ref = Rcpp::as<Rcpp::List>(feature_list[i]);
      out[i] = features_from_list(feature_ref);
    }
    return out;
  }

  nts::SUSPECTS suspects_from_list(const Rcpp::List &sus)
  {
    nts::SUSPECTS out;
    if (sus.size() == 0)
    {
      return out;
    }

    std::vector<std::string> must_have_names = {
        "analysis", "feature", "candidate_rank", "name", "polarity",
        "db_mass", "exp_mass", "error_mass",
        "db_rt", "exp_rt", "error_rt",
        "intensity", "area", "id_level", "score",
        "shared_fragments", "cosine_similarity",
        "formula", "SMILES", "InChI", "InChIKey", "xLogP", "database_id",
        "db_ms2_size", "db_ms2_mz", "db_ms2_intensity", "db_ms2_formula",
        "exp_ms2_size", "exp_ms2_mz", "exp_ms2_intensity"};

    if (!check_list_must_have_names(sus, must_have_names))
    {
      Rcpp::Rcout << "Error: SUSPECTS::suspects_from_list() - missing required names in the list." << std::endl;
      return out;
    }

    out.analysis = Rcpp::as<std::vector<std::string>>(sus["analysis"]);
    out.feature = Rcpp::as<std::vector<std::string>>(sus["feature"]);
    out.candidate_rank = Rcpp::as<std::vector<int>>(sus["candidate_rank"]);
    out.name = Rcpp::as<std::vector<std::string>>(sus["name"]);
    out.polarity = Rcpp::as<std::vector<int>>(sus["polarity"]);
    out.db_mass = Rcpp::as<std::vector<double>>(sus["db_mass"]);
    out.exp_mass = Rcpp::as<std::vector<double>>(sus["exp_mass"]);
    out.error_mass = Rcpp::as<std::vector<double>>(sus["error_mass"]);
    out.db_rt = Rcpp::as<std::vector<double>>(sus["db_rt"]);
    out.exp_rt = Rcpp::as<std::vector<double>>(sus["exp_rt"]);
    out.error_rt = Rcpp::as<std::vector<double>>(sus["error_rt"]);
    out.intensity = Rcpp::as<std::vector<double>>(sus["intensity"]);
    out.area = Rcpp::as<std::vector<double>>(sus["area"]);
    out.id_level = Rcpp::as<std::vector<int>>(sus["id_level"]);
    out.score = Rcpp::as<std::vector<double>>(sus["score"]);
    out.shared_fragments = Rcpp::as<std::vector<int>>(sus["shared_fragments"]);
    out.cosine_similarity = Rcpp::as<std::vector<double>>(sus["cosine_similarity"]);
    out.formula = Rcpp::as<std::vector<std::string>>(sus["formula"]);
    out.SMILES = Rcpp::as<std::vector<std::string>>(sus["SMILES"]);
    out.InChI = Rcpp::as<std::vector<std::string>>(sus["InChI"]);
    out.InChIKey = Rcpp::as<std::vector<std::string>>(sus["InChIKey"]);
    out.xLogP = Rcpp::as<std::vector<double>>(sus["xLogP"]);
    out.database_id = Rcpp::as<std::vector<std::string>>(sus["database_id"]);
    out.db_ms2_size = Rcpp::as<std::vector<int>>(sus["db_ms2_size"]);
    out.db_ms2_mz = Rcpp::as<std::vector<std::string>>(sus["db_ms2_mz"]);
    out.db_ms2_intensity = Rcpp::as<std::vector<std::string>>(sus["db_ms2_intensity"]);
    out.db_ms2_formula = Rcpp::as<std::vector<std::string>>(sus["db_ms2_formula"]);
    out.exp_ms2_size = Rcpp::as<std::vector<int>>(sus["exp_ms2_size"]);
    out.exp_ms2_mz = Rcpp::as<std::vector<std::string>>(sus["exp_ms2_mz"]);
    out.exp_ms2_intensity = Rcpp::as<std::vector<std::string>>(sus["exp_ms2_intensity"]);

    return out;
  }

  std::vector<nts::SUSPECTS> as_suspects_list(const Rcpp::List &suspects_list)
  {
    std::vector<nts::SUSPECTS> out;
    if (suspects_list.size() == 0)
    {
      return out;
    }
    out.resize(suspects_list.size());
    for (int i = 0; i < suspects_list.size(); ++i)
    {
      const Rcpp::List &suspects_ref = Rcpp::as<Rcpp::List>(suspects_list[i]);
      out[i] = suspects_from_list(suspects_ref);
    }
    return out;
  }

  nts::INTERNAL_STANDARDS internal_standards_from_list(const Rcpp::List &istd)
  {
    nts::INTERNAL_STANDARDS out;
    if (istd.size() == 0)
    {
      return out;
    }

    std::vector<std::string> must_have_names = {
        "analysis", "feature", "candidate_rank", "name", "polarity",
        "db_mass", "exp_mass", "error_mass",
        "db_rt", "exp_rt", "error_rt",
        "intensity", "area", "id_level", "score",
        "shared_fragments", "cosine_similarity",
        "formula", "SMILES", "InChI", "InChIKey", "xLogP", "database_id",
        "db_ms2_size", "db_ms2_mz", "db_ms2_intensity", "db_ms2_formula",
        "exp_ms2_size", "exp_ms2_mz", "exp_ms2_intensity"};

    if (!check_list_must_have_names(istd, must_have_names))
    {
      Rcpp::Rcout << "Error: INTERNAL_STANDARDS::internal_standards_from_list() - missing required names in the list." << std::endl;
      return out;
    }

    out.analysis = Rcpp::as<std::vector<std::string>>(istd["analysis"]);
    out.feature = Rcpp::as<std::vector<std::string>>(istd["feature"]);
    out.candidate_rank = Rcpp::as<std::vector<int>>(istd["candidate_rank"]);
    out.name = Rcpp::as<std::vector<std::string>>(istd["name"]);
    out.polarity = Rcpp::as<std::vector<int>>(istd["polarity"]);
    out.db_mass = Rcpp::as<std::vector<double>>(istd["db_mass"]);
    out.exp_mass = Rcpp::as<std::vector<double>>(istd["exp_mass"]);
    out.error_mass = Rcpp::as<std::vector<double>>(istd["error_mass"]);
    out.db_rt = Rcpp::as<std::vector<double>>(istd["db_rt"]);
    out.exp_rt = Rcpp::as<std::vector<double>>(istd["exp_rt"]);
    out.error_rt = Rcpp::as<std::vector<double>>(istd["error_rt"]);
    out.intensity = Rcpp::as<std::vector<double>>(istd["intensity"]);
    out.area = Rcpp::as<std::vector<double>>(istd["area"]);
    out.id_level = Rcpp::as<std::vector<int>>(istd["id_level"]);
    out.score = Rcpp::as<std::vector<double>>(istd["score"]);
    out.shared_fragments = Rcpp::as<std::vector<int>>(istd["shared_fragments"]);
    out.cosine_similarity = Rcpp::as<std::vector<double>>(istd["cosine_similarity"]);
    out.formula = Rcpp::as<std::vector<std::string>>(istd["formula"]);
    out.SMILES = Rcpp::as<std::vector<std::string>>(istd["SMILES"]);
    out.InChI = Rcpp::as<std::vector<std::string>>(istd["InChI"]);
    out.InChIKey = Rcpp::as<std::vector<std::string>>(istd["InChIKey"]);
    out.xLogP = Rcpp::as<std::vector<double>>(istd["xLogP"]);
    out.database_id = Rcpp::as<std::vector<std::string>>(istd["database_id"]);
    out.db_ms2_size = Rcpp::as<std::vector<int>>(istd["db_ms2_size"]);
    out.db_ms2_mz = Rcpp::as<std::vector<std::string>>(istd["db_ms2_mz"]);
    out.db_ms2_intensity = Rcpp::as<std::vector<std::string>>(istd["db_ms2_intensity"]);
    out.db_ms2_formula = Rcpp::as<std::vector<std::string>>(istd["db_ms2_formula"]);
    out.exp_ms2_size = Rcpp::as<std::vector<int>>(istd["exp_ms2_size"]);
    out.exp_ms2_mz = Rcpp::as<std::vector<std::string>>(istd["exp_ms2_mz"]);
    out.exp_ms2_intensity = Rcpp::as<std::vector<std::string>>(istd["exp_ms2_intensity"]);

    return out;
  }

  std::vector<nts::INTERNAL_STANDARDS> as_internal_standards_list(const Rcpp::List &internal_standards_list)
  {
    std::vector<nts::INTERNAL_STANDARDS> out;
    if (internal_standards_list.size() == 0)
    {
      return out;
    }
    out.resize(internal_standards_list.size());
    for (int i = 0; i < internal_standards_list.size(); ++i)
    {
      const Rcpp::List &istd_ref = Rcpp::as<Rcpp::List>(internal_standards_list[i]);
      out[i] = internal_standards_from_list(istd_ref);
    }
    return out;
  }

  Rcpp::List features_to_list_dt(const nts::FEATURES &fts)
  {
    int n = fts.feature.size();
    if (n == 0)
    {
      return get_empty_dt();
    }

    Rcpp::List out = Rcpp::List::create(
        Rcpp::Named("feature") = fts.feature,
        Rcpp::Named("feature_group") = fts.feature_group,
        Rcpp::Named("feature_component") = fts.feature_component,
        Rcpp::Named("adduct") = fts.adduct,
        Rcpp::Named("rt") = fts.rt,
        Rcpp::Named("mz") = fts.mz,
        Rcpp::Named("mass") = fts.mass,
        Rcpp::Named("intensity") = fts.intensity,
        Rcpp::Named("noise") = fts.noise,
        Rcpp::Named("sn") = fts.sn,
        Rcpp::Named("area") = fts.area,
        Rcpp::Named("rtmin") = fts.rtmin,
        Rcpp::Named("rtmax") = fts.rtmax,
        Rcpp::Named("width") = fts.width,
        Rcpp::Named("mzmin") = fts.mzmin,
        Rcpp::Named("mzmax") = fts.mzmax,
        Rcpp::Named("ppm") = fts.ppm,
        Rcpp::Named("fwhm_rt") = fts.fwhm_rt,
        Rcpp::Named("fwhm_mz") = fts.fwhm_mz,
        Rcpp::Named("gaussian_A") = fts.gaussian_A,
        Rcpp::Named("gaussian_mu") = fts.gaussian_mu,
        Rcpp::Named("gaussian_sigma") = fts.gaussian_sigma,
        Rcpp::Named("gaussian_r2") = fts.gaussian_r2,
        Rcpp::Named("jaggedness") = fts.jaggedness,
        Rcpp::Named("sharpness") = fts.sharpness,
        Rcpp::Named("asymmetry") = fts.asymmetry,
        Rcpp::Named("modality") = fts.modality,
        Rcpp::Named("plates") = fts.plates,
        Rcpp::Named("polarity") = fts.polarity,
        Rcpp::Named("filtered") = fts.filtered,
        Rcpp::Named("filter") = fts.filter,
        Rcpp::Named("filled") = fts.filled,
        Rcpp::Named("correction") = fts.correction,
        Rcpp::Named("eic_size") = fts.eic_size,
        Rcpp::Named("eic_rt") = fts.eic_rt,
        Rcpp::Named("eic_mz") = fts.eic_mz,
        Rcpp::Named("eic_intensity") = fts.eic_intensity,
        Rcpp::Named("eic_baseline") = fts.eic_baseline,
        Rcpp::Named("eic_smoothed") = fts.eic_smoothed,
        Rcpp::Named("ms1_size") = fts.ms1_size,
        Rcpp::Named("ms1_mz") = fts.ms1_mz,
        Rcpp::Named("ms1_intensity") = fts.ms1_intensity,
        Rcpp::Named("ms2_size") = fts.ms2_size,
        Rcpp::Named("ms2_mz") = fts.ms2_mz,
        Rcpp::Named("ms2_intensity") = fts.ms2_intensity);

    out.attr("class") = Rcpp::CharacterVector::create("data.table", "data.frame");
    return out;
  }

  Rcpp::List nts_feature_rows_to_dt(const std::vector<nts::NTS_FEATURE_ROW> &rows)
  {
    const std::size_t n = rows.size();
    if (n == 0)
    {
      return get_empty_dt();
    }

    Rcpp::CharacterVector project_id(n);
    Rcpp::CharacterVector analysis(n);
    Rcpp::CharacterVector feature(n);
    Rcpp::CharacterVector feature_component(n);
    Rcpp::CharacterVector feature_group(n);
    Rcpp::CharacterVector adduct(n);
    Rcpp::NumericVector rt(n);
    Rcpp::NumericVector mz(n);
    Rcpp::NumericVector mass(n);
    Rcpp::NumericVector intensity(n);
    Rcpp::NumericVector noise(n);
    Rcpp::NumericVector sn(n);
    Rcpp::NumericVector area(n);
    Rcpp::NumericVector rtmin(n);
    Rcpp::NumericVector rtmax(n);
    Rcpp::NumericVector width(n);
    Rcpp::NumericVector mzmin(n);
    Rcpp::NumericVector mzmax(n);
    Rcpp::NumericVector ppm(n);
    Rcpp::NumericVector fwhm_rt(n);
    Rcpp::NumericVector fwhm_mz(n);
    Rcpp::NumericVector gaussian_A(n);
    Rcpp::NumericVector gaussian_mu(n);
    Rcpp::NumericVector gaussian_sigma(n);
    Rcpp::NumericVector gaussian_r2(n);
    Rcpp::NumericVector jaggedness(n);
    Rcpp::NumericVector sharpness(n);
    Rcpp::NumericVector asymmetry(n);
    Rcpp::IntegerVector modality(n);
    Rcpp::NumericVector plates(n);
    Rcpp::IntegerVector polarity(n);
    Rcpp::LogicalVector filtered(n);
    Rcpp::CharacterVector filter(n);
    Rcpp::LogicalVector filled(n);
    Rcpp::NumericVector correction(n);
    Rcpp::IntegerVector eic_size(n);
    Rcpp::CharacterVector eic_rt(n);
    Rcpp::CharacterVector eic_mz(n);
    Rcpp::CharacterVector eic_intensity(n);
    Rcpp::CharacterVector eic_baseline(n);
    Rcpp::CharacterVector eic_smoothed(n);
    Rcpp::IntegerVector ms1_size(n);
    Rcpp::CharacterVector ms1_mz(n);
    Rcpp::CharacterVector ms1_intensity(n);
    Rcpp::IntegerVector ms2_size(n);
    Rcpp::CharacterVector ms2_mz(n);
    Rcpp::CharacterVector ms2_intensity(n);
    Rcpp::CharacterVector created_at(n);

    for (std::size_t i = 0; i < n; ++i)
    {
      const auto &row = rows[i];
      project_id[i] = row.project_id;
      analysis[i] = row.analysis;
      feature[i] = row.feature;
      feature_component[i] = row.feature_component.empty() ? NA_STRING : Rcpp::String(row.feature_component);
      feature_group[i] = row.feature_group.empty() ? NA_STRING : Rcpp::String(row.feature_group);
      adduct[i] = row.adduct.empty() ? NA_STRING : Rcpp::String(row.adduct);
      rt[i] = row.rt;
      mz[i] = row.mz;
      mass[i] = row.mass;
      intensity[i] = row.intensity;
      noise[i] = row.noise;
      sn[i] = row.sn;
      area[i] = row.area;
      rtmin[i] = row.rtmin;
      rtmax[i] = row.rtmax;
      width[i] = row.width;
      mzmin[i] = row.mzmin;
      mzmax[i] = row.mzmax;
      ppm[i] = row.ppm;
      fwhm_rt[i] = row.fwhm_rt;
      fwhm_mz[i] = row.fwhm_mz;
      gaussian_A[i] = row.gaussian_A;
      gaussian_mu[i] = row.gaussian_mu;
      gaussian_sigma[i] = row.gaussian_sigma;
      gaussian_r2[i] = row.gaussian_r2;
      jaggedness[i] = row.jaggedness;
      sharpness[i] = row.sharpness;
      asymmetry[i] = row.asymmetry;
      modality[i] = row.modality;
      plates[i] = row.plates;
      polarity[i] = row.polarity;
      filtered[i] = row.filtered;
      filter[i] = row.filter.empty() ? NA_STRING : Rcpp::String(row.filter);
      filled[i] = row.filled;
      correction[i] = row.correction;
      eic_size[i] = row.eic_size;
      eic_rt[i] = row.eic_rt.empty() ? NA_STRING : Rcpp::String(row.eic_rt);
      eic_mz[i] = row.eic_mz.empty() ? NA_STRING : Rcpp::String(row.eic_mz);
      eic_intensity[i] = row.eic_intensity.empty() ? NA_STRING : Rcpp::String(row.eic_intensity);
      eic_baseline[i] = row.eic_baseline.empty() ? NA_STRING : Rcpp::String(row.eic_baseline);
      eic_smoothed[i] = row.eic_smoothed.empty() ? NA_STRING : Rcpp::String(row.eic_smoothed);
      ms1_size[i] = row.ms1_size;
      ms1_mz[i] = row.ms1_mz.empty() ? NA_STRING : Rcpp::String(row.ms1_mz);
      ms1_intensity[i] = row.ms1_intensity.empty() ? NA_STRING : Rcpp::String(row.ms1_intensity);
      ms2_size[i] = row.ms2_size;
      ms2_mz[i] = row.ms2_mz.empty() ? NA_STRING : Rcpp::String(row.ms2_mz);
      ms2_intensity[i] = row.ms2_intensity.empty() ? NA_STRING : Rcpp::String(row.ms2_intensity);
      created_at[i] = row.created_at.empty() ? NA_STRING : Rcpp::String(row.created_at);
    }

    Rcpp::List out = Rcpp::List::create(
        Rcpp::Named("project_id") = project_id,
        Rcpp::Named("analysis") = analysis,
        Rcpp::Named("feature") = feature,
        Rcpp::Named("feature_component") = feature_component,
        Rcpp::Named("feature_group") = feature_group,
        Rcpp::Named("adduct") = adduct,
        Rcpp::Named("rt") = rt,
        Rcpp::Named("mz") = mz,
        Rcpp::Named("mass") = mass,
        Rcpp::Named("intensity") = intensity,
        Rcpp::Named("noise") = noise,
        Rcpp::Named("sn") = sn,
        Rcpp::Named("area") = area,
        Rcpp::Named("rtmin") = rtmin,
        Rcpp::Named("rtmax") = rtmax,
        Rcpp::Named("width") = width,
        Rcpp::Named("mzmin") = mzmin,
        Rcpp::Named("mzmax") = mzmax,
        Rcpp::Named("ppm") = ppm,
        Rcpp::Named("fwhm_rt") = fwhm_rt,
        Rcpp::Named("fwhm_mz") = fwhm_mz,
        Rcpp::Named("gaussian_A") = gaussian_A,
        Rcpp::Named("gaussian_mu") = gaussian_mu,
        Rcpp::Named("gaussian_sigma") = gaussian_sigma,
        Rcpp::Named("gaussian_r2") = gaussian_r2,
        Rcpp::Named("jaggedness") = jaggedness,
        Rcpp::Named("sharpness") = sharpness,
        Rcpp::Named("asymmetry") = asymmetry,
        Rcpp::Named("modality") = modality,
        Rcpp::Named("plates") = plates,
        Rcpp::Named("polarity") = polarity,
        Rcpp::Named("filtered") = filtered,
        Rcpp::Named("filter") = filter,
        Rcpp::Named("filled") = filled,
        Rcpp::Named("correction") = correction,
        Rcpp::Named("eic_size") = eic_size,
        Rcpp::Named("eic_rt") = eic_rt,
        Rcpp::Named("eic_mz") = eic_mz,
        Rcpp::Named("eic_intensity") = eic_intensity,
        Rcpp::Named("eic_baseline") = eic_baseline,
        Rcpp::Named("eic_smoothed") = eic_smoothed,
        Rcpp::Named("ms1_size") = ms1_size,
        Rcpp::Named("ms1_mz") = ms1_mz,
        Rcpp::Named("ms1_intensity") = ms1_intensity,
        Rcpp::Named("ms2_size") = ms2_size,
        Rcpp::Named("ms2_mz") = ms2_mz,
        Rcpp::Named("ms2_intensity") = ms2_intensity,
        Rcpp::Named("created_at") = created_at);
    out.attr("class") = Rcpp::CharacterVector::create("data.table", "data.frame");
    return out;
  }

  Rcpp::List nts_feature_count_rows_to_dt(const std::vector<nts::NTS_FEATURE_COUNT_ROW> &rows)
  {
    const std::size_t n = rows.size();
    if (n == 0)
    {
      return get_empty_dt();
    }
    Rcpp::CharacterVector analysis(n);
    Rcpp::IntegerVector total(n);
    Rcpp::IntegerVector filtered(n);
    Rcpp::IntegerVector groups(n);
    Rcpp::IntegerVector components(n);
    for (std::size_t i = 0; i < n; ++i)
    {
      analysis[i] = rows[i].analysis;
      total[i] = rows[i].total;
      filtered[i] = rows[i].filtered;
      groups[i] = rows[i].groups;
      components[i] = rows[i].components;
    }
    Rcpp::List out = Rcpp::List::create(Rcpp::Named("analysis") = analysis,
                                        Rcpp::Named("total") = total,
                                        Rcpp::Named("filtered") = filtered,
                                        Rcpp::Named("groups") = groups,
                                        Rcpp::Named("components") = components);
    out.attr("class") = Rcpp::CharacterVector::create("data.table", "data.frame");
    return out;
  }

  Rcpp::List nts_suspect_rows_to_dt(const std::vector<nts::NTS_SUSPECT_ROW> &rows)
  {
    const std::size_t n = rows.size();
    if (n == 0)
    {
      return get_empty_dt();
    }
    Rcpp::CharacterVector project_id(n), analysis(n), feature(n), name(n), formula(n), smiles(n), inchi(n), inchikey(n), database_id(n), db_ms2_mz(n), db_ms2_intensity(n), db_ms2_formula(n), exp_ms2_mz(n), exp_ms2_intensity(n), created_at(n);
    Rcpp::IntegerVector candidate_rank(n), polarity(n), id_level(n), shared_fragments(n), db_ms2_size(n), exp_ms2_size(n);
    Rcpp::NumericVector db_mass(n), exp_mass(n), error_mass(n), db_rt(n), exp_rt(n), error_rt(n), intensity(n), area(n), score(n), cosine_similarity(n), xLogP(n);
    for (std::size_t i = 0; i < n; ++i)
    {
      const auto &row = rows[i];
      project_id[i] = row.project_id;
      analysis[i] = row.analysis;
      feature[i] = row.feature;
      candidate_rank[i] = row.candidate_rank;
      name[i] = row.name;
      polarity[i] = row.polarity;
      db_mass[i] = row.db_mass;
      exp_mass[i] = row.exp_mass;
      error_mass[i] = row.error_mass;
      db_rt[i] = row.db_rt;
      exp_rt[i] = row.exp_rt;
      error_rt[i] = row.error_rt;
      intensity[i] = row.intensity;
      area[i] = row.area;
      id_level[i] = row.id_level;
      score[i] = row.score;
      shared_fragments[i] = row.shared_fragments;
      cosine_similarity[i] = row.cosine_similarity;
      formula[i] = row.formula.empty() ? NA_STRING : Rcpp::String(row.formula);
      smiles[i] = row.SMILES.empty() ? NA_STRING : Rcpp::String(row.SMILES);
      inchi[i] = row.InChI.empty() ? NA_STRING : Rcpp::String(row.InChI);
      inchikey[i] = row.InChIKey.empty() ? NA_STRING : Rcpp::String(row.InChIKey);
      xLogP[i] = row.xLogP;
      database_id[i] = row.database_id.empty() ? NA_STRING : Rcpp::String(row.database_id);
      db_ms2_size[i] = row.db_ms2_size;
      db_ms2_mz[i] = row.db_ms2_mz.empty() ? NA_STRING : Rcpp::String(row.db_ms2_mz);
      db_ms2_intensity[i] = row.db_ms2_intensity.empty() ? NA_STRING : Rcpp::String(row.db_ms2_intensity);
      db_ms2_formula[i] = row.db_ms2_formula.empty() ? NA_STRING : Rcpp::String(row.db_ms2_formula);
      exp_ms2_size[i] = row.exp_ms2_size;
      exp_ms2_mz[i] = row.exp_ms2_mz.empty() ? NA_STRING : Rcpp::String(row.exp_ms2_mz);
      exp_ms2_intensity[i] = row.exp_ms2_intensity.empty() ? NA_STRING : Rcpp::String(row.exp_ms2_intensity);
      created_at[i] = row.created_at.empty() ? NA_STRING : Rcpp::String(row.created_at);
    }
    Rcpp::List out = Rcpp::List::create(
        Rcpp::Named("project_id") = project_id,
        Rcpp::Named("analysis") = analysis,
        Rcpp::Named("feature") = feature,
        Rcpp::Named("candidate_rank") = candidate_rank,
        Rcpp::Named("name") = name,
        Rcpp::Named("polarity") = polarity,
        Rcpp::Named("db_mass") = db_mass,
        Rcpp::Named("exp_mass") = exp_mass,
        Rcpp::Named("error_mass") = error_mass,
        Rcpp::Named("db_rt") = db_rt,
        Rcpp::Named("exp_rt") = exp_rt,
        Rcpp::Named("error_rt") = error_rt,
        Rcpp::Named("intensity") = intensity,
        Rcpp::Named("area") = area,
        Rcpp::Named("id_level") = id_level,
        Rcpp::Named("score") = score,
        Rcpp::Named("shared_fragments") = shared_fragments,
        Rcpp::Named("cosine_similarity") = cosine_similarity,
        Rcpp::Named("formula") = formula,
        Rcpp::Named("SMILES") = smiles,
        Rcpp::Named("InChI") = inchi,
        Rcpp::Named("InChIKey") = inchikey,
        Rcpp::Named("xLogP") = xLogP,
        Rcpp::Named("database_id") = database_id,
        Rcpp::Named("db_ms2_size") = db_ms2_size,
        Rcpp::Named("db_ms2_mz") = db_ms2_mz,
        Rcpp::Named("db_ms2_intensity") = db_ms2_intensity,
        Rcpp::Named("db_ms2_formula") = db_ms2_formula,
        Rcpp::Named("exp_ms2_size") = exp_ms2_size,
        Rcpp::Named("exp_ms2_mz") = exp_ms2_mz,
        Rcpp::Named("exp_ms2_intensity") = exp_ms2_intensity,
        Rcpp::Named("created_at") = created_at);
    out.attr("class") = Rcpp::CharacterVector::create("data.table", "data.frame");
    return out;
  }

  Rcpp::List nts_internal_standard_rows_to_dt(const std::vector<nts::NTS_INTERNAL_STANDARD_ROW> &rows)
  {
    if (rows.empty())
    {
      return get_empty_dt();
    }
    std::vector<nts::NTS_SUSPECT_ROW> suspect_rows;
    suspect_rows.reserve(rows.size());
    for (const auto &row : rows)
    {
      nts::NTS_SUSPECT_ROW value;
      value.project_id = row.project_id;
      value.analysis = row.analysis;
      value.feature = row.feature;
      value.candidate_rank = row.candidate_rank;
      value.name = row.name;
      value.polarity = row.polarity;
      value.db_mass = row.db_mass;
      value.exp_mass = row.exp_mass;
      value.error_mass = row.error_mass;
      value.db_rt = row.db_rt;
      value.exp_rt = row.exp_rt;
      value.error_rt = row.error_rt;
      value.intensity = row.intensity;
      value.area = row.area;
      value.id_level = row.id_level;
      value.score = row.score;
      value.shared_fragments = row.shared_fragments;
      value.cosine_similarity = row.cosine_similarity;
      value.formula = row.formula;
      value.SMILES = row.SMILES;
      value.InChI = row.InChI;
      value.InChIKey = row.InChIKey;
      value.xLogP = row.xLogP;
      value.database_id = row.database_id;
      value.db_ms2_size = row.db_ms2_size;
      value.db_ms2_mz = row.db_ms2_mz;
      value.db_ms2_intensity = row.db_ms2_intensity;
      value.db_ms2_formula = row.db_ms2_formula;
      value.exp_ms2_size = row.exp_ms2_size;
      value.exp_ms2_mz = row.exp_ms2_mz;
      value.exp_ms2_intensity = row.exp_ms2_intensity;
      value.created_at = row.created_at;
      suspect_rows.push_back(value);
    }
    return nts_suspect_rows_to_dt(suspect_rows);
  }

  Rcpp::List nts_transformation_product_rows_to_dt(const std::vector<nts::NTS_TRANSFORMATION_PRODUCT_ROW> &rows)
  {
    const std::size_t n = rows.size();
    if (n == 0)
    {
      return get_empty_dt();
    }
    Rcpp::CharacterVector project_id(n), name(n), formula(n), smiles(n), inchi(n), inchikey(n), transformation(n), precursor_name(n), precursor_formula(n), precursor_smiles(n), precursor_inchi(n), precursor_inchikey(n), main_precursor_name(n), main_precursor_formula(n), main_precursor_smiles(n), main_precursor_inchi(n), main_precursor_inchikey(n), feature_group(n), precursor_feature_group(n), main_precursor_feature_group(n), created_at(n);
    Rcpp::NumericVector mass(n), xLogP(n), precursor_mass(n), precursor_xLogP(n), main_precursor_mass(n), main_precursor_xLogP(n), cosine_similarity(n), main_precursor_cosine_similarity(n), rt_plausibility(n), main_precursor_rt_plausibility(n);
    for (std::size_t i = 0; i < n; ++i)
    {
      const auto &row = rows[i];
      project_id[i] = row.project_id;
      name[i] = row.name.empty() ? NA_STRING : Rcpp::String(row.name);
      formula[i] = row.formula.empty() ? NA_STRING : Rcpp::String(row.formula);
      mass[i] = row.mass;
      smiles[i] = row.SMILES.empty() ? NA_STRING : Rcpp::String(row.SMILES);
      inchi[i] = row.InChI.empty() ? NA_STRING : Rcpp::String(row.InChI);
      inchikey[i] = row.InChIKey.empty() ? NA_STRING : Rcpp::String(row.InChIKey);
      xLogP[i] = row.xLogP;
      transformation[i] = row.transformation.empty() ? NA_STRING : Rcpp::String(row.transformation);
      precursor_name[i] = row.precursor_name.empty() ? NA_STRING : Rcpp::String(row.precursor_name);
      precursor_formula[i] = row.precursor_formula.empty() ? NA_STRING : Rcpp::String(row.precursor_formula);
      precursor_mass[i] = row.precursor_mass;
      precursor_smiles[i] = row.precursor_SMILES.empty() ? NA_STRING : Rcpp::String(row.precursor_SMILES);
      precursor_inchi[i] = row.precursor_InChI.empty() ? NA_STRING : Rcpp::String(row.precursor_InChI);
      precursor_inchikey[i] = row.precursor_InChIKey.empty() ? NA_STRING : Rcpp::String(row.precursor_InChIKey);
      precursor_xLogP[i] = row.precursor_xLogP;
      main_precursor_name[i] = row.main_precursor_name.empty() ? NA_STRING : Rcpp::String(row.main_precursor_name);
      main_precursor_formula[i] = row.main_precursor_formula.empty() ? NA_STRING : Rcpp::String(row.main_precursor_formula);
      main_precursor_mass[i] = row.main_precursor_mass;
      main_precursor_smiles[i] = row.main_precursor_SMILES.empty() ? NA_STRING : Rcpp::String(row.main_precursor_SMILES);
      main_precursor_inchi[i] = row.main_precursor_InChI.empty() ? NA_STRING : Rcpp::String(row.main_precursor_InChI);
      main_precursor_inchikey[i] = row.main_precursor_InChIKey.empty() ? NA_STRING : Rcpp::String(row.main_precursor_InChIKey);
      main_precursor_xLogP[i] = row.main_precursor_xLogP;
      feature_group[i] = row.feature_group.empty() ? NA_STRING : Rcpp::String(row.feature_group);
      precursor_feature_group[i] = row.precursor_feature_group.empty() ? NA_STRING : Rcpp::String(row.precursor_feature_group);
      main_precursor_feature_group[i] = row.main_precursor_feature_group.empty() ? NA_STRING : Rcpp::String(row.main_precursor_feature_group);
      cosine_similarity[i] = row.cosine_similarity;
      main_precursor_cosine_similarity[i] = row.main_precursor_cosine_similarity;
      rt_plausibility[i] = row.rt_plausibility;
      main_precursor_rt_plausibility[i] = row.main_precursor_rt_plausibility;
      created_at[i] = row.created_at.empty() ? NA_STRING : Rcpp::String(row.created_at);
    }
    Rcpp::List out = Rcpp::List::create(
        Rcpp::Named("project_id") = project_id,
        Rcpp::Named("name") = name,
        Rcpp::Named("formula") = formula,
        Rcpp::Named("mass") = mass,
        Rcpp::Named("SMILES") = smiles,
        Rcpp::Named("InChI") = inchi,
        Rcpp::Named("InChIKey") = inchikey,
        Rcpp::Named("xLogP") = xLogP,
        Rcpp::Named("transformation") = transformation,
        Rcpp::Named("precursor_name") = precursor_name,
        Rcpp::Named("precursor_formula") = precursor_formula,
        Rcpp::Named("precursor_mass") = precursor_mass,
        Rcpp::Named("precursor_SMILES") = precursor_smiles,
        Rcpp::Named("precursor_InChI") = precursor_inchi,
        Rcpp::Named("precursor_InChIKey") = precursor_inchikey,
        Rcpp::Named("precursor_xLogP") = precursor_xLogP,
        Rcpp::Named("main_precursor_name") = main_precursor_name,
        Rcpp::Named("main_precursor_formula") = main_precursor_formula,
        Rcpp::Named("main_precursor_mass") = main_precursor_mass,
        Rcpp::Named("main_precursor_SMILES") = main_precursor_smiles,
        Rcpp::Named("main_precursor_InChI") = main_precursor_inchi,
        Rcpp::Named("main_precursor_InChIKey") = main_precursor_inchikey,
        Rcpp::Named("main_precursor_xLogP") = main_precursor_xLogP,
        Rcpp::Named("feature_group") = feature_group,
        Rcpp::Named("precursor_feature_group") = precursor_feature_group,
        Rcpp::Named("main_precursor_feature_group") = main_precursor_feature_group,
        Rcpp::Named("cosine_similarity") = cosine_similarity,
        Rcpp::Named("main_precursor_cosine_similarity") = main_precursor_cosine_similarity,
        Rcpp::Named("rt_plausibility") = rt_plausibility,
        Rcpp::Named("main_precursor_rt_plausibility") = main_precursor_rt_plausibility,
        Rcpp::Named("created_at") = created_at);
    out.attr("class") = Rcpp::CharacterVector::create("data.table", "data.frame");
    return out;
  }

  Rcpp::List features_as_list_of_dt(const nts::NTS_DATA &nts_data)
  {
    const int n = nts_data.features.size();
    Rcpp::List out(n);
    if (n == 0)
    {
      return out;
    }
    for (int i = 0; i < n; i++)
    {
      out[i] = features_to_list_dt(nts_data.features[i]);
    }
    Rcpp::CharacterVector names(n);
    for (int i = 0; i < n; i++)
    {
      names[i] = nts_data.analyses[i];
    }
    out.attr("names") = names;
    return out;
  }

  Rcpp::List suspects_to_list_dt(const nts::SUSPECTS &sus)
  {
    int n = sus.analysis.size();
    if (n == 0)
    {
      return get_empty_dt();
    }

    Rcpp::List out = Rcpp::List::create(
        Rcpp::Named("analysis") = as_char_vector(sus.analysis),
        Rcpp::Named("feature") = as_char_vector(sus.feature),
        Rcpp::Named("candidate_rank") = sus.candidate_rank,
        Rcpp::Named("name") = as_char_vector(sus.name),
        Rcpp::Named("polarity") = sus.polarity,
        Rcpp::Named("db_mass") = as_numeric_vector(sus.db_mass),
        Rcpp::Named("exp_mass") = as_numeric_vector(sus.exp_mass),
        Rcpp::Named("error_mass") = as_numeric_vector(sus.error_mass),
        Rcpp::Named("db_rt") = as_numeric_vector(sus.db_rt),
        Rcpp::Named("exp_rt") = as_numeric_vector(sus.exp_rt),
        Rcpp::Named("error_rt") = as_numeric_vector(sus.error_rt),
        Rcpp::Named("intensity") = as_numeric_vector(sus.intensity),
        Rcpp::Named("area") = as_numeric_vector(sus.area),
        Rcpp::Named("id_level") = sus.id_level,
        Rcpp::Named("score") = as_numeric_vector(sus.score),
        Rcpp::Named("shared_fragments") = sus.shared_fragments,
        Rcpp::Named("cosine_similarity") = as_numeric_vector(sus.cosine_similarity),
        Rcpp::Named("formula") = as_char_vector(sus.formula),
        Rcpp::Named("SMILES") = as_char_vector(sus.SMILES),
        Rcpp::Named("InChI") = as_char_vector(sus.InChI),
        Rcpp::Named("InChIKey") = as_char_vector(sus.InChIKey),
        Rcpp::Named("xLogP") = as_numeric_vector(sus.xLogP),
        Rcpp::Named("database_id") = as_char_vector(sus.database_id),
        Rcpp::Named("db_ms2_size") = sus.db_ms2_size,
        Rcpp::Named("db_ms2_mz") = as_char_vector(sus.db_ms2_mz),
        Rcpp::Named("db_ms2_intensity") = as_char_vector(sus.db_ms2_intensity),
        Rcpp::Named("db_ms2_formula") = as_char_vector(sus.db_ms2_formula),
        Rcpp::Named("exp_ms2_size") = sus.exp_ms2_size,
        Rcpp::Named("exp_ms2_mz") = as_char_vector(sus.exp_ms2_mz),
        Rcpp::Named("exp_ms2_intensity") = as_char_vector(sus.exp_ms2_intensity));

    out.attr("class") = Rcpp::CharacterVector::create("data.table", "data.frame");
    return out;
  }

  Rcpp::List suspects_as_list_of_dt(const nts::NTS_DATA &nts_data)
  {
    const int n = nts_data.suspects.size();
    Rcpp::List out(n);
    if (n == 0)
    {
      return out;
    }
    for (int i = 0; i < n; i++)
    {
      out[i] = suspects_to_list_dt(nts_data.suspects[i]);
    }
    Rcpp::CharacterVector names(n);
    for (int i = 0; i < n; i++)
    {
      names[i] = nts_data.analyses[i];
    }
    out.attr("names") = names;
    return out;
  }

  Rcpp::List internal_standards_to_list_dt(const nts::INTERNAL_STANDARDS &istd)
  {
    int n = istd.analysis.size();
    if (n == 0)
    {
      return get_empty_dt();
    }

    Rcpp::List out = Rcpp::List::create(
        Rcpp::Named("analysis") = as_char_vector(istd.analysis),
        Rcpp::Named("feature") = as_char_vector(istd.feature),
        Rcpp::Named("candidate_rank") = istd.candidate_rank,
        Rcpp::Named("name") = as_char_vector(istd.name),
        Rcpp::Named("polarity") = istd.polarity,
        Rcpp::Named("db_mass") = as_numeric_vector(istd.db_mass),
        Rcpp::Named("exp_mass") = as_numeric_vector(istd.exp_mass),
        Rcpp::Named("error_mass") = as_numeric_vector(istd.error_mass),
        Rcpp::Named("db_rt") = as_numeric_vector(istd.db_rt),
        Rcpp::Named("exp_rt") = as_numeric_vector(istd.exp_rt),
        Rcpp::Named("error_rt") = as_numeric_vector(istd.error_rt),
        Rcpp::Named("intensity") = as_numeric_vector(istd.intensity),
        Rcpp::Named("area") = as_numeric_vector(istd.area),
        Rcpp::Named("id_level") = istd.id_level,
        Rcpp::Named("score") = as_numeric_vector(istd.score),
        Rcpp::Named("shared_fragments") = istd.shared_fragments,
        Rcpp::Named("cosine_similarity") = as_numeric_vector(istd.cosine_similarity),
        Rcpp::Named("formula") = as_char_vector(istd.formula),
        Rcpp::Named("SMILES") = as_char_vector(istd.SMILES),
        Rcpp::Named("InChI") = as_char_vector(istd.InChI),
        Rcpp::Named("InChIKey") = as_char_vector(istd.InChIKey),
        Rcpp::Named("xLogP") = as_numeric_vector(istd.xLogP),
        Rcpp::Named("database_id") = as_char_vector(istd.database_id),
        Rcpp::Named("db_ms2_size") = istd.db_ms2_size,
        Rcpp::Named("db_ms2_mz") = as_char_vector(istd.db_ms2_mz),
        Rcpp::Named("db_ms2_intensity") = as_char_vector(istd.db_ms2_intensity),
        Rcpp::Named("db_ms2_formula") = as_char_vector(istd.db_ms2_formula),
        Rcpp::Named("exp_ms2_size") = istd.exp_ms2_size,
        Rcpp::Named("exp_ms2_mz") = as_char_vector(istd.exp_ms2_mz),
        Rcpp::Named("exp_ms2_intensity") = as_char_vector(istd.exp_ms2_intensity));

    out.attr("class") = Rcpp::CharacterVector::create("data.table", "data.frame");
    return out;
  }

  Rcpp::List internal_standards_as_list_of_dt(const nts::NTS_DATA &nts_data)
  {
    const int n = nts_data.internal_standards.size();
    Rcpp::List out(n);
    if (n == 0)
    {
      return out;
    }
    for (int i = 0; i < n; i++)
    {
      out[i] = internal_standards_to_list_dt(nts_data.internal_standards[i]);
    }
    Rcpp::CharacterVector names(n);
    for (int i = 0; i < n; i++)
    {
      names[i] = nts_data.analyses[i];
    }
    out.attr("names") = names;
    return out;
  }

  std::vector<nts::suspect_screening::SuspectQuery> as_suspect_queries(const Rcpp::List &suspects_list)
  {
    std::vector<nts::suspect_screening::SuspectQuery> out;
    if (suspects_list.size() == 0)
      return out;

    Rcpp::DataFrame df(suspects_list);
    const int n = df.nrows();
    if (n == 0)
      return out;

    auto has_col = [&](const std::string &name) -> bool {
      return df.containsElementNamed(name.c_str());
    };

    const bool has_mass = has_col("mass") || has_col("neutralMass");

    Rcpp::CharacterVector name_col = has_col("name") ? df["name"] : Rcpp::CharacterVector(n, "");
    Rcpp::NumericVector mass_col = has_col("mass") ? df["mass"] : (has_col("neutralMass") ? df["neutralMass"] : Rcpp::NumericVector(n, NA_REAL));
    Rcpp::NumericVector rt_col = has_col("rt") ? df["rt"] : Rcpp::NumericVector(n, NA_REAL);
    Rcpp::CharacterVector formula_col = has_col("formula") ? df["formula"] : Rcpp::CharacterVector(n, "");
    Rcpp::CharacterVector smiles_col = has_col("SMILES") ? df["SMILES"] : Rcpp::CharacterVector(n, "");
    Rcpp::CharacterVector inchi_col = has_col("InChI") ? df["InChI"] : Rcpp::CharacterVector(n, "");
    Rcpp::CharacterVector inchikey_col = has_col("InChIKey") ? df["InChIKey"] : Rcpp::CharacterVector(n, "");
    Rcpp::NumericVector score_col = has_col("score") ? df["score"] : Rcpp::NumericVector(n, NA_REAL);

    auto get_xlogp = [&](int i, bool &has_val) -> double {
      std::vector<std::string> cols = {"xLogP", "XLogP", "xlogp", "logp", "LogP"};
      for (const auto &col : cols)
      {
        if (has_col(col))
        {
          Rcpp::NumericVector v = df[col];
          if (!Rcpp::NumericVector::is_na(v[i]))
          {
            has_val = true;
            return v[i];
          }
        }
      }
      has_val = false;
      return 0.0;
    };

    auto get_database_id = [&](int i) -> std::string {
      std::vector<std::string> cols = {"database_id", "id", "ID"};
      for (const auto &col : cols)
      {
        if (has_col(col))
        {
          Rcpp::CharacterVector v = df[col];
          if (!Rcpp::CharacterVector::is_na(v[i]))
          {
            std::string val = Rcpp::as<std::string>(v[i]);
            if (!val.empty())
              return val;
          }
        }
      }
      return "";
    };

    Rcpp::CharacterVector fragments_col = has_col("fragments") ? df["fragments"] : Rcpp::CharacterVector(n, "");
    Rcpp::CharacterVector fragments_mz_col = has_col("fragments_mz") ? df["fragments_mz"] : Rcpp::CharacterVector(n, "");
    Rcpp::CharacterVector fragments_int_col = has_col("fragments_int") ? df["fragments_int"] : Rcpp::CharacterVector(n, "");
    Rcpp::CharacterVector ms2_pos_col = has_col("ms2_positive") ? df["ms2_positive"] : Rcpp::CharacterVector(n, "");
    Rcpp::CharacterVector ms2_neg_col = has_col("ms2_negative") ? df["ms2_negative"] : Rcpp::CharacterVector(n, "");
    Rcpp::CharacterVector ms2_col = has_col("ms2") ? df["ms2"] : Rcpp::CharacterVector(n, "");

    out.reserve(n);
    for (int i = 0; i < n; ++i)
    {
      nts::suspect_screening::SuspectQuery s;
      if (!Rcpp::CharacterVector::is_na(name_col[i]))
        s.name = Rcpp::as<std::string>(name_col[i]);

      if (has_mass && !Rcpp::NumericVector::is_na(mass_col[i]))
      {
        s.has_mass = true;
        s.mass = mass_col[i];
      }
      if (!Rcpp::NumericVector::is_na(rt_col[i]))
        s.rt = rt_col[i];

      if (!Rcpp::CharacterVector::is_na(formula_col[i]))
        s.formula = Rcpp::as<std::string>(formula_col[i]);
      if (!Rcpp::CharacterVector::is_na(smiles_col[i]))
        s.SMILES = Rcpp::as<std::string>(smiles_col[i]);
      if (!Rcpp::CharacterVector::is_na(inchi_col[i]))
        s.InChI = Rcpp::as<std::string>(inchi_col[i]);
      if (!Rcpp::CharacterVector::is_na(inchikey_col[i]))
        s.InChIKey = Rcpp::as<std::string>(inchikey_col[i]);

      if (!Rcpp::NumericVector::is_na(score_col[i]))
        s.score = score_col[i];

      bool has_xlogp = false;
      double xlogp = get_xlogp(i, has_xlogp);
      s.has_xLogP = has_xlogp;
      s.xLogP = xlogp;

      s.database_id = get_database_id(i);

      std::string fragments = (!Rcpp::CharacterVector::is_na(fragments_col[i])) ? Rcpp::as<std::string>(fragments_col[i]) : "";
      std::string fragments_mz = (!Rcpp::CharacterVector::is_na(fragments_mz_col[i])) ? Rcpp::as<std::string>(fragments_mz_col[i]) : "";
      std::string fragments_int = (!Rcpp::CharacterVector::is_na(fragments_int_col[i])) ? Rcpp::as<std::string>(fragments_int_col[i]) : "";
      std::string ms2_pos = (!Rcpp::CharacterVector::is_na(ms2_pos_col[i])) ? Rcpp::as<std::string>(ms2_pos_col[i]) : "";
      std::string ms2_neg = (!Rcpp::CharacterVector::is_na(ms2_neg_col[i])) ? Rcpp::as<std::string>(ms2_neg_col[i]) : "";
      std::string ms2 = (!Rcpp::CharacterVector::is_na(ms2_col[i])) ? Rcpp::as<std::string>(ms2_col[i]) : "";

      auto parse_ms2_pairs = [&](const std::string &src, std::vector<double> &mz_out, std::vector<double> &int_out) {
        if (src.empty())
          return;
        std::vector<std::string> parts = split_string(src, ';');
        for (auto &part : parts)
        {
          std::string token = trim_copy(part);
          if (token.empty())
            continue;
          std::vector<std::string> comps = split_string(token, ' ');
          if (comps.size() < 2)
            continue;
          double mz = std::atof(comps[0].c_str());
          double inten = std::atof(comps[1].c_str());
          mz_out.push_back(mz);
          int_out.push_back(inten);
        }
      };

      if (!ms2_pos.empty())
      {
        parse_ms2_pairs(ms2_pos, s.fragments_mz_pos, s.fragments_intensity_pos);
      }
      if (!ms2_neg.empty())
      {
        parse_ms2_pairs(ms2_neg, s.fragments_mz_neg, s.fragments_intensity_neg);
      }

      if (ms2_pos.empty() && ms2_neg.empty())
      {
        if (!ms2.empty())
        {
          parse_ms2_pairs(ms2, s.fragments_mz_pos, s.fragments_intensity_pos);
          parse_ms2_pairs(ms2, s.fragments_mz_neg, s.fragments_intensity_neg);
        }
        else if (!fragments.empty())
        {
          parse_ms2_pairs(fragments, s.fragments_mz_pos, s.fragments_intensity_pos);
          parse_ms2_pairs(fragments, s.fragments_mz_neg, s.fragments_intensity_neg);
        }
        else if (!fragments_mz.empty())
        {
          std::vector<std::string> mz_vals = split_string(fragments_mz, ';');
          std::vector<std::string> int_vals = split_string(fragments_int, ';');

          std::vector<double> mz_out;
          std::vector<double> int_out;
          mz_out.reserve(mz_vals.size());
          int_out.reserve(mz_vals.size());

          for (size_t k = 0; k < mz_vals.size(); ++k)
          {
            double mz = std::atof(trim_copy(mz_vals[k]).c_str());
            double inten = 0.0;
            if (k < int_vals.size())
              inten = std::atof(trim_copy(int_vals[k]).c_str());
            mz_out.push_back(mz);
            int_out.push_back(inten);
          }

          s.fragments_mz_pos = mz_out;
          s.fragments_intensity_pos = int_out;
          s.fragments_mz_neg = std::move(mz_out);
          s.fragments_intensity_neg = std::move(int_out);
        }
      }

      out.push_back(std::move(s));
    }

    return out;
  }

  // ── Transformation products ──────────────────────────────────────────────────

  Rcpp::List transformation_products_to_dt(
      const nts::assign_transformation_products::TRANSFORMATION_PRODUCTS &tp)
  {
    int n = tp.size();
    if (n == 0) return get_empty_dt();

    Rcpp::List out = Rcpp::List::create(
        Rcpp::Named("name")                              = as_char_vector(tp.name),
        Rcpp::Named("formula")                           = as_char_vector(tp.formula),
        Rcpp::Named("mass")                              = as_numeric_vector(tp.mass),
        Rcpp::Named("SMILES")                            = as_char_vector(tp.SMILES),
        Rcpp::Named("InChI")                             = as_char_vector(tp.InChI),
        Rcpp::Named("InChIKey")                          = as_char_vector(tp.InChIKey),
        Rcpp::Named("xLogP")                             = as_numeric_vector(tp.xLogP),
        Rcpp::Named("transformation")                    = as_char_vector(tp.transformation),
        Rcpp::Named("precursor_name")                    = as_char_vector(tp.precursor_name),
        Rcpp::Named("precursor_formula")                 = as_char_vector(tp.precursor_formula),
        Rcpp::Named("precursor_mass")                    = as_numeric_vector(tp.precursor_mass),
        Rcpp::Named("precursor_SMILES")                  = as_char_vector(tp.precursor_SMILES),
        Rcpp::Named("precursor_InChI")                   = as_char_vector(tp.precursor_InChI),
        Rcpp::Named("precursor_InChIKey")                = as_char_vector(tp.precursor_InChIKey),
        Rcpp::Named("precursor_xLogP")                   = as_numeric_vector(tp.precursor_xLogP),
        Rcpp::Named("main_precursor_name")               = as_char_vector(tp.main_precursor_name),
        Rcpp::Named("main_precursor_formula")            = as_char_vector(tp.main_precursor_formula),
        Rcpp::Named("main_precursor_mass")               = as_numeric_vector(tp.main_precursor_mass),
        Rcpp::Named("main_precursor_SMILES")             = as_char_vector(tp.main_precursor_SMILES),
        Rcpp::Named("main_precursor_InChI")              = as_char_vector(tp.main_precursor_InChI),
        Rcpp::Named("main_precursor_InChIKey")           = as_char_vector(tp.main_precursor_InChIKey),
        Rcpp::Named("main_precursor_xLogP")              = as_numeric_vector(tp.main_precursor_xLogP),
        Rcpp::Named("feature_group")                     = as_char_vector(tp.feature_group),
        Rcpp::Named("precursor_feature_group")           = as_char_vector(tp.precursor_feature_group),
        Rcpp::Named("main_precursor_feature_group")      = as_char_vector(tp.main_precursor_feature_group),
        Rcpp::Named("cosine_similarity")                 = as_numeric_vector(tp.cosine_similarity),
        Rcpp::Named("main_precursor_cosine_similarity")  = as_numeric_vector(tp.main_precursor_cosine_similarity),
        Rcpp::Named("rt_plausibility")                   = as_numeric_vector(tp.rt_plausibility),
        Rcpp::Named("main_precursor_rt_plausibility")    = as_numeric_vector(tp.main_precursor_rt_plausibility));

    out.attr("class") = Rcpp::CharacterVector::create("data.table", "data.frame");
    return out;
  }

} // namespace

// [[Rcpp::export]]
SEXP rcpp_project_non_target_analysis_new(SEXP project_xptr)
{
  return project::project_call([&]() {
    auto *ptr = new nts::PROJECT_NON_TARGET_ANALYSIS(project_from_xptr(project_xptr).context());
    Rcpp::XPtr<nts::PROJECT_NON_TARGET_ANALYSIS> out(ptr, true);
    out.attr("class") = "streamfindProjectNonTargetAnalysis";
    return SEXP(out);
  });
}

// [[Rcpp::export]]
Rcpp::List rcpp_project_non_target_analysis_get_features(SEXP nts_xptr,
                                                         CharacterVector analyses,
                                                         bool include_filtered)
{
  return project::project_call([&]() {
    return nts_feature_rows_to_dt(
        project_non_target_analysis_from_xptr(nts_xptr).get_features(
            Rcpp::as<std::vector<std::string>>(analyses), include_filtered));
  });
}

// [[Rcpp::export]]
Rcpp::List rcpp_project_non_target_analysis_get_features_count(SEXP nts_xptr,
                                                               CharacterVector analyses,
                                                               bool include_filtered)
{
  return project::project_call([&]() {
    return nts_feature_count_rows_to_dt(
        project_non_target_analysis_from_xptr(nts_xptr).get_features_count(
            Rcpp::as<std::vector<std::string>>(analyses), include_filtered));
  });
}

// [[Rcpp::export]]
Rcpp::List rcpp_project_non_target_analysis_get_suspects(SEXP nts_xptr,
                                                         CharacterVector analyses,
                                                         SEXP features,
                                                         SEXP groups,
                                                         SEXP targets,
                                                         double ppm = 20.0,
                                                         double sec = 60.0,
                                                         double millisec = 5.0)
{
  return project::project_call([&]() {
    return nts_suspect_rows_to_dt(
        project_non_target_analysis_from_xptr(nts_xptr).get_suspects(
            Rcpp::as<std::vector<std::string>>(analyses),
            as_character_selection(features, "feature"),
            as_character_selection(groups, "feature_group", "group"),
            ms_targets_input_from_object(targets),
            ppm,
            sec,
            millisec));
  });
}

// [[Rcpp::export]]
Rcpp::List rcpp_project_non_target_analysis_get_internal_standards(SEXP nts_xptr,
                                                                   CharacterVector analyses,
                                                                   SEXP features,
                                                                   SEXP groups,
                                                                   SEXP targets,
                                                                   double ppm = 20.0,
                                                                   double sec = 60.0,
                                                                   double millisec = 5.0)
{
  return project::project_call([&]() {
    return nts_internal_standard_rows_to_dt(
        project_non_target_analysis_from_xptr(nts_xptr).get_internal_standards(
            Rcpp::as<std::vector<std::string>>(analyses),
            as_character_selection(features, "feature"),
            as_character_selection(groups, "feature_group", "group"),
            ms_targets_input_from_object(targets),
            ppm,
            sec,
            millisec));
  });
}

// [[Rcpp::export]]
Rcpp::List rcpp_project_non_target_analysis_get_transformation_products(SEXP nts_xptr)
{
  return project::project_call([&]() {
    return nts_transformation_product_rows_to_dt(
        project_non_target_analysis_from_xptr(nts_xptr).get_transformation_products());
  });
}

// [[Rcpp::export]]
bool rcpp_project_non_target_analysis_find_features(SEXP nts_xptr,
                                                    CharacterVector analyses,
                                                    NumericVector rt_windows_min,
                                                    NumericVector rt_windows_max,
                                                    float ppm_threshold = 15.0,
                                                    float noise_threshold = 15.0,
                                                    float min_snr = 3.0,
                                                    int min_traces = 3,
                                                    float baseline_window = 200.0,
                                                    float max_width = 100.0,
                                                    float base_quantile = 0.10,
                                                    std::string debug_analysis = "",
                                                    float debug_mz = 0.0,
                                                    int debug_spec_idx = -1)
{
  return project::project_call([&]() {
    return project_non_target_analysis_from_xptr(nts_xptr).find_features(
        Rcpp::as<std::vector<std::string>>(analyses),
        Rcpp::as<std::vector<float>>(rt_windows_min),
        Rcpp::as<std::vector<float>>(rt_windows_max),
        ppm_threshold,
        noise_threshold,
        min_snr,
        min_traces,
        baseline_window,
        max_width,
        base_quantile,
        debug_analysis,
        debug_mz,
        debug_spec_idx);
  });
}

// [[Rcpp::export]]
bool rcpp_project_non_target_analysis_suspect_screening(SEXP nts_xptr,
                                                        Rcpp::List suspects,
                                                        CharacterVector analyses,
                                                        double ppm = 5.0,
                                                        double sec = 10.0,
                                                        double ppmMS2 = 10.0,
                                                        double mzrMS2 = 0.008,
                                                        double minCosineSimilarity = 0.7,
                                                        int minSharedFragments = 3,
                                                        bool filtered = false)
{
  return project::project_call([&]() {
    return project_non_target_analysis_from_xptr(nts_xptr).suspect_screening(
        as_suspect_queries(suspects),
        Rcpp::as<std::vector<std::string>>(analyses),
        ppm,
        sec,
        ppmMS2,
        mzrMS2,
        minCosineSimilarity,
        minSharedFragments,
        filtered);
  });
}

// [[Rcpp::export]]
bool rcpp_project_non_target_analysis_find_internal_standards(SEXP nts_xptr,
                                                              Rcpp::List suspects,
                                                              CharacterVector analyses,
                                                              double ppm = 5.0,
                                                              double sec = 10.0,
                                                              double ppmMS2 = 10.0,
                                                              double mzrMS2 = 0.008,
                                                              double minCosineSimilarity = 0.7,
                                                              int minSharedFragments = 3,
                                                              bool filtered = true)
{
  return project::project_call([&]() {
    return project_non_target_analysis_from_xptr(nts_xptr).find_internal_standards(
        as_suspect_queries(suspects),
        Rcpp::as<std::vector<std::string>>(analyses),
        ppm,
        sec,
        ppmMS2,
        mzrMS2,
        minCosineSimilarity,
        minSharedFragments,
        filtered);
  });
}

// [[Rcpp::export]]
bool rcpp_project_non_target_analysis_load_features_ms1(SEXP nts_xptr,
                                                        CharacterVector analyses,
                                                        bool filtered = false,
                                                        NumericVector rtWindow = NumericVector::create(-2.0, 2.0),
                                                        NumericVector mzWindow = NumericVector::create(-1.0, 6.0),
                                                        float minTracesIntensity = 250.0,
                                                        float mzClust = 0.005,
                                                        float presence = 0.8)
{
  return project::project_call([&]() {
    return project_non_target_analysis_from_xptr(nts_xptr).load_features_ms1(
        Rcpp::as<std::vector<std::string>>(analyses),
        filtered,
        Rcpp::as<std::vector<float>>(rtWindow),
        Rcpp::as<std::vector<float>>(mzWindow),
        minTracesIntensity,
        mzClust,
        presence);
  });
}

// [[Rcpp::export]]
bool rcpp_project_non_target_analysis_load_features_ms2(SEXP nts_xptr,
                                                        CharacterVector analyses,
                                                        bool filtered = false,
                                                        float minTracesIntensity = 10.0,
                                                        float isolationWindow = 1.3,
                                                        float mzClust = 0.005,
                                                        float presence = 0.8)
{
  return project::project_call([&]() {
    return project_non_target_analysis_from_xptr(nts_xptr).load_features_ms2(
        Rcpp::as<std::vector<std::string>>(analyses),
        filtered,
        minTracesIntensity,
        isolationWindow,
        mzClust,
        presence);
  });
}

// [[Rcpp::export]]
bool rcpp_project_non_target_analysis_create_components(SEXP nts_xptr,
                                                        CharacterVector analyses,
                                                        NumericVector rtWindow = NumericVector::create(0.0, 0.0),
                                                        float minCorrelation = 0.8,
                                                        float debugRT = 0.0,
                                                        std::string debugAnalysis = "")
{
  return project::project_call([&]() {
    return project_non_target_analysis_from_xptr(nts_xptr).create_components(
        Rcpp::as<std::vector<std::string>>(analyses),
        Rcpp::as<std::vector<float>>(rtWindow),
        minCorrelation,
        debugRT,
        debugAnalysis);
  });
}

// [[Rcpp::export]]
bool rcpp_project_non_target_analysis_annotate_components(SEXP nts_xptr,
                                                          CharacterVector analyses,
                                                          int maxIsotopes = 5,
                                                          int maxCharge = 1,
                                                          int maxGaps = 1,
                                                          float ppm = 10.0,
                                                          std::string debugComponent = "",
                                                          std::string debugAnalysis = "")
{
  return project::project_call([&]() {
    return project_non_target_analysis_from_xptr(nts_xptr).annotate_components(
        Rcpp::as<std::vector<std::string>>(analyses),
        maxIsotopes,
        maxCharge,
        maxGaps,
        ppm,
        debugComponent,
        debugAnalysis);
  });
}

// [[Rcpp::export]]
bool rcpp_project_non_target_analysis_group_features(SEXP nts_xptr,
                                                     CharacterVector analyses,
                                                     std::string method = "internal_standards",
                                                     float rtDeviation = 5.0,
                                                     float ppm = 10.0,
                                                     int minSamples = 1,
                                                     float binSize = 5.0,
                                                     bool filtered = false,
                                                     bool debug = false,
                                                     float debugRT = 0.0)
{
  return project::project_call([&]() {
    return project_non_target_analysis_from_xptr(nts_xptr).group_features(
        Rcpp::as<std::vector<std::string>>(analyses),
        method,
        rtDeviation,
        ppm,
        minSamples,
        binSize,
        filtered,
        debug,
        debugRT);
  });
}

// [[Rcpp::export]]
bool rcpp_project_non_target_analysis_fill_features(SEXP nts_xptr,
                                                    CharacterVector analyses,
                                                    bool withinReplicate = false,
                                                    bool filtered = false,
                                                    float rtExpand = 10.0,
                                                    float mzExpand = 0.01,
                                                    float maxPeakWidth = 30.0,
                                                    float minTracesIntensity = 1000.0,
                                                    int minNumberTraces = 5,
                                                    float minIntensity = 5000.0,
                                                    float rtApexDeviation = 5.0,
                                                    float minSignalToNoiseRatio = 3.0,
                                                    float minGaussianFit = 0.2,
                                                    std::string debugFG = "")
{
  return project::project_call([&]() {
    return project_non_target_analysis_from_xptr(nts_xptr).fill_features(
        Rcpp::as<std::vector<std::string>>(analyses),
        withinReplicate,
        filtered,
        rtExpand,
        mzExpand,
        maxPeakWidth,
        minTracesIntensity,
        minNumberTraces,
        minIntensity,
        rtApexDeviation,
        minSignalToNoiseRatio,
        minGaussianFit,
        debugFG);
  });
}

// [[Rcpp::export]]
bool rcpp_project_non_target_analysis_blank_subtraction(SEXP nts_xptr,
                                                        CharacterVector analyses,
                                                        float blankThreshold = 5.0,
                                                        float rtExpand = 10.0,
                                                        float mzExpand = 0.005)
{
  return project::project_call([&]() {
    return project_non_target_analysis_from_xptr(nts_xptr).blank_subtraction(
        Rcpp::as<std::vector<std::string>>(analyses),
        blankThreshold,
        rtExpand,
        mzExpand);
  });
}

// [[Rcpp::export]]
bool rcpp_project_non_target_analysis_filter_features(SEXP nts_xptr,
                                                      CharacterVector analyses,
                                                      double minSN = NA_REAL,
                                                      double minIntensity = NA_REAL,
                                                      double minArea = NA_REAL,
                                                      double minWidth = NA_REAL,
                                                      double maxWidth = NA_REAL,
                                                      double maxPPM = NA_REAL,
                                                      double minFwhmRT = NA_REAL,
                                                      double maxFwhmRT = NA_REAL,
                                                      double minFwhmMZ = NA_REAL,
                                                      double maxFwhmMZ = NA_REAL,
                                                      double minGaussianA = NA_REAL,
                                                      double minGaussianMu = NA_REAL,
                                                      double maxGaussianMu = NA_REAL,
                                                      double minGaussianSigma = NA_REAL,
                                                      double maxGaussianSigma = NA_REAL,
                                                      double minGaussianR2 = NA_REAL,
                                                      double maxJaggedness = NA_REAL,
                                                      double minSharpness = NA_REAL,
                                                      double minAsymmetry = NA_REAL,
                                                      double maxAsymmetry = NA_REAL,
                                                      int maxModality = NA_INTEGER,
                                                      double minPlates = NA_REAL,
                                                      LogicalVector onlyFilled = LogicalVector::create(NA_LOGICAL),
                                                      bool removeFilled = false,
                                                      int minSizeEIC = NA_INTEGER,
                                                      int minSizeMS1 = NA_INTEGER,
                                                      int minSizeMS2 = NA_INTEGER,
                                                      double minRelPresenceReplicate = NA_REAL,
                                                      bool removeIsotopes = false,
                                                      bool removeAdducts = false,
                                                      bool removeLosses = false)
{
  return project::project_call([&]() {
    const bool hasOnlyFilled = (onlyFilled.size() > 0 && onlyFilled[0] != NA_LOGICAL);
    const bool onlyFilledValue = hasOnlyFilled ? static_cast<bool>(onlyFilled[0]) : false;
    return project_non_target_analysis_from_xptr(nts_xptr).filter_features(
        Rcpp::as<std::vector<std::string>>(analyses),
        minSN,
        minIntensity,
        minArea,
        minWidth,
        maxWidth,
        maxPPM,
        minFwhmRT,
        maxFwhmRT,
        minFwhmMZ,
        maxFwhmMZ,
        minGaussianA,
        minGaussianMu,
        maxGaussianMu,
        minGaussianSigma,
        maxGaussianSigma,
        minGaussianR2,
        maxJaggedness,
        minSharpness,
        minAsymmetry,
        maxAsymmetry,
        maxModality,
        minPlates,
        hasOnlyFilled,
        onlyFilledValue,
        removeFilled,
        minSizeEIC,
        minSizeEIC != NA_INTEGER,
        minSizeMS1,
        minSizeMS1 != NA_INTEGER,
        minSizeMS2,
        minSizeMS2 != NA_INTEGER,
        minRelPresenceReplicate,
        removeIsotopes,
        removeAdducts,
        removeLosses);
  });
}

// [[Rcpp::export]]
bool rcpp_project_non_target_analysis_filter_suspects(SEXP nts_xptr,
                                                      CharacterVector analyses,
                                                      CharacterVector names = CharacterVector::create(),
                                                      double minScore = NA_REAL,
                                                      double maxErrorRT = NA_REAL,
                                                      double maxErrorMass = NA_REAL,
                                                      IntegerVector idLevels = IntegerVector::create(),
                                                      int minSharedFragments = 0,
                                                      double minCosineSimilarity = NA_REAL)
{
  return project::project_call([&]() {
    return project_non_target_analysis_from_xptr(nts_xptr).filter_suspects(
        Rcpp::as<std::vector<std::string>>(analyses),
        Rcpp::as<std::vector<std::string>>(names),
        minScore,
        maxErrorRT,
        maxErrorMass,
        Rcpp::as<std::vector<int>>(idLevels),
        minSharedFragments,
        minCosineSimilarity);
  });
}

// [[Rcpp::export]]
bool rcpp_project_non_target_analysis_filter_internal_standards(SEXP nts_xptr,
                                                                CharacterVector analyses,
                                                                CharacterVector names = CharacterVector::create(),
                                                                double minScore = NA_REAL,
                                                                double maxErrorRT = NA_REAL,
                                                                double maxErrorMass = NA_REAL,
                                                                IntegerVector idLevels = IntegerVector::create(),
                                                                int minSharedFragments = 0,
                                                                double minCosineSimilarity = NA_REAL)
{
  return project::project_call([&]() {
    return project_non_target_analysis_from_xptr(nts_xptr).filter_internal_standards(
        Rcpp::as<std::vector<std::string>>(analyses),
        Rcpp::as<std::vector<std::string>>(names),
        minScore,
        maxErrorRT,
        maxErrorMass,
        Rcpp::as<std::vector<int>>(idLevels),
        minSharedFragments,
        minCosineSimilarity);
  });
}

// [[Rcpp::export]]
bool rcpp_project_non_target_analysis_filter_features_ms2(SEXP nts_xptr,
                                                          CharacterVector analyses,
                                                          int top = 0,
                                                          double minIntensity = NA_REAL,
                                                          double relMinIntensity = NA_REAL,
                                                          bool blankClean = false,
                                                          double mzClust = 0.005,
                                                          double blankPresenceThreshold = 0.8,
                                                          double globalPresenceThreshold = 0.1)
{
  return project::project_call([&]() {
    return project_non_target_analysis_from_xptr(nts_xptr).filter_features_ms2(
        Rcpp::as<std::vector<std::string>>(analyses),
        top,
        minIntensity,
        relMinIntensity,
        blankClean,
        mzClust,
        blankPresenceThreshold,
        globalPresenceThreshold);
  });
}

// [[Rcpp::export]]
bool rcpp_project_non_target_analysis_metfrag_screening(SEXP nts_xptr,
                                                        std::string metfrag_path,
                                                        CharacterVector analyses,
                                                        std::string database_type = "LocalCSV",
                                                        std::string database_path = "",
                                                        double ppm = 5.0,
                                                        double sec = 10.0,
                                                        double ppmMS2 = 10.0,
                                                        double mzrMS2 = 0.008,
                                                        int top_n = 1,
                                                        bool filtered = false,
                                                        std::string java_path = "java",
                                                        std::string run_dir = "",
                                                        bool debug = false,
                                                        Rcpp::List extra_params = R_NilValue)
{
  return project::project_call([&]() {
    std::vector<std::pair<std::string, std::string>> extra_params_cpp;
    if (extra_params.size() > 0) {
      Rcpp::CharacterVector ep_names = extra_params.names();
      for (int i = 0; i < extra_params.size(); ++i) {
        std::string key = Rcpp::as<std::string>(ep_names[i]);
        std::string val = Rcpp::as<std::string>(extra_params[i]);
        if (!key.empty()) {
          extra_params_cpp.emplace_back(key, val);
        }
      }
    }
    return project_non_target_analysis_from_xptr(nts_xptr).metfrag_screening(
        metfrag_path,
        Rcpp::as<std::vector<std::string>>(analyses),
        database_type,
        database_path,
        ppm,
        sec,
        ppmMS2,
        mzrMS2,
        top_n,
        filtered,
        java_path,
        run_dir,
        debug,
        extra_params_cpp);
  });
}

// [[Rcpp::export]]
bool rcpp_project_non_target_analysis_assign_transformation_products(SEXP nts_xptr,
                                                                     Rcpp::List transformation_products,
                                                                     std::string chromatographic_phase = "reverse_phase",
                                                                     double mzrMS2 = 0.008)
{
  return project::project_call([&]() {
    namespace atp = nts::assign_transformation_products;
    std::vector<atp::TPInputRow> tp_rows;
    if (transformation_products.size() > 0) {
      auto get_str = [&](const char *col) {
        Rcpp::CharacterVector v = transformation_products[col];
        std::vector<std::string> out;
        out.reserve(v.size());
        for (int i = 0; i < v.size(); ++i)
          out.push_back((v[i] == NA_STRING) ? "" : Rcpp::as<std::string>(v[i]));
        return out;
      };
      auto get_dbl = [&](const char *col) {
        Rcpp::NumericVector v = transformation_products[col];
        std::vector<double> out;
        out.reserve(v.size());
        for (int i = 0; i < v.size(); ++i)
          out.push_back(Rcpp::NumericVector::is_na(v[i]) ? std::numeric_limits<double>::quiet_NaN() : static_cast<double>(v[i]));
        return out;
      };
      auto name = get_str("name");
      auto formula = get_str("formula");
      auto mass = get_dbl("mass");
      auto SMILES = get_str("SMILES");
      auto InChI = get_str("InChI");
      auto InChIKey = get_str("InChIKey");
      auto xLogP = get_dbl("xLogP");
      auto transformation = get_str("transformation");
      auto precursor_name = get_str("precursor_name");
      auto precursor_formula = get_str("precursor_formula");
      auto precursor_mass = get_dbl("precursor_mass");
      auto precursor_SMILES = get_str("precursor_SMILES");
      auto precursor_InChI = get_str("precursor_InChI");
      auto precursor_InChIKey = get_str("precursor_InChIKey");
      auto precursor_xLogP = get_dbl("precursor_xLogP");
      auto main_precursor_name = get_str("main_precursor_name");
      auto main_precursor_formula = get_str("main_precursor_formula");
      auto main_precursor_mass = get_dbl("main_precursor_mass");
      auto main_precursor_SMILES = get_str("main_precursor_SMILES");
      auto main_precursor_InChI = get_str("main_precursor_InChI");
      auto main_precursor_InChIKey = get_str("main_precursor_InChIKey");
      auto main_precursor_xLogP = get_dbl("main_precursor_xLogP");
      for (int i = 0; i < static_cast<int>(name.size()); ++i) {
        atp::TPInputRow row;
        row.name = name[i];
        row.formula = formula[i];
        row.mass = mass[i];
        row.SMILES = SMILES[i];
        row.InChI = InChI[i];
        row.InChIKey = InChIKey[i];
        row.xLogP = xLogP[i];
        row.transformation = transformation[i];
        row.precursor_name = precursor_name[i];
        row.precursor_formula = precursor_formula[i];
        row.precursor_mass = precursor_mass[i];
        row.precursor_SMILES = precursor_SMILES[i];
        row.precursor_InChI = precursor_InChI[i];
        row.precursor_InChIKey = precursor_InChIKey[i];
        row.precursor_xLogP = precursor_xLogP[i];
        row.main_precursor_name = main_precursor_name[i];
        row.main_precursor_formula = main_precursor_formula[i];
        row.main_precursor_mass = main_precursor_mass[i];
        row.main_precursor_SMILES = main_precursor_SMILES[i];
        row.main_precursor_InChI = main_precursor_InChI[i];
        row.main_precursor_InChIKey = main_precursor_InChIKey[i];
        row.main_precursor_xLogP = main_precursor_xLogP[i];
        tp_rows.push_back(row);
      }
    }
    return project_non_target_analysis_from_xptr(nts_xptr).assign_transformation_products(
        tp_rows,
        chromatographic_phase,
        mzrMS2);
  });
}

// MARK: rcpp_nts_find_features
// [[Rcpp::export]]
Rcpp::List rcpp_nts_find_features(Rcpp::List info,
                                   Rcpp::List spectra_headers,
                                   std::vector<float> rtWindowsMin,
                                   std::vector<float> rtWindowsMax,
                                   float ppmThreshold = 15.0,
                                   float noiseThreshold = 15.0,
                                   float minSNR = 3.0,
                                   int minTraces = 3,
                                   float baselineWindow = 200.0,
                                   float maxWidth = 100.0,
                                   float baseQuantile = 0.10,
                                   std::string debugAnalysis = "",
                                   float debugMZ = 0.0,
                                   int debugSpecIdx = -1) {
  validate_per_analysis_list(info, spectra_headers, "spectra_headers");
  nts::NTS_INFO info_cpp = as_nts_info(info);
  std::vector<mass_spec::MS_SPECTRA_HEADERS> headers_cpp = as_spectra_headers(spectra_headers);
  std::vector<nts::FEATURES> features_cpp;
  std::vector<nts::SUSPECTS> suspects_cpp;
  std::vector<nts::INTERNAL_STANDARDS> internal_standards_cpp;
  nts::NTS_DATA nts_data(info_cpp, headers_cpp, features_cpp, suspects_cpp, internal_standards_cpp);
  nts_data.find_features(
    rtWindowsMin,
    rtWindowsMax,
    ppmThreshold,
    noiseThreshold,
    minSNR,
    minTraces,
    baselineWindow,
    maxWidth,
    baseQuantile,
    debugAnalysis,
    debugMZ,
    debugSpecIdx
  );
  return features_as_list_of_dt(nts_data);
};

// MARK: rcpp_nts_load_features_ms1
// [[Rcpp::export]]
Rcpp::List rcpp_nts_load_features_ms1(Rcpp::List info,
                                        Rcpp::List spectra_headers,
                                        Rcpp::List feature_list,
                                        bool filtered,
                                        std::vector<float> rtWindow,
                                        std::vector<float> mzWindow,
                                        float minTracesIntensity,
                                        float mzClust,
                                        float presence)
{
  validate_per_analysis_list(info, spectra_headers, "spectra_headers");
  validate_per_analysis_list(info, feature_list, "feature_list");
  nts::NTS_INFO info_cpp = as_nts_info(info);
  std::vector<mass_spec::MS_SPECTRA_HEADERS> headers_cpp = as_spectra_headers(spectra_headers);
  std::vector<nts::FEATURES> features_cpp = as_feature_list(feature_list);
  std::vector<nts::SUSPECTS> suspects_cpp;
  std::vector<nts::INTERNAL_STANDARDS> internal_standards_cpp;
  nts::NTS_DATA nts_data(info_cpp, headers_cpp, features_cpp, suspects_cpp, internal_standards_cpp);
  nts_data.load_features_ms1(
      filtered,
      rtWindow,
      mzWindow,
      minTracesIntensity,
      mzClust,
      presence);
  return features_as_list_of_dt(nts_data);
};

// MARK: rcpp_nts_load_features_ms2
// [[Rcpp::export]]
Rcpp::List rcpp_nts_load_features_ms2(Rcpp::List info,
                                        Rcpp::List spectra_headers,
                                        Rcpp::List feature_list,
                                        bool filtered,
                                        float minTracesIntensity,
                                        float isolationWindow,
                                        float mzClust,
                                        float presence)
{
  validate_per_analysis_list(info, spectra_headers, "spectra_headers");
  validate_per_analysis_list(info, feature_list, "feature_list");
  nts::NTS_INFO info_cpp = as_nts_info(info);
  std::vector<mass_spec::MS_SPECTRA_HEADERS> headers_cpp = as_spectra_headers(spectra_headers);
  std::vector<nts::FEATURES> features_cpp = as_feature_list(feature_list);
  std::vector<nts::SUSPECTS> suspects_cpp;
  std::vector<nts::INTERNAL_STANDARDS> internal_standards_cpp;
  nts::NTS_DATA nts_data(info_cpp, headers_cpp, features_cpp, suspects_cpp, internal_standards_cpp);
  nts_data.load_features_ms2(
      filtered,
      minTracesIntensity,
      isolationWindow,
      mzClust,
      presence);
  return features_as_list_of_dt(nts_data);
};

// MARK: rcpp_nts_create_components
// [[Rcpp::export]]
Rcpp::List rcpp_nts_create_components(Rcpp::List info,
                                      Rcpp::List spectra_headers,
                                      Rcpp::List feature_list,
                                      std::vector<float> rtWindow,
                                      float minCorrelation = 0.8,
                                      float debugRT = 0.0,
                                      std::string debugAnalysis = "")
{
  validate_per_analysis_list(info, spectra_headers, "spectra_headers");
  validate_per_analysis_list(info, feature_list, "feature_list");
  nts::NTS_INFO info_cpp = as_nts_info(info);
  std::vector<mass_spec::MS_SPECTRA_HEADERS> headers_cpp = as_spectra_headers(spectra_headers);
  std::vector<nts::FEATURES> features_cpp = as_feature_list(feature_list);
  std::vector<nts::SUSPECTS> suspects_cpp;
  std::vector<nts::INTERNAL_STANDARDS> internal_standards_cpp;
  nts::NTS_DATA nts_data(info_cpp, headers_cpp, features_cpp, suspects_cpp, internal_standards_cpp);
  nts_data.create_components(rtWindow, minCorrelation, debugRT, debugAnalysis);
  return features_as_list_of_dt(nts_data);
};

// MARK: rcpp_nts_annotate_components
// [[Rcpp::export]]
Rcpp::List rcpp_nts_annotate_components(Rcpp::List info,
                                        Rcpp::List spectra_headers,
                                        Rcpp::List feature_list,
                                        int maxIsotopes = 5,
                                        int maxCharge = 1,
                                        int maxGaps = 1,
                                        float ppm = 10.0,
                                        std::string debugComponent = "",
                                        std::string debugAnalysis = "")
{
  validate_per_analysis_list(info, spectra_headers, "spectra_headers");
  validate_per_analysis_list(info, feature_list, "feature_list");
  nts::NTS_INFO info_cpp = as_nts_info(info);
  std::vector<mass_spec::MS_SPECTRA_HEADERS> headers_cpp = as_spectra_headers(spectra_headers);
  std::vector<nts::FEATURES> features_cpp = as_feature_list(feature_list);
  std::vector<nts::SUSPECTS> suspects_cpp;
  std::vector<nts::INTERNAL_STANDARDS> internal_standards_cpp;
  nts::NTS_DATA nts_data(info_cpp, headers_cpp, features_cpp, suspects_cpp, internal_standards_cpp);
  nts_data.annotate_components(maxIsotopes, maxCharge, maxGaps, ppm, debugComponent, debugAnalysis);
  return features_as_list_of_dt(nts_data);
};

// MARK: rcpp_nts_group_features
// [[Rcpp::export]]
Rcpp::List rcpp_nts_group_features(Rcpp::List info,
                                     Rcpp::List spectra_headers,
                                     Rcpp::List feature_list,
                                     std::string method = "obi_warp",
                                     Rcpp::List internal_standards_list = R_NilValue,
                                     float rtDeviation = 5.0,
                                     float ppm = 5.0,
                                     int minSamples = 1,
                                     float binSize = 5.0,
                                     bool debug = false,
                                     float debugRT = 0.0)
{
  validate_per_analysis_list(info, spectra_headers, "spectra_headers");
  validate_per_analysis_list(info, feature_list, "feature_list");
  if (!Rf_isNull(internal_standards_list))
  {
    validate_per_analysis_list(info, internal_standards_list, "internal_standards_list");
  }
  nts::NTS_INFO info_cpp = as_nts_info(info);
  std::vector<mass_spec::MS_SPECTRA_HEADERS> headers_cpp = as_spectra_headers(spectra_headers);
  std::vector<nts::FEATURES> features_cpp = as_feature_list(feature_list);
  std::vector<nts::SUSPECTS> suspects_cpp;
  std::vector<nts::INTERNAL_STANDARDS> internal_standards_nts_cpp = as_internal_standards_list(internal_standards_list);
  nts::NTS_DATA nts_data(info_cpp, headers_cpp, features_cpp, suspects_cpp, internal_standards_nts_cpp);
  nts_data.group_features(method, rtDeviation, ppm, minSamples, binSize, debug, debugRT);
  return features_as_list_of_dt(nts_data);
};

// MARK: rcpp_nts_fill_features
// [[Rcpp::export]]
Rcpp::List rcpp_nts_fill_features(Rcpp::List info,
                                    Rcpp::List spectra_headers,
                                    Rcpp::List feature_list,
                                    bool withinReplicate = false,
                                    bool filtered = false,
                                    float rtExpand = 10.0,
                                    float mzExpand = 0.01,
                                    float maxPeakWidth = 30.0,
                                    float minTracesIntensity = 1000.0,
                                    int minNumberTraces = 5,
                                    float minIntensity = 5000.0,
                                    float rtApexDeviation = 5.0,
                                    float minSignalToNoiseRatio = 3.0,
                                    float minGaussianFit = 0.2,
                                    std::string debugFG = "")
{
  validate_per_analysis_list(info, spectra_headers, "spectra_headers");
  validate_per_analysis_list(info, feature_list, "feature_list");
  nts::NTS_INFO info_cpp = as_nts_info(info);
  std::vector<mass_spec::MS_SPECTRA_HEADERS> headers_cpp = as_spectra_headers(spectra_headers);
  std::vector<nts::FEATURES> features_cpp = as_feature_list(feature_list);
  std::vector<nts::SUSPECTS> suspects_cpp;
  std::vector<nts::INTERNAL_STANDARDS> internal_standards_cpp;
  nts::NTS_DATA nts_data(info_cpp, headers_cpp, features_cpp, suspects_cpp, internal_standards_cpp);
  nts_data.fill_features(
      withinReplicate,
      filtered,
      rtExpand,
      mzExpand,
      maxPeakWidth,
      minTracesIntensity,
      minNumberTraces,
      minIntensity,
      rtApexDeviation,
      minSignalToNoiseRatio,
      minGaussianFit,
      debugFG);
  return features_as_list_of_dt(nts_data);
};

// MARK: rcpp_nts_blank_subtraction
// [[Rcpp::export]]
Rcpp::List rcpp_nts_blank_subtraction(Rcpp::List info,
                                        Rcpp::List spectra_headers,
                                        Rcpp::List feature_list,
                                        float blankThreshold = 5.0,
                                        float rtExpand = 10.0,
                                        float mzExpand = 0.005)
{
  validate_per_analysis_list(info, spectra_headers, "spectra_headers");
  validate_per_analysis_list(info, feature_list, "feature_list");
  nts::NTS_INFO info_cpp = as_nts_info(info);
  std::vector<mass_spec::MS_SPECTRA_HEADERS> headers_cpp = as_spectra_headers(spectra_headers);
  std::vector<nts::FEATURES> features_cpp = as_feature_list(feature_list);
  std::vector<nts::SUSPECTS> suspects_cpp;
  std::vector<nts::INTERNAL_STANDARDS> internal_standards_cpp;
  nts::NTS_DATA nts_data(info_cpp, headers_cpp, features_cpp, suspects_cpp, internal_standards_cpp);
  nts_data.subtract_blank(blankThreshold, rtExpand, mzExpand);
  return features_as_list_of_dt(nts_data);
};

// MARK: rcpp_nts_filter_features
// [[Rcpp::export]]
Rcpp::List rcpp_nts_filter_features(
    Rcpp::List info,
    Rcpp::List feature_list,
    double minSN = NA_REAL,
    double minIntensity = NA_REAL,
    double minArea = NA_REAL,
    double minWidth = NA_REAL,
    double maxWidth = NA_REAL,
    double maxPPM = NA_REAL,
    double minFwhmRT = NA_REAL,
    double maxFwhmRT = NA_REAL,
    double minFwhmMZ = NA_REAL,
    double maxFwhmMZ = NA_REAL,
    double minGaussianA = NA_REAL,
    double minGaussianMu = NA_REAL,
    double maxGaussianMu = NA_REAL,
    double minGaussianSigma = NA_REAL,
    double maxGaussianSigma = NA_REAL,
    double minGaussianR2 = NA_REAL,
    double maxJaggedness = NA_REAL,
    double minSharpness = NA_REAL,
    double minAsymmetry = NA_REAL,
    double maxAsymmetry = NA_REAL,
    int maxModality = NA_INTEGER,
    double minPlates = NA_REAL,
    Rcpp::LogicalVector onlyFilled = Rcpp::LogicalVector::create(NA_LOGICAL),
    bool removeFilled = false,
    int minSizeEIC = NA_INTEGER,
    int minSizeMS1 = NA_INTEGER,
    int minSizeMS2 = NA_INTEGER,
    double minRelPresenceReplicate = NA_REAL,
    bool removeIsotopes = false,
    bool removeAdducts = false,
    bool removeLosses = false)
{
  validate_per_analysis_list(info, feature_list, "feature_list");
  nts::NTS_INFO info_cpp = as_nts_info(info);
  std::vector<mass_spec::MS_SPECTRA_HEADERS> headers_cpp;
  std::vector<nts::FEATURES> features_cpp = as_feature_list(feature_list);
  std::vector<nts::SUSPECTS> suspects_cpp;
  std::vector<nts::INTERNAL_STANDARDS> internal_standards_cpp;
  nts::NTS_DATA nts_data(info_cpp, headers_cpp, features_cpp, suspects_cpp, internal_standards_cpp);

  bool hasOnlyFilled = (onlyFilled.size() > 0 && onlyFilled[0] != NA_LOGICAL);
  bool onlyFilledValue = hasOnlyFilled ? static_cast<bool>(onlyFilled[0]) : false;
  bool hasMaxModality = (maxModality != NA_INTEGER);
  bool hasMinSizeEIC = (minSizeEIC != NA_INTEGER);
  bool hasMinSizeMS1 = (minSizeMS1 != NA_INTEGER);
  bool hasMinSizeMS2 = (minSizeMS2 != NA_INTEGER);

  nts_data.filter_features(
      minSN,
      minIntensity,
      minArea,
      minWidth,
      maxWidth,
      maxPPM,
      minFwhmRT,
      maxFwhmRT,
      minFwhmMZ,
      maxFwhmMZ,
      minGaussianA,
      minGaussianMu,
      maxGaussianMu,
      minGaussianSigma,
      maxGaussianSigma,
      minGaussianR2,
      maxJaggedness,
      minSharpness,
      minAsymmetry,
      maxAsymmetry,
      maxModality,
      hasMaxModality,
      minPlates,
      hasOnlyFilled,
      onlyFilledValue,
      removeFilled,
      minSizeEIC,
      hasMinSizeEIC,
      minSizeMS1,
      hasMinSizeMS1,
      minSizeMS2,
      hasMinSizeMS2,
      minRelPresenceReplicate,
      removeIsotopes,
      removeAdducts,
      removeLosses);
  return features_as_list_of_dt(nts_data);
};

// MARK: rcpp_nts_filter_suspects
// [[Rcpp::export]]
Rcpp::List rcpp_nts_filter_suspects(
    Rcpp::List info,
    Rcpp::List suspect_list,
    Rcpp::CharacterVector names = Rcpp::CharacterVector::create(),
    double minScore = NA_REAL,
    double maxErrorRT = NA_REAL,
    double maxErrorMass = NA_REAL,
    Rcpp::IntegerVector idLevels = Rcpp::IntegerVector::create(),
    int minSharedFragments = 0,
    double minCosineSimilarity = NA_REAL)
{
  nts::NTS_INFO info_cpp = as_nts_info(info);
  std::vector<mass_spec::MS_SPECTRA_HEADERS> headers_cpp;
  std::vector<nts::FEATURES> features_cpp;
  std::vector<nts::SUSPECTS> suspects_cpp = as_suspects_list(suspect_list);
  std::vector<nts::INTERNAL_STANDARDS> internal_standards_cpp;
  nts::NTS_DATA nts_data(info_cpp, headers_cpp, features_cpp, suspects_cpp, internal_standards_cpp);

  std::vector<std::string> names_cpp = Rcpp::as<std::vector<std::string>>(names);
  std::vector<int> idLevels_cpp = Rcpp::as<std::vector<int>>(idLevels);

  nts_data.filter_suspects(names_cpp, minScore, maxErrorRT, maxErrorMass, idLevels_cpp, minSharedFragments, minCosineSimilarity);
  return suspects_as_list_of_dt(nts_data);
};

// MARK: rcpp_nts_filter_internal_standards
// [[Rcpp::export]]
Rcpp::List rcpp_nts_filter_internal_standards(
    Rcpp::List info,
    Rcpp::List internal_standards_list,
    Rcpp::CharacterVector names = Rcpp::CharacterVector::create(),
    double minScore = NA_REAL,
    double maxErrorRT = NA_REAL,
    double maxErrorMass = NA_REAL,
    Rcpp::IntegerVector idLevels = Rcpp::IntegerVector::create(),
    int minSharedFragments = 0,
    double minCosineSimilarity = NA_REAL)
{
  nts::NTS_INFO info_cpp = as_nts_info(info);
  std::vector<mass_spec::MS_SPECTRA_HEADERS> headers_cpp;
  std::vector<nts::FEATURES> features_cpp;
  std::vector<nts::SUSPECTS> suspects_cpp;
  std::vector<nts::INTERNAL_STANDARDS> internal_standards_cpp = as_internal_standards_list(internal_standards_list);
  nts::NTS_DATA nts_data(info_cpp, headers_cpp, features_cpp, suspects_cpp, internal_standards_cpp);

  std::vector<std::string> names_cpp = Rcpp::as<std::vector<std::string>>(names);
  std::vector<int> idLevels_cpp = Rcpp::as<std::vector<int>>(idLevels);

  nts_data.filter_internal_standards(names_cpp, minScore, maxErrorRT, maxErrorMass, idLevels_cpp, minSharedFragments, minCosineSimilarity);
  return internal_standards_as_list_of_dt(nts_data);
};

// MARK: rcpp_nts_suspect_screening
// [[Rcpp::export]]
Rcpp::List rcpp_nts_suspect_screening(
    Rcpp::List info,
    Rcpp::List spectra_headers,
    Rcpp::List feature_list,
    Rcpp::List suspects,
    Rcpp::CharacterVector analyses = Rcpp::CharacterVector::create(""),
    double ppm = 5.0,
    double sec = 10.0,
    double ppmMS2 = 10.0,
    double mzrMS2 = 0.008,
    double minCosineSimilarity = 0.7,
    int minSharedFragments = 3,
    bool filtered = false)
{
  nts::NTS_INFO info_cpp = as_nts_info(info);
  std::vector<mass_spec::MS_SPECTRA_HEADERS> headers_cpp = as_spectra_headers(spectra_headers);
  std::vector<nts::FEATURES> features_cpp = as_feature_list(feature_list);
  std::vector<nts::SUSPECTS> suspects_nts_cpp;
  std::vector<nts::INTERNAL_STANDARDS> internal_standards_cpp;
  nts::NTS_DATA nts_data(info_cpp, headers_cpp, features_cpp, suspects_nts_cpp, internal_standards_cpp);

  std::vector<std::string> analyses_sel;
  if (analyses.size() > 0 && analyses[0] != NA_STRING && Rcpp::as<std::string>(analyses[0]) != "")
  {
    analyses_sel = Rcpp::as<std::vector<std::string>>(analyses);
  }

  std::vector<nts::suspect_screening::SuspectQuery> suspects_cpp = as_suspect_queries(suspects);
  nts_data.suspect_screening(
      analyses_sel,
      suspects_cpp,
      ppm,
      sec,
      ppmMS2,
      mzrMS2,
      minCosineSimilarity,
      minSharedFragments,
      filtered);

  // Combine all suspects from all analyses into a single data.table
  nts::SUSPECTS suspects_combined;
  for (size_t i = 0; i < nts_data.suspects.size(); ++i)
  {
    const nts::SUSPECTS &sus = nts_data.suspects[i];
    for (size_t j = 0; j < sus.analysis.size(); ++j)
    {
      nts::SUSPECT s;
      s.analysis = sus.analysis[j];
      s.feature = sus.feature[j];
      s.candidate_rank = sus.candidate_rank[j];
      s.name = sus.name[j];
      s.polarity = sus.polarity[j];
      s.db_mass = sus.db_mass[j];
      s.exp_mass = sus.exp_mass[j];
      s.error_mass = sus.error_mass[j];
      s.db_rt = sus.db_rt[j];
      s.exp_rt = sus.exp_rt[j];
      s.error_rt = sus.error_rt[j];
      s.intensity = sus.intensity[j];
      s.area = sus.area[j];
      s.id_level = sus.id_level[j];
      s.score = sus.score[j];
      s.shared_fragments = sus.shared_fragments[j];
      s.cosine_similarity = sus.cosine_similarity[j];
      s.formula = sus.formula[j];
      s.SMILES = sus.SMILES[j];
      s.InChI = sus.InChI[j];
      s.InChIKey = sus.InChIKey[j];
      s.xLogP = sus.xLogP[j];
      s.database_id = sus.database_id[j];
      s.db_ms2_size = sus.db_ms2_size[j];
      s.db_ms2_mz = sus.db_ms2_mz[j];
      s.db_ms2_intensity = sus.db_ms2_intensity[j];
      s.db_ms2_formula = sus.db_ms2_formula[j];
      s.exp_ms2_size = sus.exp_ms2_size[j];
      s.exp_ms2_mz = sus.exp_ms2_mz[j];
      s.exp_ms2_intensity = sus.exp_ms2_intensity[j];
      suspects_combined.append(s);
    }
  }

  return suspects_to_list_dt(suspects_combined);
};

// MARK: rcpp_nts_filter_features_ms2
// [[Rcpp::export]]
Rcpp::List rcpp_nts_filter_features_ms2(
    Rcpp::List info,
    Rcpp::List feature_list,
    int top = 0,
    double minIntensity = NA_REAL,
    double relMinIntensity = NA_REAL,
    bool blankClean = false,
    double mzClust = 0.005,
    double blankPresenceThreshold = 0.8,
    double globalPresenceThreshold = 0.1)
{
  validate_per_analysis_list(info, feature_list, "feature_list");
  nts::NTS_INFO info_cpp = as_nts_info(info);
  std::vector<mass_spec::MS_SPECTRA_HEADERS> headers_cpp;
  std::vector<nts::FEATURES> features_cpp = as_feature_list(feature_list);
  std::vector<nts::SUSPECTS> suspects_cpp;
  std::vector<nts::INTERNAL_STANDARDS> internal_standards_cpp;
  nts::NTS_DATA nts_data(info_cpp, headers_cpp, features_cpp, suspects_cpp, internal_standards_cpp);

  nts::filter_features_ms2::filter_features_ms2_impl(
      nts_data,
      top,
      std::isnan(minIntensity) ? std::numeric_limits<float>::quiet_NaN()
                               : static_cast<float>(minIntensity),
      std::isnan(relMinIntensity) ? std::numeric_limits<float>::quiet_NaN()
                                  : static_cast<float>(relMinIntensity),
      blankClean,
      static_cast<float>(mzClust),
      static_cast<float>(blankPresenceThreshold),
      static_cast<float>(globalPresenceThreshold));

  return features_as_list_of_dt(nts_data);
};

// MARK: rcpp_nts_metfrag_screening
// [[Rcpp::export]]
Rcpp::List rcpp_nts_metfrag_screening(
    Rcpp::List info,
    Rcpp::List spectra_headers,
    Rcpp::List feature_list,
    std::string metfrag_path,
    std::string database_type = "LocalCSV",
    std::string database_path = "",
    Rcpp::CharacterVector analyses = Rcpp::CharacterVector::create(""),
    double ppm = 5.0,
    double sec = 10.0,
    double ppmMS2 = 10.0,
    double mzrMS2 = 0.008,
    int top_n = 1,
    bool filtered = false,
    std::string java_path = "java",
    std::string run_dir = "",
    bool debug = false,
    Rcpp::List extra_params = R_NilValue)
{
  validate_per_analysis_list(info, feature_list, "feature_list");
  nts::NTS_INFO info_cpp = as_nts_info(info);
  std::vector<mass_spec::MS_SPECTRA_HEADERS> headers_cpp = as_spectra_headers(spectra_headers);
  std::vector<nts::FEATURES> features_cpp = as_feature_list(feature_list);
  std::vector<nts::SUSPECTS> suspects_cpp;
  std::vector<nts::INTERNAL_STANDARDS> internal_standards_cpp;
  nts::NTS_DATA nts_data(info_cpp, headers_cpp, features_cpp, suspects_cpp, internal_standards_cpp);

  std::vector<std::string> analyses_sel;
  if (analyses.size() > 0 && analyses[0] != NA_STRING && Rcpp::as<std::string>(analyses[0]) != "")
    analyses_sel = Rcpp::as<std::vector<std::string>>(analyses);

  // Convert named R list to extra_params vector of pairs.
  std::vector<std::pair<std::string, std::string>> extra_params_cpp;
  if (extra_params.size() > 0)
  {
    Rcpp::CharacterVector ep_names = extra_params.names();
    for (int i = 0; i < extra_params.size(); ++i)
    {
      std::string key = Rcpp::as<std::string>(ep_names[i]);
      std::string val = Rcpp::as<std::string>(extra_params[i]);
      if (!key.empty())
        extra_params_cpp.emplace_back(key, val);
    }
  }

  nts::metfrag_runner::MetFragParams p;
  p.metfrag_path   = metfrag_path;
  p.database_type  = database_type;
  p.database_path  = database_path;
  p.ppm            = ppm;
  p.sec            = sec;
  p.ppmMS2         = ppmMS2;
  p.mzrMS2         = mzrMS2;
  p.top_n          = top_n;
  p.filtered       = filtered;
  p.java_path      = java_path;
  p.run_dir        = run_dir;
  p.debug          = debug;
  p.extra_params   = extra_params_cpp;

  nts_data.metfrag_screening(analyses_sel, p);
  return suspects_as_list_of_dt(nts_data);
};

// MARK: rcpp_nts_assign_transformation_products
// [[Rcpp::export]]
Rcpp::List rcpp_nts_assign_transformation_products(
    Rcpp::List suspects,
    Rcpp::List transformation_products,
    std::string chromatographic_phase = "reverse_phase",
    double mzrMS2 = 0.008)
{
  namespace atp = nts::assign_transformation_products;

  // ── Parse suspects ──────────────────────────────────────────────────────────
  std::vector<atp::FlatSuspect> suspects_cpp;
  if (suspects.size() > 0)
  {
    Rcpp::CharacterVector smiles_r  = suspects["SMILES"];
    Rcpp::CharacterVector fg_r      = suspects["feature_group"];
    Rcpp::NumericVector   exp_rt_r  = suspects["exp_rt"];
    Rcpp::IntegerVector   ms2sz_r   = suspects["exp_ms2_size"];
    Rcpp::CharacterVector ms2mz_r   = suspects["exp_ms2_mz"];
    Rcpp::CharacterVector ms2int_r  = suspects["exp_ms2_intensity"];

    int n = smiles_r.size();
    suspects_cpp.reserve(n);
    for (int i = 0; i < n; ++i)
    {
      atp::FlatSuspect s;
      s.SMILES           = (smiles_r[i] == NA_STRING) ? "" : Rcpp::as<std::string>(smiles_r[i]);
      s.feature_group    = (fg_r[i]     == NA_STRING) ? "" : Rcpp::as<std::string>(fg_r[i]);
      s.exp_rt           = Rcpp::NumericVector::is_na(exp_rt_r[i]) ? std::numeric_limits<double>::quiet_NaN()
                                                                    : static_cast<double>(exp_rt_r[i]);
      s.exp_ms2_size     = Rcpp::IntegerVector::is_na(ms2sz_r[i])  ? 0 : static_cast<int>(ms2sz_r[i]);
      s.exp_ms2_mz       = (ms2mz_r[i]  == NA_STRING) ? "" : Rcpp::as<std::string>(ms2mz_r[i]);
      s.exp_ms2_intensity= (ms2int_r[i] == NA_STRING) ? "" : Rcpp::as<std::string>(ms2int_r[i]);
      suspects_cpp.push_back(s);
    }
  }

  // ── Parse transformation products ──────────────────────────────────────────
  std::vector<atp::TPInputRow> tp_rows;
  if (transformation_products.size() > 0)
  {
    auto get_str = [&](const char *col) {
      Rcpp::CharacterVector v = transformation_products[col];
      std::vector<std::string> out;
      out.reserve(v.size());
      for (int i = 0; i < v.size(); ++i)
        out.push_back((v[i] == NA_STRING) ? "" : Rcpp::as<std::string>(v[i]));
      return out;
    };
    auto get_dbl = [&](const char *col) {
      Rcpp::NumericVector v = transformation_products[col];
      std::vector<double> out;
      out.reserve(v.size());
      for (int i = 0; i < v.size(); ++i)
        out.push_back(Rcpp::NumericVector::is_na(v[i]) ? std::numeric_limits<double>::quiet_NaN()
                                                       : static_cast<double>(v[i]));
      return out;
    };

    auto name              = get_str("name");
    auto formula           = get_str("formula");
    auto mass              = get_dbl("mass");
    auto SMILES            = get_str("SMILES");
    auto InChI             = get_str("InChI");
    auto InChIKey          = get_str("InChIKey");
    auto xLogP             = get_dbl("xLogP");
    auto transformation    = get_str("transformation");
    auto prec_name         = get_str("precursor_name");
    auto prec_formula      = get_str("precursor_formula");
    auto prec_mass         = get_dbl("precursor_mass");
    auto prec_SMILES       = get_str("precursor_SMILES");
    auto prec_InChI        = get_str("precursor_InChI");
    auto prec_InChIKey     = get_str("precursor_InChIKey");
    auto prec_xLogP        = get_dbl("precursor_xLogP");
    auto main_name         = get_str("main_precursor_name");
    auto main_formula      = get_str("main_precursor_formula");
    auto main_mass         = get_dbl("main_precursor_mass");
    auto main_SMILES       = get_str("main_precursor_SMILES");
    auto main_InChI        = get_str("main_precursor_InChI");
    auto main_InChIKey     = get_str("main_precursor_InChIKey");
    auto main_xLogP        = get_dbl("main_precursor_xLogP");

    int n = static_cast<int>(name.size());
    tp_rows.reserve(n);
    for (int i = 0; i < n; ++i)
    {
      atp::TPInputRow r;
      r.name                   = name[i];
      r.formula                = formula[i];
      r.mass                   = mass[i];
      r.SMILES                 = SMILES[i];
      r.InChI                  = InChI[i];
      r.InChIKey               = InChIKey[i];
      r.xLogP                  = xLogP[i];
      r.transformation         = transformation[i];
      r.precursor_name         = prec_name[i];
      r.precursor_formula      = prec_formula[i];
      r.precursor_mass         = prec_mass[i];
      r.precursor_SMILES       = prec_SMILES[i];
      r.precursor_InChI        = prec_InChI[i];
      r.precursor_InChIKey     = prec_InChIKey[i];
      r.precursor_xLogP        = prec_xLogP[i];
      r.main_precursor_name    = main_name[i];
      r.main_precursor_formula = main_formula[i];
      r.main_precursor_mass    = main_mass[i];
      r.main_precursor_SMILES  = main_SMILES[i];
      r.main_precursor_InChI   = main_InChI[i];
      r.main_precursor_InChIKey= main_InChIKey[i];
      r.main_precursor_xLogP   = main_xLogP[i];
      tp_rows.push_back(r);
    }
  }

  atp::TRANSFORMATION_PRODUCTS result =
      atp::assign_transformation_products_impl(
          suspects_cpp, tp_rows, chromatographic_phase, mzrMS2);

  return transformation_products_to_dt(result);
};
