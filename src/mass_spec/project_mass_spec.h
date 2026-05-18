#pragma once

#include "../project/project.h"

#include <vector>
#include <string>
#include <unordered_set>
#include <cstddef>

namespace mass_spec
{

  namespace utils
  {
    int reflect_idx(int i, int n);
    double trap(double x0, double y0, double x1, double y1);
  }

  namespace spectra
  {

    struct MS_TARGETS
    {
      std::vector<int> index;
      std::vector<std::string> id;
      std::vector<int> level;
      std::vector<int> polarity;
      std::vector<bool> precursor;
      std::vector<float> mz;
      std::vector<float> mzmin;
      std::vector<float> mzmax;
      std::vector<float> rt;
      std::vector<float> rtmin;
      std::vector<float> rtmax;
      std::vector<float> mobility;
      std::vector<float> mobilitymin;
      std::vector<float> mobilitymax;

      void resize_all(int n)
      {
        index.resize(n);
        id.resize(n);
        level.resize(n);
        polarity.resize(n);
        precursor.resize(n);
        mz.resize(n);
        mzmin.resize(n);
        mzmax.resize(n);
        rt.resize(n);
        rtmin.resize(n);
        rtmax.resize(n);
        mobility.resize(n);
        mobilitymin.resize(n);
        mobilitymax.resize(n);
      }
    };

    struct MS_TARGETS_SPECTRA
    {
      std::vector<std::string> id;
      std::vector<int> polarity;
      std::vector<int> level;
      std::vector<float> pre_mz;
      std::vector<float> pre_mzlow;
      std::vector<float> pre_mzhigh;
      std::vector<float> pre_ce;
      std::vector<float> rt;
      std::vector<float> mobility;
      std::vector<float> mz;
      std::vector<float> intensity;

      void resize_all(int n)
      {
        id.resize(n);
        polarity.resize(n);
        level.resize(n);
        pre_mz.resize(n);
        pre_mzlow.resize(n);
        pre_mzhigh.resize(n);
        pre_ce.resize(n);
        rt.resize(n);
        mobility.resize(n);
        mz.resize(n);
        intensity.resize(n);
      }

      size_t size() const { return id.size(); }

      int number_ids() const
      {
        std::unordered_set<std::string> unique_ids(id.begin(), id.end());
        return static_cast<int>(unique_ids.size());
      }

      MS_TARGETS_SPECTRA operator[](const std::string &unique_id) const
      {
        MS_TARGETS_SPECTRA target;
        for (size_t i = 0; i < id.size(); ++i)
        {
          if (id[i] == unique_id)
          {
            target.id.push_back(id[i]);
            target.polarity.push_back(polarity[i]);
            target.level.push_back(level[i]);
            target.pre_mz.push_back(pre_mz[i]);
            target.pre_mzlow.push_back(pre_mzlow[i]);
            target.pre_mzhigh.push_back(pre_mzhigh[i]);
            target.pre_ce.push_back(pre_ce[i]);
            target.rt.push_back(rt[i]);
            target.mobility.push_back(mobility[i]);
            target.mz.push_back(mz[i]);
            target.intensity.push_back(intensity[i]);
          }
        }
        return target;
      }
    };

    struct MS_TARGETS_INPUT
    {
      std::size_t size = 0;
      std::vector<std::string> id;
      std::vector<std::string> analysis;
      std::vector<std::string> polarity;
      std::vector<double> mass;
      std::vector<double> mass_min;
      std::vector<double> mass_max;
      std::vector<double> mz;
      std::vector<double> mzmin;
      std::vector<double> mzmax;
      std::vector<double> rt;
      std::vector<double> rtmin;
      std::vector<double> rtmax;
      std::vector<double> mobility;
      std::vector<double> mobilitymin;
      std::vector<double> mobilitymax;

      bool empty() const { return size == 0; }
    };

    struct MS_TARGETS_REQUEST
    {
      std::vector<std::string> analyses;
      std::vector<int> levels;
      MS_TARGETS_INPUT mass;
      MS_TARGETS_INPUT mz;
      MS_TARGETS_INPUT rt;
      MS_TARGETS_INPUT mobility;
      std::vector<std::string> id;
      double ppm = 20.0;
      double sec = 60.0;
      double millisec = 5.0;
      bool all_traces = true;
      double isolation_window = 1.3;
      float min_intensity_ms1 = 0.0f;
      float min_intensity_ms2 = 0.0f;
    };

    std::vector<std::string> sanitize_analyses(const std::vector<std::string> &analyses);

    std::vector<MS_TARGETS> build_targets_by_analysis(const MS_TARGETS_REQUEST &request,
                                                      const std::vector<std::string> &analyses,
                                                      const std::vector<std::string> &polarities);

    bool has_effective_targets(const MS_TARGETS &targets);

    MS_TARGETS subset_targets(const MS_TARGETS &targets,
                              const std::vector<int> &levels,
                              bool all_traces,
                              double isolation_window);

    struct MS_SPECTRUM_POINT
    {
      double mz;
      double intensity;
    };

    struct MS_MASS_POINT
    {
      double mass;
      double intensity;
    };

    struct MS_CHARGE_POINT
    {
      double mz;
      double intensity;
      double cluster_mz; ///< rounded cluster representative
      int z;
      double mass;
      int polarity;
    };

    /// @brief Calculate charge states for a single merged spectrum (sorted by mz).
    /// @param pts list of (mz, intensity) pairs, sorted ascending by mz
    /// @param polarity +1 or -1
    /// @param round_val m/z rounding denominator for clustering (e.g. 35)
    /// @param rel_low_cut relative intensity cut (fraction of base peak)
    /// @param abs_low_cut absolute intensity cut
    /// @param top_charges number of top charge candidates to consider
    std::vector<MS_CHARGE_POINT> calculate_spectra_charges(
      const std::vector<MS_SPECTRUM_POINT> &pts,
        int polarity,
        double round_val = 35.0,
        double rel_low_cut = 0.2,
        double abs_low_cut = 300.0,
        int top_charges = 5);

    /// @brief Cluster mass values within clust_val tolerance, weighted average of mass,
    /// summed intensity.
    std::vector<MS_MASS_POINT> cluster_masses(
      const std::vector<MS_MASS_POINT> &pts,
        double clust_val);

    /// @brief Deconvolute one spectrum using its pre-computed charge rows.
    /// @param spectrum_pts raw (mz, intensity) pairs
    /// @param charges charge rows for this spectrum
    /// @param clust_val mass clustering tolerance (Da)
    /// @param window m/z window around each charge m/z to extract
    std::vector<MS_MASS_POINT> deconvolute_spectrum(
      const std::vector<MS_SPECTRUM_POINT> &spectrum_pts,
      const std::vector<MS_CHARGE_POINT> &charges,
        double clust_val = 0.1,
        double window = 20.0);

  } // namespace spectra

  namespace chromatograms
  {

  } // namespace chromatograms

  namespace api
  {
    project::db::CONNECTION_GUARD connect_checked(const std::shared_ptr<project::api::CONTEXT> &ctx);

    struct MS_ANALYSIS_ROW : public project::api::ROW
    {
      std::string analysis;
      std::string replicate;
      std::string blank;
      std::string file_name;
      std::string file_path;
      std::string file_dir;
      std::string file_extension;
      std::string format;
      std::string type;
      std::string time_stamp;
      int number_spectra = 0;
      int number_chromatograms = 0;
      int number_spectra_binary_arrays = 0;
      double min_mz = 0.0;
      double max_mz = 0.0;
      double start_rt = 0.0;
      double end_rt = 0.0;
      bool has_ion_mobility = false;
      double concentration = 0.0;
    };

    struct MS_SPECTRA_HEADER_ROW : public project::api::ROW
    {
      std::string analysis;
      int index = 0;
      int scan = 0;
      int array_length = 0;
      int level = 0;
      int mode = 0;
      int polarity = 0;
      int configuration = 0;
      double lowmz = 0.0;
      double highmz = 0.0;
      double bpmz = 0.0;
      double bpint = 0.0;
      double tic = 0.0;
      double rt = 0.0;
      double mobility = 0.0;
      double window_mz = 0.0;
      double window_mzlow = 0.0;
      double window_mzhigh = 0.0;
      double precursor_mz = 0.0;
      double precursor_intensity = 0.0;
      int precursor_charge = 0;
      double activation_ce = 0.0;
    };

    struct MS_CHROMATOGRAM_HEADER_ROW : public project::api::ROW
    {
      std::string analysis;
      int index = 0;
      std::string id;
      int array_length = 0;
      int polarity = 0;
      double precursor_mz = 0.0;
      double activation_ce = 0.0;
      double product_mz = 0.0;
    };

    struct MS_ANALYSES_TABLE
    {
      std::vector<std::string> project_id;
      std::vector<std::string> analysis;
      std::vector<std::string> replicate;
      std::vector<std::string> blank;
      std::vector<std::string> file_name;
      std::vector<std::string> file_path;
      std::vector<std::string> file_dir;
      std::vector<std::string> file_extension;
      std::vector<std::string> format;
      std::vector<std::string> type;
      std::vector<std::string> time_stamp;
      std::vector<int> number_spectra;
      std::vector<int> number_chromatograms;
      std::vector<int> number_spectra_binary_arrays;
      std::vector<double> min_mz;
      std::vector<double> max_mz;
      std::vector<double> start_rt;
      std::vector<double> end_rt;
      std::vector<bool> has_ion_mobility;
      std::vector<double> concentration;
      std::vector<std::string> created_at;

      int size() const { return static_cast<int>(analysis.size()); }

      std::vector<std::uint8_t> serialize_object() const;
      static MS_ANALYSES_TABLE deserialize_object(const std::vector<std::uint8_t> &bytes);
    };

    struct MS_SPECTRA_HEADERS_TABLE
    {
      std::vector<std::string> project_id;
      std::vector<std::string> analysis;
      std::vector<int> index;
      std::vector<int> scan;
      std::vector<int> array_length;
      std::vector<int> level;
      std::vector<int> mode;
      std::vector<int> polarity;
      std::vector<int> configuration;
      std::vector<double> lowmz;
      std::vector<double> highmz;
      std::vector<double> bpmz;
      std::vector<double> bpint;
      std::vector<double> tic;
      std::vector<double> rt;
      std::vector<double> mobility;
      std::vector<double> window_mz;
      std::vector<double> window_mzlow;
      std::vector<double> window_mzhigh;
      std::vector<double> precursor_mz;
      std::vector<double> precursor_intensity;
      std::vector<int> precursor_charge;
      std::vector<double> activation_ce;

      int size() const { return static_cast<int>(index.size()); }

      std::vector<std::uint8_t> serialize_object() const;
      static MS_SPECTRA_HEADERS_TABLE deserialize_object(const std::vector<std::uint8_t> &bytes);
    };

    struct MS_CHROMATOGRAMS_HEADERS_TABLE
    {
      std::vector<std::string> project_id;
      std::vector<std::string> analysis;
      std::vector<int> index;
      std::vector<std::string> id;
      std::vector<int> array_length;
      std::vector<int> polarity;
      std::vector<double> precursor_mz;
      std::vector<double> activation_ce;
      std::vector<double> product_mz;

      int size() const { return static_cast<int>(index.size()); }

      std::vector<std::uint8_t> serialize_object() const;
      static MS_CHROMATOGRAMS_HEADERS_TABLE deserialize_object(const std::vector<std::uint8_t> &bytes);
    };

    MS_ANALYSIS_ROW analysis_row_from_result(duckdb_result &result, idx_t row);
    MS_SPECTRA_HEADER_ROW spectra_header_row_from_result(duckdb_result &result, idx_t row);
    MS_CHROMATOGRAM_HEADER_ROW chromatogram_header_row_from_result(duckdb_result &result, idx_t row);

    struct MS_SPECTRA_TIC_ROW
    {
      std::string analysis;
      std::string replicate;
      int polarity = 0;
      int level = 0;
      double rt = 0.0;
      double tic = 0.0;
      double bpmz = 0.0;
      double bpint = 0.0;
    };

    struct MS_RAW_SPECTRUM_ROW
    {
      std::string analysis;
      std::string replicate;
      std::string id;
      int polarity = 0;
      int level = 0;
      double pre_mz = 0.0;
      double pre_mzlow = 0.0;
      double pre_mzhigh = 0.0;
      double pre_ce = 0.0;
      double rt = 0.0;
      double mobility = 0.0;
      double mz = 0.0;
      double intensity = 0.0;
    };

    class PROJECT_MASS_SPEC
    {
    public:
      explicit PROJECT_MASS_SPEC(std::shared_ptr<project::api::CONTEXT> ctx,
                                 const std::vector<std::string> &file_paths = {},
                                 const std::vector<std::string> &replicates = {},
                                 const std::vector<std::string> &blanks = {});

      static void create_schema(const std::shared_ptr<project::api::CONTEXT> &ctx);
      static void validate_schema(const std::shared_ptr<project::api::CONTEXT> &ctx);

      void import_files(const std::vector<std::string> &file_paths,
                        const std::vector<std::string> &replicates = {},
                        const std::vector<std::string> &blanks = {});
      void remove_analysis(const std::string &analysis);

      std::vector<MS_ANALYSIS_ROW> get_analyses() const;
      MS_ANALYSES_TABLE collect_analyses() const;
      std::vector<std::string> get_analysis_names() const;
      std::vector<std::string> get_replicate_names() const;
      std::vector<std::string> get_blank_names() const;
      std::vector<double> get_concentrations() const;
      void set_replicate_names(const std::vector<std::string> &values);
      void set_blank_names(const std::vector<std::string> &values);
      void set_concentrations(const std::vector<double> &values);
      std::vector<MS_SPECTRA_HEADER_ROW> get_spectra_headers(const std::vector<std::string> &analyses = {}) const;
      MS_SPECTRA_HEADERS_TABLE collect_spectra_headers(const std::vector<std::string> &analyses = {}) const;
      std::vector<MS_CHROMATOGRAM_HEADER_ROW> get_chromatograms_headers(const std::vector<std::string> &analyses = {}) const;
      MS_CHROMATOGRAMS_HEADERS_TABLE collect_chromatograms_headers(const std::vector<std::string> &analyses = {}) const;
      std::vector<MS_SPECTRA_TIC_ROW> get_spectra_tic(const std::vector<std::string> &analyses = {},
                                                      const std::vector<int> &levels = {},
                                                      double rt_min = 0.0,
                                                      double rt_max = 0.0) const;
      std::vector<MS_RAW_SPECTRUM_ROW> get_raw_spectra(const spectra::MS_TARGETS_REQUEST &request) const;
      std::vector<std::vector<std::vector<float>>> get_chromatograms_data(const std::string &analysis,
                                                                          const std::vector<int> &indices) const;

    private:
      std::shared_ptr<project::api::CONTEXT> ctx_;

      void import_file_with_connection(duckdb_connection con,
                                       const std::string &file_path,
                                       const std::string &replicate,
                                       const std::string &blank);

      static constexpr const char *analyses_table_name() { return "MS_ANALYSES"; }
      static constexpr const char *spectra_headers_table_name() { return "MS_SPECTRA_HEADERS"; }
      static constexpr const char *chromatograms_headers_table_name() { return "MS_CHROMATOGRAMS_HEADERS"; }
    };

    class PROJECT_MASS_SPEC_SPECTRA
    {
    public:
      explicit PROJECT_MASS_SPEC_SPECTRA(std::shared_ptr<project::api::CONTEXT> ctx,
                                        const std::vector<std::string> &file_paths = {},
                                        const std::vector<std::string> &replicates = {},
                                        const std::vector<std::string> &blanks = {});

      const std::shared_ptr<project::api::CONTEXT> &context() const noexcept;
      PROJECT_MASS_SPEC &base() noexcept;
      const PROJECT_MASS_SPEC &base() const noexcept;

    private:
      std::shared_ptr<project::api::CONTEXT> ctx_;
      PROJECT_MASS_SPEC base_;
    };

    class PROJECT_MASS_SPEC_CHROMATOGRAMS
    {
    public:
      explicit PROJECT_MASS_SPEC_CHROMATOGRAMS(std::shared_ptr<project::api::CONTEXT> ctx,
                                               const std::vector<std::string> &file_paths = {},
                                               const std::vector<std::string> &replicates = {},
                                               const std::vector<std::string> &blanks = {});

      const std::shared_ptr<project::api::CONTEXT> &context() const noexcept;
      PROJECT_MASS_SPEC &base() noexcept;
      const PROJECT_MASS_SPEC &base() const noexcept;

    private:
      std::shared_ptr<project::api::CONTEXT> ctx_;
      PROJECT_MASS_SPEC base_;
    };
  } // namespace api

  using PROJECT_MASS_SPEC = api::PROJECT_MASS_SPEC;
  using PROJECT_MASS_SPEC_SPECTRA = api::PROJECT_MASS_SPEC_SPECTRA;
  using PROJECT_MASS_SPEC_CHROMATOGRAMS = api::PROJECT_MASS_SPEC_CHROMATOGRAMS;

} // namespace mass_spec
