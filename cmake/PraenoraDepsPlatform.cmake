# Platform, compiler and configuration labels of the bundle.
#
# The labels name the bundle (PRAENORA_DEPS_PACKAGE_NAME) and go into its manifest and CMake
# package, where the Praenora runtime's build can check them (docs/outputs.md). Platform names are
# the runtime's: linux, macos or windows, and x86_64 or arm64.
#
# Afterwards these exist:
#   PRAENORA_DEPS_OS                 linux, macos or windows
#   PRAENORA_DEPS_ARCH               x86_64 or arm64
#   PRAENORA_DEPS_OS_MIN_VERSION     macOS: CMAKE_OSX_DEPLOYMENT_TARGET; elsewhere empty
#   PRAENORA_DEPS_DISTRIBUTION       Linux: <id>-<version> from /etc/os-release; elsewhere empty
#   PRAENORA_DEPS_COMPILER_ID        CMAKE_CXX_COMPILER_ID
#   PRAENORA_DEPS_COMPILER_VERSION   CMAKE_CXX_COMPILER_VERSION
#   PRAENORA_DEPS_COMPILER_LABEL     appleclang<major>, clang<major>, gcc<major> or msvc<toolset>
#   PRAENORA_DEPS_CXX_STDLIB         libc++, libstdc++ or msvc-stl
#   PRAENORA_DEPS_MSVC_RUNTIME       MSVC: MultiThreadedDLL or MultiThreadedDebugDLL; else empty
#   PRAENORA_DEPS_CONFIG_LABEL       release or debug
#   PRAENORA_DEPS_PACKAGE_NAME       praenora-runtime-deps-<version>-<os>-<arch>-<compiler>-<config>

include_guard(GLOBAL)
include(CheckCXXSourceCompiles)

# One configuration per build tree: the upstream builds are configured for one build type.
get_property(_praenora_deps_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(_praenora_deps_multi_config)
    message(FATAL_ERROR "praenora-runtime-deps needs a single-configuration generator such as "
        "Ninja; ${CMAKE_GENERATOR} is multi-configuration.")
endif()
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Release or Debug" FORCE)
endif()
if(NOT CMAKE_BUILD_TYPE MATCHES "^(Release|Debug)$")
    message(FATAL_ERROR "CMAKE_BUILD_TYPE is '${CMAKE_BUILD_TYPE}'; use Release or Debug.")
endif()
string(TOLOWER "${CMAKE_BUILD_TYPE}" PRAENORA_DEPS_CONFIG_LABEL)

# Operating system.
set(PRAENORA_DEPS_OS_MIN_VERSION "")
set(PRAENORA_DEPS_DISTRIBUTION "")
if(APPLE)
    set(PRAENORA_DEPS_OS macos)
    if(NOT CMAKE_OSX_DEPLOYMENT_TARGET)
        message(FATAL_ERROR "CMAKE_OSX_DEPLOYMENT_TARGET is empty; set it (14.0 by default).")
    endif()
    set(PRAENORA_DEPS_OS_MIN_VERSION "${CMAKE_OSX_DEPLOYMENT_TARGET}")
elseif(WIN32)
    set(PRAENORA_DEPS_OS windows)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(PRAENORA_DEPS_OS linux)
    cmake_host_system_information(RESULT _praenora_deps_distrib_id QUERY DISTRIB_ID)
    cmake_host_system_information(RESULT _praenora_deps_distrib_version QUERY DISTRIB_VERSION_ID)
    if(_praenora_deps_distrib_id)
        set(PRAENORA_DEPS_DISTRIBUTION
            "${_praenora_deps_distrib_id}-${_praenora_deps_distrib_version}")
    endif()
else()
    message(FATAL_ERROR "praenora-runtime-deps builds on Linux, macOS and Windows only, not on "
        "${CMAKE_SYSTEM_NAME}.")
endif()

# Architecture: one per build, as in the Praenora runtime. libRoadRunner builds for x86_64 when
# CMAKE_OSX_ARCHITECTURES is empty, so on macOS it is always set.
if(APPLE)
    if(NOT CMAKE_OSX_ARCHITECTURES)
        set(CMAKE_OSX_ARCHITECTURES "${CMAKE_HOST_SYSTEM_PROCESSOR}" CACHE STRING
            "Target architecture (one)" FORCE)
    endif()
    list(LENGTH CMAKE_OSX_ARCHITECTURES _praenora_deps_arch_count)
    if(NOT _praenora_deps_arch_count EQUAL 1)
        message(FATAL_ERROR "CMAKE_OSX_ARCHITECTURES names ${_praenora_deps_arch_count} "
            "architectures (${CMAKE_OSX_ARCHITECTURES}); a bundle holds one.")
    endif()
    set(_praenora_deps_arch "${CMAKE_OSX_ARCHITECTURES}")
elseif(MSVC)
    set(_praenora_deps_arch "${CMAKE_CXX_COMPILER_ARCHITECTURE_ID}")
else()
    set(_praenora_deps_arch "${CMAKE_SYSTEM_PROCESSOR}")
endif()
if(_praenora_deps_arch MATCHES "^(x86_64|AMD64|amd64|x64)$")
    set(PRAENORA_DEPS_ARCH x86_64)
elseif(_praenora_deps_arch MATCHES "^(arm64|ARM64|aarch64)$")
    set(PRAENORA_DEPS_ARCH arm64)
else()
    message(FATAL_ERROR "Unsupported architecture '${_praenora_deps_arch}'; x86_64 and arm64 are "
        "supported.")
endif()
if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
    message(FATAL_ERROR "praenora-runtime-deps builds 64-bit binaries only.")
endif()

# Compiler. The C and C++ compilers must come from one toolchain.
if(NOT CMAKE_C_COMPILER_ID STREQUAL CMAKE_CXX_COMPILER_ID OR
   NOT CMAKE_C_COMPILER_VERSION VERSION_EQUAL CMAKE_CXX_COMPILER_VERSION)
    message(FATAL_ERROR "The C compiler (${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION}) and "
        "the C++ compiler (${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}) differ.")
endif()
set(PRAENORA_DEPS_COMPILER_ID "${CMAKE_CXX_COMPILER_ID}")
set(PRAENORA_DEPS_COMPILER_VERSION "${CMAKE_CXX_COMPILER_VERSION}")
string(REGEX MATCH "^[0-9]+" _praenora_deps_compiler_major "${CMAKE_CXX_COMPILER_VERSION}")
if(CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")
    set(PRAENORA_DEPS_COMPILER_LABEL "appleclang${_praenora_deps_compiler_major}")
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    set(PRAENORA_DEPS_COMPILER_LABEL "clang${_praenora_deps_compiler_major}")
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    set(PRAENORA_DEPS_COMPILER_LABEL "gcc${_praenora_deps_compiler_major}")
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
    # The toolset (143 for Visual Studio 2022) decides which linkers accept the static libraries.
    set(PRAENORA_DEPS_COMPILER_LABEL "msvc${MSVC_TOOLSET_VERSION}")
else()
    message(FATAL_ERROR "Unsupported compiler ${CMAKE_CXX_COMPILER_ID}; use AppleClang, Clang, "
        "GCC or MSVC.")
endif()

# C++ standard library, as the compiler sees it.
foreach(_praenora_deps_stdlib IN ITEMS "LIBCXX|_LIBCPP_VERSION" "LIBSTDCXX|__GLIBCXX__"
                                       "MSVC_STL|_MSVC_STL_VERSION")
    string(REPLACE "|" ";" _praenora_deps_stdlib "${_praenora_deps_stdlib}")
    list(GET _praenora_deps_stdlib 0 _praenora_deps_stdlib_name)
    list(GET _praenora_deps_stdlib 1 _praenora_deps_stdlib_macro)
    check_cxx_source_compiles("#include <cstddef>
#ifndef ${_praenora_deps_stdlib_macro}
#error
#endif
int main() { return 0; }" PRAENORA_DEPS_HAS_${_praenora_deps_stdlib_name})
endforeach()
if(PRAENORA_DEPS_HAS_LIBCXX)
    set(PRAENORA_DEPS_CXX_STDLIB libc++)
elseif(PRAENORA_DEPS_HAS_LIBSTDCXX)
    set(PRAENORA_DEPS_CXX_STDLIB libstdc++)
elseif(PRAENORA_DEPS_HAS_MSVC_STL)
    set(PRAENORA_DEPS_CXX_STDLIB msvc-stl)
else()
    message(FATAL_ERROR "The C++ standard library of ${CMAKE_CXX_COMPILER} is not recognized.")
endif()

# MSVC runtime library: the shared one (/MD, /MDd), as the Praenora runtime requires.
set(PRAENORA_DEPS_MSVC_RUNTIME "")
if(MSVC)
    if(DEFINED CMAKE_MSVC_RUNTIME_LIBRARY AND
       NOT CMAKE_MSVC_RUNTIME_LIBRARY MATCHES "DLL$")
        message(FATAL_ERROR "CMAKE_MSVC_RUNTIME_LIBRARY is '${CMAKE_MSVC_RUNTIME_LIBRARY}'; the "
            "Praenora runtime needs the shared runtime library (/MD or /MDd).")
    endif()
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(PRAENORA_DEPS_MSVC_RUNTIME MultiThreadedDebugDLL)
    else()
        set(PRAENORA_DEPS_MSVC_RUNTIME MultiThreadedDLL)
    endif()
endif()

set(PRAENORA_DEPS_PACKAGE_NAME "praenora-runtime-deps-${PROJECT_VERSION}-${PRAENORA_DEPS_OS}-\
${PRAENORA_DEPS_ARCH}-${PRAENORA_DEPS_COMPILER_LABEL}-${PRAENORA_DEPS_CONFIG_LABEL}")

message(STATUS "praenora-runtime-deps: bundle ${PRAENORA_DEPS_PACKAGE_NAME}")
message(STATUS "praenora-runtime-deps: ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION} "
    "(${PRAENORA_DEPS_CXX_STDLIB}), ${CMAKE_BUILD_TYPE}")
if(PRAENORA_DEPS_OS_MIN_VERSION)
    message(STATUS "praenora-runtime-deps: macOS deployment target ${PRAENORA_DEPS_OS_MIN_VERSION}")
endif()
message(STATUS "praenora-runtime-deps: bundle directory ${CMAKE_INSTALL_PREFIX}")
