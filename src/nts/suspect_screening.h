// suspect_screening.h
// Suspect screening for PROJECT_NON_TARGET_ANALYSIS

#ifndef NTS_SUSPECT_SCREENING_H
#define NTS_SUSPECT_SCREENING_H

#include <string>
#include <vector>

namespace nts
{
  namespace api { struct NTS_SUSPECTS; class PROJECT_NON_TARGET_ANALYSIS; }
  using PROJECT_NON_TARGET_ANALYSIS = api::PROJECT_NON_TARGET_ANALYSIS;

  namespace suspect_screening
  {
    struct SuspectQuery
    {
      std::string name;
      bool has_mass = false;
      double mass = 0.0;
      double rt = 0.0;
      std::string formula;
      std::string SMILES;
      std::string InChI;
      std::string InChIKey;
      double score = 0.0;
      bool has_xLogP = false;
      double xLogP = 0.0;
      std::string database_id;
      std::vector<double> fragments_mz_pos;
      std::vector<double> fragments_intensity_pos;
      std::vector<double> fragments_mz_neg;
      std::vector<double> fragments_intensity_neg;
    };

    void suspect_screening_impl(
      PROJECT_NON_TARGET_ANALYSIS &nts_data,
        const std::vector<std::string> &analyses,
        const std::vector<SuspectQuery> &suspects,
        double ppm,
        double sec,
        double ppmMS2,
        double mzrMS2,
        double minCosineSimilarity,
        int minSharedFragments,
        bool filtered);
  } // namespace suspect_screening
} // namespace nts

#endif // NTS_SUSPECT_SCREENING_H
