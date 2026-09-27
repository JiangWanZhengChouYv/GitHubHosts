#!/usr/bin/env bash
#
# GitHubHosts 构建脚本
# 使用 XcodeGen 生成 Xcode 工程，再用 xcodebuild 构建 Release 版本，
# 最终把 GitHubHosts.app 拷贝到 dist/ 目录。
#
set -euo pipefail

# 定位到脚本所在目录，保证在任意工作目录下调用都能正确运行
cd "$(dirname "$0")"

PROJECT_NAME="GitHubHosts"
SCHEME="GitHubHosts"
CONFIGURATION="Release"
DERIVED_DATA_PATH="build"
DIST_DIR="dist"

echo "==> 使用 XcodeGen 生成 Xcode 工程 (${PROJECT_NAME}.xcodeproj)..."
xcodegen generate

echo "==> 开始构建 (${CONFIGURATION})..."
xcodebuild \
  -project "${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  build

BUILT_APP="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/${PROJECT_NAME}.app"
if [ ! -d "${BUILT_APP}" ]; then
  echo "错误: 未找到构建产物 ${BUILT_APP}" >&2
  exit 1
fi

echo "==> 拷贝构建产物到 ${DIST_DIR}/ ..."
mkdir -p "${DIST_DIR}"
rm -rf "${DIST_DIR}/${PROJECT_NAME}.app"
cp -R "${BUILT_APP}" "${DIST_DIR}/${PROJECT_NAME}.app"

echo ""
echo "构建完成 ✅"
echo "输出路径: $(cd "${DIST_DIR}" && pwd)/${PROJECT_NAME}.app"
