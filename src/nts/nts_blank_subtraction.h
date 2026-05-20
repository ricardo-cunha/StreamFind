// nts_blank_subtraction.h
// Feature blank subtraction for PROJECT_NON_TARGET_ANALYSIS

#ifndef NTS_BLANK_SUBTRACTION_H
#define NTS_BLANK_SUBTRACTION_H

#include <vector>
#include <string>

namespace nts
{
  namespace api { class PROJECT_NON_TARGET_ANALYSIS; }
  using PROJECT_NON_TARGET_ANALYSIS = api::PROJECT_NON_TARGET_ANALYSIS;

  namespace blank_subtraction
  {
    void subtract_blank_impl(
      PROJECT_NON_TARGET_ANALYSIS &nts_data,
        float blankThreshold,
        float rtExpand,
        float mzExpand,
        float minTracesIntensity = 0.0f);
  } // namespace blank_subtraction
} // namespace nts

#endif // NTS_BLANK_SUBTRACTION_H
