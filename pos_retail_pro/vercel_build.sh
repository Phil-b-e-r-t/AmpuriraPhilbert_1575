#!/usr/bin/env bash
# Builds the Flutter web app on Vercel.
# Vercel's build image has no Flutter SDK, so we download it here, then build.
set -euo pipefail

# ---- 1. Check the Firebase settings exist (set them in Vercel > Settings > Environment Variables)
missing=0
for v in FIREBASE_API_KEY FIREBASE_MESSAGING_SENDER_ID FIREBASE_PROJECT_ID FIREBASE_AUTH_DOMAIN FIREBASE_WEB_APP_ID; do
  if [ -z "${!v:-}" ]; then
    echo "ERROR: environment variable $v is not set in Vercel." >&2
    missing=1
  fi
done
if [ "$missing" -eq 1 ]; then
  echo "Add the missing variables in Vercel (Project > Settings > Environment Variables) and redeploy." >&2
  exit 1
fi

# ---- 2. Install Flutter (stable channel, shallow clone to keep it fast)
FLUTTER_DIR="$HOME/flutter"
git config --global --add safe.directory '*' || true
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"
export FLUTTER_SUPPRESS_ANALYTICS=true
export CI=true

flutter config --no-analytics >/dev/null 2>&1 || true
flutter config --enable-web
flutter --version

# ---- 3. Write the (public) Firebase config the app reads through --dart-define-from-file
cat > firebase.env.json <<EOF
{
  "FIREBASE_API_KEY": "${FIREBASE_API_KEY}",
  "FIREBASE_MESSAGING_SENDER_ID": "${FIREBASE_MESSAGING_SENDER_ID}",
  "FIREBASE_PROJECT_ID": "${FIREBASE_PROJECT_ID}",
  "FIREBASE_AUTH_DOMAIN": "${FIREBASE_AUTH_DOMAIN}",
  "FIREBASE_STORAGE_BUCKET": "${FIREBASE_STORAGE_BUCKET:-}",
  "FIREBASE_WEB_APP_ID": "${FIREBASE_WEB_APP_ID}",
  "API_BASE_URL": "${API_BASE_URL:-}"
}
EOF

# ---- 4. Build
# --no-web-resources-cdn bundles CanvasKit with the app so it can load offline.
flutter pub get
flutter build web --release --no-web-resources-cdn --dart-define-from-file=firebase.env.json

echo "Build finished: build/web"
