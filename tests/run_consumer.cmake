# bundle.consumer: cmake -DBUNDLE=<dir> -DVERSION=<v> -DSOURCE_DIR=<consumer> -DWORK_DIR=<dir>
#                        -DGENERATOR=<g> -DBUILD_TYPE=<t> -DC_COMPILER=<cc> -DCXX_COMPILER=<cxx>
#                        [-DOSX_ARCHITECTURES=<a>] [-DOSX_DEPLOYMENT_TARGET=<t>]
#                        -P run_consumer.cmake
#
# Configures and builds the consumer project (tests/consumer) in a fresh directory, with the
# bundle as its only CMAKE_PREFIX_PATH entry, then runs its program. Each step's command and output
# are printed.

cmake_minimum_required(VERSION 3.24)

file(REMOVE_RECURSE "${WORK_DIR}")
file(MAKE_DIRECTORY "${WORK_DIR}")

string(REGEX MATCH "^[0-9]+\\.[0-9]+" requested_version "${VERSION}")
set(configure "${CMAKE_COMMAND}" -S "${SOURCE_DIR}" -B "${WORK_DIR}" -G "${GENERATOR}"
    "-DCMAKE_BUILD_TYPE=${BUILD_TYPE}"
    "-DCMAKE_C_COMPILER=${C_COMPILER}"
    "-DCMAKE_CXX_COMPILER=${CXX_COMPILER}"
    "-DCMAKE_PREFIX_PATH=${BUNDLE}"
    "-DPRAENORA_DEPS_REQUESTED_VERSION=${requested_version}")
if(OSX_ARCHITECTURES)
    list(APPEND configure "-DCMAKE_OSX_ARCHITECTURES=${OSX_ARCHITECTURES}")
endif()
if(OSX_DEPLOYMENT_TARGET)
    list(APPEND configure "-DCMAKE_OSX_DEPLOYMENT_TARGET=${OSX_DEPLOYMENT_TARGET}")
endif()

if(CMAKE_HOST_WIN32)
    set(program "${WORK_DIR}/praenora_deps_consumer.exe")
else()
    set(program "${WORK_DIR}/praenora_deps_consumer")
endif()

foreach(step IN ITEMS configure build run)
    if(step STREQUAL "build")
        set(command "${CMAKE_COMMAND}" --build "${WORK_DIR}")
    elseif(step STREQUAL "run")
        set(command "${program}")
    else()
        set(command ${configure})
    endif()
    list(JOIN command " " shown)
    message(STATUS "${step}: ${shown}")
    execute_process(COMMAND ${command}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE output)
    message("${output}")
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "FAILED: ${step} (${result})")
    endif()
endforeach()
