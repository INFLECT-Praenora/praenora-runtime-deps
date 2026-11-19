# Checks of the bundle in CMAKE_INSTALL_PREFIX, run with ctest after the build
# (docs/building.md#checking-a-bundle).
#
# - bundle.manifest (check_manifest.cmake): the manifest and the CMake package agree with this
#   build's labels and versions, and the files that the Praenora runtime's finders look for exist.
# - bundle.consumer (run_consumer.cmake): a project outside this build finds the bundle through
#   find_package(PraenoraRuntimeDeps), finds json-schema-validator, nlohmann/json, libRoadRunner
#   and libAntimony as the runtime does, and runs a program that compares the versions the
#   libraries report with the bundle's, converts an Antimony model to SBML, simulates it with
#   libRoadRunner and validates JSON documents against a schema.

add_test(NAME bundle.manifest
    COMMAND "${CMAKE_COMMAND}"
        "-DBUNDLE=${CMAKE_INSTALL_PREFIX}"
        "-DBUILD_DIR=${PROJECT_BINARY_DIR}"
        "-DVERSION=${PROJECT_VERSION}"
        "-DPACKAGE_NAME=${PRAENORA_DEPS_PACKAGE_NAME}"
        "-DOS=${PRAENORA_DEPS_OS}"
        "-DARCH=${PRAENORA_DEPS_ARCH}"
        "-DCOMPILER_LABEL=${PRAENORA_DEPS_COMPILER_LABEL}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/check_manifest.cmake")

add_test(NAME bundle.consumer
    COMMAND "${CMAKE_COMMAND}"
        "-DBUNDLE=${CMAKE_INSTALL_PREFIX}"
        "-DVERSION=${PROJECT_VERSION}"
        "-DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}/consumer"
        "-DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/consumer"
        "-DGENERATOR=${CMAKE_GENERATOR}"
        "-DBUILD_TYPE=${CMAKE_BUILD_TYPE}"
        "-DC_COMPILER=${CMAKE_C_COMPILER}"
        "-DCXX_COMPILER=${CMAKE_CXX_COMPILER}"
        "-DOSX_ARCHITECTURES=${CMAKE_OSX_ARCHITECTURES}"
        "-DOSX_DEPLOYMENT_TARGET=${CMAKE_OSX_DEPLOYMENT_TARGET}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/run_consumer.cmake")

set_tests_properties(bundle.manifest bundle.consumer PROPERTIES LABELS bundle)
