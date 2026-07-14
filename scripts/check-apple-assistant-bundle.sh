#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$("${ROOT_DIR}/scripts/package-apple-assistant.sh")"
INFO_PLIST="${APP_PATH}/Contents/Info.plist"

/usr/libexec/PlistBuddy -c 'Print :NSSpeechRecognitionUsageDescription' "${INFO_PLIST}" >/dev/null
/usr/libexec/PlistBuddy -c 'Print :NSMicrophoneUsageDescription' "${INFO_PLIST}" >/dev/null
/usr/libexec/PlistBuddy -c 'Print :NSCalendarsFullAccessUsageDescription' "${INFO_PLIST}" >/dev/null
/usr/libexec/PlistBuddy -c 'Print :NSRemindersFullAccessUsageDescription' "${INFO_PLIST}" >/dev/null
/usr/libexec/PlistBuddy -c 'Print :CFBundlePackageType' "${INFO_PLIST}" | grep -qx 'APPL'

test -x "${APP_PATH}/Contents/MacOS/AppleAssistant"

echo "apple assistant bundle ok"
