#include <vector>
#include <cctype>
#include <cstdlib>
#include <cmath>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <Rcpp.h>

#include "project/project.h"
#include "mass_spec/mass_spec.h"
#include "nta/nta.h"

using namespace Rcpp;
namespace fs = std::filesystem;

// MARK: ns nta_rcpp
namespace nta_rcpp
{
  std::string csv_escape(const std::string &value)
  {
    if (value.find_first_of(",\"\n\r") == std::string::npos)
      return value;
    std::string escaped;
    escaped.reserve(value.size() + 2);
    escaped.push_back('"');
    for (char ch : value)
    {
      if (ch == '"')
        escaped.push_back('"');
      escaped.push_back(ch);
    }
    escaped.push_back('"');
    return escaped;
  }

  std::string ascii_lower(std::string value)
  {
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char ch) {
      return static_cast<char>(std::tolower(ch));
    });
    return value;
  }

  std::string find_column_name(const Rcpp::DataFrame &database, const std::vector<std::string> &aliases)
  {
    Rcpp::CharacterVector names = database.names();
    for (const auto &alias : aliases)
    {
      const std::string needle = ascii_lower(alias);
      for (R_xlen_t i = 0; i < names.size(); ++i)
      {
        if (names[i] == NA_STRING)
          continue;
        if (ascii_lower(Rcpp::as<std::string>(names[i])) == needle)
          return Rcpp::as<std::string>(names[i]);
      }
    }
    return std::string();
  }

  SEXP column_sexp(const Rcpp::DataFrame &database, const std::string &name)
  {
    SEXP col = database[name];
    if (TYPEOF(col) == VECSXP)
    {
      Rcpp::List tmp(col);
      if (tmp.size() > 0)
      {
        col = tmp[0];
      }
    }
    return col;
  }

  Rcpp::CharacterVector character_column(const Rcpp::DataFrame &database, const std::vector<std::string> &aliases)
  {
    std::string name = find_column_name(database, aliases);
    if (name.empty())
      return Rcpp::CharacterVector();
    return Rcpp::as<Rcpp::CharacterVector>(column_sexp(database, name));
  }

  Rcpp::NumericVector numeric_column(const Rcpp::DataFrame &database, const std::vector<std::string> &aliases)
  {
    std::string name = find_column_name(database, aliases);
    if (name.empty())
      return Rcpp::NumericVector();
    return Rcpp::as<Rcpp::NumericVector>(column_sexp(database, name));
  }

  std::string write_local_metfrag_database(Rcpp::DataFrame database, const std::string &run_dir)
  {
    const R_xlen_t n = database.nrows();
    if (n <= 0)
    {
      Rcpp::stop("Local MetFrag database must contain at least one row.");
    }

    Rcpp::CharacterVector name_col = character_column(database, {"name", "Name", "Identifier", "identifier", "id", "database_id", "databaseid"});
    Rcpp::CharacterVector formula_col = character_column(database, {"formula", "Formula", "MolecularFormula", "molecularformula"});
    Rcpp::NumericVector mass_col = numeric_column(database, {"mass", "Mass", "MonoisotopicMass", "monoisotopicmass"});
    Rcpp::NumericVector rt_col = numeric_column(database, {"rt", "RT", "retention_time", "RetentionTime"});
    Rcpp::CharacterVector smiles_col = character_column(database, {"SMILES", "smiles", "Smiles"});
    Rcpp::CharacterVector inchi_col = character_column(database, {"InChI", "inchi", "Inchi"});
    Rcpp::CharacterVector inchikey_col = character_column(database, {"InChIKey", "inchikey", "Inchikey"});
    Rcpp::NumericVector xlogp_col = numeric_column(database, {"xLogP", "xlogp", "XLogP", "XLogP3", "logp", "LogP"});

    if (name_col.size() == 0 || formula_col.size() == 0 || mass_col.size() == 0 || rt_col.size() == 0 ||
        smiles_col.size() == 0 || inchi_col.size() == 0 || inchikey_col.size() == 0 || xlogp_col.size() == 0)
    {
      Rcpp::stop("Local MetFrag database must include required columns (or recognized aliases) for name, formula, mass, rt, SMILES, InChI, InChIKey, and xLogP.");
    }
    std::string out_path = (fs::path(run_dir) / "metfrag_local_database.csv").string();
    std::ofstream out(out_path);
    if (!out.is_open())
    {
      Rcpp::stop("Cannot write local MetFrag database to: %s", out_path);
    }

    out << "name,formula,mass,rt,SMILES,InChI,InChIKey,xLogP\n";
    for (R_xlen_t i = 0; i < n; ++i)
    {
      if (i > 0) out << '\n';
      auto write_char = [&](const Rcpp::CharacterVector &col) {
        if (Rcpp::CharacterVector::is_na(col[i])) return std::string();
        return Rcpp::as<std::string>(col[i]);
      };
      auto write_num = [&](const Rcpp::NumericVector &col) {
        if (Rcpp::NumericVector::is_na(col[i])) return std::string();
        std::ostringstream oss;
        oss << std::fixed << std::setprecision(10) << static_cast<double>(col[i]);
        return oss.str();
      };

      out
        << csv_escape(write_char(name_col)) << ','
        << csv_escape(write_char(formula_col)) << ','
        << csv_escape(write_num(mass_col)) << ','
        << csv_escape(write_num(rt_col)) << ','
        << csv_escape(write_char(smiles_col)) << ','
        << csv_escape(write_char(inchi_col)) << ','
        << csv_escape(write_char(inchikey_col)) << ','
        << csv_escape(write_num(xlogp_col));
    }

    return out_path;
  }

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

  project::PROJECT &project_from_xptr(SEXP extptr)
  {
    Rcpp::XPtr<project::PROJECT> ptr(extptr);
    if (ptr.get() == nullptr)
    {
      stop("Project pointer is null");
    }
    return *ptr;
  }

  nta::PROJECT_NON_TARGET_ANALYSIS &project_non_target_analysis_from_xptr(SEXP extptr)
  {
    Rcpp::XPtr<nta::PROJECT_NON_TARGET_ANALYSIS> ptr(extptr);
    if (ptr.get() == nullptr)
    {
      stop("Project Non-Target Analysis pointer is null");
    }
    return *ptr;
  }


  void append_unique_strings(std::vector<std::string> &target, const std::vector<std::string> &values)
  {
    for (const auto &value : values)
    {
      if (value.empty())
      {
        continue;
      }
      if (std::find(target.begin(), target.end(), value) == target.end())
      {
        target.push_back(value);
      }
    }
  }

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

  mass_spec::spectra::MS_TARGETS_INPUT ms_targets_input_from_df(DataFrame df)
  {
    mass_spec::spectra::MS_TARGETS_INPUT out;
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

  mass_spec::spectra::MS_TARGETS_INPUT ms_targets_input_from_object(SEXP value,
                                                                    const char *default_column)
  {
    if (Rf_isNull(value))
    {
      return {};
    }
    if (Rf_isNumeric(value) && !Rf_isMatrix(value))
    {
      DataFrame df = DataFrame::create(Named(default_column) = NumericVector(value));
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

  struct CharacterSelection
  {
    std::vector<std::string> values;
    std::unordered_map<std::string, std::string> labels;
  };

  CharacterSelection as_character_selection(SEXP value, const std::string &column_a, const std::string &column_b = "")
  {
    CharacterSelection out;
    if (Rf_isNull(value))
    {
      return out;
    }
    if (Rf_inherits(value, "data.frame"))
    {
      Rcpp::DataFrame df = Rcpp::as<Rcpp::DataFrame>(value);
      std::string value_column;
      if (df.containsElementNamed(column_a.c_str()))
      {
        value_column = column_a;
      }
      else if (!column_b.empty() && df.containsElementNamed(column_b.c_str()))
      {
        value_column = column_b;
      }
      else
      {
        Rcpp::stop("Selection data.frame must contain '%s'%s%s",
                   column_a.c_str(),
                   column_b.empty() ? "" : " or '",
                   column_b.empty() ? "" : column_b.c_str());
      }

      out.values = Rcpp::as<std::vector<std::string>>(df[value_column]);

      std::vector<std::string> label_values;
      if (df.containsElementNamed("id"))
      {
        label_values = strings_from_character_vector(df["id"]);
      }
      else if (df.containsElementNamed("name"))
      {
        label_values = strings_from_character_vector(df["name"]);
      }
      if (!label_values.empty())
      {
        for (std::size_t i = 0; i < out.values.size() && i < label_values.size(); ++i)
        {
          if (!out.values[i].empty() && !label_values[i].empty())
          {
            out.labels[out.values[i]] = label_values[i];
          }
        }
      }
      return out;
    }

    Rcpp::CharacterVector vec = Rcpp::as<Rcpp::CharacterVector>(value);
    out.values = Rcpp::as<std::vector<std::string>>(vec);
    if (!Rf_isNull(vec.names()))
    {
      const auto labels = strings_from_character_vector(vec.names());
      for (std::size_t i = 0; i < out.values.size() && i < labels.size(); ++i)
      {
        if (!out.values[i].empty() && !labels[i].empty())
        {
          out.labels[out.values[i]] = labels[i];
        }
      }
    }
    return out;
  }

  std::vector<std::string> analyses_from_selection(SEXP value)
  {
    if (Rf_isNull(value) || !Rf_inherits(value, "data.frame"))
    {
      return {};
    }
    Rcpp::DataFrame df = Rcpp::as<Rcpp::DataFrame>(value);
    if (!df.containsElementNamed("analysis"))
    {
      return {};
    }
    return Rcpp::as<std::vector<std::string>>(df["analysis"]);
  }

  nta::api::NTA_QUERY_REQUEST build_nts_query_request(SEXP analyses,
                                                      SEXP features,
                                                      SEXP groups,
                                                      SEXP components,
                                                      SEXP mass,
                                                      SEXP mz,
                                                      SEXP rt,
                                                      SEXP mobility,
                                                      double ppm,
                                                      double sec,
                                                      double millisec,
                                                      bool include_filtered)
  {
    nta::api::NTA_QUERY_REQUEST query;
    if (!Rf_isNull(analyses))
    {
      query.analyses = Rcpp::as<std::vector<std::string>>(Rcpp::as<Rcpp::CharacterVector>(analyses));
    }
    const auto feature_selection = as_character_selection(features, "feature");
    const auto group_selection = as_character_selection(groups, "feature_group", "group");
    const auto component_selection = as_character_selection(components, "feature_component", "component");
    query.features = feature_selection.values;
    query.feature_labels = feature_selection.labels;
    query.feature_groups = group_selection.values;
    query.feature_group_labels = group_selection.labels;
    query.feature_components = component_selection.values;
    query.feature_component_labels = component_selection.labels;
    query.targets.analyses = query.analyses;
    query.targets.mass = ms_targets_input_from_object(mass, "mass");
    query.targets.mz = ms_targets_input_from_object(mz, "mz");
    query.targets.rt = ms_targets_input_from_object(rt, "rt");
    query.targets.mobility = ms_targets_input_from_object(mobility, "mobility");
    append_unique_strings(query.analyses, analyses_from_selection(features));
    append_unique_strings(query.analyses, analyses_from_selection(groups));
    append_unique_strings(query.analyses, analyses_from_selection(components));
    append_unique_strings(query.analyses, query.targets.mass.analysis);
    append_unique_strings(query.analyses, query.targets.mz.analysis);
    append_unique_strings(query.analyses, query.targets.rt.analysis);
    append_unique_strings(query.analyses, query.targets.mobility.analysis);
    query.targets.ppm = ppm;
    query.targets.sec = sec;
    query.targets.millisec = millisec;
    query.targets.analyses = query.analyses;
    query.include_filtered = include_filtered;
    return query;
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

  std::string sexptype_name(SEXP value)
  {
    switch (TYPEOF(value))
    {
      case NILSXP: return "NULL";
      case SYMSXP: return "SYMSXP";
      case LISTSXP: return "LISTSXP";
      case CLOSXP: return "CLOSXP";
      case ENVSXP: return "ENVSXP";
      case PROMSXP: return "PROMSXP";
      case LANGSXP: return "LANGSXP";
      case SPECIALSXP: return "SPECIALSXP";
      case BUILTINSXP: return "BUILTINSXP";
      case CHARSXP: return "CHARSXP";
      case LGLSXP: return "LGLSXP";
      case INTSXP: return "INTSXP";
      case REALSXP: return "REALSXP";
      case CPLXSXP: return "CPLXSXP";
      case STRSXP: return "STRSXP";
      case DOTSXP: return "DOTSXP";
      case ANYSXP: return "ANYSXP";
      case VECSXP: return "VECSXP";
      case EXPRSXP: return "EXPRSXP";
      case BCODESXP: return "BCODESXP";
      case EXTPTRSXP: return "EXTPTRSXP";
      case WEAKREFSXP: return "WEAKREFSXP";
      case RAWSXP: return "RAWSXP";
      case S4SXP: return "S4SXP";
      default: return "UNKNOWN";
    }
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

  Rcpp::List features_to_list_dt(const nta::api::NTA_FEATURES &fts)
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

  Rcpp::List nta_feature_rows_to_dt(const std::vector<nta::api::NTA_FEATURE_ROW> &rows)
  {
    const std::size_t n = rows.size();
    if (n == 0)
    {
      return get_empty_dt();
    }

    Rcpp::CharacterVector project_id(n);
    Rcpp::CharacterVector analysis(n);
    Rcpp::CharacterVector feature(n);
    Rcpp::CharacterVector id(n);
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
    Rcpp::CharacterVector annotation_category(n);
    Rcpp::CharacterVector annotation_type(n);
    Rcpp::CharacterVector annotation_parent_feature(n);
    Rcpp::CharacterVector annotation_element(n);
    Rcpp::NumericVector annotation_mass_error_da(n);
    Rcpp::NumericVector annotation_mass_error_ppm(n);
    Rcpp::NumericVector annotation_rt_error(n);
    Rcpp::NumericVector annotation_rel_intensity(n);
    Rcpp::NumericVector annotation_expected_rel_intensity_min(n);
    Rcpp::NumericVector annotation_expected_rel_intensity_max(n);
    Rcpp::NumericVector annotation_score(n);
    Rcpp::IntegerVector component_size(n);
    Rcpp::NumericVector component_rt_center(n);
    Rcpp::NumericVector component_rt_spread(n);
    Rcpp::NumericVector component_density(n);
    Rcpp::NumericVector component_mean_correlation(n);
    Rcpp::CharacterVector component_best_partner(n);
    Rcpp::NumericVector component_max_correlation(n);
    Rcpp::NumericVector component_mean_correlation_to_component(n);
    Rcpp::NumericVector component_membership_score(n);
    Rcpp::LogicalVector component_is_core(n);
    Rcpp::LogicalVector component_bridge_flag(n);
    Rcpp::CharacterVector created_at(n);

    for (std::size_t i = 0; i < n; ++i)
    {
      const auto &row = rows[i];
      project_id[i] = row.project_id;
      analysis[i] = row.analysis;
      feature[i] = row.feature;
      id[i] = row.id.empty() ? NA_STRING : Rcpp::String(row.id);
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
      annotation_category[i] = row.annotation_category.empty() ? NA_STRING : Rcpp::String(row.annotation_category);
      annotation_type[i] = row.annotation_type.empty() ? NA_STRING : Rcpp::String(row.annotation_type);
      annotation_parent_feature[i] = row.annotation_parent_feature.empty() ? NA_STRING : Rcpp::String(row.annotation_parent_feature);
      annotation_element[i] = row.annotation_element.empty() ? NA_STRING : Rcpp::String(row.annotation_element);
      annotation_mass_error_da[i] = row.annotation_mass_error_da;
      annotation_mass_error_ppm[i] = row.annotation_mass_error_ppm;
      annotation_rt_error[i] = row.annotation_rt_error;
      annotation_rel_intensity[i] = row.annotation_rel_intensity;
      annotation_expected_rel_intensity_min[i] = row.annotation_expected_rel_intensity_min;
      annotation_expected_rel_intensity_max[i] = row.annotation_expected_rel_intensity_max;
      annotation_score[i] = row.annotation_score;
      component_size[i] = row.component_size;
      component_rt_center[i] = row.component_rt_center;
      component_rt_spread[i] = row.component_rt_spread;
      component_density[i] = row.component_density;
      component_mean_correlation[i] = row.component_mean_correlation;
      component_best_partner[i] = row.component_best_partner.empty() ? NA_STRING : Rcpp::String(row.component_best_partner);
      component_max_correlation[i] = row.component_max_correlation;
      component_mean_correlation_to_component[i] = row.component_mean_correlation_to_component;
      component_membership_score[i] = row.component_membership_score;
      component_is_core[i] = row.component_is_core;
      component_bridge_flag[i] = row.component_bridge_flag;
      created_at[i] = row.created_at.empty() ? NA_STRING : Rcpp::String(row.created_at);
    }

    Rcpp::List out = Rcpp::List::create(
        Rcpp::Named("project_id") = project_id,
        Rcpp::Named("analysis") = analysis,
        Rcpp::Named("feature") = feature,
        Rcpp::Named("id") = id,
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
        Rcpp::Named("annotation_category") = annotation_category,
        Rcpp::Named("annotation_type") = annotation_type,
        Rcpp::Named("annotation_parent_feature") = annotation_parent_feature,
        Rcpp::Named("annotation_element") = annotation_element,
        Rcpp::Named("annotation_mass_error_da") = annotation_mass_error_da,
        Rcpp::Named("annotation_mass_error_ppm") = annotation_mass_error_ppm,
        Rcpp::Named("annotation_rt_error") = annotation_rt_error,
        Rcpp::Named("annotation_rel_intensity") = annotation_rel_intensity,
        Rcpp::Named("annotation_expected_rel_intensity_min") = annotation_expected_rel_intensity_min,
        Rcpp::Named("annotation_expected_rel_intensity_max") = annotation_expected_rel_intensity_max,
        Rcpp::Named("annotation_score") = annotation_score,
        Rcpp::Named("component_size") = component_size,
        Rcpp::Named("component_rt_center") = component_rt_center,
        Rcpp::Named("component_rt_spread") = component_rt_spread,
        Rcpp::Named("component_density") = component_density,
        Rcpp::Named("component_mean_correlation") = component_mean_correlation,
        Rcpp::Named("component_best_partner") = component_best_partner,
        Rcpp::Named("component_max_correlation") = component_max_correlation,
        Rcpp::Named("component_mean_correlation_to_component") = component_mean_correlation_to_component,
        Rcpp::Named("component_membership_score") = component_membership_score,
        Rcpp::Named("component_is_core") = component_is_core,
        Rcpp::Named("component_bridge_flag") = component_bridge_flag,
        Rcpp::Named("created_at") = created_at);
    out.attr("class") = Rcpp::CharacterVector::create("data.table", "data.frame");
    return out;
  }

  Rcpp::List nta_feature_count_rows_to_dt(const std::vector<nta::api::NTA_FEATURE_COUNT_ROW> &rows)
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

  Rcpp::List nta_matrix_suppression_rows_to_dt(const std::vector<nta::correction_algorithms::TIC_MATRIX_SUPPRESSION_ROW> &rows)
  {
    if (rows.empty())
    {
      Rcpp::List out = Rcpp::List::create(
        Rcpp::Named("analysis") = Rcpp::CharacterVector(),
        Rcpp::Named("replicate") = Rcpp::CharacterVector(),
        Rcpp::Named("polarity") = Rcpp::IntegerVector(),
        Rcpp::Named("level") = Rcpp::IntegerVector(),
        Rcpp::Named("rt") = Rcpp::NumericVector(),
        Rcpp::Named("intensity") = Rcpp::NumericVector(),
        Rcpp::Named("mp") = Rcpp::NumericVector());
      out.attr("class") = Rcpp::CharacterVector::create("data.table", "data.frame");
      return out;
    }

    const std::size_t n = rows.size();
    Rcpp::CharacterVector analysis(n), replicate(n);
    Rcpp::IntegerVector polarity(n), level(n);
    Rcpp::NumericVector rt(n), intensity(n), mp(n);

    for (std::size_t i = 0; i < n; ++i)
    {
      analysis[i] = rows[i].analysis;
      replicate[i] = rows[i].replicate.empty() ? NA_STRING : Rcpp::String(rows[i].replicate);
      polarity[i] = rows[i].polarity;
      level[i] = rows[i].level;
      rt[i] = rows[i].rt;
      intensity[i] = rows[i].intensity;
      mp[i] = rows[i].mp;
    }

    Rcpp::List out = Rcpp::List::create(
      Rcpp::Named("analysis") = analysis,
      Rcpp::Named("replicate") = replicate,
      Rcpp::Named("polarity") = polarity,
      Rcpp::Named("level") = level,
      Rcpp::Named("rt") = rt,
      Rcpp::Named("intensity") = intensity,
      Rcpp::Named("mp") = mp);
    out.attr("class") = Rcpp::CharacterVector::create("data.table", "data.frame");
    return out;
  }

  Rcpp::List nta_suspect_rows_to_dt(const std::vector<nta::api::NTA_SUSPECT_ROW> &rows)
  {
    const std::size_t n = rows.size();
    if (n == 0)
    {
      return get_empty_dt();
    }
    Rcpp::CharacterVector project_id(n), analysis(n), feature(n), feature_group(n), name(n), formula(n), smiles(n), inchi(n), inchikey(n), database_id(n), db_ms2_mz(n), db_ms2_intensity(n), db_ms2_formula(n), db_ms2_smiles(n), exp_ms2_mz(n), exp_ms2_intensity(n), created_at(n);
    Rcpp::IntegerVector candidate_rank(n), polarity(n), id_level(n), shared_fragments(n), db_ms2_size(n), exp_ms2_size(n);
    Rcpp::NumericVector db_mass(n), exp_mass(n), error_mass(n), db_rt(n), exp_rt(n), error_rt(n), intensity(n), area(n), score(n), cosine_similarity(n), xLogP(n);
    for (std::size_t i = 0; i < n; ++i)
    {
      const auto &row = rows[i];
      project_id[i] = row.project_id;
      analysis[i] = row.analysis;
      feature[i] = row.feature;
      feature_group[i] = row.feature_group.empty() ? NA_STRING : Rcpp::String(row.feature_group);
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
      db_ms2_smiles[i] = row.db_ms2_smiles.empty() ? NA_STRING : Rcpp::String(row.db_ms2_smiles);
      exp_ms2_size[i] = row.exp_ms2_size;
      exp_ms2_mz[i] = row.exp_ms2_mz.empty() ? NA_STRING : Rcpp::String(row.exp_ms2_mz);
      exp_ms2_intensity[i] = row.exp_ms2_intensity.empty() ? NA_STRING : Rcpp::String(row.exp_ms2_intensity);
      created_at[i] = row.created_at.empty() ? NA_STRING : Rcpp::String(row.created_at);
    }
    Rcpp::List out = Rcpp::List::create(
        Rcpp::Named("project_id") = project_id,
        Rcpp::Named("analysis") = analysis,
        Rcpp::Named("feature") = feature,
        Rcpp::Named("feature_group") = feature_group,
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
        Rcpp::Named("db_ms2_smiles") = db_ms2_smiles,
        Rcpp::Named("exp_ms2_size") = exp_ms2_size,
        Rcpp::Named("exp_ms2_mz") = exp_ms2_mz,
        Rcpp::Named("exp_ms2_intensity") = exp_ms2_intensity,
        Rcpp::Named("created_at") = created_at);
    out.attr("class") = Rcpp::CharacterVector::create("data.table", "data.frame");
    return out;
  }

  Rcpp::List nta_internal_standard_rows_to_dt(const std::vector<nta::api::NTA_INTERNAL_STANDARD_ROW> &rows)
  {
    const std::size_t n = rows.size();
    if (n == 0)
    {
      return get_empty_dt();
    }
    Rcpp::CharacterVector project_id(n), analysis(n), feature(n), feature_group(n), feature_component(n), adduct(n), name(n), formula(n), smiles(n), inchi(n), inchikey(n), database_id(n), db_ms2_mz(n), db_ms2_intensity(n), db_ms2_formula(n), db_ms2_smiles(n), exp_ms2_mz(n), exp_ms2_intensity(n), created_at(n);
    Rcpp::IntegerVector candidate_rank(n), polarity(n), id_level(n), shared_fragments(n), db_ms2_size(n), exp_ms2_size(n);
    Rcpp::NumericVector db_mass(n), exp_mass(n), error_mass(n), db_rt(n), exp_rt(n), error_rt(n), intensity(n), area(n), score(n), cosine_similarity(n), xLogP(n);
    for (std::size_t i = 0; i < n; ++i)
    {
      const auto &row = rows[i];
      project_id[i] = row.project_id;
      analysis[i] = row.analysis;
      feature[i] = row.feature;
      feature_group[i] = row.feature_group.empty() ? NA_STRING : Rcpp::String(row.feature_group);
      feature_component[i] = row.feature_component.empty() ? NA_STRING : Rcpp::String(row.feature_component);
      adduct[i] = row.adduct.empty() ? NA_STRING : Rcpp::String(row.adduct);
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
      db_ms2_smiles[i] = row.db_ms2_smiles.empty() ? NA_STRING : Rcpp::String(row.db_ms2_smiles);
      exp_ms2_size[i] = row.exp_ms2_size;
      exp_ms2_mz[i] = row.exp_ms2_mz.empty() ? NA_STRING : Rcpp::String(row.exp_ms2_mz);
      exp_ms2_intensity[i] = row.exp_ms2_intensity.empty() ? NA_STRING : Rcpp::String(row.exp_ms2_intensity);
      created_at[i] = row.created_at.empty() ? NA_STRING : Rcpp::String(row.created_at);
    }
    Rcpp::List out = Rcpp::List::create(
        Rcpp::Named("project_id") = project_id,
        Rcpp::Named("analysis") = analysis,
        Rcpp::Named("feature") = feature,
        Rcpp::Named("feature_group") = feature_group,
        Rcpp::Named("feature_component") = feature_component,
        Rcpp::Named("adduct") = adduct,
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
        Rcpp::Named("db_ms2_smiles") = db_ms2_smiles,
        Rcpp::Named("exp_ms2_size") = exp_ms2_size,
        Rcpp::Named("exp_ms2_mz") = exp_ms2_mz,
        Rcpp::Named("exp_ms2_intensity") = exp_ms2_intensity,
        Rcpp::Named("created_at") = created_at);
    out.attr("class") = Rcpp::CharacterVector::create("data.table", "data.frame");
    return out;
  }

  Rcpp::List nta_transformation_product_rows_to_dt(const std::vector<nta::api::NTA_TRANSFORMATION_PRODUCT_ROW> &rows)
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

  Rcpp::List features_as_list_of_dt(const std::vector<nta::api::NTA_FEATURES> &features,
                                    const std::vector<std::string> &analyses)
  {
    const int n = static_cast<int>(features.size());
    Rcpp::List out(n);
    if (n == 0)
    {
      return out;
    }
    for (int i = 0; i < n; i++)
    {
      out[i] = features_to_list_dt(features[static_cast<std::size_t>(i)]);
    }
    Rcpp::CharacterVector names(n);
    for (int i = 0; i < n; i++)
    {
      names[i] = analyses[static_cast<std::size_t>(i)];
    }
    out.attr("names") = names;
    return out;
  }

  Rcpp::List features_as_list_of_dt(const nta::PROJECT_NON_TARGET_ANALYSIS &nta_data)
  {
    return features_as_list_of_dt(nta_data.feature_buffers(), nta_data.analysis_names());
  }

  Rcpp::List suspects_to_list_dt(const nta::api::NTA_SUSPECTS &sus)
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
        Rcpp::Named("db_ms2_smiles") = as_char_vector(sus.db_ms2_smiles),
        Rcpp::Named("exp_ms2_size") = sus.exp_ms2_size,
        Rcpp::Named("exp_ms2_mz") = as_char_vector(sus.exp_ms2_mz),
        Rcpp::Named("exp_ms2_intensity") = as_char_vector(sus.exp_ms2_intensity));

    out.attr("class") = Rcpp::CharacterVector::create("data.table", "data.frame");
    return out;
  }

  Rcpp::List suspects_as_list_of_dt(const nta::PROJECT_NON_TARGET_ANALYSIS &nta_data)
  {
    const auto &suspects = nta_data.suspect_buffers();
    const auto &analysis_names = nta_data.analysis_names();
    const int n = static_cast<int>(suspects.size());
    Rcpp::List out(n);
    if (n == 0)
    {
      return out;
    }
    for (int i = 0; i < n; i++)
    {
      out[i] = suspects_to_list_dt(suspects[static_cast<std::size_t>(i)]);
    }
    Rcpp::CharacterVector names(n);
    for (int i = 0; i < n; i++)
    {
      names[i] = analysis_names[static_cast<std::size_t>(i)];
    }
    out.attr("names") = names;
    return out;
  }

  Rcpp::List internal_standards_to_list_dt(const nta::api::NTA_INTERNAL_STANDARDS &istd)
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
        Rcpp::Named("db_ms2_smiles") = as_char_vector(istd.db_ms2_smiles),
        Rcpp::Named("exp_ms2_size") = istd.exp_ms2_size,
        Rcpp::Named("exp_ms2_mz") = as_char_vector(istd.exp_ms2_mz),
        Rcpp::Named("exp_ms2_intensity") = as_char_vector(istd.exp_ms2_intensity));

    out.attr("class") = Rcpp::CharacterVector::create("data.table", "data.frame");
    return out;
  }

  Rcpp::List internal_standards_as_list_of_dt(const nta::PROJECT_NON_TARGET_ANALYSIS &nta_data)
  {
    const auto &internal_standards = nta_data.internal_standard_buffers();
    const auto &analysis_names = nta_data.analysis_names();
    const int n = static_cast<int>(internal_standards.size());
    Rcpp::List out(n);
    if (n == 0)
    {
      return out;
    }
    for (int i = 0; i < n; i++)
    {
      out[i] = internal_standards_to_list_dt(internal_standards[static_cast<std::size_t>(i)]);
    }
    Rcpp::CharacterVector names(n);
    for (int i = 0; i < n; i++)
    {
      names[i] = analysis_names[static_cast<std::size_t>(i)];
    }
    out.attr("names") = names;
    return out;
  }

  std::vector<nta::suspect_screening::SuspectQuery> as_suspect_queries(const Rcpp::List &suspects_list)
  {
    std::vector<nta::suspect_screening::SuspectQuery> out;
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
      nta::suspect_screening::SuspectQuery s;
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
      const nta::api::NTA_TRANSFORMATION_PRODUCTS &tp)
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
        Rcpp::Named("main_precursor_rt_plausibility")    = as_numeric_vector(tp.main_precursor_rt_plausibility),
        Rcpp::Named("product_structure_key")             = as_char_vector(tp.product_structure_key),
        Rcpp::Named("precursor_structure_key")           = as_char_vector(tp.precursor_structure_key),
        Rcpp::Named("main_precursor_structure_key")      = as_char_vector(tp.main_precursor_structure_key),
        Rcpp::Named("resolved_direct_parent_feature_group") = as_char_vector(tp.resolved_direct_parent_feature_group),
        Rcpp::Named("resolved_main_parent_feature_group") = as_char_vector(tp.resolved_main_parent_feature_group),
        Rcpp::Named("assignment_status")                 = as_char_vector(tp.assignment_status),
        Rcpp::Named("is_direct_assignment")              = tp.is_direct_assignment,
        Rcpp::Named("is_main_parent_consistent")         = tp.is_main_parent_consistent,
        Rcpp::Named("transformation_valid")              = tp.transformation_valid,
        Rcpp::Named("assignment_rank")                   = tp.assignment_rank,
        Rcpp::Named("network_level")                     = tp.network_level,
        Rcpp::Named("assignment_score")                  = as_numeric_vector(tp.assignment_score),
        Rcpp::Named("transformation_mass_delta_expected") = as_numeric_vector(tp.transformation_mass_delta_expected),
        Rcpp::Named("transformation_mass_delta_observed") = as_numeric_vector(tp.transformation_mass_delta_observed),
        Rcpp::Named("transformation_mass_delta_error")   = as_numeric_vector(tp.transformation_mass_delta_error));

    out.attr("class") = Rcpp::CharacterVector::create("data.table", "data.frame");
    return out;
  }

} // namespace nta_rcpp

// [[Rcpp::export]]
SEXP rcpp_project_non_target_analysis_new(SEXP project_xptr)
{
  return nta_rcpp::project_call([&]() {
    auto *ptr = new nta::PROJECT_NON_TARGET_ANALYSIS(nta_rcpp::project_from_xptr(project_xptr).context());
    Rcpp::XPtr<nta::PROJECT_NON_TARGET_ANALYSIS> out(ptr, true);
    out.attr("class") = "streamfindProjectNonTargetAnalysis";
    return SEXP(out);
  });
}

// [[Rcpp::export]]
Rcpp::List rcpp_project_non_target_analysis_get_features(
  SEXP nta_xptr,
  SEXP analyses,
  SEXP features,
  SEXP groups,
  SEXP components,
  SEXP mass,
  SEXP mz,
  SEXP rt,
  SEXP mobility,
  double ppm,
  double sec,
  double millisec,
  bool include_filtered)
{
  return  nta_rcpp::project_call([&]() {
    const auto query = nta_rcpp::build_nts_query_request(
      analyses,
      features,
      groups,
      components,
      mass,
      mz,
      rt,
      mobility,
      ppm,
      sec,
      millisec,
      include_filtered
    );
    return nta_rcpp::nta_feature_rows_to_dt(
      nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr).get_features(query)
    );
  });
}

// [[Rcpp::export]]
Rcpp::List rcpp_project_non_target_analysis_get_features_count(
  SEXP nta_xptr,
  CharacterVector analyses,
  bool include_filtered)
{
  return nta_rcpp::project_call([&]() {
    return nta_rcpp::nta_feature_count_rows_to_dt(
      nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr).get_features_count(
        Rcpp::as<std::vector<std::string>>(analyses), include_filtered
      )
    );
  });
}

// [[Rcpp::export]]
Rcpp::List rcpp_project_nta_get_matrix_suppression(
  SEXP nta_xptr,
  Rcpp::CharacterVector analyses = Rcpp::CharacterVector::create(""),
  double rtWindowVal = 10.0,
  Rcpp::Nullable<std::string> refBlankReplicate = R_NilValue)
{
  std::vector<std::string> analyses_sel;
  if (analyses.size() > 0 && analyses[0] != NA_STRING && Rcpp::as<std::string>(analyses[0]) != "")
  {
    analyses_sel = Rcpp::as<std::vector<std::string>>(analyses);
  }

  std::string ref_blank;
  if (refBlankReplicate.isNotNull())
  {
    ref_blank = Rcpp::as<std::string>(refBlankReplicate);
  }

  return nta_rcpp::project_call([&]() {
    return nta_rcpp::nta_matrix_suppression_rows_to_dt(
      nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr).get_matrix_suppression(
        analyses_sel,
        static_cast<float>(rtWindowVal),
        ref_blank)
    );
  });
}

// [[Rcpp::export]]
bool rcpp_project_nta_correct_matrix_suppression(
  SEXP nta_xptr,
  double mpRtWindow = 10.0,
  Rcpp::Nullable<std::string> refBlankReplicate = R_NilValue)
{
  std::string ref_blank;
  if (refBlankReplicate.isNotNull())
  {
    ref_blank = Rcpp::as<std::string>(refBlankReplicate);
  }

  return nta_rcpp::project_call([&]() {
    auto &nta_data = nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr);
    return nta_data.correct_matrix_suppression(static_cast<float>(mpRtWindow), ref_blank);
  });
}

// [[Rcpp::export]]
Rcpp::List rcpp_project_non_target_analysis_get_suspects(
  SEXP nta_xptr,
  SEXP analyses,
  SEXP features,
  SEXP groups,
  SEXP mass,
  SEXP mz,
  SEXP rt,
  SEXP mobility,
  double ppm,
  double sec,
  double millisec)
{
  return nta_rcpp::project_call([&]() {
    auto query = nta_rcpp::build_nts_query_request(
      analyses,
      features,
      groups,
      R_NilValue,
      mass,
      mz,
      rt,
      mobility,
      ppm,
      sec,
      millisec,
      true
    );
    return nta_rcpp::nta_suspect_rows_to_dt(
      nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr).get_suspects(query)
    );
  });
}

// [[Rcpp::export]]
Rcpp::List rcpp_project_non_target_analysis_get_internal_standards(
  SEXP nta_xptr,
  SEXP analyses,
  SEXP features,
  SEXP groups,
  SEXP mass,
  SEXP mz,
  SEXP rt,
  SEXP mobility,
  double ppm,
  double sec,
  double millisec)
{
  return nta_rcpp::project_call([&]() {
    auto query = nta_rcpp::build_nts_query_request(
      analyses,
      features,
      groups,
      R_NilValue,
      mass,
      mz,
      rt,
      mobility,
      ppm,
      sec,
      millisec,
      true
    );
    return nta_rcpp::nta_internal_standard_rows_to_dt(
      nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr).get_internal_standards(query)
    );
  });
}

// [[Rcpp::export]]
Rcpp::List rcpp_project_non_target_analysis_get_transformation_products(SEXP nta_xptr)
{
  return nta_rcpp::project_call([&]() {
    return nta_rcpp::nta_transformation_product_rows_to_dt(
      nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr).get_transformation_products()
    );
  });
}

// [[Rcpp::export]]
bool rcpp_project_non_target_analysis_assign_transformation_products(
  SEXP nta_xptr,
  Rcpp::List transformation_products,
  std::string chromatographic_phase = "reverse_phase",
  double mzrMS2 = 0.008)
{
  return nta_rcpp::project_call([&]() {
    std::vector<nta::api::NTA_TRANSFORMATION_PRODUCT_ROW> tp_rows;
      if (transformation_products.size() > 0)
      {
        auto require_col = [&](const char *col) {
          if (!transformation_products.containsElementNamed(col))
            Rcpp::stop("transformation_products must include '%s' column.", col);
        };
        auto get_col_obj = [&](const char *col) -> Rcpp::RObject {
          require_col(col);
          return transformation_products[col];
        };
        auto coerce_chr = [&](const char *col) -> Rcpp::CharacterVector {
          Rcpp::RObject obj = get_col_obj(col);
          if (TYPEOF(obj) == STRSXP && !Rf_isObject(obj))
            return Rcpp::as<Rcpp::CharacterVector>(obj);
          if (TYPEOF(obj) == VECSXP) {
            Rcpp::List lst = Rcpp::as<Rcpp::List>(obj);
            R_xlen_t sz = lst.size();
            Rcpp::CharacterVector out = Rcpp::no_init(sz);
            for (R_xlen_t i = 0; i < sz; ++i) {
              if (lst[i] == R_NilValue) {
                out[i] = NA_STRING;
              } else {
                Rcpp::RObject elem = lst[i];
                if (TYPEOF(elem) == STRSXP) {
                  Rcpp::CharacterVector tmp(elem);
                  out[i] = tmp[0];
                } else {
                  out[i] = Rcpp::as<std::string>(Rcpp::Function("as.character")(elem));
                }
              }
            }
            return out;
          }
          Rcpp::Function as_character("as.character");
          return Rcpp::as<Rcpp::CharacterVector>(as_character(obj));
        };
        auto coerce_num = [&](const char *col) -> Rcpp::NumericVector {
          Rcpp::RObject obj = get_col_obj(col);
          if (TYPEOF(obj) == VECSXP) {
            Rcpp::List lst = Rcpp::as<Rcpp::List>(obj);
            R_xlen_t sz = lst.size();
            Rcpp::NumericVector out = Rcpp::no_init(sz);
            Rcpp::Function as_numeric("as.numeric");
            for (R_xlen_t i = 0; i < sz; ++i) {
              if (lst[i] == R_NilValue) {
                out[i] = NA_REAL;
              } else {
                Rcpp::RObject elem = lst[i];
                if (TYPEOF(elem) == REALSXP) {
                  Rcpp::NumericVector tmp(elem);
                  out[i] = tmp[0];
                } else if (TYPEOF(elem) == INTSXP || TYPEOF(elem) == LGLSXP) {
                  Rcpp::IntegerVector tmp(elem);
                  out[i] = (tmp[0] == NA_INTEGER) ? NA_REAL : static_cast<double>(tmp[0]);
                } else {
                  out[i] = Rcpp::as<Rcpp::NumericVector>(as_numeric(elem))[0];
                }
              }
            }
            return out;
          }
          if ((TYPEOF(obj) == REALSXP || TYPEOF(obj) == INTSXP || TYPEOF(obj) == LGLSXP) && !Rf_isObject(obj))
            return Rcpp::as<Rcpp::NumericVector>(obj);
          Rcpp::Function as_numeric("as.numeric");
          return Rcpp::as<Rcpp::NumericVector>(as_numeric(obj));
        };

        require_col("name");
        require_col("transformation");
        require_col("precursor_name");
        require_col("precursor_formula");
        require_col("precursor_mass");
        require_col("precursor_SMILES");
        require_col("precursor_InChI");
        require_col("precursor_InChIKey");
        require_col("precursor_xLogP");
        require_col("main_precursor_name");
        require_col("main_precursor_formula");
        require_col("main_precursor_mass");
        require_col("main_precursor_SMILES");
        require_col("main_precursor_InChI");
        require_col("main_precursor_InChIKey");
        require_col("main_precursor_xLogP");

        const Rcpp::CharacterVector name_vec = coerce_chr("name");
        const int n = name_vec.size();

        auto get_str = [&](const char *col) {
          Rcpp::CharacterVector v = coerce_chr(col);
          if (v.size() != n)
            Rcpp::stop("transformation_products column '%s' has length %d, expected %d.", col, v.size(), n);
          std::vector<std::string> out;
          out.reserve(v.size());
          for (int i = 0; i < v.size(); ++i)
            out.push_back((v[i] == NA_STRING) ? "" : Rcpp::as<std::string>(v[i]));
          return out;
        };
        auto get_dbl = [&](const char *col) {
          Rcpp::NumericVector v = coerce_num(col);
          if (v.size() != n)
            Rcpp::stop("transformation_products column '%s' has length %d, expected %d.", col, v.size(), n);
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

        for (int i = 0; i < n; ++i)
        {
          nta::api::NTA_TRANSFORMATION_PRODUCT_ROW row;
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
          tp_rows.push_back(std::move(row));
        }
      }

      auto &nta_data = nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr);
      return nta_data.assign_transformation_products(tp_rows, chromatographic_phase, mzrMS2);
  });
}

// MARK: rcpp_project_nta_find_features
// [[Rcpp::export]]
bool rcpp_project_nta_find_features(SEXP nta_xptr,
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
                            int debugSpecIdx = -1)
{
  return nta_rcpp::project_call([&]() {
    auto &nta_data = nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr);
    return nta_data.find_features(
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
      debugSpecIdx);
  });
}

// MARK: rcpp_project_nta_load_features_ms1
// [[Rcpp::export]]
bool rcpp_project_nta_load_features_ms1(SEXP nta_xptr,
                                bool filtered,
                                std::vector<float> rtWindow,
                                std::vector<float> mzWindow,
                                float minTracesIntensity,
                                float mzClust,
                                float presence)
{
  return nta_rcpp::project_call([&]() {
    auto &nta_data = nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr);
    return nta_data.load_features_ms1(filtered, rtWindow, mzWindow, minTracesIntensity, mzClust, presence);
  });
}

// MARK: rcpp_project_nta_load_features_ms2
// [[Rcpp::export]]
bool rcpp_project_nta_load_features_ms2(SEXP nta_xptr,
                                bool filtered,
                                float minTracesIntensity,
                                float isolationWindow,
                                float mzClust,
                                float presence)
{
  return nta_rcpp::project_call([&]() {
    auto &nta_data = nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr);
    return nta_data.load_features_ms2(filtered, minTracesIntensity, isolationWindow, mzClust, presence);
  });
}

// MARK: rcpp_project_nta_create_components
// [[Rcpp::export]]
bool rcpp_project_nta_create_components(SEXP nta_xptr,
                                std::vector<float> rtWindow,
                                float minCorrelation = 0.8,
                                float debugRT = 0.0,
                                std::string debugAnalysis = "")
{
  return nta_rcpp::project_call([&]() {
    auto &nta_data = nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr);
    return nta_data.create_components(rtWindow, minCorrelation, debugRT, debugAnalysis);
  });
}

// MARK: rcpp_project_nta_annotate_components
// [[Rcpp::export]]
bool rcpp_project_nta_annotate_components(SEXP nta_xptr,
                                  int maxIsotopes = 5,
                                  int maxCharge = 1,
                                  int maxGaps = 1,
                                  float ppm = 10.0,
                                  Rcpp::CharacterVector isotopeElements = Rcpp::CharacterVector::create("C:1-60", "N:0-10", "O:0-20", "S:0-4", "Cl:0-6", "Br:0-4"),
                                  std::string debugComponent = "",
                                  std::string debugAnalysis = "")
{
  return nta_rcpp::project_call([&]() {
    auto &nta_data = nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr);
    return nta_data.annotate_components(
      maxIsotopes,
      maxCharge,
      maxGaps,
      ppm,
      Rcpp::as<std::vector<std::string>>(isotopeElements),
      debugComponent,
      debugAnalysis
    );
  });
}

// MARK: rcpp_project_nta_group_features
// [[Rcpp::export]]
bool rcpp_project_nta_group_features(SEXP nta_xptr,
                             std::string method = "obi_warp",
                             float rtDeviation = 5.0,
                             float ppm = 5.0,
                             int minSamples = 1,
                             float binSize = 5.0,
                             bool debug = false,
                             float debugRT = 0.0)
{
  return nta_rcpp::project_call([&]() {
    auto &nta_data = nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr);
    return nta_data.group_features(method, rtDeviation, ppm, minSamples, binSize, debug, debugRT);
  });
}

// MARK: rcpp_project_nta_fill_features
// [[Rcpp::export]]
bool rcpp_project_nta_fill_features(SEXP nta_xptr,
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
  return nta_rcpp::project_call([&]() {
    auto &nta_data = nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr);
    return nta_data.fill_features(
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

// MARK: rcpp_project_nta_blank_subtraction
// [[Rcpp::export]]
bool rcpp_project_nta_blank_subtraction(SEXP nta_xptr,
                                float blankThreshold = 5.0,
                                float rtExpand = 10.0,
                                float mzExpand = 0.005)
{
  return nta_rcpp::project_call([&]() {
    auto &nta_data = nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr);
    return nta_data.subtract_blank(blankThreshold, rtExpand, mzExpand);
  });
}

// MARK: rcpp_project_nta_filter_features
// [[Rcpp::export]]
bool rcpp_project_nta_filter_features(
  SEXP nta_xptr,
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
  bool hasOnlyFilled = (onlyFilled.size() > 0 && onlyFilled[0] != NA_LOGICAL);
  bool onlyFilledValue = hasOnlyFilled ? static_cast<bool>(onlyFilled[0]) : false;
  bool hasMaxModality = (maxModality != NA_INTEGER);
  bool hasMinSizeEIC = (minSizeEIC != NA_INTEGER);
  bool hasMinSizeMS1 = (minSizeMS1 != NA_INTEGER);
  bool hasMinSizeMS2 = (minSizeMS2 != NA_INTEGER);

  return nta_rcpp::project_call([&]() {
    auto &nta_data = nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr);
    return nta_data.filter_features(
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
  });
}

// MARK: rcpp_project_nta_filter_suspects
// [[Rcpp::export]]
bool rcpp_project_nta_filter_suspects(
  SEXP nta_xptr,
    Rcpp::CharacterVector names = Rcpp::CharacterVector::create(),
    double minScore = NA_REAL,
    double maxErrorRT = NA_REAL,
    double maxErrorMass = NA_REAL,
    Rcpp::IntegerVector idLevels = Rcpp::IntegerVector::create(),
    int minSharedFragments = 0,
    double minCosineSimilarity = NA_REAL)
{
  std::vector<std::string> names_cpp = Rcpp::as<std::vector<std::string>>(names);
  std::vector<int> idLevels_cpp = Rcpp::as<std::vector<int>>(idLevels);

  return nta_rcpp::project_call([&]() {
    auto &nta_data = nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr);
    return nta_data.filter_suspects(names_cpp, minScore, maxErrorRT, maxErrorMass, idLevels_cpp, minSharedFragments, minCosineSimilarity);
  });
}

// MARK: rcpp_project_nta_filter_internal_standards
// [[Rcpp::export]]
bool rcpp_project_nta_filter_internal_standards(
  SEXP nta_xptr,
    Rcpp::CharacterVector names = Rcpp::CharacterVector::create(),
    double minScore = NA_REAL,
    double maxErrorRT = NA_REAL,
    double maxErrorMass = NA_REAL,
    Rcpp::IntegerVector idLevels = Rcpp::IntegerVector::create(),
    int minSharedFragments = 0,
    double minCosineSimilarity = NA_REAL)
{
  std::vector<std::string> names_cpp = Rcpp::as<std::vector<std::string>>(names);
  std::vector<int> idLevels_cpp = Rcpp::as<std::vector<int>>(idLevels);

  return nta_rcpp::project_call([&]() {
    auto &nta_data = nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr);
    return nta_data.filter_internal_standards(names_cpp, minScore, maxErrorRT, maxErrorMass, idLevels_cpp, minSharedFragments, minCosineSimilarity);
  });
}

// MARK: rcpp_project_nta_find_internal_standards
// [[Rcpp::export]]
bool rcpp_project_nta_find_internal_standards(
  SEXP nta_xptr,
    Rcpp::List suspects,
    Rcpp::CharacterVector analyses = Rcpp::CharacterVector::create(""),
    double ppm = 5.0,
    double sec = 10.0,
    double ppmMS2 = 10.0,
    double mzrMS2 = 0.008,
    double minCosineSimilarity = 0.7,
    int minSharedFragments = 3,
    bool filtered = true)
{
  std::vector<std::string> analyses_sel;
  if (analyses.size() > 0 && analyses[0] != NA_STRING && Rcpp::as<std::string>(analyses[0]) != "")
  {
    analyses_sel = Rcpp::as<std::vector<std::string>>(analyses);
  }

  std::vector<nta::suspect_screening::SuspectQuery> suspects_cpp = nta_rcpp::as_suspect_queries(suspects);
  return nta_rcpp::project_call([&]() {
    auto &nta_data = nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr);
    return nta_data.find_internal_standards(
      analyses_sel,
      suspects_cpp,
      ppm,
      sec,
      ppmMS2,
      mzrMS2,
      minCosineSimilarity,
      minSharedFragments,
      filtered);
  });
}

// MARK: rcpp_project_nta_suspect_screening
// [[Rcpp::export]]
bool rcpp_project_nta_suspect_screening(
  SEXP nta_xptr,
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
  std::vector<std::string> analyses_sel;
  if (analyses.size() > 0 && analyses[0] != NA_STRING && Rcpp::as<std::string>(analyses[0]) != "")
  {
    analyses_sel = Rcpp::as<std::vector<std::string>>(analyses);
  }

  std::vector<nta::suspect_screening::SuspectQuery> suspects_cpp = nta_rcpp::as_suspect_queries(suspects);
  return nta_rcpp::project_call([&]() {
    auto &nta_data = nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr);
    return nta_data.suspect_screening(
      analyses_sel,
      suspects_cpp,
      ppm,
      sec,
      ppmMS2,
      mzrMS2,
      minCosineSimilarity,
      minSharedFragments,
      filtered);
  });
}

// MARK: rcpp_project_nta_filter_features_ms2
// [[Rcpp::export]]
bool rcpp_project_nta_filter_features_ms2(
  SEXP nta_xptr,
    int top = 0,
    double minIntensity = NA_REAL,
    double relMinIntensity = NA_REAL,
    bool blankClean = false,
    double mzClust = 0.005,
    double blankPresenceThreshold = 0.8,
    double globalPresenceThreshold = 0.1)
{
  return nta_rcpp::project_call([&]() {
    auto &nta_data = nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr);
    return nta_data.filter_features_ms2(
      top,
      std::isnan(minIntensity) ? std::numeric_limits<float>::quiet_NaN()
                               : static_cast<float>(minIntensity),
      std::isnan(relMinIntensity) ? std::numeric_limits<float>::quiet_NaN()
                                  : static_cast<float>(relMinIntensity),
      blankClean,
      static_cast<float>(mzClust),
      static_cast<float>(blankPresenceThreshold),
      static_cast<float>(globalPresenceThreshold));
  });
}

// MARK: rcpp_project_nta_metfrag_screening
// [[Rcpp::export]]
bool rcpp_project_nta_metfrag_screening(
  SEXP nta_xptr,
    std::string metfrag_path,
    std::string database_type = "PubChem",
    std::string database_path = "",
    SEXP database = R_NilValue,
    Rcpp::CharacterVector analyses = Rcpp::CharacterVector::create(""),
    double ppm = 5.0,
    double sec = 10.0,
    double ppmMS2 = 10.0,
    double mzrMS2 = 0.008,
    int top_n = 1,
    Rcpp::CharacterVector score_types = Rcpp::CharacterVector::create("FragmenterScore"),
    Rcpp::NumericVector score_weights = Rcpp::NumericVector::create(1.0),
    Rcpp::CharacterVector pre_processing_candidate_filter = Rcpp::CharacterVector::create("UnconnectedCompoundFilter", "IsotopeFilter"),
    Rcpp::CharacterVector post_processing_candidate_filter = Rcpp::CharacterVector::create("InChIKeyFilter"),
    int maximum_tree_depth = 2,
    int number_threads = 1,
    bool use_smiles = true,
    bool filtered = false,
    std::string java_path = "java",
    std::string run_dir = "",
    Rcpp::List extra_params = R_NilValue)
{
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

  nta::metfrag_runner::MetFragParams p;
  p.metfrag_path   = metfrag_path;
  p.database_type  = nta::metfrag_runner::canonicalize_database_type(database_type);
  p.database_path  = database_path;
  p.ppm            = ppm;
  p.sec            = sec;
  p.ppmMS2         = ppmMS2;
  p.mzrMS2         = mzrMS2;
  p.top_n          = top_n;
  p.score_types    = Rcpp::as<std::vector<std::string>>(score_types);
  p.score_weights  = Rcpp::as<std::vector<double>>(score_weights);
  p.pre_processing_candidate_filter = Rcpp::as<std::vector<std::string>>(pre_processing_candidate_filter);
  p.post_processing_candidate_filter = Rcpp::as<std::vector<std::string>>(post_processing_candidate_filter);
  p.maximum_tree_depth = maximum_tree_depth;
  p.number_threads = number_threads;
  p.use_smiles = use_smiles;
  p.filtered       = filtered;
  p.java_path      = java_path;
  p.run_dir        = run_dir;
  p.extra_params   = extra_params_cpp;
  p.run_dir        = nta::metfrag_runner::resolve_run_dir(p);

  if (p.database_type == "LocalCSV")
  {
    if (Rf_isNull(database))
    {
      Rcpp::stop("Local MetFrag screening requires a non-empty database data.table.");
    }
    fs::create_directories(p.run_dir);
    Rcpp::DataFrame local_database(database);
    p.database_path = nta_rcpp::write_local_metfrag_database(local_database, p.run_dir);
  }

  return nta_rcpp::project_call([&]() {
      auto &nta_data = nta_rcpp::project_non_target_analysis_from_xptr(nta_xptr);
      return nta_data.metfrag_screening(analyses_sel, p);
  });
};

// MARK: rcpp_project_nta_assign_transformation_products
// [[Rcpp::export]]
Rcpp::List rcpp_project_nta_assign_transformation_products(
    Rcpp::List suspects,
    Rcpp::List transformation_products,
    std::string chromatographic_phase = "reverse_phase",
    double mzrMS2 = 0.008)
{
  // ── Parse suspects ──────────────────────────────────────────────────────────
  std::vector<nta::api::NTA_SUSPECT_ROW> suspects_cpp;
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
      nta::api::NTA_SUSPECT_ROW s;
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
  std::vector<nta::api::NTA_TRANSFORMATION_PRODUCT_ROW> tp_rows;
  if (transformation_products.size() > 0)
  {
    Rcpp::CharacterVector name_r = transformation_products["name"];
    const int n = name_r.size();
    auto require_col = [&](const char *col) {
      if (!transformation_products.containsElementNamed(col))
      {
        Rcpp::stop("transformation_products must include '%s' column.", col);
      }
    };
    require_col("name");
    require_col("transformation");
    require_col("precursor_name");
    require_col("precursor_formula");
    require_col("precursor_mass");
    require_col("precursor_SMILES");
    require_col("precursor_InChI");
    require_col("precursor_InChIKey");
    require_col("precursor_xLogP");
    require_col("main_precursor_name");
    require_col("main_precursor_formula");
    require_col("main_precursor_mass");
    require_col("main_precursor_SMILES");
    require_col("main_precursor_InChI");
    require_col("main_precursor_InChIKey");
    require_col("main_precursor_xLogP");
    auto get_str = [&](const char *col) {
      require_col(col);
      Rcpp::CharacterVector v = transformation_products[col];
      std::vector<std::string> out;
      out.reserve(v.size());
      for (int i = 0; i < v.size(); ++i)
        out.push_back((v[i] == NA_STRING) ? "" : Rcpp::as<std::string>(v[i]));
      return out;
    };
    auto get_dbl = [&](const char *col) {
      require_col(col);
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

    tp_rows.reserve(n);
    for (int i = 0; i < n; ++i)
    {
      nta::api::NTA_TRANSFORMATION_PRODUCT_ROW r;
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

  nta::api::NTA_TRANSFORMATION_PRODUCTS result =
      nta::assign_transformation_products::assign_transformation_products_impl(
          suspects_cpp, tp_rows, chromatographic_phase, mzrMS2);

  return nta_rcpp::transformation_products_to_dt(result);
};
