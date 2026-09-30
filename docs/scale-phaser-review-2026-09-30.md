# 大型 Show / Phaser 研究審查

日期：2026-09-30。審查對象：`scale-phaser-followup-2026-09-30.md`，對照 `C:/tmp/show-rel` 的 v0.7.1.34。
本次是研究審查與離線探針，沒有修改 runtime、沒有部署，也沒有新增 grandMA3 實測結果。原研究文件保持原樣。

## 判斷與採用順序

有明確優化機會。MUSE 找出的單 slice 排程、PENDING 重掃、Group scope 重複工作都成立；但不能照原文直接實作，尤其「task 重建時重置投影就夠」和「無 PhaserRecipe 的 Phaser 都沒有合法路徑」不成立。

| 順序 | 建議 | 採用條件與預期收益 |
|---|---|---|
| 1 | PENDING 空 selection 立即回傳空投影；固定 selection 用增量投影 | 空 selection 不需要遍歷 assignment。selection 改變時必須重建投影，保留 selectedComplete 的原子發布 gate。減少反覆掃描與字串配置。 |
| 2 | 每個 Group 每次 scope 建置只計算一次 member 數，且只聯集一次 handles | 先利用現有 per-call Group cache，不新增跨 call 失效風險。移除逐 row 的重複排序與聯集；保留原本 fingerprint、stageKey 和 identity 檢查。 |
| 3 | 有時間預算及最大 slices 數的多 slice 推進 | 繼續使用原 slice 上限，所有 native API 在原 plugin coroutine 依序執行。以全 scope 完成為紫框發布條件。這才直接降低 slice 之間的排程等待。 |
| 後續 | Programmer 節流、有界 Cue 快照、快取淘汰策略 | 需各自驗證資料新鮮度和失效條件；不宜與首輪三項一次混改。 |

第一、二項適合先做，容易和原實作對照；第三項影響互動排程，實機必須量最大單 tick 時間。三項都不能承諾大型 Show 一定達到 300 ms。

## 已執行的離線核對

可重現：在工作樹執行 `python -u tools/review_scale_phaser.py`。探針直接取得 production 的 `advanceStagedResolver`，member engine 使用合成 assignments；沒有呼叫 grandMA3 native API，也沒有修改 production 原碼。

slice 大小 250（對應 R=96 的 sliceLimit），空 selection，每 member 一條 assignment：

| members | 推進次數 | 推進之間的 10 ms 等待推導 | PENDING assignment.member 檢查次數 |
|---:|---:|---:|---:|
| 1,265 | 6 | 50 ms | 3,750 |
| 12,650 | 51 | 500 ms | 318,750 |

數量增加 10 倍，PENDING 檢查增加 85 倍；不同 lane 數和 selection 會改變數量。此表是工作量與排程推導，**不是原生效能量測**。原研究的 510 ms 應修為推進之間約 500 ms：第一個 slice 在第一個 tick 就做，最後一個 slice 後先發布框才 yield。另有 Cue 偵測等待、metadata warmup、CPU 與 Pool apply，不包含在表內。

另外已核對：

- 同一 task 的 selection 從 member 1 改成 251，PENDING 投影必須移除 1、改為 251。原 task 仍繼續使用。
- 原測試的無 PhaserRecipe、raw 二步 Preset 可以證明為 moving；同份資料只加 `measure=1`，metadata 被 `ACTIVE_CHANNEL_FIELD_measure` 擋；用新 cache 移除 measure 後恢復。這證明了 gate 機制，沒有證明真實 25.2001 的完整 schema。
- 原 suite：89 workflow assertions、209 Track A checks 通過。
- 擴充探針執行原 fixtures 後：212 Track A checks 通過。
- `python tools/check_parse.py`：兩份 Lua 及 Plugin XML 解析通過。
- `python tools/build_show_candidate.py --check`：生成內容及版本一致性通過。

## 原報告需要修正的地方

1. **增量投影不能只在 task 重建時重置。** `sources()` 在同一 task 上更新 `selectedMembers`，而不是因 selection 改變就重建 task（Inspector 2695–2702）。需以精確 selection key 失效重投影，或以 member 索引作當下投影。append-only 舊 selected 列表會留下舊紅框，也可能漏掉新選到但早已完成的 member。空 selection 的 O(1) 提前返回可以先獨立實作。

2. **Scope 的完整 member signature 已有重用。** `groupKeys()` 回傳 fingerprint signature，`stageSignatures` 的 `groupSignature or table.concat(memberKeys,",")` 通常取前者（2781–2784）。所以並非每 row 都重新串接完整 member key 列表。但每 row 確實重建、排序 memberKeys，只為 count，且每 row 都重跑 handles 聯集（2775–2778）。先將 count 放進 per-call cache，且一個 Group 只聯集一次，比再建立 persistent cache 更直接。跨 call 快取仍須 fingerprint 驗證，省不了該原生讀取。

3. **時間預算是軟界線。** 單一 `GetUIChannels` / `GetPresetData` 是同步呼叫，8 ms 預算不能打斷已開始的 native API 或 slice。須同時設每 tick 最大 slices；計時不可用時回到保守單 slice。原 render 的 selection/programmer/signature 與 scope/indexing 工作也在同 tick，不能只看 engine 8 ms。排程優化應降低 wall time，`engine_total_ms` 未必下降。

4. **無 PhaserRecipe 不等於全無支援。** `ordinary()` 已讀取連續多 steps 並使用 motion bits / step value 差異判定 moving（1731–1816）；既有測試也有這條合法來源。此案應描述為「raw phaser 的非零 measure 被現有 timing gate 拒絕」。`ordinary` 是解析器名稱，不能據此推定資料一定靜態。

5. **Recipe fade 沒有直接讀取點，不等於證明沒有間接影響。** 在引用、Preset raw data、member capability 與可見 Pool 都相同時，resolver 不因 recipe fade 改變輸出。native recook、副作用和快取新鮮度仍須對照；E2 一組不變結果只能排除該 case，不能全域證偽。必須在每次前後比較時清除 metadata/stage 快取或重新啟動 plugin；否則不變可能只是 cache hit。DETAIL/COMPACT 的普通 forceRefresh 會清 metadata cache，但不能讓快取結果充當新 native dump。

6. **新舊 Preset 子物件不同不單獨證明版本差異。** Programmer 儲存與 Phaser Recipe 編寫方式也可能造成結構不同，E1 要記錄建立方式。`GetPresetDataFast` meta 表列出 timing 名稱，可以佐證欄位存在，不能保證每份普通 keyed-table Phaser 都有非零 timing。

7. **Pool 開銷尚不能排除。** 原研究抄錄的快照有 tiles 48 ms，雖不必隨 M 放大，仍占用 300 ms 預算；大型 Show 的可見 Pool 配置也未必相同。只有實測分項能判定主要成本。

## Phaser 的實作機會與必要證據

有機會擴充 raw multi-step / timing 的安全解析，不需要靠名稱猜測，也不應先把 timing gate 整段刪掉。先拿 25.2001 的唯讀完整資料證據：Preset class、bounded children class、pm/selective、UI index、active/cooked masks、所有 relevant timing 欄位的實際型別和值、連續 steps 的 ABS/REL、依賴及 release/remove/integrated 欄位。前 3 個 channel 可用來預覽，不能作完整 lane proof。

這些證據可用來逐欄確認哪些 timing 是獨立於 Feature/ABS/REL 歸屬的有限純量、哪些仍需阻擋。motion 證明沿用 steps/masks；依賴、缺步、混合 lane、未知欄位照樣 fail closed。再以靜態 Preset、普通多步 Phaser、structured Phaser、linked/self-linked、selective cell、unsafe override 對照。修改 runtime template 後須重新生成 Inspector。

先唯讀 dump 便足以決定下一個解析假設，無需先修改使用者 Show。若做 fade A/B，應在 Show 副本中保持其餘因素固定，保存原值並逐次刷新讀取，且區分 marker admission、native playback 與 tile visibility。

原廠文件核對：[GetPresetData 呼叫與 by_fixtures 定義](https://help.malighting.com/grandMA3/2.0/HTML/lua_objectfree_getpresetdata.html)；[2.5 Recipes 功能說明](https://help.malighting.com/grandMA3/2.5/HTML/rn_features-2-5.html)。本機原廠 `system_test_cuepart_recipe_properties.lua` 亦直接測試 StandardRecipe 的 FadeFromX/FadeToX 等屬性。這些文件不取代真實 Show dump。

## 實機驗收

保留 v0.7.1.34 已確認的 grid rediscovery 行為。分開測冷啟動、新 Cue、A→B→A 重訪、空/小/大 selection、解析途中換 selection，並核對最終 refs/classification 和一次發布紫框。Group 修改、Recipe 刪除與 NEW CONTENT 另測失效。收集實際 M/R/D/S、`ContextTiming` 與 Cue-to-purple wall time，才能評估 <=300 ms。

本次完成的是研究可行性審查；效能優化及 Phaser 相容性尚未實作，REAL-WORLD VALIDATION PENDING。
