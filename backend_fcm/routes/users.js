const express = require('express');
const router = express.Router();
const User = require('../models/User');

/**
 * POST /api/users/:id/fcm-token
 *
 * Registers or updates the FCM device token for a user.
 * Called automatically by the Flutter app after login / on every launch.
 *
 * Body: { "fcmToken": "..." }
 */
router.post('/:id/fcm-token', async (req, res) => {
  try {
    const { fcmToken } = req.body;

    if (!fcmToken || typeof fcmToken !== 'string') {
      return res.status(400).json({
        success: false,
        message: 'fcmToken is required and must be a string.',
      });
    }

    const user = await User.findByIdAndUpdate(
      req.params.id,
      { fcmToken },
      { new: true, select: '_id username' }
    );

    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    console.log(`🔔 FCM token saved for user ${user.username} (${user._id})`);
    res.json({ success: true, message: 'FCM token registered.' });
  } catch (err) {
    console.error('FCM token route error:', err);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

/**
 * DELETE /api/users/:id/fcm-token
 *
 * Clears the FCM token when the user logs out.
 * Called automatically by the Flutter app on logout.
 */
router.delete('/:id/fcm-token', async (req, res) => {
  try {
    await User.findByIdAndUpdate(req.params.id, { fcmToken: null });
    res.json({ success: true, message: 'FCM token cleared.' });
  } catch (err) {
    console.error('FCM token delete error:', err);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

module.exports = router;
