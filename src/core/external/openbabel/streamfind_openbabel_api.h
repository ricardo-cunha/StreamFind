#ifndef STREAMFIND_OPENBABEL_API_H
#define STREAMFIND_OPENBABEL_API_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32) && defined(STREAMFIND_OPENBABEL_BUILD_DLL)
#define STREAMFIND_OPENBABEL_API __declspec(dllexport)
#else
#define STREAMFIND_OPENBABEL_API
#endif

enum
{
  STREAMFIND_OB_SMILES_CAPACITY = 4096,
  STREAMFIND_OB_FORMULA_CAPACITY = 256,
  STREAMFIND_OB_INCHI_CAPACITY = 8192,
  STREAMFIND_OB_INCHIKEY_CAPACITY = 128,
  STREAMFIND_OB_ERROR_CAPACITY = 2048
};

typedef struct streamfind_ob_normalized_result
{
  int ok;
  int has_xlogp;
  double exact_mass;
  double xlogp;
  char canonical_smiles[STREAMFIND_OB_SMILES_CAPACITY];
  char formula[STREAMFIND_OB_FORMULA_CAPACITY];
  char inchi[STREAMFIND_OB_INCHI_CAPACITY];
  char inchikey[STREAMFIND_OB_INCHIKEY_CAPACITY];
  char error[STREAMFIND_OB_ERROR_CAPACITY];
} streamfind_ob_normalized_result;

STREAMFIND_OPENBABEL_API int sf_ob_openbabel_available(void);

STREAMFIND_OPENBABEL_API int sf_ob_normalize_structure(
  const char *smiles,
  const char *inchi,
  streamfind_ob_normalized_result *out);

#ifdef __cplusplus
}
#endif

#endif // STREAMFIND_OPENBABEL_API_H
