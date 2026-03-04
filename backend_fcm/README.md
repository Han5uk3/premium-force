# Premium Force — FCM Backend Integration

Push notification backend code for the Premium Force Flutter app.
Built with Node.js + MongoDB (Mongoose) + FCM HTTP v1 API.

---

## Folder Structure

```
backend_fcm/
├── services/
│   └── fcm.js                  ← Core: sends notifications via FCM
├── models/
│   └── User.js                 ← Add fcmToken field to your User model
├── routes/
│   └── users.js                ← REST endpoints to register/clear FCM token
├── examples/
│   └── notificationExamples.js ← Ready-made helpers for booking events
├── package.json
└── README.md
```

---

## Setup (3 steps)

### 1. Install dependencies

```bash
npm install google-auth-library axios
```

### 2. Set the environment variable on AWS

Get the service account key:

1. [Firebase Console](https://console.firebase.google.com) → **Project: premium-force**
2. ⚙️ Project Settings → **Service Accounts** → **Generate new private key**
3. Download the JSON file — copy its **entire contents**

Set it as an environment variable on your AWS EC2 / Elastic Beanstalk:

```bash
export FIREBASE_CREDENTIALS='{"type":"service_account","project_id":"premium-force",...}'
```

Or add it to your `.env` file (use dotenv):

```
FIREBASE_CREDENTIALS={"type":"service_account","project_id":"premium-force",...}
```

### 3. Add `fcmToken` to your User model

```js
// In your existing User schema, add:
fcmToken: { type: String, default: null },
```

---

## Integrating into your existing Express app

### Mount the token registration route

```js
// In your main app.js / server.js
const userFcmRouter = require("./backend_fcm/routes/users");
app.use("/api/users", userFcmRouter); // POST /api/users/:id/fcm-token
```

### Send a notification from any controller

```js
const { notifyUser } = require("./backend_fcm/services/fcm");

// Inside your booking confirmation controller:
await notifyUser(
  booking.userId,
  "🚗 Booking Confirmed",
  "Your ride is confirmed for 3:00 PM.",
  { type: "booking_confirmed", bookingId: booking._id.toString() },
);
```

---

## Notification Payload

The `data` object keys and values must all be **strings**.
The `type` field is read by the Flutter app to decide what screen to navigate to.

| `type` value        | Flutter behaviour (when tapped) |
| ------------------- | ------------------------------- |
| `booking_confirmed` | Open booking details            |
| `booking_cancelled` | Open booking details            |
| `driver_assigned`   | Open tracking screen            |
| `driver_arriving`   | Open tracking screen            |
| `broadcast`         | Open home screen                |

## API Endpoints (Flutter app calls these automatically)

| Method | Endpoint                   | Description                |
| ------ | -------------------------- | -------------------------- |
| POST   | `/api/users/:id/fcm-token` | Save token on login/launch |
| DELETE | `/api/users/:id/fcm-token` | Clear token on logout      |

---

## Testing

Send a test notification to a raw FCM token (copy from the app's debug screen):

```js
const {
  testNotification,
} = require("./backend_fcm/examples/notificationExamples");
await testNotification("PASTE_FCM_TOKEN_HERE");
```

---

## Notes

- The `channel_id: 'premium_force_high_importance'` in `fcm.js` must not be changed — it matches the Android notification channel registered in the Flutter app.
- Stale tokens (app uninstalled / reinstalled) are automatically cleared from MongoDB.
- The OAuth2 access token is cached for 55 minutes to avoid excessive Google API calls.
