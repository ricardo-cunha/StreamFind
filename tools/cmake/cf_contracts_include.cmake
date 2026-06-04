if(NOT DEFINED Python3_EXECUTABLE OR Python3_EXECUTABLE STREQUAL "")
  find_package(Python3 REQUIRED COMPONENTS Interpreter)
endif()

if(NOT DEFINED CF_CONTRACTS_INCLUDE OR CF_CONTRACTS_INCLUDE STREQUAL "")
  execute_process(
    COMMAND ${Python3_EXECUTABLE} -c "import cf_package_contracts as c; p = getattr(c, 'cf_contracts_include_path', lambda: '')(); print(p if p else '')"
    OUTPUT_VARIABLE _CF_PY_INCLUDE
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
  )
  if(NOT _CF_PY_INCLUDE STREQUAL "" AND EXISTS "${_CF_PY_INCLUDE}/cf_step_abi.h")
    set(CF_CONTRACTS_INCLUDE "${_CF_PY_INCLUDE}")
  endif()
endif()

if(NOT DEFINED CF_CONTRACTS_INCLUDE OR CF_CONTRACTS_INCLUDE STREQUAL "")
  message(FATAL_ERROR "cf_package_contracts include path not found. Install cf-package-contracts.")
endif()

if(NOT EXISTS "${CF_CONTRACTS_INCLUDE}/cf_step_abi.h")
  message(FATAL_ERROR "cf_step_abi.h not found in '${CF_CONTRACTS_INCLUDE}'")
endif()
