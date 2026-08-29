add_library(streamfind_raman STATIC src/register.cpp)
target_include_directories(streamfind_raman PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)
target_link_libraries(streamfind_raman PUBLIC streamfind::core)
