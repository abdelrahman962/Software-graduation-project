require('dotenv').config();
const { sendWhatsAppTemplate } = require('./utils/sendWhatsApp');

async function testTemplate() {
  try {
    const success = await sendWhatsAppTemplate('+972594317447', 'HXb5b62575e6e4ff6129ad7c8efe1f983e', {"1": "12/1", "2": "3pm"});
    console.log('Template sent:', success);
  } catch (error) {
    console.error('Error:', error);
  }
}

testTemplate();