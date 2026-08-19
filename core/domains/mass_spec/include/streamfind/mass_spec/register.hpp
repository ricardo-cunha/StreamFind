#pragma once

#include "streamfind/project.hpp"

namespace streamfind::mass_spec {

void register_methods(MethodRegistry &registry);
void register_operations(OperationRegistry &registry);

}
