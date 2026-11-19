# Outputs

A build produces a bundle: a directory that holds the installations of LLVM, libRoadRunner (with
libroadrunner-deps), libAntimony and json-schema-validator (with nlohmann/json), a manifest and a
CMake package. The `package` target archives it. This document describes the bundle, its name
and version, and how the [Praenora runtime](https://github.com/INFLECT-Praenora/praenora-runtime)
consumes it.

## Layout

```
<bundle>/
  praenora-runtime-deps.json        manifest
  lib/cmake/PraenoraRuntimeDeps/    CMake package: version and platform check, variables
  llvm/                             LLVM 13.0.1: bin/llvm-config, include/, lib/ (static libraries),
                                    lib/cmake/llvm/
  roadrunner/                       libRoadRunner 2.11.0 and a copy of libroadrunner-deps:
                                    include/ (rr/, sbml/, sbmlnetwork/, Poco/, ...),
                                    lib/ (roadrunner-static and the static libraries it links,
                                    and libRoadRunner's shared libraries),
                                    lib/cmake/ (CMake packages; POCO's in lib/cmake/Poco/)
  antimony/                         libAntimony 3.3.0: include/antimony_api.h,
                                    lib/libantimony-static.a, a shared library and
                                    command-line tools in bin/
  json-schema-validator/            json-schema-validator 2.4.1:
                                    include/nlohmann/json-schema.hpp,
                                    lib/libnlohmann_json_schema_validator.a (static),
                                    lib/cmake/nlohmann_json_schema_validator/;
                                    and the nlohmann/json 3.12.0 it is compiled against:
                                    include/nlohmann/, share/cmake/nlohmann_json/
```

The installation directories correspond to the prefixes that the Praenora runtime's
documentation calls `<LLVM>`, `<RR>`, `<ANT>` and `<json-schema-validator prefix>`.

nlohmann/json names its version in the symbols of every function that takes its types, such as
json-schema-validator's, so a consumer of json-schema-validator must compile against the same
nlohmann/json version. The bundle therefore holds both, and a consumer must find the bundle's
nlohmann/json before any other ([Consuming a bundle](#consuming-a-bundle)).

## Names

A bundle's name identifies its version, platform, compiler and build type:

```
praenora-runtime-deps-<version>-<os>-<arch>-<compiler>-<config>
```

for example `praenora-runtime-deps-0.1.0-macos-arm64-appleclang17-release`. No field contains `-`.

| Field | Values | Source |
|---|---|---|
| `version` | `MAJOR.MINOR.PATCH` ([Versions](#versions)) | `project(VERSION)` in `CMakeLists.txt` |
| `os` | `linux`, `macos`, `windows` | the target system |
| `arch` | `x86_64`, `arm64` | `CMAKE_OSX_ARCHITECTURES` on macOS, the compiler's target elsewhere |
| `compiler` | `appleclang<major>`, `clang<major>`, `gcc<major>`, `msvc<toolset>` | the C++ compiler; for MSVC its toolset, such as `msvc143` for Visual Studio 2022 |
| `config` | `release`, `debug` | `CMAKE_BUILD_TYPE` |

The operating system and architecture names are the Praenora runtime's. The archive is
`<name>.tar.xz` on Linux and macOS and `<name>.zip` on Windows, written to
`build/<preset>/package/`; it unpacks into a directory `<name>/`. Beside it, `<name>.tar.xz.sha256`
(or `.zip.sha256`) holds its SHA-256 checksum in the format of `sha256sum`.

Labels that do not appear in the name are in the manifest and the CMake package: the macOS
deployment target, the Linux distribution, the compiler's full version, the C++ standard library
and the MSVC runtime library.

## Versions

The bundle's version follows semantic versioning and is independent of the upstream versions,
which the manifest records. It is `project(VERSION)` in `CMakeLists.txt`.

- **Minor version** (while the major version is 0), or **major version** (from 1.0): raised by
  every change to what a consumer links or finds: an upstream commit, an upstream build option, a
  default such as the macOS deployment target, the layout, or a manifest format version.
- **Patch version**: raised by changes that leave the libraries and the layout as they were, such
  as a new manifest field, a fix to the CMake package, or documentation.

Bundles of one version built on other platforms or with other compilers differ in their names. Two
builds of one commit of this repository have the same version; the manifest's `source.commit`
identifies the commit.

The CMake package accepts a requested version when the bundle's version is at least that version
and, while the major version is 0, has the same minor version (from 1.0, the same major version).
A consumer therefore requests `MAJOR.MINOR`, for example `find_package(PraenoraRuntimeDeps 0.1)`.

## Manifest

`praenora-runtime-deps.json` is one JSON object. Paths are relative to the bundle directory. A
value that could not be determined is `null`.

| Member | Meaning |
|---|---|
| `manifest_version` | Format version of the manifest, `1`. Raised when a member is removed or changes meaning. |
| `name`, `version`, `package` | `praenora-runtime-deps`, the bundle's version and its name ([Names](#names)). |
| `source.repository`, `source.commit`, `source.modified` | This repository, the commit the bundle was built from, and whether the working tree had uncommitted changes to tracked files. |
| `platform.os`, `platform.arch` | The `os` and `arch` labels. |
| `platform.os_min_version` | macOS: the deployment target (`CMAKE_OSX_DEPLOYMENT_TARGET`). |
| `platform.distribution` | Linux: the distribution and its version, from `/etc/os-release`, such as `ubuntu-24.04`. |
| `compiler.id`, `compiler.version`, `compiler.label` | CMake's compiler identifier and version, and the `compiler` label. |
| `compiler.cxx_stdlib` | `libc++`, `libstdc++` or `msvc-stl`. |
| `compiler.msvc_runtime` | Windows: `MultiThreadedDLL` (`/MD`) or `MultiThreadedDebugDLL` (`/MDd`). |
| `build_type` | `Release` or `Debug`. |
| `components.<name>` | For `llvm`, `libroadrunner-deps`, `roadrunner`, `antimony`, `nlohmann-json` and `json-schema-validator`: `version` (as the installed files report it; `null` for libroadrunner-deps, which states none), `repository`, `ref` (the upstream tag), `commit` (the submodule's commit), `modified` (whether the submodule differs from the commit this repository records, or has changes in its working tree) and `prefix` (the directory that holds it). `components.llvm.targets` lists LLVM's targets. |
| `libraries` | Versions of libraries inside libroadrunner-deps: `libsbml`, `sundials`, `poco`, `expat`, `zlib`, `sbmlnetwork`. |
| `consumer.cmake_prefix_path` | The directories a consumer adds to `CMAKE_PREFIX_PATH`, in this order; `json-schema-validator` is first. |
| `consumer.llvm_install_prefix` | The directory a consumer passes as `LLVM_INSTALL_PREFIX`. |

## CMake package

`lib/cmake/PraenoraRuntimeDeps` holds a package that defines variables and no targets. It is found
with the bundle directory on `CMAKE_PREFIX_PATH`, or with `PraenoraRuntimeDeps_DIR` set to that
directory.

`PraenoraRuntimeDepsConfigVersion.cmake` checks the request ([Versions](#versions)) and refuses the
bundle, whatever the requested version, when the consuming project targets another operating
system or architecture, a macOS deployment target older than the bundle's, or, with MSVC, an older
toolset than the one that built the bundle. `find_package` then reports the bundle as not
accepted, with the reasons after its version.

`PraenoraRuntimeDepsConfig.cmake` sets, besides `PraenoraRuntimeDeps_VERSION`:

| Variable | Value |
|---|---|
| `PraenoraRuntimeDeps_ROOT` | The bundle directory. |
| `PraenoraRuntimeDeps_MANIFEST` | The manifest's path. |
| `PraenoraRuntimeDeps_PACKAGE_NAME` | The bundle's name. |
| `PraenoraRuntimeDeps_OS`, `_ARCH`, `_OS_MIN_VERSION`, `_COMPILER_ID`, `_COMPILER_VERSION`, `_COMPILER_LABEL`, `_CXX_STDLIB`, `_MSVC_RUNTIME`, `_BUILD_TYPE` | The labels, as in the manifest. |
| `PraenoraRuntimeDeps_LLVM_VERSION`, `_LLVM_TARGETS`, `_ROADRUNNER_VERSION`, `_ANTIMONY_VERSION`, `_LIBSBML_VERSION`, `_SUNDIALS_VERSION`, `_SBMLNETWORK_VERSION`, `_JSON_SCHEMA_VALIDATOR_VERSION`, `_NLOHMANN_JSON_VERSION` | Versions of what the bundle holds. |
| `PraenoraRuntimeDeps_PREFIX_PATH` | The absolute directories for `CMAKE_PREFIX_PATH`, in the order of `consumer.cmake_prefix_path`. |
| `PraenoraRuntimeDeps_LLVM_INSTALL_PREFIX`, `_ROADRUNNER_PREFIX`, `_ANTIMONY_PREFIX`, `_JSON_SCHEMA_VALIDATOR_PREFIX` | The installation directories. |

## Consuming a bundle

### The Praenora runtime's local presets

The Praenora runtime finds json-schema-validator and nlohmann/json, which every build of it
needs, and libRoadRunner, LLVM and libAntimony, which its providers need, through
`CMAKE_PREFIX_PATH` and `LLVM_INSTALL_PREFIX` (see `docs/platforms.md` and
`docs/developer-guide.md` in the runtime's repository). Its other dependencies (yaml-cpp, spdlog,
GoogleTest) are not in the bundle and still come from Homebrew or the distribution's packages.

With `<bundle>` the bundle directory, such as `install/macos-arm64-release` of a clone of this
repository, the hidden presets in the runtime's `CMakeUserPresets.json` list the bundle's
directories as follows; their other cache variables stay as the runtime's documentation gives
them. `<bundle>/json-schema-validator` comes before `/opt/homebrew`, which holds an nlohmann/json
of its own, so that the runtime compiles against the nlohmann/json that json-schema-validator was
compiled against ([Layout](#layout)).

```json
{
  "name": "dev-local",
  "hidden": true,
  "cacheVariables": {
    "CMAKE_PREFIX_PATH": "<bundle>/json-schema-validator;/opt/homebrew"
  }
},
{
  "name": "dev-engines-local",
  "hidden": true,
  "cacheVariables": {
    "CMAKE_PREFIX_PATH": "<bundle>/json-schema-validator;/opt/homebrew;<bundle>/roadrunner;<bundle>/roadrunner/lib/cmake;<bundle>/roadrunner/lib/cmake/Poco;<bundle>/llvm;<bundle>/antimony",
    "LLVM_INSTALL_PREFIX": "<bundle>/llvm",
    "PRAENORA_WITH_ROADRUNNER": "ON",
    "PRAENORA_WITH_ANTIMONY": "ON"
  }
}
```

The presets for one provider take the corresponding subset after
`<bundle>/json-schema-validator;/opt/homebrew`: for `dev-roadrunner-local`, the `roadrunner`
directories, `llvm` and `LLVM_INSTALL_PREFIX`; for `dev-antimony-local`, `<bundle>/roadrunner`,
`<bundle>/roadrunner/lib/cmake` and `<bundle>/antimony`. On macOS, the runtime's
`CMAKE_OSX_DEPLOYMENT_TARGET` must be at least the bundle's (`platform.os_min_version`, 14.0 by
default).

The runtime's sanitizer builds compile json-schema-validator from its sources instead
(`PRAENORA_FETCH_JSON_SCHEMA_VALIDATOR`). The submodule `external/json-schema-validator` of a
clone of this repository is a copy of the commit the runtime pins, which
`FETCHCONTENT_SOURCE_DIR_NLOHMANN_JSON_SCHEMA_VALIDATOR` can name (not yet verified).

### Checking a bundle at build time

A consumer's build can check a bundle's version and labels before it uses the bundle:

```cmake
# CMAKE_PREFIX_PATH holds <bundle>, or PraenoraRuntimeDeps_DIR names
# <bundle>/lib/cmake/PraenoraRuntimeDeps.
find_package(PraenoraRuntimeDeps 0.1 CONFIG REQUIRED)
list(PREPEND CMAKE_PREFIX_PATH ${PraenoraRuntimeDeps_PREFIX_PATH})
set(LLVM_INSTALL_PREFIX "${PraenoraRuntimeDeps_LLVM_INSTALL_PREFIX}")
```

`find_package` stops the configuration when the bundle has another minor version or was built for
another platform ([CMake package](#cmake-package)). The other variables, such as
`PraenoraRuntimeDeps_COMPILER_LABEL` and `PraenoraRuntimeDeps_ROADRUNNER_VERSION`, are there for
further checks. The current Praenora runtime does not call `find_package(PraenoraRuntimeDeps)`; it
checks the versions of libRoadRunner, LLVM and libAntimony itself.

### Moving a bundle

A bundle can be moved, or unpacked anywhere, with one exception that the Praenora runtime handles:
libRoadRunner's package `roadrunner/lib/cmake/roadrunner-static-config.cmake` names LLVM's static
libraries by their absolute paths at the bundle's original location, as libRoadRunner's own release
binaries do with the paths of their build machine. The runtime's finder
(`cmake/PraenoraRoadrunner.cmake` in its repository) replaces each such path that does not exist
with the library of the same name in `LLVM_INSTALL_PREFIX/lib`. Another consumer needs the same
replacement. On a machine where the original location still exists, those paths keep naming the
libraries there.

The package files of libSBML, NuML and libSEDML (`roadrunner/lib/cmake/sbml-static-config.cmake`
and the two beside it) also append a directory of the build machine to `CMAKE_MODULE_PATH`: the
find modules of libroadrunner-deps' installation in the build tree. Where that directory does not
exist, the line has no effect and CMake's own `FindEXPAT` module is used, as with libRoadRunner's
release binaries.

### Distribution

Distributing a bundle, as an archive or otherwise, raises the license questions that the Praenora
runtime's open-questions register (`docs/open-questions.md` in its repository) records for its
providers: OQ-27 for libRoadRunner and LLVM, OQ-29 for libAntimony. Among them, libSBML is licensed
under the LGPL 2.1 and the providers link it statically.
