#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

APP_NAME="AppSorter"
DIST_DIR="${ROOT}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"

echo "==> Building release…"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
EXEC_SRC="${BIN_DIR}/${APP_NAME}"

if [[ ! -f "${EXEC_SRC}" ]]; then
	echo "error: missing binary at ${EXEC_SRC}" >&2
	exit 1
fi

echo "==> Assembling ${APP_NAME}.app…"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
cp "${EXEC_SRC}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "${ROOT}/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
printf 'APPL????' > "${APP_BUNDLE}/Contents/PkgInfo"

echo "==> Done: ${APP_BUNDLE}"
echo "    双击运行，或执行: open \"${APP_BUNDLE}\""
