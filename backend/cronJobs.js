// cronJobs.js
const cron = require('node-cron');
const LabOwner = require('./models/Owner'); 
const Notification = require('./models/Notification');

// 🕒 Daily subscription check & suspension job
cron.schedule('0 8 * * *', async () => { // runs every day at 08:00
  try {
    const today = new Date();
    const owners = await LabOwner.find();

    for (const owner of owners) {
      if (!owner.subscription_end) continue;

      const diffDays = Math.ceil((owner.subscription_end - today) / (1000 * 60 * 60 * 24));

      // 🔹 Check if "Expiring Soon" notification already exists
      if (diffDays > 0 && diffDays <= 7) {
        const alreadyNotified = await Notification.findOne({
          receiver_id: owner._id,
          receiver_model: 'LabOwner',
          type: 'subscription',
          title: 'Subscription Expiring Soon',
          'message': { $regex: owner.subscription_end.toDateString() }
        });

        if (!alreadyNotified) {
          await Notification.create({
            receiver_id: owner._id,
            receiver_model: 'LabOwner',
            type: 'subscription',
            title: 'Subscription Expiring Soon',
            message: `Your subscription will expire in ${diffDays} day(s) on ${owner.subscription_end.toDateString()}. Please renew in time.`
          });
        }
      }

      // 🔹 Suspend expired subscriptions if not already inactive
      if (diffDays <= 0 && owner.is_active) {
        owner.is_active = false;
        await owner.save();

        // Check if "Account Suspended" notification already exists
        const suspendedNotified = await Notification.findOne({
          receiver_id: owner._id,
          receiver_model: 'LabOwner',
          type: 'subscription',
          title: 'Account Suspended',
          'message': { $regex: owner.subscription_end.toDateString() }
        });

        if (!suspendedNotified) {
          await Notification.create({
            receiver_id: owner._id,
            receiver_model: 'LabOwner',
            type: 'subscription',
            title: 'Account Suspended',
            message: `Your lab account has been suspended because your subscription expired on ${owner.subscription_end.toDateString()}. Please renew to reactivate.`
          });
        }
      }
    }

    console.log('✅ Daily subscription check & notifications completed without duplicates.');
  } catch (err) {
    console.error('❌ Error in subscription cron job:', err);
  }
});
module.exports = cron;