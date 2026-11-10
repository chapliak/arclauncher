#!/usr/bin/env bash
# Build the fork's TV APK (32-bit ARM: the Google TV Streamer runs armeabi-v7a) in Docker.
# Output: dist/arc-fork-armeabi-v7a.apk. Signing key: ~/.arc-fork-key (created on first run; BACK IT UP, never commit).
set -euo pipefail
cd "$(dirname "$0")/.."
KEY="$HOME/.arc-fork-key"; mkdir -p "$KEY" dist
[ -f "$KEY/pw" ] || { umask 077; head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24 > "$KEY/pw"; }
docker run --rm -v "$PWD":/src -v "$KEY":/key -v arc-pub:/root/.pub-cache -v arc-gradle:/root/.gradle -w /src \
  ghcr.io/cirruslabs/flutter:3.41.9 bash -c '
    set -e
    PW=$(cat /key/pw)
    [ -f /key/arc-fork.jks ] || keytool -genkeypair -keystore /key/arc-fork.jks -alias arcfork -keyalg RSA -keysize 2048 -validity 10000 \
        -storepass "$PW" -keypass "$PW" -dname "CN=Arc fork, O=chapliak" 
    git config --global --add safe.directory /src || true
    flutter pub get
    export ARC_STORE_FILE=/key/arc-fork.jks ARC_STORE_PW="$PW"
    flutter build apk --release --flavor github --target-platform android-arm ${EXTRA_ARGS:-}
    chown -R '"$(id -u):$(id -g)"' /src/build /src/.dart_tool /src/android/.gradle /src/android/local.properties /src/pubspec.lock 2>/dev/null || true
  '
APK=$(find build/app/outputs -name '*armeabi-v7a-release.apk' -o -name 'app-github-release.apk' | head -1)
cp "$APK" dist/arc-fork-armeabi-v7a.apk && ls -lh dist/arc-fork-armeabi-v7a.apk
