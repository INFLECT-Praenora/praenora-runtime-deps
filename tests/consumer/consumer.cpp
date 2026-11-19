// The program of the test bundle.consumer. Linked against the bundle's libRoadRunner,
// libAntimony and json-schema-validator, it
// 1. compares the versions the libraries report with the bundle's CMake package
//    (EXPECTED_* definitions),
// 2. converts an Antimony model of first-order decay to SBML with libAntimony, compiles it with
//    libRoadRunner (LLVM) and simulates it, and compares the result with the exact solution, and
// 3. validates a valid and an invalid document against a JSON Schema with json-schema-validator.
// It prints one line per check and exits with 1 if any check fails.
#include <antimony_api.h>
#include <llvm/Config/llvm-config.h>
#include <nlohmann/json-schema.hpp>
#include <nlohmann/json.hpp>
#include <rr/rrRoadRunner.h>
#include <rr/rrVersionInfo.h>
#include <sbml/common/libsbml-version.h>
#include <sbmlnetwork/libsbmlnetwork_common.h>

#include <cmath>
#include <cstdio>
#include <exception>
#include <string>

namespace {

int failures = 0;

void check(bool ok, const std::string& what) {
    std::printf("%s: %s\n", ok ? "ok" : "FAILED", what.c_str());
    if (!ok) {
        ++failures;
    }
}

void check_version(const char* library, const std::string& reported, const char* expected) {
    check(reported == expected,
          std::string(library) + " reports " + reported + ", the bundle states " + expected);
}

}  // namespace

int main() {
    char* antimony_version = getVersionStr();
    std::string antimony = antimony_version != nullptr ? antimony_version : "";
    if (!antimony.empty() && antimony[0] == 'v') {
        antimony.erase(0, 1);
    }
    check_version("libAntimony", antimony, EXPECTED_ANTIMONY);
    check_version("libRoadRunner", rr::getVersionStr(rr::VERSIONSTR_BASIC), EXPECTED_ROADRUNNER);
    check_version("LLVM (headers)", LLVM_VERSION_STRING, EXPECTED_LLVM);
    check_version("libSBML", libsbml::getLibSBMLDottedVersion(), EXPECTED_LIBSBML);
    check_version("SBMLNetwork", getLibraryVersion(), EXPECTED_SBMLNETWORK);
    check_version("nlohmann/json (headers)",
                  std::to_string(NLOHMANN_JSON_VERSION_MAJOR) + "." +
                      std::to_string(NLOHMANN_JSON_VERSION_MINOR) + "." +
                      std::to_string(NLOHMANN_JSON_VERSION_PATCH),
                  EXPECTED_NLOHMANN_JSON);

    const char* model =
        "model decay\n"
        "  J0: S1 -> ; k1*S1\n"
        "  S1 = 10\n"
        "  k1 = 0.5\n"
        "end\n";
    const long loaded = loadAntimonyString(model);
    check(loaded >= 0, "libAntimony loads the model");
    char* sbml = loaded >= 0 ? getSBMLString("decay") : nullptr;
    check(sbml != nullptr, "libAntimony translates the model to SBML");
    if (sbml != nullptr) {
        try {
            rr::RoadRunner runner(sbml);
            const ls::DoubleMatrix* result = runner.simulate(0.0, 2.0, 3);
            const double simulated = (*result)(2, 1);
            const double exact = 10.0 * std::exp(-0.5 * 2.0);
            char line[160];
            std::snprintf(line, sizeof line,
                          "libRoadRunner simulates S1(2) = %.8f, exact %.8f", simulated, exact);
            check(std::fabs(simulated - exact) <= 1e-5 * exact, line);
        } catch (const std::exception& error) {
            check(false, std::string("libRoadRunner simulates the model: ") + error.what());
        }
    }
    freeAll();

    using nlohmann::json;
    try {
        nlohmann::json_schema::json_validator validator;
        validator.set_root_schema(json::parse(
            R"({"type": "object", "properties": {"n": {"type": "integer"}}, "required": ["n"]})"));
        validator.validate(json::parse(R"({"n": 1})"));
        check(true, "json-schema-validator accepts a valid document");
        bool refused = false;
        try {
            validator.validate(json::parse(R"({"n": "one"})"));
        } catch (const std::exception&) {
            refused = true;
        }
        check(refused, "json-schema-validator refuses an invalid document");
    } catch (const std::exception& error) {
        check(false, std::string("json-schema-validator validates: ") + error.what());
    }
    return failures == 0 ? 0 : 1;
}
