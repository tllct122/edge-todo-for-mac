# EdgeTodo ✿

[English](README.md) | **繁體中文** | [简体中文](README.zh-Hans.md)

**一個住在 Mac 螢幕邊緣的待辦清單，讓你永遠不會忘記查看。**

大部分待辦 App 都要你停下手上的工作，再打開另一個 App。EdgeTodo 平時只會在螢幕右邊露出一條細邊：滑鼠移過去，它就會滑出來；滑鼠移開，它又會自動收回去。

<!-- 可在這裡加入示範 GIF：![demo](docs/demo.gif) -->

## 功能

- 🫧 **滑過即看**：平時收在螢幕邊緣，滑鼠移過去就會彈出
- 📌 **釘選常駐**：釘選後面板會變成液態玻璃（Liquid Glass，需要 macOS 26 或以上）
  - 正在使用時：液態玻璃加磨砂，方便閱讀
  - 使用其他 App 時：完全透明的玻璃，可以看到底下的內容
- 🔁 **重複任務**
  - *隨時重複*：適合經常做但不一定每天做的事，例如健身、洗衣服。每點一下就記錄一次完成時間，並顯示「last: 3 days ago · 12×」
  - *定期*：每天、每週、每月，或任何自訂間隔（每 3 天、每 2 週……）。完成後會顯示下次到期日，到期會自動重新出現，逾期會變紅色提醒。每日任務還會顯示 🔥 連續完成天數
- 📌 **任務置頂**：重要的任務會固定在最上方的標示區
- ↕️ **拖曳排序**：隨意調整任務順序，甚至可以拖到其他分類
- 🗂 **分類與狀態**：用 `#work`、`#life`、`#study` 等標籤分類，並可分到 To-do / Pending / Done / Cancelled
- 🎨 **全面自訂**：字型（可使用 Mac 上任何字型）、粗細、大小、文字顏色、強調色、背景色調、透明度、尺寸、圓角
- 🤖 **AI 友善**：任務儲存在一個純 JSON 檔案，任何 AI 助理或程式都可以幫你新增任務，面板會在一秒內更新
- 🪶 **輕巧原生**：只有一個 Swift 檔案，不需要任何套件、帳號或雲端

## 安裝

需要 macOS 12 或以上（液態玻璃需要 macOS 26 或以上）。

1. 下載這個 repo（**Code → Download ZIP**），然後解壓縮
2. 打開「**終端機**」，輸入 `bash `（後面有一個空格），把 `build.sh` 拖進視窗，再按 Enter
3. 如果 macOS 要求安裝 **Command Line Tools**，安裝完成後再執行一次第 2 步

腳本會自動編譯 App、安裝到 `/Applications`，然後開啟它。

## 使用方法

| 動作 | 方法 |
|---|---|
| 打開面板 | 將滑鼠移到螢幕最右邊（上半部） |
| 新增任務 | 在底部輸入。加上 `#分類` 即可分類，例如 `剪片素材 #content` |
| 完成任務 | 點擊方格 |
| 新增重複任務 | 點擊 + 旁邊的 ↻ 按鈕（依序切換：不重複 → 隨時重複 → 每天 → 每週 → 每月），或直接輸入：`/repeat`、`/daily`、`/weekly`、`/monthly`，或自訂間隔如 `/3d`（3 天）、`/2w`（2 週）、`/6m`（6 個月）、`/every 10 days`，例如 `澆花 #home /3d` |
| 記錄重複任務 | 點擊任務的 ↻ 圖示，每點一次就記錄一次完成時間 |
| 調整順序 | 拖曳任務到新位置。拖到其他分類會一併改分類，拖進 📌 區會自動置頂。也可以右鍵 → **Move Up / Move Down** |
| 任務置頂 | 右鍵 → **Pin to Top** |
| 將現有任務改為重複 | 右鍵 → **Repeat**（選擇預設，或選 **Custom interval…** 自訂每 N 天／週／月） |
| 撤回打卡 | 右鍵 → **Undo Last Check-in** |
| 移動、改分類、刪除 | 對任務按右鍵 |
| 保持面板開啟 | 點擊 📌 |
| 設定 | 點擊面板上的 ⚙︎，或選單列的 ☑︎ 圖示 → **Settings…**（⌘,） |
| 開機自動啟動 | 選單列的 ☑︎ 圖示 → **Open at Login** |

## 讓 AI 幫你新增任務

所有任務都儲存在 `~/EdgeTodo/todos.json`。讓你的 AI 助理存取 `~/EdgeTodo` 資料夾，然後說「把『訂星期五晚餐』加到我的待辦清單」，面板就會在一秒內更新。

只有 `title` 是必填，其他欄位都有預設值：

```json
{
  "todos": [
    { "title": "weekly report", "category": "work", "status": "todo" }
  ]
}
```

`status` 可以是 `todo`、`pending`、`completed` 或 `cancelled`。

加上 `"pinned": true` 可以讓任務置頂。重複任務加上 `"repeat": "anytime"`，或定期設定如 `"repeat": "every", "every": 3, "unit": "day"`（`unit` 可以是 `day`、`week` 或 `month`；也可以直接寫 `"daily"`、`"weekly"`、`"monthly"`）。App 會記錄 `lastDone` 和每次打卡時間的 `history`（ISO 8601 格式），方便你讓 AI 幫你分析習慣。

## 手動編譯

```bash
swiftc -O -parse-as-library EdgeTodo.swift -o EdgeTodo
```

使用 macOS 26 或以上的 SDK 編譯時，加上 `-D GLASS` 即可啟用液態玻璃。`build.sh` 會自動處理這一步，也會自動解決 SDK 與編譯器版本不相符的問題。

## 支持

如果 EdgeTodo 讓你的日子輕鬆了一點，歡迎在這裡支持：

- ☕ Buy Me a Coffee：https://buymeacoffee.com/sirene122

## 靈感來源

靈感來自 [@lilian.chiuuu](https://www.instagram.com/lilian.chiuuu/) 的一篇貼文，內容是一個不用特地記得打開的待辦清單。

## 授權

[MIT](LICENSE)
