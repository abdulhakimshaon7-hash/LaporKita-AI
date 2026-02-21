
require('dotenv').config();

const { GoogleGenerativeAI } = require('@google/generative-ai');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

async function listModels() {

  try {

    console.log('🔍 Checking available models...');

    console.log('API Key starts with:', process.env.GEMINI_API_KEY.substring(0, 20) + '...');

    

    // Try a simple request to see if API key works at all

    const model = genAI.getGenerativeModel({ model: 'gemini-pro' });

    const result = await model.generateContent('Say hello');

    console.log('✅ API key is valid!');

    console.log('Response:', result.response.text());

    

  } catch (error) {

    console.error('❌ Error:', error.message);

    console.error('Status:', error.status);

    

    if (error.status === 404) {

      console.log('\n💡 Your API key might need these settings:');

      console.log('1. Go to https://aistudio.google.com');

      console.log('2. Click "Get API key"');

      console.log('3. Delete existing key');

      console.log('4. Create NEW key');

      console.log('5. Make sure "Generative Language API" is enabled');

    }

  }

}

listModels();

