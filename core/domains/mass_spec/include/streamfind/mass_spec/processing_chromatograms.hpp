#pragma once

#include "streamfind/project.hpp"

namespace streamfind::mass_spec::processing {

Json load_chromatograms(streamfind::Project &project, const Json &parameters);
Json filter_chromatograms_retention_time(streamfind::Project &project, const Json &parameters);
Json get_chromatograms(streamfind::Project &project, const Json &parameters);
Json get_raw_chromatograms(streamfind::Project &project, const Json &parameters);

}
