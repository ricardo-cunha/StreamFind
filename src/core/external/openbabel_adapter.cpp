#include "openbabel_adapter.h"

#include "openbabel/streamfind_openbabel_api.h"

#include <string>

#ifdef _WIN32
#include <windows.h>
#include <vector>
#endif

namespace sf::obabel
{
  NormalizedStructure from_c_result(
      const streamfind_ob_normalized_result &result)
  {
    NormalizedStructure out;
    out.ok = result.ok != 0;
    out.error = result.error;
    out.canonical_smiles = result.canonical_smiles;
    out.formula = result.formula;
    out.inchi = result.inchi;
    out.inchikey = result.inchikey;
    out.exact_mass = result.exact_mass;
    out.xlogp = result.xlogp;
    out.has_xlogp = result.has_xlogp != 0;
    return out;
  }

#ifdef _WIN32
  using openbabel_available_fn = int (*)();
  using normalize_structure_fn = int (*)(const char *, const char *, streamfind_ob_normalized_result *);

  struct OpenBabelApi
  {
    HMODULE module = nullptr;
    openbabel_available_fn available = nullptr;
    normalize_structure_fn normalize = nullptr;
    std::string error;
  };

  std::wstring parent_directory(const std::wstring &path)
  {
    const size_t pos = path.find_last_of(L"\\/");
    if (pos == std::wstring::npos)
      return L"";
    return path.substr(0, pos);
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

  OpenBabelApi load_openbabel_api()
  {
    OpenBabelApi api;

    HMODULE self = nullptr;
    if (!GetModuleHandleExW(
            GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
            reinterpret_cast<LPCWSTR>(&load_openbabel_api),
            &self))
    {
      api.error = "GetModuleHandleExW failed for StreamFind module.";
      return api;
    }

    std::vector<wchar_t> module_path(MAX_PATH, L'\0');
    DWORD path_size = GetModuleFileNameW(self, module_path.data(), static_cast<DWORD>(module_path.size()));
    if (path_size == 0)
    {
      api.error = "GetModuleFileNameW failed for StreamFind module.";
      return api;
    }
    if (path_size >= module_path.size())
    {
      module_path.resize(path_size + 1, L'\0');
      path_size = GetModuleFileNameW(self, module_path.data(), static_cast<DWORD>(module_path.size()));
      if (path_size == 0)
      {
        api.error = "GetModuleFileNameW failed for StreamFind module.";
        return api;
      }
    }

    const std::wstring module_dir = parent_directory(std::wstring(module_path.data(), path_size));
    const std::wstring cwd = current_working_directory();
    const std::vector<std::wstring> dll_candidates = {
        module_dir + L"\\openbabel_streamfind.dll",
        module_dir + L"\\core\\external\\openbabel\\build\\windows\\bin\\openbabel_streamfind.dll",
        cwd.empty() ? L"" : cwd + L"\\src\\core\\external\\openbabel\\build\\windows\\bin\\openbabel_streamfind.dll",
        cwd.empty() ? L"" : cwd + L"\\inst\\libs\\x64\\openbabel_streamfind.dll"};

    std::wstring loaded_path;
    for (const auto &dll_path : dll_candidates)
    {
      if (dll_path.empty())
        continue;
      api.module = LoadLibraryW(dll_path.c_str());
      if (api.module != nullptr)
      {
        loaded_path = dll_path;
        break;
      }
    }

    if (api.module == nullptr)
    {
      api.error = "Could not load openbabel_streamfind.dll from expected locations near " +
                  std::string(module_dir.begin(), module_dir.end());
      return api;
    }

    api.available = reinterpret_cast<openbabel_available_fn>(
        GetProcAddress(api.module, "sf_ob_openbabel_available"));
    api.normalize = reinterpret_cast<normalize_structure_fn>(
        GetProcAddress(api.module, "sf_ob_normalize_structure"));

    if (api.available == nullptr || api.normalize == nullptr)
    {
      api.error = "Could not resolve Open Babel StreamFind API exports from " +
                  std::string(loaded_path.begin(), loaded_path.end());
      FreeLibrary(api.module);
      api.module = nullptr;
      api.available = nullptr;
      api.normalize = nullptr;
    }

    return api;
  }
#endif

  bool openbabel_available()
  {
#ifdef _WIN32
    const OpenBabelApi api = load_openbabel_api();
    return api.available != nullptr && api.available() != 0;
#else
    return sf_ob_openbabel_available() != 0;
#endif
  }

  NormalizedStructure normalize_structure(
      const std::string &smiles,
      const std::string &inchi)
  {
#ifdef _WIN32
    const OpenBabelApi api = load_openbabel_api();
    if (api.normalize == nullptr)
    {
      NormalizedStructure out;
      out.error = api.error.empty() ? "Open Babel runtime unavailable." : api.error;
      return out;
    }

    streamfind_ob_normalized_result result{};
    api.normalize(
        smiles.empty() ? nullptr : smiles.c_str(),
        inchi.empty() ? nullptr : inchi.c_str(),
        &result);
    return from_c_result(result);
#else
    streamfind_ob_normalized_result result{};
    sf_ob_normalize_structure(
        smiles.empty() ? nullptr : smiles.c_str(),
        inchi.empty() ? nullptr : inchi.c_str(),
        &result);
    return from_c_result(result);
#endif
  }
} // namespace sf::obabel
