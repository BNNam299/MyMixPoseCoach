#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$ROOT_DIR/myposecoach1"
WORKSPACE="$APP_DIR/myposecoach1.xcworkspace"
COCOAPODS_VERSION="1.16.2"
LOCAL_GEM_BIN="$ROOT_DIR/.build/ruby-bin"

if [[ -d "$LOCAL_GEM_BIN" ]]; then
  export PATH="$LOCAL_GEM_BIN:$PATH"
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Lỗi: iOS chỉ có thể bootstrap/build trên macOS." >&2
  exit 2
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Lỗi: chưa có Xcode Command Line Tools. Chạy: xcode-select --install" >&2
  exit 2
fi

if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  && [[ -f "$ROOT_DIR/.gitmodules" ]]; then
  echo "Đang khôi phục source Android tham chiếu ở submodule posecoach..."
  git -C "$ROOT_DIR" submodule sync --recursive
  git -C "$ROOT_DIR" submodule update --init --recursive
fi

"$ROOT_DIR/tools/verify_ios_assets.sh"

current_pod_version=""
if command -v pod >/dev/null 2>&1; then
  current_pod_version="$(pod --version 2>/dev/null || true)"
fi

if [[ "$current_pod_version" != "$COCOAPODS_VERSION" ]]; then
  if ! command -v ruby >/dev/null 2>&1 || ! command -v gem >/dev/null 2>&1; then
    echo "Lỗi: cần Ruby/RubyGems để cài CocoaPods $COCOAPODS_VERSION." >&2
    exit 2
  fi

  echo "Đang cài CocoaPods $COCOAPODS_VERSION cho user hiện tại..."
  mkdir -p "$LOCAL_GEM_BIN"
  gem install --user-install cocoapods \
    --version "$COCOAPODS_VERSION" \
    --bindir "$LOCAL_GEM_BIN" \
    --no-document
  export PATH="$LOCAL_GEM_BIN:$PATH"
  rehash
fi

if ! command -v pod >/dev/null 2>&1 || [[ "$(pod --version)" != "$COCOAPODS_VERSION" ]]; then
  echo "Lỗi: không gọi được CocoaPods $COCOAPODS_VERSION sau khi cài." >&2
  exit 2
fi

echo "Đang khôi phục CocoaPods từ Podfile.lock..."
(
  cd "$APP_DIR"
  pod _${COCOAPODS_VERSION}_ install --deployment
)

echo "Đang khôi phục Swift Package từ Package.resolved..."
xcodebuild -resolvePackageDependencies \
  -workspace "$WORKSPACE" \
  -scheme myposecoach1 \
  -disableAutomaticPackageResolution

echo "Bootstrap hoàn tất: $WORKSPACE"

if [[ "${1:-}" == "--open" ]]; then
  open "$WORKSPACE"
fi
