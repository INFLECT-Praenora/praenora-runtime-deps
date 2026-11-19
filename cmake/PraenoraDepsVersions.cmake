# The upstream sources of the bundle and the versions they must produce.
#
# Each entry names a submodule under external/, the upstream repository, the tag its pinned commit
# carries, and the version that the installed files must report. The bundle step
# (cmake/PraenoraDepsBundle.cmake) reads the installed versions and stops the build when one
# differs from the value here, so a submodule update and this file change together
# (docs/building.md#updating-an-upstream-dependency).
#
# The bundle's own version is project(VERSION) in CMakeLists.txt (docs/outputs.md#versions).

include_guard(GLOBAL)

# Format version of the manifest praenora-runtime-deps.json. Raised when a field is removed or
# changes meaning; adding a field does not raise it.
set(PRAENORA_DEPS_MANIFEST_VERSION 1)

set(PRAENORA_DEPS_COMPONENTS llvm libroadrunner-deps roadrunner antimony nlohmann-json
    json-schema-validator)

set(PRAENORA_DEPS_llvm_REPOSITORY "https://github.com/sys-bio/llvm-13.x")
set(PRAENORA_DEPS_llvm_REF "v13.1")
set(PRAENORA_DEPS_llvm_VERSION "13.0.1")

# libroadrunner-deps states no version of its own in its installation (its CMake project version
# is not maintained); the tag identifies it.
set(PRAENORA_DEPS_libroadrunner-deps_REPOSITORY "https://github.com/sys-bio/libroadrunner-deps")
set(PRAENORA_DEPS_libroadrunner-deps_REF "v2.3.7")
set(PRAENORA_DEPS_libroadrunner-deps_VERSION "")

set(PRAENORA_DEPS_roadrunner_REPOSITORY "https://github.com/sys-bio/roadrunner")
set(PRAENORA_DEPS_roadrunner_REF "v2.11.0")
set(PRAENORA_DEPS_roadrunner_VERSION "2.11.0")

set(PRAENORA_DEPS_antimony_REPOSITORY "https://github.com/sys-bio/antimony")
set(PRAENORA_DEPS_antimony_REF "v3.3.0")
set(PRAENORA_DEPS_antimony_VERSION "3.3.0")

# json-schema-validator and the nlohmann/json it is compiled against. The Praenora runtime pins the
# same two commits for the dependencies it can fetch (cmake/PraenoraDependencies.cmake in its
# repository); keep them equal. nlohmann/json names its version in the symbols of every function
# that takes its types, so the runtime must compile against the nlohmann/json of the bundle.
set(PRAENORA_DEPS_nlohmann-json_REPOSITORY "https://github.com/nlohmann/json")
set(PRAENORA_DEPS_nlohmann-json_REF "v3.12.0")
set(PRAENORA_DEPS_nlohmann-json_VERSION "3.12.0")

set(PRAENORA_DEPS_json-schema-validator_REPOSITORY
    "https://github.com/pboettch/json-schema-validator")
set(PRAENORA_DEPS_json-schema-validator_REF "2.4.1")
set(PRAENORA_DEPS_json-schema-validator_VERSION "2.4.1")
