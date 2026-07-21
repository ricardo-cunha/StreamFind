#include <cassert>
#include <string_view>

#include "streamfind/version.hpp"

int main() {
    assert(!streamfind::version().empty());
    assert(streamfind::version() == std::string_view{"0.1.0"});
    return 0;
}
