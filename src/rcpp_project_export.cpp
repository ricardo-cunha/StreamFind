#include <Rcpp.h>

#include "mass_spec/reader.h"
#include "mass_spec/mass_spec.h"
#include "project/project.h"

using namespace Rcpp;

// MARK: ns project_rcpp

namespace project_rcpp
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

  project::PROJECT &project_from_xptr(SEXP extptr)
  {
    Rcpp::XPtr<project::PROJECT> ptr(extptr);
    if (ptr.get() == nullptr)
    {
      stop("Project pointer is null");
    }
    return *ptr;
  }

  DataFrame audit_rows_to_df(const std::vector<project::audit_trail::AUDIT_TRAIL_ROW> &rows)
  {
    CharacterVector project_id(rows.size());
    CharacterVector operation_type(rows.size());
    CharacterVector object_type(rows.size());
    CharacterVector operation_details(rows.size());
    CharacterVector created_at(rows.size());
    for (std::size_t i = 0; i < rows.size(); ++i)
    {
      project_id[i] = rows[i].project_id;
      operation_type[i] = rows[i].operation_type;
      object_type[i] = rows[i].object_type;
      operation_details[i] = project::utils::json_to_text(rows[i].operation_details);
      created_at[i] = rows[i].created_at;
    }
    return DataFrame::create(Named("project_id") = project_id,
                             Named("operation_type") = operation_type,
                             Named("object_type") = object_type,
                             Named("operation_details") = operation_details,
                             Named("created_at") = created_at);
  }

  DataFrame cache_table_to_df(const project::cache::CACHE_TABLE &table)
  {
    const std::size_t count = table.hash.size();
    CharacterVector project_id(count);
    CharacterVector name(count);
    CharacterVector description(count);
    CharacterVector hash(count);
    IntegerVector data_size(count);
    CharacterVector created_at(count);
    for (std::size_t i = 0; i < count; ++i)
    {
      project_id[i] = table.project_id[i];
      name[i] = table.name[i];
      description[i] = table.description[i];
      hash[i] = table.hash[i];
      data_size[i] = static_cast<int>(table.data[i].size());
      created_at[i] = table.created_at[i];
    }
    return DataFrame::create(Named("project_id") = project_id,
                             Named("name") = name,
                             Named("description") = description,
                             Named("hash") = hash,
                             Named("data_size") = data_size,
                             Named("created_at") = created_at);
  }

} // namespace project_rcpp

// MARK: PROJECT EXPORTS

// [[Rcpp::export]]
SEXP rcpp_project_new(std::string db_path, std::string project_id)
{
  return project_rcpp::project_call([&]()
                                    {
    auto* ptr = new project::PROJECT(std::move(db_path), std::move(project_id));
    Rcpp::XPtr<project::PROJECT> out(ptr, true);
    out.attr("class") = "StreamFindProject";
    return SEXP(out); });
}

// [[Rcpp::export]]
std::string rcpp_project_get_domain(SEXP project_xptr)
{
  return project_rcpp::project_call([&]()
                                    { return project_rcpp::project_from_xptr(project_xptr).domain(); });
}

// [[Rcpp::export]]
SEXP rcpp_project_copy(SEXP project_xptr, std::string db_path, std::string project_id)
{
  return project_rcpp::project_call([&]()
                                    {
    auto* ptr = project_rcpp::project_from_xptr(project_xptr).copy(std::move(db_path), std::move(project_id));
    Rcpp::XPtr<project::PROJECT> out(ptr, true);
    out.attr("class") = "StreamFindProject";
    return SEXP(out); });
}

// [[Rcpp::export]]
void rcpp_project_validate(SEXP project_xptr)
{
  project_rcpp::project_call([&]()
                             {
    project_rcpp::project_from_xptr(project_xptr).validate();
    return 0; });
}

// [[Rcpp::export]]
void rcpp_project_close(SEXP project_xptr)
{
  project_rcpp::project_call([&]()
                             {
    project_rcpp::project_from_xptr(project_xptr).close();
    return 0; });
}

// [[Rcpp::export]]
std::string rcpp_project_get_metadata(SEXP project_xptr)
{
  return project_rcpp::project_call([&]()
                                    { return project::utils::json_to_text(project_rcpp::project_from_xptr(project_xptr).metadata()); });
}

// [[Rcpp::export]]
void rcpp_project_set_metadata(SEXP project_xptr, std::string metadata_json)
{
  project_rcpp::project_call([&]()
                             {
    project_rcpp::project_from_xptr(project_xptr).set_metadata(project::utils::json_from_text(metadata_json));
    return 0; });
}

// [[Rcpp::export]]
std::string rcpp_project_get_workflow(SEXP project_xptr)
{
  return project_rcpp::project_call([&]()
                                    { return project::utils::json_to_text(project_rcpp::project_from_xptr(project_xptr).workflow()); });
}

// [[Rcpp::export]]
void rcpp_project_set_workflow(SEXP project_xptr, std::string workflow_json)
{
  project_rcpp::project_call([&]()
                             {
    project_rcpp::project_from_xptr(project_xptr).set_workflow(project::utils::json_from_text(workflow_json));
    return 0; });
}

// [[Rcpp::export]]
CharacterVector rcpp_project_list_tables(SEXP project_xptr)
{
  return project_rcpp::project_call([&]()
                                    {
    const auto tables = project_rcpp::project_from_xptr(project_xptr).list_tables();
    return CharacterVector(tables.begin(), tables.end()); });
}

// [[Rcpp::export]]
DataFrame rcpp_project_get_audit(SEXP project_xptr)
{
  return project_rcpp::project_call([&]()
                                    {
    const auto out = project_rcpp::project_from_xptr(project_xptr).get_audit();
    return project_rcpp::audit_rows_to_df(out); });
}

// [[Rcpp::export]]
double rcpp_project_get_cache_size(SEXP project_xptr)
{
  return project_rcpp::project_call([&]()
                                    { return static_cast<double>(project_rcpp::project_from_xptr(project_xptr).get_cache_size()); });
}

// [[Rcpp::export]]
DataFrame rcpp_project_get_cache(SEXP project_xptr)
{
  return project_rcpp::project_call([&]()
                                    {
    const auto out = project_rcpp::project_from_xptr(project_xptr).get_cache();
    return project_rcpp::cache_table_to_df(out); });
}

// [[Rcpp::export]]
void rcpp_project_delete_cache(SEXP project_xptr, Nullable<std::string> name = R_NilValue)
{
  project_rcpp::project_call([&]()
                             {
    project_rcpp::project_from_xptr(project_xptr).delete_cache(name.isNull() ? std::string() : Rcpp::as<std::string>(name));
    return 0; });
}

// [[Rcpp::export]]
std::vector<float> rcpp_decode_string(std::string base64_encoded)
{
  if (base64_encoded.empty())
    return std::vector<float>();
  try
  {
    std::string decoded_binary = mass_spec::reader::utils::decode_base64(base64_encoded);
    return mass_spec::reader::utils::decode_little_endian_to_float(decoded_binary, 4);
  }
  catch (const std::exception &e)
  {
    Rcpp::warning(std::string("Failed to decode string: ") + e.what());
    return std::vector<float>();
  }
}

// MARK: ns mass_spec_rcpp

namespace mass_spec_rcpp
{
  mass_spec::PROJECT_MASS_SPEC &project_mass_spec_from_xptr(SEXP extptr)
  {
    Rcpp::XPtr<mass_spec::PROJECT_MASS_SPEC> ptr(extptr);
    if (ptr.get() == nullptr)
    {
      stop("Project Mass Spec pointer is null");
    }
    return *ptr;
  }

  mass_spec::PROJECT_MASS_SPEC_SPECTRA &project_mass_spec_spectra_from_xptr(SEXP extptr)
  {
    Rcpp::XPtr<mass_spec::PROJECT_MASS_SPEC_SPECTRA> ptr(extptr);
    if (ptr.get() == nullptr)
    {
      stop("Project Mass Spec Spectra pointer is null");
    }
    return *ptr;
  }

  mass_spec::PROJECT_MASS_SPEC_CHROMATOGRAMS &project_mass_spec_chromatograms_from_xptr(SEXP extptr)
  {
    Rcpp::XPtr<mass_spec::PROJECT_MASS_SPEC_CHROMATOGRAMS> ptr(extptr);
    if (ptr.get() == nullptr)
    {
      stop("Project Mass Spec Chromatograms pointer is null");
    }
    return *ptr;
  }

  DataFrame ms_analysis_rows_to_df(const std::vector<mass_spec::api::MS_ANALYSIS_ROW> &rows)
  {
    CharacterVector project_id(rows.size());
    CharacterVector analysis(rows.size());
    CharacterVector replicate(rows.size());
    CharacterVector blank(rows.size());
    CharacterVector file_name(rows.size());
    CharacterVector file_path(rows.size());
    CharacterVector file_dir(rows.size());
    CharacterVector file_extension(rows.size());
    CharacterVector format(rows.size());
    CharacterVector type(rows.size());
    CharacterVector time_stamp(rows.size());
    IntegerVector number_spectra(rows.size());
    IntegerVector number_chromatograms(rows.size());
    IntegerVector number_spectra_binary_arrays(rows.size());
    NumericVector min_mz(rows.size());
    NumericVector max_mz(rows.size());
    NumericVector start_rt(rows.size());
    NumericVector end_rt(rows.size());
    LogicalVector has_ion_mobility(rows.size());
    NumericVector concentration(rows.size());
    CharacterVector created_at(rows.size());
    for (std::size_t i = 0; i < rows.size(); ++i)
    {
      project_id[i] = rows[i].project_id;
      analysis[i] = rows[i].analysis;
      if (rows[i].replicate.empty())
        replicate[i] = CharacterVector::get_na();
      else
        replicate[i] = rows[i].replicate;
      if (rows[i].blank.empty())
        blank[i] = CharacterVector::get_na();
      else
        blank[i] = rows[i].blank;
      if (rows[i].file_name.empty())
        file_name[i] = CharacterVector::get_na();
      else
        file_name[i] = rows[i].file_name;
      file_path[i] = rows[i].file_path;
      if (rows[i].file_dir.empty())
        file_dir[i] = CharacterVector::get_na();
      else
        file_dir[i] = rows[i].file_dir;
      if (rows[i].file_extension.empty())
        file_extension[i] = CharacterVector::get_na();
      else
        file_extension[i] = rows[i].file_extension;
      if (rows[i].format.empty())
        format[i] = CharacterVector::get_na();
      else
        format[i] = rows[i].format;
      if (rows[i].type.empty())
        type[i] = CharacterVector::get_na();
      else
        type[i] = rows[i].type;
      if (rows[i].time_stamp.empty())
        time_stamp[i] = CharacterVector::get_na();
      else
        time_stamp[i] = rows[i].time_stamp;
      number_spectra[i] = rows[i].number_spectra;
      number_chromatograms[i] = rows[i].number_chromatograms;
      number_spectra_binary_arrays[i] = rows[i].number_spectra_binary_arrays;
      min_mz[i] = rows[i].min_mz;
      max_mz[i] = rows[i].max_mz;
      start_rt[i] = rows[i].start_rt;
      end_rt[i] = rows[i].end_rt;
      has_ion_mobility[i] = rows[i].has_ion_mobility;
      concentration[i] = rows[i].concentration;
      created_at[i] = rows[i].created_at;
    }
    return DataFrame::create(Named("project_id") = project_id,
                             Named("analysis") = analysis,
                             Named("replicate") = replicate,
                             Named("blank") = blank,
                             Named("file_name") = file_name,
                             Named("file_path") = file_path,
                             Named("file_dir") = file_dir,
                             Named("file_extension") = file_extension,
                             Named("format") = format,
                             Named("type") = type,
                             Named("time_stamp") = time_stamp,
                             Named("number_spectra") = number_spectra,
                             Named("number_chromatograms") = number_chromatograms,
                             Named("number_spectra_binary_arrays") = number_spectra_binary_arrays,
                             Named("min_mz") = min_mz,
                             Named("max_mz") = max_mz,
                             Named("start_rt") = start_rt,
                             Named("end_rt") = end_rt,
                             Named("has_ion_mobility") = has_ion_mobility,
                             Named("concentration") = concentration,
                             Named("created_at") = created_at);
  }

  DataFrame ms_spectra_header_rows_to_df(const std::vector<mass_spec::api::MS_SPECTRA_HEADER_ROW> &rows)
  {
    CharacterVector project_id(rows.size());
    CharacterVector analysis(rows.size());
    IntegerVector index(rows.size());
    IntegerVector scan(rows.size());
    IntegerVector array_length(rows.size());
    IntegerVector level(rows.size());
    IntegerVector mode(rows.size());
    IntegerVector polarity(rows.size());
    IntegerVector configuration(rows.size());
    NumericVector lowmz(rows.size());
    NumericVector highmz(rows.size());
    NumericVector bpmz(rows.size());
    NumericVector bpint(rows.size());
    NumericVector tic(rows.size());
    NumericVector rt(rows.size());
    NumericVector mobility(rows.size());
    NumericVector window_mz(rows.size());
    NumericVector pre_mzlow(rows.size());
    NumericVector pre_mzhigh(rows.size());
    NumericVector pre_mz(rows.size());
    NumericVector pre_intensity(rows.size());
    IntegerVector pre_charge(rows.size());
    NumericVector pre_ce(rows.size());
    for (std::size_t i = 0; i < rows.size(); ++i)
    {
      project_id[i] = rows[i].project_id;
      analysis[i] = rows[i].analysis;
      index[i] = rows[i].index;
      scan[i] = rows[i].scan;
      array_length[i] = rows[i].array_length;
      level[i] = rows[i].level;
      mode[i] = rows[i].mode;
      polarity[i] = rows[i].polarity;
      configuration[i] = rows[i].configuration;
      lowmz[i] = rows[i].lowmz;
      highmz[i] = rows[i].highmz;
      bpmz[i] = rows[i].bpmz;
      bpint[i] = rows[i].bpint;
      tic[i] = rows[i].tic;
      rt[i] = rows[i].rt;
      mobility[i] = rows[i].mobility;
      window_mz[i] = rows[i].window_mz;
      pre_mzlow[i] = rows[i].window_mzlow;
      pre_mzhigh[i] = rows[i].window_mzhigh;
      pre_mz[i] = rows[i].precursor_mz;
      pre_intensity[i] = rows[i].precursor_intensity;
      pre_charge[i] = rows[i].precursor_charge;
      pre_ce[i] = rows[i].activation_ce;
    }
    return DataFrame::create(Named("project_id") = project_id,
                             Named("analysis") = analysis,
                             Named("index") = index,
                             Named("scan") = scan,
                             Named("array_length") = array_length,
                             Named("level") = level,
                             Named("mode") = mode,
                             Named("polarity") = polarity,
                             Named("configuration") = configuration,
                             Named("lowmz") = lowmz,
                             Named("highmz") = highmz,
                             Named("bpmz") = bpmz,
                             Named("bpint") = bpint,
                             Named("tic") = tic,
                             Named("rt") = rt,
                             Named("mobility") = mobility,
                             Named("window_mz") = window_mz,
                             Named("pre_mzlow") = pre_mzlow,
                             Named("pre_mzhigh") = pre_mzhigh,
                             Named("pre_mz") = pre_mz,
                             Named("pre_intensity") = pre_intensity,
                             Named("pre_charge") = pre_charge,
                             Named("pre_ce") = pre_ce);
  }

  DataFrame ms_chromatogram_header_rows_to_df(const std::vector<mass_spec::api::MS_CHROMATOGRAM_HEADER_ROW> &rows)
  {
    CharacterVector project_id(rows.size());
    CharacterVector analysis(rows.size());
    IntegerVector index(rows.size());
    CharacterVector id(rows.size());
    IntegerVector array_length(rows.size());
    IntegerVector polarity(rows.size());
    NumericVector pre_mz(rows.size());
    NumericVector pre_ce(rows.size());
    NumericVector pro_mz(rows.size());
    for (std::size_t i = 0; i < rows.size(); ++i)
    {
      project_id[i] = rows[i].project_id;
      analysis[i] = rows[i].analysis;
      index[i] = rows[i].index;
      if (rows[i].id.empty())
        id[i] = CharacterVector::get_na();
      else
        id[i] = rows[i].id;
      array_length[i] = rows[i].array_length;
      polarity[i] = rows[i].polarity;
      pre_mz[i] = rows[i].precursor_mz;
      pre_ce[i] = rows[i].activation_ce;
      pro_mz[i] = rows[i].product_mz;
    }
    return DataFrame::create(Named("project_id") = project_id,
                             Named("analysis") = analysis,
                             Named("index") = index,
                             Named("id") = id,
                             Named("array_length") = array_length,
                             Named("polarity") = polarity,
                             Named("pre_mz") = pre_mz,
                             Named("pre_ce") = pre_ce,
                             Named("pro_mz") = pro_mz);
  }

  DataFrame ms_spectra_tic_rows_to_df(const std::vector<mass_spec::api::MS_SPECTRA_TIC_ROW> &rows)
  {
    CharacterVector analysis(rows.size());
    CharacterVector replicate(rows.size());
    IntegerVector polarity(rows.size());
    IntegerVector level(rows.size());
    NumericVector rt(rows.size());
    NumericVector mobility(rows.size());
    NumericVector tic(rows.size());
    NumericVector bpmz(rows.size());
    NumericVector bpint(rows.size());
    for (std::size_t i = 0; i < rows.size(); ++i)
    {
      analysis[i] = rows[i].analysis;
      if (rows[i].replicate.empty())
        replicate[i] = CharacterVector::get_na();
      else
        replicate[i] = rows[i].replicate;
      polarity[i] = rows[i].polarity;
      level[i] = rows[i].level;
      rt[i] = rows[i].rt;
      mobility[i] = rows[i].mobility;
      tic[i] = rows[i].tic;
      bpmz[i] = rows[i].bpmz;
      bpint[i] = rows[i].bpint;
    }
    return DataFrame::create(Named("analysis") = analysis,
                             Named("replicate") = replicate,
                             Named("polarity") = polarity,
                             Named("level") = level,
                             Named("rt") = rt,
                             Named("mobility") = mobility,
                             Named("tic") = tic,
                             Named("bpmz") = bpmz,
                             Named("bpint") = bpint);
  }

  DataFrame ms_raw_spectrum_rows_to_df(const std::vector<mass_spec::api::MS_RAW_SPECTRUM_ROW> &rows)
  {
    CharacterVector analysis(rows.size());
    CharacterVector replicate(rows.size());
    CharacterVector id(rows.size());
    IntegerVector polarity(rows.size());
    IntegerVector level(rows.size());
    NumericVector pre_mz(rows.size());
    NumericVector pre_mzlow(rows.size());
    NumericVector pre_mzhigh(rows.size());
    NumericVector pre_ce(rows.size());
    NumericVector rt(rows.size());
    NumericVector mobility(rows.size());
    NumericVector mz(rows.size());
    NumericVector intensity(rows.size());
    for (std::size_t i = 0; i < rows.size(); ++i)
    {
      analysis[i] = rows[i].analysis;
      if (rows[i].replicate.empty())
        replicate[i] = CharacterVector::get_na();
      else
        replicate[i] = rows[i].replicate;
      if (rows[i].id.empty())
        id[i] = CharacterVector::get_na();
      else
        id[i] = rows[i].id;
      polarity[i] = rows[i].polarity;
      level[i] = rows[i].level;
      pre_mz[i] = rows[i].pre_mz;
      pre_mzlow[i] = rows[i].pre_mzlow;
      pre_mzhigh[i] = rows[i].pre_mzhigh;
      pre_ce[i] = rows[i].pre_ce;
      rt[i] = rows[i].rt;
      mobility[i] = rows[i].mobility;
      mz[i] = rows[i].mz;
      intensity[i] = rows[i].intensity;
    }
    return DataFrame::create(Named("analysis") = analysis,
                             Named("replicate") = replicate,
                             Named("id") = id,
                             Named("polarity") = polarity,
                             Named("level") = level,
                             Named("pre_mz") = pre_mz,
                             Named("pre_mzlow") = pre_mzlow,
                             Named("pre_mzhigh") = pre_mzhigh,
                             Named("pre_ce") = pre_ce,
                             Named("rt") = rt,
                             Named("mobility") = mobility,
                             Named("mz") = mz,
                             Named("intensity") = intensity);
  }

  DataFrame ms_processed_spectrum_rows_to_df(const std::vector<mass_spec::api::MS_RAW_SPECTRUM_ROW> &rows,
                                             bool include_precursor = false)
  {
    CharacterVector analysis(rows.size());
    CharacterVector replicate(rows.size());
    CharacterVector id(rows.size());
    IntegerVector polarity(rows.size());
    NumericVector pre_mz(rows.size());
    NumericVector rt(rows.size());
    NumericVector mobility(rows.size());
    NumericVector mz(rows.size());
    NumericVector intensity(rows.size());
    bool has_precursor = false;
    for (std::size_t i = 0; i < rows.size(); ++i)
    {
      analysis[i] = rows[i].analysis;
      if (rows[i].replicate.empty())
        replicate[i] = CharacterVector::get_na();
      else
        replicate[i] = rows[i].replicate;
      if (rows[i].id.empty())
        id[i] = CharacterVector::get_na();
      else
        id[i] = rows[i].id;
      polarity[i] = rows[i].polarity;
      pre_mz[i] = rows[i].pre_mz;
      rt[i] = rows[i].rt;
      mobility[i] = rows[i].mobility;
      mz[i] = rows[i].mz;
      intensity[i] = rows[i].intensity;
      has_precursor = has_precursor || std::abs(rows[i].pre_mz) > 0.0;
    }

    if (include_precursor && has_precursor)
    {
      return DataFrame::create(Named("analysis") = analysis,
                               Named("replicate") = replicate,
                               Named("id") = id,
                               Named("polarity") = polarity,
                               Named("pre_mz") = pre_mz,
                               Named("rt") = rt,
                               Named("mobility") = mobility,
                               Named("mz") = mz,
                               Named("intensity") = intensity);
    }

    return DataFrame::create(Named("analysis") = analysis,
                             Named("replicate") = replicate,
                             Named("id") = id,
                             Named("polarity") = polarity,
                             Named("rt") = rt,
                             Named("mobility") = mobility,
                             Named("mz") = mz,
                             Named("intensity") = intensity);
  }

  DataFrame ms_chromatograms_to_df(const std::string &analysis,
                                   const std::string &replicate,
                                   const std::vector<mass_spec::api::MS_CHROMATOGRAM_HEADER_ROW> &headers,
                                   const std::vector<std::vector<std::vector<float>>> &chromatograms)
  {
    std::size_t n = 0;
    for (const auto &chrom : chromatograms)
    {
      if (chrom.size() >= 2)
      {
        n += std::min(chrom[0].size(), chrom[1].size());
      }
    }

    CharacterVector analysis_col(n);
    CharacterVector replicate_col(n);
    IntegerVector index_col(n);
    CharacterVector id_col(n);
    IntegerVector polarity_col(n);
    NumericVector pre_mz_col(n);
    NumericVector pre_ce_col(n);
    NumericVector pro_mz_col(n);
    NumericVector rt_col(n);
    NumericVector intensity_col(n);

    std::size_t row = 0;
    for (std::size_t i = 0; i < chromatograms.size() && i < headers.size(); ++i)
    {
      if (chromatograms[i].size() < 2)
      {
        continue;
      }
      const auto &rt = chromatograms[i][0];
      const auto &intensity = chromatograms[i][1];
      const std::size_t size = std::min(rt.size(), intensity.size());
      for (std::size_t j = 0; j < size; ++j)
      {
        analysis_col[row] = analysis;
        if (replicate.empty())
        {
          replicate_col[row] = CharacterVector::get_na();
        }
        else
        {
          replicate_col[row] = replicate;
        }
        index_col[row] = headers[i].index;
        if (headers[i].id.empty())
        {
          id_col[row] = CharacterVector::get_na();
        }
        else
        {
          id_col[row] = headers[i].id;
        }
        polarity_col[row] = headers[i].polarity;
        pre_mz_col[row] = headers[i].precursor_mz;
        pre_ce_col[row] = headers[i].activation_ce;
        pro_mz_col[row] = headers[i].product_mz;
        rt_col[row] = rt[j];
        intensity_col[row] = intensity[j];
        ++row;
      }
    }

    return DataFrame::create(Named("analysis") = analysis_col,
                             Named("replicate") = replicate_col,
                             Named("index") = index_col,
                             Named("id") = id_col,
                             Named("polarity") = polarity_col,
                             Named("pre_mz") = pre_mz_col,
                             Named("pre_ce") = pre_ce_col,
                             Named("pro_mz") = pro_mz_col,
                             Named("rt") = rt_col,
                             Named("intensity") = intensity_col);
  }

  CharacterVector named_character_vector(const std::vector<std::string> &values, const std::vector<std::string> &names)
  {
    CharacterVector out(values.size());
    CharacterVector out_names(names.size());
    for (std::size_t i = 0; i < values.size(); ++i)
    {
      if (values[i].empty())
      {
        out[i] = CharacterVector::get_na();
      }
      else
      {
        out[i] = values[i];
      }
    }
    for (std::size_t i = 0; i < names.size(); ++i)
    {
      out_names[i] = names[i];
    }
    out.attr("names") = out_names;
    return out;
  }

  NumericVector named_numeric_vector(const std::vector<double> &values, const std::vector<std::string> &names)
  {
    NumericVector out(values.size());
    CharacterVector out_names(names.size());
    for (std::size_t i = 0; i < values.size(); ++i)
    {
      out[i] = values[i];
    }
    for (std::size_t i = 0; i < names.size(); ++i)
    {
      out_names[i] = names[i];
    }
    out.attr("names") = out_names;
    return out;
  }

  std::vector<std::string> analyses_from_character_vector(CharacterVector analyses)
  {
    std::vector<std::string> out;
    out.reserve(analyses.size());
    for (const auto &analysis : analyses)
    {
      if (analysis == NA_STRING)
      {
        continue;
      }
      out.push_back(as<std::string>(analysis));
    }
    return out;
  }

  std::vector<std::string> available_analysis_names(const std::vector<mass_spec::api::MS_ANALYSIS_ROW> &rows)
  {
    std::vector<std::string> out;
    out.reserve(rows.size());
    for (const auto &row : rows)
    {
      if (!row.analysis.empty())
      {
        out.push_back(row.analysis);
      }
    }
    return out;
  }

  std::vector<std::string> resolve_analysis_selection(SEXP analyses_sexp,
                                                      mass_spec::PROJECT_MASS_SPEC &mass_spec)
  {
    if (Rf_isNull(analyses_sexp))
    {
      return {};
    }

    const auto analyses_rows = mass_spec.get_analyses();
    const auto all_analyses = available_analysis_names(analyses_rows);

    if (TYPEOF(analyses_sexp) == STRSXP)
    {
      const auto requested = analyses_from_character_vector(Rcpp::as<CharacterVector>(analyses_sexp));
      if (requested.empty())
      {
        return {};
      }
      std::set<std::string> valid(all_analyses.begin(), all_analyses.end());
      std::vector<std::string> out;
      out.reserve(requested.size());
      for (const auto &analysis : requested)
      {
        if (valid.find(analysis) != valid.end())
        {
          out.push_back(analysis);
        }
      }
      return out;
    }

    if (TYPEOF(analyses_sexp) == INTSXP || TYPEOF(analyses_sexp) == REALSXP)
    {
      auto sorted_analyses = all_analyses;
      std::sort(sorted_analyses.begin(), sorted_analyses.end());
      NumericVector indices(analyses_sexp);
      std::vector<std::string> out;
      out.reserve(indices.size());
      for (R_xlen_t i = 0; i < indices.size(); ++i)
      {
        const double index_value = indices[i];
        if (NumericVector::is_na(index_value) || !R_finite(index_value))
        {
          continue;
        }
        const int index = static_cast<int>(index_value);
        if (index >= 1 && index <= static_cast<int>(sorted_analyses.size()))
        {
          out.push_back(sorted_analyses[static_cast<std::size_t>(index - 1)]);
        }
      }
      return out;
    }

    return {};
  }

  std::vector<double> doubles_from_numeric_vector(const NumericVector &values)
  {
    std::vector<double> out(values.size());
    for (R_xlen_t i = 0; i < values.size(); ++i)
    {
      out[static_cast<std::size_t>(i)] = NumericVector::is_na(values[i]) ? 0.0 : static_cast<double>(values[i]);
    }
    return out;
  }

  std::vector<std::string> strings_from_character_vector(const CharacterVector &values)
  {
    std::vector<std::string> out(values.size());
    for (R_xlen_t i = 0; i < values.size(); ++i)
    {
      out[static_cast<std::size_t>(i)] = CharacterVector::is_na(values[i]) ? std::string() : as<std::string>(values[i]);
    }
    return out;
  }

  template <typename T>
  void assign_if_present(DataFrame df, const char *name, T &target);

  template <>
  void assign_if_present(DataFrame df, const char *name, std::vector<double> &target)
  {
    if (df.containsElementNamed(name))
    {
      target = doubles_from_numeric_vector(df[name]);
    }
  }

  template <>
  void assign_if_present(DataFrame df, const char *name, std::vector<std::string> &target)
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

  mass_spec::spectra::MS_TARGETS_INPUT ms_targets_input_from_object(SEXP value, const char *default_column)
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

  mass_spec::spectra::MS_TARGETS_REQUEST build_raw_spectra_request(mass_spec::PROJECT_MASS_SPEC &mass_spec,
                                                                   SEXP analyses,
                                                                   std::vector<int> levels,
                                                                   SEXP mass,
                                                                   SEXP mz,
                                                                   SEXP rt,
                                                                   SEXP mobility,
                                                                   CharacterVector id,
                                                                   double ppm,
                                                                   double sec,
                                                                   double millisec,
                                                                   bool all_traces,
                                                                   double isolation_window,
                                                                   float min_intensity_ms1,
                                                                   float min_intensity_ms2)
  {
    mass_spec::spectra::MS_TARGETS_REQUEST request;
    request.analyses = resolve_analysis_selection(analyses, mass_spec);
    request.levels = std::move(levels);
    request.mass = ms_targets_input_from_object(mass, "mass");
    request.mz = ms_targets_input_from_object(mz, "mz");
    request.rt = ms_targets_input_from_object(rt, "rt");
    request.mobility = ms_targets_input_from_object(mobility, "mobility");
    request.id = analyses_from_character_vector(id);
    request.ppm = ppm;
    request.sec = sec;
    request.millisec = millisec;
    request.all_traces = all_traces;
    request.isolation_window = isolation_window;
    request.min_intensity_ms1 = min_intensity_ms1;
    request.min_intensity_ms2 = min_intensity_ms2;
    return request;
  }

  struct GroupKey
  {
    std::string analysis;
    std::string id;
    bool operator<(const GroupKey &o) const
    {
      if (analysis != o.analysis)
        return analysis < o.analysis;
      return id < o.id;
    }
  };

  /// Build a sorted map from group key → vector of row indices.
  std::map<GroupKey, std::vector<int>> build_groups(
      const CharacterVector &analysis_col,
      const CharacterVector &id_col)
  {
    std::map<GroupKey, std::vector<int>> groups;
    const int n = analysis_col.size();
    for (int i = 0; i < n; ++i)
      groups[{as<std::string>(analysis_col[i]), as<std::string>(id_col[i])}].push_back(i);
    return groups;
  }

  /// Sort a group's indices by rt (or x-axis).
  void sort_by_rt(std::vector<int> &idx, const NumericVector &rt_col)
  {
    std::sort(idx.begin(), idx.end(), [&](int a, int b)
              { return rt_col[a] < rt_col[b]; });
  }
}

// MARK: PROJECT MASS SPEC EXPORTS

// [[Rcpp::export]]
SEXP rcpp_project_mass_spec_new(SEXP project_xptr,
                                CharacterVector file_paths,
                                CharacterVector replicates,
                                CharacterVector blanks)
{
  return project_rcpp::project_call([&]()
                                    {
        auto* ptr = new mass_spec::PROJECT_MASS_SPEC(project_rcpp::project_from_xptr(project_xptr).context(),
                                                     Rcpp::as<std::vector<std::string>>(file_paths),
                                                     Rcpp::as<std::vector<std::string>>(replicates),
                                                     Rcpp::as<std::vector<std::string>>(blanks));
        Rcpp::XPtr<mass_spec::PROJECT_MASS_SPEC> out(ptr, true);
        out.attr("class") = "StreamFindProjectMassSpec";
        return SEXP(out); });
}

// [[Rcpp::export]]
void rcpp_project_mass_spec_import_files(SEXP mass_spec_xptr,
                                         CharacterVector file_paths,
                                         CharacterVector replicates,
                                         CharacterVector blanks)
{
  project::api::project_call([&]()
                             {
        mass_spec_rcpp::project_mass_spec_from_xptr(mass_spec_xptr).import_files(as<std::vector<std::string>>(file_paths),
                                                                 as<std::vector<std::string>>(replicates),
                                                                 as<std::vector<std::string>>(blanks));
        return 0; });
}

// [[Rcpp::export]]
void rcpp_project_mass_spec_remove_analysis(SEXP mass_spec_xptr, std::string analysis)
{
  project::api::project_call([&]()
                             {
        mass_spec_rcpp::project_mass_spec_from_xptr(mass_spec_xptr).remove_analysis(analysis);
        return 0; });
}

// [[Rcpp::export]]
DataFrame rcpp_project_mass_spec_list_analyses(SEXP mass_spec_xptr)
{
  return project::api::project_call([&]()
                                    { return mass_spec_rcpp::ms_analysis_rows_to_df(mass_spec_rcpp::project_mass_spec_from_xptr(mass_spec_xptr).get_analyses()); });
}

// [[Rcpp::export]]
CharacterVector rcpp_project_mass_spec_get_analysis_names(SEXP mass_spec_xptr)
{
  return project::api::project_call([&]()
                                    {
        const auto& mass_spec = mass_spec_rcpp::project_mass_spec_from_xptr(mass_spec_xptr);
        const auto names = mass_spec.get_analysis_names();
        return CharacterVector(names.begin(), names.end()); });
}

// [[Rcpp::export]]
CharacterVector rcpp_project_mass_spec_get_replicate_names(SEXP mass_spec_xptr)
{
  return project::api::project_call([&]()
                                    {
        const auto& mass_spec = mass_spec_rcpp::project_mass_spec_from_xptr(mass_spec_xptr);
        return mass_spec_rcpp::named_character_vector(mass_spec.get_replicate_names(), mass_spec.get_analysis_names()); });
}

// [[Rcpp::export]]
void rcpp_project_mass_spec_set_replicate_names(SEXP mass_spec_xptr, CharacterVector values)
{
  project::api::project_call([&]()
                             {
        mass_spec_rcpp::project_mass_spec_from_xptr(mass_spec_xptr).set_replicate_names(as<std::vector<std::string>>(values));
        return 0; });
}

// [[Rcpp::export]]
CharacterVector rcpp_project_mass_spec_get_blank_names(SEXP mass_spec_xptr)
{
  return project::api::project_call([&]()
                                    {
        const auto& mass_spec = mass_spec_rcpp::project_mass_spec_from_xptr(mass_spec_xptr);
        return mass_spec_rcpp::named_character_vector(mass_spec.get_blank_names(), mass_spec.get_analysis_names()); });
}

// [[Rcpp::export]]
void rcpp_project_mass_spec_set_blank_names(SEXP mass_spec_xptr, CharacterVector values)
{
  project::api::project_call([&]()
                             {
        mass_spec_rcpp::project_mass_spec_from_xptr(mass_spec_xptr).set_blank_names(as<std::vector<std::string>>(values));
        return 0; });
}

// [[Rcpp::export]]
NumericVector rcpp_project_mass_spec_get_concentrations(SEXP mass_spec_xptr)
{
  return project::api::project_call([&]()
                                    {
        const auto& mass_spec = mass_spec_rcpp::project_mass_spec_from_xptr(mass_spec_xptr);
        return mass_spec_rcpp::named_numeric_vector(mass_spec.get_concentrations(), mass_spec.get_analysis_names()); });
}

// [[Rcpp::export]]
void rcpp_project_mass_spec_set_concentrations(SEXP mass_spec_xptr, NumericVector values)
{
  project::api::project_call([&]()
                             {
        mass_spec_rcpp::project_mass_spec_from_xptr(mass_spec_xptr).set_concentrations(as<std::vector<double>>(values));
        return 0; });
}

// [[Rcpp::export]]
DataFrame rcpp_project_mass_spec_get_spectra_headers(SEXP mass_spec_xptr, SEXP analyses)
{
  return project::api::project_call([&]()
                                    {
        auto& mass_spec = mass_spec_rcpp::project_mass_spec_from_xptr(mass_spec_xptr);
  return mass_spec_rcpp::ms_spectra_header_rows_to_df(mass_spec.get_spectra_headers(mass_spec_rcpp::resolve_analysis_selection(analyses, mass_spec))); });
}

// [[Rcpp::export]]
DataFrame rcpp_project_mass_spec_get_chromatograms_headers(SEXP mass_spec_xptr, SEXP analyses)
{
  return project::api::project_call([&]()
                                    {
        auto& mass_spec = mass_spec_rcpp::project_mass_spec_from_xptr(mass_spec_xptr);
  return mass_spec_rcpp::ms_chromatogram_header_rows_to_df(mass_spec.get_chromatograms_headers(mass_spec_rcpp::resolve_analysis_selection(analyses, mass_spec))); });
}

// [[Rcpp::export]]
DataFrame rcpp_project_mass_spec_get_spectra_tic(SEXP mass_spec_xptr,
             SEXP analyses,
                                                 std::vector<int> levels,
                                                 double rtmin,
                                                 double rtmax)
{
  return project::api::project_call([&]() {
    auto& mass_spec = mass_spec_rcpp::project_mass_spec_from_xptr(mass_spec_xptr);
    double rt_min = rtmin;
    double rt_max = rtmax;
    return mass_spec_rcpp::ms_spectra_tic_rows_to_df(
        mass_spec.get_spectra_tic(
          mass_spec_rcpp::resolve_analysis_selection(analyses, mass_spec), levels, rt_min, rt_max
        )
    );
  });
}

// [[Rcpp::export]]
DataFrame rcpp_project_mass_spec_get_raw_spectra(SEXP mass_spec_xptr,
                                                 SEXP analyses,
                                                 std::vector<int> levels,
                                                 SEXP mass,
                                                 SEXP mz,
                                                 SEXP rt,
                                                 SEXP mobility,
                                                 CharacterVector id,
                                                 double ppm,
                                                 double sec,
                                                 double millisec,
                                                 bool all_traces,
                                                 double isolation_window,
                                                 float min_intensity_ms1,
                                                 float min_intensity_ms2)
{
  return project::api::project_call([&]() {
    auto& mass_spec = mass_spec_rcpp::project_mass_spec_from_xptr(mass_spec_xptr);
    auto request = mass_spec_rcpp::build_raw_spectra_request(
        mass_spec,
        analyses,
        std::move(levels),
        mass,
        mz,
        rt,
        mobility,
        id,
        ppm,
        sec,
        millisec,
        all_traces,
        isolation_window,
        min_intensity_ms1,
        min_intensity_ms2
    );
    return mass_spec_rcpp::ms_raw_spectrum_rows_to_df(
        mass_spec.get_raw_spectra(request)
    );
  });
}

// [[Rcpp::export]]
DataFrame rcpp_project_mass_spec_get_raw_spectra_eic(SEXP mass_spec_xptr,
                                                     SEXP analyses,
                                                     SEXP mass,
                                                     SEXP mz,
                                                     SEXP rt,
                                                     SEXP mobility,
                                                     CharacterVector id,
                                                     double ppm,
                                                     double sec,
                                                     double millisec)
{
  return project::api::project_call([&]() {
    auto& mass_spec = mass_spec_rcpp::project_mass_spec_from_xptr(mass_spec_xptr);
    auto request = mass_spec_rcpp::build_raw_spectra_request(
        mass_spec,
        analyses,
        {1},
        mass,
        mz,
        rt,
        mobility,
        id,
        ppm,
        sec,
        millisec,
        true,
        1.3,
        0.0f,
        0.0f
    );
    return mass_spec_rcpp::ms_processed_spectrum_rows_to_df(mass_spec.get_raw_spectra_eic(request));
  });
}

// [[Rcpp::export]]
DataFrame rcpp_project_mass_spec_get_raw_spectra_ms1(SEXP mass_spec_xptr,
                                                     SEXP analyses,
                                                     SEXP mass,
                                                     SEXP mz,
                                                     SEXP rt,
                                                     SEXP mobility,
                                                     CharacterVector id,
                                                     double ppm,
                                                     double sec,
                                                     double millisec,
                                                     float mz_clust,
                                                     float presence,
                                                     float min_intensity)
{
  return project::api::project_call([&]() {
    auto& mass_spec = mass_spec_rcpp::project_mass_spec_from_xptr(mass_spec_xptr);
    auto request = mass_spec_rcpp::build_raw_spectra_request(
        mass_spec,
        analyses,
        {1},
        mass,
        mz,
        rt,
        mobility,
        id,
        ppm,
        sec,
        millisec,
        true,
        1.3,
        min_intensity,
        0.0f
    );
    return mass_spec_rcpp::ms_processed_spectrum_rows_to_df(mass_spec.get_raw_spectra_ms1(request, mz_clust, presence));
  });
}

// [[Rcpp::export]]
DataFrame rcpp_project_mass_spec_get_raw_spectra_ms2(SEXP mass_spec_xptr,
                                                     SEXP analyses,
                                                     SEXP mass,
                                                     SEXP mz,
                                                     SEXP rt,
                                                     SEXP mobility,
                                                     CharacterVector id,
                                                     double ppm,
                                                     double sec,
                                                     double millisec,
                                                     float isolation_window,
                                                     float mz_clust,
                                                     float presence,
                                                     float min_intensity)
{
  return project::api::project_call([&]() {
    auto& mass_spec = mass_spec_rcpp::project_mass_spec_from_xptr(mass_spec_xptr);
    auto request = mass_spec_rcpp::build_raw_spectra_request(
        mass_spec,
        analyses,
        {2},
        mass,
        mz,
        rt,
        mobility,
        id,
        ppm,
        sec,
        millisec,
        false,
        isolation_window,
        0.0f,
        min_intensity
    );
    return mass_spec_rcpp::ms_processed_spectrum_rows_to_df(mass_spec.get_raw_spectra_ms2(request, isolation_window, mz_clust, presence), true);
  });
}

// [[Rcpp::export]]
DataFrame rcpp_project_mass_spec_get_raw_chromatograms(SEXP mass_spec_xptr,
                                                       std::string analysis,
                                                       std::vector<int> indices)
{
  return project::api::project_call([&]() {
    auto& mass_spec = mass_spec_rcpp::project_mass_spec_from_xptr(mass_spec_xptr);
    const auto analyses = mass_spec.get_analyses();
    const auto analysis_it = std::find_if(analyses.begin(), analyses.end(), [&](const auto& row) {
      return row.analysis == analysis;
    });
    if (analysis_it == analyses.end()) {
      stop("Mass spec analysis not found: " + analysis);
    }
    const auto all_headers = mass_spec.get_chromatograms_headers({analysis});
    std::vector<mass_spec::api::MS_CHROMATOGRAM_HEADER_ROW> selected_headers;
    if (indices.empty()) {
      selected_headers = all_headers;
      indices.reserve(all_headers.size());
      for (const auto& header : all_headers) {
        indices.push_back(header.index);
      }
    } else {
      for (int index : indices) {
        const auto it = std::find_if(all_headers.begin(), all_headers.end(), [&](const auto& header) {
          return header.index == index;
        });
        if (it != all_headers.end()) {
          selected_headers.push_back(*it);
        }
      }
    }
    return mass_spec_rcpp::ms_chromatograms_to_df(
      analysis,
      analysis_it->replicate,
      selected_headers,
      mass_spec.get_raw_chromatograms(analysis, indices)
    );
  });
}

// MARK: PROJECT MASS SPEC SPECTRA EXPORTS

// [[Rcpp::export]]
SEXP rcpp_project_mass_spec_spectra_new(SEXP project_xptr,
                                        CharacterVector file_paths,
                                        CharacterVector replicates,
                                        CharacterVector blanks)
{
  return project_rcpp::project_call([&]()
                                    {
        auto* ptr = new mass_spec::PROJECT_MASS_SPEC_SPECTRA(project_rcpp::project_from_xptr(project_xptr).context(),
                                                             Rcpp::as<std::vector<std::string>>(file_paths),
                                                             Rcpp::as<std::vector<std::string>>(replicates),
                                                             Rcpp::as<std::vector<std::string>>(blanks));
        Rcpp::XPtr<mass_spec::PROJECT_MASS_SPEC_SPECTRA> out(ptr, true);
        out.attr("class") = "StreamFindProjectMassSpecSpectra";
        return SEXP(out); });
}

// MARK: PROJECT MASS SPEC CHROMATOGRAMS EXPORTS

// [[Rcpp::export]]
SEXP rcpp_project_mass_spec_chromatograms_new(SEXP project_xptr,
                                              CharacterVector file_paths,
                                              CharacterVector replicates,
                                              CharacterVector blanks)
{
  return project_rcpp::project_call([&]()
                                    {
        auto* ptr = new mass_spec::PROJECT_MASS_SPEC_CHROMATOGRAMS(project_rcpp::project_from_xptr(project_xptr).context(),
                                                                   Rcpp::as<std::vector<std::string>>(file_paths),
                                                                   Rcpp::as<std::vector<std::string>>(replicates),
                                                                   Rcpp::as<std::vector<std::string>>(blanks));
        Rcpp::XPtr<mass_spec::PROJECT_MASS_SPEC_CHROMATOGRAMS> out(ptr, true);
        out.attr("class") = "StreamFindProjectMassSpecChromatograms";
        return SEXP(out); });
}
