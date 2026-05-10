#include "project_mass_spec_chromatograms.h"

namespace mass_spec {

PROJECT_MASS_SPEC_CHROMATOGRAMS::PROJECT_MASS_SPEC_CHROMATOGRAMS(std::shared_ptr<project::CONTEXT> ctx)
    : ctx_(std::move(ctx)), base_(ctx_) {
  project::PROJECT root(ctx_->db_path, ctx_->project_id);
  root.set_domain("mass_spec_chromatograms");
}

const std::shared_ptr<project::CONTEXT>& PROJECT_MASS_SPEC_CHROMATOGRAMS::context() const noexcept {
  return ctx_;
}

PROJECT_MASS_SPEC& PROJECT_MASS_SPEC_CHROMATOGRAMS::base() noexcept {
  return base_;
}

const PROJECT_MASS_SPEC& PROJECT_MASS_SPEC_CHROMATOGRAMS::base() const noexcept {
  return base_;
}

}  // namespace mass_spec
