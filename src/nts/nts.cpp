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

    std::vector<std::uint8_t> NTS_INTERNAL_STANDARDS::serialize_object() const
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

    NTS_INTERNAL_STANDARDS NTS_INTERNAL_STANDARDS::deserialize_object(const std::vector<std::uint8_t> &bytes)
    {
      project::cache::BINARY_READER reader(bytes);
      NTS_INTERNAL_STANDARDS value;
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
        throw project::error::ERROR(project::error::ERROR_CODE::SchemaMismatch, "deserialize NTS_INTERNAL_STANDARDS: trailing bytes remain");
      }
      return value;
    }

    std::vector<std::uint8_t> NTS_FEATURES_CACHE::serialize_object() const
    {
      std::vector<std::uint8_t> out;
      project::cache::write_scalar<std::uint64_t>(out, static_cast<std::uint64_t>(buffers.size()));
      for (const auto &buffer : buffers)
      {
        const auto bytes = buffer.serialize_object();
        project::cache::write_scalar<std::uint64_t>(out, static_cast<std::uint64_t>(bytes.size()));
        if (!bytes.empty())
        {
          project::cache::append_bytes(out, bytes.data(), bytes.size());
        }
      }
      return out;
    }

    NTS_FEATURES_CACHE NTS_FEATURES_CACHE::deserialize_object(const std::vector<std::uint8_t> &bytes)
    {
      project::cache::BINARY_READER reader(bytes);
      NTS_FEATURES_CACHE value;
      const auto count = project::cache::read_scalar<std::uint64_t>(reader);
      value.buffers.reserve(static_cast<std::size_t>(count));
      for (std::uint64_t i = 0; i < count; ++i)
      {
        const auto size = project::cache::read_scalar<std::uint64_t>(reader);
        std::vector<std::uint8_t> item(size);
        if (size > 0)
        {
          reader.read_bytes(item.data(), static_cast<std::size_t>(size));
        }
        value.buffers.push_back(NTS_FEATURES::deserialize_object(item));
      }
      if (!reader.empty())
      {
        throw project::error::ERROR(project::error::ERROR_CODE::SchemaMismatch, "deserialize NTS_FEATURES_CACHE: trailing bytes remain");
      }
      return value;
    }

    std::vector<std::uint8_t> NTS_SUSPECTS_CACHE::serialize_object() const
    {
      std::vector<std::uint8_t> out;
      project::cache::write_scalar<std::uint64_t>(out, static_cast<std::uint64_t>(buffers.size()));
      for (const auto &buffer : buffers)
      {
        const auto bytes = buffer.serialize_object();
        project::cache::write_scalar<std::uint64_t>(out, static_cast<std::uint64_t>(bytes.size()));
        if (!bytes.empty())
        {
          project::cache::append_bytes(out, bytes.data(), bytes.size());
        }
      }
      return out;
    }

    NTS_SUSPECTS_CACHE NTS_SUSPECTS_CACHE::deserialize_object(const std::vector<std::uint8_t> &bytes)
    {
      project::cache::BINARY_READER reader(bytes);
      NTS_SUSPECTS_CACHE value;
      const auto count = project::cache::read_scalar<std::uint64_t>(reader);
      value.buffers.reserve(static_cast<std::size_t>(count));
      for (std::uint64_t i = 0; i < count; ++i)
      {
        const auto size = project::cache::read_scalar<std::uint64_t>(reader);
        std::vector<std::uint8_t> item(size);
        if (size > 0)
        {
          reader.read_bytes(item.data(), static_cast<std::size_t>(size));
        }
        value.buffers.push_back(NTS_SUSPECTS::deserialize_object(item));
      }
      if (!reader.empty())
      {
        throw project::error::ERROR(project::error::ERROR_CODE::SchemaMismatch, "deserialize NTS_SUSPECTS_CACHE: trailing bytes remain");
      }
      return value;
    }

    std::vector<std::uint8_t> NTS_INTERNAL_STANDARDS_CACHE::serialize_object() const
    {
      std::vector<std::uint8_t> out;
      project::cache::write_scalar<std::uint64_t>(out, static_cast<std::uint64_t>(buffers.size()));
      for (const auto &buffer : buffers)
      {
        const auto bytes = buffer.serialize_object();
        project::cache::write_scalar<std::uint64_t>(out, static_cast<std::uint64_t>(bytes.size()));
        if (!bytes.empty())
        {
          project::cache::append_bytes(out, bytes.data(), bytes.size());
        }
      }
      return out;
    }

    NTS_INTERNAL_STANDARDS_CACHE NTS_INTERNAL_STANDARDS_CACHE::deserialize_object(const std::vector<std::uint8_t> &bytes)
    {
      project::cache::BINARY_READER reader(bytes);
      NTS_INTERNAL_STANDARDS_CACHE value;
      const auto count = project::cache::read_scalar<std::uint64_t>(reader);
      value.buffers.reserve(static_cast<std::size_t>(count));
      for (std::uint64_t i = 0; i < count; ++i)
      {
        const auto size = project::cache::read_scalar<std::uint64_t>(reader);
        std::vector<std::uint8_t> item(size);
        if (size > 0)
        {
          reader.read_bytes(item.data(), static_cast<std::size_t>(size));
        }
        value.buffers.push_back(NTS_INTERNAL_STANDARDS::deserialize_object(item));
      }
      if (!reader.empty())
      {
        throw project::error::ERROR(project::error::ERROR_CODE::SchemaMismatch, "deserialize NTS_INTERNAL_STANDARDS_CACHE: trailing bytes remain");
      }
      return value;
    }

    std::vector<std::uint8_t> NTS_TRANSFORMATION_PRODUCTS::serialize_object() const
    {
      std::vector<std::uint8_t> out;
      project::cache::write_vector(out, name);
      project::cache::write_vector(out, formula);
      project::cache::write_vector(out, mass);
      project::cache::write_vector(out, SMILES);
      project::cache::write_vector(out, InChI);
      project::cache::write_vector(out, InChIKey);
      project::cache::write_vector(out, xLogP);
      project::cache::write_vector(out, transformation);
      project::cache::write_vector(out, precursor_name);
      project::cache::write_vector(out, precursor_formula);
      project::cache::write_vector(out, precursor_mass);
      project::cache::write_vector(out, precursor_SMILES);
      project::cache::write_vector(out, precursor_InChI);
      project::cache::write_vector(out, precursor_InChIKey);
      project::cache::write_vector(out, precursor_xLogP);
      project::cache::write_vector(out, main_precursor_name);
      project::cache::write_vector(out, main_precursor_formula);
      project::cache::write_vector(out, main_precursor_mass);
      project::cache::write_vector(out, main_precursor_SMILES);
      project::cache::write_vector(out, main_precursor_InChI);
      project::cache::write_vector(out, main_precursor_InChIKey);
      project::cache::write_vector(out, main_precursor_xLogP);
      project::cache::write_vector(out, feature_group);
      project::cache::write_vector(out, precursor_feature_group);
      project::cache::write_vector(out, main_precursor_feature_group);
      project::cache::write_vector(out, cosine_similarity);
      project::cache::write_vector(out, main_precursor_cosine_similarity);
      project::cache::write_vector(out, rt_plausibility);
      project::cache::write_vector(out, main_precursor_rt_plausibility);
      return out;
    }

    NTS_TRANSFORMATION_PRODUCTS NTS_TRANSFORMATION_PRODUCTS::deserialize_object(const std::vector<std::uint8_t> &bytes)
    {
      project::cache::BINARY_READER reader(bytes);
      NTS_TRANSFORMATION_PRODUCTS value;
      project::cache::read_vector(reader, value.name);
      project::cache::read_vector(reader, value.formula);
      project::cache::read_vector(reader, value.mass);
      project::cache::read_vector(reader, value.SMILES);
      project::cache::read_vector(reader, value.InChI);
      project::cache::read_vector(reader, value.InChIKey);
      project::cache::read_vector(reader, value.xLogP);
      project::cache::read_vector(reader, value.transformation);
      project::cache::read_vector(reader, value.precursor_name);
      project::cache::read_vector(reader, value.precursor_formula);
      project::cache::read_vector(reader, value.precursor_mass);
      project::cache::read_vector(reader, value.precursor_SMILES);
      project::cache::read_vector(reader, value.precursor_InChI);
      project::cache::read_vector(reader, value.precursor_InChIKey);
      project::cache::read_vector(reader, value.precursor_xLogP);
      project::cache::read_vector(reader, value.main_precursor_name);
      project::cache::read_vector(reader, value.main_precursor_formula);
      project::cache::read_vector(reader, value.main_precursor_mass);
      project::cache::read_vector(reader, value.main_precursor_SMILES);
      project::cache::read_vector(reader, value.main_precursor_InChI);
      project::cache::read_vector(reader, value.main_precursor_InChIKey);
      project::cache::read_vector(reader, value.main_precursor_xLogP);
      project::cache::read_vector(reader, value.feature_group);
      project::cache::read_vector(reader, value.precursor_feature_group);
      project::cache::read_vector(reader, value.main_precursor_feature_group);
      project::cache::read_vector(reader, value.cosine_similarity);
      project::cache::read_vector(reader, value.main_precursor_cosine_similarity);
      project::cache::read_vector(reader, value.rt_plausibility);
      project::cache::read_vector(reader, value.main_precursor_rt_plausibility);
      if (!reader.empty())
      {
        throw project::error::ERROR(project::error::ERROR_CODE::SchemaMismatch, "deserialize NTS_TRANSFORMATION_PRODUCTS: trailing bytes remain");
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

    NTS_FEATURE_ROW feature_row_from_table(const NTS_FEATURES_TABLE &table, std::size_t row)
    {
      NTS_FEATURE_ROW value;
      value.project_id = table.project_id[row];
      value.analysis = table.analysis[row];
      value.feature = table.feature[row];
      value.feature_component = table.feature_component[row];
      value.feature_group = table.feature_group[row];
      value.adduct = table.adduct[row];
      value.rt = table.rt[row];
      value.mz = table.mz[row];
      value.mass = table.mass[row];
      value.intensity = table.intensity[row];
      value.noise = table.noise[row];
      value.sn = table.sn[row];
      value.area = table.area[row];
      value.rtmin = table.rtmin[row];
      value.rtmax = table.rtmax[row];
      value.width = table.width[row];
      value.mzmin = table.mzmin[row];
      value.mzmax = table.mzmax[row];
      value.ppm = table.ppm[row];
      value.fwhm_rt = table.fwhm_rt[row];
      value.fwhm_mz = table.fwhm_mz[row];
      value.gaussian_A = table.gaussian_A[row];
      value.gaussian_mu = table.gaussian_mu[row];
      value.gaussian_sigma = table.gaussian_sigma[row];
      value.gaussian_r2 = table.gaussian_r2[row];
      value.jaggedness = table.jaggedness[row];
      value.sharpness = table.sharpness[row];
      value.asymmetry = table.asymmetry[row];
      value.modality = table.modality[row];
      value.plates = table.plates[row];
      value.polarity = table.polarity[row];
      value.filtered = table.filtered[row];
      value.filter = table.filter[row];
      value.filled = table.filled[row];
      value.correction = table.correction[row];
      value.eic_size = table.eic_size[row];
      value.eic_rt = table.eic_rt[row];
      value.eic_mz = table.eic_mz[row];
      value.eic_intensity = table.eic_intensity[row];
      value.eic_baseline = table.eic_baseline[row];
      value.eic_smoothed = table.eic_smoothed[row];
      value.ms1_size = table.ms1_size[row];
      value.ms1_mz = table.ms1_mz[row];
      value.ms1_intensity = table.ms1_intensity[row];
      value.ms2_size = table.ms2_size[row];
      value.ms2_mz = table.ms2_mz[row];
      value.ms2_intensity = table.ms2_intensity[row];
      value.created_at = table.created_at[row];
      return value;
    }

    NTS_SUSPECT_ROW suspect_row_from_table(const NTS_SUSPECTS_TABLE &table, std::size_t row)
    {
      NTS_SUSPECT_ROW value;
      value.project_id = table.project_id[row];
      value.analysis = table.analysis[row];
      value.feature = table.feature[row];
      value.candidate_rank = table.candidate_rank[row];
      value.name = table.name[row];
      value.polarity = table.polarity[row];
      value.db_mass = table.db_mass[row];
      value.exp_mass = table.exp_mass[row];
      value.error_mass = table.error_mass[row];
      value.db_rt = table.db_rt[row];
      value.exp_rt = table.exp_rt[row];
      value.error_rt = table.error_rt[row];
      value.intensity = table.intensity[row];
      value.area = table.area[row];
      value.id_level = table.id_level[row];
      value.score = table.score[row];
      value.shared_fragments = table.shared_fragments[row];
      value.cosine_similarity = table.cosine_similarity[row];
      value.formula = table.formula[row];
      value.SMILES = table.SMILES[row];
      value.InChI = table.InChI[row];
      value.InChIKey = table.InChIKey[row];
      value.xLogP = table.xLogP[row];
      value.database_id = table.database_id[row];
      value.db_ms2_size = table.db_ms2_size[row];
      value.db_ms2_mz = table.db_ms2_mz[row];
      value.db_ms2_intensity = table.db_ms2_intensity[row];
      value.db_ms2_formula = table.db_ms2_formula[row];
      value.exp_ms2_size = table.exp_ms2_size[row];
      value.exp_ms2_mz = table.exp_ms2_mz[row];
      value.exp_ms2_intensity = table.exp_ms2_intensity[row];
      value.created_at = table.created_at[row];
      return value;
    }

    NTS_INTERNAL_STANDARD_ROW internal_standard_row_from_table(const NTS_INTERNAL_STANDARDS_TABLE &table, std::size_t row)
    {
      NTS_INTERNAL_STANDARD_ROW value;
      value.project_id = table.project_id[row];
      value.analysis = table.analysis[row];
      value.feature = table.feature[row];
      value.candidate_rank = table.candidate_rank[row];
      value.name = table.name[row];
      value.polarity = table.polarity[row];
      value.db_mass = table.db_mass[row];
      value.exp_mass = table.exp_mass[row];
      value.error_mass = table.error_mass[row];
      value.db_rt = table.db_rt[row];
      value.exp_rt = table.exp_rt[row];
      value.error_rt = table.error_rt[row];
      value.intensity = table.intensity[row];
      value.area = table.area[row];
      value.id_level = table.id_level[row];
      value.score = table.score[row];
      value.shared_fragments = table.shared_fragments[row];
      value.cosine_similarity = table.cosine_similarity[row];
      value.formula = table.formula[row];
      value.SMILES = table.SMILES[row];
      value.InChI = table.InChI[row];
      value.InChIKey = table.InChIKey[row];
      value.xLogP = table.xLogP[row];
      value.database_id = table.database_id[row];
      value.db_ms2_size = table.db_ms2_size[row];
      value.db_ms2_mz = table.db_ms2_mz[row];
      value.db_ms2_intensity = table.db_ms2_intensity[row];
      value.db_ms2_formula = table.db_ms2_formula[row];
      value.exp_ms2_size = table.exp_ms2_size[row];
      value.exp_ms2_mz = table.exp_ms2_mz[row];
      value.exp_ms2_intensity = table.exp_ms2_intensity[row];
      value.created_at = table.created_at[row];
      return value;
    }

    NTS_TRANSFORMATION_PRODUCT_ROW transformation_product_row_from_table(const NTS_TRANSFORMATION_PRODUCTS_TABLE &table, std::size_t row)
    {
      NTS_TRANSFORMATION_PRODUCT_ROW value;
      value.project_id = table.project_id[row];
      value.name = table.name[row];
      value.formula = table.formula[row];
      value.mass = table.mass[row];
      value.SMILES = table.SMILES[row];
      value.InChI = table.InChI[row];
      value.InChIKey = table.InChIKey[row];
      value.xLogP = table.xLogP[row];
      value.transformation = table.transformation[row];
      value.precursor_name = table.precursor_name[row];
      value.precursor_formula = table.precursor_formula[row];
      value.precursor_mass = table.precursor_mass[row];
      value.precursor_SMILES = table.precursor_SMILES[row];
      value.precursor_InChI = table.precursor_InChI[row];
      value.precursor_InChIKey = table.precursor_InChIKey[row];
      value.precursor_xLogP = table.precursor_xLogP[row];
      value.main_precursor_name = table.main_precursor_name[row];
      value.main_precursor_formula = table.main_precursor_formula[row];
      value.main_precursor_mass = table.main_precursor_mass[row];
      value.main_precursor_SMILES = table.main_precursor_SMILES[row];
      value.main_precursor_InChI = table.main_precursor_InChI[row];
      value.main_precursor_InChIKey = table.main_precursor_InChIKey[row];
      value.main_precursor_xLogP = table.main_precursor_xLogP[row];
      value.feature_group = table.feature_group[row];
      value.precursor_feature_group = table.precursor_feature_group[row];
      value.main_precursor_feature_group = table.main_precursor_feature_group[row];
      value.cosine_similarity = table.cosine_similarity[row];
      value.main_precursor_cosine_similarity = table.main_precursor_cosine_similarity[row];
      value.rt_plausibility = table.rt_plausibility[row];
      value.main_precursor_rt_plausibility = table.main_precursor_rt_plausibility[row];
      value.created_at = table.created_at[row];
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

    struct FEATURE_METADATA
    {
      std::string feature_group;
      std::string feature_component;
      std::string adduct;
    };

      std::vector<std::string> sanitize_query_values(const std::vector<std::string> &values)
      {
        std::vector<std::string> out;
        out.reserve(values.size());
        for (const auto &value : values)
        {
          const auto trimmed = mass_spec::spectra::sanitize_analyses({value});
          if (!trimmed.empty())
          {
            out.push_back(trimmed.front());
          }
          else if (!value.empty())
          {
            out.push_back(value);
          }
        }
        return out;
      }

      bool has_target_filters(const NTS_QUERY_REQUEST &query)
      {
        return !query.targets.mass.empty() ||
               !query.targets.mz.empty() ||
               !query.targets.rt.empty() ||
               !query.targets.mobility.empty();
      }

      std::vector<std::string> collect_feature_row_analyses(const std::vector<NTS_FEATURE_ROW> &rows)
      {
        std::vector<std::string> analyses;
        analyses.reserve(rows.size());
        for (const auto &row : rows)
        {
          if (std::find(analyses.begin(), analyses.end(), row.analysis) == analyses.end())
          {
            analyses.push_back(row.analysis);
          }
        }
        return analyses;
      }

      bool matches_feature_target(const NTS_FEATURE_ROW &row,
                                  const mass_spec::spectra::MS_TARGETS &targets)
      {
        for (std::size_t i = 0; i < targets.id.size(); ++i)
        {
          if (targets.polarity[i] != 0 && row.polarity != targets.polarity[i])
          {
            continue;
          }
          if ((targets.mzmin[i] > 0.0f || targets.mzmax[i] > 0.0f) &&
              (row.mz < targets.mzmin[i] || row.mz > targets.mzmax[i]))
          {
            continue;
          }
          if ((targets.rtmin[i] > 0.0f || targets.rtmax[i] > 0.0f) &&
              (row.rt < targets.rtmin[i] || row.rt > targets.rtmax[i]))
          {
            continue;
          }
          return true;
        }
        return false;
      }

      std::vector<NTS_FEATURE_ROW> filter_feature_rows_by_targets(const std::vector<NTS_FEATURE_ROW> &rows,
                                                                  const NTS_QUERY_REQUEST &query)
      {
        if (rows.empty() || !has_target_filters(query))
        {
          return rows;
        }

        const auto selected_analyses = mass_spec::spectra::sanitize_analyses(
            query.analyses.empty() ? collect_feature_row_analyses(rows) : query.analyses);
        if (selected_analyses.empty())
        {
          return {};
        }

        auto targets_by_analysis = mass_spec::spectra::build_targets_by_analysis(
            query.targets,
            selected_analyses,
            {"1", "-1"});

        std::unordered_map<std::string, mass_spec::spectra::MS_TARGETS> targets_lookup;
        for (std::size_t i = 0; i < selected_analyses.size() && i < targets_by_analysis.size(); ++i)
        {
          if (mass_spec::spectra::has_effective_targets(targets_by_analysis[i]))
          {
            targets_lookup.emplace(selected_analyses[i], std::move(targets_by_analysis[i]));
          }
        }

        if (targets_lookup.empty())
        {
          return {};
        }

        std::vector<NTS_FEATURE_ROW> out;
        out.reserve(rows.size());
        for (const auto &row : rows)
        {
          const auto it = targets_lookup.find(row.analysis);
          if (it == targets_lookup.end())
          {
            continue;
          }
          if (matches_feature_target(row, it->second))
          {
            out.push_back(row);
          }
        }
        return out;
      }

      std::unordered_set<std::string> feature_keys_from_rows(const std::vector<NTS_FEATURE_ROW> &rows)
      {
        std::unordered_set<std::string> out;
        out.reserve(rows.size());
        for (const auto &row : rows)
        {
          out.insert(row.analysis + "\x1f" + row.feature);
        }
        return out;
      }

      std::unordered_map<std::string, FEATURE_METADATA> feature_metadata_from_rows(const std::vector<NTS_FEATURE_ROW> &rows)
      {
        std::unordered_map<std::string, FEATURE_METADATA> out;
        out.reserve(rows.size());
        for (const auto &row : rows)
        {
          out[row.analysis + "\x1f" + row.feature] = FEATURE_METADATA{
              row.feature_group,
              row.feature_component,
              row.adduct};
        }
        return out;
      }

      std::string bytes_to_hex(const std::vector<std::uint8_t> &bytes)
      {
        static constexpr char hex[] = "0123456789abcdef";
        std::string out;
        out.reserve(bytes.size() * 2);
        for (const auto byte : bytes)
        {
          out.push_back(hex[(byte >> 4) & 0x0F]);
          out.push_back(hex[byte & 0x0F]);
        }
        return out;
      }

    std::string stable_hash_hex(const std::string &text)
    {
      constexpr std::uint64_t offset_basis = 14695981039346656037ull;
      constexpr std::uint64_t prime = 1099511628211ull;
      std::uint64_t hash = offset_basis;
      for (const unsigned char ch : text)
      {
        hash ^= static_cast<std::uint64_t>(ch);
        hash *= prime;
      }

      std::ostringstream stream;
      stream << std::hex << std::setfill('0') << std::setw(16) << hash;
      return stream.str();
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

    mass_spec::reader::MS_SPECTRA_HEADERS PROJECT_NON_TARGET_ANALYSIS::spectra_headers_at(std::size_t index) const
    {
      if (index >= analysis_names().size())
      {
        throw project::error::ERROR(project::error::ERROR_CODE::InvalidArgument, "NTS spectra_headers_at index out of range");
      }

      if (spectra_headers_cache_.size() != analysis_names().size())
      {
        spectra_headers_cache_.assign(analysis_names().size(), std::nullopt);
      }

      auto &cached = spectra_headers_cache_[index];
      if (cached.has_value())
      {
        return *cached;
      }

      mass_spec::reader::MS_SPECTRA_HEADERS header;
      const auto &analysis = analysis_names()[index];
      for (std::size_t row = 0; row < static_cast<std::size_t>(spectra_headers_table_.size()); ++row)
      {
        if (spectra_headers_table_.analysis[row] != analysis)
        {
          continue;
        }

        header.index.push_back(spectra_headers_table_.index[row]);
        header.scan.push_back(spectra_headers_table_.scan[row]);
        header.array_length.push_back(spectra_headers_table_.array_length[row]);
        header.level.push_back(spectra_headers_table_.level[row]);
        header.mode.push_back(spectra_headers_table_.mode[row]);
        header.polarity.push_back(spectra_headers_table_.polarity[row]);
        header.lowmz.push_back(static_cast<float>(spectra_headers_table_.lowmz[row]));
        header.highmz.push_back(static_cast<float>(spectra_headers_table_.highmz[row]));
        header.bpmz.push_back(static_cast<float>(spectra_headers_table_.bpmz[row]));
        header.bpint.push_back(static_cast<float>(spectra_headers_table_.bpint[row]));
        header.tic.push_back(static_cast<float>(spectra_headers_table_.tic[row]));
        header.configuration.push_back(spectra_headers_table_.configuration[row]);
        header.rt.push_back(static_cast<float>(spectra_headers_table_.rt[row]));
        header.mobility.push_back(static_cast<float>(spectra_headers_table_.mobility[row]));
        header.window_mz.push_back(static_cast<float>(spectra_headers_table_.window_mz[row]));
        header.window_mzlow.push_back(static_cast<float>(spectra_headers_table_.window_mzlow[row]));
        header.window_mzhigh.push_back(static_cast<float>(spectra_headers_table_.window_mzhigh[row]));
        header.precursor_mz.push_back(static_cast<float>(spectra_headers_table_.precursor_mz[row]));
        header.precursor_intensity.push_back(static_cast<float>(spectra_headers_table_.precursor_intensity[row]));
        header.precursor_charge.push_back(spectra_headers_table_.precursor_charge[row]);
        header.activation_ce.push_back(static_cast<float>(spectra_headers_table_.activation_ce[row]));
      }

      cached = std::move(header);
      return *cached;
    }

    NTS_FEATURES_TABLE PROJECT_NON_TARGET_ANALYSIS::collect_features_table(const NTS_QUERY_REQUEST &query) const
    {
      NTS_FEATURES_TABLE table;
      const auto rows = get_features(query);
      for (const auto &row : rows)
      {
        table.append(row);
      }
      return table;
    }

    NTS_SUSPECTS_TABLE PROJECT_NON_TARGET_ANALYSIS::collect_suspects_table(const NTS_QUERY_REQUEST &query) const
    {
      NTS_SUSPECTS_TABLE table;
      const auto rows = get_suspects(query);
      for (const auto &row : rows)
      {
        table.append(row);
      }
      return table;
    }

    NTS_INTERNAL_STANDARDS_TABLE PROJECT_NON_TARGET_ANALYSIS::collect_internal_standards_table(const NTS_QUERY_REQUEST &query) const
    {
      NTS_INTERNAL_STANDARDS_TABLE table;
      const auto rows = get_internal_standards(query);
      for (const auto &row : rows)
      {
        table.append(row);
      }
      return table;
    }

    NTS_TRANSFORMATION_PRODUCTS_TABLE PROJECT_NON_TARGET_ANALYSIS::collect_transformation_products_table() const
    {
      NTS_TRANSFORMATION_PRODUCTS_TABLE table;
      const auto rows = get_transformation_products();
      for (const auto &row : rows)
      {
        table.append(row);
      }
      return table;
    }

    void PROJECT_NON_TARGET_ANALYSIS::materialize_feature_buffers() const
    {
      if (feature_buffers_ready_ && feature_buffers_.size() == analysis_names().size())
      {
        return;
      }

      feature_buffers_.assign(analysis_names().size(), NTS_FEATURES());
      std::unordered_map<std::string, std::size_t> analysis_index;
      analysis_index.reserve(analysis_names().size());
      for (std::size_t i = 0; i < analysis_names().size(); ++i)
      {
        feature_buffers_[i].set_analysis(analysis_names()[i]);
        analysis_index.emplace(analysis_names()[i], i);
      }

      for (std::size_t row = 0; row < static_cast<std::size_t>(features_table_.size()); ++row)
      {
        const auto feature_row = feature_row_from_table(features_table_, row);
        const auto it = analysis_index.find(feature_row.analysis);
        if (it != analysis_index.end())
        {
          feature_buffers_[it->second].append_feature(feature_row);
        }
      }

      feature_buffers_ready_ = true;
    }

    void PROJECT_NON_TARGET_ANALYSIS::materialize_suspect_buffers() const
    {
      if (suspect_buffers_ready_ && suspect_buffers_.size() == analysis_names().size())
      {
        return;
      }

      suspect_buffers_.assign(analysis_names().size(), NTS_SUSPECTS());
      std::unordered_map<std::string, std::size_t> analysis_index;
      analysis_index.reserve(analysis_names().size());
      for (std::size_t i = 0; i < analysis_names().size(); ++i)
      {
        analysis_index.emplace(analysis_names()[i], i);
      }

      for (std::size_t row = 0; row < static_cast<std::size_t>(suspects_table_.size()); ++row)
      {
        const auto suspect_row = suspect_row_from_table(suspects_table_, row);
        const auto it = analysis_index.find(suspect_row.analysis);
        if (it != analysis_index.end())
        {
          suspect_buffers_[it->second].append(suspect_row);
        }
      }

      suspect_buffers_ready_ = true;
    }

    void PROJECT_NON_TARGET_ANALYSIS::materialize_internal_standard_buffers() const
    {
      if (internal_standard_buffers_ready_ && internal_standard_buffers_.size() == analysis_names().size())
      {
        return;
      }

      internal_standard_buffers_.assign(analysis_names().size(), NTS_INTERNAL_STANDARDS());
      std::unordered_map<std::string, std::size_t> analysis_index;
      analysis_index.reserve(analysis_names().size());
      for (std::size_t i = 0; i < analysis_names().size(); ++i)
      {
        analysis_index.emplace(analysis_names()[i], i);
      }

      for (std::size_t row = 0; row < static_cast<std::size_t>(internal_standards_table_.size()); ++row)
      {
        const auto standard_row = internal_standard_row_from_table(internal_standards_table_, row);
        const auto it = analysis_index.find(standard_row.analysis);
        if (it != analysis_index.end())
        {
          internal_standard_buffers_[it->second].append(standard_row);
        }
      }

      internal_standard_buffers_ready_ = true;
    }

    void PROJECT_NON_TARGET_ANALYSIS::materialize_transformation_products_buffer() const
    {
      if (transformation_products_ready_)
      {
        return;
      }

      transformation_products_buffer_ = NTS_TRANSFORMATION_PRODUCTS();
      for (std::size_t row = 0; row < static_cast<std::size_t>(transformation_products_table_.size()); ++row)
      {
        transformation_products_buffer_.append(transformation_product_row_from_table(transformation_products_table_, row));
      }
      transformation_products_ready_ = true;
    }

    std::vector<NTS_FEATURES> &PROJECT_NON_TARGET_ANALYSIS::feature_buffers()
    {
      materialize_feature_buffers();
      return feature_buffers_;
    }

    const std::vector<NTS_FEATURES> &PROJECT_NON_TARGET_ANALYSIS::feature_buffers() const
    {
      materialize_feature_buffers();
      return feature_buffers_;
    }

    std::vector<NTS_SUSPECTS> &PROJECT_NON_TARGET_ANALYSIS::suspect_buffers()
    {
      materialize_suspect_buffers();
      return suspect_buffers_;
    }

    const std::vector<NTS_SUSPECTS> &PROJECT_NON_TARGET_ANALYSIS::suspect_buffers() const
    {
      materialize_suspect_buffers();
      return suspect_buffers_;
    }

    std::vector<NTS_INTERNAL_STANDARDS> &PROJECT_NON_TARGET_ANALYSIS::internal_standard_buffers()
    {
      materialize_internal_standard_buffers();
      return internal_standard_buffers_;
    }

    const std::vector<NTS_INTERNAL_STANDARDS> &PROJECT_NON_TARGET_ANALYSIS::internal_standard_buffers() const
    {
      materialize_internal_standard_buffers();
      return internal_standard_buffers_;
    }

    NTS_TRANSFORMATION_PRODUCTS &PROJECT_NON_TARGET_ANALYSIS::transformation_products()
    {
      materialize_transformation_products_buffer();
      return transformation_products_buffer_;
    }

    const NTS_TRANSFORMATION_PRODUCTS &PROJECT_NON_TARGET_ANALYSIS::transformation_products() const
    {
      materialize_transformation_products_buffer();
      return transformation_products_buffer_;
    }

    void PROJECT_NON_TARGET_ANALYSIS::load_processing_metadata()
    {
      mass_spec::PROJECT_MASS_SPEC project(ctx_);
      analyses_table_ = project.collect_analyses();
      spectra_headers_cache_.assign(analysis_names().size(), std::nullopt);
      feature_buffers_.clear();
      suspect_buffers_.clear();
      internal_standard_buffers_.clear();
      transformation_products_buffer_ = NTS_TRANSFORMATION_PRODUCTS();
      feature_buffers_ready_ = false;
      suspect_buffers_ready_ = false;
      internal_standard_buffers_ready_ = false;
      transformation_products_ready_ = false;
    }

    void PROJECT_NON_TARGET_ANALYSIS::load_processing_headers()
    {
      mass_spec::PROJECT_MASS_SPEC project(ctx_);
      spectra_headers_table_ = project.collect_spectra_headers(analysis_names());
      spectra_headers_cache_.assign(analysis_names().size(), std::nullopt);
    }

    void PROJECT_NON_TARGET_ANALYSIS::load_processing_features(bool include_filtered)
    {
      NTS_QUERY_REQUEST query;
      query.analyses = analysis_names();
      query.include_filtered = include_filtered;
      features_table_ = collect_features_table(query);
      feature_buffers_.clear();
      feature_buffers_ready_ = false;
    }

    void PROJECT_NON_TARGET_ANALYSIS::load_processing_suspects()
    {
      NTS_QUERY_REQUEST query;
      query.analyses = analysis_names();
      suspects_table_ = collect_suspects_table(query);
      suspect_buffers_.clear();
      suspect_buffers_ready_ = false;
    }

    void PROJECT_NON_TARGET_ANALYSIS::load_processing_internal_standards()
    {
      NTS_QUERY_REQUEST query;
      query.analyses = analysis_names();
      internal_standards_table_ = collect_internal_standards_table(query);
      internal_standard_buffers_.clear();
      internal_standard_buffers_ready_ = false;
    }

    void PROJECT_NON_TARGET_ANALYSIS::load_processing_transformation_products()
    {
      transformation_products_table_ = collect_transformation_products_table();
      transformation_products_buffer_ = NTS_TRANSFORMATION_PRODUCTS();
      transformation_products_ready_ = false;
    }

    void PROJECT_NON_TARGET_ANALYSIS::save_processing_features()
    {
      const auto &features = feature_buffers();
      features_table_ = NTS_FEATURES_TABLE();
      auto guard = mass_spec::api::connect_checked(ctx_);
      std::cout << "Saving features to duckdb... ";
      project::db::run_sql(guard.get(), "BEGIN TRANSACTION", "begin save NTS features transaction");
      try
      {
        project::db::run_prepared(
            guard.get(),
            "DELETE FROM NTS_FEATURES WHERE project_id = ?",
            "delete NTS features",
            [&](duckdb_prepared_statement statement)
            { duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str()); },
            [](duckdb_result &) {});

        for (const auto &feature_table : features)
        {
          for (int i = 0; i < feature_table.size(); ++i)
          {
            auto row = feature_table.get_feature(i);
            row.project_id = ctx_->project_id;
            features_table_.append(row);
            project::db::run_prepared(
                guard.get(),
                "INSERT INTO NTS_FEATURES (project_id, analysis, feature, feature_component, feature_group, adduct, rt, mz, mass, intensity, noise, sn, area, rtmin, rtmax, width, mzmin, mzmax, ppm, fwhm_rt, fwhm_mz, gaussian_A, gaussian_mu, gaussian_sigma, gaussian_r2, jaggedness, sharpness, asymmetry, modality, plates, polarity, filtered, filter, filled, correction, eic_size, eic_rt, eic_mz, eic_intensity, eic_baseline, eic_smoothed, ms1_size, ms1_mz, ms1_intensity, ms2_size, ms2_mz, ms2_intensity) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                "insert NTS feature",
                [&](duckdb_prepared_statement statement)
                {
                  duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str());
                  duckdb_bind_varchar(statement, 2, row.analysis.c_str());
                  duckdb_bind_varchar(statement, 3, row.feature.c_str());
                  project::db::bind_optional_varchar(statement, 4, row.feature_component);
                  project::db::bind_optional_varchar(statement, 5, row.feature_group);
                  project::db::bind_optional_varchar(statement, 6, row.adduct);
                  duckdb_bind_double(statement, 7, row.rt);
                  duckdb_bind_double(statement, 8, row.mz);
                  duckdb_bind_double(statement, 9, row.mass);
                  duckdb_bind_double(statement, 10, row.intensity);
                  duckdb_bind_double(statement, 11, row.noise);
                  duckdb_bind_double(statement, 12, row.sn);
                  duckdb_bind_double(statement, 13, row.area);
                  duckdb_bind_double(statement, 14, row.rtmin);
                  duckdb_bind_double(statement, 15, row.rtmax);
                  duckdb_bind_double(statement, 16, row.width);
                  duckdb_bind_double(statement, 17, row.mzmin);
                  duckdb_bind_double(statement, 18, row.mzmax);
                  duckdb_bind_double(statement, 19, row.ppm);
                  duckdb_bind_double(statement, 20, row.fwhm_rt);
                  duckdb_bind_double(statement, 21, row.fwhm_mz);
                  duckdb_bind_double(statement, 22, row.gaussian_A);
                  duckdb_bind_double(statement, 23, row.gaussian_mu);
                  duckdb_bind_double(statement, 24, row.gaussian_sigma);
                  duckdb_bind_double(statement, 25, row.gaussian_r2);
                  duckdb_bind_double(statement, 26, row.jaggedness);
                  duckdb_bind_double(statement, 27, row.sharpness);
                  duckdb_bind_double(statement, 28, row.asymmetry);
                  duckdb_bind_int32(statement, 29, row.modality);
                  duckdb_bind_double(statement, 30, row.plates);
                  duckdb_bind_int32(statement, 31, row.polarity);
                  duckdb_bind_boolean(statement, 32, row.filtered);
                  project::db::bind_optional_varchar(statement, 33, row.filter);
                  duckdb_bind_boolean(statement, 34, row.filled);
                  duckdb_bind_double(statement, 35, row.correction);
                  duckdb_bind_int32(statement, 36, row.eic_size);
                  project::db::bind_optional_varchar(statement, 37, row.eic_rt);
                  project::db::bind_optional_varchar(statement, 38, row.eic_mz);
                  project::db::bind_optional_varchar(statement, 39, row.eic_intensity);
                  project::db::bind_optional_varchar(statement, 40, row.eic_baseline);
                  project::db::bind_optional_varchar(statement, 41, row.eic_smoothed);
                  duckdb_bind_int32(statement, 42, row.ms1_size);
                  project::db::bind_optional_varchar(statement, 43, row.ms1_mz);
                  project::db::bind_optional_varchar(statement, 44, row.ms1_intensity);
                  duckdb_bind_int32(statement, 45, row.ms2_size);
                  project::db::bind_optional_varchar(statement, 46, row.ms2_mz);
                  project::db::bind_optional_varchar(statement, 47, row.ms2_intensity);
                },
                [](duckdb_result &) {});
          }
        }

        project::db::run_sql(guard.get(), "COMMIT", "commit save NTS features transaction");
        std::cout << "Done!" << std::endl;
      }
      catch (...)
      {
        try
        {
          project::db::run_sql(guard.get(), "ROLLBACK", "rollback save NTS features transaction");
        }
        catch (...)
        {
        }
        throw;
      }
    }

    void PROJECT_NON_TARGET_ANALYSIS::save_processing_suspects()
    {
      const auto &suspects = suspect_buffers();
      suspects_table_ = NTS_SUSPECTS_TABLE();
      auto guard = mass_spec::api::connect_checked(ctx_);
      std::cout << "Saving suspects to duckdb... ";
      project::db::run_sql(guard.get(), "BEGIN TRANSACTION", "begin save NTS suspects transaction");
      try
      {
        project::db::run_prepared(
            guard.get(),
            "DELETE FROM NTS_SUSPECTS WHERE project_id = ?",
            "delete NTS suspects",
            [&](duckdb_prepared_statement statement)
            { duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str()); },
            [](duckdb_result &) {});

        for (const auto &suspect_table : suspects)
        {
          for (int i = 0; i < suspect_table.size(); ++i)
          {
            auto row = suspect_table.get_suspect(i);
            row.project_id = ctx_->project_id;
            suspects_table_.append(row);
            project::db::run_prepared(
                guard.get(),
                "INSERT INTO NTS_SUSPECTS (project_id, analysis, feature, candidate_rank, name, polarity, db_mass, exp_mass, error_mass, db_rt, exp_rt, error_rt, intensity, area, id_level, score, shared_fragments, cosine_similarity, formula, SMILES, InChI, InChIKey, xLogP, database_id, db_ms2_size, db_ms2_mz, db_ms2_intensity, db_ms2_formula, exp_ms2_size, exp_ms2_mz, exp_ms2_intensity) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                "insert NTS suspect",
                [&](duckdb_prepared_statement statement)
                {
                  duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str());
                  duckdb_bind_varchar(statement, 2, row.analysis.c_str());
                  duckdb_bind_varchar(statement, 3, row.feature.c_str());
                  duckdb_bind_int32(statement, 4, row.candidate_rank);
                  duckdb_bind_varchar(statement, 5, row.name.c_str());
                  duckdb_bind_int32(statement, 6, row.polarity);
                  duckdb_bind_double(statement, 7, row.db_mass);
                  duckdb_bind_double(statement, 8, row.exp_mass);
                  duckdb_bind_double(statement, 9, row.error_mass);
                  duckdb_bind_double(statement, 10, row.db_rt);
                  duckdb_bind_double(statement, 11, row.exp_rt);
                  duckdb_bind_double(statement, 12, row.error_rt);
                  duckdb_bind_double(statement, 13, row.intensity);
                  duckdb_bind_double(statement, 14, row.area);
                  duckdb_bind_int32(statement, 15, row.id_level);
                  duckdb_bind_double(statement, 16, row.score);
                  duckdb_bind_int32(statement, 17, row.shared_fragments);
                  duckdb_bind_double(statement, 18, row.cosine_similarity);
                  project::db::bind_optional_varchar(statement, 19, row.formula);
                  project::db::bind_optional_varchar(statement, 20, row.SMILES);
                  project::db::bind_optional_varchar(statement, 21, row.InChI);
                  project::db::bind_optional_varchar(statement, 22, row.InChIKey);
                  duckdb_bind_double(statement, 23, row.xLogP);
                  project::db::bind_optional_varchar(statement, 24, row.database_id);
                  duckdb_bind_int32(statement, 25, row.db_ms2_size);
                  project::db::bind_optional_varchar(statement, 26, row.db_ms2_mz);
                  project::db::bind_optional_varchar(statement, 27, row.db_ms2_intensity);
                  project::db::bind_optional_varchar(statement, 28, row.db_ms2_formula);
                  duckdb_bind_int32(statement, 29, row.exp_ms2_size);
                  project::db::bind_optional_varchar(statement, 30, row.exp_ms2_mz);
                  project::db::bind_optional_varchar(statement, 31, row.exp_ms2_intensity);
                },
                [](duckdb_result &) {});
          }
        }

        project::db::run_sql(guard.get(), "COMMIT", "commit save NTS suspects transaction");
        std::cout << "Done!" << std::endl;
      }
      catch (...)
      {
        try
        {
          project::db::run_sql(guard.get(), "ROLLBACK", "rollback save NTS suspects transaction");
        }
        catch (...)
        {
        }
        throw;
      }
    }

    void PROJECT_NON_TARGET_ANALYSIS::save_processing_internal_standards()
    {
      const auto &internal_standards = internal_standard_buffers();
      internal_standards_table_ = NTS_INTERNAL_STANDARDS_TABLE();
      auto guard = mass_spec::api::connect_checked(ctx_);
      std::cout << "Saving internal standards to duckdb... ";
      project::db::run_sql(guard.get(), "BEGIN TRANSACTION", "begin save NTS internal standards transaction");
      try
      {
        project::db::run_prepared(
            guard.get(),
            "DELETE FROM NTS_INTERNAL_STANDARDS WHERE project_id = ?",
            "delete NTS internal standards",
            [&](duckdb_prepared_statement statement)
            { duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str()); },
            [](duckdb_result &) {});

        for (const auto &internal_table : internal_standards)
        {
          for (int i = 0; i < internal_table.size(); ++i)
          {
            auto row = internal_table.get_internal_standard(i);
            row.project_id = ctx_->project_id;
            internal_standards_table_.append(row);
            project::db::run_prepared(
                guard.get(),
                "INSERT INTO NTS_INTERNAL_STANDARDS (project_id, analysis, feature, candidate_rank, name, polarity, db_mass, exp_mass, error_mass, db_rt, exp_rt, error_rt, intensity, area, id_level, score, shared_fragments, cosine_similarity, formula, SMILES, InChI, InChIKey, xLogP, database_id, db_ms2_size, db_ms2_mz, db_ms2_intensity, db_ms2_formula, exp_ms2_size, exp_ms2_mz, exp_ms2_intensity) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                "insert NTS internal standard",
                [&](duckdb_prepared_statement statement)
                {
                  duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str());
                  duckdb_bind_varchar(statement, 2, row.analysis.c_str());
                  duckdb_bind_varchar(statement, 3, row.feature.c_str());
                  duckdb_bind_int32(statement, 4, row.candidate_rank);
                  duckdb_bind_varchar(statement, 5, row.name.c_str());
                  duckdb_bind_int32(statement, 6, row.polarity);
                  duckdb_bind_double(statement, 7, row.db_mass);
                  duckdb_bind_double(statement, 8, row.exp_mass);
                  duckdb_bind_double(statement, 9, row.error_mass);
                  duckdb_bind_double(statement, 10, row.db_rt);
                  duckdb_bind_double(statement, 11, row.exp_rt);
                  duckdb_bind_double(statement, 12, row.error_rt);
                  duckdb_bind_double(statement, 13, row.intensity);
                  duckdb_bind_double(statement, 14, row.area);
                  duckdb_bind_int32(statement, 15, row.id_level);
                  duckdb_bind_double(statement, 16, row.score);
                  duckdb_bind_int32(statement, 17, row.shared_fragments);
                  duckdb_bind_double(statement, 18, row.cosine_similarity);
                  project::db::bind_optional_varchar(statement, 19, row.formula);
                  project::db::bind_optional_varchar(statement, 20, row.SMILES);
                  project::db::bind_optional_varchar(statement, 21, row.InChI);
                  project::db::bind_optional_varchar(statement, 22, row.InChIKey);
                  duckdb_bind_double(statement, 23, row.xLogP);
                  project::db::bind_optional_varchar(statement, 24, row.database_id);
                  duckdb_bind_int32(statement, 25, row.db_ms2_size);
                  project::db::bind_optional_varchar(statement, 26, row.db_ms2_mz);
                  project::db::bind_optional_varchar(statement, 27, row.db_ms2_intensity);
                  project::db::bind_optional_varchar(statement, 28, row.db_ms2_formula);
                  duckdb_bind_int32(statement, 29, row.exp_ms2_size);
                  project::db::bind_optional_varchar(statement, 30, row.exp_ms2_mz);
                  project::db::bind_optional_varchar(statement, 31, row.exp_ms2_intensity);
                },
                [](duckdb_result &) {});
          }
        }

        project::db::run_sql(guard.get(), "COMMIT", "commit save NTS internal standards transaction");
        std::cout << "Done!" << std::endl;
      }
      catch (...)
      {
        try
        {
          project::db::run_sql(guard.get(), "ROLLBACK", "rollback save NTS internal standards transaction");
        }
        catch (...)
        {
        }
        throw;
      }
    }

    std::string PROJECT_NON_TARGET_ANALYSIS::build_processing_cache_key(
        const std::string &step,
        const std::string &args_key,
        const std::vector<std::string> &dependency_keys) const
    {
      std::ostringstream payload;
      payload << "project=" << ctx_->project_id
              << "|step=" << step
              << "|args=" << args_key
              << "|analyses=" << bytes_to_hex(analyses_table_.serialize_object());
      for (const auto &dependency_key : dependency_keys)
      {
        payload << "|dep=" << dependency_key;
      }
      return std::string("nts|") + step + "|" + stable_hash_hex(payload.str());
    }

    NTS_FEATURES_CACHE PROJECT_NON_TARGET_ANALYSIS::feature_cache_snapshot() const
    {
      return NTS_FEATURES_CACHE{feature_buffers()};
    }

    NTS_SUSPECTS_CACHE PROJECT_NON_TARGET_ANALYSIS::suspect_cache_snapshot() const
    {
      return NTS_SUSPECTS_CACHE{suspect_buffers()};
    }

    NTS_INTERNAL_STANDARDS_CACHE PROJECT_NON_TARGET_ANALYSIS::internal_standard_cache_snapshot() const
    {
      return NTS_INTERNAL_STANDARDS_CACHE{internal_standard_buffers()};
    }

    std::string PROJECT_NON_TARGET_ANALYSIS::feature_state_cache_key() const
    {
      return stable_hash_hex(bytes_to_hex(feature_cache_snapshot().serialize_object()));
    }

    std::string PROJECT_NON_TARGET_ANALYSIS::suspect_state_cache_key() const
    {
      return stable_hash_hex(bytes_to_hex(suspect_cache_snapshot().serialize_object()));
    }

    std::string PROJECT_NON_TARGET_ANALYSIS::internal_standard_state_cache_key() const
    {
      return stable_hash_hex(bytes_to_hex(internal_standard_cache_snapshot().serialize_object()));
    }

    bool PROJECT_NON_TARGET_ANALYSIS::restore_feature_cache(const std::string &hash)
    {
      project::cache::CACHE cache(ctx_);
      const auto cached = cache.get_object<NTS_FEATURES_CACHE>(hash);
      if (!cached.has_value())
      {
        return false;
      }
      std::cout << "Loading features from cache... ";
      feature_buffers_ = cached->buffers;
      feature_buffers_ready_ = true;
      std::cout << "Done!" << std::endl;
      save_processing_features();
      return true;
    }

    bool PROJECT_NON_TARGET_ANALYSIS::restore_suspect_cache(const std::string &hash)
    {
      project::cache::CACHE cache(ctx_);
      const auto cached = cache.get_object<NTS_SUSPECTS_CACHE>(hash);
      if (!cached.has_value())
      {
        return false;
      }
      std::cout << "Loading suspects from cache... ";
      suspect_buffers_ = cached->buffers;
      suspect_buffers_ready_ = true;
      save_processing_suspects();
      return true;
    }

    bool PROJECT_NON_TARGET_ANALYSIS::restore_internal_standard_cache(const std::string &hash)
    {
      project::cache::CACHE cache(ctx_);
      const auto cached = cache.get_object<NTS_INTERNAL_STANDARDS_CACHE>(hash);
      if (!cached.has_value())
      {
        return false;
      }
      std::cout << "Loading internal standards from cache... ";
      internal_standard_buffers_ = cached->buffers;
      internal_standard_buffers_ready_ = true;
      save_processing_internal_standards();
      return true;
    }

    bool PROJECT_NON_TARGET_ANALYSIS::restore_transformation_products_cache(const std::string &hash)
    {
      project::cache::CACHE cache(ctx_);
      const auto cached = cache.get_object<NTS_TRANSFORMATION_PRODUCTS>(hash);
      if (!cached.has_value())
      {
        return false;
      }
      std::cout << "Loading transformation products from cache... ";
      transformation_products_buffer_ = *cached;
      transformation_products_ready_ = true;
      save_processing_transformation_products(*cached);
      return true;
    }

    void PROJECT_NON_TARGET_ANALYSIS::store_feature_cache(const std::string &hash, const std::string &description)
    {
      std::cout << "Caching features... ";
      project::cache::CACHE(ctx_).put_object("NTS_FEATURES_CACHE", hash, description, feature_cache_snapshot());
      std::cout << "Done!" << std::endl;
    }

    void PROJECT_NON_TARGET_ANALYSIS::store_suspect_cache(const std::string &hash, const std::string &description)
    {
      std::cout << "Caching suspects... ";
      project::cache::CACHE(ctx_).put_object("NTS_SUSPECTS_CACHE", hash, description, suspect_cache_snapshot());
      std::cout << "Done!" << std::endl;
    }

    void PROJECT_NON_TARGET_ANALYSIS::store_internal_standard_cache(const std::string &hash, const std::string &description)
    {
      std::cout << "Caching internal standards... ";
      project::cache::CACHE(ctx_).put_object("NTS_INTERNAL_STANDARDS_CACHE", hash, description, internal_standard_cache_snapshot());
      std::cout << "Done!" << std::endl;
    }

    void PROJECT_NON_TARGET_ANALYSIS::store_transformation_products_cache(
        const std::string &hash,
        const std::string &description,
        const NTS_TRANSFORMATION_PRODUCTS &products)
    {
      std::cout << "Caching transformation products... ";
      project::cache::CACHE(ctx_).put_object("NTS_TRANSFORMATION_PRODUCTS", hash, description, products);
      std::cout << "Done!" << std::endl;
    }

    bool PROJECT_NON_TARGET_ANALYSIS::run_cached_features_algorithm(
        const std::string &step,
        const std::string &args_key,
        const std::vector<std::string> &dependency_keys,
        const std::string &description,
        const std::function<void()> &algorithm)
    {
      try
      {
        const auto cache_key = build_processing_cache_key(step, args_key, dependency_keys);
        if (restore_feature_cache(cache_key))
        {
          return true;
        }
        algorithm();
        save_processing_features();
        store_feature_cache(cache_key, description);
        return true;
      }
      catch (...)
      {
        return false;
      }
    }

    bool PROJECT_NON_TARGET_ANALYSIS::run_cached_suspects_algorithm(
        const std::string &step,
        const std::string &args_key,
        const std::vector<std::string> &dependency_keys,
        const std::string &description,
        const std::function<void()> &algorithm)
    {
      try
      {
        const auto cache_key = build_processing_cache_key(step, args_key, dependency_keys);
        if (restore_suspect_cache(cache_key))
        {
          return true;
        }
        algorithm();
        save_processing_suspects();
        store_suspect_cache(cache_key, description);
        return true;
      }
      catch (...)
      {
        return false;
      }
    }

    bool PROJECT_NON_TARGET_ANALYSIS::run_cached_internal_standards_algorithm(
        const std::string &step,
        const std::string &args_key,
        const std::vector<std::string> &dependency_keys,
        const std::string &description,
        const std::function<void()> &algorithm)
    {
      try
      {
        const auto cache_key = build_processing_cache_key(step, args_key, dependency_keys);
        if (restore_internal_standard_cache(cache_key))
        {
          return true;
        }
        algorithm();
        save_processing_internal_standards();
        store_internal_standard_cache(cache_key, description);
        return true;
      }
      catch (...)
      {
        return false;
      }
    }

    bool PROJECT_NON_TARGET_ANALYSIS::run_cached_transformation_products_algorithm(
        const std::string &step,
        const std::string &args_key,
        const std::vector<std::string> &dependency_keys,
        const std::string &description,
      const std::function<NTS_TRANSFORMATION_PRODUCTS()> &algorithm)
    {
      try
      {
        const auto cache_key = build_processing_cache_key(step, args_key, dependency_keys);
        if (restore_transformation_products_cache(cache_key))
        {
          return true;
        }
        const auto products = algorithm();
        save_processing_transformation_products(products);
        store_transformation_products_cache(cache_key, description, products);
        return true;
      }
      catch (...)
      {
        return false;
      }
    }

    void PROJECT_NON_TARGET_ANALYSIS::save_processing_transformation_products(
        const NTS_TRANSFORMATION_PRODUCTS &products)
    {
      transformation_products_table_ = NTS_TRANSFORMATION_PRODUCTS_TABLE();
      transformation_products_buffer_ = products;
      transformation_products_ready_ = true;
      auto guard = mass_spec::api::connect_checked(ctx_);
      std::cout << "Saving transformation products to duckdb... ";
      project::db::run_sql(guard.get(), "BEGIN TRANSACTION", "begin save NTS transformation products transaction");
      try
      {
        project::db::run_prepared(
            guard.get(),
            "DELETE FROM NTS_TRANSFORMATION_PRODUCTS WHERE project_id = ?",
            "delete NTS transformation products",
            [&](duckdb_prepared_statement statement)
            { duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str()); },
            [](duckdb_result &) {});

        for (int i = 0; i < products.size(); ++i)
        {
          auto row = products.get_transformation_product(i);
          row.project_id = ctx_->project_id;
          transformation_products_table_.append(row);
          project::db::run_prepared(
              guard.get(),
              "INSERT INTO NTS_TRANSFORMATION_PRODUCTS (project_id, name, formula, mass, SMILES, InChI, InChIKey, xLogP, transformation, precursor_name, precursor_formula, precursor_mass, precursor_SMILES, precursor_InChI, precursor_InChIKey, precursor_xLogP, main_precursor_name, main_precursor_formula, main_precursor_mass, main_precursor_SMILES, main_precursor_InChI, main_precursor_InChIKey, main_precursor_xLogP, feature_group, precursor_feature_group, main_precursor_feature_group, cosine_similarity, main_precursor_cosine_similarity, rt_plausibility, main_precursor_rt_plausibility) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
              "insert NTS transformation product",
              [&](duckdb_prepared_statement statement)
              {
                duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str());
                project::db::bind_optional_varchar(statement, 2, row.name);
                project::db::bind_optional_varchar(statement, 3, row.formula);
                duckdb_bind_double(statement, 4, row.mass);
                project::db::bind_optional_varchar(statement, 5, row.SMILES);
                project::db::bind_optional_varchar(statement, 6, row.InChI);
                project::db::bind_optional_varchar(statement, 7, row.InChIKey);
                duckdb_bind_double(statement, 8, row.xLogP);
                project::db::bind_optional_varchar(statement, 9, row.transformation);
                project::db::bind_optional_varchar(statement, 10, row.precursor_name);
                project::db::bind_optional_varchar(statement, 11, row.precursor_formula);
                duckdb_bind_double(statement, 12, row.precursor_mass);
                project::db::bind_optional_varchar(statement, 13, row.precursor_SMILES);
                project::db::bind_optional_varchar(statement, 14, row.precursor_InChI);
                project::db::bind_optional_varchar(statement, 15, row.precursor_InChIKey);
                duckdb_bind_double(statement, 16, row.precursor_xLogP);
                project::db::bind_optional_varchar(statement, 17, row.main_precursor_name);
                project::db::bind_optional_varchar(statement, 18, row.main_precursor_formula);
                duckdb_bind_double(statement, 19, row.main_precursor_mass);
                project::db::bind_optional_varchar(statement, 20, row.main_precursor_SMILES);
                project::db::bind_optional_varchar(statement, 21, row.main_precursor_InChI);
                project::db::bind_optional_varchar(statement, 22, row.main_precursor_InChIKey);
                duckdb_bind_double(statement, 23, row.main_precursor_xLogP);
                project::db::bind_optional_varchar(statement, 24, row.feature_group);
                project::db::bind_optional_varchar(statement, 25, row.precursor_feature_group);
                project::db::bind_optional_varchar(statement, 26, row.main_precursor_feature_group);
                duckdb_bind_double(statement, 27, row.cosine_similarity);
                duckdb_bind_double(statement, 28, row.main_precursor_cosine_similarity);
                duckdb_bind_double(statement, 29, row.rt_plausibility);
                duckdb_bind_double(statement, 30, row.main_precursor_rt_plausibility);
              },
              [](duckdb_result &) {});
        }

        project::db::run_sql(guard.get(), "COMMIT", "commit save NTS transformation products transaction");
        std::cout << "Done!" << std::endl;
      }
      catch (...)
      {
        try
        {
          project::db::run_sql(guard.get(), "ROLLBACK", "rollback save NTS transformation products transaction");
        }
        catch (...)
        {
        }
        throw;
      }
    }

    bool PROJECT_NON_TARGET_ANALYSIS::find_features(
        const std::vector<float> &rtWindowsMin,
        const std::vector<float> &rtWindowsMax,
        const float &ppmThreshold,
        const float &noiseThreshold,
        const float &minSNR,
        const int &minTraces,
        const float &baselineWindow,
        const float &maxWidth,
        const float &baseQuantile,
        const std::string &debugAnalysis,
        const float &debugMZ,
        const int &debugSpecIdx)
    {
      load_processing_metadata();
      load_processing_headers();
      return run_cached_features_algorithm(
          "find_features",
          cache_join_key({cache_vector_key(rtWindowsMin), cache_vector_key(rtWindowsMax), cache_scalar_key(ppmThreshold), cache_scalar_key(noiseThreshold), cache_scalar_key(minSNR), cache_scalar_key(minTraces), cache_scalar_key(baselineWindow), cache_scalar_key(maxWidth), cache_scalar_key(baseQuantile), debugAnalysis, cache_scalar_key(debugMZ), cache_scalar_key(debugSpecIdx)}),
          {},
          "Cached NTS features for find_features",
          [&]() {
            features_table_ = NTS_FEATURES_TABLE();
            feature_buffers_.assign(analysis_names().size(), NTS_FEATURES());
            for (std::size_t i = 0; i < analysis_names().size(); ++i)
            {
              feature_buffers_[i].set_analysis(analysis_names()[i]);
            }
            feature_buffers_ready_ = true;
            deconvolution::find_features_impl(*this, rtWindowsMin, rtWindowsMax, ppmThreshold, noiseThreshold, minSNR, minTraces, baselineWindow, maxWidth, baseQuantile, debugAnalysis, debugMZ, debugSpecIdx);
          });
    }

    bool PROJECT_NON_TARGET_ANALYSIS::create_components(const std::vector<float> &rtWindow, float minCorrelation, float debugRT, const std::string &debugAnalysis)
    {
      load_processing_metadata();
      load_processing_features(true);
      return run_cached_features_algorithm(
          "create_components",
          cache_join_key({cache_vector_key(rtWindow), cache_scalar_key(minCorrelation), cache_scalar_key(debugRT), debugAnalysis}),
          {feature_state_cache_key()},
          "Cached NTS features for create_components",
          [&]() { componentization::create_components_impl(*this, rtWindow, minCorrelation, debugRT, debugAnalysis); });
    }

    bool PROJECT_NON_TARGET_ANALYSIS::annotate_components(int maxIsotopes, int maxCharge, int maxGaps, float ppm, const std::string &debugComponent, const std::string &debugAnalysis)
    {
      load_processing_metadata();
      load_processing_features(true);
      return run_cached_features_algorithm(
          "annotate_components",
          cache_join_key({cache_scalar_key(maxIsotopes), cache_scalar_key(maxCharge), cache_scalar_key(maxGaps), cache_scalar_key(ppm), debugComponent, debugAnalysis}),
          {feature_state_cache_key()},
          "Cached NTS features for annotate_components",
          [&]() { annotation::annotate_components_impl(*this, maxIsotopes, maxCharge, maxGaps, ppm, debugComponent, debugAnalysis); });
    }

    bool PROJECT_NON_TARGET_ANALYSIS::group_features(const std::string &method, float rtDeviation, float ppm, int minSamples, float binSize, bool debug, float debugRT)
    {
      load_processing_metadata();
      load_processing_features(true);
      std::vector<std::string> dependencies{feature_state_cache_key()};
      if (method == "internal_standards")
      {
        load_processing_internal_standards();
        dependencies.push_back(internal_standard_state_cache_key());
      }
      else
      {
        internal_standards_table_ = NTS_INTERNAL_STANDARDS_TABLE();
        internal_standard_buffers_.assign(analysis_names().size(), NTS_INTERNAL_STANDARDS());
        internal_standard_buffers_ready_ = true;
      }
      return run_cached_features_algorithm(
          "group_features",
          cache_join_key({method, cache_scalar_key(rtDeviation), cache_scalar_key(ppm), cache_scalar_key(minSamples), cache_scalar_key(binSize), cache_bool_key(debug), cache_scalar_key(debugRT)}),
          dependencies,
          "Cached NTS features for group_features",
          [&]() { alignment::group_features_impl(*this, method, rtDeviation, ppm, minSamples, binSize, debug, debugRT); });
    }

    bool PROJECT_NON_TARGET_ANALYSIS::fill_features(bool withinReplicate, bool filtered, float rtExpand, float mzExpand, float maxPeakWidth, float minTracesIntensity, int minNumberTraces, float minIntensity, float rtApexDeviation, float minSignalToNoiseRatio, float minGaussianFit, std::string debugFG)
    {
      load_processing_metadata();
      load_processing_headers();
      load_processing_features(true);
      return run_cached_features_algorithm(
          "fill_features",
          cache_join_key({cache_bool_key(withinReplicate), cache_bool_key(filtered), cache_scalar_key(rtExpand), cache_scalar_key(mzExpand), cache_scalar_key(maxPeakWidth), cache_scalar_key(minTracesIntensity), cache_scalar_key(minNumberTraces), cache_scalar_key(minIntensity), cache_scalar_key(rtApexDeviation), cache_scalar_key(minSignalToNoiseRatio), cache_scalar_key(minGaussianFit), debugFG}),
          {feature_state_cache_key()},
          "Cached NTS features for fill_features",
          [&]() { gap_filling::fill_features_impl(*this, withinReplicate, filtered, rtExpand, mzExpand, maxPeakWidth, minTracesIntensity, minNumberTraces, minIntensity, rtApexDeviation, minSignalToNoiseRatio, minGaussianFit, debugFG); });
    }

    bool PROJECT_NON_TARGET_ANALYSIS::subtract_blank(float blankThreshold, float rtExpand, float mzExpand, float minTracesIntensity)
    {
      load_processing_metadata();
      load_processing_headers();
      load_processing_features(true);
      return run_cached_features_algorithm(
          "subtract_blank",
          cache_join_key({cache_scalar_key(blankThreshold), cache_scalar_key(rtExpand), cache_scalar_key(mzExpand), cache_scalar_key(minTracesIntensity)}),
          {feature_state_cache_key()},
          "Cached NTS features for subtract_blank",
          [&]() { blank_subtraction::subtract_blank_impl(*this, blankThreshold, rtExpand, mzExpand, minTracesIntensity); });
    }

    bool PROJECT_NON_TARGET_ANALYSIS::filter_features(double minSN, double minIntensity, double minArea, double minWidth, double maxWidth, double maxPPM, double minFwhmRT, double maxFwhmRT, double minFwhmMZ, double maxFwhmMZ, double minGaussianA, double minGaussianMu, double maxGaussianMu, double minGaussianSigma, double maxGaussianSigma, double minGaussianR2, double maxJaggedness, double minSharpness, double minAsymmetry, double maxAsymmetry, int maxModality, bool hasMaxModality, double minPlates, bool hasOnlyFilled, bool onlyFilledValue, bool removeFilled, int minSizeEIC, bool hasMinSizeEIC, int minSizeMS1, bool hasMinSizeMS1, int minSizeMS2, bool hasMinSizeMS2, double minRelPresenceReplicate, bool removeIsotopes, bool removeAdducts, bool removeLosses)
    {
      load_processing_metadata();
      load_processing_features(true);
      return run_cached_features_algorithm(
          "filter_features",
          cache_join_key({cache_scalar_key(minSN), cache_scalar_key(minIntensity), cache_scalar_key(minArea), cache_scalar_key(minWidth), cache_scalar_key(maxWidth), cache_scalar_key(maxPPM), cache_scalar_key(minFwhmRT), cache_scalar_key(maxFwhmRT), cache_scalar_key(minFwhmMZ), cache_scalar_key(maxFwhmMZ), cache_scalar_key(minGaussianA), cache_scalar_key(minGaussianMu), cache_scalar_key(maxGaussianMu), cache_scalar_key(minGaussianSigma), cache_scalar_key(maxGaussianSigma), cache_scalar_key(minGaussianR2), cache_scalar_key(maxJaggedness), cache_scalar_key(minSharpness), cache_scalar_key(minAsymmetry), cache_scalar_key(maxAsymmetry), cache_scalar_key(maxModality), cache_bool_key(hasMaxModality), cache_scalar_key(minPlates), cache_bool_key(hasOnlyFilled), cache_bool_key(onlyFilledValue), cache_bool_key(removeFilled), cache_scalar_key(minSizeEIC), cache_bool_key(hasMinSizeEIC), cache_scalar_key(minSizeMS1), cache_bool_key(hasMinSizeMS1), cache_scalar_key(minSizeMS2), cache_bool_key(hasMinSizeMS2), cache_scalar_key(minRelPresenceReplicate), cache_bool_key(removeIsotopes), cache_bool_key(removeAdducts), cache_bool_key(removeLosses)}),
          {feature_state_cache_key()},
          "Cached NTS features for filter_features",
          [&]() { filter_features::filter_features_impl(*this, minSN, minIntensity, minArea, minWidth, maxWidth, maxPPM, minFwhmRT, maxFwhmRT, minFwhmMZ, maxFwhmMZ, minGaussianA, minGaussianMu, maxGaussianMu, minGaussianSigma, maxGaussianSigma, minGaussianR2, maxJaggedness, minSharpness, minAsymmetry, maxAsymmetry, maxModality, hasMaxModality, minPlates, hasOnlyFilled, onlyFilledValue, removeFilled, minSizeEIC, hasMinSizeEIC, minSizeMS1, hasMinSizeMS1, minSizeMS2, hasMinSizeMS2, minRelPresenceReplicate, removeIsotopes, removeAdducts, removeLosses); });
    }

    bool PROJECT_NON_TARGET_ANALYSIS::suspect_screening(const std::vector<std::string> &analyses, const std::vector<suspect_screening::SuspectQuery> &suspects, double ppm, double sec, double ppmMS2, double mzrMS2, double minCosineSimilarity, int minSharedFragments, bool filtered)
    {
      load_processing_metadata();
      load_processing_features(true);
      load_processing_suspects();
      std::vector<std::string> suspect_keys;
      suspect_keys.reserve(suspects.size());
      for (const auto &suspect : suspects)
      {
        suspect_keys.push_back(cache_join_key({suspect.name, cache_bool_key(suspect.has_mass), cache_scalar_key(suspect.mass), cache_scalar_key(suspect.rt), suspect.formula, suspect.SMILES, suspect.InChI, suspect.InChIKey, cache_scalar_key(suspect.score), cache_bool_key(suspect.has_xLogP), cache_scalar_key(suspect.xLogP), suspect.database_id, cache_vector_key(suspect.fragments_mz_pos), cache_vector_key(suspect.fragments_intensity_pos), cache_vector_key(suspect.fragments_mz_neg), cache_vector_key(suspect.fragments_intensity_neg)}));
      }
      return run_cached_suspects_algorithm(
          "suspect_screening",
          cache_join_key({cache_vector_key(analyses), cache_scalar_key(ppm), cache_scalar_key(sec), cache_scalar_key(ppmMS2), cache_scalar_key(mzrMS2), cache_scalar_key(minCosineSimilarity), cache_scalar_key(minSharedFragments), cache_bool_key(filtered), cache_join_key(suspect_keys)}),
          {feature_state_cache_key(), suspect_state_cache_key()},
          "Cached NTS suspects for suspect_screening",
          [&]() { suspect_screening::suspect_screening_impl(*this, analyses, suspects, ppm, sec, ppmMS2, mzrMS2, minCosineSimilarity, minSharedFragments, filtered); });
    }

    bool PROJECT_NON_TARGET_ANALYSIS::filter_suspects(const std::vector<std::string> &names, double minScore, double maxErrorRT, double maxErrorMass, const std::vector<int> &idLevels, int minSharedFragments, double minCosineSimilarity)
    {
      load_processing_metadata();
      load_processing_suspects();
      return run_cached_suspects_algorithm(
          "filter_suspects",
          cache_join_key({cache_vector_key(names), cache_scalar_key(minScore), cache_scalar_key(maxErrorRT), cache_scalar_key(maxErrorMass), cache_vector_key(idLevels), cache_scalar_key(minSharedFragments), cache_scalar_key(minCosineSimilarity)}),
          {suspect_state_cache_key()},
          "Cached NTS suspects for filter_suspects",
          [&]() { filter_suspects::filter_suspects_impl(*this, names, minScore, maxErrorRT, maxErrorMass, idLevels, minSharedFragments, minCosineSimilarity); });
    }

    bool PROJECT_NON_TARGET_ANALYSIS::filter_internal_standards(const std::vector<std::string> &names, double minScore, double maxErrorRT, double maxErrorMass, const std::vector<int> &idLevels, int minSharedFragments, double minCosineSimilarity)
    {
      load_processing_metadata();
      load_processing_internal_standards();
      return run_cached_internal_standards_algorithm(
          "filter_internal_standards",
          cache_join_key({cache_vector_key(names), cache_scalar_key(minScore), cache_scalar_key(maxErrorRT), cache_scalar_key(maxErrorMass), cache_vector_key(idLevels), cache_scalar_key(minSharedFragments), cache_scalar_key(minCosineSimilarity)}),
          {internal_standard_state_cache_key()},
          "Cached NTS internal standards for filter_internal_standards",
          [&]() { filter_internal_standards::filter_internal_standards_impl(*this, names, minScore, maxErrorRT, maxErrorMass, idLevels, minSharedFragments, minCosineSimilarity); });
    }

    bool PROJECT_NON_TARGET_ANALYSIS::filter_features_ms2(int top, float minIntensity, float relMinIntensity, bool blankClean, float mzClust, float blankPresenceThreshold, float globalPresenceThreshold)
    {
      load_processing_metadata();
      load_processing_features(true);
      return run_cached_features_algorithm(
          "filter_features_ms2",
          cache_join_key({cache_scalar_key(top), cache_scalar_key(minIntensity), cache_scalar_key(relMinIntensity), cache_bool_key(blankClean), cache_scalar_key(mzClust), cache_scalar_key(blankPresenceThreshold), cache_scalar_key(globalPresenceThreshold)}),
          {feature_state_cache_key()},
          "Cached NTS features for filter_features_ms2",
          [&]() { filter_features_ms2::filter_features_ms2_impl(*this, top, minIntensity, relMinIntensity, blankClean, mzClust, blankPresenceThreshold, globalPresenceThreshold); });
    }

    bool PROJECT_NON_TARGET_ANALYSIS::metfrag_screening(const std::vector<std::string> &analyses, const metfrag_runner::MetFragParams &params)
    {
      load_processing_metadata();
      load_processing_features(true);
      load_processing_suspects();
      std::vector<std::string> extra_params;
      extra_params.reserve(params.extra_params.size());
      for (const auto &entry : params.extra_params)
      {
        extra_params.push_back(cache_join_key({entry.first, entry.second}));
      }
      return run_cached_suspects_algorithm(
          "metfrag_screening",
          cache_join_key({cache_vector_key(analyses), params.metfrag_path, params.database_type, params.database_path, cache_scalar_key(params.ppm), cache_scalar_key(params.sec), cache_scalar_key(params.ppmMS2), cache_scalar_key(params.mzrMS2), cache_scalar_key(params.top_n), cache_bool_key(params.filtered), params.java_path, params.run_dir, cache_bool_key(params.debug), cache_join_key(extra_params)}),
          {feature_state_cache_key(), suspect_state_cache_key()},
          "Cached NTS suspects for metfrag_screening",
          [&]() { metfrag_runner::metfrag_screening_impl(*this, analyses, params); });
    }

    bool PROJECT_NON_TARGET_ANALYSIS::assign_transformation_products(const std::vector<NTS_TRANSFORMATION_PRODUCT_ROW> &transformation_products, const std::string &chromatographic_phase, double mzrMS2)
    {
      load_processing_metadata();
      load_processing_features(true);
      load_processing_suspects();
      std::vector<std::string> input_rows;
      input_rows.reserve(transformation_products.size());
      for (const auto &row : transformation_products)
      {
        input_rows.push_back(cache_join_key({row.name, row.formula, cache_scalar_key(row.mass), row.SMILES, row.InChI, row.InChIKey, cache_scalar_key(row.xLogP), row.transformation, row.precursor_name, row.precursor_formula, cache_scalar_key(row.precursor_mass), row.precursor_SMILES, row.precursor_InChI, row.precursor_InChIKey, cache_scalar_key(row.precursor_xLogP), row.main_precursor_name, row.main_precursor_formula, cache_scalar_key(row.main_precursor_mass), row.main_precursor_SMILES, row.main_precursor_InChI, row.main_precursor_InChIKey, cache_scalar_key(row.main_precursor_xLogP)}));
      }
      return run_cached_transformation_products_algorithm(
          "assign_transformation_products",
          cache_join_key({chromatographic_phase, cache_scalar_key(mzrMS2), cache_join_key(input_rows)}),
          {feature_state_cache_key(), suspect_state_cache_key()},
          "Cached NTS transformation products for assign_transformation_products",
          [&]() {
            NTS_QUERY_REQUEST query;
            query.analyses = analysis_names();
            return assign_transformation_products::assign_transformation_products_impl(
                get_suspects(query),
                transformation_products,
                chromatographic_phase,
                mzrMS2);
          });
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
      NTS_QUERY_REQUEST query;
      query.analyses = analyses;
      query.include_filtered = include_filtered;
      return get_features(query);
    }

    std::vector<NTS_FEATURE_ROW> PROJECT_NON_TARGET_ANALYSIS::get_features(
        const NTS_QUERY_REQUEST &query) const
    {
      auto guard = mass_spec::api::connect_checked(ctx_);
      std::vector<NTS_FEATURE_ROW> out;
      const auto selected_analyses = mass_spec::spectra::sanitize_analyses(query.analyses);
      const auto selected_features = sanitize_query_values(query.features);
      const auto selected_feature_groups = sanitize_query_values(query.feature_groups);
      const auto selected_feature_components = sanitize_query_values(query.feature_components);
      std::string sql =
          "SELECT project_id, analysis, feature, feature_component, feature_group, adduct, rt, mz, mass, intensity, "
          "noise, sn, area, rtmin, rtmax, width, mzmin, mzmax, ppm, fwhm_rt, fwhm_mz, gaussian_A, gaussian_mu, "
          "gaussian_sigma, gaussian_r2, jaggedness, sharpness, asymmetry, modality, plates, polarity, filtered, "
          "filter, filled, correction, eic_size, eic_rt, eic_mz, eic_intensity, eic_baseline, eic_smoothed, "
          "ms1_size, ms1_mz, ms1_intensity, ms2_size, ms2_mz, ms2_intensity, created_at "
          "FROM NTS_FEATURES WHERE project_id = ?";
      if (!query.include_filtered)
      {
        sql += " AND filtered = FALSE";
      }
      if (!selected_analyses.empty())
      {
        sql += " AND analysis IN (";
        sql += project::db::placeholders(selected_analyses.size());
        sql += ")";
      }
      if (!selected_features.empty())
      {
        sql += " AND feature IN (";
        sql += project::db::placeholders(selected_features.size());
        sql += ")";
      }
      if (!selected_feature_groups.empty())
      {
        sql += " AND feature_group IN (";
        sql += project::db::placeholders(selected_feature_groups.size());
        sql += ")";
      }
      if (!selected_feature_components.empty())
      {
        sql += " AND feature_component IN (";
        sql += project::db::placeholders(selected_feature_components.size());
        sql += ")";
      }
      sql += " ORDER BY lower(analysis), analysis, mz, rt, feature";

      project::db::run_prepared(guard.get(), sql, "query NTS feature rows", [&](duckdb_prepared_statement statement)
                                {
                         idx_t bind_index = 1;
                         duckdb_bind_varchar(statement, bind_index++, ctx_->project_id.c_str());
                         for (const auto& analysis : selected_analyses) {
                           duckdb_bind_varchar(statement, bind_index++, analysis.c_str());
                         }
                         for (const auto& feature : selected_features) {
                           duckdb_bind_varchar(statement, bind_index++, feature.c_str());
                         }
                         for (const auto& group : selected_feature_groups) {
                           duckdb_bind_varchar(statement, bind_index++, group.c_str());
                         }
                         for (const auto& component : selected_feature_components) {
                           duckdb_bind_varchar(statement, bind_index++, component.c_str());
                         } }, [&](duckdb_result &result)
                                { out = project::db::rows_from_result(&result, [&](idx_t row)
                                                                      { return feature_row_from_result(result, row); }); });
      return filter_feature_rows_by_targets(out, query);
    }

    std::vector<NTS_SUSPECT_ROW> PROJECT_NON_TARGET_ANALYSIS::get_suspects(const NTS_QUERY_REQUEST &query) const
    {
      auto guard = mass_spec::api::connect_checked(ctx_);
      std::vector<NTS_SUSPECT_ROW> out;
      const auto selected_analyses = mass_spec::spectra::sanitize_analyses(query.analyses);

      std::string sql =
          "SELECT project_id, analysis, feature, candidate_rank, name, polarity, db_mass, exp_mass, error_mass, db_rt, exp_rt, error_rt, intensity, area, id_level, score, shared_fragments, cosine_similarity, formula, SMILES, InChI, InChIKey, xLogP, database_id, db_ms2_size, db_ms2_mz, db_ms2_intensity, db_ms2_formula, exp_ms2_size, exp_ms2_mz, exp_ms2_intensity, created_at "
          "FROM NTS_SUSPECTS WHERE project_id = ?";
      if (!selected_analyses.empty())
      {
        sql += " AND analysis IN (";
        sql += project::db::placeholders(selected_analyses.size());
        sql += ")";
      }
      sql += " ORDER BY lower(analysis), analysis, feature, candidate_rank, name";

      project::db::run_prepared(guard.get(), sql, "query NTS suspect rows", [&](duckdb_prepared_statement statement)
                                {
                         idx_t bind_index = 1;
                         duckdb_bind_varchar(statement, bind_index++, ctx_->project_id.c_str());
                         for (const auto& analysis : selected_analyses) {
                           duckdb_bind_varchar(statement, bind_index++, analysis.c_str());
                         } }, [&](duckdb_result &result)
                                { out = project::db::rows_from_result(&result, [&](idx_t row)
                                                                      { return suspect_row_from_result(result, row); }); });

      if (out.empty())
      {
        return out;
      }

      auto feature_query = query;
      feature_query.include_filtered = true;
      const auto feature_rows = get_features(feature_query);

      if (!query.features.empty() || !query.feature_groups.empty() || !query.feature_components.empty() || has_target_filters(query))
      {
        const auto keys = feature_keys_from_rows(feature_rows);
        if (keys.empty())
        {
          return {};
        }
        std::vector<NTS_SUSPECT_ROW> filtered;
        filtered.reserve(out.size());
        for (const auto &row : out)
        {
          if (keys.find(row.analysis + "\x1f" + row.feature) != keys.end())
          {
            filtered.push_back(row);
          }
        }
        out = std::move(filtered);
      }

      const auto metadata = feature_metadata_from_rows(feature_rows);
      for (auto &row : out)
      {
        const auto it = metadata.find(row.analysis + "\x1f" + row.feature);
        if (it != metadata.end())
        {
          row.feature_group = it->second.feature_group;
        }
      }

      return out;
    }

    std::vector<NTS_INTERNAL_STANDARD_ROW> PROJECT_NON_TARGET_ANALYSIS::get_internal_standards(const NTS_QUERY_REQUEST &query) const
    {
      auto guard = mass_spec::api::connect_checked(ctx_);
      std::vector<NTS_INTERNAL_STANDARD_ROW> out;
      const auto selected_analyses = mass_spec::spectra::sanitize_analyses(query.analyses);

      std::string sql =
          "SELECT project_id, analysis, feature, candidate_rank, name, polarity, db_mass, exp_mass, error_mass, db_rt, exp_rt, error_rt, intensity, area, id_level, score, shared_fragments, cosine_similarity, formula, SMILES, InChI, InChIKey, xLogP, database_id, db_ms2_size, db_ms2_mz, db_ms2_intensity, db_ms2_formula, exp_ms2_size, exp_ms2_mz, exp_ms2_intensity, created_at "
          "FROM NTS_INTERNAL_STANDARDS WHERE project_id = ?";
      if (!selected_analyses.empty())
      {
        sql += " AND analysis IN (";
        sql += project::db::placeholders(selected_analyses.size());
        sql += ")";
      }
      sql += " ORDER BY lower(analysis), analysis, feature, candidate_rank, name";

      project::db::run_prepared(guard.get(), sql, "query NTS internal standard rows", [&](duckdb_prepared_statement statement)
                                {
                         idx_t bind_index = 1;
                         duckdb_bind_varchar(statement, bind_index++, ctx_->project_id.c_str());
                         for (const auto& analysis : selected_analyses) {
                           duckdb_bind_varchar(statement, bind_index++, analysis.c_str());
                         } }, [&](duckdb_result &result)
                                { out = project::db::rows_from_result(&result, [&](idx_t row)
                                                                      { return internal_standard_row_from_result(result, row); }); });

      if (out.empty())
      {
        return out;
      }

      auto feature_query = query;
      feature_query.include_filtered = true;
      const auto feature_rows = get_features(feature_query);

      if (!query.features.empty() || !query.feature_groups.empty() || !query.feature_components.empty() || has_target_filters(query))
      {
        const auto keys = feature_keys_from_rows(feature_rows);
        if (keys.empty())
        {
          return {};
        }
        std::vector<NTS_INTERNAL_STANDARD_ROW> filtered;
        filtered.reserve(out.size());
        for (const auto &row : out)
        {
          if (keys.find(row.analysis + "\x1f" + row.feature) != keys.end())
          {
            filtered.push_back(row);
          }
        }
        out = std::move(filtered);
      }

      const auto metadata = feature_metadata_from_rows(feature_rows);
      for (auto &row : out)
      {
        const auto it = metadata.find(row.analysis + "\x1f" + row.feature);
        if (it != metadata.end())
        {
          row.feature_group = it->second.feature_group;
          row.feature_component = it->second.feature_component;
          row.adduct = it->second.adduct;
        }
      }

      return out;
    }

    std::vector<NTS_TRANSFORMATION_PRODUCT_ROW> PROJECT_NON_TARGET_ANALYSIS::get_transformation_products() const
    {
      auto guard = mass_spec::api::connect_checked(ctx_);
      std::vector<NTS_TRANSFORMATION_PRODUCT_ROW> out;
      const std::string sql =
          "SELECT project_id, name, formula, mass, SMILES, InChI, InChIKey, xLogP, transformation, precursor_name, precursor_formula, precursor_mass, precursor_SMILES, precursor_InChI, precursor_InChIKey, precursor_xLogP, main_precursor_name, main_precursor_formula, main_precursor_mass, main_precursor_SMILES, main_precursor_InChI, main_precursor_InChIKey, main_precursor_xLogP, feature_group, precursor_feature_group, main_precursor_feature_group, cosine_similarity, main_precursor_cosine_similarity, rt_plausibility, main_precursor_rt_plausibility, created_at "
          "FROM NTS_TRANSFORMATION_PRODUCTS WHERE project_id = ? "
          "ORDER BY lower(name), name, lower(transformation), transformation";

      project::db::run_prepared(guard.get(), sql, "query NTS transformation product rows", [&](duckdb_prepared_statement statement)
                                {
                         duckdb_bind_varchar(statement, 1, ctx_->project_id.c_str()); }, [&](duckdb_result &result)
                                { out = project::db::rows_from_result(&result, [&](idx_t row)
                                                                      { return transformation_product_row_from_result(result, row); }); });
      return out;
    }

  } // namespace api

} // namespace nts

// MARK: load_features_ms1
bool nts::PROJECT_NON_TARGET_ANALYSIS::load_features_ms1(
    bool filtered,
    const std::vector<float> &rtWindow,
    const std::vector<float> &mzWindow,
    float minTracesIntensity,
    float mzClust,
    float presence)
{
  load_processing_metadata();
  load_processing_headers();
  load_processing_features(true);
  return run_cached_features_algorithm(
      "load_features_ms1",
      cache_join_key({cache_bool_key(filtered), cache_vector_key(rtWindow), cache_vector_key(mzWindow), cache_scalar_key(minTracesIntensity), cache_scalar_key(mzClust), cache_scalar_key(presence)}),
      {feature_state_cache_key()},
      "Cached NTS features for load_features_ms1",
      [&]() {
        auto &features = feature_buffers();
        const auto &files = file_paths();
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
              mzmin = ft_j.mzmin + mzWindow[0];
              mzmax = ft_j.mzmax + mzWindow[1];
            }

            if (hasRtWindow)
            {
              rtmin = ft_j.rtmin + rtWindow[0];
              rtmax = ft_j.rtmax + rtWindow[1];
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

          if (targets.id.empty())
            continue;

          const std::string &file_i = files[i];
          if (!std::filesystem::exists(file_i))
            continue;

          const auto header_i = spectra_headers_at(i);
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
      });
}

// MARK: load_features_ms2
bool nts::PROJECT_NON_TARGET_ANALYSIS::load_features_ms2(
    bool filtered,
    float minTracesIntensity,
    float isolationWindow,
    float mzClust,
    float presence)
{
  load_processing_metadata();
  load_processing_headers();
  load_processing_features(true);
  return run_cached_features_algorithm(
      "load_features_ms2",
      cache_join_key({cache_bool_key(filtered), cache_scalar_key(minTracesIntensity), cache_scalar_key(isolationWindow), cache_scalar_key(mzClust), cache_scalar_key(presence)}),
      {feature_state_cache_key()},
      "Cached NTS features for load_features_ms2",
      [&]() {
        auto &features = feature_buffers();
        const auto &files = file_paths();
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

          if (targets.id.empty())
            continue;

          const std::string &file_i = files[i];
          if (!std::filesystem::exists(file_i))
            continue;

          const auto header_i = spectra_headers_at(i);
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
      });
}
