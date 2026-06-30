include_guard(GLOBAL)

function(streamfind_detect_platform out_var)
  if(WIN32)
    set(_sf_platform "windows-x64")
  elseif(APPLE)
    set(_sf_platform "macos-arm64")
  else()
    set(_sf_platform "linux-x64")
  endif()

  set(${out_var} "${_sf_platform}" PARENT_SCOPE)
endfunction()

function(streamfind_configure_duckdb repo_root)
  streamfind_detect_platform(_sf_platform)

  set(_sf_duckdb_root "${repo_root}/src/core/external/duckdb")
  set(_sf_duckdb_include_dir "${_sf_duckdb_root}/include")

  if(WIN32)
    set(_sf_duckdb_lib "${_sf_duckdb_root}/lib/${_sf_platform}/duckdb.lib")
    set(_sf_duckdb_runtime "${_sf_duckdb_root}/lib/${_sf_platform}/duckdb.dll")
    set(_sf_duckdb_target_type SHARED)
  elseif(APPLE)
    set(_sf_duckdb_lib "${_sf_duckdb_root}/lib/${_sf_platform}/libduckdb.dylib")
    set(_sf_duckdb_runtime "${_sf_duckdb_lib}")
    set(_sf_duckdb_target_type SHARED)
  else()
    set(_sf_duckdb_lib "${_sf_duckdb_root}/lib/${_sf_platform}/libduckdb_static.a")
    set(_sf_duckdb_runtime "${_sf_duckdb_lib}")
    set(_sf_duckdb_target_type STATIC)
  endif()

  if(NOT TARGET streamfind_duckdb)
    add_library(streamfind_duckdb ${_sf_duckdb_target_type} IMPORTED GLOBAL)
    set_target_properties(streamfind_duckdb PROPERTIES
      IMPORTED_LOCATION "${_sf_duckdb_lib}"
    )
  endif()

  set(STREAMFIND_EXTERNAL_DIR "${repo_root}/src/core/external" PARENT_SCOPE)
  set(STREAMFIND_DUCKDB_INCLUDE_DIR "${_sf_duckdb_include_dir}" PARENT_SCOPE)
  set(STREAMFIND_DUCKDB_LIBRARY "${_sf_duckdb_lib}" PARENT_SCOPE)
  set(STREAMFIND_DUCKDB_RUNTIME_LIBRARY "${_sf_duckdb_runtime}" PARENT_SCOPE)
  set(STREAMFIND_PLATFORM_TAG "${_sf_platform}" PARENT_SCOPE)
endfunction()
