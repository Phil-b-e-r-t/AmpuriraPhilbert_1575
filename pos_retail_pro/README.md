# POS Retail Pro

POS Retail Pro is a Flutter point-of-sale app with Firebase Authentication and
local-first data storage. Google and email/password sign-in use Firebase; the
Node server is not required for login, sales, inventory, or customers.

## Firebase setup

1. Create a Firebase project and register the Android, iOS, and web apps you
   plan to run. In **Authentication > Sign-in method**, enable **Google** and
   **Email/Password**.
   The Android package name must match `applicationId` in
   `android/app/build.gradle.kts` (`com.example.pos_retail_pro` by default).
2. For Android, add your app's SHA-1 and SHA-256 signing fingerprints in the
   Firebase Android app settings. For iOS, register the exact bundle ID used
   by the app. Add your web host (and `localhost` for local development) to
   Firebase Authentication's authorized domains.
3. Copy the app IDs and project values from Firebase project settings into a
   local `firebase.env.json` file in this directory:

   ```json
   {
     "FIREBASE_API_KEY": "your-web-api-key",
     "FIREBASE_MESSAGING_SENDER_ID": "your-sender-id",
     "FIREBASE_PROJECT_ID": "your-project-id",
     "FIREBASE_AUTH_DOMAIN": "your-project-id.firebaseapp.com",
     "FIREBASE_STORAGE_BUCKET": "your-project-id.firebasestorage.app",
     "FIREBASE_WEB_APP_ID": "1:123456789:web:abc123",
     "FIREBASE_ANDROID_APP_ID": "1:123456789:android:abc123",
     "FIREBASE_IOS_APP_ID": "1:123456789:ios:abc123",
     "FIREBASE_IOS_BUNDLE_ID": "com.example.pos_retail_pro"
   }
   ```

   These Firebase app identifiers are public configuration, not service
   account credentials. Do not put service account keys in the Flutter app.
   The local config file is ignored by Git.
4. Run with the local configuration:

   ```bash
   flutter pub get
   flutter run -d chrome --dart-define-from-file=firebase.env.json
   # Android: flutter run --dart-define-from-file=firebase.env.json
   ```

   Repeat the `--dart-define-from-file` option when building a release.

New users can select **Continue with Google** or create a Firebase
email/password account. Firebase remembers a signed-in user on the device, so
after a successful sign-in the app can reopen and work offline. A first-time
sign-in still needs internet access.

Signed-in accounts have owner access to inventory stored on that installation.
Firebase Auth identifies users but does not sync POS records or assign app
roles.

## Offline storage

Products, customers, stock updates, and sales are saved to SQLite on Android
and iOS, and to browser storage on web. They remain available offline on that
device. Data is not synced between devices or backed up to Firebase. Clearing
the app/browser data removes the local copy. Export or backup is not currently
provided.

## PayPal (optional)

Cash, card, mobile money, and bank transfer sales are recorded locally.
PayPal checkout still requires the separate Node service because it creates
and captures PayPal orders:

1. Create a PayPal app at <https://developer.paypal.com> and obtain its
   sandbox client ID and secret.
2. Configure `server/.env` from `server/.env.example`, then run `npm install`
   and `npm start` in `server/`.
3. Set the service URL under **More > Payment Settings**. This setting is only
   needed for PayPal; the app's sign-in and local POS features do not use it.

PayPal does not support UGX. The service converts UGX to USD using
`UGX_PER_USD`. Check that your business account can receive payments from
Uganda and withdraw funds before going live. Keep PayPal secrets on the server,
never in the Flutter app.

## Product images

Place optional images in `assets/images/`. The app uses fallback icons if an
image is missing.

| File | Use |
|---|---|
| `coke.png`, `sprite.png`, `water.png`, `bread.png`, `chips.png` | Product images |
| `pay_cash.png`, `pay_card.png`, `pay_momo.png`, `pay_bank.png` | Payment method icons |
| `pay_paypal.png` | PayPal logo |
| `logo.png` | Optional business logo |

## Run and build

```bash
flutter run --dart-define-from-file=firebase.env.json
flutter build web --dart-define-from-file=firebase.env.json
```

For Android emulator testing of PayPal only, the server can be reached at
`http://10.0.2.2:3000`. A real phone needs a reachable server URL; use HTTPS in
production. Mobile Money and Bank Transfer are manually confirmed.
