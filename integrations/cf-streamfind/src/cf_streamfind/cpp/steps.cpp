#include <memory>
#include <sstream>
#include <string>
#include <stdexcept>
#include <utility>
#include <vector>

#include "cf_step_abi.h"
#include "cf_plugin_table.h"
#include "cf_streamfind_signature_hashes.h"

#include "mass_spec/mass_spec.h"
#include "nta/nta.h"
#include "project/project.h"

namespace {

static const CfStepRuntimeContractV1* require_step_runtime(const CfExecutionContext* ctx) {
  return (ctx && ctx->step_runtime) ? ctx->step_runtime : nullptr;
}

static bool read_text_value(
  const CfExecutionContext* ctx,
  const CfStepRuntimeContractV1* runtime,
  const CfValueHandle* input,
  std::string& out) {
  if (!runtime || !runtime->read_text || !input) {
    return false;
  }

  const char* text = nullptr;
  size_t size = 0;
  if (runtime->read_text(ctx, input, &text, &size) != CF_STATUS_OK) {
    return false;
  }

  if (!text && size > 0) {
    return false;
  }

  out.assign(text ? text : "", size);
  return true;
}

static bool read_numeric_value(
  const CfExecutionContext* ctx,
  const CfStepRuntimeContractV1* runtime,
  const CfValueHandle* input,
  double& out) {
  if (!runtime || !runtime->read_numeric_scalar || !input) {
    return false;
  }
  return runtime->read_numeric_scalar(ctx, input, &out) == CF_STATUS_OK;
}

static std::string require_text_param(
  const CfExecutionContext* ctx,
  const CfStepRuntimeContractV1* runtime,
  const CfValueHandle* value,
  const char* param_name) {
  std::string text;
  if (!read_text_value(ctx, runtime, value, text)) {
    throw std::runtime_error(std::string("failed to read parameter: ") + param_name);
  }
  if (text.empty()) {
    throw std::runtime_error(std::string("parameter must not be empty: ") + param_name);
  }
  return text;
}

static std::vector<std::string> parse_json_string_array(
  const std::string& json_text,
  const char* param_name) {
  if (json_text.empty()) {
    return {};
  }

  const auto parsed = project::json::parse(json_text);
  if (!parsed.is_array()) {
    throw std::runtime_error(std::string(param_name) + " must be a JSON array");
  }

  std::vector<std::string> values;
  values.reserve(parsed.size());
  for (std::size_t i = 0; i < parsed.size(); ++i) {
    if (!parsed.at(i).is_string()) {
      std::ostringstream message;
      message << param_name << "[" << i << "] must be a string";
      throw std::runtime_error(message.str());
    }
    values.push_back(parsed.at(i).get<std::string>());
  }
  return values;
}

static std::vector<std::string> read_optional_string_array_param(
  const CfExecutionContext* ctx,
  const CfStepRuntimeContractV1* runtime,
  const CfValueHandle* value,
  const char* param_name) {
  std::string text;
  if (!read_text_value(ctx, runtime, value, text)) {
    throw std::runtime_error(std::string("failed to read parameter: ") + param_name);
  }
  return parse_json_string_array(text, param_name);
}

static std::pair<std::vector<float>, std::vector<float>> parse_rt_windows(const std::string& json_text) {
  std::vector<float> mins;
  std::vector<float> maxs;

  if (json_text.empty()) {
    return {mins, maxs};
  }

  const auto parsed = project::json::parse(json_text);
  if (!parsed.is_array()) {
    throw std::runtime_error("rt_windows must be a JSON array");
  }

  mins.reserve(parsed.size());
  maxs.reserve(parsed.size());
  for (const auto& window : parsed) {
    if (!window.is_object() || !window.contains("rtmin") || !window.contains("rtmax")) {
      throw std::runtime_error("each rt_windows entry must contain rtmin and rtmax");
    }
    mins.push_back(static_cast<float>(window.at("rtmin").get<double>()));
    maxs.push_back(static_cast<float>(window.at("rtmax").get<double>()));
  }

  return {mins, maxs};
}

struct ProjectRef {
  std::string db_path;
  std::string project_id;
};

struct ProjectImportArgs {
  std::vector<std::string> file_paths;
  std::vector<std::string> replicates;
  std::vector<std::string> blanks;
};

static ProjectRef parse_project_ref(const std::string& json_text) {
  if (json_text.empty()) {
    throw std::runtime_error("project_ref must not be empty");
  }

  const auto parsed = project::json::parse(json_text);
  if (!parsed.is_object()) {
    throw std::runtime_error("project_ref must be a JSON object");
  }
  if (!parsed.contains("db_path") || !parsed.at("db_path").is_string()) {
    throw std::runtime_error("project_ref.db_path must be a string");
  }
  if (!parsed.contains("project_id") || !parsed.at("project_id").is_string()) {
    throw std::runtime_error("project_ref.project_id must be a string");
  }

  ProjectRef ref{
    parsed.at("db_path").get<std::string>(),
    parsed.at("project_id").get<std::string>()
  };
  if (ref.db_path.empty()) {
    throw std::runtime_error("project_ref.db_path must not be empty");
  }
  if (ref.project_id.empty()) {
    throw std::runtime_error("project_ref.project_id must not be empty");
  }
  return ref;
}

static std::string serialize_project_ref(const ProjectRef& ref) {
  project::json payload = {
    {"db_path", ref.db_path},
    {"project_id", ref.project_id}
  };
  return payload.dump();
}

static void validate_import_args(const ProjectImportArgs& args) {
  if (!args.replicates.empty() && args.replicates.size() != args.file_paths.size()) {
    throw std::runtime_error("replicates must be empty or have the same length as file_paths");
  }
  if (!args.blanks.empty() && args.blanks.size() != args.file_paths.size()) {
    throw std::runtime_error("blanks must be empty or have the same length as file_paths");
  }
}

static void ensure_project_domain(project::PROJECT& project_root, const std::string& expected_domain) {
  const std::string current_domain = project_root.domain();
  if (current_domain.empty()) {
    project_root.set_domain(expected_domain);
    return;
  }
  if (current_domain != expected_domain) {
    throw std::runtime_error(
      "project domain is already set to " + current_domain + " and is not compatible with " + expected_domain);
  }
}

template <typename ChildFactory>
static ProjectRef prepare_project_child(
  const ProjectRef& ref,
  const ProjectImportArgs& import_args,
  const std::string& expected_domain,
  ChildFactory&& child_factory) {
  validate_import_args(import_args);

  project::PROJECT project_root(ref.db_path, ref.project_id);
  project_root.validate();
  ensure_project_domain(project_root, expected_domain);
  mass_spec::PROJECT_MASS_SPEC mass_spec_project(
    project_root.context(),
    import_args.file_paths,
    import_args.replicates,
    import_args.blanks);
  (void)mass_spec_project;
  auto child_project = child_factory(project_root.context());
  (void)child_project;

  return ref;
}

static CfStatusCode call_sf_nta_project(
  CfExecutionContext* ctx,
  const CfValueHandle* params,
  size_t n_params,
  const CfValueHandle* inputs,
  size_t n_inputs,
  CfValueHandle* outputs,
  size_t n_outputs) {
  using S = cf_sig::sf_nta_project;

  (void)inputs;

  if (n_inputs < S::kInputCount || n_params < S::kParamCount || n_outputs < S::kOutputCount) {
    return CF_STATUS_INVALID;
  }

  const CfStepRuntimeContractV1* runtime = require_step_runtime(ctx);
  if (!runtime || !runtime->write_string) {
    return CF_STATUS_ERROR;
  }

  try {
    const ProjectRef project_ref{
      require_text_param(ctx, runtime, &params[S::P_db_path], "db_path"),
      require_text_param(ctx, runtime, &params[S::P_project_id], "project_id")
    };
    const ProjectImportArgs import_args{
      read_optional_string_array_param(ctx, runtime, &params[S::P_file_paths], "file_paths"),
      read_optional_string_array_param(ctx, runtime, &params[S::P_replicates], "replicates"),
      read_optional_string_array_param(ctx, runtime, &params[S::P_blanks], "blanks")
    };

    const ProjectRef prepared_ref = prepare_project_child(
      project_ref,
      import_args,
      "mass_spec_nta",
      [](const std::shared_ptr<project::api::CONTEXT>& ctx_value) {
        return nta::PROJECT_NON_TARGET_ANALYSIS(ctx_value);
      });

    const std::string output_json = serialize_project_ref(prepared_ref);
    return runtime->write_string(
      ctx,
      &outputs[S::O_data],
      output_json.c_str(),
      output_json.size());
  } catch (const std::exception&) {
    return CF_STATUS_ERROR;
  }
}

static CfStatusCode call_sf_nta_find_features(
  CfExecutionContext* ctx,
  const CfValueHandle* params,
  size_t n_params,
  const CfValueHandle* inputs,
  size_t n_inputs,
  CfValueHandle* outputs,
  size_t n_outputs) {
  using S = cf_sig::sf_nta_find_features;

  if (n_params < S::kParamCount || n_inputs < S::kInputCount || n_outputs < S::kOutputCount) {
    return CF_STATUS_INVALID;
  }

  const CfStepRuntimeContractV1* runtime = require_step_runtime(ctx);
  if (!runtime || !runtime->write_string) {
    return CF_STATUS_ERROR;
  }

  try {
    std::string project_ref_json;
    std::string rt_windows_json;
    std::string debug_analysis;
    double base_quantile = 0.0;
    double baseline_window = 0.0;
    double debug_mz = 0.0;
    double debug_spec_idx = -1.0;
    double max_width = 0.0;
    double min_snr = 0.0;
    double min_traces = 0.0;
    double noise_threshold = 0.0;
    double ppm_threshold = 0.0;

    if (!read_text_value(ctx, runtime, &inputs[S::I_data], project_ref_json)) {
      return CF_STATUS_INVALID;
    }
    if (!read_text_value(ctx, runtime, &params[S::P_rt_windows], rt_windows_json)) {
      return CF_STATUS_INVALID;
    }
    if (!read_numeric_value(ctx, runtime, &params[S::P_base_quantile], base_quantile) ||
        !read_numeric_value(ctx, runtime, &params[S::P_baseline_window], baseline_window) ||
        !read_text_value(ctx, runtime, &params[S::P_debug_analysis], debug_analysis) ||
        !read_numeric_value(ctx, runtime, &params[S::P_debug_mz], debug_mz) ||
        !read_numeric_value(ctx, runtime, &params[S::P_debug_spec_idx], debug_spec_idx) ||
        !read_numeric_value(ctx, runtime, &params[S::P_max_width], max_width) ||
        !read_numeric_value(ctx, runtime, &params[S::P_min_snr], min_snr) ||
        !read_numeric_value(ctx, runtime, &params[S::P_min_traces], min_traces) ||
        !read_numeric_value(ctx, runtime, &params[S::P_noise_threshold], noise_threshold) ||
        !read_numeric_value(ctx, runtime, &params[S::P_ppm_threshold], ppm_threshold)) {
      return CF_STATUS_INVALID;
    }

    auto rt_windows = parse_rt_windows(rt_windows_json);
    const ProjectRef project_ref = parse_project_ref(project_ref_json);

    project::PROJECT project_root(project_ref.db_path, project_ref.project_id);
    nta::PROJECT_NON_TARGET_ANALYSIS nta_project(project_root.context());

    const bool success = nta_project.find_features(
      rt_windows.first,
      rt_windows.second,
      static_cast<float>(ppm_threshold),
      static_cast<float>(noise_threshold),
      static_cast<float>(min_snr),
      static_cast<int>(min_traces),
      static_cast<float>(baseline_window),
      static_cast<float>(max_width),
      static_cast<float>(base_quantile),
      debug_analysis,
      static_cast<float>(debug_mz),
      static_cast<int>(debug_spec_idx));

    if (!success) {
      return CF_STATUS_ERROR;
    }

    return runtime->write_string(
      ctx,
      &outputs[S::O_data],
      project_ref_json.c_str(),
      project_ref_json.size());
  } catch (const std::exception&) {
    return CF_STATUS_ERROR;
  }
}

#define CF_STREAMFIND_STEPS(X) \
  X(cf_generated::ksf_nta_projectIri, cf_generated::ksf_nta_projectSigHash, call_sf_nta_project, nullptr) \
  X(cf_generated::ksf_nta_find_featuresIri, cf_generated::ksf_nta_find_featuresSigHash, call_sf_nta_find_features, nullptr)

}  // namespace

CF_DEFINE_STEP_TABLE(CF_STREAMFIND_STEPS)
