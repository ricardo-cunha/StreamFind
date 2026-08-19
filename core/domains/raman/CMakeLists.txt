add_library(streamfind_raman STATIC src/register.cpp)
target_include_directories(streamfind_raman PUBLIC include)
target_link_libraries(streamfind_raman PUBLIC streamfind::core)
