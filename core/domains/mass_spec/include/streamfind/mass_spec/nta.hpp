#pragma once

#include "streamfind/mass_spec/reader.hpp"

#include <algorithm>
#include <cmath>
#include <fstream>
#include <iostream>
#include <numeric>
#include <sstream>
#include <string>
#include <tuple>
#include <vector>

namespace nta {
namespace utils {
extern std::ofstream debug_log;
void init_debug_log(const std::string &, const std::string & = {});
void close_debug_log();
float mean(const std::vector<float> &);
float standard_deviation(const std::vector<float> &, float);
float quantile(std::vector<float>, float);
std::vector<size_t> get_sort_indices_float(const std::vector<float> &);
void reorder_multiple_vectors(const std::vector<size_t> &, std::vector<float> &, std::vector<float> &, std::vector<float> &);
void reorder_multiple_vectors(const std::vector<size_t> &, std::vector<float> &, std::vector<float> &, std::vector<float> &, std::vector<float> &, std::vector<int> &);
std::vector<size_t> filter_above_threshold(const std::vector<float> &, const std::vector<float> &);
std::vector<int> cluster_by_threshold_float(const std::vector<float> &, const std::vector<float> &);
std::vector<float> calculate_baseline(const std::vector<float> &, int);
std::vector<float> smooth_intensity_savitzky_golay(const std::vector<float> &, int, int);
void calculate_derivatives(const std::vector<float> &, std::vector<float> &, std::vector<float> &);
void fit_gaussian(const std::vector<float> &, const std::vector<float> &, float &, float &, float &, float &);
float gaussian_function_with_baseline(float, float, float, float, float);
float calculate_gaussian_rsquared(const std::vector<float> &, const std::vector<float> &, float, float, float, float);
float calculate_area(const std::vector<float> &, const std::vector<float> &);
float calculate_jaggedness(const std::vector<float> &);
float calculate_sharpness(const std::vector<float> &, const std::vector<float> &, float);
float calculate_asymmetry(const std::vector<float> &, const std::vector<float> &);
int calculate_modality(const std::vector<float> &, float);
float calculate_theoretical_plates(float, float);
}
}

#define DEBUG_LOG(value) do { if (::nta::utils::debug_log.is_open()) ::nta::utils::debug_log << value; } while (false)

namespace nta::api {
struct NTA_FEATURE_ROW {
    std::string analysis, feature, feature_component, feature_group, adduct;
    double rt = 0, mz = 0, mass = 0, intensity = 0, noise = 0, sn = 0, area = 0;
    double rtmin = 0, rtmax = 0, width = 0, mzmin = 0, mzmax = 0, ppm = 0;
    double fwhm_rt = 0, fwhm_mz = 0, gaussian_A = 0, gaussian_mu = 0, gaussian_sigma = 0, gaussian_r2 = 0;
    double jaggedness = 0, sharpness = 0, asymmetry = 0;
    int modality = 0, polarity = 0, eic_size = 0, ms1_size = 0, ms2_size = 0;
    double plates = 0;
    bool filtered = false, filled = false;
    std::string filter;
    double correction = 0;
    std::string eic_rt, eic_mz, eic_intensity, eic_baseline, eic_smoothed;
    std::string ms1_mz, ms1_intensity, ms2_mz, ms2_intensity;
    std::string annotation_category, annotation_type, annotation_parent_feature, annotation_element;
    double annotation_mass_error_da = 0, annotation_mass_error_ppm = 0, annotation_rt_error = 0;
    double annotation_rel_intensity = 0, annotation_expected_rel_intensity_min = 0;
    double annotation_expected_rel_intensity_max = 0, annotation_score = 0;
    int component_size = 0;
    double component_rt_center = 0, component_rt_spread = 0, component_density = 0;
    double component_mean_correlation = 0;
    std::string component_best_partner;
    double component_max_correlation = 0, component_mean_correlation_to_component = 0;
    double component_membership_score = 0;
    bool component_is_core = false, component_bridge_flag = false;
};

struct NTA_FEATURES {
    std::vector<NTA_FEATURE_ROW> rows;
    std::string analysis;
    void append_feature(const NTA_FEATURE_ROW &row) { rows.push_back(row); }
};
}

namespace nta {
class PROJECT_NON_TARGET_ANALYSIS {
public:
    PROJECT_NON_TARGET_ANALYSIS(std::vector<std::string> names, std::vector<std::string> paths,
                                std::vector<mass_spec::reader::MASS_SPEC_SPECTRA_HEADERS> headers)
        : names_(std::move(names)), paths_(std::move(paths)), headers_(std::move(headers)), buffers_(names_.size()) {}
    const std::vector<std::string> &analysis_names() const { return names_; }
    const std::vector<std::string> &file_paths() const { return paths_; }
    const auto &spectra_headers_at(size_t i) const { return headers_.at(i); }
    auto &feature_buffers() { return buffers_; }
private:
    std::vector<std::string> names_, paths_;
    std::vector<mass_spec::reader::MASS_SPEC_SPECTRA_HEADERS> headers_;
    std::vector<api::NTA_FEATURES> buffers_;
};
using namespace api;
}
