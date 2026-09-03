#include <cassert>
#include <string_view>

#include "streamfind/version.hpp"

int main() {
    assert(!streamfind::version().empty());
    assert(streamfind::version().find('.') != std::string_view::npos);
    return 0;
}
