#pragma once

#include "streamfind/project.hpp"

namespace streamfind::mass_spec::processing_methods {

Json find_features(streamfind::Project &project, const Json &parameters);

}
