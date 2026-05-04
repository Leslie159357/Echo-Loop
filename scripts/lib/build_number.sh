#!/usr/bin/env bash
# 公共构建号计算函数
#
# 用法：source scripts/lib/build_number.sh
#       calculate_build_number "1.0.8"
#
# 输出变量：
#   BUILD_NUMBER  - 构建号（空表示默认 0）
#   TAG_NAME      - 要创建的 tag 名
#   SKIP_TAG_CREATION - 是否跳过 tag 创建（当前 commit 已有同版本 tag）

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
# 参数：BUILD_NAME - 版本号（如 1.0.8）
# 输出：设置 BUILD_NUMBER, TAG_NAME, SKIP_TAG_CREATION 变量
calculate_build_number() {
  local BUILD_NAME="$1"
  BUILD_NUMBER=""
  TAG_NAME=""
  SKIP_TAG_CREATION=0

  # 1. 检查当前 commit 是否已有同版本 tag
  local EXISTING_TAG="$(git tag --points-at HEAD | grep -E "^v${BUILD_NAME}([+][0-9]+)?$" || true)"
  if [[ -n "$EXISTING_TAG" ]]; then
    # 提取构建号（无 + 后缀则默认空）
    if [[ "$EXISTING_TAG" =~ [+][0-9]+$ ]]; then
      BUILD_NUMBER="${BASH_REMATCH[0]#+}"
    fi
    SKIP_TAG_CREATION=1
    TAG_NAME="$EXISTING_TAG"
    return 0
  fi

  # 2. 获取同版本号的最大构建号
  local MAX_BUILD="$(git tag -l "v${BUILD_NAME}*" | grep -Eo '[+][0-9]+$' | grep -Eo '[0-9]+' | sort -n | tail -1 || true)"

  # 3. 检查是否有纯版本 tag（v1.0.8 无构建号）
  local HAS_PURE_TAG=""
  if git tag -l | grep -q "^v${BUILD_NAME}$"; then
    HAS_PURE_TAG="yes"
  fi

  # 4. 计算新构建号和 tag 名
  if [[ -n "$MAX_BUILD" ]]; then
    # 有 +N tag，构建号递增
    BUILD_NUMBER=$((MAX_BUILD + 1))
    TAG_NAME="v${BUILD_NAME}+${BUILD_NUMBER}"
  elif [[ -n "$HAS_PURE_TAG" ]]; then
    # 只有纯版本 tag，这是第二次构建
    BUILD_NUMBER=1
    TAG_NAME="v${BUILD_NAME}+1"
  else
    # 无任何同版本 tag，第一次构建
    BUILD_NUMBER=""  # 不设置，Flutter 默认为 0
    TAG_NAME="v${BUILD_NAME}"
  fi

  SKIP_TAG_CREATION=0
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
parse_tag() {
  local TAG="$1"
  # v1.0.8 或 v1.0.8+2 → 提取 1.0.8 和构建号
  local build_name="${TAG#v}"
  build_name="${build_name%+*}"
  local build_number=""
  if [[ "$TAG" =~ [+][0-9]+$ ]]; then
    build_number="${BASH_REMATCH[0]#+}"
  fi
  # 输出供 eval 解析，空值也要输出
  echo "BUILD_NAME=${build_name}"
  echo "BUILD_NUMBER=${build_number:-}"
}