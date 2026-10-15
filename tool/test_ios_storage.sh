#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
mkdir -p "$temporary/Sources/LedgerStorage" "$temporary/Tests/LedgerStorageTests"
cp tool/native_ios/LedgerStorage.swift "$temporary/Sources/LedgerStorage/"
sed 's/@testable import Runner/@testable import LedgerStorage/' tool/native_ios/RunnerTests.swift \
  > "$temporary/Tests/LedgerStorageTests/RunnerTests.swift"
cat > "$temporary/Package.swift" <<'SWIFT'
// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "LedgerStorage", targets: [
  .target(name: "LedgerStorage"),
  .testTarget(name: "LedgerStorageTests", dependencies: ["LedgerStorage"]),
])
SWIFT
# Exercise the exact production Foundation storage implementation and test cases.
# iOS channel/inference tests separately run in the iPhone simulator.
swift test --package-path "$temporary"
