#!/usr/bin/env bash
# Runs the TodoTxtCore checks (used instead of `swift test`, which needs Xcode).
# Exits non-zero if any check fails.
set -euo pipefail
cd "$(dirname "$0")/.."
swift run TodoTxtCoreChecks "$@"
