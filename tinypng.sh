#!/bin/bash
#
# tinypng - 使用 TinyPNG (Tinify) API 壓縮圖片
#
# 用法:
#   tinypng [選項] [路徑]
#
# 路徑:
#   省略         壓縮當前目錄下的圖片
#   <檔案>       壓縮指定檔案
#   <目錄>       壓縮指定目錄下的圖片
#
# 選項:
#   --deep       遞迴處理子目錄
#   --dry-run    預覽模式，不實際壓縮
#   -h, --help   顯示說明
#
# 環境變數:
#   TINYFY_API_KEY   TinyPNG API Key（必填）
#

set -euo pipefail

# ── 顏色 ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── 預設值 ──
DEEP=false
DRY_RUN=false
TARGET=""

# 永遠排除的目錄
EXCLUDE_DIRS=("node_modules" ".git" "vendor")

# 支援的圖片副檔名
IMAGE_EXTENSIONS=("png" "jpg" "jpeg" "webp" "avif")

# ── 函式 ──

usage() {
  echo -e "${BOLD}tinypng${RESET} - 使用 TinyPNG API 壓縮圖片"
  echo ""
  echo -e "${BOLD}用法:${RESET}"
  echo "  tinypng                      壓縮當前目錄下的圖片"
  echo "  tinypng photo.png            壓縮指定檔案（覆蓋原檔）"
  echo "  tinypng ./images/            壓縮指定目錄下的圖片"
  echo "  tinypng --deep               遞迴壓縮當前目錄下所有圖片"
  echo "  tinypng --deep ./images/     遞迴壓縮指定目錄下所有圖片"
  echo ""
  echo -e "${BOLD}選項:${RESET}"
  echo "  --deep       遞迴處理子目錄"
  echo "  --dry-run    預覽模式，不實際壓縮"
  echo "  -h, --help   顯示說明"
  echo ""
  echo -e "${BOLD}自動排除:${RESET}"
  echo "  node_modules, .git, vendor"
  echo ""
  echo -e "${BOLD}環境變數:${RESET}"
  echo "  TINYFY_API_KEY   TinyPNG API Key（必填，免費方案每月 500 張）"
}

human_size() {
  local bytes=$1
  if (( bytes >= 1048576 )); then
    printf "%.2f MB" "$(echo "scale=2; $bytes / 1048576" | bc)"
  elif (( bytes >= 1024 )); then
    printf "%.1f KB" "$(echo "scale=1; $bytes / 1024" | bc)"
  else
    printf "%d B" "$bytes"
  fi
}

is_image_file() {
  local file="$1"
  local ext="${file##*.}"
  ext="${ext,,}"  # 轉小寫
  for valid_ext in "${IMAGE_EXTENSIONS[@]}"; do
    if [[ "$ext" == "$valid_ext" ]]; then
      return 0
    fi
  done
  return 1
}

# 搜尋目錄下的圖片檔案
find_images() {
  local dir="$1"
  local deep="$2"

  # 建立 find 排除條件
  local exclude_args=()
  for d in "${EXCLUDE_DIRS[@]}"; do
    exclude_args+=(-name "$d" -prune -o)
  done

  # 建立副檔名搜尋條件
  local ext_args=()
  local first=true
  for ext in "${IMAGE_EXTENSIONS[@]}"; do
    if $first; then
      ext_args+=(-iname "*.${ext}")
      first=false
    else
      ext_args+=(-o -iname "*.${ext}")
    fi
  done

  if $deep; then
    find "$dir" \( "${exclude_args[@]}" \( "${ext_args[@]}" \) -print \) 2>/dev/null | sort
  else
    find "$dir" -maxdepth 1 \( "${ext_args[@]}" \) -print 2>/dev/null | sort
  fi
}

compress_image() {
  local input_file="$1"
  local display_name="$2"

  # 取得原始檔案大小
  local original_size
  original_size=$(stat -f%z "$input_file" 2>/dev/null || stat -c%s "$input_file" 2>/dev/null)

  printf "  ${CYAN}⏳${RESET} %-50s " "$display_name"

  # Step 1: 上傳圖片到 Tinify API
  local header_file="/tmp/tinypng_headers_$$"
  local response
  response=$(curl -s -w "\n%{http_code}" \
    --user "api:${TINYFY_API_KEY}" \
    --data-binary @"$input_file" \
    --dump-header "$header_file" \
    "https://api.tinify.com/shrink")

  local http_code
  http_code=$(echo "$response" | tail -1)
  local body
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" != "201" ]]; then
    local error_msg
    error_msg=$(echo "$body" | grep -o '"message":"[^"]*"' | head -1 | cut -d'"' -f4)
    printf "${RED}✗ 失敗${RESET} (HTTP %s: %s)\n" "$http_code" "${error_msg:-未知錯誤}"
    return 1
  fi

  # 從 header 取得壓縮後圖片的 URL
  local location
  location=$(grep -i '^Location:' "$header_file" | tr -d '\r' | awk '{print $2}')

  if [[ -z "$location" ]]; then
    printf "${RED}✗ 失敗${RESET} (無法取得壓縮後圖片 URL)\n"
    return 1
  fi

  # Step 2: 下載壓縮後的圖片（覆蓋原檔）
  curl -s --user "api:${TINYFY_API_KEY}" \
    --output "$input_file" \
    "$location"

  # 取得壓縮後檔案大小
  local compressed_size
  compressed_size=$(stat -f%z "$input_file" 2>/dev/null || stat -c%s "$input_file" 2>/dev/null)

  # 計算節省比例
  local saved_bytes saved_pct
  saved_bytes=$((original_size - compressed_size))
  if (( original_size > 0 )); then
    saved_pct=$(echo "scale=1; $saved_bytes * 100 / $original_size" | bc)
  else
    saved_pct="0"
  fi

  printf "${GREEN}✓${RESET} %s → %s ${GREEN}(-${saved_pct}%%)${RESET}\n" \
    "$(human_size "$original_size")" \
    "$(human_size "$compressed_size")"

  # 紀錄統計
  echo "${original_size}:${compressed_size}" >> /tmp/tinypng_stats_$$
}

# ── 解析參數 ──

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deep)
      DEEP=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo -e "${RED}錯誤: 未知選項 $1${RESET}" >&2
      echo ""
      usage
      exit 1
      ;;
    *)
      if [[ -n "$TARGET" ]]; then
        echo -e "${RED}錯誤: 只能指定一個路徑${RESET}" >&2
        exit 1
      fi
      TARGET="$1"
      shift
      ;;
  esac
done

# ── 檢查前置條件 ──

if [[ -z "${TINYFY_API_KEY:-}" ]]; then
  echo -e "${RED}錯誤: 請設定環境變數 TINYFY_API_KEY${RESET}" >&2
  echo "  export TINYFY_API_KEY=\"your-api-key\"" >&2
  echo "  免費申請: https://tinypng.com/developers" >&2
  exit 1
fi

if ! command -v curl &>/dev/null; then
  echo -e "${RED}錯誤: 需要安裝 curl${RESET}" >&2
  exit 1
fi

if ! command -v bc &>/dev/null; then
  echo -e "${RED}錯誤: 需要安裝 bc${RESET}" >&2
  exit 1
fi

# ── 決定要壓縮的檔案 ──

FILES=()

if [[ -z "$TARGET" ]]; then
  # 沒指定路徑 → 當前目錄
  TARGET="."
fi

if [[ -f "$TARGET" ]]; then
  # 指定的是檔案
  if is_image_file "$TARGET"; then
    FILES+=("$TARGET")
  else
    echo -e "${RED}錯誤: $TARGET 不是支援的圖片格式（PNG/JPG/WebP/AVIF）${RESET}" >&2
    exit 1
  fi
elif [[ -d "$TARGET" ]]; then
  # 指定的是目錄
  SEARCH_DIR="$TARGET"

  # --deep 模式：偵測 dist/build 目錄
  if $DEEP; then
    FOUND_BUILD_DIRS=()
    for build_dir in "dist" "build"; do
      if [[ -d "${SEARCH_DIR}/${build_dir}" ]]; then
        # 確認裡面有圖片
        local_count=$(find_images "${SEARCH_DIR}/${build_dir}" true | wc -l | tr -d ' ')
        if (( local_count > 0 )); then
          FOUND_BUILD_DIRS+=("$build_dir")
        fi
      fi
    done

    if [[ ${#FOUND_BUILD_DIRS[@]} -gt 0 ]]; then
      build_names=$(printf ", " "${FOUND_BUILD_DIRS[@]}")
      build_names="${build_names%, }"
      echo ""
      echo -e "${YELLOW}📁 發現 ${build_names} 目錄含有圖片${RESET}"
      echo -n "   是否只壓縮 ${build_names} 裡的圖片？(y/N) "
      read -r answer

      if [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]]; then
        # 只壓縮 dist/build
        for build_dir in "${FOUND_BUILD_DIRS[@]}"; do
          while IFS= read -r f; do
            FILES+=("$f")
          done < <(find_images "${SEARCH_DIR}/${build_dir}" true)
        done
      else
        # 排除 dist/build，壓縮其他
        for build_dir in "${FOUND_BUILD_DIRS[@]}"; do
          EXCLUDE_DIRS+=("$build_dir")
        done
        while IFS= read -r f; do
          FILES+=("$f")
        done < <(find_images "$SEARCH_DIR" true)
      fi
    else
      # 沒有 dist/build，正常遞迴搜尋
      while IFS= read -r f; do
        FILES+=("$f")
      done < <(find_images "$SEARCH_DIR" true)
    fi
  else
    # 非 deep 模式：只搜當前層
    while IFS= read -r f; do
      FILES+=("$f")
    done < <(find_images "$SEARCH_DIR" false)
  fi
else
  echo -e "${RED}錯誤: $TARGET 不存在${RESET}" >&2
  exit 1
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo -e "${YELLOW}沒有找到可壓縮的圖片${RESET}"
  exit 0
fi

# ── 開始壓縮 ──

echo ""
echo -e "${BOLD}🐼 TinyPNG 圖片壓縮${RESET}"
echo -e "   共 ${#FILES[@]} 張圖片"
if $DEEP; then
  echo -e "   模式: 遞迴 (--deep)"
fi
if $DRY_RUN; then
  echo -e "   ${YELLOW}🔍 預覽模式${RESET}"
fi
echo ""

# 清理暫存
rm -f /tmp/tinypng_stats_$$

if $DRY_RUN; then
  for f in "${FILES[@]}"; do
    local_size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null)
    printf "  ${CYAN}📄${RESET} %-50s %s\n" "$f" "$(human_size "$local_size")"
  done
  echo ""
  echo -e "${YELLOW}預覽完成，移除 --dry-run 以執行壓縮${RESET}"
  exit 0
fi

# 實際壓縮
SUCCESS=0
FAIL=0

for f in "${FILES[@]}"; do
  if compress_image "$f" "$f"; then
    ((SUCCESS++))
  else
    ((FAIL++))
  fi
done

# ── 總結報告 ──

echo ""
echo -e "${BOLD}📊 壓縮結果${RESET}"

if [[ -f /tmp/tinypng_stats_$$ ]]; then
  total_original=0
  total_compressed=0
  while IFS=: read -r orig comp; do
    total_original=$((total_original + orig))
    total_compressed=$((total_compressed + comp))
  done < /tmp/tinypng_stats_$$

  total_saved=$((total_original - total_compressed))
  if (( total_original > 0 )); then
    total_pct=$(echo "scale=1; $total_saved * 100 / $total_original" | bc)
  else
    total_pct="0"
  fi

  echo -e "   ✅ 成功: ${GREEN}${SUCCESS}${RESET} 張"
  if (( FAIL > 0 )); then
    echo -e "   ❌ 失敗: ${RED}${FAIL}${RESET} 張"
  fi
  echo -e "   📦 原始大小: $(human_size $total_original)"
  echo -e "   📦 壓縮後:   $(human_size $total_compressed)"
  echo -e "   💾 共節省:   ${GREEN}$(human_size $total_saved) (-${total_pct}%)${RESET}"
else
  echo -e "   ❌ 全部失敗: ${RED}${FAIL}${RESET} 張"
fi

# 清理暫存
rm -f /tmp/tinypng_stats_$$ /tmp/tinypng_headers_$$

echo ""
