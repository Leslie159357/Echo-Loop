#!/usr/bin/env bash
# 公共构建号计算函数
#
# 用法：source scripts/lib/build_number.sh
#       calculate_build_number "1.0.8"
#
# 输出变量：
#   BUILD_NUMBER  - 构建号（commit count，全局单调递增）
#   TAG_NAME      - 要创建的 tag 名（纯 SemVer，如 v1.0.11）
#   SKIP_TAG_CREATION - 是否跳过 tag 创建（当前 commit 已有同版本 tag）
#
# 设计原则：
# - Android versionCode 必须单调递增。跨 versionName 重置 +N 会导致
#   旧版本（如 v1.0.10+4）已被 Android 记下 versionCode=4，新版本
#   v1.0.11+1 的 versionCode=1 反而被系统拒绝安装。
# - 改用 commit count 作为 versionCode：每次 commit 自动 +1，永不倒退。
# - tag 只用纯 SemVer 形式（v1.0.11），用户和系统通过 versionName 识别版本。

# 从 pubspec.yaml 读取版本号（不含构建号）
get_build_name() {
  local raw_version="$(grep '^version:' pubspec.yaml | awk '{print $2}' || true)"
  if [[ -z "$raw_version" ]]; then
    echo "ERROR: Unable to read version from pubspec.yaml" >&2
    return 1
  fi
  # 去除构建号后缀（如 1.0.8+1 → 1.0.8）
  echo "${raw_version%%+*}"
}

# 计算构建号
# 参数：BUILD_NAME - 版本号（如 1.0.11）
# 输出：设置 BUILD_NUMBER, TAG_NAME, SKIP_TAG_CREATION 变量
calculate_build_number() {
  local BUILD_NAME="$1"
  BUILD_NUMBER=""
  TAG_NAME="v${BUILD_NAME}"   # 纯 SemVer，不带 +N
  SKIP_TAG_CREATION=0

  # versionCode 全局单调递增：直接用 commit count
  BUILD_NUMBER="$(git rev-list --count HEAD)"

  # 当前 commit 已有同 tag → 跳过 tag 创建
  if git tag --points-at HEAD | grep -qx "$TAG_NAME"; then
    SKIP_TAG_CREATION=1
  fi
}

# 创建 tag（用于 CI 成功后）
create_build_tag() {
  local TAG="$1"
  if git tag "$TAG"; then
    echo "Created git tag: $TAG"
    return 0
  else
    echo "ERROR: Failed to create git tag: $TAG" >&2
    return 1
  fi
}

# 从 tag 提取版本号和构建号
# 支持两种格式：
#   v1.0.11      新格式 → BUILD_NUMBER 用 git rev-list --count <tag> 算
#   v1.0.11+5    旧格式 → BUILD_NUMBER=5（兼容历史 tag 回放）
parse_tag() {
  local TAG="$1"
  local build_name="${TAG#v}"
  build_name="${build_name%+*}"
  local build_number=""
  if [[ "$TAG" == *+* ]]; then
    # 旧格式：直接取 +N
    build_number="${TAG##*+}"
  else
    # 新格式：用 commit count（基于 tag 指向的 commit，不是 HEAD）
    build_number="$(git rev-list --count "$TAG" 2>/dev/null || echo "")"
  fi
  echo "BUILD_NAME=${build_name}"
  echo "BUILD_NUMBER=${build_number}"
}
