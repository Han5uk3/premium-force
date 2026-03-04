const mongoose = require('mongoose');

/**
 * User schema — add fcmToken to your existing User model.
 *
 * If you already have a User model, just add the `fcmToken` field to it.
 * This file is provided as a reference / drop-in if you need a full model.
 */
const userSchema = new mongoose.Schema(
  {
    username: { type: String, required: true, trim: true },
    email: { type: String, required: true, trim: true, lowercase: true },
    phoneNumber: { type: String, required: true },
    countryCode: { type: String, default: '+966' },
    role: { type: String, enum: ['customer', 'driver', 'admin'], default: 'customer' },
    isActive: { type: Boolean, default: true },
    location: { type: String },
    lat: { type: Number },
    long: { type: Number },
    specialId: { type: String },
    profileImageUrl: { type: String },

    // ── FCM push notification token ──────────────────────────────────────
    // Stored by the Flutter app on every launch.
    // Set to null when the user logs out or the token becomes stale.
    fcmToken: { type: String, default: null },
  },
  { timestamps: true }
);

module.exports = mongoose.model('User', userSchema);
