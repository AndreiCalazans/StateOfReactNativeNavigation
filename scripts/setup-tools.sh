#!/usr/bin/env bash
# Install the repo-local toolchain (Maestro + Flashlight) into .tools/.
# Idempotent: skips anything already present. Nothing is installed globally.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="$REPO_ROOT/.tools"
mkdir -p "$TOOLS"

MAESTRO_VERSION="${MAESTRO_VERSION:-2.6.0}"

# --- Maestro ---------------------------------------------------------------
if [ -x "$TOOLS/maestro/bin/maestro" ]; then
  echo "[setup] maestro already present ($("$TOOLS/maestro/bin/maestro" --version 2>/dev/null | tail -1))"
else
  echo "[setup] downloading Maestro $MAESTRO_VERSION"
  url="https://github.com/mobile-dev-inc/Maestro/releases/download/cli-${MAESTRO_VERSION}/maestro.zip"
  tmp="$(mktemp -d)"
  curl -sL --fail -o "$tmp/maestro.zip" "$url"
  unzip -q -o "$tmp/maestro.zip" -d "$TOOLS"
  rm -rf "$tmp"
  echo "[setup] maestro installed -> $TOOLS/maestro/bin/maestro"
fi

# --- Flashlight ------------------------------------------------------------
case "$(uname -s)" in
  Linux)  FL_FILE="flashlight-linux" ;;
  Darwin) FL_FILE="flashlight-macos" ;;
  *) echo "[setup] unsupported OS for flashlight: $(uname -s)" >&2; FL_FILE="" ;;
esac

if [ -x "$TOOLS/flashlight/bin/flashlight" ]; then
  echo "[setup] flashlight already present"
elif [ -n "$FL_FILE" ]; then
  echo "[setup] downloading Flashlight ($FL_FILE)"
  mkdir -p "$TOOLS/flashlight/bin"
  tmp="$(mktemp -d)"
  curl -sL --fail -o "$tmp/$FL_FILE.zip" \
    "https://github.com/bamlab/flashlight/releases/latest/download/$FL_FILE.zip"
  unzip -q -o "$tmp/$FL_FILE.zip" -d "$tmp"
  mv "$tmp/$FL_FILE" "$TOOLS/flashlight/bin/flashlight"
  chmod +x "$TOOLS/flashlight/bin/flashlight"
  rm -rf "$tmp"
  echo "[setup] flashlight installed -> $TOOLS/flashlight/bin/flashlight"
fi

echo "[setup] done. Run: source scripts/env.sh"
