#ifndef NTA_H
#define NTA_H

#include <vector>
#include <fstream>
#include <iomanip>
#include <numeric>
#include <sstream>
#include <unordered_map>
#include <iostream>

#include "nta_deconvolution.h"
#include "nta_annotation.h"
#include "nta_componentization.h"
#include "nta_alignment.h"
#include "nta_gap_filling.h"
#include "nta_blank_subtraction.h"
#include "nta_correction_algorithms.h"
#include "nta_filters.h"
#include "nta_suspect_screening.h"
#include "nta_metfrag_runner.h"
#include "nta_assign_transformation_products.h"

#include "project/project.h"
#include "mass_spec/mass_spec.h"
#include "mass_spec/reader.h"

namespace nta
{

  // MARK: NTA_INFO
  struct NTA_INFO
  {
    std::vector<std::string> analyses;
    std::vector<std::string> replicates;
    std::vector<std::string> blanks;
    std::vector<std::string> files;

    int size() const
    {
      return analyses.size();
    }
  };

  // MARK: ns utils
  namespace utils
  {
    // Debug log file stream (global for debugging)
    extern std::ofstream debug_log;

    // Helper function to initialize debug log with dynamic filename
    void init_debug_log(const std::string &filename, const std::string &header = "");

    // Helper function to close debug log
    void close_debug_log();

    // (DEBUG_LOG/DEBUG_OUT moved to global scope at end of header)

    float mean(const std::vector<float> &v);

    float standard_deviation(const std::vector<float> &v, float mean_val);

    float quantile(std::vector<float> data, float quantile_fraction);

    std::string encode_floats_base64(const std::vector<float> &input, int precision = 4);

    float gaussian_function(const float &A, const float &mu, const float &sigma, const float &x);

    float gaussian_function_with_baseline(
        const float &A,
        const float &mu,
        const float &sigma,
        const float &baseline,
        const float &x);

    std::vector<size_t> get_sort_indices_float(const std::vector<float> &data);

    void reorder_float_data(std::vector<float> &data, const std::vector<size_t> &indices);

    void reorder_int_data(std::vector<int> &data, const std::vector<size_t> &indices);

    void reorder_multiple_vectors(
        const std::vector<size_t> &indices,
        std::vector<float> &vec1);

    void reorder_multiple_vectors(
        const std::vector<size_t> &indices,
        std::vector<float> &vec1,
        std::vector<float> &vec2);

    void reorder_multiple_vectors(
        const std::vector<size_t> &indices,
        std::vector<float> &vec1,
        std::vector<float> &vec2,
        std::vector<float> &vec3);

    void reorder_multiple_vectors(
        const std::vector<size_t> &indices,
        std::vector<float> &vec1,
        std::vector<float> &vec2,
        std::vector<float> &vec3,
        std::vector<float> &vec4);

    void reorder_multiple_vectors(
        const std::vector<size_t> &indices,
        std::vector<float> &vec1,
        std::vector<float> &vec2,
        std::vector<float> &vec3,
        std::vector<float> &vec4,
        std::vector<int> &int_vec);

    std::vector<size_t> filter_above_threshold(
        const std::vector<float> &data,
        const std::vector<float> &thresholds);

    std::vector<int> cluster_by_threshold_float(
        const std::vector<float> &sorted_data,
        const std::vector<float> &thresholds);

    std::vector<float> calculate_baseline(const std::vector<float> &intensity, int windowSize);

    std::vector<float> smooth_intensity_savitzky_golay(
        const std::vector<float> &intensity,
        int windowSize,
        int polyOrder);

    std::vector<float> smooth_intensity(const std::vector<float> &intensity, int windowSize);

    void calculate_derivatives(
        const std::vector<float> &smoothed_intensity,
        std::vector<float> &first_derivative,
        std::vector<float> &second_derivative);

    float calculate_jaggedness(const std::vector<float> &intensity);

    float calculate_sharpness(
        const std::vector<float> &rt,
        const std::vector<float> &intensity,
        float area);

    float calculate_asymmetry(
        const std::vector<float> &rt,
        const std::vector<float> &intensity);

    int calculate_modality(
        const std::vector<float> &smoothed_intensity,
        float min_prominence_ratio);

    float calculate_theoretical_plates(float rt_apex, float width_at_half_height);

    // Calculate peak area using trapezoidal integration
    float calculate_area(const std::vector<float> &rt, const std::vector<float> &intensity);

    // Gaussian fitting functions
    float gaussian_cost_function(
        const std::vector<float> &x,
        const std::vector<float> &y,
        float A, float mu, float sigma);

    void fit_gaussian(
        const std::vector<float> &x,
        const std::vector<float> &y,
        float &A, float &mu, float &sigma,
        float &baseline);

    float calculate_gaussian_rsquared(
        const std::vector<float> &x,
        const std::vector<float> &y,
        float A, float mu, float sigma,
        float baseline);

  }

  // MARK: ns api
  namespace api
  {
    struct NTA_FEATURE_SPECTRUM
    {
      std::vector<float> mz;
      std::vector<float> intensity;
      // Optional constructor to initialize from targets spectra
      NTA_FEATURE_SPECTRUM() = default;
      NTA_FEATURE_SPECTRUM(const mass_spec::spectra::MS_TARGETS_SPECTRA &spectra,
                           float mzClust,
                           float presence);

      // Optional initializer
      void init_from_targets(const mass_spec::spectra::MS_TARGETS_SPECTRA &spectra,
                             float mzClust,
                             float presence);
    };

    // MARK: merge_NTA_FEATURE_SPECTRA
    NTA_FEATURE_SPECTRUM merge_NTA_FEATURE_SPECTRA(
        const mass_spec::spectra::MS_TARGETS_SPECTRA &spectra,
        const float &mzClust,
        const float &presence);

    // MARK: NTA_FEATURE_ROW
    struct NTA_FEATURE_ROW : public project::api::ROW
    {
      std::string analysis;
      std::string feature;
      std::string id;
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
      std::string annotation_category;
      std::string annotation_type;
      std::string annotation_parent_feature;
      std::string annotation_element;
      double annotation_mass_error_da = 0.0;
      double annotation_mass_error_ppm = 0.0;
      double annotation_rt_error = 0.0;
      double annotation_rel_intensity = 0.0;
      double annotation_expected_rel_intensity_min = 0.0;
      double annotation_expected_rel_intensity_max = 0.0;
      double annotation_score = 0.0;
    };

    struct NTA_FEATURES_COUNT_ROW
    {
      std::string analysis;
      int total = 0;
      int filtered = 0;
      int groups = 0;
      int components = 0;
    };

    // MARK: NTA_FEATURES
    struct NTA_FEATURES
    {
      std::string analysis;
      std::vector<std::string> feature;
      std::vector<std::string> feature_group;
      std::vector<std::string> feature_component;
      std::vector<std::string> adduct;
      std::vector<float> rt;
      std::vector<float> mz;
      std::vector<float> mass;
      std::vector<float> intensity;
      std::vector<float> noise;
      std::vector<float> sn;
      std::vector<float> area;
      std::vector<float> rtmin;
      std::vector<float> rtmax;
      std::vector<float> width;
      std::vector<float> mzmin;
      std::vector<float> mzmax;
      std::vector<float> ppm;
      std::vector<float> fwhm_rt;
      std::vector<float> fwhm_mz;
      std::vector<float> gaussian_A;
      std::vector<float> gaussian_mu;
      std::vector<float> gaussian_sigma;
      std::vector<float> gaussian_r2;
      std::vector<float> jaggedness;
      std::vector<float> sharpness;
      std::vector<float> asymmetry;
      std::vector<int> modality;
      std::vector<float> plates;
      std::vector<int> polarity;
      std::vector<bool> filtered;
      std::vector<std::string> filter;
      std::vector<bool> filled;
      std::vector<float> correction;
      std::vector<int> eic_size;
      std::vector<std::string> eic_rt;
      std::vector<std::string> eic_mz;
      std::vector<std::string> eic_intensity;
      std::vector<std::string> eic_baseline;
      std::vector<std::string> eic_smoothed;
      std::vector<int> ms1_size;
      std::vector<std::string> ms1_mz;
      std::vector<std::string> ms1_intensity;
      std::vector<int> ms2_size;
      std::vector<std::string> ms2_mz;
      std::vector<std::string> ms2_intensity;
      std::vector<std::string> annotation_category;
      std::vector<std::string> annotation_type;
      std::vector<std::string> annotation_parent_feature;
      std::vector<std::string> annotation_element;
      std::vector<float> annotation_mass_error_da;
      std::vector<float> annotation_mass_error_ppm;
      std::vector<float> annotation_rt_error;
      std::vector<float> annotation_rel_intensity;
      std::vector<float> annotation_expected_rel_intensity_min;
      std::vector<float> annotation_expected_rel_intensity_max;
      std::vector<float> annotation_score;

      int size() const
      {
        return feature.size();
      };

      std::vector<std::uint8_t> serialize_object() const;

      static NTA_FEATURES deserialize_object(const std::vector<std::uint8_t> &bytes);

      NTA_FEATURE_ROW get_feature(const int &i) const
      {
        NTA_FEATURE_ROW feature_i;
        feature_i.analysis = analysis;
        feature_i.feature = feature[i];
        feature_i.feature_group = feature_group[i];
        feature_i.feature_component = feature_component[i];
        feature_i.adduct = adduct[i];
        feature_i.rt = rt[i];
        feature_i.mz = mz[i];
        feature_i.mass = mass[i];
        feature_i.intensity = intensity[i];
        feature_i.noise = noise[i];
        feature_i.sn = sn[i];
        feature_i.area = area[i];
        feature_i.rtmin = rtmin[i];
        feature_i.rtmax = rtmax[i];
        feature_i.width = width[i];
        feature_i.mzmin = mzmin[i];
        feature_i.mzmax = mzmax[i];
        feature_i.ppm = ppm[i];
        feature_i.fwhm_rt = fwhm_rt[i];
        feature_i.fwhm_mz = fwhm_mz[i];
        feature_i.gaussian_A = gaussian_A[i];
        feature_i.gaussian_mu = gaussian_mu[i];
        feature_i.gaussian_sigma = gaussian_sigma[i];
        feature_i.gaussian_r2 = gaussian_r2[i];
        feature_i.jaggedness = jaggedness[i];
        feature_i.sharpness = sharpness[i];
        feature_i.asymmetry = asymmetry[i];
        feature_i.modality = modality[i];
        feature_i.plates = plates[i];
        feature_i.polarity = polarity[i];
        feature_i.filtered = filtered[i];
        feature_i.filter = filter[i];
        feature_i.filled = filled[i];
        feature_i.correction = correction[i];
        feature_i.eic_size = eic_size[i];
        feature_i.eic_rt = eic_rt[i];
        feature_i.eic_mz = eic_mz[i];
        feature_i.eic_intensity = eic_intensity[i];
        feature_i.eic_baseline = eic_baseline[i];
        feature_i.eic_smoothed = eic_smoothed[i];
        feature_i.ms1_size = ms1_size[i];
        feature_i.ms1_mz = ms1_mz[i];
        feature_i.ms1_intensity = ms1_intensity[i];
        feature_i.ms2_size = ms2_size[i];
        feature_i.ms2_mz = ms2_mz[i];
        feature_i.ms2_intensity = ms2_intensity[i];
        feature_i.annotation_category = annotation_category[i];
        feature_i.annotation_type = annotation_type[i];
        feature_i.annotation_parent_feature = annotation_parent_feature[i];
        feature_i.annotation_element = annotation_element[i];
        feature_i.annotation_mass_error_da = annotation_mass_error_da[i];
        feature_i.annotation_mass_error_ppm = annotation_mass_error_ppm[i];
        feature_i.annotation_rt_error = annotation_rt_error[i];
        feature_i.annotation_rel_intensity = annotation_rel_intensity[i];
        feature_i.annotation_expected_rel_intensity_min = annotation_expected_rel_intensity_min[i];
        feature_i.annotation_expected_rel_intensity_max = annotation_expected_rel_intensity_max[i];
        feature_i.annotation_score = annotation_score[i];
        return feature_i;
      };

      void set_feature(const int &i, const NTA_FEATURE_ROW &feature_i)
      {
        feature[i] = feature_i.feature;
        feature_group[i] = feature_i.feature_group;
        feature_component[i] = feature_i.feature_component;
        adduct[i] = feature_i.adduct;
        rt[i] = feature_i.rt;
        mz[i] = feature_i.mz;
        mass[i] = feature_i.mass;
        intensity[i] = feature_i.intensity;
        noise[i] = feature_i.noise;
        sn[i] = feature_i.sn;
        area[i] = feature_i.area;
        rtmin[i] = feature_i.rtmin;
        rtmax[i] = feature_i.rtmax;
        width[i] = feature_i.width;
        mzmin[i] = feature_i.mzmin;
        mzmax[i] = feature_i.mzmax;
        ppm[i] = feature_i.ppm;
        fwhm_rt[i] = feature_i.fwhm_rt;
        fwhm_mz[i] = feature_i.fwhm_mz;
        gaussian_A[i] = feature_i.gaussian_A;
        gaussian_mu[i] = feature_i.gaussian_mu;
        gaussian_sigma[i] = feature_i.gaussian_sigma;
        gaussian_r2[i] = feature_i.gaussian_r2;
        jaggedness[i] = feature_i.jaggedness;
        sharpness[i] = feature_i.sharpness;
        asymmetry[i] = feature_i.asymmetry;
        modality[i] = feature_i.modality;
        plates[i] = feature_i.plates;
        polarity[i] = feature_i.polarity;
        filtered[i] = feature_i.filtered;
        filter[i] = feature_i.filter;
        filled[i] = feature_i.filled;
        correction[i] = feature_i.correction;
        eic_size[i] = feature_i.eic_size;
        eic_rt[i] = feature_i.eic_rt;
        eic_mz[i] = feature_i.eic_mz;
        eic_intensity[i] = feature_i.eic_intensity;
        eic_baseline[i] = feature_i.eic_baseline;
        eic_smoothed[i] = feature_i.eic_smoothed;
        ms1_size[i] = feature_i.ms1_size;
        ms1_mz[i] = feature_i.ms1_mz;
        ms1_intensity[i] = feature_i.ms1_intensity;
        ms2_size[i] = feature_i.ms2_size;
        ms2_mz[i] = feature_i.ms2_mz;
        ms2_intensity[i] = feature_i.ms2_intensity;
        annotation_category[i] = feature_i.annotation_category;
        annotation_type[i] = feature_i.annotation_type;
        annotation_parent_feature[i] = feature_i.annotation_parent_feature;
        annotation_element[i] = feature_i.annotation_element;
        annotation_mass_error_da[i] = feature_i.annotation_mass_error_da;
        annotation_mass_error_ppm[i] = feature_i.annotation_mass_error_ppm;
        annotation_rt_error[i] = feature_i.annotation_rt_error;
        annotation_rel_intensity[i] = feature_i.annotation_rel_intensity;
        annotation_expected_rel_intensity_min[i] = feature_i.annotation_expected_rel_intensity_min;
        annotation_expected_rel_intensity_max[i] = feature_i.annotation_expected_rel_intensity_max;
        annotation_score[i] = feature_i.annotation_score;
      };

      void append_feature(const NTA_FEATURE_ROW &feature_i)
      {
        feature.push_back(feature_i.feature);
        feature_group.push_back(feature_i.feature_group);
        feature_component.push_back(feature_i.feature_component);
        adduct.push_back(feature_i.adduct);
        rt.push_back(feature_i.rt);
        mz.push_back(feature_i.mz);
        mass.push_back(feature_i.mass);
        intensity.push_back(feature_i.intensity);
        noise.push_back(feature_i.noise);
        sn.push_back(feature_i.sn);
        area.push_back(feature_i.area);
        rtmin.push_back(feature_i.rtmin);
        rtmax.push_back(feature_i.rtmax);
        width.push_back(feature_i.width);
        mzmin.push_back(feature_i.mzmin);
        mzmax.push_back(feature_i.mzmax);
        ppm.push_back(feature_i.ppm);
        fwhm_rt.push_back(feature_i.fwhm_rt);
        fwhm_mz.push_back(feature_i.fwhm_mz);
        gaussian_A.push_back(feature_i.gaussian_A);
        gaussian_mu.push_back(feature_i.gaussian_mu);
        gaussian_sigma.push_back(feature_i.gaussian_sigma);
        gaussian_r2.push_back(feature_i.gaussian_r2);
        jaggedness.push_back(feature_i.jaggedness);
        sharpness.push_back(feature_i.sharpness);
        asymmetry.push_back(feature_i.asymmetry);
        modality.push_back(feature_i.modality);
        plates.push_back(feature_i.plates);
        polarity.push_back(feature_i.polarity);
        filtered.push_back(feature_i.filtered);
        filter.push_back(feature_i.filter);
        filled.push_back(feature_i.filled);
        correction.push_back(feature_i.correction);
        eic_size.push_back(feature_i.eic_size);
        eic_rt.push_back(feature_i.eic_rt);
        eic_mz.push_back(feature_i.eic_mz);
        eic_intensity.push_back(feature_i.eic_intensity);
        eic_baseline.push_back(feature_i.eic_baseline);
        eic_smoothed.push_back(feature_i.eic_smoothed);
        ms1_size.push_back(feature_i.ms1_size);
        ms1_mz.push_back(feature_i.ms1_mz);
        ms1_intensity.push_back(feature_i.ms1_intensity);
        ms2_size.push_back(feature_i.ms2_size);
        ms2_mz.push_back(feature_i.ms2_mz);
        ms2_intensity.push_back(feature_i.ms2_intensity);
        annotation_category.push_back(feature_i.annotation_category);
        annotation_type.push_back(feature_i.annotation_type);
        annotation_parent_feature.push_back(feature_i.annotation_parent_feature);
        annotation_element.push_back(feature_i.annotation_element);
        annotation_mass_error_da.push_back(feature_i.annotation_mass_error_da);
        annotation_mass_error_ppm.push_back(feature_i.annotation_mass_error_ppm);
        annotation_rt_error.push_back(feature_i.annotation_rt_error);
        annotation_rel_intensity.push_back(feature_i.annotation_rel_intensity);
        annotation_expected_rel_intensity_min.push_back(feature_i.annotation_expected_rel_intensity_min);
        annotation_expected_rel_intensity_max.push_back(feature_i.annotation_expected_rel_intensity_max);
        annotation_score.push_back(feature_i.annotation_score);
      };

      void set_analysis(const std::string &a)
      {
        analysis = a;
      }

      void sort_by_mz()
      {
        if (feature.size() == 0)
          return;

        std::vector<int> new_order(feature.size());
        std::iota(new_order.begin(), new_order.end(), 0);

        std::sort(new_order.begin(), new_order.end(), [this](int i1, int i2)
                  { return mz[i1] < mz[i2]; });

        // Create sorted copies of all vectors
        std::vector<std::string> feature_sorted(feature.size());
        std::vector<std::string> feature_group_sorted(feature.size());
        std::vector<std::string> feature_component_sorted(feature.size());
        std::vector<std::string> adduct_sorted(feature.size());
        std::vector<float> rt_sorted(feature.size());
        std::vector<float> mz_sorted(feature.size());
        std::vector<float> mass_sorted(feature.size());
        std::vector<float> intensity_sorted(feature.size());
        std::vector<float> noise_sorted(feature.size());
        std::vector<float> sn_sorted(feature.size());
        std::vector<float> area_sorted(feature.size());
        std::vector<float> rtmin_sorted(feature.size());
        std::vector<float> rtmax_sorted(feature.size());
        std::vector<float> width_sorted(feature.size());
        std::vector<float> mzmin_sorted(feature.size());
        std::vector<float> mzmax_sorted(feature.size());
        std::vector<float> ppm_sorted(feature.size());
        std::vector<float> fwhm_rt_sorted(feature.size());
        std::vector<float> fwhm_mz_sorted(feature.size());
        std::vector<float> gaussian_A_sorted(feature.size());
        std::vector<float> gaussian_mu_sorted(feature.size());
        std::vector<float> gaussian_sigma_sorted(feature.size());
        std::vector<float> gaussian_r2_sorted(feature.size());
        std::vector<float> jaggedness_sorted(feature.size());
        std::vector<float> sharpness_sorted(feature.size());
        std::vector<float> asymmetry_sorted(feature.size());
        std::vector<int> modality_sorted(feature.size());
        std::vector<float> plates_sorted(feature.size());
        std::vector<int> polarity_sorted(feature.size());
        std::vector<bool> filtered_sorted(feature.size());
        std::vector<std::string> filter_sorted(feature.size());
        std::vector<bool> filled_sorted(feature.size());
        std::vector<float> correction_sorted(feature.size());
        std::vector<int> eic_size_sorted(feature.size());
        std::vector<std::string> eic_rt_sorted(feature.size());
        std::vector<std::string> eic_mz_sorted(feature.size());
        std::vector<std::string> eic_intensity_sorted(feature.size());
        std::vector<std::string> eic_baseline_sorted(feature.size());
        std::vector<std::string> eic_smoothed_sorted(feature.size());
        std::vector<int> ms1_size_sorted(feature.size());
        std::vector<std::string> ms1_mz_sorted(feature.size());
        std::vector<std::string> ms1_intensity_sorted(feature.size());
        std::vector<int> ms2_size_sorted(feature.size());
        std::vector<std::string> ms2_mz_sorted(feature.size());
        std::vector<std::string> ms2_intensity_sorted(feature.size());
        std::vector<std::string> annotation_category_sorted(feature.size());
        std::vector<std::string> annotation_type_sorted(feature.size());
        std::vector<std::string> annotation_parent_feature_sorted(feature.size());
        std::vector<std::string> annotation_element_sorted(feature.size());
        std::vector<float> annotation_mass_error_da_sorted(feature.size());
        std::vector<float> annotation_mass_error_ppm_sorted(feature.size());
        std::vector<float> annotation_rt_error_sorted(feature.size());
        std::vector<float> annotation_rel_intensity_sorted(feature.size());
        std::vector<float> annotation_expected_rel_intensity_min_sorted(feature.size());
        std::vector<float> annotation_expected_rel_intensity_max_sorted(feature.size());
        std::vector<float> annotation_score_sorted(feature.size());

        for (size_t i = 0; i < feature.size(); i++)
        {
          int idx = new_order[i];
          feature_sorted[i] = feature[idx];
          feature_group_sorted[i] = feature_group[idx];
          feature_component_sorted[i] = feature_component[idx];
          adduct_sorted[i] = adduct[idx];
          rt_sorted[i] = rt[idx];
          mz_sorted[i] = mz[idx];
          mass_sorted[i] = mass[idx];
          intensity_sorted[i] = intensity[idx];
          noise_sorted[i] = noise[idx];
          sn_sorted[i] = sn[idx];
          area_sorted[i] = area[idx];
          rtmin_sorted[i] = rtmin[idx];
          rtmax_sorted[i] = rtmax[idx];
          width_sorted[i] = width[idx];
          mzmin_sorted[i] = mzmin[idx];
          mzmax_sorted[i] = mzmax[idx];
          ppm_sorted[i] = ppm[idx];
          fwhm_rt_sorted[i] = fwhm_rt[idx];
          fwhm_mz_sorted[i] = fwhm_mz[idx];
          gaussian_A_sorted[i] = gaussian_A[idx];
          gaussian_mu_sorted[i] = gaussian_mu[idx];
          gaussian_sigma_sorted[i] = gaussian_sigma[idx];
          gaussian_r2_sorted[i] = gaussian_r2[idx];
          jaggedness_sorted[i] = jaggedness[idx];
          sharpness_sorted[i] = sharpness[idx];
          asymmetry_sorted[i] = asymmetry[idx];
          modality_sorted[i] = modality[idx];
          plates_sorted[i] = plates[idx];
          polarity_sorted[i] = polarity[idx];
          filtered_sorted[i] = filtered[idx];
          filter_sorted[i] = filter[idx];
          filled_sorted[i] = filled[idx];
          correction_sorted[i] = correction[idx];
          eic_size_sorted[i] = eic_size[idx];
          eic_rt_sorted[i] = eic_rt[idx];
          eic_mz_sorted[i] = eic_mz[idx];
          eic_intensity_sorted[i] = eic_intensity[idx];
          eic_baseline_sorted[i] = eic_baseline[idx];
          eic_smoothed_sorted[i] = eic_smoothed[idx];
          ms1_size_sorted[i] = ms1_size[idx];
          ms1_mz_sorted[i] = ms1_mz[idx];
          ms1_intensity_sorted[i] = ms1_intensity[idx];
          ms2_size_sorted[i] = ms2_size[idx];
          ms2_mz_sorted[i] = ms2_mz[idx];
          ms2_intensity_sorted[i] = ms2_intensity[idx];
          annotation_category_sorted[i] = annotation_category[idx];
          annotation_type_sorted[i] = annotation_type[idx];
          annotation_parent_feature_sorted[i] = annotation_parent_feature[idx];
          annotation_element_sorted[i] = annotation_element[idx];
          annotation_mass_error_da_sorted[i] = annotation_mass_error_da[idx];
          annotation_mass_error_ppm_sorted[i] = annotation_mass_error_ppm[idx];
          annotation_rt_error_sorted[i] = annotation_rt_error[idx];
          annotation_rel_intensity_sorted[i] = annotation_rel_intensity[idx];
          annotation_expected_rel_intensity_min_sorted[i] = annotation_expected_rel_intensity_min[idx];
          annotation_expected_rel_intensity_max_sorted[i] = annotation_expected_rel_intensity_max[idx];
          annotation_score_sorted[i] = annotation_score[idx];
        }

        // Replace with sorted vectors
        feature = feature_sorted;
        feature_group = feature_group_sorted;
        feature_component = feature_component_sorted;
        adduct = adduct_sorted;
        rt = rt_sorted;
        mz = mz_sorted;
        mass = mass_sorted;
        intensity = intensity_sorted;
        noise = noise_sorted;
        sn = sn_sorted;
        area = area_sorted;
        rtmin = rtmin_sorted;
        rtmax = rtmax_sorted;
        width = width_sorted;
        mzmin = mzmin_sorted;
        mzmax = mzmax_sorted;
        ppm = ppm_sorted;
        fwhm_rt = fwhm_rt_sorted;
        fwhm_mz = fwhm_mz_sorted;
        gaussian_A = gaussian_A_sorted;
        gaussian_mu = gaussian_mu_sorted;
        gaussian_sigma = gaussian_sigma_sorted;
        gaussian_r2 = gaussian_r2_sorted;
        jaggedness = jaggedness_sorted;
        sharpness = sharpness_sorted;
        asymmetry = asymmetry_sorted;
        modality = modality_sorted;
        plates = plates_sorted;
        polarity = polarity_sorted;
        filtered = filtered_sorted;
        filter = filter_sorted;
        filled = filled_sorted;
        correction = correction_sorted;
        eic_size = eic_size_sorted;
        eic_rt = eic_rt_sorted;
        eic_mz = eic_mz_sorted;
        eic_intensity = eic_intensity_sorted;
        eic_baseline = eic_baseline_sorted;
        eic_smoothed = eic_smoothed_sorted;
        ms1_size = ms1_size_sorted;
        ms1_mz = ms1_mz_sorted;
        ms1_intensity = ms1_intensity_sorted;
        ms2_size = ms2_size_sorted;
        ms2_mz = ms2_mz_sorted;
        ms2_intensity = ms2_intensity_sorted;
        annotation_category = annotation_category_sorted;
        annotation_type = annotation_type_sorted;
        annotation_parent_feature = annotation_parent_feature_sorted;
        annotation_element = annotation_element_sorted;
        annotation_mass_error_da = annotation_mass_error_da_sorted;
        annotation_mass_error_ppm = annotation_mass_error_ppm_sorted;
        annotation_rt_error = annotation_rt_error_sorted;
        annotation_rel_intensity = annotation_rel_intensity_sorted;
        annotation_expected_rel_intensity_min = annotation_expected_rel_intensity_min_sorted;
        annotation_expected_rel_intensity_max = annotation_expected_rel_intensity_max_sorted;
        annotation_score = annotation_score_sorted;
      };
    };

    struct NTA_FEATURES_TABLE
    {
      std::vector<std::string> project_id;
      std::vector<std::string> analysis;
      std::vector<std::string> feature;
      std::vector<std::string> feature_component;
      std::vector<std::string> feature_group;
      std::vector<std::string> adduct;
      std::vector<double> rt;
      std::vector<double> mz;
      std::vector<double> mass;
      std::vector<double> intensity;
      std::vector<double> noise;
      std::vector<double> sn;
      std::vector<double> area;
      std::vector<double> rtmin;
      std::vector<double> rtmax;
      std::vector<double> width;
      std::vector<double> mzmin;
      std::vector<double> mzmax;
      std::vector<double> ppm;
      std::vector<double> fwhm_rt;
      std::vector<double> fwhm_mz;
      std::vector<double> gaussian_A;
      std::vector<double> gaussian_mu;
      std::vector<double> gaussian_sigma;
      std::vector<double> gaussian_r2;
      std::vector<double> jaggedness;
      std::vector<double> sharpness;
      std::vector<double> asymmetry;
      std::vector<int> modality;
      std::vector<double> plates;
      std::vector<int> polarity;
      std::vector<bool> filtered;
      std::vector<std::string> filter;
      std::vector<bool> filled;
      std::vector<double> correction;
      std::vector<int> eic_size;
      std::vector<std::string> eic_rt;
      std::vector<std::string> eic_mz;
      std::vector<std::string> eic_intensity;
      std::vector<std::string> eic_baseline;
      std::vector<std::string> eic_smoothed;
      std::vector<int> ms1_size;
      std::vector<std::string> ms1_mz;
      std::vector<std::string> ms1_intensity;
      std::vector<int> ms2_size;
      std::vector<std::string> ms2_mz;
      std::vector<std::string> ms2_intensity;
      std::vector<std::string> annotation_category;
      std::vector<std::string> annotation_type;
      std::vector<std::string> annotation_parent_feature;
      std::vector<std::string> annotation_element;
      std::vector<double> annotation_mass_error_da;
      std::vector<double> annotation_mass_error_ppm;
      std::vector<double> annotation_rt_error;
      std::vector<double> annotation_rel_intensity;
      std::vector<double> annotation_expected_rel_intensity_min;
      std::vector<double> annotation_expected_rel_intensity_max;
      std::vector<double> annotation_score;
      std::vector<std::string> created_at;

      int size() const { return static_cast<int>(feature.size()); }

      void append(const NTA_FEATURE_ROW &row)
      {
        project_id.push_back(row.project_id);
        analysis.push_back(row.analysis);
        feature.push_back(row.feature);
        feature_component.push_back(row.feature_component);
        feature_group.push_back(row.feature_group);
        adduct.push_back(row.adduct);
        rt.push_back(row.rt);
        mz.push_back(row.mz);
        mass.push_back(row.mass);
        intensity.push_back(row.intensity);
        noise.push_back(row.noise);
        sn.push_back(row.sn);
        area.push_back(row.area);
        rtmin.push_back(row.rtmin);
        rtmax.push_back(row.rtmax);
        width.push_back(row.width);
        mzmin.push_back(row.mzmin);
        mzmax.push_back(row.mzmax);
        ppm.push_back(row.ppm);
        fwhm_rt.push_back(row.fwhm_rt);
        fwhm_mz.push_back(row.fwhm_mz);
        gaussian_A.push_back(row.gaussian_A);
        gaussian_mu.push_back(row.gaussian_mu);
        gaussian_sigma.push_back(row.gaussian_sigma);
        gaussian_r2.push_back(row.gaussian_r2);
        jaggedness.push_back(row.jaggedness);
        sharpness.push_back(row.sharpness);
        asymmetry.push_back(row.asymmetry);
        modality.push_back(row.modality);
        plates.push_back(row.plates);
        polarity.push_back(row.polarity);
        filtered.push_back(row.filtered);
        filter.push_back(row.filter);
        filled.push_back(row.filled);
        correction.push_back(row.correction);
        eic_size.push_back(row.eic_size);
        eic_rt.push_back(row.eic_rt);
        eic_mz.push_back(row.eic_mz);
        eic_intensity.push_back(row.eic_intensity);
        eic_baseline.push_back(row.eic_baseline);
        eic_smoothed.push_back(row.eic_smoothed);
        ms1_size.push_back(row.ms1_size);
        ms1_mz.push_back(row.ms1_mz);
        ms1_intensity.push_back(row.ms1_intensity);
        ms2_size.push_back(row.ms2_size);
        ms2_mz.push_back(row.ms2_mz);
        ms2_intensity.push_back(row.ms2_intensity);
        annotation_category.push_back(row.annotation_category);
        annotation_type.push_back(row.annotation_type);
        annotation_parent_feature.push_back(row.annotation_parent_feature);
        annotation_element.push_back(row.annotation_element);
        annotation_mass_error_da.push_back(row.annotation_mass_error_da);
        annotation_mass_error_ppm.push_back(row.annotation_mass_error_ppm);
        annotation_rt_error.push_back(row.annotation_rt_error);
        annotation_rel_intensity.push_back(row.annotation_rel_intensity);
        annotation_expected_rel_intensity_min.push_back(row.annotation_expected_rel_intensity_min);
        annotation_expected_rel_intensity_max.push_back(row.annotation_expected_rel_intensity_max);
        annotation_score.push_back(row.annotation_score);
        created_at.push_back(row.created_at);
      }
    };

    struct NTA_FEATURES_CACHE
    {
      std::vector<NTA_FEATURES> buffers;

      std::vector<std::uint8_t> serialize_object() const;

      static NTA_FEATURES_CACHE deserialize_object(const std::vector<std::uint8_t> &bytes);
    };

    NTA_FEATURE_ROW feature_row_from_table(const NTA_FEATURES_TABLE &table, std::size_t row);

    struct NTA_FEATURE_COUNT_ROW
    {
      std::string analysis;
      int total = 0;
      int filtered = 0;
      int groups = 0;
      int components = 0;
    };

    // MARK: NTA_SUSPECT_ROW
    struct NTA_SUSPECT_ROW : public project::api::ROW
    {
      std::string analysis;
      std::string feature;
      std::string feature_group;
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

    // MARK: NTA_SUSPECTS
    struct NTA_SUSPECTS
    {
      std::vector<std::string> analysis;
      std::vector<std::string> feature;
      std::vector<int> candidate_rank;
      std::vector<std::string> name;
      std::vector<int> polarity;
      std::vector<double> db_mass;
      std::vector<double> exp_mass;
      std::vector<double> error_mass;
      std::vector<double> db_rt;
      std::vector<double> exp_rt;
      std::vector<double> error_rt;
      std::vector<double> intensity;
      std::vector<double> area;
      std::vector<int> id_level;
      std::vector<double> score;
      std::vector<int> shared_fragments;
      std::vector<double> cosine_similarity;
      std::vector<std::string> formula;
      std::vector<std::string> SMILES;
      std::vector<std::string> InChI;
      std::vector<std::string> InChIKey;
      std::vector<double> xLogP;
      std::vector<std::string> database_id;
      std::vector<int> db_ms2_size;
      std::vector<std::string> db_ms2_mz;
      std::vector<std::string> db_ms2_intensity;
      std::vector<std::string> db_ms2_formula;
      std::vector<int> exp_ms2_size;
      std::vector<std::string> exp_ms2_mz;
      std::vector<std::string> exp_ms2_intensity;

      int size() const
      {
        return analysis.size();
      }

      std::vector<std::uint8_t> serialize_object() const;

      static NTA_SUSPECTS deserialize_object(const std::vector<std::uint8_t> &bytes);

      NTA_SUSPECT_ROW get_suspect(const int &i) const
      {
        NTA_SUSPECT_ROW suspect_i;
        suspect_i.analysis = analysis[i];
        suspect_i.feature = feature[i];
        suspect_i.candidate_rank = candidate_rank[i];
        suspect_i.name = name[i];
        suspect_i.polarity = polarity[i];
        suspect_i.db_mass = db_mass[i];
        suspect_i.exp_mass = exp_mass[i];
        suspect_i.error_mass = error_mass[i];
        suspect_i.db_rt = db_rt[i];
        suspect_i.exp_rt = exp_rt[i];
        suspect_i.error_rt = error_rt[i];
        suspect_i.intensity = intensity[i];
        suspect_i.area = area[i];
        suspect_i.id_level = id_level[i];
        suspect_i.score = score[i];
        suspect_i.shared_fragments = shared_fragments[i];
        suspect_i.cosine_similarity = cosine_similarity[i];
        suspect_i.formula = formula[i];
        suspect_i.SMILES = SMILES[i];
        suspect_i.InChI = InChI[i];
        suspect_i.InChIKey = InChIKey[i];
        suspect_i.xLogP = xLogP[i];
        suspect_i.database_id = database_id[i];
        suspect_i.db_ms2_size = db_ms2_size[i];
        suspect_i.db_ms2_mz = db_ms2_mz[i];
        suspect_i.db_ms2_intensity = db_ms2_intensity[i];
        suspect_i.db_ms2_formula = db_ms2_formula[i];
        suspect_i.exp_ms2_size = exp_ms2_size[i];
        suspect_i.exp_ms2_mz = exp_ms2_mz[i];
        suspect_i.exp_ms2_intensity = exp_ms2_intensity[i];
        return suspect_i;
      }

      void append(const NTA_SUSPECT_ROW &s)
      {
        analysis.push_back(s.analysis);
        feature.push_back(s.feature);
        candidate_rank.push_back(s.candidate_rank);
        name.push_back(s.name);
        polarity.push_back(s.polarity);
        db_mass.push_back(s.db_mass);
        exp_mass.push_back(s.exp_mass);
        error_mass.push_back(s.error_mass);
        db_rt.push_back(s.db_rt);
        exp_rt.push_back(s.exp_rt);
        error_rt.push_back(s.error_rt);
        intensity.push_back(s.intensity);
        area.push_back(s.area);
        id_level.push_back(s.id_level);
        score.push_back(s.score);
        shared_fragments.push_back(s.shared_fragments);
        cosine_similarity.push_back(s.cosine_similarity);
        formula.push_back(s.formula);
        SMILES.push_back(s.SMILES);
        InChI.push_back(s.InChI);
        InChIKey.push_back(s.InChIKey);
        xLogP.push_back(s.xLogP);
        database_id.push_back(s.database_id);
        db_ms2_size.push_back(s.db_ms2_size);
        db_ms2_mz.push_back(s.db_ms2_mz);
        db_ms2_intensity.push_back(s.db_ms2_intensity);
        db_ms2_formula.push_back(s.db_ms2_formula);
        exp_ms2_size.push_back(s.exp_ms2_size);
        exp_ms2_mz.push_back(s.exp_ms2_mz);
        exp_ms2_intensity.push_back(s.exp_ms2_intensity);
      }
    };

    struct NTA_SUSPECTS_TABLE
    {
      std::vector<std::string> project_id;
      std::vector<std::string> analysis;
      std::vector<std::string> feature;
      std::vector<int> candidate_rank;
      std::vector<std::string> name;
      std::vector<int> polarity;
      std::vector<double> db_mass;
      std::vector<double> exp_mass;
      std::vector<double> error_mass;
      std::vector<double> db_rt;
      std::vector<double> exp_rt;
      std::vector<double> error_rt;
      std::vector<double> intensity;
      std::vector<double> area;
      std::vector<int> id_level;
      std::vector<double> score;
      std::vector<int> shared_fragments;
      std::vector<double> cosine_similarity;
      std::vector<std::string> formula;
      std::vector<std::string> SMILES;
      std::vector<std::string> InChI;
      std::vector<std::string> InChIKey;
      std::vector<double> xLogP;
      std::vector<std::string> database_id;
      std::vector<int> db_ms2_size;
      std::vector<std::string> db_ms2_mz;
      std::vector<std::string> db_ms2_intensity;
      std::vector<std::string> db_ms2_formula;
      std::vector<int> exp_ms2_size;
      std::vector<std::string> exp_ms2_mz;
      std::vector<std::string> exp_ms2_intensity;
      std::vector<std::string> created_at;

      int size() const { return static_cast<int>(analysis.size()); }

      void append(const NTA_SUSPECT_ROW &row)
      {
        project_id.push_back(row.project_id);
        analysis.push_back(row.analysis);
        feature.push_back(row.feature);
        candidate_rank.push_back(row.candidate_rank);
        name.push_back(row.name);
        polarity.push_back(row.polarity);
        db_mass.push_back(row.db_mass);
        exp_mass.push_back(row.exp_mass);
        error_mass.push_back(row.error_mass);
        db_rt.push_back(row.db_rt);
        exp_rt.push_back(row.exp_rt);
        error_rt.push_back(row.error_rt);
        intensity.push_back(row.intensity);
        area.push_back(row.area);
        id_level.push_back(row.id_level);
        score.push_back(row.score);
        shared_fragments.push_back(row.shared_fragments);
        cosine_similarity.push_back(row.cosine_similarity);
        formula.push_back(row.formula);
        SMILES.push_back(row.SMILES);
        InChI.push_back(row.InChI);
        InChIKey.push_back(row.InChIKey);
        xLogP.push_back(row.xLogP);
        database_id.push_back(row.database_id);
        db_ms2_size.push_back(row.db_ms2_size);
        db_ms2_mz.push_back(row.db_ms2_mz);
        db_ms2_intensity.push_back(row.db_ms2_intensity);
        db_ms2_formula.push_back(row.db_ms2_formula);
        exp_ms2_size.push_back(row.exp_ms2_size);
        exp_ms2_mz.push_back(row.exp_ms2_mz);
        exp_ms2_intensity.push_back(row.exp_ms2_intensity);
        created_at.push_back(row.created_at);
      }
    };

    struct NTA_SUSPECTS_CACHE
    {
      std::vector<NTA_SUSPECTS> buffers;

      std::vector<std::uint8_t> serialize_object() const;

      static NTA_SUSPECTS_CACHE deserialize_object(const std::vector<std::uint8_t> &bytes);
    };

    NTA_SUSPECT_ROW suspect_row_from_table(const NTA_SUSPECTS_TABLE &table, std::size_t row);

    // MARK: NTA_INTERNAL_STANDARD_ROW
    struct NTA_INTERNAL_STANDARD_ROW : public project::api::ROW
    {
      std::string analysis;
      std::string feature;
      std::string feature_group;
      std::string feature_component;
      std::string adduct;
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

    // MARK: NTA_INTERNAL_STANDARDS
    struct NTA_INTERNAL_STANDARDS
    {
      std::vector<std::string> analysis;
      std::vector<std::string> feature;
      std::vector<int> candidate_rank;
      std::vector<std::string> name;
      std::vector<int> polarity;
      std::vector<double> db_mass;
      std::vector<double> exp_mass;
      std::vector<double> error_mass;
      std::vector<double> db_rt;
      std::vector<double> exp_rt;
      std::vector<double> error_rt;
      std::vector<double> intensity;
      std::vector<double> area;
      std::vector<int> id_level;
      std::vector<double> score;
      std::vector<int> shared_fragments;
      std::vector<double> cosine_similarity;
      std::vector<std::string> formula;
      std::vector<std::string> SMILES;
      std::vector<std::string> InChI;
      std::vector<std::string> InChIKey;
      std::vector<double> xLogP;
      std::vector<std::string> database_id;
      std::vector<int> db_ms2_size;
      std::vector<std::string> db_ms2_mz;
      std::vector<std::string> db_ms2_intensity;
      std::vector<std::string> db_ms2_formula;
      std::vector<int> exp_ms2_size;
      std::vector<std::string> exp_ms2_mz;
      std::vector<std::string> exp_ms2_intensity;

      int size() const
      {
        return analysis.size();
      }

      std::vector<std::uint8_t> serialize_object() const;

      static NTA_INTERNAL_STANDARDS deserialize_object(const std::vector<std::uint8_t> &bytes);

      NTA_INTERNAL_STANDARD_ROW get_internal_standard(const int &i) const
      {
        NTA_INTERNAL_STANDARD_ROW standard_i;
        standard_i.analysis = analysis[i];
        standard_i.feature = feature[i];
        standard_i.candidate_rank = candidate_rank[i];
        standard_i.name = name[i];
        standard_i.polarity = polarity[i];
        standard_i.db_mass = db_mass[i];
        standard_i.exp_mass = exp_mass[i];
        standard_i.error_mass = error_mass[i];
        standard_i.db_rt = db_rt[i];
        standard_i.exp_rt = exp_rt[i];
        standard_i.error_rt = error_rt[i];
        standard_i.intensity = intensity[i];
        standard_i.area = area[i];
        standard_i.id_level = id_level[i];
        standard_i.score = score[i];
        standard_i.shared_fragments = shared_fragments[i];
        standard_i.cosine_similarity = cosine_similarity[i];
        standard_i.formula = formula[i];
        standard_i.SMILES = SMILES[i];
        standard_i.InChI = InChI[i];
        standard_i.InChIKey = InChIKey[i];
        standard_i.xLogP = xLogP[i];
        standard_i.database_id = database_id[i];
        standard_i.db_ms2_size = db_ms2_size[i];
        standard_i.db_ms2_mz = db_ms2_mz[i];
        standard_i.db_ms2_intensity = db_ms2_intensity[i];
        standard_i.db_ms2_formula = db_ms2_formula[i];
        standard_i.exp_ms2_size = exp_ms2_size[i];
        standard_i.exp_ms2_mz = exp_ms2_mz[i];
        standard_i.exp_ms2_intensity = exp_ms2_intensity[i];
        return standard_i;
      }

      void append(const NTA_INTERNAL_STANDARD_ROW &is)
      {
        analysis.push_back(is.analysis);
        feature.push_back(is.feature);
        candidate_rank.push_back(is.candidate_rank);
        name.push_back(is.name);
        polarity.push_back(is.polarity);
        db_mass.push_back(is.db_mass);
        exp_mass.push_back(is.exp_mass);
        error_mass.push_back(is.error_mass);
        db_rt.push_back(is.db_rt);
        exp_rt.push_back(is.exp_rt);
        error_rt.push_back(is.error_rt);
        intensity.push_back(is.intensity);
        area.push_back(is.area);
        id_level.push_back(is.id_level);
        score.push_back(is.score);
        shared_fragments.push_back(is.shared_fragments);
        cosine_similarity.push_back(is.cosine_similarity);
        formula.push_back(is.formula);
        SMILES.push_back(is.SMILES);
        InChI.push_back(is.InChI);
        InChIKey.push_back(is.InChIKey);
        xLogP.push_back(is.xLogP);
        database_id.push_back(is.database_id);
        db_ms2_size.push_back(is.db_ms2_size);
        db_ms2_mz.push_back(is.db_ms2_mz);
        db_ms2_intensity.push_back(is.db_ms2_intensity);
        db_ms2_formula.push_back(is.db_ms2_formula);
        exp_ms2_size.push_back(is.exp_ms2_size);
        exp_ms2_mz.push_back(is.exp_ms2_mz);
        exp_ms2_intensity.push_back(is.exp_ms2_intensity);
      }
    };

    struct NTA_INTERNAL_STANDARDS_TABLE
    {
      std::vector<std::string> project_id;
      std::vector<std::string> analysis;
      std::vector<std::string> feature;
      std::vector<int> candidate_rank;
      std::vector<std::string> name;
      std::vector<int> polarity;
      std::vector<double> db_mass;
      std::vector<double> exp_mass;
      std::vector<double> error_mass;
      std::vector<double> db_rt;
      std::vector<double> exp_rt;
      std::vector<double> error_rt;
      std::vector<double> intensity;
      std::vector<double> area;
      std::vector<int> id_level;
      std::vector<double> score;
      std::vector<int> shared_fragments;
      std::vector<double> cosine_similarity;
      std::vector<std::string> formula;
      std::vector<std::string> SMILES;
      std::vector<std::string> InChI;
      std::vector<std::string> InChIKey;
      std::vector<double> xLogP;
      std::vector<std::string> database_id;
      std::vector<int> db_ms2_size;
      std::vector<std::string> db_ms2_mz;
      std::vector<std::string> db_ms2_intensity;
      std::vector<std::string> db_ms2_formula;
      std::vector<int> exp_ms2_size;
      std::vector<std::string> exp_ms2_mz;
      std::vector<std::string> exp_ms2_intensity;
      std::vector<std::string> created_at;

      int size() const { return static_cast<int>(analysis.size()); }

      void append(const NTA_INTERNAL_STANDARD_ROW &row)
      {
        project_id.push_back(row.project_id);
        analysis.push_back(row.analysis);
        feature.push_back(row.feature);
        candidate_rank.push_back(row.candidate_rank);
        name.push_back(row.name);
        polarity.push_back(row.polarity);
        db_mass.push_back(row.db_mass);
        exp_mass.push_back(row.exp_mass);
        error_mass.push_back(row.error_mass);
        db_rt.push_back(row.db_rt);
        exp_rt.push_back(row.exp_rt);
        error_rt.push_back(row.error_rt);
        intensity.push_back(row.intensity);
        area.push_back(row.area);
        id_level.push_back(row.id_level);
        score.push_back(row.score);
        shared_fragments.push_back(row.shared_fragments);
        cosine_similarity.push_back(row.cosine_similarity);
        formula.push_back(row.formula);
        SMILES.push_back(row.SMILES);
        InChI.push_back(row.InChI);
        InChIKey.push_back(row.InChIKey);
        xLogP.push_back(row.xLogP);
        database_id.push_back(row.database_id);
        db_ms2_size.push_back(row.db_ms2_size);
        db_ms2_mz.push_back(row.db_ms2_mz);
        db_ms2_intensity.push_back(row.db_ms2_intensity);
        db_ms2_formula.push_back(row.db_ms2_formula);
        exp_ms2_size.push_back(row.exp_ms2_size);
        exp_ms2_mz.push_back(row.exp_ms2_mz);
        exp_ms2_intensity.push_back(row.exp_ms2_intensity);
        created_at.push_back(row.created_at);
      }
    };

    struct NTA_INTERNAL_STANDARDS_CACHE
    {
      std::vector<NTA_INTERNAL_STANDARDS> buffers;

      std::vector<std::uint8_t> serialize_object() const;

      static NTA_INTERNAL_STANDARDS_CACHE deserialize_object(const std::vector<std::uint8_t> &bytes);
    };

    NTA_INTERNAL_STANDARD_ROW internal_standard_row_from_table(const NTA_INTERNAL_STANDARDS_TABLE &table, std::size_t row);

    // MARK: NTA_TRANSFORMATION_PRODUCT_ROW
    struct NTA_TRANSFORMATION_PRODUCT_ROW : public project::api::ROW
    {
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

    struct NTA_TRANSFORMATION_PRODUCTS
    {
      std::vector<std::string> name;
      std::vector<std::string> formula;
      std::vector<double> mass;
      std::vector<std::string> SMILES;
      std::vector<std::string> InChI;
      std::vector<std::string> InChIKey;
      std::vector<double> xLogP;
      std::vector<std::string> transformation;
      std::vector<std::string> precursor_name;
      std::vector<std::string> precursor_formula;
      std::vector<double> precursor_mass;
      std::vector<std::string> precursor_SMILES;
      std::vector<std::string> precursor_InChI;
      std::vector<std::string> precursor_InChIKey;
      std::vector<double> precursor_xLogP;
      std::vector<std::string> main_precursor_name;
      std::vector<std::string> main_precursor_formula;
      std::vector<double> main_precursor_mass;
      std::vector<std::string> main_precursor_SMILES;
      std::vector<std::string> main_precursor_InChI;
      std::vector<std::string> main_precursor_InChIKey;
      std::vector<double> main_precursor_xLogP;
      std::vector<std::string> feature_group;
      std::vector<std::string> precursor_feature_group;
      std::vector<std::string> main_precursor_feature_group;
      std::vector<double> cosine_similarity;
      std::vector<double> main_precursor_cosine_similarity;
      std::vector<double> rt_plausibility;
      std::vector<double> main_precursor_rt_plausibility;

      int size() const
      {
        return static_cast<int>(name.size());
      }

      std::vector<std::uint8_t> serialize_object() const;

      static NTA_TRANSFORMATION_PRODUCTS deserialize_object(const std::vector<std::uint8_t> &bytes);

      NTA_TRANSFORMATION_PRODUCT_ROW get_transformation_product(const int &i) const
      {
        NTA_TRANSFORMATION_PRODUCT_ROW row;
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
        row.feature_group = feature_group[i];
        row.precursor_feature_group = precursor_feature_group[i];
        row.main_precursor_feature_group = main_precursor_feature_group[i];
        row.cosine_similarity = cosine_similarity[i];
        row.main_precursor_cosine_similarity = main_precursor_cosine_similarity[i];
        row.rt_plausibility = rt_plausibility[i];
        row.main_precursor_rt_plausibility = main_precursor_rt_plausibility[i];
        return row;
      }

      void append(const NTA_TRANSFORMATION_PRODUCT_ROW &row)
      {
        name.push_back(row.name);
        formula.push_back(row.formula);
        mass.push_back(row.mass);
        SMILES.push_back(row.SMILES);
        InChI.push_back(row.InChI);
        InChIKey.push_back(row.InChIKey);
        xLogP.push_back(row.xLogP);
        transformation.push_back(row.transformation);
        precursor_name.push_back(row.precursor_name);
        precursor_formula.push_back(row.precursor_formula);
        precursor_mass.push_back(row.precursor_mass);
        precursor_SMILES.push_back(row.precursor_SMILES);
        precursor_InChI.push_back(row.precursor_InChI);
        precursor_InChIKey.push_back(row.precursor_InChIKey);
        precursor_xLogP.push_back(row.precursor_xLogP);
        main_precursor_name.push_back(row.main_precursor_name);
        main_precursor_formula.push_back(row.main_precursor_formula);
        main_precursor_mass.push_back(row.main_precursor_mass);
        main_precursor_SMILES.push_back(row.main_precursor_SMILES);
        main_precursor_InChI.push_back(row.main_precursor_InChI);
        main_precursor_InChIKey.push_back(row.main_precursor_InChIKey);
        main_precursor_xLogP.push_back(row.main_precursor_xLogP);
        feature_group.push_back(row.feature_group);
        precursor_feature_group.push_back(row.precursor_feature_group);
        main_precursor_feature_group.push_back(row.main_precursor_feature_group);
        cosine_similarity.push_back(row.cosine_similarity);
        main_precursor_cosine_similarity.push_back(row.main_precursor_cosine_similarity);
        rt_plausibility.push_back(row.rt_plausibility);
        main_precursor_rt_plausibility.push_back(row.main_precursor_rt_plausibility);
      }
    };

    struct NTA_TRANSFORMATION_PRODUCTS_TABLE
    {
      std::vector<std::string> project_id;
      std::vector<std::string> name;
      std::vector<std::string> formula;
      std::vector<double> mass;
      std::vector<std::string> SMILES;
      std::vector<std::string> InChI;
      std::vector<std::string> InChIKey;
      std::vector<double> xLogP;
      std::vector<std::string> transformation;
      std::vector<std::string> precursor_name;
      std::vector<std::string> precursor_formula;
      std::vector<double> precursor_mass;
      std::vector<std::string> precursor_SMILES;
      std::vector<std::string> precursor_InChI;
      std::vector<std::string> precursor_InChIKey;
      std::vector<double> precursor_xLogP;
      std::vector<std::string> main_precursor_name;
      std::vector<std::string> main_precursor_formula;
      std::vector<double> main_precursor_mass;
      std::vector<std::string> main_precursor_SMILES;
      std::vector<std::string> main_precursor_InChI;
      std::vector<std::string> main_precursor_InChIKey;
      std::vector<double> main_precursor_xLogP;
      std::vector<std::string> feature_group;
      std::vector<std::string> precursor_feature_group;
      std::vector<std::string> main_precursor_feature_group;
      std::vector<double> cosine_similarity;
      std::vector<double> main_precursor_cosine_similarity;
      std::vector<double> rt_plausibility;
      std::vector<double> main_precursor_rt_plausibility;
      std::vector<std::string> created_at;

      int size() const
      {
        return static_cast<int>(name.size());
      }

      void append(const NTA_TRANSFORMATION_PRODUCT_ROW &row)
      {
        project_id.push_back(row.project_id);
        name.push_back(row.name);
        formula.push_back(row.formula);
        mass.push_back(row.mass);
        SMILES.push_back(row.SMILES);
        InChI.push_back(row.InChI);
        InChIKey.push_back(row.InChIKey);
        xLogP.push_back(row.xLogP);
        transformation.push_back(row.transformation);
        precursor_name.push_back(row.precursor_name);
        precursor_formula.push_back(row.precursor_formula);
        precursor_mass.push_back(row.precursor_mass);
        precursor_SMILES.push_back(row.precursor_SMILES);
        precursor_InChI.push_back(row.precursor_InChI);
        precursor_InChIKey.push_back(row.precursor_InChIKey);
        precursor_xLogP.push_back(row.precursor_xLogP);
        main_precursor_name.push_back(row.main_precursor_name);
        main_precursor_formula.push_back(row.main_precursor_formula);
        main_precursor_mass.push_back(row.main_precursor_mass);
        main_precursor_SMILES.push_back(row.main_precursor_SMILES);
        main_precursor_InChI.push_back(row.main_precursor_InChI);
        main_precursor_InChIKey.push_back(row.main_precursor_InChIKey);
        main_precursor_xLogP.push_back(row.main_precursor_xLogP);
        feature_group.push_back(row.feature_group);
        precursor_feature_group.push_back(row.precursor_feature_group);
        main_precursor_feature_group.push_back(row.main_precursor_feature_group);
        cosine_similarity.push_back(row.cosine_similarity);
        main_precursor_cosine_similarity.push_back(row.main_precursor_cosine_similarity);
        rt_plausibility.push_back(row.rt_plausibility);
        main_precursor_rt_plausibility.push_back(row.main_precursor_rt_plausibility);
        created_at.push_back(row.created_at);
      }
    };

    NTA_TRANSFORMATION_PRODUCT_ROW transformation_product_row_from_table(
        const NTA_TRANSFORMATION_PRODUCTS_TABLE &table,
        std::size_t row);

    struct NTA_QUERY_REQUEST
    {
      std::vector<std::string> analyses;
      std::vector<std::string> features;
      std::unordered_map<std::string, std::string> feature_labels;
      std::vector<std::string> feature_groups;
      std::unordered_map<std::string, std::string> feature_group_labels;
      std::vector<std::string> feature_components;
      std::unordered_map<std::string, std::string> feature_component_labels;
      mass_spec::spectra::MS_TARGETS_REQUEST targets;
      bool include_filtered = false;
    };

    // MARK: PROJECT_NON_TARGET_ANALYSIS
    class PROJECT_NON_TARGET_ANALYSIS
    {
    private:
      std::shared_ptr<project::api::CONTEXT> ctx_;
      mass_spec::api::MS_ANALYSES_TABLE analyses_table_;
      mass_spec::api::MS_SPECTRA_HEADERS_TABLE spectra_headers_table_;
      mutable std::vector<std::optional<mass_spec::reader::MS_SPECTRA_HEADERS>> spectra_headers_cache_;
      NTA_FEATURES_TABLE features_table_;
      NTA_SUSPECTS_TABLE suspects_table_;
      NTA_INTERNAL_STANDARDS_TABLE internal_standards_table_;
      NTA_TRANSFORMATION_PRODUCTS_TABLE transformation_products_table_;
      mutable std::vector<NTA_FEATURES> feature_buffers_;
      mutable std::vector<NTA_SUSPECTS> suspect_buffers_;
      mutable std::vector<NTA_INTERNAL_STANDARDS> internal_standard_buffers_;
      mutable NTA_TRANSFORMATION_PRODUCTS transformation_products_buffer_;
      mutable bool feature_buffers_ready_ = false;
      mutable bool suspect_buffers_ready_ = false;
      mutable bool internal_standard_buffers_ready_ = false;
      mutable bool transformation_products_ready_ = false;

      static constexpr const char *features_table_name() { return "NTA_FEATURES"; }
      static constexpr const char *internal_standards_table_name() { return "NTA_INTERNAL_STANDARDS"; }
      static constexpr const char *suspects_table_name() { return "NTA_SUSPECTS"; }
      static constexpr const char *transformation_products_table_name() { return "NTA_TRANSFORMATION_PRODUCTS"; }

      NTA_FEATURES_TABLE collect_features_table(const NTA_QUERY_REQUEST &query) const;
      NTA_SUSPECTS_TABLE collect_suspects_table(const NTA_QUERY_REQUEST &query) const;
      NTA_INTERNAL_STANDARDS_TABLE collect_internal_standards_table(const NTA_QUERY_REQUEST &query) const;
      NTA_TRANSFORMATION_PRODUCTS_TABLE collect_transformation_products_table() const;
      std::vector<NTA_FEATURE_ROW> get_features(duckdb_connection con, const NTA_QUERY_REQUEST &query) const;
      std::vector<NTA_SUSPECT_ROW> get_suspects(duckdb_connection con, const NTA_QUERY_REQUEST &query) const;
      std::vector<NTA_INTERNAL_STANDARD_ROW> get_internal_standards(duckdb_connection con, const NTA_QUERY_REQUEST &query) const;

      void materialize_feature_buffers() const;
      void materialize_suspect_buffers() const;
      void materialize_internal_standard_buffers() const;
      void materialize_transformation_products_buffer() const;

      template <typename T>
      static std::string cache_scalar_key(const T &value)
      {
        std::ostringstream stream;
        stream << std::setprecision(17) << value;
        return stream.str();
      }
      static std::string cache_bool_key(bool value)
      {
        return value ? "1" : "0";
      }

      template <typename T>
      static std::string cache_vector_key(const std::vector<T> &values)
      {
        std::vector<std::string> parts;
        parts.reserve(values.size());
        for (const auto &value : values)
        {
          parts.push_back(cache_scalar_key(value));
        }
        return cache_join_key(parts);
      }

      static std::string cache_vector_key(const std::vector<std::string> &values)
      {
        return cache_join_key(values);
      }

      static std::string cache_join_key(const std::vector<std::string> &parts)
      {
        std::ostringstream stream;
        for (const auto &part : parts)
        {
          stream << part.size() << ':' << part << ';';
        }
        return stream.str();
      }

      std::string build_processing_cache_key(const std::string &step,
                                             const std::string &args_key,
                                             const std::vector<std::string> &dependency_keys = {}) const;
      std::string analyses_state_cache_key() const;

      NTA_FEATURES_CACHE feature_cache_snapshot() const;
      NTA_SUSPECTS_CACHE suspect_cache_snapshot() const;
      NTA_INTERNAL_STANDARDS_CACHE internal_standard_cache_snapshot() const;

      std::string feature_state_cache_key() const;
      std::string suspect_state_cache_key() const;
      std::string internal_standard_state_cache_key() const;

      bool restore_feature_cache(const std::string &hash);
      bool restore_suspect_cache(const std::string &hash);
      bool restore_internal_standard_cache(const std::string &hash);
      bool restore_transformation_products_cache(const std::string &hash);

      bool run_cached_features_algorithm(const std::string &step,
                                         const std::string &args_key,
                                         const std::vector<std::string> &dependency_keys,
                                         const std::string &description,
                                         const std::function<void()> &algorithm);
      bool run_cached_suspects_algorithm(const std::string &step,
                                         const std::string &args_key,
                                         const std::vector<std::string> &dependency_keys,
                                         const std::string &description,
                                         const std::function<void()> &algorithm);
      bool run_cached_internal_standards_algorithm(const std::string &step,
                                                   const std::string &args_key,
                                                   const std::vector<std::string> &dependency_keys,
                                                   const std::string &description,
                                                   const std::function<void()> &algorithm);

      bool run_cached_transformation_products_algorithm(
          const std::string &step,
          const std::string &args_key,
          const std::vector<std::string> &dependency_keys,
          const std::string &description,
          const std::function<NTA_TRANSFORMATION_PRODUCTS()> &algorithm);

      void store_feature_cache(const std::string &hash, const std::string &description);
      void store_suspect_cache(const std::string &hash, const std::string &description);
      void store_internal_standard_cache(const std::string &hash, const std::string &description);

      void store_transformation_products_cache(const std::string &hash,
                                               const std::string &description,
                                               const NTA_TRANSFORMATION_PRODUCTS &products);

      void load_processing_metadata();
      void load_processing_headers();
      void load_processing_features(bool include_filtered);
      void load_processing_suspects();
      void load_processing_internal_standards();
      void load_processing_transformation_products();

      void save_processing_features();
      void save_processing_suspects();
      void save_processing_internal_standards();

      void save_processing_transformation_products(const NTA_TRANSFORMATION_PRODUCTS &products);

    public:
      explicit PROJECT_NON_TARGET_ANALYSIS(std::shared_ptr<project::api::CONTEXT> ctx);
      static void create_schema(const std::shared_ptr<project::api::CONTEXT> &ctx);
      static void validate_schema(const std::shared_ptr<project::api::CONTEXT> &ctx);

      const mass_spec::api::MS_ANALYSES_TABLE &analyses_table() const noexcept { return analyses_table_; }
      const mass_spec::api::MS_SPECTRA_HEADERS_TABLE &spectra_headers_table() const noexcept { return spectra_headers_table_; }
      const NTA_FEATURES_TABLE &features_table() const noexcept { return features_table_; }
      const NTA_SUSPECTS_TABLE &suspects_table() const noexcept { return suspects_table_; }
      const NTA_INTERNAL_STANDARDS_TABLE &internal_standards_table() const noexcept { return internal_standards_table_; }
      const NTA_TRANSFORMATION_PRODUCTS_TABLE &transformation_products_table() const noexcept { return transformation_products_table_; }
      const std::vector<std::string> &analysis_names() const noexcept { return analyses_table_.analysis; }
      const std::vector<std::string> &replicate_names() const noexcept { return analyses_table_.replicate; }
      const std::vector<std::string> &blank_names() const noexcept { return analyses_table_.blank; }
      const std::vector<std::string> &file_paths() const noexcept { return analyses_table_.file_path; }
      std::vector<NTA_FEATURES> &feature_buffers();
      const std::vector<NTA_FEATURES> &feature_buffers() const;
      std::vector<NTA_SUSPECTS> &suspect_buffers();
      const std::vector<NTA_SUSPECTS> &suspect_buffers() const;
      std::vector<NTA_INTERNAL_STANDARDS> &internal_standard_buffers();
      const std::vector<NTA_INTERNAL_STANDARDS> &internal_standard_buffers() const;
      NTA_TRANSFORMATION_PRODUCTS &transformation_products();
      const NTA_TRANSFORMATION_PRODUCTS &transformation_products() const;
      mass_spec::reader::MS_SPECTRA_HEADERS spectra_headers_at(std::size_t index) const;

      int size() const
      {
        return static_cast<int>(analysis_names().size());
      }

      std::vector<NTA_FEATURE_COUNT_ROW> get_features_count(
          const std::vector<std::string> &analyses = {},
          bool include_filtered = false) const;

      std::vector<NTA_FEATURE_ROW> get_features(
        const std::vector<std::string> &analyses = {},
        bool include_filtered = false) const;
      std::vector<NTA_FEATURE_ROW> get_features(const NTA_QUERY_REQUEST &query) const;
      std::vector<NTA_SUSPECT_ROW> get_suspects(const NTA_QUERY_REQUEST &query) const;
      std::vector<NTA_INTERNAL_STANDARD_ROW> get_internal_standards(const NTA_QUERY_REQUEST &query) const;
      std::vector<NTA_TRANSFORMATION_PRODUCT_ROW> get_transformation_products() const;

      bool find_features(
        const std::vector<float> &rtWindowsMin,
        const std::vector<float> &rtWindowsMax,
        const float &ppmThreshold,
        const float &noiseThreshold,
        const float &minSNR,
        const int &minTraces,
        const float &baselineWindow,
        const float &maxWidth,
        const float &baseQuantile,
        const std::string &debugAnalysis = "",
        const float &debugMZ = 0.0f,
        const int &debugSpecIdx = -1);

      bool create_components(
        const std::vector<float> &rtWindow,
        float minCorrelation = 0.8f,
        float debugRT = 0.0f,
        const std::string &debugAnalysis = "");

      bool annotate_components(
        int maxIsotopes = 5,
        int maxCharge = 1,
        int maxGaps = 1,
        float ppm = 10.0,
        const std::vector<std::string> &isotopeElements = {"C:1-60", "N:0-10", "O:0-20", "S:0-4", "Cl:0-6", "Br:0-4"},
        const std::string &debugComponent = "",
        const std::string &debugAnalysis = "");

      bool group_features(
        const std::string &method,
        float rtDeviation,
        float ppm,
        int minSamples,
        float binSize = 5.0f,
        bool debug = false,
        float debugRT = 0.0f);

      bool load_features_ms1(
        bool filtered,
        const std::vector<float> &rtWindow,
        const std::vector<float> &mzWindow,
        float minTracesIntensity,
        float mzClust,
        float presence);

      bool load_features_ms2(
        bool filtered,
        float minTracesIntensity,
        float isolationWindow,
        float mzClust,
        float presence);

      bool fill_features(
        bool withinReplicate,
        bool filtered,
        float rtExpand,
        float mzExpand,
        float maxPeakWidth,
        float minTracesIntensity,
        int minNumberTraces,
        float minIntensity,
        float rtApexDeviation,
        float minSignalToNoiseRatio,
        float minGaussianFit,
        std::string debugFG = "");

      bool subtract_blank(
        float blankThreshold,
        float rtExpand,
        float mzExpand,
        float minTracesIntensity = 0.0f);

      std::vector<correction_algorithms::TIC_MATRIX_SUPPRESSION_ROW> get_matrix_suppression(
        const std::vector<std::string> &analyses = {},
        float rtWindow = 10.0f,
        const std::string &refBlankReplicate = "");

      bool correct_matrix_suppression(
        float mpRtWindow = 10.0f,
        const std::string &refBlankReplicate = "");

      bool filter_features(
        double minSN,
        double minIntensity,
        double minArea,
        double minWidth,
        double maxWidth,
        double maxPPM,
        double minFwhmRT,
        double maxFwhmRT,
        double minFwhmMZ,
        double maxFwhmMZ,
        double minGaussianA,
        double minGaussianMu,
        double maxGaussianMu,
        double minGaussianSigma,
        double maxGaussianSigma,
        double minGaussianR2,
        double maxJaggedness,
        double minSharpness,
        double minAsymmetry,
        double maxAsymmetry,
        int maxModality,
        bool hasMaxModality,
        double minPlates,
        bool hasOnlyFilled,
        bool onlyFilledValue,
        bool removeFilled,
        int minSizeEIC,
        bool hasMinSizeEIC,
        int minSizeMS1,
        bool hasMinSizeMS1,
        int minSizeMS2,
        bool hasMinSizeMS2,
        double minRelPresenceReplicate,
        bool removeIsotopes,
        bool removeAdducts,
        bool removeLosses);

      bool suspect_screening(
        const std::vector<std::string> &analyses,
        const std::vector<suspect_screening::SuspectQuery> &suspects,
        double ppm,
        double sec,
        double ppmMS2,
        double mzrMS2,
        double minCosineSimilarity,
        int minSharedFragments,
        bool filtered);

      bool find_internal_standards(
        const std::vector<std::string> &analyses,
        const std::vector<suspect_screening::SuspectQuery> &suspects,
        double ppm,
        double sec,
        double ppmMS2,
        double mzrMS2,
        double minCosineSimilarity,
        int minSharedFragments,
        bool filtered);

      bool filter_suspects(
        const std::vector<std::string> &names,
        double minScore,
        double maxErrorRT,
        double maxErrorMass,
        const std::vector<int> &idLevels,
        int minSharedFragments,
        double minCosineSimilarity);

      bool filter_internal_standards(
        const std::vector<std::string> &names,
        double minScore,
        double maxErrorRT,
        double maxErrorMass,
        const std::vector<int> &idLevels,
        int minSharedFragments,
        double minCosineSimilarity);

      bool filter_features_ms2(
        int top,
        float minIntensity,
        float relMinIntensity,
        bool blankClean,
        float mzClust,
        float blankPresenceThreshold,
        float globalPresenceThreshold);

      bool metfrag_screening(
        const std::vector<std::string> &analyses,
        const metfrag_runner::MetFragParams &params);

      bool assign_transformation_products(
        const std::vector<NTA_TRANSFORMATION_PRODUCT_ROW> &transformation_products,
        const std::string &chromatographic_phase = "reverse_phase",
        double mzrMS2 = 0.008);
    };

  } // namespace api

  using PROJECT_NON_TARGET_ANALYSIS = api::PROJECT_NON_TARGET_ANALYSIS;
}; // namespace nta

// Include internal NTS module headers now that `nta::api` types are defined
// (sub-modules already included above)

// Macro to write verbose debug output ONLY to log file (not console)
#define DEBUG_LOG(x)                       \
  do                                       \
  {                                        \
    if (::nta::utils::debug_log.is_open()) \
    {                                      \
      ::nta::utils::debug_log << x;        \
      ::nta::utils::debug_log.flush();     \
    }                                      \
  } while (0)

// Macro to write important debug output to both console and log file
#define DEBUG_OUT(x)                       \
  do                                       \
  {                                        \
    if (::nta::utils::debug_log.is_open()) \
    {                                      \
      ::nta::utils::debug_log << x;        \
      ::nta::utils::debug_log.flush();     \
    }                                      \
    std::cout << x;                        \
  } while (0)

#endif
