# The bundle step: cmake -DPRAENORA_DEPS_BUNDLE_INPUTS=<file> -P PraenoraDepsBundle.cmake
#
# Run by the target praenora_deps_bundle after the upstream builds
# (cmake/PraenoraDepsPackage.cmake). It
# 1. reads the versions that the installed files report: LLVM (LLVMConfig.cmake), libRoadRunner
#    (rr/rrVersionInfo.h), libAntimony (antimony_version.txt, which its build writes but does
#    not install), nlohmann/json and json-schema-validator (their CMake package version files),
#    and the libraries of libroadrunner-deps (their CMake package version files; SBMLNetwork's
#    VERSION.txt in its sources, since it installs no version);
# 2. stops with an error when the version of LLVM, libRoadRunner, libAntimony, nlohmann/json or
#    json-schema-validator differs from cmake/PraenoraDepsVersions.cmake;
# 3. records the commit of this repository and of each submodule, and whether either differs from
#    what this repository's HEAD records;
# 4. copies this repository's LICENSE and each component's license files
#    (PRAENORA_DEPS_<component>_LICENSES) into <bundle>/licenses, and stops with an error when one
#    is missing;
# 5. writes <bundle>/praenora-runtime-deps.json and the CMake package
#    <bundle>/lib/cmake/PraenoraRuntimeDeps (docs/outputs.md).
#
# Paths in the manifest are relative to the bundle directory, so the bundle can be moved.

cmake_minimum_required(VERSION 3.24)

if(NOT PRAENORA_DEPS_BUNDLE_INPUTS OR NOT EXISTS "${PRAENORA_DEPS_BUNDLE_INPUTS}")
    message(FATAL_ERROR "PRAENORA_DEPS_BUNDLE_INPUTS must name the inputs file of the build tree.")
endif()
include("${PRAENORA_DEPS_BUNDLE_INPUTS}")
set(bundle "${PRAENORA_DEPS_BUNDLE_DIR}")
set(templates "${CMAKE_CURRENT_LIST_DIR}")

# _praenora_deps_package_version(<out> <glob>...): PACKAGE_VERSION of the first version file
# matching one of the globs (relative to the bundle), or empty.
function(_praenora_deps_package_version out)
    set(files "")
    foreach(glob IN LISTS ARGN)
        file(GLOB matches LIST_DIRECTORIES false "${bundle}/${glob}")
        list(APPEND files ${matches})
    endforeach()
    set(version "")
    foreach(file IN LISTS files)
        file(STRINGS "${file}" lines REGEX "^[ \t]*set\\(PACKAGE_VERSION ")
        foreach(line IN LISTS lines)
            if(line MATCHES "set\\(PACKAGE_VERSION \"?([0-9][0-9A-Za-z.+-]*)\"?\\)")
                set(version "${CMAKE_MATCH_1}")
                break()
            endif()
        endforeach()
        if(version)
            break()
        endif()
    endforeach()
    set(${out} "${version}" PARENT_SCOPE)
endfunction()

# _praenora_deps_first_line(<out> <file>): the first line of <file>, stripped, or empty.
function(_praenora_deps_first_line out file)
    set(line "")
    if(EXISTS "${file}")
        file(STRINGS "${file}" lines LIMIT_COUNT 1)
        string(STRIP "${lines}" line)
    endif()
    set(${out} "${line}" PARENT_SCOPE)
endfunction()

# 1. Installed versions.
set(llvm_config "${bundle}/llvm/lib/cmake/llvm/LLVMConfig.cmake")
if(NOT EXISTS "${llvm_config}")
    message(FATAL_ERROR "LLVM is not installed in the bundle: ${llvm_config} is missing.")
endif()
file(STRINGS "${llvm_config}" llvm_lines REGEX "^set\\(LLVM_(PACKAGE_VERSION|TARGETS_TO_BUILD) ")
set(installed_llvm "")
set(llvm_targets "")
foreach(line IN LISTS llvm_lines)
    if(line MATCHES "^set\\(LLVM_PACKAGE_VERSION ([^)]+)\\)")
        set(installed_llvm "${CMAKE_MATCH_1}")
    elseif(line MATCHES "^set\\(LLVM_TARGETS_TO_BUILD ([^)]+)\\)")
        set(llvm_targets "${CMAKE_MATCH_1}")
    endif()
endforeach()

set(rr_header "${bundle}/roadrunner/include/rr/rrVersionInfo.h")
if(NOT EXISTS "${rr_header}")
    message(FATAL_ERROR "libRoadRunner is not installed in the bundle: ${rr_header} is missing.")
endif()
file(STRINGS "${rr_header}" rr_lines REGEX "^#define RR_VERSION_(MAJOR|MINOR|PATCH) [0-9]+")
set(rr_parts "")
foreach(part IN ITEMS MAJOR MINOR PATCH)
    foreach(line IN LISTS rr_lines)
        if(line MATCHES "^#define RR_VERSION_${part} ([0-9]+)")
            list(APPEND rr_parts "${CMAKE_MATCH_1}")
        endif()
    endforeach()
endforeach()
list(JOIN rr_parts "." installed_roadrunner)

set(antimony_header "${bundle}/antimony/include/antimony_api.h")
if(NOT EXISTS "${antimony_header}")
    message(FATAL_ERROR "libAntimony is not installed in the bundle: ${antimony_header} is "
        "missing.")
endif()
_praenora_deps_first_line(installed_antimony
    "${PRAENORA_DEPS_WORK_DIR}/antimony/build/antimony_version.txt")

set(json_packages "json-schema-validator/lib/cmake/nlohmann_json_schema_validator")
_praenora_deps_package_version(installed_nlohmann_json
    "json-schema-validator/share/cmake/nlohmann_json/nlohmann_jsonConfigVersion.cmake")
_praenora_deps_package_version(installed_json_schema_validator
    "${json_packages}/nlohmann_json_schema_validatorConfigVersion.cmake")

# _praenora_deps_roadrunner_package_version(<out> <glob>): the same in libRoadRunner's package
# directories, lib/cmake and, on Windows, cmake.
macro(_praenora_deps_roadrunner_package_version out glob)
    _praenora_deps_package_version(${out} "roadrunner/lib/cmake/${glob}" "roadrunner/cmake/${glob}")
endmacro()
# libSBML's package is sbml-static, or libsbml-static on Windows.
_praenora_deps_roadrunner_package_version(libsbml_version "*sbml-static-config-version.cmake")
_praenora_deps_roadrunner_package_version(sundials_version "sundials/SUNDIALSConfigVersion.cmake")
_praenora_deps_roadrunner_package_version(poco_version "Poco/PocoFoundationConfigVersion.cmake")
_praenora_deps_roadrunner_package_version(expat_version "expat-*/expat-config-version.cmake")
_praenora_deps_roadrunner_package_version(zlib_version "zlib/ZLIBConfigVersion.cmake")
_praenora_deps_first_line(sbmlnetwork_version
    "${PRAENORA_DEPS_SOURCE_DIR}/external/libroadrunner-deps/third_party/SBMLNetwork/VERSION.txt")

# 2. Versions against the pins.
set(mismatches "")
foreach(pair IN ITEMS "llvm|${installed_llvm}" "roadrunner|${installed_roadrunner}"
                      "antimony|${installed_antimony}" "nlohmann-json|${installed_nlohmann_json}"
                      "json-schema-validator|${installed_json_schema_validator}")
    string(REPLACE "|" ";" pair "${pair}")
    list(GET pair 0 component)
    list(LENGTH pair pair_length)
    set(installed "")
    if(pair_length GREATER 1)
        list(GET pair 1 installed)
    endif()
    set(expected "${PRAENORA_DEPS_${component}_VERSION}")
    if(NOT installed STREQUAL expected)
        string(APPEND mismatches
            "\n  ${component}: installed '${installed}', expected '${expected}'")
    endif()
endforeach()
if(mismatches)
    message(FATAL_ERROR "The bundle's versions differ from cmake/PraenoraDepsVersions.cmake:"
        "${mismatches}\nUpdate the pins and the submodules together "
        "(docs/building.md#updating-an-upstream-dependency).")
endif()

# 3. Commits. Empty when git or the repository is not available.
set(source_commit "")
set(source_modified "")
set(git_available FALSE)
if(PRAENORA_DEPS_GIT AND EXISTS "${PRAENORA_DEPS_SOURCE_DIR}/.git")
    execute_process(COMMAND "${PRAENORA_DEPS_GIT}" -C "${PRAENORA_DEPS_SOURCE_DIR}" rev-parse HEAD
        RESULT_VARIABLE result OUTPUT_VARIABLE source_commit ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(result EQUAL 0)
        set(git_available TRUE)
        execute_process(COMMAND "${PRAENORA_DEPS_GIT}" -C "${PRAENORA_DEPS_SOURCE_DIR}"
                --no-optional-locks status --porcelain --untracked-files=no
            OUTPUT_VARIABLE status ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)
        if(status)
            set(source_modified true)
        else()
            set(source_modified false)
        endif()
    else()
        set(source_commit "")
    endif()
endif()
foreach(component IN LISTS PRAENORA_DEPS_COMPONENTS)
    set(${component}_commit "")
    set(${component}_modified "")
    if(NOT git_available)
        continue()
    endif()
    set(path "${PRAENORA_DEPS_SOURCE_DIR}/external/${component}")
    execute_process(COMMAND "${PRAENORA_DEPS_GIT}" -C "${path}" rev-parse HEAD
        RESULT_VARIABLE result OUTPUT_VARIABLE commit ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(NOT result EQUAL 0)
        continue()
    endif()
    set(${component}_commit "${commit}")
    # Modified: another commit than the superproject records, or changes in the working tree
    # (nested submodules included).
    execute_process(COMMAND "${PRAENORA_DEPS_GIT}" -C "${PRAENORA_DEPS_SOURCE_DIR}"
            --no-optional-locks ls-files --stage -- "external/${component}"
        OUTPUT_VARIABLE recorded ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)
    execute_process(COMMAND "${PRAENORA_DEPS_GIT}" -C "${path}"
            --no-optional-locks status --porcelain --untracked-files=no
        OUTPUT_VARIABLE status ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(status OR NOT recorded MATCHES "^160000 ${commit} ")
        set(${component}_modified true)
        message(WARNING "external/${component} differs from the commit this repository records, "
            "or has changes in its working tree; the manifest says so.")
    else()
        set(${component}_modified false)
    endif()
endforeach()

# 4. License files, under licenses/<component>/ with their paths in the submodule, and this
# repository's under licenses/praenora-runtime-deps/. The directory is written anew each time, so
# it holds the listed files only.
set(licenses_dir "${bundle}/licenses")
file(REMOVE_RECURSE "${licenses_dir}")
set(missing_licenses "")
set(source_licenses "licenses/praenora-runtime-deps/LICENSE")
if(EXISTS "${PRAENORA_DEPS_SOURCE_DIR}/LICENSE")
    configure_file("${PRAENORA_DEPS_SOURCE_DIR}/LICENSE" "${bundle}/${source_licenses}" COPYONLY)
else()
    string(APPEND missing_licenses "\n  LICENSE")
endif()
foreach(component IN LISTS PRAENORA_DEPS_COMPONENTS)
    set(${component}_licenses "")
    foreach(file IN LISTS PRAENORA_DEPS_${component}_LICENSES)
        set(from "${PRAENORA_DEPS_SOURCE_DIR}/external/${component}/${file}")
        if(EXISTS "${from}")
            set(to "licenses/${component}/${file}")
            configure_file("${from}" "${bundle}/${to}" COPYONLY)
            list(APPEND ${component}_licenses "${to}")
        else()
            string(APPEND missing_licenses "\n  external/${component}/${file}")
        endif()
    endforeach()
endforeach()
if(missing_licenses)
    message(FATAL_ERROR "License files listed in cmake/PraenoraDepsVersions.cmake are missing:"
        "${missing_licenses}\nUpdate the lists with the submodules "
        "(docs/building.md#updating-an-upstream-dependency).")
endif()

# 5a. What a consumer adds to CMAKE_PREFIX_PATH, relative to the bundle: the directories that
# exist among those the Praenora runtime's finders need (docs/outputs.md#consuming-a-bundle).
# json-schema-validator comes first: its nlohmann/json must be found before any other.
set(prefix_path "")
foreach(dir IN ITEMS json-schema-validator roadrunner roadrunner/lib/cmake
                     roadrunner/lib/cmake/Poco roadrunner/cmake llvm antimony)
    if(IS_DIRECTORY "${bundle}/${dir}")
        list(APPEND prefix_path "${dir}")
    endif()
endforeach()

# 5b. The manifest.
# _praenora_deps_json(<out> <value>): <value> as a JSON string, or null when it is empty.
function(_praenora_deps_json out value)
    if(value STREQUAL "")
        set(${out} "null" PARENT_SCOPE)
        return()
    endif()
    string(REPLACE "\\" "\\\\" value "${value}")
    string(REPLACE "\"" "\\\"" value "${value}")
    set(${out} "\"${value}\"" PARENT_SCOPE)
endfunction()
# _praenora_deps_json_bool(<out> <value>): true, false or null.
function(_praenora_deps_json_bool out value)
    if(value STREQUAL "")
        set(${out} "null" PARENT_SCOPE)
    elseif(value)
        set(${out} "true" PARENT_SCOPE)
    else()
        set(${out} "false" PARENT_SCOPE)
    endif()
endfunction()
# _praenora_deps_json_array(<out> <list>): the list as a JSON array of strings.
function(_praenora_deps_json_array out)
    set(array "[]")
    set(index 0)
    foreach(item IN LISTS ARGN)
        _praenora_deps_json(item "${item}")
        string(JSON array SET "${array}" ${index} "${item}")
        math(EXPR index "${index} + 1")
    endforeach()
    set(${out} "${array}" PARENT_SCOPE)
endfunction()
# _praenora_deps_set(<path>... <json value>): sets a member of the manifest.
macro(_praenora_deps_set)
    string(JSON manifest SET "${manifest}" ${ARGV})
endmacro()

set(manifest "{}")
_praenora_deps_set(manifest_version "${PRAENORA_DEPS_MANIFEST_VERSION}")
_praenora_deps_json(value "praenora-runtime-deps")
_praenora_deps_set(name "${value}")
_praenora_deps_json(value "${PRAENORA_DEPS_VERSION}")
_praenora_deps_set(version "${value}")
_praenora_deps_json(value "${PRAENORA_DEPS_PACKAGE_NAME}")
_praenora_deps_set(package "${value}")

_praenora_deps_set(source "{}")
_praenora_deps_json(value "${PRAENORA_DEPS_HOMEPAGE}")
_praenora_deps_set(source repository "${value}")
_praenora_deps_json(value "${source_commit}")
_praenora_deps_set(source commit "${value}")
_praenora_deps_json_bool(value "${source_modified}")
_praenora_deps_set(source modified "${value}")
_praenora_deps_json_array(value ${source_licenses})
_praenora_deps_set(source licenses "${value}")

_praenora_deps_set(platform "{}")
_praenora_deps_json(value "${PRAENORA_DEPS_OS}")
_praenora_deps_set(platform os "${value}")
_praenora_deps_json(value "${PRAENORA_DEPS_ARCH}")
_praenora_deps_set(platform arch "${value}")
_praenora_deps_json(value "${PRAENORA_DEPS_OS_MIN_VERSION}")
_praenora_deps_set(platform os_min_version "${value}")
_praenora_deps_json(value "${PRAENORA_DEPS_DISTRIBUTION}")
_praenora_deps_set(platform distribution "${value}")

_praenora_deps_set(compiler "{}")
_praenora_deps_json(value "${PRAENORA_DEPS_COMPILER_ID}")
_praenora_deps_set(compiler id "${value}")
_praenora_deps_json(value "${PRAENORA_DEPS_COMPILER_VERSION}")
_praenora_deps_set(compiler version "${value}")
_praenora_deps_json(value "${PRAENORA_DEPS_COMPILER_LABEL}")
_praenora_deps_set(compiler label "${value}")
_praenora_deps_json(value "${PRAENORA_DEPS_CXX_STDLIB}")
_praenora_deps_set(compiler cxx_stdlib "${value}")
_praenora_deps_json(value "${PRAENORA_DEPS_MSVC_RUNTIME}")
_praenora_deps_set(compiler msvc_runtime "${value}")

_praenora_deps_json(value "${PRAENORA_DEPS_BUILD_TYPE}")
_praenora_deps_set(build_type "${value}")

set(llvm_prefix llvm)
set(libroadrunner-deps_prefix roadrunner)
set(roadrunner_prefix roadrunner)
set(antimony_prefix antimony)
set(nlohmann-json_prefix json-schema-validator)
set(json-schema-validator_prefix json-schema-validator)
set(llvm_installed "${installed_llvm}")
set(libroadrunner-deps_installed "")
set(roadrunner_installed "${installed_roadrunner}")
set(antimony_installed "${installed_antimony}")
set(nlohmann-json_installed "${installed_nlohmann_json}")
set(json-schema-validator_installed "${installed_json_schema_validator}")
_praenora_deps_set(components "{}")
foreach(component IN LISTS PRAENORA_DEPS_COMPONENTS)
    _praenora_deps_set(components ${component} "{}")
    _praenora_deps_json(value "${${component}_installed}")
    _praenora_deps_set(components ${component} version "${value}")
    _praenora_deps_json(value "${PRAENORA_DEPS_${component}_REPOSITORY}")
    _praenora_deps_set(components ${component} repository "${value}")
    _praenora_deps_json(value "${PRAENORA_DEPS_${component}_REF}")
    _praenora_deps_set(components ${component} ref "${value}")
    _praenora_deps_json(value "${${component}_commit}")
    _praenora_deps_set(components ${component} commit "${value}")
    _praenora_deps_json_bool(value "${${component}_modified}")
    _praenora_deps_set(components ${component} modified "${value}")
    _praenora_deps_json(value "${${component}_prefix}")
    _praenora_deps_set(components ${component} prefix "${value}")
    _praenora_deps_json_array(value ${${component}_licenses})
    _praenora_deps_set(components ${component} licenses "${value}")
endforeach()
_praenora_deps_json_array(value ${llvm_targets})
_praenora_deps_set(components llvm targets "${value}")

_praenora_deps_set(libraries "{}")
foreach(pair IN ITEMS "libsbml|${libsbml_version}" "sundials|${sundials_version}"
                      "poco|${poco_version}" "expat|${expat_version}" "zlib|${zlib_version}"
                      "sbmlnetwork|${sbmlnetwork_version}")
    string(REPLACE "|" ";" pair "${pair}")
    list(GET pair 0 library)
    list(LENGTH pair pair_length)
    set(version "")
    if(pair_length GREATER 1)
        list(GET pair 1 version)
    endif()
    _praenora_deps_json(value "${version}")
    _praenora_deps_set(libraries ${library} "${value}")
endforeach()

_praenora_deps_set(consumer "{}")
_praenora_deps_json_array(value ${prefix_path})
_praenora_deps_set(consumer cmake_prefix_path "${value}")
_praenora_deps_json(value "llvm")
_praenora_deps_set(consumer llvm_install_prefix "${value}")

file(CONFIGURE OUTPUT "${bundle}/praenora-runtime-deps.json" CONTENT "${manifest}\n" @ONLY)

# 5c. The CMake package.
set(config_prefix_path "")
foreach(dir IN LISTS prefix_path)
    list(APPEND config_prefix_path "\${PraenoraRuntimeDeps_ROOT}/${dir}")
endforeach()
set(PRAENORA_DEPS_CONFIG_PREFIX_PATH "${config_prefix_path}")
set(PRAENORA_DEPS_LLVM_INSTALLED "${installed_llvm}")
set(PRAENORA_DEPS_LLVM_TARGETS_INSTALLED "${llvm_targets}")
set(PRAENORA_DEPS_ROADRUNNER_INSTALLED "${installed_roadrunner}")
set(PRAENORA_DEPS_ANTIMONY_INSTALLED "${installed_antimony}")
set(PRAENORA_DEPS_LIBSBML_INSTALLED "${libsbml_version}")
set(PRAENORA_DEPS_SUNDIALS_INSTALLED "${sundials_version}")
set(PRAENORA_DEPS_SBMLNETWORK_INSTALLED "${sbmlnetwork_version}")
set(PRAENORA_DEPS_NLOHMANN_JSON_INSTALLED "${installed_nlohmann_json}")
set(PRAENORA_DEPS_JSON_SCHEMA_VALIDATOR_INSTALLED "${installed_json_schema_validator}")
set(PRAENORA_DEPS_MSVC_TOOLSET "")
if(PRAENORA_DEPS_COMPILER_LABEL MATCHES "^msvc([0-9]+)$")
    set(PRAENORA_DEPS_MSVC_TOOLSET "${CMAKE_MATCH_1}")
endif()
set(package_dir "${bundle}/lib/cmake/PraenoraRuntimeDeps")
configure_file("${templates}/PraenoraRuntimeDepsConfig.cmake.in"
    "${package_dir}/PraenoraRuntimeDepsConfig.cmake" @ONLY)
configure_file("${templates}/PraenoraRuntimeDepsConfigVersion.cmake.in"
    "${package_dir}/PraenoraRuntimeDepsConfigVersion.cmake" @ONLY)

message(STATUS "praenora-runtime-deps ${PRAENORA_DEPS_VERSION}: LLVM ${installed_llvm} "
    "(${llvm_targets}), libRoadRunner ${installed_roadrunner}, libAntimony ${installed_antimony}, "
    "libSBML ${libsbml_version}, SUNDIALS ${sundials_version}, SBMLNetwork ${sbmlnetwork_version}, "
    "json-schema-validator ${installed_json_schema_validator}, nlohmann/json "
    "${installed_nlohmann_json}")
message(STATUS "praenora-runtime-deps: wrote ${bundle}/praenora-runtime-deps.json")
