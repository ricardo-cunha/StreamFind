// metfrag_runner.cpp — MetFragCL subprocess runner implementation

#include "nta_metfrag_runner.h"
#include "nta.h"
#include "mass_spec/mass_spec.h"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <chrono>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace fs = std::filesystem;

namespace
{
  const std::vector<std::string> kSupportedMetFragDatabaseTypes = {
    "KEGG",
    "PubChem",
    "ExtendedPubChem",
    "ChemSpiderRest",
    "LocalSDF",
    "LocalPSV",
    "LocalCSV"
  };
  const std::vector<std::string> kSupportedMetFragCandidateWriters = {
    "SDF",
    "XLS",
    "CSV",
    "ExtendedXLS",
    "ExtendedFragmentsXLS"
  };
}

// ── Internal helpers ──────────────────────────────────────────────────────────
namespace
{
  // Decode a base64 + little-endian float32 encoded string to vector<double>.
  std::vector<double> decode_encoded(const std::string &encoded)
  {
    std::vector<double> out;
    if (encoded.empty())
      return out;
    std::string raw        = mass_spec::reader::utils::decode_base64(encoded);
    std::vector<float> fv  = mass_spec::reader::utils::decode_little_endian_to_float(raw, 4);
    out.reserve(fv.size());
    for (float f : fv)
      out.push_back(static_cast<double>(f));
    return out;
  }

  // Trim leading/trailing whitespace.
  std::string trim_ws(const std::string &s)
  {
    size_t a = s.find_first_not_of(" \t\r\n");
    if (a == std::string::npos)
      return "";
    size_t b = s.find_last_not_of(" \t\r\n");
    return s.substr(a, b - a + 1);
  }

  std::string to_lower_ascii(std::string s)
  {
    std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) {
      return static_cast<char>(std::tolower(c));
    });
    return s;
  }

  bool is_local_database_type(const std::string &database_type)
  {
    return database_type == "LocalSDF" ||
           database_type == "LocalPSV" ||
           database_type == "LocalCSV";
  }

  bool has_extra_param(
      const std::vector<std::pair<std::string, std::string>> &extra_params,
      const std::string &key)
  {
    for (const auto &entry : extra_params)
    {
      if (entry.first == key && !trim_ws(entry.second).empty())
        return true;
    }
    return false;
  }

  std::string join_strings(
      const std::vector<std::string> &values,
      const std::string &separator)
  {
    std::ostringstream oss;
    for (std::size_t i = 0; i < values.size(); ++i)
    {
      if (i > 0)
        oss << separator;
      oss << values[i];
    }
    return oss.str();
  }

  std::string join_doubles(
      const std::vector<double> &values,
      const std::string &separator)
  {
    std::ostringstream oss;
    oss << std::fixed << std::setprecision(6);
    for (std::size_t i = 0; i < values.size(); ++i)
    {
      if (i > 0)
        oss << separator;
      oss << values[i];
    }
    return oss.str();
  }

  std::string make_run_timestamp()
  {
    const auto now = std::chrono::system_clock::now();
    const std::time_t now_time = std::chrono::system_clock::to_time_t(now);
    std::tm time_info{};
#ifdef _WIN32
    localtime_s(&time_info, &now_time);
#else
    localtime_r(&now_time, &time_info);
#endif
    std::ostringstream oss;
    oss << std::put_time(&time_info, "%Y%m%d_%H%M%S");
    return oss.str();
  }

  std::string default_metfrag_run_dir()
  {
    return (fs::path(".") / "log" / "metfrag" / ("run_" + make_run_timestamp())).string();
  }

  std::string default_empty_peak_list_path(const std::string &run_dir)
  {
    return (fs::path(run_dir) / "_metfrag_empty_peaklist.txt").string();
  }

  void ensure_empty_peak_list_file(const std::string &path)
  {
    if (fs::exists(path))
      return;
    std::ofstream f(path);
  }

  // Build a safe filename component from analysis + feature names.
  std::string safe_id(const std::string &a, const std::string &b)
  {
    std::string combined = a + "_" + b;
    std::string out;
    out.reserve(combined.size());
    for (unsigned char c : combined)
      out += (std::isalnum(c) || c == '-' || c == '.') ? static_cast<char>(c) : '_';
    return out;
  }

  // ── File writing ─────────────────────────────────────────────────────────

  void write_peak_list(
      const std::string &path,
      const std::vector<double> &mz,
      const std::vector<double> &intensity)
  {
    std::ofstream f(path);
    for (size_t i = 0; i < mz.size() && i < intensity.size(); ++i)
      f << mz[i] << " " << intensity[i] << "\n";
  }

  void write_params_file(
      const std::string &path,
      const std::string &common_template,
      double precursor_mass,
      int polarity,
      const std::string &ms2_path,
      const std::string &sample_name)
  {
    std::ofstream f(path);
    // MetFrag (Java) requires forward slashes in paths on all platforms.
    auto fwd = [](std::string s) -> std::string {
      for (char &c : s) if (c == '\\') c = '/';
      return s;
    };
    f << common_template;
    f << "PeakListPath = " << fwd(ms2_path) << "\n";
    f << "NeutralPrecursorMass = " << precursor_mass << "\n";
    f << "PrecursorIonMode = " << polarity << "\n";
    f << "IsPositiveIonMode = " << ((polarity > 0) ? "True" : "False") << "\n";
    f << "SampleName = " << sample_name << "\n";
  }

  // ── Subprocess ───────────────────────────────────────────────────────────

  // Run MetFragCL and redirect stdout+stderr to log_path.
  // Returns exit status (0 = success).
  int run_metfrag(
      const std::string &metfrag_path,
      const std::string &java_path,
      const std::string &params_path,
      const std::string &log_path)
  {
    auto q = [](const std::string &p) { return "\"" + p + "\""; };

    std::string cmd;
    // JAR mode: file ends with .jar (case-insensitive)
    bool is_jar = (metfrag_path.size() > 4) &&
                  (metfrag_path.substr(metfrag_path.size() - 4) == ".jar" ||
                   metfrag_path.substr(metfrag_path.size() - 4) == ".JAR");
    if (is_jar)
      cmd = q(java_path) + " -jar " + q(metfrag_path) + " " + q(params_path);
    else
      cmd = q(metfrag_path) + " " + q(params_path);

    cmd += " > " + q(log_path) + " 2>&1";

#ifdef _WIN32
    // On Windows, cmd.exe /c applies "rule 2" when the command starts with '"':
    // it strips the leading '"' and removes the last '"', which corrupts the
    // redirect target (e.g. "log.log" 2>&1 → log.log 2>&1 as the filename).
    // Wrapping the entire command in an extra outer '"' pair causes cmd.exe to
    // strip only that outer pair, leaving the inner command intact.
    return std::system(("\"" + cmd + "\"").c_str());
#else
    return std::system(cmd.c_str());
#endif
  }

  // ── CSV parsing ───────────────────────────────────────────────────────────

  std::string build_common_params_template(
      const nta::metfrag_runner::MetFragParams &params,
      const std::string &database_path,
      const std::string &results_dir)
  {
    std::ostringstream oss;
    auto fwd = [](std::string s) -> std::string {
      for (char &c : s) if (c == '\\') c = '/';
      return s;
    };
    auto w = [&](const std::string &k, const std::string &v) {
      oss << k << " = " << v << "\n";
    };

    for (const auto &kv : params.extra_params)
      w(kv.first, kv.second);

    w("MetFragDatabaseType", params.database_type);
    w("DatabaseSearchRelativeMassDeviation", std::to_string(params.ppm));
    w("FragmentPeakMatchRelativeMassDeviation", std::to_string(params.ppmMS2));
    w("FragmentPeakMatchAbsoluteMassDeviation", std::to_string(params.mzrMS2));
    w("MetFragScoreTypes", join_strings(params.score_types, ","));
    w("MetFragScoreWeights", join_doubles(params.score_weights, ","));
    w("MetFragPreProcessingCandidateFilter", join_strings(params.pre_processing_candidate_filter, ","));
    w("MetFragPostProcessingCandidateFilter", join_strings(params.post_processing_candidate_filter, ","));
    w("MetFragCandidateWriter", join_strings(params.candidate_writer, ","));
    w("ResultsPath", fwd(results_dir));
    w("MaximumTreeDepth", std::to_string(params.maximum_tree_depth));
    w("NumberThreads", std::to_string(params.number_threads));
    w("UseSmiles", params.use_smiles ? "True" : "False");

    if (!database_path.empty())
      w("LocalDatabasePath", fwd(database_path));

    return oss.str();
  }

  std::vector<std::string> collect_metfrag_result_files(
      const std::string &results_dir,
      const std::string &sample_name)
  {
    std::vector<std::string> candidates = {
      results_dir + "/" + sample_name + ".csv",
      results_dir + "/" + sample_name + "_1.csv"
    };

    try
    {
      for (const auto &entry : fs::directory_iterator(results_dir))
      {
        if (!entry.is_regular_file())
          continue;
        if (entry.path().extension() != ".csv" && entry.path().extension() != ".CSV")
          continue;
        std::string stem = entry.path().stem().string();
        if (stem.rfind(sample_name, 0) == 0)
          candidates.push_back(entry.path().string());
      }
    }
    catch (...) {}

    std::sort(candidates.begin(), candidates.end());
    candidates.erase(std::unique(candidates.begin(), candidates.end()), candidates.end());

    std::vector<std::string> existing;
    for (const auto &cand : candidates)
    {
      if (fs::exists(cand))
        existing.push_back(cand);
    }
    return existing;
  }

  std::vector<std::string> split_csv_line(const std::string &line)
  {
    std::vector<std::string> fields;
    std::string field;
    bool in_quotes = false;
    for (size_t i = 0; i < line.size(); ++i)
    {
      char c = line[i];
      if (c == '"')
      {
        if (in_quotes && i + 1 < line.size() && line[i + 1] == '"')
          { field += '"'; ++i; }
        else
          in_quotes = !in_quotes;
      }
      else if (c == ',' && !in_quotes)
        { fields.push_back(trim_ws(field)); field.clear(); }
      else
        field += c;
    }
    fields.push_back(trim_ws(field));
    return fields;
  }

  // Case-insensitive column-index lookup.
  int find_col(
      const std::vector<std::string> &headers,
      std::initializer_list<const char *> options)
  {
    for (const char *opt : options)
    {
      std::string o = opt;
      std::transform(o.begin(), o.end(), o.begin(), ::tolower);
      for (size_t i = 0; i < headers.size(); ++i)
      {
        std::string h = headers[i];
        std::transform(h.begin(), h.end(), h.begin(), ::tolower);
        if (h == o)
          return static_cast<int>(i);
      }
    }
    return -1;
  }

  struct MetFragRow
  {
    std::string name;
    std::string formula;
    std::string SMILES;
    std::string InChI;
    std::string InChIKey;
    std::string database_id;
    double      score       = 0.0;
    double      xLogP       = std::numeric_limits<double>::quiet_NaN();
    double      neutral_mass= std::numeric_limits<double>::quiet_NaN();
    std::string expl_peaks;
    std::string expl_formulas;
  };

  // Locate and parse the MetFrag output CSV for a given sample_name.
  std::vector<MetFragRow> parse_metfrag_csv(
      const std::string &results_dir,
      const std::string &sample_name)
  {
    std::vector<MetFragRow> out;

    std::vector<std::string> candidates = collect_metfrag_result_files(results_dir, sample_name);

    std::ifstream f;
    for (const auto &cand : candidates)
    { f.open(cand); if (f.is_open()) break; }
    if (!f.is_open())
      return out;

    std::string header_line;
    if (!std::getline(f, header_line))
      return out;
    auto headers = split_csv_line(header_line);

    int ci_name  = find_col(headers, {"Name", "CompoundName", "compound_name"});
    int ci_form  = find_col(headers, {"MolecularFormula", "formula"});
    int ci_smi   = find_col(headers, {"SMILES", "smiles", "CanonicalSMILES"});
    int ci_inchi = find_col(headers, {"InChI", "inchi1", "StandardInChI"});
    int ci_ikey  = find_col(headers, {"InChIKey", "inchi_key"});
    int ci_id    = find_col(headers, {"Identifier", "PubChemCID", "database_id", "InChIKey"});
    int ci_score = find_col(headers, {"Score", "MetFragScore", "TotalScore", "FinalScore"});
    int ci_xlogp = find_col(headers, {"XLogP", "XLogP3", "LogP", "XLogP-3"});
    int ci_mass  = find_col(headers, {"NeutralMass", "MonoisotopicMass", "ExactMass"});
    int ci_expl  = find_col(headers, {"ExplPeaks", "ExplainedPeaks"});
    int ci_exform= find_col(headers, {"FormulasOfExplPeaks", "ExplPeakFormulas"});

    auto gf = [](const std::vector<std::string> &row, int idx) -> std::string {
      if (idx < 0 || static_cast<size_t>(idx) >= row.size()) return "";
      return row[idx];
    };

    std::string line;
    while (std::getline(f, line))
    {
      if (trim_ws(line).empty()) continue;
      auto row = split_csv_line(line);
      MetFragRow r;
      r.name        = gf(row, ci_name);
      r.formula     = gf(row, ci_form);
      r.SMILES      = gf(row, ci_smi);
      r.InChI       = gf(row, ci_inchi);
      r.InChIKey    = gf(row, ci_ikey);
      r.database_id = gf(row, ci_id);
      std::string ss = gf(row, ci_score);
      if (!ss.empty()) r.score = std::atof(ss.c_str());
      std::string xs = gf(row, ci_xlogp);
      if (!xs.empty() && xs != "NA") r.xLogP = std::atof(xs.c_str());
      std::string ms = gf(row, ci_mass);
      if (!ms.empty()) r.neutral_mass = std::atof(ms.c_str());
      r.expl_peaks    = gf(row, ci_expl);
      r.expl_formulas = gf(row, ci_exform);
      out.push_back(std::move(r));
    }

    // Sort descending by score.
    std::stable_sort(out.begin(), out.end(),
        [](const MetFragRow &a, const MetFragRow &b) { return a.score > b.score; });
    return out;
  }

  // ── ExplPeaks parsing ─────────────────────────────────────────────────────
  // MetFrag ExplPeaks format: "mz_intensity;mz_intensity;..."
  // FormulasOfExplPeaks format: "mz:formula;mz:formula;..."

  void parse_expl_peaks(
      const std::string &expl_peaks,
      const std::string &expl_formulas,
      std::vector<double> &mz_out,
      std::vector<double> &intensity_out,
      std::string &formula_out)
  {
    mz_out.clear(); intensity_out.clear(); formula_out.clear();
    if (expl_peaks.empty()) return;

    std::istringstream ss(expl_peaks);
    std::string token;
    while (std::getline(ss, token, ';'))
    {
      if (token.empty()) continue;
      size_t us = token.find('_');
      if (us == std::string::npos) continue;
      mz_out.push_back(std::atof(token.substr(0, us).c_str()));
      intensity_out.push_back(std::atof(token.substr(us + 1).c_str()));
    }

    if (!expl_formulas.empty())
    {
      std::vector<std::string> parts;
      std::istringstream fs(expl_formulas);
      std::string ft;
      while (std::getline(fs, ft, ';'))
      {
        size_t colon = ft.find(':');
        if (colon != std::string::npos)
        {
          std::string form = ft.substr(colon + 1);
          if (!form.empty()) parts.push_back(form);
        }
      }
      for (size_t i = 0; i < parts.size(); ++i)
        formula_out += (i == 0 ? "" : ";") + parts[i];
    }
  }

  // ── Cosine similarity ─────────────────────────────────────────────────────

  double cosine_similarity(
      const std::vector<double> &db_mz,
      const std::vector<double> &db_int,
      const std::vector<double> &exp_mz,
      const std::vector<double> &exp_int,
      double ppm_ms2,
      double mzr_ms2,
      int &shared_out)
  {
    shared_out = 0;
    if (db_mz.empty() || exp_mz.empty()) return 0.0;

    std::vector<double> i_db, i_exp;
    i_db.reserve(db_mz.size());
    i_exp.reserve(db_mz.size());

    for (size_t z = 0; z < db_mz.size(); ++z)
    {
      double tol  = std::max(db_mz[z] * ppm_ms2 / 1e6, mzr_ms2);
      double lo   = db_mz[z] - tol;
      double hi   = db_mz[z] + tol;
      int    best = -1;
      double best_err = std::numeric_limits<double>::max();
      for (size_t k = 0; k < exp_mz.size(); ++k)
        if (exp_mz[k] >= lo && exp_mz[k] <= hi)
        {
          double err = std::abs(exp_mz[k] - db_mz[z]);
          if (err < best_err) { best_err = err; best = static_cast<int>(k); }
        }
      if (best >= 0) { i_db.push_back(db_int[z]); i_exp.push_back(exp_int[best]); ++shared_out; }
    }

    if (shared_out == 0) return 0.0;

    double max_db  = *std::max_element(i_db.begin(), i_db.end());
    double max_exp = *std::max_element(i_exp.begin(), i_exp.end());
    if (max_db <= 0.0 || max_exp <= 0.0) return 0.0;

    double dot = 0.0, mag_db = 0.0, mag_exp = 0.0;
    for (size_t k = 0; k < i_db.size(); ++k)
    {
      double di = i_db[k] / max_db, ei = i_exp[k] / max_exp;
      dot += di * ei; mag_db += di * di; mag_exp += ei * ei;
    }
    if (mag_db <= 0.0 || mag_exp <= 0.0) return 0.0;
    return std::round(dot / (std::sqrt(mag_db) * std::sqrt(mag_exp)) * 10000.0) / 10000.0;
  }

  // ── LocalCSV column normalizer ───────────────────────────────────────────
  //
  // MetFrag's LocalCSVDatabase requires specific column names:
  //   Identifier, MonoisotopicMass, MolecularFormula, SMILES, InChI, InChIKey, Name
  //
  // User-supplied CSVs often use: name, mass, formula, smiles, inchi, inchikey, ...
  // This function rewrites a normalised copy in run_dir when the columns differ,
  // and returns the path to use (original if already correct, new copy otherwise).
  std::string normalize_localcsv_database(
      const std::string &db_path,
      const std::string &run_dir_path,
      bool debug)
  {
    if (db_path.empty()) return db_path;

    std::ifstream in(db_path);
    if (!in.is_open())
    {
      std::cerr << "[metfrag] LocalCSV database not found: " << db_path << "\n";
      return db_path;
    }

    // Read header line.
    std::string header_line;
    if (!std::getline(in, header_line))
      return db_path;

    std::vector<std::string> cols = split_csv_line(header_line);
    if (cols.empty()) return db_path;

    // Case-insensitive column index lookup.
    auto find_col = [&](const std::vector<std::string> &candidates) -> int
    {
      for (const auto &cand : candidates)
      {
        std::string lc_cand = cand;
        std::transform(lc_cand.begin(), lc_cand.end(), lc_cand.begin(), ::tolower);
        for (int i = 0; i < static_cast<int>(cols.size()); ++i)
        {
          std::string lc_col = cols[i];
          std::transform(lc_col.begin(), lc_col.end(), lc_col.begin(), ::tolower);
          if (lc_col == lc_cand) return i;
        }
      }
      return -1;
    };

    // Rename map: MetFrag target → accepted user column names (first match wins).
    struct RenameRule { std::string target; std::vector<std::string> aliases; };
    std::vector<RenameRule> rules = {
      { "Name",             { "Name", "name" } },
      { "MolecularFormula", { "MolecularFormula", "formula" } },
      { "MonoisotopicMass", { "MonoisotopicMass", "mass" } },
      { "SMILES",           { "SMILES", "smiles", "Smiles" } },
      { "InChI",            { "InChI", "inchi", "Inchi" } },
      { "InChIKey",         { "InChIKey", "inchikey", "Inchikey" } },
      { "Identifier",       { "Identifier", "identifier", "id", "database_id", "databaseid" } },
    };

    bool renamed_any = false;
    for (const auto &rule : rules)
    {
      int idx = find_col(rule.aliases);
      if (idx < 0) continue;
      if (cols[idx] != rule.target)
      {
        cols[idx] = rule.target;
        renamed_any = true;
      }
    }

    // If still no Identifier column, derive from Name column.
    int id_idx   = find_col({ "Identifier" });
    int name_idx = find_col({ "Name" });
    bool add_identifier = (id_idx < 0 && name_idx >= 0);
    if (add_identifier) renamed_any = true;

    if (!renamed_any && !add_identifier)
      return db_path;  // Already correct — use as-is.

    // Write normalised copy.
    std::string out_path = run_dir_path + "/metfrag_localcsv_normalized.csv";
    std::ofstream out(out_path);
    if (!out.is_open())
    {
      std::cerr << "[metfrag] Cannot write normalised LocalCSV to: " << out_path << "\n";
      return db_path;
    }

    // Write new header (append Identifier at end if derived from Name).
    for (size_t i = 0; i < cols.size(); ++i)
    {
      if (i > 0) out << ',';
      out << cols[i];
    }
    if (add_identifier) out << ",Identifier";
    out << '\n';

    // Stream data rows, appending Identifier value when needed.
    std::string row;
    while (std::getline(in, row))
    {
      out << row;
      if (add_identifier)
      {
        // Append value of Name column as Identifier.
        std::vector<std::string> fields = split_csv_line(row);
        std::string id_val = (name_idx < static_cast<int>(fields.size())) ? fields[name_idx] : "";
        out << ',' << id_val;
      }
      out << '\n';
    }

    if (debug)
      std::cerr << "[metfrag] LocalCSV normalised: " << out_path << "\n";

    return out_path;
  }

} // anonymous namespace

// ── Public implementation ─────────────────────────────────────────────────────

namespace nta::metfrag_runner
{

std::vector<std::string> supported_database_types()
{
  return kSupportedMetFragDatabaseTypes;
}

std::string canonicalize_database_type(const std::string &database_type)
{
  const std::string needle = to_lower_ascii(trim_ws(database_type));
  for (const auto &value : kSupportedMetFragDatabaseTypes)
  {
    if (to_lower_ascii(value) == needle)
      return value;
  }

  std::ostringstream oss;
  oss << "Unsupported MetFrag database_type '" << database_type << "'. Supported values are: ";
  for (size_t i = 0; i < kSupportedMetFragDatabaseTypes.size(); ++i)
  {
    if (i > 0)
      oss << ", ";
    oss << kSupportedMetFragDatabaseTypes[i];
  }
  throw std::invalid_argument(oss.str());
}

MetFragParams canonicalize_and_validate_params(const MetFragParams &params)
{
  MetFragParams out = params;
  out.database_type = canonicalize_database_type(params.database_type);

  if (out.score_types.empty())
    throw std::invalid_argument("MetFrag score_types must not be empty.");
  if (out.score_types.size() != out.score_weights.size())
    throw std::invalid_argument("MetFrag score_types and score_weights must have the same length.");
  if (out.pre_processing_candidate_filter.empty())
    throw std::invalid_argument("MetFrag pre_processing_candidate_filter must not be empty.");
  if (out.post_processing_candidate_filter.empty())
    throw std::invalid_argument("MetFrag post_processing_candidate_filter must not be empty.");
  if (out.candidate_writer.empty())
    throw std::invalid_argument("MetFrag candidate_writer must not be empty.");
  for (const auto &writer : out.candidate_writer)
  {
    if (std::find(kSupportedMetFragCandidateWriters.begin(), kSupportedMetFragCandidateWriters.end(), writer) ==
        kSupportedMetFragCandidateWriters.end())
    {
      throw std::invalid_argument("Unsupported MetFrag candidate_writer '" + writer + "'.");
    }
  }
  if (std::find(out.candidate_writer.begin(), out.candidate_writer.end(), "CSV") == out.candidate_writer.end())
    throw std::invalid_argument("MetFrag candidate_writer must include 'CSV' for StreamFind result parsing.");
  if (out.maximum_tree_depth < 1)
    throw std::invalid_argument("MetFrag maximum_tree_depth must be at least 1.");
  if (out.number_threads < 1)
    throw std::invalid_argument("MetFrag number_threads must be at least 1.");

  if (is_local_database_type(out.database_type))
  {
    if (trim_ws(out.database_path).empty())
    {
      throw std::invalid_argument(
        "MetFrag database_type '" + out.database_type +
        "' requires a non-empty database_path."
      );
    }
    if (!fs::exists(out.database_path))
    {
      throw std::invalid_argument(
        "MetFrag local database file does not exist: " + out.database_path
      );
    }
  }

  if (out.database_type == "ChemSpiderRest" &&
      !has_extra_param(out.extra_params, "ChemSpiderToken"))
  {
    throw std::invalid_argument(
      "MetFrag database_type 'ChemSpiderRest' requires extra_params[['ChemSpiderToken']]."
    );
  }

  return out;
}

void metfrag_screening_impl(
  PROJECT_NON_TARGET_ANALYSIS &nta_data,
    const std::vector<std::string> &analyses_sel,
    const MetFragParams &p)
{
  const MetFragParams params = canonicalize_and_validate_params(p);
  const auto &analysis_names = nta_data.analysis_names();
  auto &feature_buffers = nta_data.feature_buffers();
  auto &suspect_buffers = nta_data.suspect_buffers();
  const size_t n_ana = analysis_names.size();

  // Ensure run directory exists.
  std::string run_dir = params.run_dir.empty() ? default_metfrag_run_dir() : params.run_dir;
  try { fs::create_directories(run_dir); }
  catch (const std::exception &e)
  {
    std::cerr << "[metfrag_runner] Failed to create run_dir '" << run_dir << "': " << e.what() << "\n";
  }
  std::cout << "[metfrag_runner] run_dir: " << run_dir << std::endl;

  // Normalise LocalCSV column names once before the feature loop.
  std::string effective_db_path = params.database_path;
  if (!effective_db_path.empty())
  {
    if (params.database_type == "LocalCSV")
      effective_db_path = normalize_localcsv_database(effective_db_path, run_dir, params.debug);
  }

  const std::string common_params_template =
    build_common_params_template(params, effective_db_path, run_dir);
  const std::string shared_empty_peak_list = default_empty_peak_list_path(run_dir);
  ensure_empty_peak_list_file(shared_empty_peak_list);

  // Reset suspects for all analyses.
  for (size_t ai = 0; ai < n_ana; ++ai)
    suspect_buffers[ai] = nta::api::NTA_SUSPECTS();

  for (size_t ai = 0; ai < n_ana; ++ai)
  {
    const std::string &ana = analysis_names[ai];

    if (!analyses_sel.empty() &&
        std::find(analyses_sel.begin(), analyses_sel.end(), ana) == analyses_sel.end())
      continue;

    nta::api::NTA_FEATURES &feats = feature_buffers[ai];
    const int n_feat = feats.size();

    std::cout << ai + 1 << "/" << n_ana
              << " MetFrag screening: " << ana
              << " (" << n_feat << " features)" << std::endl;
    int n_suspects_found = 0;

    for (int fi = 0; fi < n_feat; ++fi)
    {
      // Skip filtered features unless explicitly requested.
      if (!params.filtered && feats.filtered[fi])
        continue;

      // Decode MS2 peak list.
      std::vector<double> ms2_mz  = decode_encoded(feats.ms2_mz[fi]);
      std::vector<double> ms2_int = decode_encoded(feats.ms2_intensity[fi]);

      // Determine neutral precursor mass.
      double precursor_mass = std::numeric_limits<double>::quiet_NaN();
      if (feats.mass[fi] > 0.0f)
        precursor_mass = static_cast<double>(feats.mass[fi]);
      else if (feats.mz[fi] > 0.0f)
        precursor_mass = static_cast<double>(feats.mz[fi]) -
                         feats.polarity[fi] * 1.007276;
      if (std::isnan(precursor_mass))
        continue;

      // Build safe file-name stem.
      std::string sid         = safe_id(ana, feats.feature[fi]);
      const bool has_ms2 = !ms2_mz.empty();
      std::string ms2_path    = has_ms2 ? (run_dir + "/ms2_" + sid + ".txt") : shared_empty_peak_list;
      std::string params_path = run_dir + "/metfrag_" + sid + ".params";
      std::string log_path    = run_dir + "/metfrag_" + sid + ".log";
      std::string debug_path  = run_dir + "/metfrag_" + sid + ".debug.txt";
      std::string sample_name = "metfrag_" + sid;

      if (has_ms2)
        write_peak_list(ms2_path, ms2_mz, ms2_int);

      // Write parameter file.
      write_params_file(params_path, common_params_template, precursor_mass,
                        feats.polarity[fi], ms2_path, sample_name);

      // Optional debug metadata file.
      if (params.debug)
      {
        std::ofstream dbg(debug_path);
        dbg << "analysis="     << ana                << "\n"
            << "feature="      << feats.feature[fi]  << "\n"
            << "polarity="     << feats.polarity[fi]  << "\n"
            << "precursor_mass=" << precursor_mass    << "\n"
            << "ms2_points="   << ms2_mz.size()       << "\n"
            << "ms2_file="     << ms2_path            << "\n"
            << "params_file="  << params_path         << "\n"
            << "results_path=" << run_dir             << "\n";
      }

      // -- Invoke MetFragCL --------------------------------------------------
      int status = run_metfrag(params.metfrag_path, params.java_path, params_path, log_path);

      // -- Parse output CSV --------------------------------------------------
      std::vector<MetFragRow> rows = parse_metfrag_csv(run_dir, sample_name);
      std::vector<std::string> csv_paths = collect_metfrag_result_files(run_dir, sample_name);

      if (params.debug)
      {
        std::ofstream dbg(debug_path, std::ios::app);
        dbg << "metfrag_exit_status=" << status << "\n"
            << "csv_rows_found=" << rows.size() << "\n";
        if (rows.empty())
        {
          // Append last 20 lines of the MetFrag log to the debug file.
          std::ifstream log_in(log_path);
          std::vector<std::string> log_lines;
          std::string ln;
          while (std::getline(log_in, ln)) log_lines.push_back(ln);
          dbg << "--- log tail ---\n";
          int start = std::max(0, static_cast<int>(log_lines.size()) - 20);
          for (int li = start; li < static_cast<int>(log_lines.size()); ++li)
            dbg << log_lines[li] << "\n";
        }
      }

      if (rows.empty())
      {
        if (params.debug)
        {
          std::cerr << "[metfrag] No results for feature " << feats.feature[fi]
                    << " (mass=" << precursor_mass
                    << ", status=" << status << ")\n";
        }
        if (!params.debug)
        {
          if (has_ms2)
            fs::remove(ms2_path);
          fs::remove(params_path);
          for (const auto &csv_path : csv_paths)
            fs::remove(csv_path);
        }
        continue;
      }

      int rank = 1;
      for (const MetFragRow &row : rows)
      {
        if (rank > params.top_n)
          break;

        // Decode MetFrag's ExplPeaks into parallel mz/intensity vectors.
        std::vector<double> db_mz, db_int;
        std::string db_form;
        parse_expl_peaks(row.expl_peaks, row.expl_formulas, db_mz, db_int, db_form);

        // Encode explained fragments for SUSPECT storage.
        std::vector<float> db_mzf(db_mz.begin(), db_mz.end());
        std::vector<float> db_intf(db_int.begin(), db_int.end());
        std::string db_ms2_mz_enc  = nta::utils::encode_floats_base64(db_mzf);
        std::string db_ms2_int_enc = nta::utils::encode_floats_base64(db_intf);

        // Cosine similarity between explained peaks and experimental MS2.
        int shared = 0;
        double cosine = 0.0;
        if (!db_mz.empty() && !ms2_mz.empty())
          cosine = cosine_similarity(db_mz, db_int, ms2_mz, ms2_int,
                                     params.ppmMS2, params.mzrMS2, shared);

        // Mass error (ppm).
        double error_mass = std::numeric_limits<double>::quiet_NaN();
        if (!std::isnan(row.neutral_mass) && precursor_mass > 0.0)
          error_mass = std::round(
              ((precursor_mass - row.neutral_mass) / precursor_mass) * 1e6 * 10.0) / 10.0;

        // RT post-filter: skip candidate if database RT is known and out of tolerance.
        double db_rt_val  = std::numeric_limits<double>::quiet_NaN();
        double error_rt   = std::numeric_limits<double>::quiet_NaN();
        if (!std::isnan(db_rt_val) &&
            std::abs(static_cast<double>(feats.rt[fi]) - db_rt_val) > params.sec)
        {
          ++rank;
          continue;
        }
        if (!std::isnan(db_rt_val))
          error_rt = static_cast<double>(feats.rt[fi]) - db_rt_val;

        // Assign identification level.
        bool rt_match  = (!std::isnan(db_rt_val) &&
                           std::abs(static_cast<double>(feats.rt[fi]) - db_rt_val) <= params.sec);
        bool ms2_match = (shared > 0);
        int  id_level  = 4;
        if      (rt_match && ms2_match) id_level = 1;
        else if (ms2_match)             id_level = 2;
        else if (rt_match)              id_level = 3;

        // Populate SUSPECT.
        nta::api::NTA_SUSPECT_ROW s;
        s.analysis           = ana;
        s.feature            = feats.feature[fi];
        s.candidate_rank     = rank;
        s.name               = row.name.empty() ? row.database_id : row.name;
        s.polarity           = feats.polarity[fi];
        s.db_mass            = row.neutral_mass;
        s.exp_mass           = precursor_mass;
        s.error_mass         = error_mass;
        s.db_rt              = db_rt_val;
        s.exp_rt             = static_cast<double>(feats.rt[fi]);
        s.error_rt           = error_rt;
        s.intensity          = static_cast<double>(feats.intensity[fi]);
        s.area               = static_cast<double>(feats.area[fi]);
        s.id_level           = id_level;
        s.score              = row.score;
        s.shared_fragments   = shared;
        s.cosine_similarity  = cosine;
        s.formula            = row.formula;
        s.SMILES             = row.SMILES;
        s.InChI              = row.InChI;
        s.InChIKey           = row.InChIKey;
        s.xLogP              = row.xLogP;
        s.database_id        = row.database_id;
        s.db_ms2_size        = static_cast<int>(db_mz.size());
        s.db_ms2_mz          = db_ms2_mz_enc;
        s.db_ms2_intensity   = db_ms2_int_enc;
        s.db_ms2_formula     = db_form;
        s.exp_ms2_size       = feats.ms2_size[fi];
        s.exp_ms2_mz         = feats.ms2_mz[fi];
        s.exp_ms2_intensity  = feats.ms2_intensity[fi];

        suspect_buffers[ai].append(s);
        ++rank;
        ++n_suspects_found;
      }

      if (!params.debug)
      {
        if (has_ms2)
          fs::remove(ms2_path);
        fs::remove(params_path);
        for (const auto &csv_path : csv_paths)
          fs::remove(csv_path);
        if (status == 0)
          fs::remove(log_path);
      }
    } // features

    std::cout << "  Found " << n_suspects_found << " suspect(s) in " << ana << std::endl;
  } // analyses
}

} // namespace nta::metfrag_runner
