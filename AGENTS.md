# AGENTS.md

Guide for coding agents and human contributors working in `praenora-runtime-deps`. Read it before
changing anything.

## Purpose

This repository builds dependencies of the
[Praenora runtime](https://github.com/INFLECT-Praenora/praenora-runtime) from source and packages
them as a bundle that the runtime's build consumes: LLVM 13, libRoadRunner 2.11 with
libroadrunner-deps, and libAntimony 3.3, which the runtime's `roadrunner` and `antimony` service
providers link statically, and json-schema-validator 2.4 with the nlohmann/json 3.12 it is
compiled against, which every build of the runtime links. The upstream sources are git
submodules; this repository holds only the build, the packaging, the checks, the workflow that
builds and releases the bundles, and the documentation.

The bundle's layout matches what the Praenora runtime's finders expect, so the runtime builds
against it without changes. Producing bundles that the runtime can consume takes priority over
every other goal.

## Status

Verified on macOS arm64 with AppleClang 17 (Release): the build, the bundle's checks (`ctest`),
and a Debug build of the Praenora runtime with both providers against an unpacked copy of the
archive, with json-schema-validator and nlohmann/json from the bundle, in which all of the
runtime's tests pass. The Linux and Windows presets are written but
not yet verified. The GitHub Actions workflow (`.github/workflows/build.yml`), which builds the
bundles for pull requests and drafts releases for automated builds of the Praenora runtime, is
written but has not run yet (not yet verified); no release has been published.

## Setup and commands

Requirements: CMake 3.24+, Ninja, Python 3, Git, and a C and C++ compiler of one toolchain
(AppleClang, GCC or Clang, or MSVC of Visual Studio 2022). Details are in
[docs/building.md](docs/building.md).

```sh
git submodule update --init --recursive --depth 1   # the upstream sources, without history
cmake --preset macos-arm64-release                   # or linux-x64-*, windows-x64-*
cmake --build --preset macos-arm64-release           # builds the bundle into install/<preset>
ctest --preset macos-arm64-release                   # bundle.manifest and bundle.consumer
cmake --build --preset macos-arm64-release --target package   # build/<preset>/package/*.tar.xz
```

A full Release build took 12 minutes on a 10-core Apple silicon machine; later builds check each
upstream build for changes. Build trees go to `build/<preset>`, bundles to `install/<preset>`.

## Repository map

```
LICENSE                   MIT license of this repository's files
CMakeLists.txt            superbuild: project(VERSION) is the bundle's version
CMakePresets.json         {linux-x64,macos-arm64,windows-x64}-{release,debug}
cmake/
  PraenoraDepsVersions.cmake   upstream repositories, tags, expected versions and license files;
                               the longest object file path; manifest format
  PraenoraDepsPlatform.cmake   OS, architecture, compiler and configuration labels; bundle name
  PraenoraDepsUpstreams.cmake  the external projects and the options passed to each
  PraenoraDepsPackage.cmake    the bundle step target and CPack (target package)
  PraenoraDepsBundle.cmake     the bundle step (script): version checks, manifest, CMake package
  PraenoraRuntimeDepsConfig.cmake.in, PraenoraRuntimeDepsConfigVersion.cmake.in
                               the bundle's CMake package
tests/                    bundle.manifest (check_manifest.cmake) and bundle.consumer
                          (run_consumer.cmake, consumer/: a project that links the bundle)
external/                 submodules: llvm (sys-bio/llvm-13.x), libroadrunner-deps,
                          roadrunner, antimony (all from github.com/sys-bio), nlohmann-json
                          (nlohmann/json), json-schema-validator (pboettch/json-schema-validator)
.github/workflows/
  build.yml               builds, checks and archives the bundles; drafts a release on request
docs/                     building.md (developer guide), outputs.md (layout, names, versions,
                          manifest, CMake package, consumption, licenses), releasing.md (the
                          workflow, its runners and the release procedure)
```

## Conventions

- **Build tools.** The Praenora runtime's: CMake (3.24+, presets version 5), Ninja, CTest, CPack.
  No other build system and no scripts in other languages for the build.
- **Workflow.** One GitHub Actions workflow, `.github/workflows/build.yml`. It prepares each runner
  and runs the commands of the presets; what the build does stays in CMake. Runner labels name
  fixed image versions, never `-latest`, and actions are pinned to commits. A change to the runners
  follows [docs/releasing.md](docs/releasing.md#changing-a-runner-image).
- **CMake style.** Four-space indentation, lines of at most 100 characters, lowercase commands.
  Variables of this project start with `PRAENORA_DEPS_`; functions and macros with
  `praenora_deps_` (`_praenora_deps_` when internal to one file). Each file under `cmake/` starts
  with a comment that says what it does and what it defines.
- **Upstream builds.** Every option passed to an upstream build is set in
  `cmake/PraenoraDepsUpstreams.cmake` and explained in
  [docs/building.md](docs/building.md#what-the-build-does). Keep upstream defaults unless the
  bundle needs otherwise, and say why where an option differs.
- **Labels.** Platform names are the Praenora runtime's: `linux`, `macos`, `windows`; `x86_64`,
  `arm64`. A new label goes into the bundle name only if no field then contains `-`.
- **Text.** UTF-8 and LF line endings. Documentation is concise and factual: plain sentences, no
  idioms or figurative language. Mark anything not verified as "not yet verified".

## Change rules

- **Upstream updates.** A submodule commit, its entry in `cmake/PraenoraDepsVersions.cmake`, the
  bundle's version and the documentation change together
  ([docs/building.md](docs/building.md#updating-an-upstream-dependency)). Use the upstream
  combinations that libRoadRunner's release workflow names, and for json-schema-validator and
  nlohmann/json the commits that the Praenora runtime pins. The runtime accepts libRoadRunner
  2.11.x, LLVM 13 and libAntimony 3.3.x only; check its finders before moving past them.
- **Licenses.** This repository's files are under the MIT license (`LICENSE`). The libraries keep
  their upstream licenses: each component's license files are listed in
  `cmake/PraenoraDepsVersions.cmake` and copied into the bundle's `licenses/`. A new component, or
  an upstream update that adds, moves or changes a license file, updates that list and the table
  in [docs/outputs.md](docs/outputs.md#licenses) together.
- **nlohmann/json.** json-schema-validator and every consumer of it must compile against one
  nlohmann/json version, because nlohmann/json names its version in its symbols. Keep the
  bundle's `json-schema-validator` directory first in `consumer.cmake_prefix_path`, and keep
  nlohmann/json's options that change its symbol names at their defaults.
- **Versions.** Raise the bundle's version in `CMakeLists.txt` with every change to what a consumer
  links or finds, following [docs/outputs.md](docs/outputs.md#versions). Raise
  `PRAENORA_DEPS_MANIFEST_VERSION` when a manifest member is removed or changes meaning.
- **Consumers.** The layout, the manifest members and the CMake package's variables are an
  interface of the Praenora runtime's build. Change them only together with
  [docs/outputs.md](docs/outputs.md), and check the runtime against the new bundle.
- **Releases.** Bundles are published only as releases that the workflow drafts from `main` and an
  administrator publishes, following [docs/releasing.md](docs/releasing.md). A published release
  never changes; a rebuilt bundle gets a new version.
- **Verification.** Before reporting a change as done, build the bundle, run `ctest`, and, for any
  change to the libraries or the layout, build and test the Praenora runtime with both providers
  against it.
- **Documentation.** A change updates its code, checks and documentation in the same commit.
  Documents refer to the Praenora runtime by its repository URL and by paths inside that
  repository, never by a path on a local machine.

## Prohibitions

- No changes inside `external/`: the bundle is built from upstream commits only. Fixes go upstream;
  a submodule moves only to an upstream commit.
- No copies of upstream sources outside the submodules, and no downloads during the build.
- Never commit build trees, bundles, archives or `CMakeUserPresets.json`.
- No release, tag `v*` or release asset made by hand.
- Agent instructions live in this file only.
