#include <Rcpp.h>

#include <fstream>

#include "core/external/openbabel_adapter.h"

namespace obabel
{
  // Shared helpers for the native Open Babel Rcpp bridge.
  static inline bool has_column(const Rcpp::DataFrame &df, const char *name)
  {
    return df.containsElementNamed(name);
  }

  static inline std::string string_at(const Rcpp::CharacterVector &values, R_xlen_t index)
  {
    if (index < 0 || index >= values.size() || Rcpp::CharacterVector::is_na(values[index]))
    {
      return std::string();
    }
    return Rcpp::as<std::string>(values[index]);
  }

  static inline double numeric_at(const Rcpp::NumericVector &values, R_xlen_t index)
  {
    if (index < 0 || index >= values.size() || Rcpp::NumericVector::is_na(values[index]))
    {
      return NA_REAL;
    }
    return static_cast<double>(values[index]);
  }

  static inline Rcpp::CharacterVector empty_character_column(R_xlen_t size, const char *value = "")
  {
    Rcpp::CharacterVector out(size);
    for (R_xlen_t i = 0; i < size; ++i)
    {
      out[i] = value;
    }
    return out;
  }

  static inline Rcpp::DataFrame as_data_frame(
    const Rcpp::CharacterVector &name,
    const Rcpp::CharacterVector &formula,
    const Rcpp::NumericVector &mass,
    const Rcpp::NumericVector &rt,
    const Rcpp::CharacterVector &smiles,
    const Rcpp::CharacterVector &inchi,
    const Rcpp::CharacterVector &inchikey,
    const Rcpp::NumericVector &xlogp,
    const Rcpp::CharacterVector &ms2_positive,
    const Rcpp::CharacterVector &ms2_negative)
  {
    const R_xlen_t n = name.size();
    Rcpp::List out(10);
    out[0] = name;
    out[1] = formula;
    out[2] = mass;
    out[3] = rt;
    out[4] = smiles;
    out[5] = inchi;
    out[6] = inchikey;
    out[7] = xlogp;
    out[8] = ms2_positive;
    out[9] = ms2_negative;
    out.attr("names") = Rcpp::CharacterVector::create(
      "name", "formula", "mass", "rt", "SMILES",
      "InChI", "InChIKey", "xLogP", "ms2_positive", "ms2_negative");
    out.attr("class") = "data.frame";
    out.attr("row.names") = Rcpp::IntegerVector::create(NA_INTEGER, -static_cast<int>(n));
    return Rcpp::DataFrame(out);
  }

  static inline void maybe_write_csv(const Rcpp::DataFrame &out, const Rcpp::Nullable<std::string> &file)
  {
    if (file.isNull())
    {
      return;
    }
    const std::string file_path = Rcpp::as<std::string>(file);
    if (file_path.empty())
    {
      return;
    }

    Rcpp::Environment dt = Rcpp::Environment::namespace_env("data.table");
    Rcpp::Function fwrite = dt["fwrite"];
    fwrite(Rcpp::Named("x") = out, Rcpp::Named("file") = file_path);
  }
}

//' Render a structure as SVG with the native Open Babel backend
//'
//' Converts a `SMILES` or `InChI` structure into an SVG depiction using the
//' embedded Open Babel runtime. The returned SVG has a transparent background.
//'
//' @param SMILES Optional structure in SMILES format.
//' @param InChI Optional structure in InChI format.
//' @param width Width in pixels.
//' @param height Height in pixels.
//' @param darkMode Logical, use a light bond color suitable for dark backgrounds.
//' @return A length-one character string containing SVG markup, or `""` on failure.
//' @export
// [[Rcpp::export]]
std::string rcpp_openbabel_structure_svg(
  Rcpp::Nullable<std::string> SMILES = R_NilValue,
  Rcpp::Nullable<std::string> InChI = R_NilValue,
  int width = 140,
  int height = 120,
  bool darkMode = false)
{
  const std::string smiles = SMILES.isNull() ? std::string() : Rcpp::as<std::string>(SMILES);
  const std::string inchi = InChI.isNull() ? std::string() : Rcpp::as<std::string>(InChI);
  const std::string bond_color = darkMode ? "#e6edf4" : "#1e2129";
  const sf::obabel::StructureSvg svg = sf::obabel::render_structure_svg(
    smiles,
    inchi,
    width,
    height,
    bond_color
  );
  return svg.ok ? svg.svg : std::string();
}

//' Inspect the native Open Babel runtime paths
//'
//' Returns diagnostic text describing the loaded Open Babel module path,
//' `BABEL_DATADIR`, and candidate data directories considered at runtime.
//'
//' @return A length-one character string with runtime diagnostics.
//' @export
// [[Rcpp::export]]
std::string rcpp_openbabel_debug_runtime()
{
  return sf::obabel::debug_runtime();
}

//' Create a suspect screening table with the native Open Babel backend
//'
//' Normalizes suspect structures with the embedded Open Babel runtime and
//' returns the standard suspect-screening columns. When `file` is provided, the
//' resulting table is also written as CSV using `data.table::fwrite()`.
//'
//' @param suspects A `data.frame` with required column `name` and at least one
//'   structure column from `SMILES` or `InChI`. Optional columns `rt`,
//'   `ms2_positive`, and `ms2_negative` are preserved.
//' @param file Optional output CSV path. When provided, the normalized table is
//'   written to disk.
//' @return A `data.frame` with columns `name`, `formula`, `mass`, `rt`,
//'   `SMILES`, `InChI`, `InChIKey`, `xLogP`, `ms2_positive`, and
//'   `ms2_negative`.
//' @export
// [[Rcpp::export]]
Rcpp::DataFrame rcpp_get_suspects_screening_csv(
  Rcpp::DataFrame suspects,
  Rcpp::Nullable<std::string> file = R_NilValue)
{
  if (!obabel::has_column(suspects, "name"))
  {
    Rcpp::stop("suspects must include 'name' column.");
  }

  const bool has_smiles = obabel::has_column(suspects, "SMILES");
  const bool has_inchi = obabel::has_column(suspects, "InChI");
  if (!has_smiles && !has_inchi)
  {
    Rcpp::stop("suspects must include either 'SMILES' or 'InChI' column.");
  }

  const Rcpp::CharacterVector names = suspects["name"];
  const R_xlen_t n = names.size();

  const Rcpp::CharacterVector smiles_in = has_smiles
    ? Rcpp::CharacterVector(suspects["SMILES"])
    : Rcpp::CharacterVector(n, NA_STRING);
  const Rcpp::CharacterVector inchi_in = has_inchi
    ? Rcpp::CharacterVector(suspects["InChI"])
    : Rcpp::CharacterVector(n, NA_STRING);

  const bool has_rt = obabel::has_column(suspects, "rt");
  const Rcpp::NumericVector rt_in = has_rt
    ? Rcpp::NumericVector(suspects["rt"])
    : Rcpp::NumericVector(n, NA_REAL);

  const bool has_ms2_positive = obabel::has_column(suspects, "ms2_positive");
  const bool has_ms2_negative = obabel::has_column(suspects, "ms2_negative");
  const Rcpp::CharacterVector ms2_positive_in = has_ms2_positive
    ? Rcpp::CharacterVector(suspects["ms2_positive"])
    : obabel::empty_character_column(n);
  const Rcpp::CharacterVector ms2_negative_in = has_ms2_negative
    ? Rcpp::CharacterVector(suspects["ms2_negative"])
    : obabel::empty_character_column(n);

  Rcpp::CharacterVector out_name(n);
  Rcpp::CharacterVector out_formula(n, NA_STRING);
  Rcpp::NumericVector out_mass(n, NA_REAL);
  Rcpp::NumericVector out_rt(n, NA_REAL);
  Rcpp::CharacterVector out_smiles(n, NA_STRING);
  Rcpp::CharacterVector out_inchi(n, NA_STRING);
  Rcpp::CharacterVector out_inchikey(n, NA_STRING);
  Rcpp::NumericVector out_xlogp(n, NA_REAL);
  Rcpp::CharacterVector out_ms2_positive(n);
  Rcpp::CharacterVector out_ms2_negative(n);

  for (R_xlen_t i = 0; i < n; ++i)
  {
    const std::string name = obabel::string_at(names, i);
    const std::string smiles = obabel::string_at(smiles_in, i);
    const std::string inchi = obabel::string_at(inchi_in, i);

    out_name[i] = name;
    out_rt[i] = obabel::numeric_at(rt_in, i);
    out_ms2_positive[i] = obabel::string_at(ms2_positive_in, i);
    out_ms2_negative[i] = obabel::string_at(ms2_negative_in, i);

    if (smiles.empty() && inchi.empty())
    {
      continue;
    }

    const sf::obabel::NormalizedStructure normalized =
      sf::obabel::normalize_structure(smiles, inchi);

    if (normalized.ok)
    {
      if (!normalized.formula.empty())
      {
        out_formula[i] = normalized.formula;
      }
      out_mass[i] = normalized.exact_mass;
      if (!normalized.canonical_smiles.empty())
      {
        out_smiles[i] = normalized.canonical_smiles;
      }
      if (!normalized.inchi.empty())
      {
        out_inchi[i] = normalized.inchi;
      }
      if (!normalized.inchikey.empty())
      {
        out_inchikey[i] = normalized.inchikey;
      }
      if (normalized.has_xlogp)
      {
        out_xlogp[i] = normalized.xlogp;
      }
    }
    else
    {
      if (!smiles.empty())
      {
        out_smiles[i] = smiles;
      }
      if (!inchi.empty())
      {
        out_inchi[i] = inchi;
      }
    }
  }

  Rcpp::DataFrame out = obabel::as_data_frame(
    out_name,
    out_formula,
    out_mass,
    out_rt,
    out_smiles,
    out_inchi,
    out_inchikey,
    out_xlogp,
    out_ms2_positive,
    out_ms2_negative
  );

  obabel::maybe_write_csv(out, file);
  return out;
}

//' Derive possible molecular formulas from monoisotopic mass
//'
//' Enumerates possible molecular formulas that match a given monoisotopic mass
//' within a specified tolerance using exact isotopic masses from Open Babel.
//'
//' @param mass Monoisotopic mass in Da.
//' @param tolerance_ppm Mass tolerance in ppm (default 5).
//' @param elements Optional character vector of element constraints in the
//'   format \code{"Symbol:min-max"}, e.g. \code{c("C:1-80", "N:0-10", "O:0-20")}.
//'   When NULL (default), uses C, H, N, O, P, S with automatically computed
//'   maximum counts based on the mass.
//' @return A \code{data.frame} with columns \code{formula}, \code{exact_mass},
//'   and \code{error_ppm}, sorted by increasing error.
//' @export
// [[Rcpp::export]]
Rcpp::DataFrame rcpp_formula_from_mass(
  double mass,
  double tolerance_ppm = 5.0,
  Rcpp::Nullable<Rcpp::CharacterVector> elements = R_NilValue)
{
  if (mass <= 0.0)
  {
    Rcpp::stop("mass must be positive.");
  }

  std::string elem_str;
  if (!elements.isNull())
  {
    Rcpp::CharacterVector elem_vec = Rcpp::as<Rcpp::CharacterVector>(elements);
    bool has_h = false;
    for (R_xlen_t i = 0; i < elem_vec.size(); ++i)
    {
      const std::string token = Rcpp::as<std::string>(elem_vec[i]);
      // Check if H is already specified (token starts with "H" or "H:")
      const size_t colon = token.find(':');
      const std::string symbol = (colon == std::string::npos) ? token : token.substr(0, colon);
      if (symbol == "H") has_h = true;
      if (i > 0) elem_str += ";";
      elem_str += token;
    }
    // Always include H if not specified
    if (!has_h)
    {
      if (!elem_str.empty()) elem_str += ";";
      elem_str += "H:0-" + std::to_string(static_cast<int>((mass * 1.5) / 1.007825) + 1);
    }
  }

  const std::vector<sf::obabel::FormulaMatch> matches =
    sf::obabel::formula_from_mass(mass, tolerance_ppm, elem_str);

  const R_xlen_t n = static_cast<R_xlen_t>(matches.size());
  Rcpp::CharacterVector out_formula(n);
  Rcpp::NumericVector out_exact_mass(n);
  Rcpp::NumericVector out_error_ppm(n);

  for (R_xlen_t i = 0; i < n; ++i)
  {
    out_formula[i] = matches[i].formula;
    out_exact_mass[i] = matches[i].exact_mass;
    out_error_ppm[i] = matches[i].error_ppm;
  }

  Rcpp::List out(3);
  out[0] = out_formula;
  out[1] = out_exact_mass;
  out[2] = out_error_ppm;
  out.attr("names") = Rcpp::CharacterVector::create(
    "formula", "exact_mass", "error_ppm");
  out.attr("class") = "data.frame";
  out.attr("row.names") = Rcpp::IntegerVector::create(NA_INTEGER, -static_cast<int>(n));
  return Rcpp::DataFrame(out);
}

//' Create a suspect screening CSV from MOL files using the native Open Babel
//' backend
//'
//' Reads one or more MOL files, validates each file, and normalizes the
//' structures using the embedded Open Babel runtime. Returns the standard
//' suspect-screening columns. When \code{file} is provided, the resulting table
//' is also written as CSV using \code{data.table::fwrite()}.
//'
//' @param files A character vector of full paths to MOL files.
//' @param file Optional output CSV path. When provided, the normalized table is
//'   written to disk.
//' @return A \code{data.frame} with columns \code{name}, \code{formula},
//'   \code{mass}, \code{rt}, \code{SMILES}, \code{InChI}, \code{InChIKey},
//'   \code{xLogP}, \code{ms2_positive}, and \code{ms2_negative}.
//' @export
// [[Rcpp::export]]
Rcpp::DataFrame rcpp_get_suspect_screening_csv_from_mol_files(
  Rcpp::CharacterVector files,
  Rcpp::Nullable<std::string> file = R_NilValue)
{
  const R_xlen_t n = files.size();
  if (n == 0)
  {
    Rcpp::stop("files vector is empty.");
  }

  Rcpp::CharacterVector out_name(n);
  Rcpp::CharacterVector out_formula(n, NA_STRING);
  Rcpp::NumericVector out_mass(n, NA_REAL);
  Rcpp::NumericVector out_rt(n, NA_REAL);
  Rcpp::CharacterVector out_smiles(n, NA_STRING);
  Rcpp::CharacterVector out_inchi(n, NA_STRING);
  Rcpp::CharacterVector out_inchikey(n, NA_STRING);
  Rcpp::NumericVector out_xlogp(n, NA_REAL);
  Rcpp::CharacterVector out_ms2_positive(n);
  Rcpp::CharacterVector out_ms2_negative(n);

  for (R_xlen_t i = 0; i < n; ++i)
  {
    const std::string file_path = obabel::string_at(files, i);

    if (file_path.empty())
    {
      out_name[i] = "";
      continue;
    }

    // Extract filename stem for the name column
    const size_t sep_pos = file_path.find_last_of("\\/");
    const std::string filename = (sep_pos == std::string::npos)
      ? file_path
      : file_path.substr(sep_pos + 1);
    const size_t dot_pos = filename.find_last_of('.');
    const std::string name = (dot_pos == std::string::npos)
      ? filename
      : filename.substr(0, dot_pos);
    out_name[i] = name;

    // Validate file exists
    std::ifstream test(file_path.c_str());
    if (!test.good())
    {
      continue;
    }
    test.close();

    const sf::obabel::NormalizedStructure normalized =
      sf::obabel::normalize_structure_from_mol_file(file_path);

    if (normalized.ok)
    {
      if (!normalized.formula.empty())
      {
        out_formula[i] = normalized.formula;
      }
      out_mass[i] = normalized.exact_mass;
      if (!normalized.canonical_smiles.empty())
      {
        out_smiles[i] = normalized.canonical_smiles;
      }
      if (!normalized.inchi.empty())
      {
        out_inchi[i] = normalized.inchi;
      }
      if (!normalized.inchikey.empty())
      {
        out_inchikey[i] = normalized.inchikey;
      }
      if (normalized.has_xlogp)
      {
        out_xlogp[i] = normalized.xlogp;
      }
    }
  }

  Rcpp::DataFrame out = obabel::as_data_frame(
    out_name,
    out_formula,
    out_mass,
    out_rt,
    out_smiles,
    out_inchi,
    out_inchikey,
    out_xlogp,
    out_ms2_positive,
    out_ms2_negative
  );

  obabel::maybe_write_csv(out, file);
  return out;
}
