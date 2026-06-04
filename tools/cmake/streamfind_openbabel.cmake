include_guard(GLOBAL)

function(streamfind_enable_openbabel target repo_root)
  if(NOT DEFINED Python3_EXECUTABLE OR Python3_EXECUTABLE STREQUAL "")
    find_package(Python3 REQUIRED COMPONENTS Interpreter)
  endif()

  if(WIN32)
    set(_sf_ob_platform windows)
  elseif(APPLE)
    set(_sf_ob_platform macos)
  else()
    set(_sf_ob_platform linux)
  endif()

  set(_sf_ob_root "${repo_root}/src/core/external/openbabel/openbabel-3-2-0")
  set(_sf_ob_build "${repo_root}/src/core/external/openbabel/build/${_sf_ob_platform}")
  set(_sf_ob_stamp "${_sf_ob_build}/.stamp")
  set(_sf_ob_runtime_dll "${_sf_ob_build}/bin/openbabel_streamfind.dll")
  set(_sf_ob_open_lib "${_sf_ob_build}/lib/libopenbabel_streamfind.a")
  set(_sf_ob_inchi_lib "${_sf_ob_build}/lib/libinchi_streamfind.a")
  set(_sf_ob_builder "${repo_root}/tools/build_openbabel.py")
  set(_sf_ob_have_prebuilt FALSE)
  if(WIN32)
    if(EXISTS "${_sf_ob_stamp}" AND EXISTS "${_sf_ob_runtime_dll}")
      set(_sf_ob_have_prebuilt TRUE)
    endif()
  elseif(EXISTS "${_sf_ob_stamp}" AND EXISTS "${_sf_ob_open_lib}" AND EXISTS "${_sf_ob_inchi_lib}")
    set(_sf_ob_have_prebuilt TRUE)
  endif()

  if(DEFINED ENV{OPENBABEL_RELEASE_ARTIFACT_ONLY} AND NOT "$ENV{OPENBABEL_RELEASE_ARTIFACT_ONLY}" STREQUAL "")
    set(_sf_ob_release_artifact_only "$ENV{OPENBABEL_RELEASE_ARTIFACT_ONLY}")
  else()
    set(_sf_ob_release_artifact_only 1)
  endif()

  set(_sf_ob_command
    ${Python3_EXECUTABLE}
    ${_sf_ob_builder}
    --repo-root ${repo_root}
    --platform ${_sf_ob_platform}
    --cc=${CMAKE_C_COMPILER}
    --cxx=${CMAKE_CXX_COMPILER}
    --ar=${CMAKE_AR}
    --cflag=-O2
    --cflag=-w
    --cxxflag=-std=c++17
    --cxxflag=-O2
    --cxxflag=-w
  )

  if(NOT WIN32)
    list(APPEND _sf_ob_command --cflag=-fPIC --cxxflag=-fPIC)
  else()
    list(APPEND _sf_ob_command --cflag=-D__USE_MINGW_ANSI_STDIO=1 --cxxflag=-D__USE_MINGW_ANSI_STDIO=1)
  endif()

  if(_sf_ob_release_artifact_only)
    list(APPEND _sf_ob_command --release-artifact-only)
  endif()

  if(NOT TARGET streamfind_openbabel_build)
    add_custom_command(
      OUTPUT ${_sf_ob_stamp}
      COMMAND ${_sf_ob_command}
      DEPENDS
        ${_sf_ob_builder}
        ${repo_root}/tools/openbabel_sources/openbabel_cpp.txt
        ${repo_root}/tools/openbabel_sources/inchi_c.txt
        ${repo_root}/src/core/external/openbabel/inchi-iupac-1.07.5/src/ichilnct.c
        ${repo_root}/src/core/external/openbabel/openbabel_c_api.cpp
        ${repo_root}/src/core/external/openbabel/streamfind_openbabel_api.h
      COMMENT "Building vendored Open Babel archives"
      VERBATIM
    )
    add_custom_target(streamfind_openbabel_build DEPENDS ${_sf_ob_stamp})
  endif()

  if(NOT TARGET streamfind_openbabel_ready)
    if(_sf_ob_have_prebuilt)
      add_custom_target(streamfind_openbabel_ready)
    else()
      add_custom_target(streamfind_openbabel_ready DEPENDS streamfind_openbabel_build)
    endif()
  endif()

  if(NOT WIN32)
    if(NOT TARGET streamfind_openbabel)
      add_library(streamfind_openbabel STATIC IMPORTED GLOBAL)
      set_target_properties(streamfind_openbabel PROPERTIES
        IMPORTED_LOCATION "${_sf_ob_open_lib}"
      )
      add_dependencies(streamfind_openbabel streamfind_openbabel_ready)
    endif()

    if(NOT TARGET streamfind_inchi)
      add_library(streamfind_inchi STATIC IMPORTED GLOBAL)
      set_target_properties(streamfind_inchi PROPERTIES
        IMPORTED_LOCATION "${_sf_ob_inchi_lib}"
      )
      add_dependencies(streamfind_inchi streamfind_openbabel_ready)
    endif()
  endif()

  target_include_directories(${target} PRIVATE
    ${_sf_ob_root}/include
    ${_sf_ob_root}/include/inchi
    ${_sf_ob_root}/src
    ${_sf_ob_root}/data
    ${_sf_ob_root}/src/formats/libinchi
  )
  if(NOT WIN32)
    target_link_libraries(${target} PRIVATE streamfind_openbabel streamfind_inchi)
  endif()
  add_dependencies(${target} streamfind_openbabel_ready)

  if(WIN32)
    add_custom_command(TARGET ${target} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E make_directory $<TARGET_FILE_DIR:${target}>
      COMMAND ${CMAKE_COMMAND} -E copy_if_different ${_sf_ob_runtime_dll} $<TARGET_FILE_DIR:${target}>
    )
  endif()
endfunction()
