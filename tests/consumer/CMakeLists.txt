# The consumer project of the test bundle.consumer (tests/run_consumer.cmake).
#
# It finds the bundle as the Praenora runtime's build can: find_package(PraenoraRuntimeDeps), then
# json-schema-validator and nlohmann/json by their packages, which must come from the bundle,
# libRoadRunner's CMake package and the packages its static library links, and libAntimony and
# SBMLNetwork by header and library, all through PraenoraRuntimeDeps_PREFIX_PATH, under the names
# the upstream builds give them on each platform. It links one program against all of them, and
# checks that the bundle's CMake package refuses requests it cannot satisfy.

cmake_minimum_required(VERSION 3.24)
project(praenora_deps_consumer LANGUAGES C CXX)

find_package(PraenoraRuntimeDeps ${PRAENORA_DEPS_REQUESTED_VERSION} CONFIG REQUIRED)
message(STATUS "PraenoraRuntimeDeps ${PraenoraRuntimeDeps_VERSION} at ${PraenoraRuntimeDeps_ROOT} "
    "(${PraenoraRuntimeDeps_PACKAGE_NAME})")
list(PREPEND CMAKE_PREFIX_PATH ${PraenoraRuntimeDeps_PREFIX_PATH})

# json-schema-validator and nlohmann/json, from the bundle and of the bundle's versions.
find_package(nlohmann_json CONFIG REQUIRED)
find_package(nlohmann_json_schema_validator CONFIG REQUIRED)
foreach(pair IN ITEMS "nlohmann_json|NLOHMANN_JSON"
                      "nlohmann_json_schema_validator|JSON_SCHEMA_VALIDATOR")
    string(REPLACE "|" ";" pair "${pair}")
    list(GET pair 0 package)
    list(GET pair 1 variable)
    set(prefix "${PraenoraRuntimeDeps_JSON_SCHEMA_VALIDATOR_PREFIX}")
    string(FIND "${${package}_DIR}/" "${prefix}/" position)
    if(NOT position EQUAL 0)
        message(FATAL_ERROR "${package} was found at ${${package}_DIR}, not in the bundle "
            "(${prefix}).")
    endif()
    if(NOT ${package}_VERSION STREQUAL PraenoraRuntimeDeps_${variable}_VERSION)
        message(FATAL_ERROR "${package} is ${${package}_VERSION}; the bundle states "
            "${PraenoraRuntimeDeps_${variable}_VERSION}.")
    endif()
    message(STATUS "${package} ${${package}_VERSION} at ${${package}_DIR}")
endforeach()

if(WIN32)
    set(sbml_package libsbml-static)
else()
    set(sbml_package sbml-static)
endif()

# The packages libRoadRunner's static library links, then libRoadRunner itself. Its package files
# do not find their dependencies.
find_package(ZLIB CONFIG REQUIRED COMPONENTS static)
find_package(bzip2 CONFIG QUIET)
find_package(expat CONFIG REQUIRED)
# libSBML's package finds expat with libSBML's own FindEXPAT module, which searches the names
# expat and libexpat only, not those of the bundle's expat on Windows (libexpatMD, libexpatdMD for
# Debug). As libRoadRunner's and libAntimony's builds do, EXPAT_LIBRARY and EXPAT_INCLUDE_DIR are
# set from expat's package first; the module then uses them.
get_target_property(EXPAT_LIBRARY expat::expat LOCATION)
get_target_property(EXPAT_INCLUDE_DIR expat::expat INTERFACE_INCLUDE_DIRECTORIES)
foreach(package IN ITEMS ${sbml_package} rr-libstruct clapack nleq1 nleq2 PocoFoundation PocoNet
                         PocoXML SUNDIALS roadrunner-static)
    find_package(${package} CONFIG REQUIRED)
endforeach()

# libAntimony and SBMLNetwork have no package. On Windows their static libraries keep the prefix
# lib, and SBMLNetwork's ends in md, or mdd for Debug (the MSVC runtime library).
find_path(ANTIMONY_INCLUDE_DIR antimony_api.h REQUIRED NO_CACHE)
find_library(ANTIMONY_LIBRARY NAMES antimony-static libantimony-static REQUIRED NO_CACHE)
find_path(SBMLNETWORK_INCLUDE_DIR sbmlnetwork/libsbmlnetwork_common.h REQUIRED NO_CACHE)
find_library(SBMLNETWORK_LIBRARY
    NAMES sbmlnetwork-static libsbmlnetwork-static libsbmlnetwork-staticmd libsbmlnetwork-staticmdd
    REQUIRED NO_CACHE)
add_library(consumer::sbmlnetwork STATIC IMPORTED)
set_target_properties(consumer::sbmlnetwork PROPERTIES
    IMPORTED_LOCATION "${SBMLNETWORK_LIBRARY}"
    IMPORTED_LINK_INTERFACE_LANGUAGES CXX
    INTERFACE_INCLUDE_DIRECTORIES "${SBMLNETWORK_INCLUDE_DIR}"
    INTERFACE_LINK_LIBRARIES "${sbml_package};${CMAKE_DL_LIBS}")
add_library(consumer::antimony STATIC IMPORTED)
set_target_properties(consumer::antimony PROPERTIES
    IMPORTED_LOCATION "${ANTIMONY_LIBRARY}"
    IMPORTED_LINK_INTERFACE_LANGUAGES CXX
    INTERFACE_INCLUDE_DIRECTORIES "${ANTIMONY_INCLUDE_DIR}"
    INTERFACE_LINK_LIBRARIES "consumer::sbmlnetwork;${sbml_package}")

add_executable(praenora_deps_consumer consumer.cpp)
target_compile_features(praenora_deps_consumer PRIVATE cxx_std_17)
target_include_directories(praenora_deps_consumer PRIVATE
    "${PraenoraRuntimeDeps_LLVM_INSTALL_PREFIX}/include")
target_link_libraries(praenora_deps_consumer PRIVATE
    consumer::antimony roadrunner-static::roadrunner-static
    nlohmann_json_schema_validator::validator nlohmann_json::nlohmann_json)
target_compile_definitions(praenora_deps_consumer PRIVATE
    "EXPECTED_LLVM=\"${PraenoraRuntimeDeps_LLVM_VERSION}\""
    "EXPECTED_ROADRUNNER=\"${PraenoraRuntimeDeps_ROADRUNNER_VERSION}\""
    "EXPECTED_ANTIMONY=\"${PraenoraRuntimeDeps_ANTIMONY_VERSION}\""
    "EXPECTED_LIBSBML=\"${PraenoraRuntimeDeps_LIBSBML_VERSION}\""
    "EXPECTED_SBMLNETWORK=\"${PraenoraRuntimeDeps_SBMLNETWORK_VERSION}\""
    "EXPECTED_NLOHMANN_JSON=\"${PraenoraRuntimeDeps_NLOHMANN_JSON_VERSION}\"")

# The version file refuses what the bundle cannot satisfy. Each case overrides variables in a
# function scope only.
function(expect_refused description version)
    foreach(assignment IN LISTS ARGN)
        string(REGEX MATCH "^([^=]+)=(.*)$" _ "${assignment}")
        set(${CMAKE_MATCH_1} "${CMAKE_MATCH_2}")
    endforeach()
    find_package(PraenoraRuntimeDeps ${version} CONFIG QUIET)
    if(PraenoraRuntimeDeps_FOUND)
        message(FATAL_ERROR "The bundle was accepted for ${description}.")
    endif()
    message(STATUS "Refused as expected: ${description}")
endfunction()

string(REGEX MATCH "^([0-9]+)\\.([0-9]+)" _ "${PraenoraRuntimeDeps_VERSION}")
math(EXPR newer_minor "${CMAKE_MATCH_2} + 1")
math(EXPR newer_major "${CMAKE_MATCH_1} + 1")
expect_refused("version ${CMAKE_MATCH_1}.${newer_minor}" "${CMAKE_MATCH_1}.${newer_minor}")
expect_refused("version ${newer_major}.0" "${newer_major}.0")
if(PraenoraRuntimeDeps_OS STREQUAL "linux")
    expect_refused("another operating system" "" CMAKE_SYSTEM_NAME=Windows)
else()
    expect_refused("another operating system" "" CMAKE_SYSTEM_NAME=Linux)
endif()
if(PraenoraRuntimeDeps_ARCH STREQUAL "arm64")
    set(other_arch x86_64)
else()
    set(other_arch arm64)
endif()
expect_refused("another architecture" ""
    CMAKE_OSX_ARCHITECTURES=${other_arch} CMAKE_SYSTEM_PROCESSOR=${other_arch}
    CMAKE_CXX_COMPILER_ARCHITECTURE_ID=${other_arch})
if(PraenoraRuntimeDeps_OS_MIN_VERSION AND PraenoraRuntimeDeps_OS_MIN_VERSION VERSION_GREATER 11.0)
    expect_refused("macOS deployment target 11.0" "" CMAKE_OSX_DEPLOYMENT_TARGET=11.0)
endif()
