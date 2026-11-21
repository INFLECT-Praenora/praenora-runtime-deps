cmake_minimum_required(VERSION 3.24)

# The macOS deployment target of every dependency. It is a cache default set before project(), as
# in the Praenora runtime; 14.0 is the target of the upstream release binaries the runtime was
# verified with (docs/outputs.md#platform-and-compiler-labels).
set(CMAKE_OSX_DEPLOYMENT_TARGET "14.0" CACHE STRING
    "Minimum macOS version of the dependencies (macOS only)")

project(praenora_runtime_deps
    VERSION 0.1.1
    DESCRIPTION "Build dependencies of the Praenora runtime"
    HOMEPAGE_URL "https://github.com/INFLECT-Praenora/praenora-runtime-deps"
    LANGUAGES C CXX)

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX "${PROJECT_BINARY_DIR}/install" CACHE PATH
        "Directory the dependency bundle is written to during the build" FORCE)
endif()

include(PraenoraDepsVersions)
include(PraenoraDepsPlatform)
include(PraenoraDepsUpstreams)
include(PraenoraDepsPackage)

enable_testing()
add_subdirectory(tests)
