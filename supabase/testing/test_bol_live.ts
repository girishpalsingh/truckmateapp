import { processWithGemini } from "../functions/_shared/document-processor.ts";
import { config } from "../functions/_shared/config.ts";

async function testBolProcessing() {
    console.log("Testing BOL Processing with Live Gemini...");

    if (config.development.mock_llm) {
        console.warn("WARNING: Mock LLM is still enabled in config code. This test is intended for LIVE LLM.");
    }

    // You need to provide a real image URL here for testing.
    // Since I don't have one, I will define a placeholder. 
    // The user needs to update this or I will use a dummy one that might fail or work if valid.
    // "https://www.example.com/sample_bol.jpg" likely won't work with Gemini unless it's a real image.
    // I will try to use a publicly available sample if possible, or ask user to provide one.
    // For now, I'll use a placeholder variable.

    // Replace this with a valid URL to a BOL image
    // Using placeholder to verify pipeline connectivity. Real extraction requires a real BOL image.
    const TEST_IMAGE_URL = "https://placehold.co/600x800.png";

    console.log(`Processing image: ${TEST_IMAGE_URL}`);
    console.log(`Model: ${config.llm.gemini.model}`);

    try {
        const result = await processWithGemini(
            TEST_IMAGE_URL,
            "bol",
            config.llm.gemini.model
        );

        console.log("------------------------------------------");
        console.log("Extraction Success!");
        console.log("Confidence:", result.confidence);
        console.log("------------------------------------------");
        console.log("Extracted Data Preview:");
        console.log(JSON.stringify(result.extractedData, null, 2));
        console.log("------------------------------------------");
        console.log("Raw Text Len:", result.rawText.length);

    } catch (error) {
        console.error("Test Failed:", error);
    }
}

testBolProcessing();
