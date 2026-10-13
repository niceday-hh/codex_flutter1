#!/usr/bin/env bash
set -euo pipefail
# Passwords stay in CI environment variables; no key material is written to git.
INPUT="${1:?APK path is required}"
TOOLS_DIR="$(find "$ANDROID_HOME/build-tools" -type f -name apksigner | sort -V | tail -1)"
TOOLS_DIR="$(dirname "$TOOLS_DIR")"
ALIGNED="${INPUT%.apk}-aligned.apk"
SIGNED="${INPUT%.apk}-compat-signed.apk"
trap 'rm -f "$ALIGNED" "$SIGNED"' EXIT

# Preserve alignment before signing. Never alter ZIP bytes after signing.
"$TOOLS_DIR/zipalign" -P 16 -f 4 "$INPUT" "$ALIGNED"
"$TOOLS_DIR/apksigner" sign \
  --ks android/app/shiguang-release.jks \
  --ks-key-alias "$KEY_ALIAS" \
  --ks-pass env:KEYSTORE_PASSWORD --key-pass env:KEY_PASSWORD \
  --v1-signing-enabled true --v2-signing-enabled true \
  --v3-signing-enabled true --v4-signing-enabled false \
  --v1-signer-name CERT --out "$SIGNED" "$ALIGNED"
"$TOOLS_DIR/apksigner" verify --min-sdk-version 23 --verbose --print-certs "$SIGNED"
"$TOOLS_DIR/zipalign" -c -P 16 4 "$SIGNED"
mv "$SIGNED" "$INPUT"
