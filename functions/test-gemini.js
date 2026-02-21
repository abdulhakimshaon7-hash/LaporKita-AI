// File: functions/src/test-gemini.js
// Run this file with: node src/test-gemini.js
// DELETE this file before final submission (it's just for testing)

// Load environment variables from .env file
require("dotenv").config();

// Import the Google AI library
const { GoogleGenerativeAI } = require("@google/generative-ai");

// Initialize with your API key from .env
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// Main test function
async function testGemini() {
  console.log("🧪 Testing Gemini API connection...");
  console.log("API Key starts with:", process.env.GEMINI_API_KEY.substring(0, 10) + "...");
  
  try {
    // Get the Gemini Pro model
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
    
    // Send a simple test message
    const result = await model.generateContent("Say 'Gemini is working!' in one sentence.");
    const response = await result.response;
    const text = response.text();
    
    console.log("✅ Gemini response:", text);
    console.log("🎉 API connection successful!");
    
  } catch (error) {
    console.error("❌ Gemini API error:", error.message);
    if (error.message.includes("API_KEY_INVALID")) {
      console.error("Your API key is wrong — check your .env file");
    }
  }
}

// Install dotenv first: npm install dotenv
testGemini();

