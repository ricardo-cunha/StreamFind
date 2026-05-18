#include "nts.h"
#include "nts_annotation.h"
#include "nts_componentization.h"
#include "nts_alignment.h"
#include <iomanip>
#include <algorithm>
#include <sstream>
#include <filesystem>
#include <cmath>

#include "nts.h"

namespace nts
{

  namespace api
  {



  } // namespace api

  // MARK: ns utils
  namespace utils
  {

    // Debug log file stream (global for debugging)
    std::ofstream debug_log;

    // Helper function to initialize debug log with dynamic filename
    void init_debug_log(const std::string &filename, const std::string &header)
    {
      if (!debug_log.is_open())
      {
        debug_log.open(filename, std::ios::out | std::ios::trunc);
        if (debug_log.is_open() && !header.empty())
        {
          debug_log << header << std::endl;
        }
      }
    };

    // Helper function to close debug log
    void close_debug_log()
    {
      if (debug_log.is_open())
      {
        debug_log.close();
      }
    };

    // MARK: mean, standard_deviation
    float mean(const std::vector<float> &v)
    {
      return std::accumulate(v.begin(), v.end(), 0.0) / v.size();
    }

    float standard_deviation(const std::vector<float> &v, float mean_val)
    {
      float sum = 0.0;
      for (float num : v)
      {
        sum += pow(num - mean_val, 2);
      }
      return sqrt(sum / v.size());
    }

    // MARK: quantile
    float quantile(std::vector<float> data, float quantile_fraction)
    {
      if (data.empty())
        return 0.0f;
      if (quantile_fraction <= 0.0f)
        return *std::min_element(data.begin(), data.end());
      if (quantile_fraction >= 1.0f)
        return *std::max_element(data.begin(), data.end());

      size_t idx = static_cast<size_t>((data.size() - 1) * quantile_fraction);
      std::nth_element(data.begin(), data.begin() + idx, data.end());
      return data[idx];
    }

    // MARK: encode_floats_base64
    std::string encode_floats_base64(const std::vector<float> &input, int precision)
    {
      if (input.empty())
      {
        return "";
      }

      std::string encoded = mass_spec::reader::utils::encode_little_endian_from_float(input, precision);
      return mass_spec::reader::utils::encode_base64(encoded);
    }

    // MARK: gaussian_function
    float gaussian_function(const float &A,
                            const float &mu,
                            const float &sigma,
                            const float &x)
    {
      return A * exp(-pow(x - mu, 2) / (2 * pow(sigma, 2)));
    }

    // MARK: gaussian_function_with_baseline
    float gaussian_function_with_baseline(const float &A,
                                          const float &mu,
                                          const float &sigma,
                                          const float &baseline,
                                          const float &x)
    {
      return baseline + A * exp(-pow(x - mu, 2) / (2 * pow(sigma, 2)));
    }

    // MARK: get_sort_indices_float
    std::vector<size_t> get_sort_indices_float(const std::vector<float> &data)
    {
      std::vector<size_t> indices(data.size());
      std::iota(indices.begin(), indices.end(), 0);
      std::sort(indices.begin(), indices.end(), [&data](size_t a, size_t b)
                { return data[a] < data[b]; });
      return indices;
    }

    // MARK: reorder_float_data
    void reorder_float_data(std::vector<float> &data, const std::vector<size_t> &indices)
    {
      std::vector<float> reordered;
      reordered.reserve(data.size());
      for (size_t idx : indices)
      {
        reordered.push_back(data[idx]);
      }
      data = std::move(reordered);
    }

    // MARK: reorder_int_data
    void reorder_int_data(std::vector<int> &data, const std::vector<size_t> &indices)
    {
      std::vector<int> reordered;
      reordered.reserve(data.size());
      for (size_t idx : indices)
      {
        reordered.push_back(data[idx]);
      }
      data = std::move(reordered);
    }

    // MARK: reorder_multiple_vectors
    void reorder_multiple_vectors(const std::vector<size_t> &indices,
                                  std::vector<float> &vec1)
    {
      reorder_float_data(vec1, indices);
    }

    void reorder_multiple_vectors(const std::vector<size_t> &indices,
                                  std::vector<float> &vec1,
                                  std::vector<float> &vec2)
    {
      reorder_float_data(vec1, indices);
      reorder_float_data(vec2, indices);
    }

    void reorder_multiple_vectors(const std::vector<size_t> &indices,
                                  std::vector<float> &vec1,
                                  std::vector<float> &vec2,
                                  std::vector<float> &vec3)
    {
      reorder_float_data(vec1, indices);
      reorder_float_data(vec2, indices);
      reorder_float_data(vec3, indices);
    }

    void reorder_multiple_vectors(const std::vector<size_t> &indices,
                                  std::vector<float> &vec1,
                                  std::vector<float> &vec2,
                                  std::vector<float> &vec3,
                                  std::vector<float> &vec4)
    {
      reorder_float_data(vec1, indices);
      reorder_float_data(vec2, indices);
      reorder_float_data(vec3, indices);
      reorder_float_data(vec4, indices);
    }

    void reorder_multiple_vectors(const std::vector<size_t> &indices,
                                  std::vector<float> &vec1,
                                  std::vector<float> &vec2,
                                  std::vector<float> &vec3,
                                  std::vector<float> &vec4,
                                  std::vector<int> &int_vec)
    {
      reorder_float_data(vec1, indices);
      reorder_float_data(vec2, indices);
      reorder_float_data(vec3, indices);
      reorder_float_data(vec4, indices);
      reorder_int_data(int_vec, indices);
    }

    // MARK: filter_above_threshold
    std::vector<size_t> filter_above_threshold(
        const std::vector<float> &data,
        const std::vector<float> &thresholds)
    {
      std::vector<size_t> indices;
      indices.reserve(data.size() / 2); // Conservative estimate

      const size_t n = std::min(data.size(), thresholds.size());
      for (size_t i = 0; i < n; ++i)
      {
        if (data[i] > thresholds[i])
        {
          indices.push_back(i);
        }
      }
      return indices;
    }

    // MARK: cluster_by_threshold_float
    std::vector<int> cluster_by_threshold_float(
        const std::vector<float> &sorted_data,
        const std::vector<float> &thresholds)
    {
      const size_t n = sorted_data.size();
      std::vector<int> clusters(n);

      if (n == 0)
        return clusters;

      clusters[0] = 0;
      int current_cluster = 0;

      for (size_t i = 1; i < n; ++i)
      {
        float diff = sorted_data[i] - sorted_data[i - 1];
        float threshold = (i < thresholds.size()) ? thresholds[i] : thresholds.back();

        if (diff > threshold)
        {
          ++current_cluster;
        }
        clusters[i] = current_cluster;
      }

      return clusters;
    }

    // MARK: calculate_baseline
    std::vector<float> calculate_baseline(const std::vector<float> &intensity, int windowSize)
    {
      const size_t n = intensity.size();
      std::vector<float> baseline(n);

      for (size_t i = 0; i < n; ++i)
      {
        size_t start_idx = (i >= static_cast<size_t>(windowSize)) ? i - windowSize : 0;
        size_t end_idx = std::min(n - 1, i + windowSize);

        float min_intensity = intensity[start_idx];
        for (size_t j = start_idx; j <= end_idx; ++j)
        {
          min_intensity = std::min(min_intensity, intensity[j]);
        }
        baseline[i] = min_intensity;
      }

      // Smooth baseline using 3-point moving average
      if (n >= 3)
      {
        std::vector<float> smoothed_baseline = baseline;
        for (size_t i = 1; i < n - 1; ++i)
        {
          smoothed_baseline[i] = (baseline[i - 1] + baseline[i] + baseline[i + 1]) / 3.0f;
        }
        baseline = std::move(smoothed_baseline);
      }

      return baseline;
    }

    // MARK: smooth_intensity_savitzky_golay
    std::vector<float> smooth_intensity_savitzky_golay(
        const std::vector<float> &intensity,
        int windowSize,
        int polyOrder)
    {
      const size_t n = intensity.size();
      std::vector<float> smoothed(n, 0.0f);

      if (windowSize < 3 || windowSize % 2 == 0 || polyOrder < 1 || polyOrder >= windowSize)
      {
        // Fallback to simple smoothing if parameters are invalid
        return smooth_intensity(intensity, windowSize);
      }

      int half_window = windowSize / 2;

      // Precompute the Savitzky-Golay convolution coefficients (for uniform spacing)
      // Use least-squares fit to a polynomial of given order
      // Reference: Numerical Recipes, or https://en.wikipedia.org/wiki/Savitzky–Golay_filter
      std::vector<float> coeffs(windowSize, 0.0f);
      {
        // Build the design matrix
        std::vector<std::vector<float>> A(windowSize, std::vector<float>(polyOrder + 1, 0.0f));
        for (int i = -half_window; i <= half_window; ++i)
        {
          for (int j = 0; j <= polyOrder; ++j)
          {
            A[i + half_window][j] = std::pow(static_cast<float>(i), j);
          }
        }
        // Compute (A^T A)^{-1} A^T for the center point (convolution coefficients)
        // Only need the first row of the pseudoinverse for smoothing
        std::vector<float> AtA(polyOrder + 1, 0.0f);
        std::vector<std::vector<float>> ATA(polyOrder + 1, std::vector<float>(polyOrder + 1, 0.0f));
        for (int i = 0; i <= polyOrder; ++i)
        {
          for (int j = 0; j <= polyOrder; ++j)
          {
            float sum = 0.0f;
            for (int k = 0; k < windowSize; ++k)
            {
              sum += A[k][i] * A[k][j];
            }
            ATA[i][j] = sum;
          }
        }
        // Invert ATA (small matrix, use Gaussian elimination)
        std::vector<std::vector<float>> inv_ATA = ATA;
        int m = polyOrder + 1;
        // Augment with identity
        for (int i = 0; i < m; ++i)
        {
          inv_ATA[i].resize(2 * m, 0.0f);
          inv_ATA[i][m + i] = 1.0f;
        }
        // Gaussian elimination
        for (int i = 0; i < m; ++i)
        {
          float diag = inv_ATA[i][i];
          if (std::abs(diag) < 1e-12f)
            continue;
          for (int j = 0; j < 2 * m; ++j)
            inv_ATA[i][j] /= diag;
          for (int k = 0; k < m; ++k)
          {
            if (k == i)
              continue;
            float factor = inv_ATA[k][i];
            for (int j = 0; j < 2 * m; ++j)
            {
              inv_ATA[k][j] -= factor * inv_ATA[i][j];
            }
          }
        }
        // Extract inverse
        std::vector<std::vector<float>> ATA_inv(m, std::vector<float>(m, 0.0f));
        for (int i = 0; i < m; ++i)
          for (int j = 0; j < m; ++j)
            ATA_inv[i][j] = inv_ATA[i][m + j];

        // Compute convolution coefficients for smoothing (center point)
        std::vector<float> B(m, 0.0f);
        for (int i = 0; i < windowSize; ++i)
        {
          B[0] += A[i][0];
        }
        for (int i = 0; i < windowSize; ++i)
        {
          for (int j = 0; j < m; ++j)
          {
            B[j] += A[i][j];
          }
        }
        // The smoothing coefficients are the first row of (ATA_inv * A^T) at the center
        for (int k = 0; k < windowSize; ++k)
        {
          float c = 0.0f;
          for (int j = 0; j < m; ++j)
          {
            c += ATA_inv[0][j] * A[k][j];
          }
          coeffs[k] = c;
        }
      }

      // Apply convolution (handle edges by reflecting)
      for (size_t i = 0; i < n; ++i)
      {
        float sum = 0.0f;
        for (int j = -half_window; j <= half_window; ++j)
        {
          int idx = static_cast<int>(i) + j;
          // Reflect at boundaries
          if (idx < 0)
            idx = -idx;
          if (idx >= static_cast<int>(n))
            idx = 2 * static_cast<int>(n) - idx - 2;
          sum += coeffs[j + half_window] * intensity[idx];
        }
        smoothed[i] = sum;
      }

      return smoothed;
    };

    // MARK: smooth_intensity
    std::vector<float> smooth_intensity(const std::vector<float> &intensity, int windowSize)
    {
      const size_t n = intensity.size();
      std::vector<float> smoothed(n);
      int half_window = windowSize / 2;

      for (size_t i = 0; i < n; ++i)
      {
        size_t start_idx = (i >= static_cast<size_t>(half_window)) ? i - half_window : 0;
        size_t end_idx = std::min(n - 1, i + half_window);

        float sum = 0.0f;
        size_t count = 0;
        for (size_t j = start_idx; j <= end_idx; ++j)
        {
          sum += intensity[j];
          count++;
        }
        smoothed[i] = sum / count;
      }

      return smoothed;
    }

    // MARK: calculate_derivatives
    void calculate_derivatives(const std::vector<float> &smoothed_intensity,
                               std::vector<float> &first_derivative,
                               std::vector<float> &second_derivative)
    {
      const size_t n = smoothed_intensity.size();

      // Calculate first derivative
      first_derivative.clear();
      first_derivative.reserve(n - 1);
      for (size_t i = 0; i < n - 1; ++i)
      {
        first_derivative.push_back(smoothed_intensity[i + 1] - smoothed_intensity[i]);
      }

      // Calculate second derivative
      second_derivative.clear();
      second_derivative.reserve(first_derivative.size() - 1);
      for (size_t i = 0; i < first_derivative.size() - 1; ++i)
      {
        second_derivative.push_back(first_derivative[i + 1] - first_derivative[i]);
      }
    };

    // MARK: calculate_peak_area
    float calculate_area(const std::vector<float> &rt, const std::vector<float> &intensity)
    {
      if (rt.size() < 2 || rt.size() != intensity.size())
        return 0.0f;

      float area = 0.0f;
      for (size_t i = 1; i < rt.size(); ++i)
      {
        float dx = rt[i] - rt[i - 1];
        float avg_intensity = (intensity[i] + intensity[i - 1]) / 2.0f;
        area += dx * avg_intensity;
      }

      return std::max(0.0f, area);
    }

    // MARK: fit_gaussian
    void fit_gaussian(const std::vector<float> &x, const std::vector<float> &y,
                      float &A, float &mu, float &sigma, float &baseline)
    {
      // Adam optimizer parameters
      const float alpha = 0.01f;   // Learning rate
      const float beta1 = 0.9f;    // First moment decay rate
      const float beta2 = 0.999f;  // Second moment decay rate
      const float epsilon = 1e-8f; // Small value to prevent division by zero
      const int max_iterations = 500;

      float m_A = 0.0f, v_A = 0.0f, m_mu = 0.0f, v_mu = 0.0f, m_sigma = 0.0f, v_sigma = 0.0f;
      float m_baseline = 0.0f, v_baseline = 0.0f;

      for (int iter = 1; iter <= max_iterations; ++iter)
      {
        float grad_A = 0.0f, grad_mu = 0.0f, grad_sigma = 0.0f, grad_baseline = 0.0f;

        // Calculate gradients
        for (size_t i = 0; i < x.size(); ++i)
        {
          float exp_term = std::exp(-std::pow(x[i] - mu, 2) / (2 * std::pow(sigma, 2)));
          float y_pred = baseline + A * exp_term;
          float error = y[i] - y_pred;

          grad_A += -2 * error * exp_term;
          grad_mu += -2 * error * A * exp_term * (x[i] - mu) / std::pow(sigma, 2);
          grad_sigma += -2 * error * A * exp_term * std::pow(x[i] - mu, 2) / std::pow(sigma, 3);
          grad_baseline += -2 * error;
        }

        // Adam update for A
        m_A = beta1 * m_A + (1 - beta1) * grad_A;
        v_A = beta2 * v_A + (1 - beta2) * grad_A * grad_A;
        float A_hat = m_A / (1 - std::pow(beta1, iter));
        float v_A_hat = v_A / (1 - std::pow(beta2, iter));
        A -= alpha * A_hat / (std::sqrt(v_A_hat) + epsilon);
        A = std::max(0.1f, A); // Keep positive

        // Adam update for mu
        m_mu = beta1 * m_mu + (1 - beta1) * grad_mu;
        v_mu = beta2 * v_mu + (1 - beta2) * grad_mu * grad_mu;
        float mu_hat = m_mu / (1 - std::pow(beta1, iter));
        float v_mu_hat = v_mu / (1 - std::pow(beta2, iter));
        mu -= alpha * mu_hat / (std::sqrt(v_mu_hat) + epsilon);

        // Adam update for sigma
        m_sigma = beta1 * m_sigma + (1 - beta1) * grad_sigma;
        v_sigma = beta2 * v_sigma + (1 - beta2) * grad_sigma * grad_sigma;
        float sigma_hat = m_sigma / (1 - std::pow(beta1, iter));
        float v_sigma_hat = v_sigma / (1 - std::pow(beta2, iter));
        sigma -= alpha * sigma_hat / (std::sqrt(v_sigma_hat) + epsilon);
        sigma = std::max(0.1f, std::min(sigma, 100.0f)); // Constrain sigma

        // Adam update for baseline
        m_baseline = beta1 * m_baseline + (1 - beta1) * grad_baseline;
        v_baseline = beta2 * v_baseline + (1 - beta2) * grad_baseline * grad_baseline;
        float baseline_hat = m_baseline / (1 - std::pow(beta1, iter));
        float v_baseline_hat = v_baseline / (1 - std::pow(beta2, iter));
        baseline -= alpha * baseline_hat / (std::sqrt(v_baseline_hat) + epsilon);
        baseline = std::max(0.0f, baseline); // Keep non-negative
      }
    }

    // MARK: calculate_gaussian_rsquared
    float calculate_gaussian_rsquared(const std::vector<float> &x, const std::vector<float> &y,
                                      float A, float mu, float sigma, float baseline)
    {
      if (x.empty() || y.empty() || x.size() != y.size())
        return 0.0f;

      float ss_total = 0.0f;
      float ss_residual = 0.0f;
      float mean_y = mean(y);

      for (size_t i = 0; i < x.size(); ++i)
      {
        float y_pred = gaussian_function_with_baseline(A, mu, sigma, baseline, x[i]);
        ss_residual += std::pow(y[i] - y_pred, 2);
        ss_total += std::pow(y[i] - mean_y, 2);
      }

      if (ss_total == 0.0f)
        return 0.0f;

      float r2 = 1.0f - (ss_residual / ss_total);
      // Don't clamp - negative R² indicates fit worse than mean (important diagnostic!)
      return r2;
    }

    // MARK: calculate_jaggedness
    // Measures peak smoothness (lower = smoother = better quality)
    // Returns normalized jaggedness score (0 = perfectly smooth, higher = more jagged)
    float calculate_jaggedness(const std::vector<float> &intensity)
    {
      if (intensity.size() < 3)
        return 0.0f;

      float max_intensity = *std::max_element(intensity.begin(), intensity.end());
      if (max_intensity == 0.0f)
        return 0.0f;

      float jaggedness = 0.0f;
      for (size_t i = 1; i < intensity.size() - 1; ++i)
      {
        float expected = (intensity[i - 1] + intensity[i + 1]) / 2.0f;
        jaggedness += std::abs(intensity[i] - expected);
      }

      // Normalize by number of points and max intensity
      return jaggedness / ((intensity.size() - 2) * max_intensity);
    }

    // MARK: calculate_sharpness
    // Measures how "sharp" vs "flat" the peak is (higher = sharper)
    // Returns sharpness score
    float calculate_sharpness(const std::vector<float> &rt,
                              const std::vector<float> &intensity,
                              float area)
    {
      if (rt.empty() || intensity.empty() || rt.size() != intensity.size())
        return 0.0f;

      float max_intensity = *std::max_element(intensity.begin(), intensity.end());
      float width = rt.back() - rt.front();

      if (width == 0.0f || area == 0.0f)
        return 0.0f;

      // Sharpness = peak_height / (width * sqrt(area))
      // Higher values indicate sharper, more defined peaks
      return max_intensity / (width * std::sqrt(std::abs(area)));
    }

    // MARK: calculate_asymmetry
    // Calculates asymmetry factor (tailing factor) at 10% of peak height
    // Returns: 1.0 = symmetric, >1.0 = tailing, <1.0 = fronting
    float calculate_asymmetry(const std::vector<float> &rt,
                              const std::vector<float> &intensity)
    {
      if (rt.size() < 3 || intensity.size() < 3 || rt.size() != intensity.size())
        return 1.0f;

      // Find apex
      auto max_it = std::max_element(intensity.begin(), intensity.end());
      float max_intensity = *max_it;
      size_t max_idx = std::distance(intensity.begin(), max_it);

      // Calculate 10% height (USP standard)
      float baseline = std::min(intensity.front(), intensity.back());
      float peak_height = max_intensity - baseline;
      float target_height = baseline + (peak_height * 0.1f);

      // Find left and right points at 10% height
      size_t left_idx = 0;
      size_t right_idx = intensity.size() - 1;

      // Search left from apex
      for (size_t i = max_idx; i > 0; --i)
      {
        if (intensity[i] <= target_height)
        {
          left_idx = i;
          break;
        }
      }

      // Search right from apex
      for (size_t i = max_idx; i < intensity.size(); ++i)
      {
        if (intensity[i] <= target_height)
        {
          right_idx = i;
          break;
        }
      }

      if (left_idx >= max_idx || right_idx <= max_idx)
        return 1.0f;

      float rt_apex = rt[max_idx];
      float A = rt_apex - rt[left_idx];  // Left width
      float B = rt[right_idx] - rt_apex; // Right width

      if (A == 0.0f)
        return 10.0f; // Maximum asymmetry if left side is zero

      // USP tailing factor: T = (A + B) / (2*A)
      // Simplified: asymmetry_factor = B / A
      return B / A;
    };

    // MARK: calculate_modality
    // Counts number of local maxima in smoothed intensity (co-elution detection)
    // Returns: number of local maxima (1 = single peak, >1 = multiple peaks/co-elution)
    int calculate_modality(const std::vector<float> &smoothed_intensity,
                           float min_prominence_ratio)
    {
      if (smoothed_intensity.size() < 3)
        return 1;

      float global_max = *std::max_element(smoothed_intensity.begin(), smoothed_intensity.end());
      float min_prominence = global_max * min_prominence_ratio;

      int local_maxima_count = 0;

      for (size_t i = 1; i < smoothed_intensity.size() - 1; ++i)
      {
        // Check if it's a local maximum
        if (smoothed_intensity[i] > smoothed_intensity[i - 1] &&
            smoothed_intensity[i] > smoothed_intensity[i + 1])
        {
          // Check prominence (must be significant relative to global max)
          if (smoothed_intensity[i] >= min_prominence)
          {
            local_maxima_count++;
          }
        }
      }

      return std::max(1, local_maxima_count);
    };

    // MARK: calculate_theoretical_plates
    // Calculates chromatographic efficiency (theoretical plates)
    // Returns: number of theoretical plates (N)
    float calculate_theoretical_plates(float rt_apex,
                                       float width_at_half_height)
    {
      if (width_at_half_height == 0.0f || rt_apex == 0.0f)
        return 0.0f;

      // N = 5.54 * (tR / W₀.₅)²
      // where tR is retention time at apex and W₀.₅ is width at half height
      return 5.54f * std::pow(rt_apex / width_at_half_height, 2.0f);
    };

  } // namespace utils

  // MARK: ns api
  namespace api
  {
    // MARK: merge_NTS_FEATURE_SPECTRA
    NTS_FEATURE_SPECTRUM merge_NTS_FEATURE_SPECTRA(
        const mass_spec::spectra::MS_TARGETS_SPECTRA &spectra,
        const float &mzClust,
        const float &presence)
    {
      NTS_FEATURE_SPECTRUM out;

      const size_t n = spectra.mz.size();
      if (n == 0)
        return out;

      // Sort indices once so we can sweep contiguous clusters by m/z.
      std::vector<size_t> idx(n);
      std::iota(idx.begin(), idx.end(), 0);
      std::sort(idx.begin(), idx.end(), [&](size_t i, size_t j)
                { return spectra.mz[i] < spectra.mz[j]; });

      std::vector<float> sorted_mz(n);
      std::vector<float> sorted_intensity(n);
      std::vector<float> sorted_rt(spectra.rt.size());
      for (size_t k = 0; k < n; ++k)
      {
        const size_t src = idx[k];
        sorted_mz[k] = spectra.mz[src];
        sorted_intensity[k] = spectra.intensity[src];
        if (!sorted_rt.empty() && spectra.rt.size() > src)
          sorted_rt[k] = spectra.rt[src];
      }

      // Pre-compute total unique RT count for presence filtering.
      size_t total_unique_rt = 0;
      if (!sorted_rt.empty())
      {
        std::vector<float> tmp = sorted_rt;
        std::sort(tmp.begin(), tmp.end());
        total_unique_rt = static_cast<size_t>(std::unique(tmp.begin(), tmp.end()) - tmp.begin());
      }

      std::vector<float> new_mz;
      std::vector<float> new_intensity;
      new_mz.reserve(n);
      new_intensity.reserve(n);

      const float mz_tol = std::max(mzClust, 0.0f);
      const float presence_thresh = std::clamp(presence, 0.0f, 1.0f);

      size_t start = 0;
      while (start < n)
      {
        size_t end = start + 1;
        while (end < n && (sorted_mz[end] - sorted_mz[end - 1]) <= mz_tol)
          ++end;

        // Cluster range is [start, end)
        const size_t cluster_size = end - start;

        // Presence filter: require enough unique RTs inside this cluster.
        if (presence_thresh > 0.0f && total_unique_rt > 0)
        {
          std::vector<float> rt_slice;
          rt_slice.reserve(cluster_size);
          for (size_t i = start; i < end; ++i)
            rt_slice.push_back(sorted_rt[i]);
          std::sort(rt_slice.begin(), rt_slice.end());
          size_t unique_rt = static_cast<size_t>(std::unique(rt_slice.begin(), rt_slice.end()) - rt_slice.begin());

          if (static_cast<float>(unique_rt) < presence_thresh * static_cast<float>(total_unique_rt))
          {
            start = end;
            continue;
          }
        }

        float weighted_mz = 0.0f;
        float intensity_sum = 0.0f;
        float max_int = 0.0f;

        for (size_t i = start; i < end; ++i)
        {
          const float inten = sorted_intensity[i];
          weighted_mz += sorted_mz[i] * inten;
          intensity_sum += inten;
          max_int = std::max(max_int, inten);
        }

        if (intensity_sum > 0.0f)
        {
          new_mz.push_back(weighted_mz / intensity_sum);
          new_intensity.push_back(max_int);
        }

        start = end;
      }

      out.mz = std::move(new_mz);
      out.intensity = std::move(new_intensity);
      return out;
    };

    // NTS_FEATURE_SPECTRUM constructors / initializers
    NTS_FEATURE_SPECTRUM::NTS_FEATURE_SPECTRUM(
        const mass_spec::spectra::MS_TARGETS_SPECTRA &spectra,
        float mzClust,
        float presence)
    {
      *this = ::nts::api::merge_NTS_FEATURE_SPECTRA(spectra, mzClust, presence);
    }

    void NTS_FEATURE_SPECTRUM::init_from_targets(
        const mass_spec::spectra::MS_TARGETS_SPECTRA &spectra,
        float mzClust,
        float presence)
    {
      *this = ::nts::api::merge_NTS_FEATURE_SPECTRA(spectra, mzClust, presence);
    }

    std::vector<std::uint8_t> NTS_FEATURES::serialize_object() const
    {
      std::vector<std::uint8_t> out;
      project::cache::write_string(out, analysis);
      project::cache::write_vector(out, feature);
      project::cache::write_vector(out, feature_group);
      project::cache::write_vector(out, feature_component);
      project::cache::write_vector(out, adduct);
      project::cache::write_vector(out, rt);
      project::cache::write_vector(out, mz);
      project::cache::write_vector(out, mass);
      project::cache::write_vector(out, intensity);
      project::cache::write_vector(out, noise);
      project::cache::write_vector(out, sn);
      project::cache::write_vector(out, area);
      project::cache::write_vector(out, rtmin);
      project::cache::write_vector(out, rtmax);
      project::cache::write_vector(out, width);
      project::cache::write_vector(out, mzmin);
      project::cache::write_vector(out, mzmax);
      project::cache::write_vector(out, ppm);
      project::cache::write_vector(out, fwhm_rt);
      project::cache::write_vector(out, fwhm_mz);
      project::cache::write_vector(out, gaussian_A);
      project::cache::write_vector(out, gaussian_mu);
      project::cache::write_vector(out, gaussian_sigma);
      project::cache::write_vector(out, gaussian_r2);
      project::cache::write_vector(out, jaggedness);
      project::cache::write_vector(out, sharpness);
      project::cache::write_vector(out, asymmetry);
      project::cache::write_vector(out, modality);
      project::cache::write_vector(out, plates);
      project::cache::write_vector(out, polarity);
      project::cache::write_vector(out, filtered);
      project::cache::write_vector(out, filter);
      project::cache::write_vector(out, filled);
      project::cache::write_vector(out, correction);
      project::cache::write_vector(out, eic_size);
      project::cache::write_vector(out, eic_rt);
      project::cache::write_vector(out, eic_mz);
      project::cache::write_vector(out, eic_intensity);
      project::cache::write_vector(out, eic_baseline);
      project::cache::write_vector(out, eic_smoothed);
      project::cache::write_vector(out, ms1_size);
      project::cache::write_vector(out, ms1_mz);
      project::cache::write_vector(out, ms1_intensity);
      project::cache::write_vector(out, ms2_size);
      project::cache::write_vector(out, ms2_mz);
      project::cache::write_vector(out, ms2_intensity);
      return out;
    }

    NTS_FEATURES NTS_FEATURES::deserialize_object(const std::vector<std::uint8_t> &bytes)
    {
      project::cache::BINARY_READER reader(bytes);
      NTS_FEATURES value;
      value.analysis = project::cache::read_string(reader);
      project::cache::read_vector(reader, value.feature);
      project::cache::read_vector(reader, value.feature_group);
      project::cache::read_vector(reader, value.feature_component);
      project::cache::read_vector(reader, value.adduct);
      project::cache::read_vector(reader, value.rt);
      project::cache::read_vector(reader, value.mz);
      project::cache::read_vector(reader, value.mass);
      project::cache::read_vector(reader, value.intensity);
      project::cache::read_vector(reader, value.noise);
      project::cache::read_vector(reader, value.sn);
      project::cache::read_vector(reader, value.area);
      project::cache::read_vector(reader, value.rtmin);
      project::cache::read_vector(reader, value.rtmax);
      project::cache::read_vector(reader, value.width);
      project::cache::read_vector(reader, value.mzmin);
      project::cache::read_vector(reader, value.mzmax);
      project::cache::read_vector(reader, value.ppm);
      project::cache::read_vector(reader, value.fwhm_rt);
      project::cache::read_vector(reader, value.fwhm_mz);
      project::cache::read_vector(reader, value.gaussian_A);
      project::cache::read_vector(reader, value.gaussian_mu);
      project::cache::read_vector(reader, value.gaussian_sigma);
      project::cache::read_vector(reader, value.gaussian_r2);
      project::cache::read_vector(reader, value.jaggedness);
      project::cache::read_vector(reader, value.sharpness);
      project::cache::read_vector(reader, value.asymmetry);
      project::cache::read_vector(reader, value.modality);
      project::cache::read_vector(reader, value.plates);
      project::cache::read_vector(reader, value.polarity);
      project::cache::read_vector(reader, value.filtered);
      project::cache::read_vector(reader, value.filter);
      project::cache::read_vector(reader, value.filled);
      project::cache::read_vector(reader, value.correction);
      project::cache::read_vector(reader, value.eic_size);
      project::cache::read_vector(reader, value.eic_rt);
      project::cache::read_vector(reader, value.eic_mz);
      project::cache::read_vector(reader, value.eic_intensity);
      project::cache::read_vector(reader, value.eic_baseline);
      project::cache::read_vector(reader, value.eic_smoothed);
      project::cache::read_vector(reader, value.ms1_size);
      project::cache::read_vector(reader, value.ms1_mz);
      project::cache::read_vector(reader, value.ms1_intensity);
      project::cache::read_vector(reader, value.ms2_size);
      project::cache::read_vector(reader, value.ms2_mz);
      project::cache::read_vector(reader, value.ms2_intensity);
      if (!reader.empty())
      {
        throw project::error::ERROR(project::error::ERROR_CODE::SchemaMismatch, "deserialize NTS_FEATURES: trailing bytes remain");
      }
      return value;
    }

    std::vector<std::uint8_t> NTS_SUSPECTS::serialize_object() const
    {
      std::vector<std::uint8_t> out;
      project::cache::write_vector(out, analysis);
      project::cache::write_vector(out, feature);
      project::cache::write_vector(out, candidate_rank);
      project::cache::write_vector(out, name);
      project::cache::write_vector(out, polarity);
      project::cache::write_vector(out, db_mass);
      project::cache::write_vector(out, exp_mass);
      project::cache::write_vector(out, error_mass);
      project::cache::write_vector(out, db_rt);
      project::cache::write_vector(out, exp_rt);
      project::cache::write_vector(out, error_rt);
      project::cache::write_vector(out, intensity);
      project::cache::write_vector(out, area);
      project::cache::write_vector(out, id_level);
      project::cache::write_vector(out, score);
      project::cache::write_vector(out, shared_fragments);
      project::cache::write_vector(out, cosine_similarity);
      project::cache::write_vector(out, formula);
      project::cache::write_vector(out, SMILES);
      project::cache::write_vector(out, InChI);
      project::cache::write_vector(out, InChIKey);
      project::cache::write_vector(out, xLogP);
      project::cache::write_vector(out, database_id);
      project::cache::write_vector(out, db_ms2_size);
      project::cache::write_vector(out, db_ms2_mz);
      project::cache::write_vector(out, db_ms2_intensity);
      project::cache::write_vector(out, db_ms2_formula);
      project::cache::write_vector(out, exp_ms2_size);
      project::cache::write_vector(out, exp_ms2_mz);
      project::cache::write_vector(out, exp_ms2_intensity);
      return out;
    }

    NTS_SUSPECTS NTS_SUSPECTS::deserialize_object(const std::vector<std::uint8_t> &bytes)
    {
      project::cache::BINARY_READER reader(bytes);
      NTS_SUSPECTS value;
      project::cache::read_vector(reader, value.analysis);
      project::cache::read_vector(reader, value.feature);
      project::cache::read_vector(reader, value.candidate_rank);
      project::cache::read_vector(reader, value.name);
      project::cache::read_vector(reader, value.polarity);
      project::cache::read_vector(reader, value.db_mass);
      project::cache::read_vector(reader, value.exp_mass);
      project::cache::read_vector(reader, value.error_mass);
      project::cache::read_vector(reader, value.db_rt);
      project::cache::read_vector(reader, value.exp_rt);
      project::cache::read_vector(reader, value.error_rt);
      project::cache::read_vector(reader, value.intensity);
      project::cache::read_vector(reader, value.area);
      project::cache::read_vector(reader, value.id_level);
      project::cache::read_vector(reader, value.score);
      project::cache::read_vector(reader, value.shared_fragments);
      project::cache::read_vector(reader, value.cosine_similarity);
      project::cache::read_vector(reader, value.formula);
      project::cache::read_vector(reader, value.SMILES);
      project::cache::read_vector(reader, value.InChI);
      project::cache::read_vector(reader, value.InChIKey);
      project::cache::read_vector(reader, value.xLogP);
      project::cache::read_vector(reader, value.database_id);
      project::cache::read_vector(reader, value.db_ms2_size);
      project::cache::read_vector(reader, value.db_ms2_mz);
      project::cache::read_vector(reader, value.db_ms2_intensity);
      project::cache::read_vector(reader, value.db_ms2_formula);
      project::cache::read_vector(reader, value.exp_ms2_size);
      project::cache::read_vector(reader, value.exp_ms2_mz);
      project::cache::read_vector(reader, value.exp_ms2_intensity);
      if (!reader.empty())
      {
        throw project::error::ERROR(project::error::ERROR_CODE::SchemaMismatch, "deserialize NTS_SUSPECTS: trailing bytes remain");
      }
      return value;
    }

    NTS_FEATURE_ROW feature_row_from_result(duckdb_result &result, idx_t row)
    {
      NTS_FEATURE_ROW value;
      value.project_id = project::db::result_varchar(&result, 0, row);
      value.analysis = project::db::result_varchar(&result, 1, row);
      value.feature = project::db::result_varchar(&result, 2, row);
      value.feature_component = project::db::result_varchar(&result, 3, row);
      value.feature_group = project::db::result_varchar(&result, 4, row);
      value.adduct = project::db::result_varchar(&result, 5, row);
      value.rt = project::db::nullable_double(duckdb_value_double(&result, 6, row));
      value.mz = project::db::nullable_double(duckdb_value_double(&result, 7, row));
      value.mass = project::db::nullable_double(duckdb_value_double(&result, 8, row));
      value.intensity = project::db::nullable_double(duckdb_value_double(&result, 9, row));
      value.noise = project::db::nullable_double(duckdb_value_double(&result, 10, row));
      value.sn = project::db::nullable_double(duckdb_value_double(&result, 11, row));
      value.area = project::db::nullable_double(duckdb_value_double(&result, 12, row));
      value.rtmin = project::db::nullable_double(duckdb_value_double(&result, 13, row));
      value.rtmax = project::db::nullable_double(duckdb_value_double(&result, 14, row));
      value.width = project::db::nullable_double(duckdb_value_double(&result, 15, row));
      value.mzmin = project::db::nullable_double(duckdb_value_double(&result, 16, row));
      value.mzmax = project::db::nullable_double(duckdb_value_double(&result, 17, row));
      value.ppm = project::db::nullable_double(duckdb_value_double(&result, 18, row));
      value.fwhm_rt = project::db::nullable_double(duckdb_value_double(&result, 19, row));
      value.fwhm_mz = project::db::nullable_double(duckdb_value_double(&result, 20, row));
      value.gaussian_A = project::db::nullable_double(duckdb_value_double(&result, 21, row));
      value.gaussian_mu = project::db::nullable_double(duckdb_value_double(&result, 22, row));
      value.gaussian_sigma = project::db::nullable_double(duckdb_value_double(&result, 23, row));
      value.gaussian_r2 = project::db::nullable_double(duckdb_value_double(&result, 24, row));
      value.jaggedness = project::db::nullable_double(duckdb_value_double(&result, 25, row));
      value.sharpness = project::db::nullable_double(duckdb_value_double(&result, 26, row));
      value.asymmetry = project::db::nullable_double(duckdb_value_double(&result, 27, row));
      value.modality = project::db::nullable_int(duckdb_value_int32(&result, 28, row));
      value.plates = project::db::nullable_double(duckdb_value_double(&result, 29, row));
      value.polarity = project::db::nullable_int(duckdb_value_int32(&result, 30, row));
      value.filtered = duckdb_value_boolean(&result, 31, row) != 0;
      value.filter = project::db::result_varchar(&result, 32, row);
      value.filled = duckdb_value_boolean(&result, 33, row) != 0;
      value.correction = project::db::nullable_double(duckdb_value_double(&result, 34, row));
      value.eic_size = project::db::nullable_int(duckdb_value_int32(&result, 35, row));
      value.eic_rt = project::db::result_varchar(&result, 36, row);
      value.eic_mz = project::db::result_varchar(&result, 37, row);
      value.eic_intensity = project::db::result_varchar(&result, 38, row);
      value.eic_baseline = project::db::result_varchar(&result, 39, row);
      value.eic_smoothed = project::db::result_varchar(&result, 40, row);
      value.ms1_size = project::db::nullable_int(duckdb_value_int32(&result, 41, row));
      value.ms1_mz = project::db::result_varchar(&result, 42, row);
      value.ms1_intensity = project::db::result_varchar(&result, 43, row);
      value.ms2_size = project::db::nullable_int(duckdb_value_int32(&result, 44, row));
      value.ms2_mz = project::db::result_varchar(&result, 45, row);
      value.ms2_intensity = project::db::result_varchar(&result, 46, row);
      value.created_at = project::db::result_varchar(&result, 47, row);
      return value;
    }

    NTS_SUSPECT_ROW suspect_row_from_result(duckdb_result &result, idx_t row)
    {
      NTS_SUSPECT_ROW value;
      value.project_id = project::db::result_varchar(&result, 0, row);
      value.analysis = project::db::result_varchar(&result, 1, row);
      value.feature = project::db::result_varchar(&result, 2, row);
      value.candidate_rank = duckdb_value_int32(&result, 3, row);
      value.name = project::db::result_varchar(&result, 4, row);
      value.polarity = duckdb_value_int32(&result, 5, row);
      value.db_mass = duckdb_value_double(&result, 6, row);
      value.exp_mass = duckdb_value_double(&result, 7, row);
      value.error_mass = duckdb_value_double(&result, 8, row);
      value.db_rt = duckdb_value_double(&result, 9, row);
      value.exp_rt = duckdb_value_double(&result, 10, row);
      value.error_rt = duckdb_value_double(&result, 11, row);
      value.intensity = duckdb_value_double(&result, 12, row);
      value.area = duckdb_value_double(&result, 13, row);
      value.id_level = duckdb_value_int32(&result, 14, row);
      value.score = duckdb_value_double(&result, 15, row);
      value.shared_fragments = duckdb_value_int32(&result, 16, row);
      value.cosine_similarity = duckdb_value_double(&result, 17, row);
      value.formula = project::db::result_varchar(&result, 18, row);
      value.SMILES = project::db::result_varchar(&result, 19, row);
      value.InChI = project::db::result_varchar(&result, 20, row);
      value.InChIKey = project::db::result_varchar(&result, 21, row);
      value.xLogP = duckdb_value_double(&result, 22, row);
      value.database_id = project::db::result_varchar(&result, 23, row);
      value.db_ms2_size = duckdb_value_int32(&result, 24, row);
      value.db_ms2_mz = project::db::result_varchar(&result, 25, row);
      value.db_ms2_intensity = project::db::result_varchar(&result, 26, row);
      value.db_ms2_formula = project::db::result_varchar(&result, 27, row);
      value.exp_ms2_size = duckdb_value_int32(&result, 28, row);
      value.exp_ms2_mz = project::db::result_varchar(&result, 29, row);
      value.exp_ms2_intensity = project::db::result_varchar(&result, 30, row);
      value.created_at = project::db::result_varchar(&result, 31, row);
      return value;
    }

    NTS_INTERNAL_STANDARD_ROW internal_standard_row_from_result(duckdb_result &result, idx_t row)
    {
      NTS_INTERNAL_STANDARD_ROW value;
      value.project_id = project::db::result_varchar(&result, 0, row);
      value.analysis = project::db::result_varchar(&result, 1, row);
      value.feature = project::db::result_varchar(&result, 2, row);
      value.candidate_rank = duckdb_value_int32(&result, 3, row);
      value.name = project::db::result_varchar(&result, 4, row);
      value.polarity = duckdb_value_int32(&result, 5, row);
      value.db_mass = duckdb_value_double(&result, 6, row);
      value.exp_mass = duckdb_value_double(&result, 7, row);
      value.error_mass = duckdb_value_double(&result, 8, row);
      value.db_rt = duckdb_value_double(&result, 9, row);
      value.exp_rt = duckdb_value_double(&result, 10, row);
      value.error_rt = duckdb_value_double(&result, 11, row);
      value.intensity = duckdb_value_double(&result, 12, row);
      value.area = duckdb_value_double(&result, 13, row);
      value.id_level = duckdb_value_int32(&result, 14, row);
      value.score = duckdb_value_double(&result, 15, row);
      value.shared_fragments = duckdb_value_int32(&result, 16, row);
      value.cosine_similarity = duckdb_value_double(&result, 17, row);
      value.formula = project::db::result_varchar(&result, 18, row);
      value.SMILES = project::db::result_varchar(&result, 19, row);
      value.InChI = project::db::result_varchar(&result, 20, row);
      value.InChIKey = project::db::result_varchar(&result, 21, row);
      value.xLogP = duckdb_value_double(&result, 22, row);
      value.database_id = project::db::result_varchar(&result, 23, row);
      value.db_ms2_size = duckdb_value_int32(&result, 24, row);
      value.db_ms2_mz = project::db::result_varchar(&result, 25, row);
      value.db_ms2_intensity = project::db::result_varchar(&result, 26, row);
      value.db_ms2_formula = project::db::result_varchar(&result, 27, row);
      value.exp_ms2_size = duckdb_value_int32(&result, 28, row);
      value.exp_ms2_mz = project::db::result_varchar(&result, 29, row);
      value.exp_ms2_intensity = project::db::result_varchar(&result, 30, row);
      value.created_at = project::db::result_varchar(&result, 31, row);
      return value;
    }

    NTS_TRANSFORMATION_PRODUCT_ROW transformation_product_row_from_result(duckdb_result &result, idx_t row)
    {
      NTS_TRANSFORMATION_PRODUCT_ROW value;
      value.project_id = project::db::result_varchar(&result, 0, row);
      value.name = project::db::result_varchar(&result, 1, row);
      value.formula = project::db::result_varchar(&result, 2, row);
      value.mass = duckdb_value_double(&result, 3, row);
      value.SMILES = project::db::result_varchar(&result, 4, row);
      value.InChI = project::db::result_varchar(&result, 5, row);
      value.InChIKey = project::db::result_varchar(&result, 6, row);
      value.xLogP = duckdb_value_double(&result, 7, row);
      value.transformation = project::db::result_varchar(&result, 8, row);
      value.precursor_name = project::db::result_varchar(&result, 9, row);
      value.precursor_formula = project::db::result_varchar(&result, 10, row);
      value.precursor_mass = duckdb_value_double(&result, 11, row);
      value.precursor_SMILES = project::db::result_varchar(&result, 12, row);
      value.precursor_InChI = project::db::result_varchar(&result, 13, row);
      value.precursor_InChIKey = project::db::result_varchar(&result, 14, row);
      value.precursor_xLogP = duckdb_value_double(&result, 15, row);
      value.main_precursor_name = project::db::result_varchar(&result, 16, row);
      value.main_precursor_formula = project::db::result_varchar(&result, 17, row);
      value.main_precursor_mass = duckdb_value_double(&result, 18, row);
      value.main_precursor_SMILES = project::db::result_varchar(&result, 19, row);
      value.main_precursor_InChI = project::db::result_varchar(&result, 20, row);
      value.main_precursor_InChIKey = project::db::result_varchar(&result, 21, row);
      value.main_precursor_xLogP = duckdb_value_double(&result, 22, row);
      value.feature_group = project::db::result_varchar(&result, 23, row);
      value.precursor_feature_group = project::db::result_varchar(&result, 24, row);
      value.main_precursor_feature_group = project::db::result_varchar(&result, 25, row);
      value.cosine_similarity = duckdb_value_double(&result, 26, row);
      value.main_precursor_cosine_similarity = duckdb_value_double(&result, 27, row);
      value.rt_plausibility = duckdb_value_double(&result, 28, row);
      value.main_precursor_rt_plausibility = duckdb_value_double(&result, 29, row);
      value.created_at = project::db::result_varchar(&result, 30, row);
      return value;
    }

    // MARK: PROJECT_NON_TARGET_ANALYSIS
    PROJECT_NON_TARGET_ANALYSIS::PROJECT_NON_TARGET_ANALYSIS(std::shared_ptr<project::api::CONTEXT> ctx)
        : ctx_(std::move(ctx))
    {
      project::PROJECT root(ctx_->db_path, ctx_->project_id);
      root.set_domain("mass_spec_nts");
      mass_spec::PROJECT_MASS_SPEC::create_schema(ctx_);
      mass_spec::PROJECT_MASS_SPEC::validate_schema(ctx_);
      create_schema(ctx_);
      validate_schema(ctx_);
    }

    void PROJECT_NON_TARGET_ANALYSIS::create_schema(const std::shared_ptr<project::api::CONTEXT> &ctx)
    {
      auto guard = mass_spec::api::connect_checked(ctx);
      project::db::run_sql(
          guard.get(),
          "CREATE TABLE IF NOT EXISTS NTS_FEATURES ("
          "project_id VARCHAR NOT NULL, "
          "analysis VARCHAR NOT NULL, "
          "feature VARCHAR NOT NULL, "
          "feature_component VARCHAR, "
          "feature_group VARCHAR, "
          "adduct VARCHAR, "
          "rt DOUBLE, "
          "mz DOUBLE, "
          "mass DOUBLE, "
          "intensity DOUBLE, "
          "noise DOUBLE, "
          "sn DOUBLE, "
          "area DOUBLE, "
          "rtmin DOUBLE, "
          "rtmax DOUBLE, "
          "width DOUBLE, "
          "mzmin DOUBLE, "
          "mzmax DOUBLE, "
          "ppm DOUBLE, "
          "fwhm_rt DOUBLE, "
          "fwhm_mz DOUBLE, "
          "gaussian_A DOUBLE, "
          "gaussian_mu DOUBLE, "
          "gaussian_sigma DOUBLE, "
          "gaussian_r2 DOUBLE, "
          "jaggedness DOUBLE, "
          "sharpness DOUBLE, "
          "asymmetry DOUBLE, "
          "modality INTEGER, "
          "plates DOUBLE, "
          "polarity INTEGER, "
          "filtered BOOLEAN, "
          "filter VARCHAR, "
          "filled BOOLEAN, "
          "correction DOUBLE, "
          "eic_size INTEGER, "
          "eic_rt VARCHAR, "
          "eic_mz VARCHAR, "
          "eic_intensity VARCHAR, "
          "eic_baseline VARCHAR, "
          "eic_smoothed VARCHAR, "
          "ms1_size INTEGER, "
          "ms1_mz VARCHAR, "
          "ms1_intensity VARCHAR, "
          "ms2_size INTEGER, "
          "ms2_mz VARCHAR, "
          "ms2_intensity VARCHAR, "
          "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
          "PRIMARY KEY(project_id, analysis, feature)"
          ")",
          "create NTS_FEATURES table");
      project::db::run_sql(
          guard.get(),
          "CREATE TABLE IF NOT EXISTS NTS_INTERNAL_STANDARDS ("
          "project_id VARCHAR NOT NULL, "
          "analysis VARCHAR NOT NULL, "
          "feature VARCHAR NOT NULL, "
          "candidate_rank INTEGER NOT NULL, "
          "name VARCHAR NOT NULL, "
          "polarity INTEGER, "
          "db_mass DOUBLE, "
          "exp_mass DOUBLE, "
          "error_mass DOUBLE, "
          "db_rt DOUBLE, "
          "exp_rt DOUBLE, "
          "error_rt DOUBLE, "
          "intensity DOUBLE, "
          "area DOUBLE, "
          "id_level INTEGER, "
          "score DOUBLE, "
          "shared_fragments INTEGER, "
          "cosine_similarity DOUBLE, "
          "formula VARCHAR, "
          "SMILES VARCHAR, "
          "InChI VARCHAR, "
          "InChIKey VARCHAR, "
          "xLogP DOUBLE, "
          "database_id VARCHAR, "
          "db_ms2_size INTEGER, "
          "db_ms2_mz VARCHAR, "
          "db_ms2_intensity VARCHAR, "
          "db_ms2_formula VARCHAR, "
          "exp_ms2_size INTEGER, "
          "exp_ms2_mz VARCHAR, "
          "exp_ms2_intensity VARCHAR, "
          "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
          "PRIMARY KEY(project_id, analysis, feature, candidate_rank, name)"
          ")",
          "create NTS_INTERNAL_STANDARDS table");
      project::db::run_sql(
          guard.get(),
          "CREATE TABLE IF NOT EXISTS NTS_SUSPECTS ("
          "project_id VARCHAR NOT NULL, "
          "analysis VARCHAR NOT NULL, "
          "feature VARCHAR NOT NULL, "
          "candidate_rank INTEGER NOT NULL, "
          "name VARCHAR NOT NULL, "
          "polarity INTEGER, "
          "db_mass DOUBLE, "
          "exp_mass DOUBLE, "
          "error_mass DOUBLE, "
          "db_rt DOUBLE, "
          "exp_rt DOUBLE, "
          "error_rt DOUBLE, "
          "intensity DOUBLE, "
          "area DOUBLE, "
          "id_level INTEGER, "
          "score DOUBLE, "
          "shared_fragments INTEGER, "
          "cosine_similarity DOUBLE, "
          "formula VARCHAR, "
          "SMILES VARCHAR, "
          "InChI VARCHAR, "
          "InChIKey VARCHAR, "
          "xLogP DOUBLE, "
          "database_id VARCHAR, "
          "db_ms2_size INTEGER, "
          "db_ms2_mz VARCHAR, "
          "db_ms2_intensity VARCHAR, "
          "db_ms2_formula VARCHAR, "
          "exp_ms2_size INTEGER, "
          "exp_ms2_mz VARCHAR, "
          "exp_ms2_intensity VARCHAR, "
          "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
          "PRIMARY KEY(project_id, analysis, feature, candidate_rank, name)"
          ")",
          "create NTS_SUSPECTS table");
      project::db::run_sql(
          guard.get(),
          "CREATE TABLE IF NOT EXISTS NTS_TRANSFORMATION_PRODUCTS ("
          "project_id VARCHAR NOT NULL, "
          "name VARCHAR, "
          "formula VARCHAR, "
          "mass DOUBLE, "
          "SMILES VARCHAR, "
          "InChI VARCHAR, "
          "InChIKey VARCHAR, "
          "xLogP DOUBLE, "
          "transformation VARCHAR, "
          "precursor_name VARCHAR, "
          "precursor_formula VARCHAR, "
          "precursor_mass DOUBLE, "
          "precursor_SMILES VARCHAR, "
          "precursor_InChI VARCHAR, "
          "precursor_InChIKey VARCHAR, "
          "precursor_xLogP DOUBLE, "
          "main_precursor_name VARCHAR, "
          "main_precursor_formula VARCHAR, "
          "main_precursor_mass DOUBLE, "
          "main_precursor_SMILES VARCHAR, "
          "main_precursor_InChI VARCHAR, "
          "main_precursor_InChIKey VARCHAR, "
          "main_precursor_xLogP DOUBLE, "
          "feature_group VARCHAR, "
          "precursor_feature_group VARCHAR, "
          "main_precursor_feature_group VARCHAR, "
          "cosine_similarity DOUBLE, "
          "main_precursor_cosine_similarity DOUBLE, "
          "rt_plausibility DOUBLE, "
          "main_precursor_rt_plausibility DOUBLE, "
          "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP"
          ")",
          "create NTS_TRANSFORMATION_PRODUCTS table");
    }

    void PROJECT_NON_TARGET_ANALYSIS::validate_schema(const std::shared_ptr<project::api::CONTEXT> &ctx)
    {
      auto guard = mass_spec::api::connect_checked(ctx);
      project::db::validate_columns_present(
          guard.get(),
          features_table_name(),
          {{"project_id", "VARCHAR", true},
           {"analysis", "VARCHAR", true},
           {"feature", "VARCHAR", true},
           {"feature_component", "VARCHAR", false},
           {"feature_group", "VARCHAR", false},
           {"adduct", "VARCHAR", false},
           {"rt", "DOUBLE", false},
           {"mz", "DOUBLE", false},
           {"mass", "DOUBLE", false},
           {"intensity", "DOUBLE", false},
           {"noise", "DOUBLE", false},
           {"sn", "DOUBLE", false},
           {"area", "DOUBLE", false},
           {"rtmin", "DOUBLE", false},
           {"rtmax", "DOUBLE", false},
           {"width", "DOUBLE", false},
           {"mzmin", "DOUBLE", false},
           {"mzmax", "DOUBLE", false},
           {"ppm", "DOUBLE", false},
           {"fwhm_rt", "DOUBLE", false},
           {"fwhm_mz", "DOUBLE", false},
           {"gaussian_A", "DOUBLE", false},
           {"gaussian_mu", "DOUBLE", false},
           {"gaussian_sigma", "DOUBLE", false},
           {"gaussian_r2", "DOUBLE", false},
           {"jaggedness", "DOUBLE", false},
           {"sharpness", "DOUBLE", false},
           {"asymmetry", "DOUBLE", false},
           {"modality", "INTEGER", false},
           {"plates", "DOUBLE", false},
           {"polarity", "INTEGER", false},
           {"filtered", "BOOLEAN", false},
           {"filter", "VARCHAR", false},
           {"filled", "BOOLEAN", false},
           {"correction", "DOUBLE", false},
           {"eic_size", "INTEGER", false},
           {"eic_rt", "VARCHAR", false},
           {"eic_mz", "VARCHAR", false},
           {"eic_intensity", "VARCHAR", false},
           {"eic_baseline", "VARCHAR", false},
           {"eic_smoothed", "VARCHAR", false},
           {"ms1_size", "INTEGER", false},
           {"ms1_mz", "VARCHAR", false},
           {"ms1_intensity", "VARCHAR", false},
           {"ms2_size", "INTEGER", false},
           {"ms2_mz", "VARCHAR", false},
           {"ms2_intensity", "VARCHAR", false},
           {"created_at", "TIMESTAMP", false}});
      project::db::validate_columns_present(
          guard.get(),
          internal_standards_table_name(),
          {{"project_id", "VARCHAR", true},
           {"analysis", "VARCHAR", true},
           {"feature", "VARCHAR", true},
           {"candidate_rank", "INTEGER", true},
           {"name", "VARCHAR", true},
           {"polarity", "INTEGER", false},
           {"db_mass", "DOUBLE", false},
           {"exp_mass", "DOUBLE", false},
           {"error_mass", "DOUBLE", false},
           {"db_rt", "DOUBLE", false},
           {"exp_rt", "DOUBLE", false},
           {"error_rt", "DOUBLE", false},
           {"intensity", "DOUBLE", false},
           {"area", "DOUBLE", false},
           {"id_level", "INTEGER", false},
           {"score", "DOUBLE", false},
           {"shared_fragments", "INTEGER", false},
           {"cosine_similarity", "DOUBLE", false},
           {"formula", "VARCHAR", false},
           {"SMILES", "VARCHAR", false},
           {"InChI", "VARCHAR", false},
           {"InChIKey", "VARCHAR", false},
           {"xLogP", "DOUBLE", false},
           {"database_id", "VARCHAR", false},
           {"db_ms2_size", "INTEGER", false},
           {"db_ms2_mz", "VARCHAR", false},
           {"db_ms2_intensity", "VARCHAR", false},
           {"db_ms2_formula", "VARCHAR", false},
           {"exp_ms2_size", "INTEGER", false},
           {"exp_ms2_mz", "VARCHAR", false},
           {"exp_ms2_intensity", "VARCHAR", false},
           {"created_at", "TIMESTAMP", false}});
      project::db::validate_columns_present(
          guard.get(),
          suspects_table_name(),
          {{"project_id", "VARCHAR", true},
           {"analysis", "VARCHAR", true},
           {"feature", "VARCHAR", true},
           {"candidate_rank", "INTEGER", true},
           {"name", "VARCHAR", true},
           {"polarity", "INTEGER", false},
           {"db_mass", "DOUBLE", false},
           {"exp_mass", "DOUBLE", false},
           {"error_mass", "DOUBLE", false},
           {"db_rt", "DOUBLE", false},
           {"exp_rt", "DOUBLE", false},
           {"error_rt", "DOUBLE", false},
           {"intensity", "DOUBLE", false},
           {"area", "DOUBLE", false},
           {"id_level", "INTEGER", false},
           {"score", "DOUBLE", false},
           {"shared_fragments", "INTEGER", false},
           {"cosine_similarity", "DOUBLE", false},
           {"formula", "VARCHAR", false},
           {"SMILES", "VARCHAR", false},
           {"InChI", "VARCHAR", false},
           {"InChIKey", "VARCHAR", false},
           {"xLogP", "DOUBLE", false},
           {"database_id", "VARCHAR", false},
           {"db_ms2_size", "INTEGER", false},
           {"db_ms2_mz", "VARCHAR", false},
           {"db_ms2_intensity", "VARCHAR", false},
           {"db_ms2_formula", "VARCHAR", false},
           {"exp_ms2_size", "INTEGER", false},
           {"exp_ms2_mz", "VARCHAR", false},
           {"exp_ms2_intensity", "VARCHAR", false},
           {"created_at", "TIMESTAMP", false}});
      project::db::validate_columns_present(
          guard.get(),
          transformation_products_table_name(),
          {{"project_id", "VARCHAR", true},
           {"name", "VARCHAR", false},
           {"formula", "VARCHAR", false},
           {"mass", "DOUBLE", false},
           {"SMILES", "VARCHAR", false},
           {"InChI", "VARCHAR", false},
           {"InChIKey", "VARCHAR", false},
           {"xLogP", "DOUBLE", false},
           {"transformation", "VARCHAR", false},
           {"precursor_name", "VARCHAR", false},
           {"precursor_formula", "VARCHAR", false},
           {"precursor_mass", "DOUBLE", false},
           {"precursor_SMILES", "VARCHAR", false},
           {"precursor_InChI", "VARCHAR", false},
           {"precursor_InChIKey", "VARCHAR", false},
           {"precursor_xLogP", "DOUBLE", false},
           {"main_precursor_name", "VARCHAR", false},
           {"main_precursor_formula", "VARCHAR", false},
           {"main_precursor_mass", "DOUBLE", false},
           {"main_precursor_SMILES", "VARCHAR", false},
           {"main_precursor_InChI", "VARCHAR", false},
           {"main_precursor_InChIKey", "VARCHAR", false},
           {"main_precursor_xLogP", "DOUBLE", false},
           {"feature_group", "VARCHAR", false},
           {"precursor_feature_group", "VARCHAR", false},
           {"main_precursor_feature_group", "VARCHAR", false},
           {"cosine_similarity", "DOUBLE", false},
           {"main_precursor_cosine_similarity", "DOUBLE", false},
           {"rt_plausibility", "DOUBLE", false},
           {"main_precursor_rt_plausibility", "DOUBLE", false},
           {"created_at", "TIMESTAMP", false}});
    };

    std::vector<NTS_FEATURE_COUNT_ROW> PROJECT_NON_TARGET_ANALYSIS::get_features_count(
        const std::vector<std::string> &analyses,
        bool include_filtered) const
    {
      auto guard = mass_spec::api::connect_checked(ctx_);
      std::vector<NTS_FEATURE_COUNT_ROW> out;
      const auto selected_analyses = mass_spec::spectra::sanitize_analyses(analyses);
      if (selected_analyses.empty())
      {
        return out;
      }

      std::string sql =
          "SELECT analysis, COUNT(*) AS total, "
          "SUM(CASE WHEN filtered THEN 1 ELSE 0 END) AS filtered_count, "
          "COUNT(DISTINCT CASE WHEN feature_group IS NOT NULL AND feature_group != '' THEN feature_group END) AS groups_count, "
          "COUNT(DISTINCT CASE WHEN feature_component IS NOT NULL AND feature_component != '' THEN feature_component END) AS components_count "
          "FROM NTS_FEATURES WHERE project_id = ? AND analysis IN (";
      sql += project::db::placeholders(selected_analyses.size());
      sql += ")";
      if (!include_filtered)
      {
        sql += " AND filtered = FALSE";
      }
      sql += " GROUP BY analysis ORDER BY lower(analysis), analysis";

      std::unordered_map<std::string, NTS_FEATURE_COUNT_ROW> rows_by_analysis;
      project::db::run_prepared(guard.get(), sql, "query NTS feature counts", [&](duckdb_prepared_statement statement)
                                {
      idx_t bind_index = 1;
      duckdb_bind_varchar(statement, bind_index++, ctx_->project_id.c_str());
      for (const auto& analysis : selected_analyses) {
        duckdb_bind_varchar(statement, bind_index++, analysis.c_str());
      } }, [&](duckdb_result &result)
                                {
      const idx_t count = duckdb_row_count(&result);
      for (idx_t row = 0; row < count; ++row) {
        NTS_FEATURE_COUNT_ROW value;
        value.analysis = project::db::result_varchar(&result, 0, row);
        value.total = duckdb_value_int64(&result, 1, row);
        value.filtered = duckdb_value_int64(&result, 2, row);
        value.groups = duckdb_value_int64(&result, 3, row);
        value.components = duckdb_value_int64(&result, 4, row);
        rows_by_analysis.emplace(value.analysis, value);
      } });

      out.reserve(selected_analyses.size());
      for (const auto &analysis : selected_analyses)
      {
        const auto it = rows_by_analysis.find(analysis);
        if (it == rows_by_analysis.end())
        {
          out.push_back(NTS_FEATURE_COUNT_ROW{analysis, 0, 0, 0, 0});
        }
        else
        {
          out.push_back(it->second);
        }
      }
      return out;
    }

    std::vector<NTS_FEATURE_ROW> PROJECT_NON_TARGET_ANALYSIS::get_features(
        const std::vector<std::string> &analyses,
        bool include_filtered) const
    {
      auto guard = mass_spec::api::connect_checked(ctx_);
      std::vector<NTS_FEATURE_ROW> out;
      const auto selected_analyses = mass_spec::spectra::sanitize_analyses(analyses);
      std::string sql =
          "SELECT project_id, analysis, feature, feature_component, feature_group, adduct, rt, mz, mass, intensity, "
          "noise, sn, area, rtmin, rtmax, width, mzmin, mzmax, ppm, fwhm_rt, fwhm_mz, gaussian_A, gaussian_mu, "
          "gaussian_sigma, gaussian_r2, jaggedness, sharpness, asymmetry, modality, plates, polarity, filtered, "
          "filter, filled, correction, eic_size, eic_rt, eic_mz, eic_intensity, eic_baseline, eic_smoothed, "
          "ms1_size, ms1_mz, ms1_intensity, ms2_size, ms2_mz, ms2_intensity, created_at "
          "FROM NTS_FEATURES WHERE project_id = ?";
      if (!include_filtered)
      {
        sql += " AND filtered = FALSE";
      }
      if (!selected_analyses.empty())
      {
        sql += " AND analysis IN (";
        sql += project::db::placeholders(selected_analyses.size());
        sql += ")";
      }
      sql += " ORDER BY lower(analysis), analysis, mz, rt, feature";

      project::db::run_prepared(guard.get(), sql, "query NTS feature rows", [&](duckdb_prepared_statement statement)
                                {
                         idx_t bind_index = 1;
                         duckdb_bind_varchar(statement, bind_index++, ctx_->project_id.c_str());
                         for (const auto& analysis : selected_analyses) {
                           duckdb_bind_varchar(statement, bind_index++, analysis.c_str());
                         } }, [&](duckdb_result &result)
                                { out = project::db::rows_from_result(&result, [&](idx_t row)
                                                                      { return feature_row_from_result(result, row); }); });
      return out;
    }

  } // namespace api

} // namespace nts

// MARK: load_features_ms1
void nts::NTS_DATA::load_features_ms1(
    bool filtered,
    const std::vector<float> &rtWindow,
    const std::vector<float> &mzWindow,
    float minTracesIntensity,
    float mzClust,
    float presence)
{
  const bool hasRtWindow = rtWindow.size() >= 2;
  const bool hasMzWindow = mzWindow.size() >= 2;

  for (size_t i = 0; i < features.size(); i++)
  {
    nts::api::NTS_FEATURES &fts_i = features[i];

    if (fts_i.size() == 0)
      continue;

    mass_spec::spectra::MS_TARGETS targets;
    int counter = 0;

    for (int j = 0; j < fts_i.size(); j++)
    {
      const nts::api::NTS_FEATURE_ROW &ft_j = fts_i.get_feature(j);

      if (ft_j.filtered && !filtered)
        continue;

      if (ft_j.ms1_size > 0 && !ft_j.ms1_mz.empty() && !ft_j.ms1_intensity.empty())
        continue;

      float mzmin = ft_j.mzmin;
      float mzmax = ft_j.mzmax;
      float rtmin = ft_j.rtmin;
      float rtmax = ft_j.rtmax;

      if (hasMzWindow)
      {
        mzmin = ft_j.mzmin + mzWindow[0]; // left boundary adjustment
        mzmax = ft_j.mzmax + mzWindow[1]; // right boundary adjustment
      }

      if (hasRtWindow)
      {
        rtmin = ft_j.rtmin + rtWindow[0]; // left boundary adjustment
        rtmax = ft_j.rtmax + rtWindow[1]; // right boundary adjustment
      }

      targets.index.push_back(counter);
      targets.id.push_back(ft_j.feature);
      targets.level.push_back(1);
      targets.polarity.push_back(ft_j.polarity);
      targets.precursor.push_back(false);
      targets.mz.push_back(ft_j.mz);
      targets.mzmin.push_back(mzmin);
      targets.mzmax.push_back(mzmax);
      targets.rt.push_back(ft_j.rt);
      targets.rtmin.push_back(rtmin);
      targets.rtmax.push_back(rtmax);
      targets.mobilitymin.push_back(0);
      targets.mobilitymax.push_back(0);
      counter++;
    }

    if (targets.id.size() == 0)
      continue;

    const std::string &file_i = files[i];

    if (!std::filesystem::exists(file_i))
      continue;

    const mass_spec::reader::MS_SPECTRA_HEADERS &header_i = headers[i];

    mass_spec::reader::MS_FILE ana(file_i);
    mass_spec::spectra::MS_TARGETS_SPECTRA res = ana.get_spectra_targets(targets, header_i, minTracesIntensity, 0);

    for (int j = 0; j < fts_i.size(); j++)
    {
      nts::api::NTS_FEATURE_ROW ft_j = fts_i.get_feature(j);

      if (ft_j.filtered && !filtered)
        continue;

      if (ft_j.ms1_size > 0 && !ft_j.ms1_mz.empty() && !ft_j.ms1_intensity.empty())
        continue;

      const mass_spec::spectra::MS_TARGETS_SPECTRA &res_j = res[ft_j.feature];

      const auto clustered = nts::api::merge_NTS_FEATURE_SPECTRA(res_j, mzClust, presence);
      const int n_res_j = static_cast<int>(clustered.mz.size());

      if (n_res_j == 0)
        continue;

      ft_j.ms1_size = n_res_j;
      ft_j.ms1_mz = utils::encode_floats_base64(clustered.mz);
      ft_j.ms1_intensity = utils::encode_floats_base64(clustered.intensity);

      fts_i.set_feature(j, ft_j);
    }
  }
}

// MARK: load_features_ms2
void nts::NTS_DATA::load_features_ms2(
    bool filtered,
    float minTracesIntensity,
    float isolationWindow,
    float mzClust,
    float presence)
{
  for (size_t i = 0; i < features.size(); i++)
  {
    nts::api::NTS_FEATURES &fts_i = features[i];

    if (fts_i.size() == 0)
      continue;

    mass_spec::spectra::MS_TARGETS targets;
    int counter = 0;

    for (int j = 0; j < fts_i.size(); j++)
    {
      const nts::api::NTS_FEATURE_ROW &ft_j = fts_i.get_feature(j);

      if (ft_j.filtered && !filtered)
        continue;

      if (ft_j.ms2_size > 0 && !ft_j.ms2_mz.empty() && !ft_j.ms2_intensity.empty())
        continue;

      targets.index.push_back(counter);
      targets.id.push_back(ft_j.feature);
      targets.level.push_back(2);
      targets.polarity.push_back(ft_j.polarity);
      targets.precursor.push_back(true);
      targets.mzmin.push_back(ft_j.mzmin - (isolationWindow / 2));
      targets.mzmax.push_back(ft_j.mzmax + (isolationWindow / 2));
      targets.rtmin.push_back(ft_j.rtmin - 1);
      targets.rtmax.push_back(ft_j.rtmax + 1);
      targets.mobilitymin.push_back(0);
      targets.mobilitymax.push_back(0);
      counter++;
    }

    if (targets.id.size() == 0)
      continue;

    const std::string &file_i = files[i];

    if (!std::filesystem::exists(file_i))
      continue;

    const mass_spec::reader::MS_SPECTRA_HEADERS &header_i = headers[i];

    mass_spec::reader::MS_FILE ana(file_i);
    mass_spec::spectra::MS_TARGETS_SPECTRA res = ana.get_spectra_targets(targets, header_i, 0, minTracesIntensity);

    for (int j = 0; j < fts_i.size(); j++)
    {
      nts::api::NTS_FEATURE_ROW ft_j = fts_i.get_feature(j);

      if (ft_j.filtered && !filtered)
        continue;

      if (ft_j.ms2_size > 0 && !ft_j.ms2_mz.empty() && !ft_j.ms2_intensity.empty())
        continue;

      const mass_spec::spectra::MS_TARGETS_SPECTRA &res_j = res[ft_j.feature];

      const auto clustered = nts::api::merge_NTS_FEATURE_SPECTRA(res_j, mzClust, presence);
      const int n_res_j = static_cast<int>(clustered.mz.size());

      if (n_res_j == 0)
        continue;

      ft_j.ms2_size = n_res_j;
      ft_j.ms2_mz = utils::encode_floats_base64(clustered.mz);
      ft_j.ms2_intensity = utils::encode_floats_base64(clustered.intensity);

      fts_i.set_feature(j, ft_j);
    }
  }
}
