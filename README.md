# 🐼 tinypng

一行指令壓縮圖片 — 使用 [TinyPNG (Tinify)](https://tinypng.com/) API 的 Shell 腳本。

## 功能特色

- 支援 **PNG / JPG / WebP / AVIF** 格式
- 壓縮單一檔案或整個目錄
- `--deep` 遞迴處理子目錄
- `--dry-run` 預覽模式，不實際壓縮
- 自動偵測 `dist/` / `build/` 目錄，詢問是否只壓縮產出物
- 自動排除 `node_modules`、`.git`、`vendor`
- 彩色終端輸出，顯示壓縮比例與總結報告

## 安裝

```bash
# 下載腳本
curl -o tinypng.sh https://raw.githubusercontent.com/Hsing24/shell-tinypng/main/tinypng.sh

# 賦予執行權限
chmod +x tinypng.sh

# （可選）移至 PATH 目錄
sudo mv tinypng.sh /usr/local/bin/tinypng
```

### 前置需求

- `curl`
- `bc`
- [TinyPNG API Key](https://tinypng.com/developers)（免費方案每月 500 張）

## 設定

將你的 API Key 設為環境變數：

```bash
export TINYFY_API_KEY="your-api-key"
```

建議加入 `~/.bashrc` 或 `~/.zshrc` 以持久化。

## 用法

```bash
# 壓縮當前目錄下的圖片
tinypng

# 壓縮指定檔案
tinypng photo.png

# 壓縮指定目錄
tinypng ./images/

# 遞迴壓縮所有子目錄
tinypng --deep

# 遞迴壓縮指定目錄
tinypng --deep ./images/

# 預覽模式（不實際壓縮）
tinypng --dry-run
tinypng --deep --dry-run ./images/
```

### 選項

| 選項 | 說明 |
| --- | --- |
| `--deep` | 遞迴處理子目錄 |
| `--dry-run` | 預覽模式，列出檔案但不壓縮 |
| `-h`, `--help` | 顯示說明 |

## 輸出範例

```
🐼 TinyPNG 圖片壓縮
   共 3 張圖片

  ⏳ ./hero.png                   ✓ 1.20 MB → 450.3 KB (-63.4%)
  ⏳ ./icon.png                   ✓ 85.0 KB → 32.1 KB (-62.2%)
  ⏳ ./banner.jpg                 ✓ 2.50 MB → 980.5 KB (-61.7%)

📊 壓縮結果
   ✅ 成功: 3 張
   📦 原始大小: 3.78 MB
   📦 壓縮後:   1.43 MB
   💾 共節省:   2.35 MB (-62.2%)
```

## License

[MIT](LICENSE)
