# bundle.manifest: cmake -DBUNDLE=<dir> -DBUILD_DIR=<dir> -DVERSION=<v> -DPACKAGE_NAME=<name>
#                        -DOS=<os> -DARCH=<arch> -DCOMPILER_LABEL=<label> -DBUILD_TYPE=<type>
#                        -P check_manifest.cmake
#
# Checks that the bundle's manifest names this build's version, labels and build type, that the
# directories it lists for consumers exist, with json-schema-validator's first (it holds the
# nlohmann/json that consumers must find first), that the files the Praenora runtime's finders
# look for exist, under the names the upstream builds give them on each platform, that the
# manifest lists license files for this repository and for every component and that they exist,
# and that no CMake file of the bundle names a path in the build tree, which would not exist once
# the build tree is gone or the bundle is moved. Prints each check; fails at the end if any failed.
#
# One upstream exception is allowed: libroadrunner-deps' package files for libSBML, NuML and
# libSEDML append the directory of their find modules at build time to CMAKE_MODULE_PATH, as in
# libRoadRunner's release binaries. Where that directory does not exist, the line has no effect.

cmake_minimum_required(VERSION 3.24)

set(failures 0)

# _report(<ok> <what>)
function(_report ok what)
    if(ok)
        message(STATUS "ok: ${what}")
    else()
        message(STATUS "FAILED: ${what}")
        math(EXPR count "${failures} + 1")
        set(failures ${count} PARENT_SCOPE)
    endif()
endfunction()

# check_equal(<what> <actual> <expected>)
macro(check_equal what actual expected)
    if("${actual}" STREQUAL "${expected}")
        _report(TRUE "${what} is ${expected}")
    else()
        _report(FALSE "${what} is ${expected}, not '${actual}'")
    endif()
endmacro()

# check_exists(<path relative to the bundle>)
macro(check_exists path)
    if(EXISTS "${BUNDLE}/${path}")
        _report(TRUE "${path} exists")
    else()
        _report(FALSE "${path} exists")
    endif()
endmacro()

# _json(<out> <member>...): a member of the manifest, or NOTFOUND.
macro(_json out)
    string(JSON ${out} ERROR_VARIABLE _json_error GET "${manifest}" ${ARGN})
    if(_json_error)
        set(${out} NOTFOUND)
    endif()
endmacro()

set(manifest_file "${BUNDLE}/praenora-runtime-deps.json")
if(NOT EXISTS "${manifest_file}")
    message(FATAL_ERROR "FAILED: ${manifest_file} does not exist; build the project first.")
endif()
file(READ "${manifest_file}" manifest)
string(JSON _type ERROR_VARIABLE _error TYPE "${manifest}")
if(_error OR NOT _type STREQUAL "OBJECT")
    message(FATAL_ERROR "FAILED: ${manifest_file} is not a JSON object: ${_error}")
endif()

_json(value manifest_version)
check_equal("manifest_version" "${value}" "1")
_json(value name)
check_equal("name" "${value}" "praenora-runtime-deps")
_json(value version)
check_equal("version" "${value}" "${VERSION}")
_json(value package)
check_equal("package" "${value}" "${PACKAGE_NAME}")
_json(value platform os)
check_equal("platform.os" "${value}" "${OS}")
_json(value platform arch)
check_equal("platform.arch" "${value}" "${ARCH}")
_json(value compiler label)
check_equal("compiler.label" "${value}" "${COMPILER_LABEL}")
_json(value build_type)
check_equal("build_type" "${value}" "${BUILD_TYPE}")
foreach(component IN ITEMS llvm roadrunner antimony nlohmann-json json-schema-validator)
    _json(value components ${component} version)
    if(value MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+$")
        _report(TRUE "components.${component}.version is a version (${value})")
    else()
        _report(FALSE "components.${component}.version is a version, not '${value}'")
    endif()
endforeach()

# The directories for consumers.
string(JSON count ERROR_VARIABLE _json_error LENGTH "${manifest}" consumer cmake_prefix_path)
if(NOT _json_error AND count GREATER 0)
    _report(TRUE "consumer.cmake_prefix_path lists ${count} directories")
    math(EXPR last "${count} - 1")
    foreach(index RANGE ${last})
        _json(dir consumer cmake_prefix_path ${index})
        if(IS_DIRECTORY "${BUNDLE}/${dir}")
            _report(TRUE "consumer.cmake_prefix_path: ${dir} is a directory")
        else()
            _report(FALSE "consumer.cmake_prefix_path: ${dir} is a directory")
        endif()
    endforeach()
    _json(first consumer cmake_prefix_path 0)
    check_equal("consumer.cmake_prefix_path's first directory" "${first}" "json-schema-validator")
else()
    _report(FALSE "consumer.cmake_prefix_path lists directories")
endif()
# The static libraries of libAntimony and SBMLNetwork keep the prefix lib on Windows too, and
# SBMLNetwork's carries the postfix of the MSVC runtime library that libroadrunner-deps adds to
# its libraries there: md for /MD (Release), mdd for /MDd (Debug).
if(OS STREQUAL "windows")
    set(exe ".exe")
    set(static_prefix "")
    set(static_suffix ".lib")
    set(sbml_package libsbml-static)
    if(BUILD_TYPE STREQUAL "Debug")
        set(sbmlnetwork_library libsbmlnetwork-staticmdd.lib)
    else()
        set(sbmlnetwork_library libsbmlnetwork-staticmd.lib)
    endif()
    set(antimony_library libantimony-static.lib)
else()
    set(exe "")
    set(static_prefix "lib")
    set(static_suffix ".a")
    set(sbml_package sbml-static)
    set(sbmlnetwork_library libsbmlnetwork-static.a)
    set(antimony_library libantimony-static.a)
endif()
_json(llvm consumer llvm_install_prefix)
check_exists("${llvm}/bin/llvm-config${exe}")

# The files the Praenora runtime's finders look for, and the bundle's CMake package.
foreach(file IN ITEMS
        "lib/cmake/PraenoraRuntimeDeps/PraenoraRuntimeDepsConfig.cmake"
        "lib/cmake/PraenoraRuntimeDeps/PraenoraRuntimeDepsConfigVersion.cmake"
        "roadrunner/lib/cmake/roadrunner-static-config.cmake"
        "roadrunner/include/rr/rrVersionInfo.h"
        "roadrunner/lib/cmake/${sbml_package}-config.cmake"
        "roadrunner/include/sbmlnetwork/libsbmlnetwork_common.h"
        "roadrunner/lib/${sbmlnetwork_library}"
        "antimony/include/antimony_api.h"
        "antimony/lib/${antimony_library}"
        "json-schema-validator/include/nlohmann/json.hpp"
        "json-schema-validator/include/nlohmann/json-schema.hpp"
        "json-schema-validator/share/cmake/nlohmann_json/nlohmann_jsonConfig.cmake"
        "json-schema-validator/lib/cmake/nlohmann_json_schema_validator/\
nlohmann_json_schema_validatorConfig.cmake"
        "json-schema-validator/lib/${static_prefix}nlohmann_json_schema_validator${static_suffix}")
    check_exists("${file}")
endforeach()

# License files: at least one for this repository and for each component, and each exists.
# check_licenses(<what> <member>...)
macro(check_licenses what)
    string(JSON _count ERROR_VARIABLE _json_error LENGTH "${manifest}" ${ARGN})
    if(NOT _json_error AND _count GREATER 0)
        _report(TRUE "${what} lists ${_count} license file(s)")
        math(EXPR _last "${_count} - 1")
        foreach(_index RANGE ${_last})
            _json(_license ${ARGN} ${_index})
            check_exists("${_license}")
        endforeach()
    else()
        _report(FALSE "${what} lists license files")
    endif()
endmacro()
check_licenses("source.licenses" source licenses)
foreach(component IN ITEMS llvm libroadrunner-deps roadrunner antimony nlohmann-json
                           json-schema-validator)
    check_licenses("components.${component}.licenses" components ${component} licenses)
endforeach()

# No CMake file of the bundle names the build tree, apart from the upstream exception above.
string(REGEX REPLACE "([][+.*()^$?|\\\\])" "\\\\\\1" build_dir_regex "${BUILD_DIR}/")
file(GLOB_RECURSE cmake_files LIST_DIRECTORIES false "${BUNDLE}/*.cmake")
list(LENGTH cmake_files cmake_file_count)
set(naming_build_tree "")
foreach(file IN LISTS cmake_files)
    file(STRINGS "${file}" lines REGEX "${build_dir_regex}")
    foreach(line IN LISTS lines)
        if(NOT line MATCHES "^list\\(APPEND CMAKE_MODULE_PATH \"[^\"]*\"\\)$")
            file(RELATIVE_PATH relative "${BUNDLE}" "${file}")
            list(APPEND naming_build_tree "${relative}: ${line}")
        endif()
    endforeach()
endforeach()
if(naming_build_tree)
    list(JOIN naming_build_tree "\n  " naming_build_tree)
    _report(FALSE "no CMake file of the bundle names the build tree:\n  ${naming_build_tree}")
else()
    _report(TRUE "none of the bundle's ${cmake_file_count} CMake files names the build tree")
endif()

if(failures GREATER 0)
    message(FATAL_ERROR "${failures} check(s) failed")
endif()
