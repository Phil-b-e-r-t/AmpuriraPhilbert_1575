# POS Retail Pro (Flutter + PayPal)

The API server must be running for login and sign-up. For local development, web and mobile use `http://192.168.206.31:3000` by default so both connect to the same server. This address is specific to this development Wi-Fi network and must be changed if the computer's IP changes. For a deployed server, build with `--dart-define=API_BASE_URL=https://your-server.example.com`.

## 1. Create the project and drop in the code
```bash
flutter create pos_retail_pro --org com.yourname --platforms android,ios
cd pos_retail_pro
# copy from this zip, replacing the generated files:
#   pubspec.yaml, lib/ (all files), assets/ , server/
flutter pub get
```
Needs Flutter 3.27 or newer.

## 2. Upload / add your images (put them in assets/images/)
Export from Figma (select layer > Export > PNG @2x). The app works without them (icons are used instead) but looks like your design with them.

| File name | Figma layer (node id) |
|---|---|
| coke.png | Product image / coke (18:97) |
| sprite.png | Product image / sprite (18:104) |
| water.png | Product image / water (18:112) |
| bread.png | Product image / bread (18:119) |
| chips.png | Product image / chips (18:123) |
| pay_cash.png | Payment Options > Cash icon (I22:352;2:205) |
| pay_card.png | Credit/Debit Card icon (I22:352;2:210) |
| pay_momo.png | Mobile Money icon (I22:352;2:214) |
| pay_bank.png | Bank Transfer icon (I22:352;2:218) |
| pay_paypal.png | PayPal logo (download from PayPal brand centre) |
| logo.png (optional) | your business logo |

## 3. PayPal setup
1. https://developer.paypal.com > Apps & Credentials > Sandbox > Create App. Copy Client ID + Secret.
2. `cd server && cp .env.example .env`, paste the keys, then `npm install && npm start`.
3. Android emulator reaches it at http://10.0.2.2:3000 (default in `lib/state.dart`). Real phone: use your PC IP or a deployed https URL, and set it in the app under More > Payment Settings.
4. Test with a sandbox *personal* buyer account (Dashboard > Sandbox > Accounts).

IMPORTANT: PayPal does not support UGX. The server converts UGX to USD using UGX_PER_USD (set it to a current rate). Check with PayPal that your business account can receive payments from Uganda and withdraw funds.

## 4. Platform config
Android `android/app/build.gradle(.kts)`: set `minSdk = 23`.
Android `AndroidManifest.xml` (inside <manifest>): `<uses-permission android:name="android.permission.INTERNET"/>`
For local http testing add to <application>: `android:usesCleartextTraffic="true"` (remove for production).
iOS `ios/Podfile`: `platform :ios, '13.0'`. For local http testing add NSAppTransportSecurity > NSAllowsLocalNetworking = true in Info.plist.

## 5. Run
```bash
flutter run
```
Login uses the owner account configured in `server/.env` (defaults: `owner@pos.com` / `ChangeMe123!`); change the default password before use. New users can register from Sign Up while the API server is running.

## Before going live
- Set `seedDemoData = false` in lib/db.dart.
- Replace demo login with real auth; add auth (token) to the server endpoints.
- Deploy server over HTTPS, keep keys only in server env vars, switch PAYPAL_ENV=live.
- Replace in-memory /sales with a real database.
- Mobile Money and Bank Transfer are manually confirmed. For automatic MTN/Airtel use their APIs or Flutterwave via the same server pattern.

## Running on Chrome / Edge (web)
```bash
flutter run -d chrome      # or: flutter run -d edge
```
- Data is stored in the browser (so clearing site data clears the app's data).
- PayPal opens in a NEW TAB. Approve there, come back, press "Payment received".
- Keep `cd server && npm start` running; the web app talks to http://localhost:3000.
- Build for hosting: `flutter build web`.

---
# Version 2: MySQL database + login

```
Flutter app  ──HTTP/JSON + login token──▶  Node server (server/)  ──▶  MySQL (XAMPP)
 (offline copy on the device)                 + PayPal
```

## Setup
1. **XAMPP Control Panel:** click Start next to **MySQL** (Apache is not needed).
2. **Server:**
   ```bash
   cd server
   npm install
   copy .env.example .env        # (Mac/Linux: cp)
   ```
   Edit `.env`: set `JWT_SECRET` to a long random text, add your PayPal keys. If MySQL has a password, set `DB_PASSWORD`.
   ```bash
   npm start
   ```
   On first start it creates the `pos_retail_pro` database, all tables, an owner account (`owner@pos.com` / `ChangeMe123!` from .env) and demo products/customers. Look at the tables in phpMyAdmin (http://localhost/phpmyadmin).
3. **App:** `flutter pub get` then `flutter run -d chrome` (or an Android device). Web and mobile default to `http://192.168.206.31:3000`.
4. **Real phone:** keep the phone and PC on the same Wi-Fi and allow Node through Windows Firewall. If the PC's IP changes, update the server address using the gear icon on the login screen.

## How offline + sync works
- Every sale is saved on the device first, then uploaded. The server ignores a sale it already has, so retries are safe.
- When all sales are uploaded the app downloads the latest products, customers and sales (every 60 s and when the connection returns), so all devices agree.
- Adding products/customers and editing stock needs a connection (and an owner account for inventory).

## Roles
`owner` can edit inventory; `cashier` can sell and add customers. New accounts created from the app's **Sign Up** screen are assigned the `cashier` role and signed in automatically. The seeded owner account can create more users (owner token needed): `POST /users {name,email,password,role}`.
