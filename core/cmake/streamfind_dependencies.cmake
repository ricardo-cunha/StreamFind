include_guard(GLOBAL)

function(streamfind_detect_platform out_var)
    if(WIN32)
        set(_platform windows-x64)
    elseif(APPLE)
        set(_platform macos-arm64)
    else()
        set(_platform linux-x64)
    endif()

    set(${out_var} "${_platform}" PARENT_SCOPE)
endfunction()

function(streamfind_configure_duckdb vendor_root)
    streamfind_detect_platform(_platform)

    set(_root "${vendor_root}/duckdb")
    set(_include "${_root}/include")

    if(NOT EXISTS "${_include}/duckdb.h")
        message(FATAL_ERROR "DuckDB headers not found under ${_include}")
    endif()

    if(WIN32)
        set(_imported "${_root}/lib/${_platform}/duckdb.lib")
        set(_runtime "${_root}/lib/${_platform}/duckdb.dll")
        if(NOT EXISTS "${_imported}" OR NOT EXISTS "${_runtime}")
            message(FATAL_ERROR "DuckDB Windows import/runtime libraries not found under ${_root}/lib/${_platform}")
        endif()

        add_library(streamfind_duckdb SHARED IMPORTED GLOBAL)
        set_target_properties(streamfind_duckdb PROPERTIES
            IMPORTED_IMPLIB "${_imported}"
            IMPORTED_LOCATION "${_runtime}"
            INTERFACE_INCLUDE_DIRECTORIES "${_include}"
        )
        set(_import_library "${_imported}")
        set(_static_libraries "")
    else()
        find_file(_shared
            NAMES libduckdb.so libduckdb.dylib
            PATHS "${_root}/lib/${_platform}"
            NO_DEFAULT_PATH
        )
        find_file(_static
            NAMES libduckdb_static.a
            PATHS "${_root}/lib/${_platform}"
            NO_DEFAULT_PATH
        )

        if(_shared)
            add_library(streamfind_duckdb SHARED IMPORTED GLOBAL)
            set_target_properties(streamfind_duckdb PROPERTIES
                IMPORTED_LOCATION "${_shared}"
                INTERFACE_INCLUDE_DIRECTORIES "${_include}"
            )
            set(_runtime "${_shared}")
            set(_static_libraries "")
        elseif(_static)
            find_package(Threads REQUIRED)
            set(_extension_loader "${_root}/lib/${_platform}/libduckdb_generated_extension_loader.a")
            if(NOT EXISTS "${_extension_loader}")
                message(FATAL_ERROR
                    "Complete DuckDB static package required: ${_extension_loader} is missing")
            endif()
            file(GLOB _static_extensions CONFIGURE_DEPENDS
                "${_root}/lib/${_platform}/lib*.a"
            )
            list(REMOVE_ITEM _static_extensions "${_static}")
            list(SORT _static_extensions)
            set(_static_libraries "${_static};${_static_extensions}")
            add_library(streamfind_duckdb INTERFACE)
            target_include_directories(streamfind_duckdb INTERFACE
                "$<BUILD_INTERFACE:${_include}>"
                "$<INSTALL_INTERFACE:include>"
            )
            target_link_libraries(streamfind_duckdb INTERFACE
                "-Wl,--start-group"
                ${_static_libraries}
                "-Wl,--end-group"
                Threads::Threads
                ${CMAKE_DL_LIBS}
            )
            set(_runtime "")
        else()
            message(FATAL_ERROR "DuckDB library not found under ${_root}/lib/${_platform}")
        endif()
    endif()

    add_library(streamfind::duckdb ALIAS streamfind_duckdb)
    set(STREAMFIND_DUCKDB_RUNTIME "${_runtime}" PARENT_SCOPE)
    set(STREAMFIND_DUCKDB_IMPORT_LIBRARY "${_import_library}" PARENT_SCOPE)
    set(STREAMFIND_DUCKDB_STATIC_LIBRARIES "${_static_libraries}" PARENT_SCOPE)
    set(STREAMFIND_DUCKDB_INCLUDE_DIR "${_include}" PARENT_SCOPE)
    set(STREAMFIND_PLATFORM_TAG "${_platform}" PARENT_SCOPE)
endfunction()

function(streamfind_configure_zstd vendor_root)
    set(_root "${vendor_root}/zstd")
    if(NOT EXISTS "${_root}/build/cmake/CMakeLists.txt")
        message(FATAL_ERROR "Vendored Zstandard sources not found under ${_root}")
    endif()

    set(ZSTD_BUILD_PROGRAMS OFF CACHE BOOL "" FORCE)
    set(ZSTD_BUILD_TESTS OFF CACHE BOOL "" FORCE)
    set(ZSTD_BUILD_CONTRIB OFF CACHE BOOL "" FORCE)
    set(ZSTD_BUILD_STATIC ON CACHE BOOL "" FORCE)
    set(ZSTD_BUILD_SHARED OFF CACHE BOOL "" FORCE)

    add_subdirectory(
        "${_root}/build/cmake"
        "${CMAKE_BINARY_DIR}/streamfind-zstd"
        EXCLUDE_FROM_ALL
    )

    if(NOT TARGET streamfind::zstd)
        add_library(streamfind::zstd ALIAS libzstd_static)
    endif()
endfunction()

function(streamfind_add_openbabel vendor_root)
    set(_root "${vendor_root}/openbabel")
    set(_ob_root "${_root}/openbabel-3-2-0")
    set(_inchi_root "${_root}/inchi-iupac-1.07.5")
    set(_inchi_base "${_root}/INCHI_BASE")
    set(STREAMFIND_OPENBABEL_DATA_DIR "${_ob_root}/data")
    file(GLOB _ob_sources CONFIGURE_DEPENDS
        "${_ob_root}/src/*.cpp"
        "${_ob_root}/src/math/matrix3x3.cpp"
        "${_ob_root}/src/math/spacegroup.cpp"
        "${_ob_root}/src/math/transform3d.cpp"
        "${_ob_root}/src/math/vector3.cpp"
        "${_ob_root}/src/stereo/*.cpp"
        "${_ob_root}/src/ops/gen2D.cpp"
        "${_ob_root}/src/depict/depict.cpp"
        "${_ob_root}/src/depict/svgpainter.cpp"
        "${_ob_root}/src/descriptors/groupcontrib.cpp"
        "${_ob_root}/src/formats/mdlformat.cpp"
        "${_ob_root}/src/formats/smilesformat.cpp"
        "${_ob_root}/src/formats/svgformat.cpp"
        "${_ob_root}/src/formats/getinchi.cpp"
        "${_ob_root}/src/formats/inchiformat.cpp"
    )
    list(FILTER _ob_sources EXCLUDE REGEX
        "/(RDKitConv|conformersearch|confsearch|distgeom|dlhandler_unix|doxygen_pages)\\.cpp$"
    )
    if(WIN32)
        set(STREAMFIND_OB_HAVE_CONIO_H 1)
        set(STREAMFIND_OB_MODULE_EXTENSION ".obf")
    else()
        set(STREAMFIND_OB_HAVE_CONIO_H 0)
        set(STREAMFIND_OB_MODULE_EXTENSION ".so")
        list(FILTER _ob_sources EXCLUDE REGEX "/dlhandler_win32\\.cpp$")
    endif()
    set(STREAMFIND_OPENBABEL_CONFIG_DIR "${CMAKE_CURRENT_BINARY_DIR}/streamfind-openbabel-config")
    file(MAKE_DIRECTORY "${STREAMFIND_OPENBABEL_CONFIG_DIR}/openbabel")
    configure_file(
        "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/openbabel_babelconfig.h.in"
        "${STREAMFIND_OPENBABEL_CONFIG_DIR}/openbabel/babelconfig.h"
        @ONLY
    )
    file(GLOB _inchi_sources CONFIGURE_DEPENDS
        "${_ob_root}/src/formats/libinchi/*.c"
        "${_inchi_root}/src/ichilnct.c"
        "${_inchi_root}/src/inchi_dll_a.c"
        "${_inchi_root}/src/inchi_dll_b.c"
        "${_inchi_root}/src/inchi_dll_main.c"
    )

    set(_includes
        "${STREAMFIND_OPENBABEL_CONFIG_DIR}"
        "${_ob_root}/include"
        "${_ob_root}/include/inchi"
        "${_ob_root}/src"
        "${_ob_root}/data"
        "${_ob_root}/src/formats/libinchi"
        "${_inchi_root}/src"
        "${_inchi_base}/src"
        "${_root}"
    )

    add_library(streamfind_inchi STATIC ${_inchi_sources})
    add_library(streamfind_openbabel STATIC ${_ob_sources})
    add_library(streamfind::inchi ALIAS streamfind_inchi)
    add_library(streamfind::openbabel ALIAS streamfind_openbabel)

    foreach(_target IN ITEMS streamfind_inchi streamfind_openbabel)
        set_target_properties(${_target} PROPERTIES
            CXX_STANDARD 17
            CXX_STANDARD_REQUIRED ON
            POSITION_INDEPENDENT_CODE ON
        )
        target_include_directories(${_target} PRIVATE ${_includes})
        target_compile_definitions(${_target} PRIVATE TARGET_API_LIB)
        if(MSVC)
            target_compile_definitions(${_target} PRIVATE
                NOMINMAX
                strcasecmp=_stricmp
                strncasecmp=_strnicmp
            )
        endif()
        target_compile_options(${_target} PRIVATE
            $<$<CXX_COMPILER_ID:GNU,Clang>:-w>
            $<$<CXX_COMPILER_ID:MSVC>:/W0;/wd4244>
        )
    endforeach()

    target_include_directories(streamfind_inchi PRIVATE ${_includes})
    target_include_directories(streamfind_openbabel PRIVATE ${_includes})
    target_link_libraries(streamfind_openbabel PUBLIC streamfind::inchi)

    set(STREAMFIND_OPENBABEL_DATA_DIR "${_ob_root}/data" PARENT_SCOPE)
endfunction()

function(streamfind_configure_dependencies vendor_root)
    set(_vendor_root "${vendor_root}")
    streamfind_configure_duckdb("${_vendor_root}")
    streamfind_configure_zstd("${_vendor_root}")
    streamfind_add_openbabel("${_vendor_root}")

    if(NOT TARGET streamfind::zlib)
        add_subdirectory(
            "${_vendor_root}/zlib/zlib-develop"
            "${CMAKE_BINARY_DIR}/streamfind-vendored-zlib"
            EXCLUDE_FROM_ALL
        )
    endif()

    set(STREAMFIND_VENDOR_DIR "${_vendor_root}" PARENT_SCOPE)
    set(STREAMFIND_DUCKDB_RUNTIME "${STREAMFIND_DUCKDB_RUNTIME}" PARENT_SCOPE)
    set(STREAMFIND_DUCKDB_IMPORT_LIBRARY "${STREAMFIND_DUCKDB_IMPORT_LIBRARY}" PARENT_SCOPE)
    set(STREAMFIND_DUCKDB_STATIC_LIBRARIES "${STREAMFIND_DUCKDB_STATIC_LIBRARIES}" PARENT_SCOPE)
    set(STREAMFIND_DUCKDB_INCLUDE_DIR "${STREAMFIND_DUCKDB_INCLUDE_DIR}" PARENT_SCOPE)
    set(STREAMFIND_PLATFORM_TAG "${STREAMFIND_PLATFORM_TAG}" PARENT_SCOPE)
    set(STREAMFIND_OPENBABEL_DATA_DIR "${STREAMFIND_OPENBABEL_DATA_DIR}" PARENT_SCOPE)
endfunction()
