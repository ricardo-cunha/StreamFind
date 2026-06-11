#include "streamfind_openbabel_api.h"

#include <algorithm>
#include <cmath>
#include <cctype>
#include <cstring>
#include <limits>
#include <sstream>
#include <string>
#include <cstdlib>
#include <mutex>

#ifdef _WIN32
#include <windows.h>
#include <vector>
#endif

#include <openbabel/descriptor.h>
#include <openbabel/groupcontrib.h>
#include <openbabel/mol.h>
#include <openbabel/obconversion.h>
#include <openbabel/oberror.h>
#include <openbabel/tokenst.h>

namespace
{
#ifdef _WIN32
  std::wstring widen_path(const std::string &path)
  {
    return std::wstring(path.begin(), path.end());
  }

  std::string narrow_path(const std::wstring &path)
  {
    return std::string(path.begin(), path.end());
  }

  std::wstring parent_directory(const std::wstring &path)
  {
    const size_t pos = path.find_last_of(L"\\/");
    if (pos == std::wstring::npos)
      return L"";
    return path.substr(0, pos);
  }

  bool directory_exists(const std::wstring &path)
  {
    if (path.empty())
      return false;
    const DWORD attributes = GetFileAttributesW(path.c_str());
    return attributes != INVALID_FILE_ATTRIBUTES &&
           (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
  }

  std::wstring current_working_directory()
  {
    DWORD size = GetCurrentDirectoryW(0, nullptr);
    if (size == 0)
      return L"";
    std::vector<wchar_t> buffer(size, L'\0');
    DWORD written = GetCurrentDirectoryW(size, buffer.data());
    if (written == 0 || written >= size)
      return L"";
    return std::wstring(buffer.data(), written);
  }

  std::wstring current_module_path()
  {
    HMODULE self = nullptr;
    if (!GetModuleHandleExW(
            GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
            reinterpret_cast<LPCWSTR>(&current_module_path),
            &self))
      return L"";

    std::vector<wchar_t> module_path(MAX_PATH, L'\0');
    DWORD path_size = GetModuleFileNameW(self, module_path.data(), static_cast<DWORD>(module_path.size()));
    if (path_size == 0)
      return L"";
    if (path_size >= module_path.size())
    {
      module_path.resize(path_size + 1, L'\0');
      path_size = GetModuleFileNameW(self, module_path.data(), static_cast<DWORD>(module_path.size()));
      if (path_size == 0)
        return L"";
    }
    return std::wstring(module_path.data(), path_size);
  }

  bool ensure_openbabel_data_dir()
  {
    static bool configured = false;
    static std::once_flag configure_once;
    std::call_once(configure_once, []() {
      const std::wstring module_path = current_module_path();
      const std::wstring module_dir = parent_directory(module_path);
      const std::wstring parent1 = parent_directory(module_dir);
      const std::wstring parent2 = parent_directory(parent1);
      const std::wstring parent3 = parent_directory(parent2);
      const std::wstring parent4 = parent_directory(parent3);
      const std::wstring cwd = current_working_directory();
      const std::wstring source_file = widen_path(__FILE__);
      const std::wstring source_dir = parent_directory(source_file);
      const std::wstring source_root = parent_directory(source_dir);

      const std::vector<std::wstring> candidates = {
          module_dir + L"\\openbabel-3-2-0\\data",
          parent2.empty() ? L"" : parent2 + L"\\openbabel-3-2-0\\data",
          parent3.empty() ? L"" : parent3 + L"\\openbabel-3-2-0\\data",
          parent4.empty() ? L"" : parent4 + L"\\openbabel-3-2-0\\data",
          source_root.empty() ? L"" : source_root + L"\\openbabel-3-2-0\\data",
          cwd.empty() ? L"" : cwd + L"\\src\\core\\external\\openbabel\\openbabel-3-2-0\\data"};

      for (const auto &candidate : candidates)
      {
        if (!directory_exists(candidate))
          continue;
        configured = SetEnvironmentVariableW(L"BABEL_DATADIR", candidate.c_str()) != 0;
        if (configured)
        {
          const std::string narrow_candidate(candidate.begin(), candidate.end());
          configured = _putenv_s("BABEL_DATADIR", narrow_candidate.c_str()) == 0;
        }
        if (configured)
          return;
      }
    });

    return configured;
  }

  std::string debug_openbabel_runtime()
  {
    const std::wstring module_path = current_module_path();
    const std::wstring module_dir = parent_directory(module_path);
    const std::wstring parent1 = parent_directory(module_dir);
    const std::wstring parent2 = parent_directory(parent1);
    const std::wstring parent3 = parent_directory(parent2);
    const std::wstring parent4 = parent_directory(parent3);
    const std::wstring cwd = current_working_directory();
    const std::wstring source_file = widen_path(__FILE__);
    const std::wstring source_dir = parent_directory(source_file);
    const std::wstring source_root = parent_directory(source_dir);
    const char *env = std::getenv("BABEL_DATADIR");

    const std::vector<std::wstring> candidates = {
        module_dir + L"\\openbabel-3-2-0\\data",
        parent2.empty() ? L"" : parent2 + L"\\openbabel-3-2-0\\data",
        parent3.empty() ? L"" : parent3 + L"\\openbabel-3-2-0\\data",
        parent4.empty() ? L"" : parent4 + L"\\openbabel-3-2-0\\data",
        source_root.empty() ? L"" : source_root + L"\\openbabel-3-2-0\\data",
        cwd.empty() ? L"" : cwd + L"\\src\\core\\external\\openbabel\\openbabel-3-2-0\\data"};

    std::ostringstream oss;
    oss << "module_path=" << narrow_path(module_path) << "\n";
    oss << "cwd=" << narrow_path(cwd) << "\n";
    oss << "__FILE__=" << __FILE__ << "\n";
    oss << "env.BABEL_DATADIR=" << (env != nullptr ? env : "<unset>") << "\n";
    oss << "ensure_openbabel_data_dir=" << (ensure_openbabel_data_dir() ? "ok" : "failed") << "\n";
    env = std::getenv("BABEL_DATADIR");
    oss << "env.BABEL_DATADIR.after=" << (env != nullptr ? env : "<unset>") << "\n";
    for (size_t i = 0; i < candidates.size(); ++i)
    {
      oss << "candidate[" << i << "]=" << narrow_path(candidates[i])
          << " exists=" << (directory_exists(candidates[i]) ? "true" : "false") << "\n";
    }

    std::ifstream logp_stream;
    const std::string opened_logp = OpenBabel::OpenDatafile(logp_stream, "logp.txt");
    oss << "OpenDatafile(logp.txt)=" << (opened_logp.empty() ? "<empty>" : opened_logp) << "\n";
    oss << "OpenDatafile(logp.txt).good=" << (logp_stream.good() ? "true" : "false") << "\n";

    std::ifstream psa_stream;
    const std::string opened_psa = OpenBabel::OpenDatafile(psa_stream, "psa.txt");
    oss << "OpenDatafile(psa.txt)=" << (opened_psa.empty() ? "<empty>" : opened_psa) << "\n";
    oss << "OpenDatafile(psa.txt).good=" << (psa_stream.good() ? "true" : "false") << "\n";

    std::ifstream mr_stream;
    const std::string opened_mr = OpenBabel::OpenDatafile(mr_stream, "mr.txt");
    oss << "OpenDatafile(mr.txt)=" << (opened_mr.empty() ? "<empty>" : opened_mr) << "\n";
    oss << "OpenDatafile(mr.txt).good=" << (mr_stream.good() ? "true" : "false") << "\n";

    OpenBabel::OBDescriptor *logp_desc = OpenBabel::OBDescriptor::FindType("logP");
    oss << "OBDescriptor::FindType(logP)=" << (logp_desc != nullptr ? "found" : "null") << "\n";
    if (logp_desc != nullptr)
    {
      OpenBabel::OBMol test_mol;
      OpenBabel::OBConversion conv;
      const bool in_ok = conv.SetInFormat("smi");
      const bool read_ok = in_ok && conv.ReadString(&test_mol, "c1ccccc1");
      oss << "testmol.read_ok=" << (read_ok ? "true" : "false") << "\n";
      if (read_ok)
      {
        const double pred = logp_desc->Predict(&test_mol);
        oss << "logP.predict.benzene=" << pred << "\n";
      }
    }

    return oss.str();
  }
#endif

  std::string trim_copy(const std::string &value)
  {
    const auto begin = std::find_if_not(value.begin(), value.end(), [](unsigned char ch) {
      return std::isspace(ch) != 0;
    });
    const auto end = std::find_if_not(value.rbegin(), value.rend(), [](unsigned char ch) {
      return std::isspace(ch) != 0;
    }).base();
    if (begin >= end)
      return "";
    return std::string(begin, end);
  }

  std::string normalize_formula(const std::string &formula)
  {
    std::string out;
    out.reserve(formula.size() + 8);
    for (size_t i = 0; i < formula.size(); ++i)
    {
      if (formula[i] == 'D')
      {
        out += "[2H]";
      }
      else if (formula[i] == 'T')
      {
        out += "[3H]";
      }
      else
      {
        out += formula[i];
      }
    }
    return out;
  }

  bool finite_value(double value)
  {
#ifdef _WIN32
    return _finite(value) != 0;
#else
    return std::isfinite(value);
#endif
  }

  bool read_molecule(OpenBabel::OBMol &mol,
                     const std::string &source,
                     const char *format_id,
                     std::string &error)
  {
    OpenBabel::OBConversion conv;
    if (!conv.SetInFormat(format_id))
    {
      error = std::string("Open Babel format unavailable: ") + format_id;
      return false;
    }
    if (!conv.ReadString(&mol, source))
    {
      error = std::string("Open Babel could not parse ") + format_id;
      return false;
    }
    return mol.NumAtoms() > 0;
  }

  std::string write_molecule(OpenBabel::OBMol &mol,
                             const char *format_id,
                             std::string &error)
  {
    OpenBabel::OBConversion conv;
    if (!conv.SetOutFormat(format_id))
    {
      error = std::string("Open Babel format unavailable: ") + format_id;
      return "";
    }
    const std::string result = trim_copy(conv.WriteString(&mol, true));
    if (result.empty())
    {
      error = std::string("Open Babel could not write ") + format_id;
    }
    return result;
  }

  void zero_result(streamfind_ob_normalized_result *out)
  {
    if (out != nullptr)
      std::memset(out, 0, sizeof(*out));
  }

  void zero_svg_result(streamfind_ob_svg_result *out)
  {
    if (out != nullptr)
      std::memset(out, 0, sizeof(*out));
  }

  void copy_text(char *dest, size_t capacity, const std::string &value)
  {
    if (dest == nullptr || capacity == 0)
      return;
    std::strncpy(dest, value.c_str(), capacity - 1);
    dest[capacity - 1] = '\0';
  }

  std::string normalize_svg_output(std::string svg, int width_px, int height_px)
  {
    if (width_px > 0)
    {
      const std::string width_attr = "width=\"";
      const size_t width_pos = svg.find(width_attr);
      if (width_pos != std::string::npos)
      {
        const size_t width_end = svg.find('"', width_pos + width_attr.size());
        if (width_end != std::string::npos)
        {
          svg.replace(width_pos + width_attr.size(), width_end - (width_pos + width_attr.size()), std::to_string(width_px) + "px");
        }
      }
    }
    if (height_px > 0)
    {
      const std::string height_attr = "height=\"";
      const size_t height_pos = svg.find(height_attr);
      if (height_pos != std::string::npos)
      {
        const size_t height_end = svg.find('"', height_pos + height_attr.size());
        if (height_end != std::string::npos)
        {
          svg.replace(height_pos + height_attr.size(), height_end - (height_pos + height_attr.size()), std::to_string(height_px) + "px");
        }
      }
    }

    const std::string rect_token = "<rect";
    const std::string fill_token = "fill=\"none\"";
    size_t search_pos = 0;
    while ((search_pos = svg.find(rect_token, search_pos)) != std::string::npos)
    {
      const size_t tag_end = svg.find('>', search_pos);
      if (tag_end == std::string::npos)
        break;
      const std::string tag = svg.substr(search_pos, tag_end - search_pos + 1);
      if (tag.find(fill_token) == std::string::npos &&
          tag.find("width=\"100%\"") != std::string::npos &&
          tag.find("height=\"100%\"") != std::string::npos)
      {
        svg.erase(search_pos, tag_end - search_pos + 1);
        continue;
      }
      search_pos = tag_end + 1;
    }
    return svg;
  }
}

extern "C"
{
  int sf_ob_openbabel_available(void)
  {
#ifdef _WIN32
    ensure_openbabel_data_dir();
#endif
    return OpenBabel::OBConversion::FindFormat("smi") != nullptr &&
           OpenBabel::OBConversion::FindFormat("can") != nullptr &&
           OpenBabel::OBConversion::FindFormat("inchi") != nullptr &&
           OpenBabel::OBConversion::FindFormat("inchikey") != nullptr;
  }

  int sf_ob_normalize_structure(
    const char *smiles,
    const char *inchi,
    streamfind_ob_normalized_result *out)
  {
    zero_result(out);
    if (out == nullptr)
      return 0;

#ifdef _WIN32
    ensure_openbabel_data_dir();
#endif
    OpenBabel::obErrorLog.SetOutputLevel(OpenBabel::obError);

    OpenBabel::OBMol mol;
    std::string parse_error;
    bool parsed = false;

    if (smiles != nullptr && *smiles != '\0')
      parsed = read_molecule(mol, smiles, "smi", parse_error);
    if (!parsed && inchi != nullptr && *inchi != '\0')
    {
      mol.Clear();
      parsed = read_molecule(mol, inchi, "inchi", parse_error);
    }
    if (!parsed)
    {
      copy_text(out->error, STREAMFIND_OB_ERROR_CAPACITY,
                parse_error.empty() ? std::string("No valid structure source available.") : parse_error);
      return 0;
    }

    std::string error;
    const std::string canonical_smiles = write_molecule(mol, "can", error);
    if (!error.empty())
    {
      copy_text(out->error, STREAMFIND_OB_ERROR_CAPACITY, error);
      return 0;
    }

    const std::string normalized_inchi = write_molecule(mol, "inchi", error);
    if (!error.empty())
    {
      copy_text(out->error, STREAMFIND_OB_ERROR_CAPACITY, error);
      return 0;
    }

    const std::string inchikey = write_molecule(mol, "inchikey", error);
    if (!error.empty())
    {
      copy_text(out->error, STREAMFIND_OB_ERROR_CAPACITY, error);
      return 0;
    }

    copy_text(out->canonical_smiles, STREAMFIND_OB_SMILES_CAPACITY, canonical_smiles);
    copy_text(out->inchi, STREAMFIND_OB_INCHI_CAPACITY, normalized_inchi);
    copy_text(out->inchikey, STREAMFIND_OB_INCHIKEY_CAPACITY, inchikey);
    copy_text(out->formula, STREAMFIND_OB_FORMULA_CAPACITY, normalize_formula(mol.GetFormula()));
    out->exact_mass = mol.GetExactMass();

    if (OpenBabel::OBDescriptor *logp = OpenBabel::OBDescriptor::FindType("logP"))
    {
      const double value = logp->Predict(&mol);
      if (finite_value(value))
      {
        out->xlogp = value;
        out->has_xlogp = 1;
      }
    }

    out->ok = 1;
    return 1;
  }

  int sf_ob_render_structure_svg(
    const char *smiles,
    const char *inchi,
    int width_px,
    int height_px,
    const char *bond_color,
    streamfind_ob_svg_result *out)
  {
    zero_svg_result(out);
    if (out == nullptr)
      return 0;

#ifdef _WIN32
    ensure_openbabel_data_dir();
#endif
    OpenBabel::obErrorLog.SetOutputLevel(OpenBabel::obError);

    OpenBabel::OBMol mol;
    std::string parse_error;
    bool parsed = false;

    if (smiles != nullptr && *smiles != '\0')
      parsed = read_molecule(mol, smiles, "smi", parse_error);
    if (!parsed && inchi != nullptr && *inchi != '\0')
    {
      mol.Clear();
      parsed = read_molecule(mol, inchi, "inchi", parse_error);
    }
    if (!parsed)
    {
      copy_text(out->error, STREAMFIND_OB_ERROR_CAPACITY,
                parse_error.empty() ? std::string("No valid structure source available.") : parse_error);
      return 0;
    }

    OpenBabel::OBConversion conv;
    if (!conv.SetOutFormat("svg"))
    {
      copy_text(out->error, STREAMFIND_OB_ERROR_CAPACITY, "Open Babel format unavailable: svg");
      return 0;
    }

    conv.AddOption("b", OpenBabel::OBConversion::OUTOPTIONS, "none");
    if (bond_color != nullptr && *bond_color != '\0')
      conv.AddOption("B", OpenBabel::OBConversion::OUTOPTIONS, bond_color);
    std::string error;
    std::string svg = trim_copy(conv.WriteString(&mol, true));
    if (svg.empty())
    {
      copy_text(out->error, STREAMFIND_OB_ERROR_CAPACITY, "Open Babel could not write svg");
      return 0;
    }

    svg = normalize_svg_output(svg, width_px, height_px);
    copy_text(out->svg, STREAMFIND_OB_SVG_CAPACITY, svg);
    out->ok = 1;
    return 1;
  }

  int sf_ob_debug_runtime(
    char *out,
    size_t capacity)
  {
    if (out == nullptr || capacity == 0)
      return 0;
#ifdef _WIN32
    const std::string text = debug_openbabel_runtime();
#else
    const std::string text = "Open Babel runtime debug is only implemented on Windows.";
#endif
    std::strncpy(out, text.c_str(), capacity - 1);
    out[capacity - 1] = '\0';
    return 1;
  }
}
