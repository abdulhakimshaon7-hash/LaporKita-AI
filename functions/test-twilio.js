
require('dotenv').config();

const twilio = require('twilio');

const client = twilio(

  process.env.TWILIO_ACCOUNT_SID,

  process.env.TWILIO_AUTH_TOKEN

);

// Replace with YOUR Malaysian number (the one that joined sandbox)

const YOUR_PHONE = 'whatsapp:+601151692338';

console.log('📱 Sending test WhatsApp message...');

client.messages.create({

  from: process.env.TWILIO_WHATSAPP_NUMBER,

  to: YOUR_PHONE,

  body: '✅ LaporKita AI is connected! Your complaint system is ready to receive WhatsApp messages.'

})

.then(msg => {

  console.log('✅ Message sent successfully!');

  console.log('Message SID:', msg.sid);

  console.log('Check your WhatsApp - you should have received a message!');

})

.catch(err => {

  console.error('❌ Error sending message:', err.message);

  console.error('\nTroubleshooting:');

  console.error('1. Did you join the sandbox? Send "join <your-code>" to +1 415 523 8886');

  console.error('2. Is YOUR_PHONE correct? Format: whatsapp:+60123456789');

  console.error('3. Check your .env file has correct TWILIO credentials');

});

