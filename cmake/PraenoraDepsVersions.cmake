# The upstream sources of the bundle, the versions they must produce and their license files.
#
# Each entry names a submodule under external/, the upstream repository, the tag its pinned commit
# carries (for a commit after a tag, the name that git describe --tags gives it), the version that
# the installed files must report, and the license files that go into the bundle. The bundle step
# (cmake/PraenoraDepsBundle.cmake) reads the installed versions and stops the build when one
# differs from the value here or when a license file is missing, so a submodule update and this
# file change together (docs/building.md#updating-an-upstream-dependency).
#
# PRAENORA_DEPS_<component>_LICENSES lists files relative to the submodule. The bundle step copies
# each to licenses/<component>/ in the bundle, under the same relative path
# (docs/outputs.md#licenses).
#
# The bundle's own version is project(VERSION) in CMakeLists.txt (docs/outputs.md#versions).

include_guard(GLOBAL)

# Format version of the manifest praenora-runtime-deps.json. Raised when a field is removed or
# changes meaning; adding a field does not raise it.
set(PRAENORA_DEPS_MANIFEST_VERSION 1)

set(PRAENORA_DEPS_COMPONENTS llvm libroadrunner-deps roadrunner antimony nlohmann-json
    json-schema-validator)

# LLVM: the head of the fork's branch release/13.x, six commits after the tag v13.1. Its sources
# differ from v13.1 only in the fork's fix for GCC 13 ("Updates to compile in ubuntu 24"):
# llvm/Support/Signals.h uses uintptr_t without including <cstdint>, which GCC 13's standard
# library no longer includes through <string>, so v13.1 does not compile with GCC 13.
set(PRAENORA_DEPS_llvm_REPOSITORY "https://github.com/sys-bio/llvm-13.x")
set(PRAENORA_DEPS_llvm_REF "v13.1-6-g4cb21e5280cb")
set(PRAENORA_DEPS_llvm_VERSION "13.0.1")
set(PRAENORA_DEPS_llvm_LICENSES "llvm/LICENSE.TXT")

# libroadrunner-deps states no version of its own in its installation (its CMake project version
# is not maintained); the tag identifies it.
set(PRAENORA_DEPS_libroadrunner-deps_REPOSITORY "https://github.com/sys-bio/libroadrunner-deps")
set(PRAENORA_DEPS_libroadrunner-deps_REF "v2.3.7")
set(PRAENORA_DEPS_libroadrunner-deps_VERSION "")
# The license files of the libraries of libroadrunner-deps that libRoadRunner's installation
# copies into the bundle. NLEQ1, NLEQ2 and rr-libstruct have none: NLEQ's terms are in its source
# files and in libRoadRunner's NOTICE.txt, and rr-libstruct states a BSD license in its source
# files (docs/outputs.md#licenses).
set(PRAENORA_DEPS_libroadrunner-deps_LICENSES
    third_party/bzip2/LICENSE
    third_party/clapack/COPYING
    third_party/expat/COPYING
    third_party/libsbml/COPYING.txt
    third_party/libsbml/LICENSE.txt
    third_party/libSEDML/LICENSE.txt
    third_party/NuML/libnuml/LICENSE.txt
    third_party/poco/LICENSE
    third_party/SBMLNetwork/LICENSE
    third_party/sundials/LICENSE
    third_party/sundials/NOTICE
    third_party/zlib/LICENSE)

set(PRAENORA_DEPS_roadrunner_REPOSITORY "https://github.com/sys-bio/roadrunner")
set(PRAENORA_DEPS_roadrunner_REF "v2.11.0")
set(PRAENORA_DEPS_roadrunner_VERSION "2.11.0")
set(PRAENORA_DEPS_roadrunner_LICENSES LICENSE.txt NOTICE.txt)

set(PRAENORA_DEPS_antimony_REPOSITORY "https://github.com/sys-bio/antimony")
set(PRAENORA_DEPS_antimony_REF "v3.3.0")
set(PRAENORA_DEPS_antimony_VERSION "3.3.0")
set(PRAENORA_DEPS_antimony_LICENSES LICENSE.txt)

# json-schema-validator and the nlohmann/json it is compiled against. The Praenora runtime pins the
# same two commits for the dependencies it can fetch (cmake/PraenoraDependencies.cmake in its
# repository); keep them equal. nlohmann/json names its version in the symbols of every function
# that takes its types, so the runtime must compile against the nlohmann/json of the bundle.
set(PRAENORA_DEPS_nlohmann-json_REPOSITORY "https://github.com/nlohmann/json")
set(PRAENORA_DEPS_nlohmann-json_REF "v3.12.0")
set(PRAENORA_DEPS_nlohmann-json_VERSION "3.12.0")
set(PRAENORA_DEPS_nlohmann-json_LICENSES LICENSE.MIT)

set(PRAENORA_DEPS_json-schema-validator_REPOSITORY
    "https://github.com/pboettch/json-schema-validator")
set(PRAENORA_DEPS_json-schema-validator_REF "2.4.1")
set(PRAENORA_DEPS_json-schema-validator_VERSION "2.4.1")
set(PRAENORA_DEPS_json-schema-validator_LICENSES LICENSE)
