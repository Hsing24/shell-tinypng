#!/bin/bash

# tinypng 一鍵安裝器：預設安裝至使用者自己的 ~/.local/bin。
set -euo pipefail

SCRIPT_URL="https://raw.githubusercontent.com/Hsing24/shell-tinypng/main/tinypng.sh"
INSTALL_DIR="${TINYPNG_INSTALL_DIR:-${HOME}/.local/bin}"
INSTALL_PATH="${INSTALL_DIR}/tinypng"
AUTO_CONFIRM=false
TEMP_PATH=""

cleanup() {
  if [[ -n "$TEMP_PATH" ]]; then
    rm -f "$TEMP_PATH"
  fi
}
trap cleanup EXIT

usage() {
  echo "用法: install.sh [--yes]"
  echo ""
  echo "  --yes  跳過確認（請先確認腳本來源）"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      AUTO_CONFIRM=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "錯誤: 未知選項 $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -t 0 && ! -r /dev/tty && ! "$AUTO_CONFIRM" == true ]]; then
  echo "錯誤: 非互動模式需要明確加上 --yes。" >&2
  exit 1
fi

echo "即將安裝 tinypng："
echo "  來源: $SCRIPT_URL"
echo "  目標: $INSTALL_PATH"
echo ""

if [[ "$AUTO_CONFIRM" != true ]]; then
  if [[ -r /dev/tty ]]; then
    read -r -p "確認安裝？(y/N) " answer < /dev/tty
  else
    read -r -p "確認安裝？(y/N) " answer
  fi
  case "${answer,,}" in
    y|yes) ;;
    *)
      echo "已取消安裝。"
      exit 0
      ;;
  esac
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "錯誤: 需要安裝 curl。" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"
TEMP_PATH=$(mktemp "${INSTALL_DIR}/.tinypng.XXXXXX")
curl --fail --silent --show-error --location "$SCRIPT_URL" --output "$TEMP_PATH"
chmod 755 "$TEMP_PATH"
mv -f "$TEMP_PATH" "$INSTALL_PATH"
TEMP_PATH=""

echo "安裝完成：$INSTALL_PATH"
if [[ ":${PATH}:" != *":${INSTALL_DIR}:"* ]]; then
  echo "請將以下目錄加入 PATH，之後即可直接使用 tinypng："
  echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
fi
echo "API Key 設定方式："
echo "  export TINYPNG_API_KEY=\"your-api-key\""
