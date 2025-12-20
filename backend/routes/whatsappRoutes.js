const express = require('express');
const router = express.Router();
const twilio = require('twilio');
const Notification = require('../models/Notification');
const Admin = require('../models/Admin');
const LabOwner = require('../models/Owner');
const { sendWhatsAppMessage } = require('../utils/sendWhatsApp');

// Twilio webhook for incoming WhatsApp messages
router.post('/webhook', async (req, res) => {
  try {
    const { From, Body, To } = req.body;

    // Remove 'whatsapp:' prefix from phone numbers
    const senderPhone = From.replace('whatsapp:', '');
    const twilioNumber = To.replace('whatsapp:', '');

    console.log(`Incoming WhatsApp from ${senderPhone}: ${Body}`);

    // Find admin by phone number
    const admin = await Admin.findOne({ phone_number: senderPhone });
    if (!admin) {
      console.log('Message from unknown number, ignoring');
      return res.status(200).send('OK');
    }

    // Find the most recent owner contact notification that this admin hasn't replied to
    const recentOwnerMessage = await Notification.findOne({
      receiver_id: admin._id,
      receiver_model: 'Admin',
      type: 'system',
      is_read: false
    }).sort({ createdAt: -1 });

    if (!recentOwnerMessage) {
      console.log('No recent owner message to reply to');
      return res.status(200).send('OK');
    }

    // Get the owner who sent the original message
    const owner = await LabOwner.findById(recentOwnerMessage.sender_id);
    if (!owner) {
      console.log('Owner not found');
      return res.status(200).send('OK');
    }

    // Send WhatsApp reply to owner
    const replyMessage = `📬 Reply from Admin\n\n💬 ${Body}\n\n---\nRegards,\nMedical Lab System Admin`;

    await sendWhatsAppMessage(owner.phone_number, replyMessage);

    // Create reply notification in database
    await Notification.create({
      sender_id: admin._id,
      sender_model: 'Admin',
      receiver_id: owner._id,
      receiver_model: 'Owner',
      type: 'message',
      title: 'Admin Reply',
      message: Body,
      parent_id: recentOwnerMessage._id,
      conversation_id: recentOwnerMessage.conversation_id || recentOwnerMessage._id,
      is_reply: true
    });

    // Mark original notification as read
    recentOwnerMessage.is_read = true;
    await recentOwnerMessage.save();

    res.status(200).send('OK');

  } catch (error) {
    console.error('WhatsApp webhook error:', error);
    res.status(500).send('Error');
  }
});

module.exports = router;