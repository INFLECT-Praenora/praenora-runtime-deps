# praenora-runtime-deps

Builds dependencies of the
[Praenora runtime](https://github.com/INFLECT-Praenora/praenora-runtime) from source: LLVM 13,
libRoadRunner 2.11 with its dependency set libroadrunner-deps, libAntimony 3.3, and
json-schema-validator 2.4 with the nlohmann/json it is compiled against. The upstream sources are
git submodules under `external/`. The build produces a bundle: one directory, and optionally one
archive, that holds the installations in the layout the Praenora runtime's build expects, with the
libraries' license files, a manifest and a CMake package that state the bundle's version, platform
and compiler. GitHub Actions builds the bundles for Linux x86-64, macOS arm64 and Windows x86-64,
and releases of this repository publish them for automated builds of the runtime
([docs/releasing.md](docs/releasing.md)).

| Component | Upstream | Pinned | Bundle directory |
|---|---|---|---|
| LLVM 13.0.1 | [sys-bio/llvm-13.x](https://github.com/sys-bio/llvm-13.x) | `v13.1` | `llvm/` |
| libroadrunner-deps (libSBML, SUNDIALS, POCO, SBMLNetwork, expat, zlib, ...) | [sys-bio/libroadrunner-deps](https://github.com/sys-bio/libroadrunner-deps) | `v2.3.7` | copied into `roadrunner/` |
| libRoadRunner 2.11.0 | [sys-bio/roadrunner](https://github.com/sys-bio/roadrunner) | `v2.11.0` | `roadrunner/` |
| libAntimony 3.3.0 | [sys-bio/antimony](https://github.com/sys-bio/antimony) | `v3.3.0` | `antimony/` |
| nlohmann/json 3.12.0 | [nlohmann/json](https://github.com/nlohmann/json) | `v3.12.0` | `json-schema-validator/` |
| json-schema-validator 2.4.1 | [pboettch/json-schema-validator](https://github.com/pboettch/json-schema-validator) | `2.4.1` | `json-schema-validator/` |

## Quick start

macOS arm64, from a fresh clone:

```sh
git submodule update --init --recursive --depth 1
cmake --preset macos-arm64-release
cmake --build --preset macos-arm64-release       # writes the bundle to install/macos-arm64-release
ctest --preset macos-arm64-release               # checks the bundle
cmake --build --preset macos-arm64-release --target package
```

The last command writes
`build/macos-arm64-release/package/praenora-runtime-deps-<version>-macos-arm64-<compiler>-release.tar.xz`
and its `.sha256` file. On Linux and Windows, use the `linux-x64-*` and `windows-x64-*` presets.

To build the Praenora runtime against the bundle, point its local presets at the bundle's
directories ([docs/outputs.md](docs/outputs.md#consuming-a-bundle)). The archives of a release can
be used the same way ([docs/outputs.md](docs/outputs.md#from-a-release)).

## Status

Verified on macOS arm64 with AppleClang 17 (Release): the build, the bundle's checks, and a Debug
build of the Praenora runtime with its roadrunner and antimony providers against an unpacked copy
of the archive, with json-schema-validator and nlohmann/json from the bundle, in which all 945
tests of the runtime pass. The Linux and Windows presets are written but not yet verified. The
GitHub Actions workflow that builds the bundles and drafts releases is written but has not run
yet (not yet verified), and no release has been published.

## Documentation

- [docs/building.md](docs/building.md): requirements, presets, options, what the build does,
  checking a bundle and updating an upstream dependency.
- [docs/outputs.md](docs/outputs.md): the bundle's layout, name, version scheme, manifest and
  CMake package, how the Praenora runtime consumes a bundle, and the licenses of what it holds.
- [docs/releasing.md](docs/releasing.md): the GitHub Actions workflow, its runners and the release
  procedure.
- [AGENTS.md](AGENTS.md): guide for contributors and coding agents.

## License

This repository's files are under the MIT license ([LICENSE](LICENSE)), copyright The Praenora
developers. The libraries that the build compiles into a bundle are not: each keeps the license of
its upstream project, and each bundle holds their license files in `licenses/`
([docs/outputs.md](docs/outputs.md#licenses)).
