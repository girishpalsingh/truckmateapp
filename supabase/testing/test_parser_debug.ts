
import { mapRateConData } from "../functions/_shared/llm_response_proc/gemini_flash_rate_con_parser.ts";
import mockResponse from "../functions/mock_llm_response/response.json" with { type: "json" };

console.log("Testing Rate Con Parser...");

const result = mapRateConData("test-doc-id", mockResponse, "test-org-id");

console.log("Resulting Data Structure:");
console.log(JSON.stringify(result, null, 2));

console.log("\n--- Verification ---");
console.log("1. overall_traffic_light:", result.overall_traffic_light);
console.log("2. driver_view_data:", result.driver_view_data ? "PRESENT" : "MISSING");

if (result.overall_traffic_light !== 'RED') {
    console.error("FAIL: overall_traffic_light should be RED, got", result.overall_traffic_light);
} else {
    console.log("PASS: overall_traffic_light is correct.");
}

if (!result.driver_view_data) {
    console.error("FAIL: driver_view_data is missing.");
} else {
    console.log("PASS: driver_view_data is present.");
    console.log(JSON.stringify(result.driver_view_data, null, 2));
}
