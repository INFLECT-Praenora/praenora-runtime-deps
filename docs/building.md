# Building the dependencies

This guide is for developers who build the dependency bundle of the
[Praenora runtime](https://github.com/INFLECT-Praenora/praenora-runtime) on their own machine. What
the bundle holds, and how the runtime consumes it, is in [outputs.md](outputs.md); how GitHub
Actions builds the bundles and how they are published is in [releasing.md](releasing.md).

## Requirements

- CMake 3.24 or newer and Ninja: the build tools of the Praenora runtime.
- A C and C++ compiler of one toolchain: AppleClang on macOS (AppleClang 17 is verified), GCC or
  Clang on Linux, MSVC of Visual Studio 2022 on Windows. The Praenora runtime links the bundle's
  static libraries, so build the bundle with the compiler that builds the runtime, or an older
  one of the same family.
- Python 3, which LLVM's configuration requires.
- Git, to fetch the submodules and to record their commits in the manifest.
- Disk space, measured for a macOS arm64 Release build: 2.1 GB for the sources (fetched without
  history), 0.7 GB for the build tree, 0.4 GB for the bundle and 64 MB for its archive.

Nothing else is needed: every library of the bundle is built from the submodules. The build itself
never uses the network.

## Getting the sources

The upstream sources are submodules under `external/`; libroadrunner-deps has submodules of its
own. Fetch them all, without history:

```sh
git submodule update --init --recursive --depth 1
```

or clone with them:

```sh
git clone --recurse-submodules --shallow-submodules https://github.com/INFLECT-Praenora/praenora-runtime-deps.git
```

Configuration stops with a message when a submodule is missing.

## Presets

Each preset builds one configuration for one platform into `build/<preset>` and writes the bundle to
`install/<preset>`. Both directories are ignored by git.

| Preset | Platform | Build type | Status |
|---|---|---|---|
| `macos-arm64-release` | macOS arm64 | Release | Verified |
| `macos-arm64-debug` | macOS arm64 | Debug | Not yet verified |
| `linux-x64-release` | Linux x86-64 | Release | Not yet verified |
| `linux-x64-debug` | Linux x86-64 | Debug | Not yet verified |
| `windows-x64-release` | Windows x86-64 | Release | Not yet verified |
| `windows-x64-debug` | Windows x86-64 | Debug | Not yet verified |

GitHub Actions builds and checks `linux-x64-release`, `macos-arm64-release`, `windows-x64-release`
and `windows-x64-debug` for every pull request to `main`, on fixed runner images
([releasing.md](releasing.md#the-workflow)).

On macOS and Linux, the Praenora runtime links a Release bundle in each of its build types, as it
links libRoadRunner's Release binaries; on macOS, a Debug build of the runtime is verified with a
Release bundle. On Windows, the runtime's build type must match the bundle's, because Debug and
Release builds use different C runtime libraries (`/MDd` and `/MD`).

```sh
cmake --preset macos-arm64-release
cmake --build --preset macos-arm64-release
ctest --preset macos-arm64-release
cmake --build --preset macos-arm64-release --target package
```

The build runs the upstream builds one after another, each with the full parallelism of its own
Ninja build, and prints their output as they run. A Release build on a 10-core Apple silicon
machine took 12 minutes. Building again checks each upstream build for changes; a second build
without changes took 22 seconds, and the archive 45 seconds.

Settings of one machine, such as a compiler launcher, go into a `CMakeUserPresets.json` (ignored by
git) whose presets inherit the presets above.

## Options

| Cache variable | Default | Meaning |
|---|---|---|
| `CMAKE_INSTALL_PREFIX` | `install/<preset>` (`<build>/install` without a preset) | The bundle directory. The build writes the bundle there; there is no separate install step. |
| `CMAKE_OSX_DEPLOYMENT_TARGET` | `14.0` | The oldest macOS the bundle supports (macOS only). 14.0 matches the upstream release binaries the Praenora runtime was first verified with. The runtime must use the same target or a newer one. |
| `CMAKE_OSX_ARCHITECTURES` | `arm64` in the macOS presets | One architecture. libRoadRunner builds for x86_64 when this is empty, so the build sets it to the host's architecture when no preset does. |
| `PRAENORA_DEPS_LLVM_TARGETS` | `host` | `LLVM_TARGETS_TO_BUILD` of the LLVM build. libRoadRunner initializes the native target only. `all`, the upstream default, builds every target and takes longer. |
| `CMAKE_C_COMPILER_LAUNCHER`, `CMAKE_CXX_COMPILER_LAUNCHER` | empty | Passed to every upstream build, for example `ccache`. |

## What the build does

`CMakeLists.txt` is a superbuild: each upstream project is an external project
([`cmake/PraenoraDepsUpstreams.cmake`](../cmake/PraenoraDepsUpstreams.cmake)) built from its
submodule. Every upstream build gets the same compilers, build type, architecture and deployment
target, position-independent code (the Praenora runtime links the static libraries into shared
provider libraries) and the library directory `lib`. CMake's user package registry is not
searched, so packages registered on the build machine are not found, and installation messages
name only the files that changed.

1. **LLVM** (`external/llvm`, the `llvm` directory of sys-bio's LLVM 13 fork) installs into
   `<bundle>/llvm`. The pinned commit is the head of the fork's branch `release/13.x`: the tag
   `v13.1` and the fork's fix for GCC 13, without which `llvm/Support/Signals.h` does not compile
   with GCC 13 (it uses `uintptr_t` without including `<cstdint>`). It keeps the fork's defaults
   except: the target list (`PRAENORA_DEPS_LLVM_TARGETS`), and the optional host libraries
   libxml2, libedit, libpfm, Z3, zlib, terminfo and the language bindings, which are turned off so
   that the bundle does not depend on what the build machine has installed. libRoadRunner links
   none of them.
2. **libroadrunner-deps** (`external/libroadrunner-deps`) builds libSBML, SUNDIALS, POCO,
   SBMLNetwork, CLAPACK, NLEQ1, NLEQ2, rr-libstruct, expat, zlib, bzip2, NuML and libSEDML with its
   defaults, and installs into the build tree (`work/libroadrunner-deps/install`).
3. **libRoadRunner** (`external/roadrunner`) is built against both, with its C and C++ libraries
   only (no tests, plugins, Python or Java bindings, examples, applications or documentation), and
   installs into `<bundle>/roadrunner`. Its installation copies libroadrunner-deps into the same
   directory, as its release binaries do.
4. **libAntimony** (`external/antimony`) is built against libroadrunner-deps, without QTAntimony,
   Python, Julia, CellML or its tests, and installs into `<bundle>/antimony`.
5. **nlohmann/json** (`external/nlohmann-json`), header-only, installs into
   `<bundle>/json-schema-validator` with its defaults and without its tests. The options that
   change the names of its symbols, such as `JSON_Diagnostics`, keep their defaults, as in the
   Praenora runtime.
6. **json-schema-validator** (`external/json-schema-validator`) is built as a static library
   against that nlohmann/json, without its tests or examples, and installs into the same
   directory. Its build downloads nlohmann/json when it does not find it; the build sets
   `FETCHCONTENT_FULLY_DISCONNECTED`, which makes that an error.
7. **The bundle step** ([`cmake/PraenoraDepsBundle.cmake`](../cmake/PraenoraDepsBundle.cmake))
   reads the versions the installed files report and stops when one of LLVM, libRoadRunner,
   libAntimony, nlohmann/json and json-schema-validator differs from
   [`cmake/PraenoraDepsVersions.cmake`](../cmake/PraenoraDepsVersions.cmake), or when an object
   file path below `build/<preset>/work` is longer than `PRAENORA_DEPS_LONGEST_OBJECT_PATH` there
   (on Windows, configuration checks the build tree's path with that length,
   [Platform notes](#platform-notes)).
   It records the commit of this repository and of each submodule, copies this repository's
   `LICENSE` and the license files that `cmake/PraenoraDepsVersions.cmake` lists for each
   component into `licenses/` (and stops when one is missing), and writes the manifest
   `praenora-runtime-deps.json` and the CMake package `PraenoraRuntimeDeps` into the bundle.

The target `package` builds everything, then archives the bundle with CPack
([`cmake/PraenoraDepsPackage.cmake`](../cmake/PraenoraDepsPackage.cmake)).

## Checking a bundle

`ctest --preset <preset>` runs two tests on the bundle in `CMAKE_INSTALL_PREFIX`:

- `bundle.manifest` checks that the manifest names this build's version, platform and compiler,
  that the directories it lists for consumers exist, with `json-schema-validator` first, that the
  files the Praenora runtime's finders look for exist, that it lists license files for this
  repository and for every component and that they exist, and that no CMake file of the bundle
  names a path in the build tree.
- `bundle.consumer` configures and builds [`tests/consumer`](../tests/consumer), a project that
  finds the bundle through `find_package(PraenoraRuntimeDeps)` with the bundle as its only prefix,
  finds json-schema-validator and nlohmann/json (and checks that both come from the bundle),
  libRoadRunner and libAntimony as the Praenora runtime does, and links them into one program.
  The program compares the versions the libraries report with the bundle's, converts an Antimony
  model to SBML and simulates it with libRoadRunner against the exact solution, and validates a
  valid and an invalid document against a JSON Schema with json-schema-validator. The
  project also checks that the bundle's version file refuses a newer version, another operating
  system, another architecture and, on macOS, an older deployment target.

The final check is a build of the Praenora runtime with its `roadrunner` and `antimony`
providers against the bundle, and its tests ([outputs.md](outputs.md#consuming-a-bundle)).

## Updating an upstream dependency

The submodule commit, the pin in
[`cmake/PraenoraDepsVersions.cmake`](../cmake/PraenoraDepsVersions.cmake) and the bundle's version
change together. For example, for a new libRoadRunner tag `v2.11.1`:

1. Check out the tag in the submodule:

   ```sh
   git -C external/roadrunner fetch --depth 1 origin tag v2.11.1
   git -C external/roadrunner checkout v2.11.1
   ```

   For libroadrunner-deps, then also run
   `git -C external/libroadrunner-deps submodule update --init --recursive --depth 1`.
2. Use the versions upstream uses together: libRoadRunner's release workflow
   (`.github/workflows/main.yml` in its repository) names the libroadrunner-deps and llvm-13.x
   releases it builds against (`libroadrunner_deps_release_version`, `llvm_release_version`).
   For json-schema-validator and nlohmann/json, use the commits that the Praenora runtime pins
   for its fetched dependencies (`cmake/PraenoraDependencies.cmake` in its repository).
   When a release's tag does not compile with a supported compiler and the upstream branch of
   that release holds the fix, pin the branch's commit and record the name that
   `git describe --tags` gives it as its tag, as for LLVM (`v13.1-6-g4cb21e5280cb` on
   `release/13.x`). Fetch such a commit by its hash:
   `git -C external/llvm fetch --depth 1 origin <commit>`.
3. Update the repository, tag and version of each changed component in
   `cmake/PraenoraDepsVersions.cmake`, and raise the bundle's version in `CMakeLists.txt`
   ([outputs.md](outputs.md#versions)). Check the component's license files: the list
   `PRAENORA_DEPS_<component>_LICENSES` names them, the build stops when one of them is missing,
   and a new or changed license goes into the table in
   [outputs.md](outputs.md#licenses). When the build stops because an object file path is longer
   than `PRAENORA_DEPS_LONGEST_OBJECT_PATH`, set it to the length the message names and update
   the lengths in [Platform notes](#platform-notes) and in the workflow's comment.
4. Build and check the bundle, then build and test the Praenora runtime against it. The runtime
   accepts libRoadRunner 2.11.x, LLVM 13 and libAntimony 3.3.x only; another release needs a
   change in the runtime first.
5. Update the tables in [README.md](../README.md) and the versions named in these documents, then
   stage the submodule and the files together:
   `git add external/roadrunner cmake/PraenoraDepsVersions.cmake CMakeLists.txt README.md docs`.

Never commit changes inside a submodule's working tree: the bundle is built from upstream commits
only, and the manifest marks a component whose working tree differs from its recorded commit
(`modified`).

## Platform notes

- **macOS.** The bundle needs macOS 14.0 or later by default (`CMAKE_OSX_DEPLOYMENT_TARGET`); the
  Praenora runtime must be configured with the same deployment target or a newer one, or its linker
  warns about every library of the bundle. Building for an older target is not verified.
- **Linux.** Not yet verified. The bundle uses `lib`, never `lib64`, so its layout is the same on
  every distribution. The manifest names the distribution the bundle was built on
  (`platform.distribution`); a bundle runs on that distribution's C library version or a newer one.
- **Windows.** Not yet verified. Run the presets from a Visual Studio 2022 developer command prompt
  for x64, which provides `cl` and Ninja. The bundle uses the shared C runtime library (`/MD`, or
  `/MDd` for Debug), as the Praenora runtime requires; libRoadRunner installs a `cmake` directory
  there that the manifest lists for consumers. `cl` stops with error C1083 when the path of an
  object file is longer than 259 characters, and the upstream builds write object files up to 186
  characters below the work directory `build/<preset>/work` (`PRAENORA_DEPS_LONGEST_OBJECT_PATH`
  in [`cmake/PraenoraDepsVersions.cmake`](../cmake/PraenoraDepsVersions.cmake); the longest is a
  SUNDIALS object file in libroadrunner-deps). The path of the checkout must therefore be at most
  41 characters long, such as `C:\src\praenora-runtime-deps`; configuration stops with a message
  when the build tree's path is too long. For a checkout with a longer path, map a drive letter
  to its parent directory, for example `subst P: C:\Users\<user>\source\repos`, and run every
  command of the presets in `P:\praenora-runtime-deps`, as the workflow does
  ([releasing.md](releasing.md#the-workflow)). The build tree records the path it was configured
  from, so do not mix the two paths.
