#!/usr/bin/env bash
set -euo pipefail

# 从 HuggingFace 镜像下载 whisper 模型文件，上传到 R2 public/models/。
# 一次性脚本，模型文件固定后不需要重复运行。
#
# 用法:
#   scripts/upload_asr_models_to_r2.sh
#
# 环境变量:
#   R2_ENDPOINT           S3-compatible endpoint URL
#   R2_ACCESS_KEY_ID      R2 API token access key ID
#   R2_SECRET_ACCESS_KEY  R2 API token secret access key
#   R2_BUCKET             R2 bucket name

: "${R2_ENDPOINT:?Set R2_ENDPOINT}"
: "${R2_ACCESS_KEY_ID:?Set R2_ACCESS_KEY_ID}"
: "${R2_SECRET_ACCESS_KEY:?Set R2_SECRET_ACCESS_KEY}"
: "${R2_BUCKET:?Set R2_BUCKET}"

HF_MIRROR="https://hf-mirror.com"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

log() { echo "$(date +%H:%M:%S) $*"; }

# 模型定义: model_id|hf_repo|commit|file1,file2,...
MODELS=(
  "whisper-tiny-en-int8|csukuangfj/sherpa-onnx-whisper-tiny.en|d026532c022fa99fd789d6b32446a1df7b6bfc43|tiny.en-encoder.int8.onnx,tiny.en-decoder.int8.onnx,tiny.en-tokens.txt"
  "whisper-base-en-int8|csukuangfj/sherpa-onnx-whisper-base.en|59eea950fc76df2453efb57e6c0fd334548e8ffe|base.en-encoder.int8.onnx,base.en-decoder.int8.onnx,base.en-tokens.txt"
  "whisper-small-en-int8|csukuangfj/sherpa-onnx-whisper-small.en|d9533f69affd85061aee349af7fea5cb2996dbbe|small.en-encoder.int8.onnx,small.en-decoder.int8.onnx,small.en-tokens.txt"
)

for entry in "${MODELS[@]}"; do
  IFS='|' read -r model_id hf_repo commit files_csv <<< "$entry"
  IFS=',' read -ra files <<< "$files_csv"

  log "📦 $model_id"
  model_tmp="$TMP_DIR/$model_id"
  mkdir -p "$model_tmp"

  for file in "${files[@]}"; do
    url="$HF_MIRROR/$hf_repo/resolve/$commit/$file"
    local_path="$model_tmp/$file"

    log "  ↓ 下载 $file ..."
    curl -fSL --progress-bar -o "$local_path" "$url"

    r2_key="public/models/$model_id/$file"
    log "  ↑ 上传 → s3://${R2_BUCKET}/${r2_key}"
    AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
    AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
    aws s3 cp "$local_path" "s3://${R2_BUCKET}/${r2_key}" \
      --endpoint-url "$R2_ENDPOINT" \
      --no-progress

    # 上传完立即删除，节省临时空间
    rm -f "$local_path"
  done
  log "  ✓ $model_id 完成"
done

log "✅ 全部完成"
