#!/usr/bin/env bash
# Builds index.standalone.html: a single self-contained file with the Tailwind
# CDN replaced by a locally-compiled CSS bundle (only the classes used) and the
# OpenCloud fonts embedded as base64 data URIs.
#
# Works on macOS and Linux. Requires: curl, python3, base64.
# Caches the Tailwind CLI binary in ./.build/ — safe to add that dir to .gitignore.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_HTML="${SCRIPT_DIR}/index.html"
FONTS_DIR="${SCRIPT_DIR}/fonts"
OUTPUT_HTML="${SCRIPT_DIR}/index.standalone.html"
BUILD_DIR="${SCRIPT_DIR}/.build"
TW_VERSION="v3.4.17"

# --- Detect platform ----------------------------------------------------------
case "$(uname -s)" in
  Linux)  OS="linux" ;;
  Darwin) OS="macos" ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64|amd64)   ARCH="x64"   ;;
  arm64|aarch64)  ARCH="arm64" ;;
  *) echo "Unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac
PLATFORM="${OS}-${ARCH}"

# --- Required tools -----------------------------------------------------------
for cmd in curl python3 base64; do
  command -v "$cmd" >/dev/null 2>&1 \
    || { echo "Missing required command: $cmd" >&2; exit 1; }
done

mkdir -p "${BUILD_DIR}"

# --- Download Tailwind CLI standalone (cached) --------------------------------
TW_BIN="${BUILD_DIR}/tailwindcss-${PLATFORM}"
if [[ ! -x "${TW_BIN}" ]]; then
  echo "Downloading Tailwind CLI ${TW_VERSION} for ${PLATFORM}..."
  curl -fsSL -o "${TW_BIN}" \
    "https://github.com/tailwindlabs/tailwindcss/releases/download/${TW_VERSION}/tailwindcss-${PLATFORM}"
  chmod +x "${TW_BIN}"
fi

# --- Generate Tailwind config + input (mirrors the inline CDN config) --------
TW_INPUT="${BUILD_DIR}/input.css"
TW_CONFIG="${BUILD_DIR}/tailwind.config.js"
TW_OUTPUT="${BUILD_DIR}/tailwind.css"

cat > "${TW_INPUT}" <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF

cat > "${TW_CONFIG}" <<'EOF'
module.exports = {
  content: ["./index.html"],
  theme: {
    extend: {
      fontFamily: {
        sans: ["'OpenCloud'", "system-ui", "sans-serif"],
      },
      colors: {
        lilac: "#e2baff",
        "lilac-dark": "#ca8df5",
        petrol: "#20434f",
        "petrol-dark": "#19353f",
        paper: "#f1f3f4",
      },
    },
  },
};
EOF

# --- Build Tailwind CSS (scans index.html for classes used) ------------------
echo "Building Tailwind CSS..."
( cd "${SCRIPT_DIR}" \
  && "${TW_BIN}" -c "${TW_CONFIG}" -i "${TW_INPUT}" -o "${TW_OUTPUT}" --minify )

# --- Base64-encode fonts ------------------------------------------------------
echo "Encoding fonts..."
if [[ "$OS" == "macos" ]]; then
  base64 -i "${FONTS_DIR}/OpenCloud-Regular.otf" -o "${BUILD_DIR}/regular.b64"
  base64 -i "${FONTS_DIR}/OpenCloud-Bold.otf"    -o "${BUILD_DIR}/bold.b64"
else
  base64 -w0 "${FONTS_DIR}/OpenCloud-Regular.otf" > "${BUILD_DIR}/regular.b64"
  base64 -w0 "${FONTS_DIR}/OpenCloud-Bold.otf"    > "${BUILD_DIR}/bold.b64"
fi

# --- Assemble self-contained HTML via Python ---------------------------------
echo "Assembling ${OUTPUT_HTML}..."
SOURCE_HTML="${SOURCE_HTML}" \
TW_OUTPUT="${TW_OUTPUT}" \
REGULAR_B64_FILE="${BUILD_DIR}/regular.b64" \
BOLD_B64_FILE="${BUILD_DIR}/bold.b64" \
OUTPUT_HTML="${OUTPUT_HTML}" \
python3 - <<'PYEOF'
import os, re
from pathlib import Path

src = Path(os.environ["SOURCE_HTML"]).read_text(encoding="utf-8")
tw_css = Path(os.environ["TW_OUTPUT"]).read_text(encoding="utf-8")

# macOS base64 wraps lines by default; flatten any whitespace just in case.
regular_b64 = "".join(Path(os.environ["REGULAR_B64_FILE"]).read_text().split())
bold_b64    = "".join(Path(os.environ["BOLD_B64_FILE"]).read_text().split())

# Drop the Tailwind CDN <script> tag.
src = re.sub(
    r'\s*<script src="https://cdn\.tailwindcss\.com"></script>',
    "",
    src,
)

# Drop the inline `tailwind.config = {...}` <script> block.
src = re.sub(
    r'\s*<script>\s*tailwind\.config\s*=.*?</script>',
    "",
    src,
    flags=re.DOTALL,
)

# Swap the @font-face URLs for inline data URIs.
src = src.replace(
    "url('fonts/OpenCloud-Regular.otf') format('opentype')",
    f"url('data:font/otf;base64,{regular_b64}') format('opentype')",
)
src = src.replace(
    "url('fonts/OpenCloud-Bold.otf') format('opentype')",
    f"url('data:font/otf;base64,{bold_b64}') format('opentype')",
)

# Inline the compiled Tailwind CSS at the top of the existing <style> block.
src = src.replace("<style>", f"<style>\n{tw_css}\n", 1)

Path(os.environ["OUTPUT_HTML"]).write_text(src, encoding="utf-8")
print(f"Wrote {os.environ['OUTPUT_HTML']} ({len(src):,} bytes)")
PYEOF

echo "Done."
