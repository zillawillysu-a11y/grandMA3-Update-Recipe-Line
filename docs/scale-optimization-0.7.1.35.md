# v0.7.1.35 第一輪效能實作

2026-09-30。基於已實機確認標記行為的 v0.7.1.34。REAL-WORLD VALIDATION PENDING。

## 變更

- 空 selection 的 PENDING 結果直接維持空紅框投影，不再遍歷正在增長的 assignment 列表。非空 selection 仍使用原完整投影與 selectedComplete gate，換選取也不沿用舊投影。
- scope 每次呼叫對每個不同 Group 只計算一次 member count。已有 fingerprint signature 時不排序 member keys；缺 signature 時仍用原排序、逗號串接格式。
- 每個 Group 的 handles 只聯集一次，依該 Group 最後出現的 row 順序聯集；重疊 Group 的最終 handle 優先順序與原逐 row 聯集相同。
- 所有 Recipe rows、canonical identity、member capability、metadata 安全檢查、stageKey、原子紫框發布及 v0.7.1.34 grid rediscovery 保留。

沒有增加跨 call 快取。每次 sources scope 呼叫重建 Group count/signature 和最後 row 順序；原 Group fingerprint 及現有 stage cache 的失效規則保留。scope 編輯及 Recipe deletion / NEW CONTENT 仍走原解析流程。

## 離線證據

`python tools/run_workflow.py`：89 workflow assertions、215 Track A checks 通過。
新增回歸包含：空 selection 不讀 assignment.member；同一 task 改選已完成 member 仍能顯示投影；重複 Group 只計數/聯集一次；重疊 Group 的 last-row handle 優先順序；原 fallback signature 格式；下一次 scope 呼叫讀到 Group membership 及 Recipe Selection 的修改。

`python -u tools/review_scale_phaser.py`：

| 模擬 members（slice 250） | v0.7.1.34 空 selection assignment 檢查 | v0.7.1.35 檢查 | 推進次數 |
|---:|---:|---:|---:|
| 1,265 | 3,750 | 0 | 6 |
| 12,650 | 318,750 | 0 | 51 |

擴充探針及原 fixtures 共 218 Track A checks 通過。Lua/XML 解析及 generated runtime/version 一致性通過。

以上是工作量證據，不是 grandMA3 耗時量測。slice 排程仍為一個 tick 推進一個 slice；12,650 members 案例仍有約 500 ms 的推進間等待。不能據此宣稱達成 <=300 ms 或 Phaser BUG 已修復。

## 實機驗收與後續

匯入 v0.7.1.35，啟動並檢查紫框及 Group 紅框：空選取、一般選取、解析途中換選取都應維持原規則。相同 Cue 比較冷啟動和暖重訪，DETAIL 的 scope/render/resolver 分項可輔助；Cue-to-purple 以 wall time 為準。確認 Recipe 刪除及 NEW CONTENT 沒退步。

此輪確認後再做有時間及最大 slices 預算的多 slice 排程；25.2001 的非零 measure 相容性則先取得唯讀 native dump，再改安全解析。

已實際複製 Plugin XML 及其兩份 Lua 元件到本機 Update Plugin 目錄，三份 SHA256 與來源一致。部署前版本備份：`C:/tmp/update-plugin-pre-0.7.1.35-20260930-121434`。雜湊一致只證明部署檔案相同，實機效果仍待使用者測試。
