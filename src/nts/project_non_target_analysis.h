#pragma once

#include "../mass_spec/project_mass_spec.h"
#include "../project/cache.h"
#include "assign_transformation_products.h"
#include "suspect_screening.h"
#include "nts.h"

#include <limits>

namespace nts {

struct NTS_FEATURE_ROW : public project::ROW {
  std::string analysis;
  std::string feature;
  std::string feature_component;
  std::string feature_group;
  std::string adduct;
  double rt = 0.0;
  double mz = 0.0;
  double mass = 0.0;
  double intensity = 0.0;
  double noise = 0.0;
  double sn = 0.0;
  double area = 0.0;
  double rtmin = 0.0;
  double rtmax = 0.0;
  double width = 0.0;
  double mzmin = 0.0;
  double mzmax = 0.0;
  double ppm = 0.0;
  double fwhm_rt = 0.0;
  double fwhm_mz = 0.0;
  double gaussian_A = 0.0;
  double gaussian_mu = 0.0;
  double gaussian_sigma = 0.0;
  double gaussian_r2 = 0.0;
  double jaggedness = 0.0;
  double sharpness = 0.0;
  double asymmetry = 0.0;
  int modality = 0;
  double plates = 0.0;
  int polarity = 0;
  bool filtered = false;
  std::string filter;
  bool filled = false;
  double correction = 0.0;
  int eic_size = 0;
  std::string eic_rt;
  std::string eic_mz;
  std::string eic_intensity;
  std::string eic_baseline;
  std::string eic_smoothed;
  int ms1_size = 0;
  std::string ms1_mz;
  std::string ms1_intensity;
  int ms2_size = 0;
  std::string ms2_mz;
  std::string ms2_intensity;
};

struct NTS_FEATURE_COUNT_ROW {
  std::string analysis;
  int total = 0;
  int filtered = 0;
  int groups = 0;
  int components = 0;
};

struct NTS_SUSPECT_ROW : public project::ROW {
  std::string analysis;
  std::string feature;
  int candidate_rank = 0;
  std::string name;
  int polarity = 0;
  double db_mass = 0.0;
  double exp_mass = 0.0;
  double error_mass = 0.0;
  double db_rt = 0.0;
  double exp_rt = 0.0;
  double error_rt = 0.0;
  double intensity = 0.0;
  double area = 0.0;
  int id_level = 0;
  double score = 0.0;
  int shared_fragments = 0;
  double cosine_similarity = 0.0;
  std::string formula;
  std::string SMILES;
  std::string InChI;
  std::string InChIKey;
  double xLogP = 0.0;
  std::string database_id;
  int db_ms2_size = 0;
  std::string db_ms2_mz;
  std::string db_ms2_intensity;
  std::string db_ms2_formula;
  int exp_ms2_size = 0;
  std::string exp_ms2_mz;
  std::string exp_ms2_intensity;
};

struct NTS_INTERNAL_STANDARD_ROW : public project::ROW {
  std::string analysis;
  std::string feature;
  int candidate_rank = 0;
  std::string name;
  int polarity = 0;
  double db_mass = 0.0;
  double exp_mass = 0.0;
  double error_mass = 0.0;
  double db_rt = 0.0;
  double exp_rt = 0.0;
  double error_rt = 0.0;
  double intensity = 0.0;
  double area = 0.0;
  int id_level = 0;
  double score = 0.0;
  int shared_fragments = 0;
  double cosine_similarity = 0.0;
  std::string formula;
  std::string SMILES;
  std::string InChI;
  std::string InChIKey;
  double xLogP = 0.0;
  std::string database_id;
  int db_ms2_size = 0;
  std::string db_ms2_mz;
  std::string db_ms2_intensity;
  std::string db_ms2_formula;
  int exp_ms2_size = 0;
  std::string exp_ms2_mz;
  std::string exp_ms2_intensity;
};

struct NTS_TRANSFORMATION_PRODUCT_ROW : public project::ROW {
  std::string name;
  std::string formula;
  double mass = 0.0;
  std::string SMILES;
  std::string InChI;
  std::string InChIKey;
  double xLogP = 0.0;
  std::string transformation;
  std::string precursor_name;
  std::string precursor_formula;
  double precursor_mass = 0.0;
  std::string precursor_SMILES;
  std::string precursor_InChI;
  std::string precursor_InChIKey;
  double precursor_xLogP = 0.0;
  std::string main_precursor_name;
  std::string main_precursor_formula;
  double main_precursor_mass = 0.0;
  std::string main_precursor_SMILES;
  std::string main_precursor_InChI;
  std::string main_precursor_InChIKey;
  double main_precursor_xLogP = 0.0;
  std::string feature_group;
  std::string precursor_feature_group;
  std::string main_precursor_feature_group;
  double cosine_similarity = 0.0;
  double main_precursor_cosine_similarity = 0.0;
  double rt_plausibility = 0.0;
  double main_precursor_rt_plausibility = 0.0;
};

/**
 * Project-scoped NTS facade layered on top of the Mass Spec project domain.
 *
 * The facade owns NTS tables in the shared project database and provides the
 * schema anchor for migrating legacy non-target-analysis result persistence
 * into ProjectNonTargetAnalysis.
 */
class PROJECT_NON_TARGET_ANALYSIS {
 public:
  explicit PROJECT_NON_TARGET_ANALYSIS(std::shared_ptr<project::CONTEXT> ctx);

  static void create_schema(const std::shared_ptr<project::CONTEXT>& ctx);
  static void validate_schema(const std::shared_ptr<project::CONTEXT>& ctx);

  bool find_features(const std::vector<std::string>& analyses,
                     const std::vector<float>& rt_windows_min,
                     const std::vector<float>& rt_windows_max,
                     float ppm_threshold = 15.0f,
                     float noise_threshold = 15.0f,
                     float min_snr = 3.0f,
                     int min_traces = 3,
                     float baseline_window = 200.0f,
                     float max_width = 100.0f,
                     float base_quantile = 0.10f,
                     const std::string& debug_analysis = "",
                     float debug_mz = 0.0f,
                     int debug_spec_idx = -1);
  bool suspect_screening(const std::vector<suspect_screening::SuspectQuery>& suspects,
                         const std::vector<std::string>& analyses = {},
                         double ppm = 5.0,
                         double sec = 10.0,
                         double ppm_ms2 = 10.0,
                         double mzr_ms2 = 0.008,
                         double min_cosine_similarity = 0.7,
                         int min_shared_fragments = 3,
                         bool filtered = false);
  bool find_internal_standards(const std::vector<suspect_screening::SuspectQuery>& suspects,
                               const std::vector<std::string>& analyses = {},
                               double ppm = 5.0,
                               double sec = 10.0,
                               double ppm_ms2 = 10.0,
                               double mzr_ms2 = 0.008,
                               double min_cosine_similarity = 0.7,
                               int min_shared_fragments = 3,
                               bool filtered = true);
  bool load_features_ms1(const std::vector<std::string>& analyses = {},
                         bool filtered = false,
                         const std::vector<float>& rt_window = {-2.0f, 2.0f},
                         const std::vector<float>& mz_window = {-1.0f, 6.0f},
                         float min_traces_intensity = 250.0f,
                         float mz_clust = 0.005f,
                         float presence = 0.8f);
  bool load_features_ms2(const std::vector<std::string>& analyses = {},
                         bool filtered = false,
                         float min_traces_intensity = 10.0f,
                         float isolation_window = 1.3f,
                         float mz_clust = 0.005f,
                         float presence = 0.8f);
  bool create_components(const std::vector<std::string>& analyses = {},
                         const std::vector<float>& rt_window = {0.0f, 0.0f},
                         float min_correlation = 0.8f,
                         float debug_rt = 0.0f,
                         const std::string& debug_analysis = "");
  bool annotate_components(const std::vector<std::string>& analyses = {},
                           int max_isotopes = 5,
                           int max_charge = 1,
                           int max_gaps = 1,
                           float ppm = 10.0f,
                           const std::string& debug_component = "",
                           const std::string& debug_analysis = "");
  bool group_features(const std::vector<std::string>& analyses = {},
                      const std::string& method = "internal_standards",
                      float rt_deviation = 5.0f,
                      float ppm = 10.0f,
                      int min_samples = 1,
                      float bin_size = 5.0f,
                      bool filtered = false,
                      bool debug = false,
                      float debug_rt = 0.0f);
  bool fill_features(const std::vector<std::string>& analyses = {},
                     bool within_replicate = false,
                     bool filtered = false,
                     float rt_expand = 10.0f,
                     float mz_expand = 0.01f,
                     float max_peak_width = 30.0f,
                     float min_traces_intensity = 1000.0f,
                     int min_number_traces = 5,
                     float min_intensity = 5000.0f,
                     float rt_apex_deviation = 5.0f,
                     float min_signal_to_noise_ratio = 3.0f,
                     float min_gaussian_fit = 0.2f,
                     const std::string& debug_fg = "");
  bool blank_subtraction(const std::vector<std::string>& analyses = {},
                         float blank_threshold = 5.0f,
                         float rt_expand = 10.0f,
                         float mz_expand = 0.005f);
  bool filter_features(const std::vector<std::string>& analyses = {},
                       double min_sn = std::numeric_limits<double>::quiet_NaN(),
                       double min_intensity = std::numeric_limits<double>::quiet_NaN(),
                       double min_area = std::numeric_limits<double>::quiet_NaN(),
                       double min_width = std::numeric_limits<double>::quiet_NaN(),
                       double max_width = std::numeric_limits<double>::quiet_NaN(),
                       double max_ppm = std::numeric_limits<double>::quiet_NaN(),
                       double min_fwhm_rt = std::numeric_limits<double>::quiet_NaN(),
                       double max_fwhm_rt = std::numeric_limits<double>::quiet_NaN(),
                       double min_fwhm_mz = std::numeric_limits<double>::quiet_NaN(),
                       double max_fwhm_mz = std::numeric_limits<double>::quiet_NaN(),
                       double min_gaussian_a = std::numeric_limits<double>::quiet_NaN(),
                       double min_gaussian_mu = std::numeric_limits<double>::quiet_NaN(),
                       double max_gaussian_mu = std::numeric_limits<double>::quiet_NaN(),
                       double min_gaussian_sigma = std::numeric_limits<double>::quiet_NaN(),
                       double max_gaussian_sigma = std::numeric_limits<double>::quiet_NaN(),
                       double min_gaussian_r2 = std::numeric_limits<double>::quiet_NaN(),
                       double max_jaggedness = std::numeric_limits<double>::quiet_NaN(),
                       double min_sharpness = std::numeric_limits<double>::quiet_NaN(),
                       double min_asymmetry = std::numeric_limits<double>::quiet_NaN(),
                       double max_asymmetry = std::numeric_limits<double>::quiet_NaN(),
                       int max_modality = std::numeric_limits<int>::min(),
                       double min_plates = std::numeric_limits<double>::quiet_NaN(),
                       bool has_only_filled = false,
                       bool only_filled_value = false,
                       bool remove_filled = false,
                       int min_size_eic = std::numeric_limits<int>::min(),
                       bool has_min_size_eic = false,
                       int min_size_ms1 = std::numeric_limits<int>::min(),
                       bool has_min_size_ms1 = false,
                       int min_size_ms2 = std::numeric_limits<int>::min(),
                       bool has_min_size_ms2 = false,
                       double min_rel_presence_replicate = std::numeric_limits<double>::quiet_NaN(),
                       bool remove_isotopes = false,
                       bool remove_adducts = false,
                       bool remove_losses = false);
  bool filter_suspects(const std::vector<std::string>& analyses = {},
                       const std::vector<std::string>& names = {},
                       double min_score = std::numeric_limits<double>::quiet_NaN(),
                       double max_error_rt = std::numeric_limits<double>::quiet_NaN(),
                       double max_error_mass = std::numeric_limits<double>::quiet_NaN(),
                       const std::vector<int>& id_levels = {},
                       int min_shared_fragments = 0,
                       double min_cosine_similarity = std::numeric_limits<double>::quiet_NaN());
  bool filter_internal_standards(const std::vector<std::string>& analyses = {},
                                 const std::vector<std::string>& names = {},
                                 double min_score = std::numeric_limits<double>::quiet_NaN(),
                                 double max_error_rt = std::numeric_limits<double>::quiet_NaN(),
                                 double max_error_mass = std::numeric_limits<double>::quiet_NaN(),
                                 const std::vector<int>& id_levels = {},
                                 int min_shared_fragments = 0,
                                 double min_cosine_similarity = std::numeric_limits<double>::quiet_NaN());
  bool filter_features_ms2(const std::vector<std::string>& analyses = {},
                           int top = 0,
                           double min_intensity = std::numeric_limits<double>::quiet_NaN(),
                           double rel_min_intensity = std::numeric_limits<double>::quiet_NaN(),
                           bool blank_clean = false,
                           double mz_clust = 0.005,
                           double blank_presence_threshold = 0.8,
                           double global_presence_threshold = 0.1);
  bool metfrag_screening(const std::string& metfrag_path,
                         const std::vector<std::string>& analyses = {},
                         const std::string& database_type = "LocalCSV",
                         const std::string& database_path = "",
                         double ppm = 5.0,
                         double sec = 10.0,
                         double ppm_ms2 = 10.0,
                         double mzr_ms2 = 0.008,
                         int top_n = 1,
                         bool filtered = false,
                         const std::string& java_path = "java",
                         const std::string& run_dir = "",
                         bool debug = false,
                         const std::vector<std::pair<std::string, std::string>>& extra_params = {});
  bool assign_transformation_products(
      const std::vector<assign_transformation_products::TPInputRow>& transformation_products,
      const std::string& chromatographic_phase = "reverse_phase",
      double mzr_ms2 = 0.008);
  std::vector<NTS_FEATURE_ROW> get_features(const std::vector<std::string>& analyses = {},
                                              bool include_filtered = false) const;
  std::vector<NTS_FEATURE_COUNT_ROW> get_features_count(const std::vector<std::string>& analyses = {},
                                                         bool include_filtered = false) const;
  std::vector<NTS_SUSPECT_ROW> get_suspects(
      const std::vector<std::string>& analyses = {},
      const std::vector<std::string>& features = {},
      const std::vector<std::string>& groups = {},
      const mass_spec::MS_TARGETS_INPUT& targets = {},
      double ppm = 20.0,
      double sec = 60.0,
      double millisec = 5.0) const;
  std::vector<NTS_INTERNAL_STANDARD_ROW> get_internal_standards(
      const std::vector<std::string>& analyses = {},
      const std::vector<std::string>& features = {},
      const std::vector<std::string>& groups = {},
      const mass_spec::MS_TARGETS_INPUT& targets = {},
      double ppm = 20.0,
      double sec = 60.0,
      double millisec = 5.0) const;
  std::vector<NTS_TRANSFORMATION_PRODUCT_ROW> get_transformation_products() const;

 private:
  std::shared_ptr<project::CONTEXT> ctx_;

  static constexpr const char* features_table_name() { return "NTS_FEATURES"; }
  static constexpr const char* internal_standards_table_name() { return "NTS_INTERNAL_STANDARDS"; }
  static constexpr const char* suspects_table_name() { return "NTS_SUSPECTS"; }
  static constexpr const char* transformation_products_table_name() { return "NTS_TRANSFORMATION_PRODUCTS"; }
};

}  // namespace nts
