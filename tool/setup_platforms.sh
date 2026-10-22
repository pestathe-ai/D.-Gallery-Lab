#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter create --project-name d_gallery_lab --org dev.dgallerylab --platforms=android .
rm -f test/widget_test.dart
M=android/app/src/main/AndroidManifest.xml
PERMS='    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />\
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />\
    <uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" />\
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />\
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />\
    <uses-permission android:name="android.permission.MANAGE_MEDIA" />'
sed -i "s#<application#${PERMS}\n    <application#" "$M"
sed -i 's#android:label="[^"]*"#android:label="D. Gallery Lab"#' "$M"
grep -n "permission\|label" "$M"
flutter pub get
