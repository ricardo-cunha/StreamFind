#pragma once

#include "project_mass_spec.h"

namespace mass_spec {

class PROJECT_MASS_SPEC_SPECTRA {
 public:
  explicit PROJECT_MASS_SPEC_SPECTRA(std::shared_ptr<project::CONTEXT> ctx);

  const std::shared_ptr<project::CONTEXT>& context() const noexcept;
  PROJECT_MASS_SPEC& base() noexcept;
  const PROJECT_MASS_SPEC& base() const noexcept;

 private:
  std::shared_ptr<project::CONTEXT> ctx_;
  PROJECT_MASS_SPEC base_;
};

}  // namespace mass_spec
