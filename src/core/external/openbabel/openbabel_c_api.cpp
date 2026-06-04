#include "streamfind_openbabel_api.h"

#include <algorithm>
#include <cmath>
#include <cctype>
#include <cstring>
#include <limits>
#include <sstream>
#include <string>

#include <openbabel/descriptor.h>
#include <openbabel/mol.h>
#include <openbabel/obconversion.h>
#include <openbabel/oberror.h>

namespace
{
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
}
