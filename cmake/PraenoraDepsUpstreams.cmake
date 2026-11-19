# The upstream builds, as external projects built from the submodules under external/.
#
# Order: LLVM and libroadrunner-deps first, then libRoadRunner (which needs both) and libAntimony
# (which needs libroadrunner-deps); nlohmann/json, then json-schema-validator (which needs it).
# Each project installs into a directory of the bundle during the build; the bundle is
# CMAKE_INSTALL_PREFIX:
#
#   <bundle>/llvm                    LLVM (LLVM_INSTALL_PREFIX for the Praenora runtime)
#   <bundle>/roadrunner              libRoadRunner, with a copy of libroadrunner-deps (libSBML,
#                                    SUNDIALS, POCO, SBMLNetwork, expat, zlib and the others)
#   <bundle>/antimony                libAntimony
#   <bundle>/json-schema-validator   json-schema-validator and nlohmann/json
#
# libroadrunner-deps itself installs into the build tree (work/libroadrunner-deps/install):
# libRoadRunner's installation copies it, and libAntimony is built against it.
#
# Every project gets the same compilers, build type, architecture, deployment target and compiler
# launchers, position-independent code (its static libraries are linked into shared provider
# libraries) and the library directory lib. The steps run in Ninja's console pool, one at a time,
# each with the full parallelism of its own build, and print their output as they run.
#
# Options:
#   PRAENORA_DEPS_LLVM_TARGETS   LLVM_TARGETS_TO_BUILD (default host: the target architecture
#                                only, which is all that libRoadRunner initializes)

include_guard(GLOBAL)
include(ExternalProject)

set(PRAENORA_DEPS_LLVM_TARGETS "host" CACHE STRING
    "LLVM_TARGETS_TO_BUILD of the LLVM build (host builds the target architecture only)")

set(PRAENORA_DEPS_WORK_DIR "${PROJECT_BINARY_DIR}/work")
set(PRAENORA_DEPS_ROADRUNNER_DEPS_PREFIX "${PRAENORA_DEPS_WORK_DIR}/libroadrunner-deps/install")

# The submodules must be checked out, with their own submodules (libroadrunner-deps has some).
foreach(_praenora_deps_marker IN ITEMS
        "llvm/llvm/CMakeLists.txt"
        "libroadrunner-deps/CMakeLists.txt"
        "libroadrunner-deps/third_party/libsbml/CMakeLists.txt"
        "roadrunner/CMakeLists.txt"
        "antimony/CMakeLists.txt"
        "nlohmann-json/CMakeLists.txt"
        "json-schema-validator/CMakeLists.txt")
    if(NOT EXISTS "${PROJECT_SOURCE_DIR}/external/${_praenora_deps_marker}")
        message(FATAL_ERROR "external/${_praenora_deps_marker} is missing: the submodules are not "
            "checked out. Run\n  git submodule update --init --recursive --depth 1\nin "
            "${PROJECT_SOURCE_DIR} (docs/building.md).")
    endif()
endforeach()

set(_praenora_deps_common_args
    "-DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}"
    "-DCMAKE_C_COMPILER:FILEPATH=${CMAKE_C_COMPILER}"
    "-DCMAKE_CXX_COMPILER:FILEPATH=${CMAKE_CXX_COMPILER}"
    "-DCMAKE_INSTALL_LIBDIR:STRING=lib"
    "-DCMAKE_INSTALL_MESSAGE:STRING=LAZY"
    "-DCMAKE_POSITION_INDEPENDENT_CODE:BOOL=ON"
    "-DCMAKE_FIND_USE_PACKAGE_REGISTRY:BOOL=OFF")
if(APPLE)
    list(APPEND _praenora_deps_common_args
        "-DCMAKE_OSX_ARCHITECTURES:STRING=${CMAKE_OSX_ARCHITECTURES}"
        "-DCMAKE_OSX_DEPLOYMENT_TARGET:STRING=${CMAKE_OSX_DEPLOYMENT_TARGET}")
    if(CMAKE_OSX_SYSROOT)
        list(APPEND _praenora_deps_common_args "-DCMAKE_OSX_SYSROOT:PATH=${CMAKE_OSX_SYSROOT}")
    endif()
endif()
foreach(_praenora_deps_launcher IN ITEMS CMAKE_C_COMPILER_LAUNCHER CMAKE_CXX_COMPILER_LAUNCHER)
    if(${_praenora_deps_launcher})
        list(APPEND _praenora_deps_common_args
            "-D${_praenora_deps_launcher}:STRING=${${_praenora_deps_launcher}}")
    endif()
endforeach()
if(DEFINED CMAKE_MSVC_RUNTIME_LIBRARY)
    list(APPEND _praenora_deps_common_args
        "-DCMAKE_MSVC_RUNTIME_LIBRARY:STRING=${CMAKE_MSVC_RUNTIME_LIBRARY}")
endif()

# _praenora_deps_add_upstream(<name> <install dir> [SOURCE_SUBDIR <dir>] [DEPENDS <targets>...]
#                             [ARGS <cache args>...])
function(_praenora_deps_add_upstream name install_dir)
    cmake_parse_arguments(PARSE_ARGV 2 arg "" "SOURCE_SUBDIR" "DEPENDS;ARGS")
    set(extra "")
    if(arg_SOURCE_SUBDIR)
        list(APPEND extra SOURCE_SUBDIR "${arg_SOURCE_SUBDIR}")
    endif()
    if(arg_DEPENDS)
        list(APPEND extra DEPENDS ${arg_DEPENDS})
    endif()
    ExternalProject_Add(${name}
        SOURCE_DIR "${PROJECT_SOURCE_DIR}/external/${name}"
        PREFIX "${PRAENORA_DEPS_WORK_DIR}/${name}"
        BINARY_DIR "${PRAENORA_DEPS_WORK_DIR}/${name}/build"
        INSTALL_DIR "${install_dir}"
        ${extra}
        CMAKE_CACHE_ARGS
            ${_praenora_deps_common_args}
            "-DCMAKE_INSTALL_PREFIX:PATH=${install_dir}"
            ${arg_ARGS}
        BUILD_ALWAYS TRUE
        USES_TERMINAL_CONFIGURE TRUE
        USES_TERMINAL_BUILD TRUE
        USES_TERMINAL_INSTALL TRUE)
endfunction()

# LLVM: the fork's defaults, as in its release builds, except the target list and the optional
# host libraries, which are turned off so that the bundle does not depend on what the build machine
# has installed. libRoadRunner links none of them.
_praenora_deps_add_upstream(llvm "${CMAKE_INSTALL_PREFIX}/llvm"
    SOURCE_SUBDIR llvm
    ARGS
        "-DLLVM_TARGETS_TO_BUILD:STRING=${PRAENORA_DEPS_LLVM_TARGETS}"
        "-DLLVM_ENABLE_BINDINGS:BOOL=OFF"
        "-DLLVM_ENABLE_LIBEDIT:BOOL=OFF"
        "-DLLVM_ENABLE_LIBPFM:BOOL=OFF"
        "-DLLVM_ENABLE_LIBXML2:STRING=OFF"
        "-DLLVM_ENABLE_TERMINFO:BOOL=OFF"
        "-DLLVM_ENABLE_ZLIB:STRING=OFF"
        "-DLLVM_ENABLE_Z3_SOLVER:BOOL=OFF")

# libroadrunner-deps: its defaults, as in its release builds.
_praenora_deps_add_upstream(libroadrunner-deps "${PRAENORA_DEPS_ROADRUNNER_DEPS_PREFIX}")

# libRoadRunner: the C++ libraries only, as the Praenora runtime links them.
_praenora_deps_add_upstream(roadrunner "${CMAKE_INSTALL_PREFIX}/roadrunner"
    DEPENDS llvm libroadrunner-deps
    ARGS
        "-DRR_DEPENDENCIES_INSTALL_PREFIX:PATH=${PRAENORA_DEPS_ROADRUNNER_DEPS_PREFIX}"
        "-DLLVM_INSTALL_PREFIX:PATH=${CMAKE_INSTALL_PREFIX}/llvm"
        "-DBUILD_TESTS:BOOL=OFF"
        "-DBUILD_TEST_TOOLS:BOOL=OFF"
        "-DBUILD_RR_PLUGINS:BOOL=OFF"
        "-DBUILD_PYTHON:BOOL=OFF"
        "-DBUILD_JAVA:BOOL=OFF"
        "-DBUILD_EXAMPLES:BOOL=OFF"
        "-DBUILD_APPS:BOOL=OFF"
        "-DBUILD_DOCS:BOOL=OFF")

# libAntimony: the C library only, with the options the Praenora runtime documents.
_praenora_deps_add_upstream(antimony "${CMAKE_INSTALL_PREFIX}/antimony"
    DEPENDS libroadrunner-deps
    ARGS
        "-DANT_DEPENDENCIES_INSTALL_PREFIX:PATH=${PRAENORA_DEPS_ROADRUNNER_DEPS_PREFIX}"
        "-DWITH_QTANTIMONY:BOOL=OFF"
        "-DWITH_PYTHON:BOOL=OFF"
        "-DWITH_CELLML:BOOL=OFF"
        "-DWITH_GTEST:BOOL=OFF"
        "-DWITH_JULIA:BOOL=OFF")

# nlohmann/json: header-only; its defaults, without its tests. Its options that change the names of
# its symbols (JSON_Diagnostics and the others) keep their defaults, as the Praenora runtime's do.
set(PRAENORA_DEPS_JSON_PREFIX "${CMAKE_INSTALL_PREFIX}/json-schema-validator")
_praenora_deps_add_upstream(nlohmann-json "${PRAENORA_DEPS_JSON_PREFIX}"
    ARGS
        "-DJSON_BuildTests:BOOL=OFF"
        "-DJSON_Install:BOOL=ON")

# json-schema-validator: the static library, as the Praenora runtime links it, compiled against
# the nlohmann/json above. Its build downloads nlohmann/json when find_package() does not find
# it; FETCHCONTENT_FULLY_DISCONNECTED turns that into an error.
_praenora_deps_add_upstream(json-schema-validator "${PRAENORA_DEPS_JSON_PREFIX}"
    DEPENDS nlohmann-json
    ARGS
        "-Dnlohmann_json_DIR:PATH=${PRAENORA_DEPS_JSON_PREFIX}/share/cmake/nlohmann_json"
        "-DFETCHCONTENT_FULLY_DISCONNECTED:BOOL=ON"
        "-DJSON_VALIDATOR_INSTALL:BOOL=ON"
        "-DJSON_VALIDATOR_BUILD_TESTS:BOOL=OFF"
        "-DJSON_VALIDATOR_BUILD_EXAMPLES:BOOL=OFF"
        "-DJSON_VALIDATOR_SHARED_LIBS:BOOL=OFF")
