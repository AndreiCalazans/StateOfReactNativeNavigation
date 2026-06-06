#!/usr/bin/env bash
# Source this to put the repo-local toolchain on PATH:
#   source scripts/env.sh
#
# Adds .tools/maestro + .tools/flashlight to PATH, resolves JAVA_HOME and
# ANDROID_HOME. Everything stays inside the repo (nothing global required).

_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"

# Maestro (downloaded into .tools/maestro by scripts/setup-tools.sh)
if [ -d "$_repo_root/.tools/maestro/bin" ]; then
  export PATH="$_repo_root/.tools/maestro/bin:$PATH"
fi

# Flashlight (prebuilt binary in .tools/flashlight/bin)
if [ -d "$_repo_root/.tools/flashlight/bin" ]; then
  export PATH="$_repo_root/.tools/flashlight/bin:$PATH"
fi

# Java 17 (Maestro + Gradle). Prefer an existing JAVA_HOME, else mise's 17.
if [ -z "${JAVA_HOME:-}" ] || ! "$JAVA_HOME/bin/java" -version >/dev/null 2>&1; then
  for _c in \
    "$HOME/.local/share/mise/installs/java/17.0.2" \
    "$(/usr/libexec/java_home -v 17 2>/dev/null || true)"; do
    if [ -n "$_c" ] && [ -x "$_c/bin/java" ]; then
      export JAVA_HOME="$_c"
      break
    fi
  done
fi

# Android SDK
if [ -z "${ANDROID_HOME:-}" ] && [ -d "$HOME/Library/Android/sdk" ]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
fi
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
if [ -n "${ANDROID_HOME:-}" ]; then
  export PATH="$ANDROID_HOME/platform-tools:$PATH"
fi

echo "[env] PATH includes repo .tools; JAVA_HOME=${JAVA_HOME:-unset}; ANDROID_HOME=${ANDROID_HOME:-unset}"
echo "[env] maestro: $(command -v maestro || echo 'not found')"
echo "[env] flashlight: $(command -v flashlight || echo 'not found')"
