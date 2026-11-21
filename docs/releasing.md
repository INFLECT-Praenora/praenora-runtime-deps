# Releasing

This document describes how GitHub Actions builds the bundles and how an administrator publishes
them as a release that automated builds of the
[Praenora runtime](https://github.com/INFLECT-Praenora/praenora-runtime) download. What a bundle
holds and how it is consumed is in [outputs.md](outputs.md); building one on your own machine is
in [building.md](building.md).

Not yet verified: the workflow has not run on GitHub yet, and its Linux and Windows builds are the
first builds of those presets.

## The workflow

[`.github/workflows/build.yml`](../.github/workflows/build.yml) (named "Build") runs:

- on every pull request to `main`;
- when run manually, on any branch: in the repository's Actions tab, *Build*, *Run workflow*; or
  `gh workflow run build.yml --ref <branch>`. GitHub offers the manual run once the workflow is on
  `main`. With the input `publish`, which only `main` accepts, the run also creates a draft
  release.

Its jobs:

1. **Prepare** reads the bundle's version from `project(VERSION)` in `CMakeLists.txt`. With
   `publish`, it stops the run unless the run is on `main` and the tag `v<version>` does not exist.
2. **One build job per bundle**, named after its preset:

   | Job | Runner | Compiler (expected) | Archive |
   |---|---|---|---|
   | `linux-x64-release` | `ubuntu-24.04` | GCC 13 | `praenora-runtime-deps-<version>-linux-x86_64-gcc13-release.tar.xz` |
   | `macos-arm64-release` | `macos-26` | AppleClang 17 (Xcode 26) | `praenora-runtime-deps-<version>-macos-arm64-appleclang17-release.tar.xz` |
   | `windows-x64-release` | `windows-2022` | MSVC of Visual Studio 2022 (toolset 143) | `praenora-runtime-deps-<version>-windows-x86_64-msvc143-release.zip` |
   | `windows-x64-debug` | `windows-2022` | MSVC of Visual Studio 2022 (toolset 143) | `praenora-runtime-deps-<version>-windows-x86_64-msvc143-debug.zip` |

   The compilers are the ones these images are expected to have; the archive names of the first
   run will show them. Each job turns off Git's line-ending conversion and turns on long paths
   (Windows), checks out the repository, fetches the submodules with
   `git submodule update --init --recursive --depth 1`, installs Ninja where it is missing (Linux
   and macOS) or enters the Visual Studio 2022 developer environment for x64, which provides `cl`
   and Ninja (Windows), and runs the commands of [building.md](building.md#presets): configure,
   build, `ctest`, and the `package` target. On Windows, it first maps the drive `P:` to the
   checkout's parent directory with `subst` and runs these commands in `P:\praenora-runtime-deps`:
   from the checkout's own path, the longest object file path of libroadrunner-deps is longer
   than `cl` accepts ([building.md](building.md#platform-notes)). It then checks that the
   manifest records unmodified sources (`source.modified` and every `components.<name>.modified`
   are `false`) and uploads the archive and its `.sha256` file as a workflow artifact named after
   the preset, kept for 7 days.
3. **Draft release**, with `publish` only: downloads the archives, checks that their names carry
   the version and that they match their `.sha256` files, writes release notes with the component
   versions from the Linux bundle's manifest, and creates the draft release `v<version>` of the
   built commit, with every archive and `.sha256` file. A draft is visible only to users with write
   access, and creates no tag; publishing it creates the tag `v<version>` on that commit.

The runner labels name fixed image versions, not `ubuntu-latest`, `macos-latest` or
`windows-latest`, which GitHub moves to newer images: the compiler of the image names the bundle,
and a consumer must build with that compiler or a newer one of the same family.

- `ubuntu-24.04` has GCC 13, and is the distribution of libRoadRunner's own Ubuntu 24 archives. A
  bundle built on it needs the C library of Ubuntu 24.04 or a newer one.
- `macos-26` has AppleClang 17, the compiler the bundle was first verified with. The deployment
  target (14.0), not the runner's macOS version, decides which macOS versions the bundle supports.
- `windows-2022` has Visual Studio 2022. Static libraries built with it can be linked by Visual
  Studio 2022 and newer; `windows-2025` has Visual Studio 2026 (toolset 145), whose static
  libraries Visual Studio 2022 cannot link.

Linux and macOS have Release bundles only: the Praenora runtime links a Release bundle in each of
its build types there. On Windows, the runtime's build type must match the bundle's, so Windows has
both ([building.md](building.md#presets)).

**Artifacts and releases.** The artifacts of a run are for checking that run's bundles: they can
be downloaded from the run's page or with `gh run download <run id>`, and they expire after
7 days. The bundles of a pull request are built from the merge commit that GitHub makes for it,
which the manifest's `source.commit` names and which is on no branch. Consumers use releases only
([outputs.md](outputs.md#from-a-release)).

**Required checks.** The jobs report the checks `Prepare`, `linux-x64-release`,
`macos-arm64-release`, `windows-x64-release` and `windows-x64-debug`. The workflow has no path
filters, so every pull request reports all of them, and the ruleset on `main` can require them.

## Repository settings

The release procedure relies on these settings:

- **Rulesets.** `main` takes changes only through pull requests with the checks above. Tags
  `v*` are created, moved or deleted by administrators only; publishing a draft release creates
  its tag, so the administrators who publish releases must be allowed to create tags.
- **Releases.** Immutable releases on: once published, a release's assets and tag cannot change.
- **Actions.** The default `GITHUB_TOKEN` reads the repository's contents only; the release job
  asks for `contents: write` itself. Workflows of pull requests from outside contributors wait for
  approval. If the allowed actions are restricted, `actions/checkout`, `actions/upload-artifact`
  and `actions/download-artifact` are allowed; the workflow pins each to a commit.

## Release procedure

1. **Prepare the change.** In a pull request to `main`, raise `project(VERSION)` in
   `CMakeLists.txt` as [outputs.md](outputs.md#versions) says, together with the change it
   versions, following the change rules of [AGENTS.md](../AGENTS.md). The pull request's checks
   build and check every bundle.
2. **Merge** the pull request into `main`.
3. **Run the workflow with `publish`** on `main`: in the Actions tab, *Build*, *Run workflow*,
   branch `main`, with *Create a draft release* checked; or

   ```sh
   gh workflow run build.yml --ref main -f publish=true
   ```

   The run stops at once if the tag `v<version>` exists; then the version was not raised.
4. **Check the draft release** `v<version>` when the run has finished. It holds four archives and
   four `.sha256` files.
   - The archive names carry the version and the expected compiler labels
     ([The workflow](#the-workflow)). Another label means that a runner image changed its compiler
     ([Changing a runner image](#changing-a-runner-image)).
   - Download the archive of your platform and check it:

     ```sh
     gh release download v<version> --repo INFLECT-Praenora/praenora-runtime-deps \
         --pattern '*-macos-arm64-*'
     shasum -a 256 -c praenora-runtime-deps-<version>-macos-arm64-appleclang17-release.tar.xz.sha256
     ```

   - Unpack it, then build the Praenora runtime with both providers against it and run its tests
     ([outputs.md](outputs.md#consuming-a-bundle)), as [AGENTS.md](../AGENTS.md) requires for any
     change to the libraries or the layout.
   - Check that the bundles may be published under the licenses of what they hold
     ([outputs.md](outputs.md#licenses)); for NLEQ1 and NLEQ2, this is open.
5. **Publish** the release, after editing its notes if needed. Publishing creates the tag
   `v<version>` on the built commit; the release then cannot change.
6. **Update the Praenora runtime**: in a pull request of the runtime, raise its pin to the new
   version and the archives' SHA-256 values ([outputs.md](outputs.md#from-a-release)).

If a build job fails, the run creates no release. A draft that should not be published is deleted
with `gh release delete v<version> --repo INFLECT-Praenora/praenora-runtime-deps`; it has no tag,
so the workflow can then run again for the same version. A published release with a defect is
replaced by a new version.

## Changing a runner image

GitHub announces image changes in its changelog and in the repository actions/runner-images; it
retires old images after an announcement. When a job moves to another runner label (for example
`windows-2022` to `windows-2025`), or an image changes its compiler's major version, the compiler
label in that bundle's name changes. Then, in one pull request:

1. change the label in the workflow, if it changes;
2. raise the bundle's minor version ([outputs.md](outputs.md#versions));
3. update the table in [The workflow](#the-workflow) and the verification status in
   [building.md](building.md#presets).

After the release, the Praenora runtime moves its jobs to the same images when it raises its pin.
