#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null || { echo 'Flutter SDK is required.' >&2; exit 1; }
[[ "$(uname -s)" == Darwin ]] || { echo 'iOS builds require macOS and Xcode.' >&2; exit 1; }

# Generate the platform scaffold once. Re-running preserves signing settings.
if [[ ! -f ios/Runner.xcodeproj/project.pbxproj ]]; then
  temporary="$(mktemp -d)"
  trap 'rm -rf "$temporary"' EXIT
  flutter create --platforms=ios --org com.shiguang --project-name smart_budget \
    --no-pub "$temporary/smart_budget"
  mkdir -p ios
  cp -a "$temporary/smart_budget/ios/." ios/
fi

cp tool/native_ios/AppDelegate.swift ios/Runner/AppDelegate.swift
cat tool/native_ios/LedgerStorage.swift tool/native_ios/SmartBudgetHost.swift >> ios/Runner/AppDelegate.swift
cp tool/native_ios/RunnerTests.swift ios/RunnerTests/RunnerTests.swift
python3 tool/configure_ios.py
swift tool/native_ios/GenerateIcons.swift ios/branding-paths.json ios/Runner/Assets.xcassets/AppIcon.appiconset
rm ios/branding-paths.json
echo 'iOS host prepared (iPhone, iOS 15+). Run model preparation before building.'
