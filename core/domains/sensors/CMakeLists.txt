add_library(streamfind_sensors STATIC src/register.cpp)
target_include_directories(streamfind_sensors PUBLIC include)
target_link_libraries(streamfind_sensors PUBLIC streamfind::core)
