#ifndef STREAMFIND_OPENBABEL_ADAPTER_H
#define STREAMFIND_OPENBABEL_ADAPTER_H

#include <string>

namespace sf::obabel
{
  struct NormalizedStructure
  {
    bool ok = false;
    std::string error;
    // These fields are derived from the parsed structure and should be treated
    // as the normalized canonical values for downstream screening.
    std::string canonical_smiles;
    std::string formula;
    std::string inchi;
    std::string inchikey;
    double exact_mass = 0.0;
    double xlogp = 0.0;
    bool has_xlogp = false;
  };

  bool openbabel_available();

  NormalizedStructure normalize_structure(
      const std::string &smiles,
      const std::string &inchi);

} // namespace sf::obabel

#endif // STREAMFIND_OPENBABEL_ADAPTER_H
