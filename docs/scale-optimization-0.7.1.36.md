# v0.7.1.36：降低引擎重複原生查詢與批次等待

2026-09-30。使用者回報 v0.7.1.35 的速度仍不可接受，要求先處理速度，Phaser BUG 晚點修。REAL-WORLD VALIDATION PENDING for v0.7.1.36。

## 最新實機證據

已讀取錄影 `2026-09-30 12-27-11.mp4`（60 fps、20.22 秒、1440×2560），並檢視完整尺寸的 Inspector 裁切畫面。以下是錄影中面板顯示的數字，並非以 GO 到紫框逐幀量測的新數字：

| 約略影片時點 | Cue / 狀態 | 面板 total | 累積 engine | 其他 |
|---:|---|---:|---:|---|
| 0 秒 | 21 Inter AG Stomp / INCONCLUSIVE | 1620.1 ms | 985.9 ms | scope 94.3、tiles 45.1 ms |
| 2 秒 | 22 Last Fill / PENDING | 539.5 ms | 237.5 ms | rows 226、members 424/1295、scope 106.5 ms |
| 4 秒 | 23 End / PENDING | 300.5 ms | 111.8 ms | rows 231、members 103/1967、scope 155.0 ms |
| 10 秒 | 24 Top5 / INCONCLUSIVE | 2071.6 ms | 1096.1 ms | scope 125.3、tiles 47.1 ms |
| 15 秒 | 2 Player_1_Count / PROVEN | 386.7 ms | 157.0 ms | scope 49.7、tiles 49.3 ms |
| 16 秒 | 3 Player_1_Verse / PROVEN | 461.6 ms | 207.7 ms | scope 61.8、tiles 32.6 ms |

v0.7.1.35 的局部工作量優化未滿足速度需求。錄影表明引擎本身占了相當成本，單改 yield 不足以處理 1–2 秒的解析。

## 本輪實作

- 每個 stage runtime/task 建立最多 4096 項的正向 address cache。原 runtime 的 row normalization、metadata lookup、FeatureGroup identity 和 sourceGroups 收集都經過同一個 identity adapter；同 handle 在本次解析內只需一次 `ToAddr`。未能證明的地址不快取，超過上限回到原讀取。
- 只重用本次 task 已讀到的地址，不改 `canonicalMemberKey` 的 fixture round-trip 證明，不持久化 address cache。Cue/task 切換、原有 structure invalidation 或 forceRefresh 重建 runtime 後即重新讀取。Preset/Group 外部修改仍依既有 fingerprint/structure polling 及 refresh 規則。
- 使用原本有界單批引擎，在一個 tick 中最多推進 4 個 steps，8 ms 軟預算。從 production render 開始計入預算，包含 sources 前已消耗的 render 時間；每次至少推進一次以免餓死。同步 native API 不可中斷，預算只禁止再啟動下一批。
- Time 缺失、讀不到、或倒退時回到單步；不以 os.clock CPU fallback 授權額外 native 批次。沒有新增巢狀 coroutine。
- selection 不變時不重排剩餘 members；改變時照原規則重新排優先序。每步合併仍沿用原解析器，紫框仍等全 scope 完成後一次發布。
- 每步重置/累計 metadata、member UI、engine 計時，避免多步時重複相減；引擎 elapsed 只扣除 run 內的 metadata/UI 差值。DETAIL 與 ContextTiming 增加 steps/tick / resolver_steps，便於查看排程是否仍受單批成本限制。

Phaser timing/unsafe 規則、Recipe deletion / NEW CONTENT、Group 紅框、v0.7.1.34 grid rediscovery 均沿用原路徑。

## 離線驗證

- `python tools/run_workflow.py`：89 workflow assertions、226 Track A checks 通過。
- `python -u tools/review_scale_phaser.py`：擴充原 fixtures 後 229 checks 通過。
- `python tools/check_parse.py`、`python tools/build_show_candidate.py --check`、`git diff --check` 通過。
- 回歸驗證：每 tick 四步上限、超時後停止追加、已消耗預算、Time 缺失/無值/倒退、累積計時不重複扣除、完整最終 assignments、PENDING 紫框不提前發布、解析中換 selection，以及 task address cache 的正向重用、跨 stage 重新讀取與容量上限。
- 1,000 次相同 stage address 查詢得到相同結果，底層 ToAddr 只執行 1 次；新 stage 讀到更改後的地址。這證明原生呼叫次數下降，不代表實機 CPU 時間已降多少。

以合成 engine 每 step 固定 1 ms、slice 250 的模型：

| members | 單步 ticks / 推進間等待 | 新排程 ticks / 推進間等待 | 完整 assignments |
|---:|---:|---:|---:|
| 1265 | 6 / 50 ms | 2 / 10 ms | 1265 |
| 12650 | 51 / 500 ms | 13 / 120 ms | 12650 |

這是控制時鐘的排程模型，不是 native 量測。實際單步若仍超過 8 ms，會維持一批/tick；address adapter 能降低的 engine 成本還需要錄影/ContextTiming 確認。

## 下一輪實機測試

匯入 v0.7.1.36 後，在同一 Show 重播 Cue 21→22→23→24，再測前段 Cue 2→3，維持錄影的空 selection。保留 DETAIL 面板，核對 total、scope、engine 累積與 steps/tick；用 GO 到紫框 wall time 判斷速度，不以模型當達標證據。冷啟動與暖重訪分開記錄。

另外確認紫框與 Group 紅框、解析途中換 selection、Recipe 刪除及 NEW CONTENT 沒有退步。若 engine 明顯下降而 scope 成為主因，下一輪針對 scope/index 與 Cue 快照失效；若 engine 仍高且 steps 常為 1，針對純 Lua reverse/unsafe barrier 重建成本，不能只繼續調短 yield。Phaser BUG 依使用者要求延期。

## Deployment

XML and both referenced Lua files copied to the local Update Plugin directory; SHA256 equality verified for all three. Backup: `C:/tmp/update-plugin-pre-0.7.1.36-20260930-124847`. Native validation remains pending.
