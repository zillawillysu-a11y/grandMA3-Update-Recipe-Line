# Track A 標記延遲研究：100 ms 冷／暖路徑

研究日期：2026-09-29。研究基準：已由使用者確認內容正確的 v0.7.1.28。
本次只新增研究文件與離線呼叫計數工具，沒有修改或部署 production。

## 結論與證據界線

- 沒有找到已文件化、可直接輸入一批 Fixture/SubFixture 的 UI capability API。不能把這句擴張成「2.5.0.3 絕對沒有」：仍需該實機的 BuildDetails、GetApiDescriptor / GetObjApiDescriptor 核對。
- 有足夠原廠原始碼證據支持 PoolObject + ObjectIndex 對照；可建一對多可見按鈕索引，需處理原生按鈕回收、捲動、View Recall、hidden grid。
- 目前 2.2–4.3 秒不是原生 API 下限的證明。程式存在可重現的重複讀取、交叉比較，以及每 slice 重跑的周邊工作。
- 暖路徑應改為讀取已證明的 Sequence 快照與差異套框；冷路徑仍需量出不可省略的原生讀取成本。不能先承諾全部 cold 操作能在 100 ms 內完成。
- 此研究沒有以 mock 時間宣稱 native 速度，也沒有把正確的 Track A 語意改成近似結果。

## 原生 API 調查

官方來源：

1. [GetUIChannels](https://help.malighting.com/grandMA3/2.1/HTML/lua_objectfree_getuichannels.html)：單一 (sub)fixture index 或 handle；true 回傳 channel handles，false 回傳數值 indexes。未列出 member list / Group 批次 overload。
2. [GetUIChannelIndex](https://help.malighting.com/grandMA3/2.1/HTML/lua_objectfree_getuichannelindex.html)：Fixture patch index + Attribute index 的單對查詢，不是批次列舉。不能只查一個 Attribute 就代表完整 FeatureGroup，也不能把未知回傳當成能力不存在。
3. [GetApiDescriptor](https://help.malighting.com/grandMA3/2.0/HTML/lua_objectfree_getapidescriptor.html)：回傳原生函式的名稱、參數、回傳型態。實機只需擷取 channel / fixture / pool / hook 相關項目，無須 dump 整個 Show。
4. [HookObjectChange](https://help.malighting.com/grandMA3/2.1/HTML/lua_objectfree_hookobjectchange.html)：可監看物件變更；文件沒有保證所有 descendant、Selection、playback Cue 或 UI recycle 事件的覆蓋。必須測試 callback 覆蓋才能依賴它失效快取。
5. [GetButton](https://help.malighting.com/grandMA3/2.3/HTML/lua_objectfree_getbutton.html)：硬體 MA3Module 按鍵狀態，並非 Pool tile 查找捷徑。

版本注意：線上部分 /2.5/ Lua URL 實際顯示較舊版本頁面；以上引用明列可取得的版本。不能只憑 URL 宣稱 2.5.0.3 執行行為已證實。

另外直接讀取本機 MA 安裝檔案，沒有執行會修改 Show 的 system tests：

根目錄：`C:/ProgramData/MALightingTechnology/gma3_2.5.0/shared/resource/lib_plugins/systemtests/`

- `help/system_test_helping_functions_db.lua:2263`：原廠逐一 `GetUIChannel(i)`（0 至 GetUIChannelCount()-1），使用回傳的 `sf_index` 與 `logical_channel.attribute`。可作為全 Patch 建索引的候選，但仍是每 channel 一次呼叫，對大量未使用 Patch 可能更慢；不是一次批次快照。
- `db/system_test_api_tests.lua`：有 GetUIChannel(index)，以及 SubFixture + Attribute 形式的測試。未證實可取代完整 capability 枚舉。
- `ui/uitf/wrappers/system_test_uitf_wrappers_pool.lua`：GetTarget 使用 PoolObject；FindVisibleButtonForIndex 遍歷 UIChildren 比較 ObjectIndex；是否空 tile 使用 PoolObject:Ptr(ObjectIndex)。
- `ui/system_test_ui_pool_layout_grid_scrolling.lua`：PoolColumnsCount、ScrollV，以及捲動後相同位置的按鈕 ObjectIndex 改變。不可把 button handle 永遠綁到第一次的 Pool object。
- `lib_menus/ui/window_sheet/window_content_sheet.lua`（相對 shared/resource）：MA 原廠對 scroller 使用 HookObjectChange。這是可用性線索，不是所有 Pool 事件皆被通知的保證。

### 候選 capability 路徑的安全比較

A. 保留目前 GetUIChannels(handle,true)，把已驗證的 member capability 保留到 Patch / Attribute 定義變更為止。

B. A/B 測 `GetUIChannels(handle,false)`：逐 member 驗證其完整 index 集合等於 true 模式的 INDEX-1；再比較同一 GetAttributeByUIChannel -> Feature -> FeatureGroup 結果。成功才採用，可減少 UIChannel handle 屬性存取。数值模式不可再盲目減 1。

C. 全 Patch GetUIChannel(i) 索引：必須對全部 1,295 個案例比對 canonical member、全部 UI-index、Attribute、FeatureGroup；缺項、重複歸屬、nil、parent/child 混淆均失敗。量測全 Patch channel 數與成本，只有確實有利才選。

D. 額外共用 Attribute handle -> FeatureGroup 的 memo，避免不同 UI channel 重走相同 Feature/Parent。仍保留每 member 的真實 UI ownership；Selective 不能退化成 FG boolean。

任何新路徑都保留 ToAddr 嚴格 dotted identity + unique ObjectList round trip。sf_index 只能作原生 API 的暫時查詢鍵，不是 canonical identity。不能憑 FixtureType 相同共享能力，也不能由名稱推定。

## 已確認的程式工作放大

定位於 `RecipeTracking_Inspector.lua` 與 `tools/templates/show_track_a_runtime.lua`（請以函式名定位，行號可能變動）：

| 路徑 | 現有行為 | 後果 |
|---|---|---|
| render 的空 selection 分支 | 每次都設 poolMarkersDirty=true | 即使 selection 從未改變，也繞過 0.5 秒 Pool lookup 節流 |
| refreshPoolMarkers / sameReference | address 未命中的每個 tile 與所有 references 比較，失敗時逐一嘗試多種原生 identity | 最壞 O(可見按鈕數 × refs)，包含所有未標記 tile；不限 Generator |
| groupKeys | 先逐 member GetSubfixture/ToAddr 並排序，之後才檢查快取 | 暖命中仍有全 Group 原生呼叫 |
| completeGroups / relation | Group Pool 多個候選重建 selection canonical keys | 換 selection 時重複 ToAddr/ObjectList；須保持原有 Group admission 結果 |
| sources | scope 及 stage signature 建立之後才檢查 stage cache | 暖結果仍支付 77–95 ms 的 scope 成本 |
| advanceStagedResolver / runtime.run | 每 32 members 呼叫 run，重走 rows/groupMembers 交集 | 1,295 members 至少 41 批；相同 row 範圍重複準備 |
| main/render | 每個 pending resume 仍跑 panel、programmer、signature、Pool 等工作 | elapsed 包含大量非 engine 工作及 host yield |
| readProgrammer | 每 render 檢查 selected members 的 channels/GetProgPhaser；較後才按 feature 篩選 | 即使 resolver/UI channel cache 暖，仍有選取數量相關成本 |
| trackingStructureKey | 定期讀 Cue/Part/Recipe 結構與 links | 快取失效檢查本身也有成本，不能稱為免費 |
| main idle polling | 正常間隔 100 ms，再加處理及繪製 | 無法保證最壞端到端 <=100 ms |

### 可重現離線呼叫計數

工具：`uv run --with lupa python tools/research_marker_call_counts.py`。
透過 debug upvalues 呼叫未修改的 production closures；所有 native API 用計數 mock，無 native 時間結論。

200 個可見 tile、13 refs、13 命中：

| 情境 | CompareHandle | HandleToInt | HandleToStr | ToAddr | AddrNative | Ptr | Append |
|---|---:|---:|---:|---:|---:|---:|---:|
| 初次掃描 | 2431 | 4862 | 4862 | 5075 | 4862 | 200 | 13 |
| deadline 前、不 dirty | 0 | 0 | 0 | 0 | 0 | 13 | 0 |
| deadline 前、dirty | 2431 | 4862 | 4862 | 5075 | 4862 | 213 | 0 |
| identity 索引示意模型 | 0 | 213 | 0 | 0 | 0 | 200 | 不繪製 |

最後一列只驗證合成資料的相同 13 筆對照，不是 native alias / collision 證明或 production 替代實作。

1,295-member Group 的第二次快取命中：仍有 GetSubfixture=1295、ToAddr=1295；省掉的是 ObjectList，不是全部 member 讀取。兩次返回相同 keys 物件且 cache-hit counter=1。

## 保留語意的架構方案

### 1. 長存的資料索引與明確失效範圍

建立版本代號：Show/Patch、Attribute 定義、Group selection、reference/linked-reference、selected Sequence Recipe graph、可見 Pool view。它們是 plugin 自己追蹤的 generation，不能冒稱原生 revision。

- canonical identity/原生 handle/完整 UI ownership：只在其有效 epoch 內使用。
- Group canonical members、member -> Groups：在真正 Group/Patch 變更才重建。
- per-reference metadata 及 linked Preset dependencies：原規則不動；只有相應來源失效才重讀。
- normalized Recipe rows、member -> 按時間排序的 rows：只建立一次，不每 slice 重走 Group 範圍。
- Cue 快照保存 final lanes、source groups、已證明 refs、unsafe attribution/REL blockers。設定 LRU/記憶體上限；容量不足造成 cold miss 必須如實計入，不可假定整場可无限快取。

原生 hooks 只更新 dirty/generation，不在 callback 執行重解析；先驗證 Recipe insert/delete/Enabled/Values/Selection、Group store、Preset/linked Preset edit、Patch edit、Show reload、選擇 Sequence、Cue jump 的覆蓋。
沒有證明 notification 完整的依賴仍要驗證 fingerprint；若驗證使 100 ms 超標，該變更情境就尚未達標，不能悄悄取消驗證。背景 audit 只能補漏，不能把發現前的 stale 結果稱為正確。

### 2. Cue 与 Selection 分離

紫框只看 SelectedSequence 及其當前 Cue 的 Recipe history，不讀其他 Sequence 的輸出競爭。

- selection：canonical member keys -> 已證明的 member/lane assignments -> 原有 selected Group/ref 投影。stage 紫框快照不失效；不跑完整 resolver、不掃整個 Group Pool、不重讀 reference metadata。
- 已快取 Cue：先驗依賴 epoch，再直接取快照，按 refs 差集套框。
- 未快取 Cue：在預編譯 history 索引中，只重算受影響 member；對該 member 重跑完整相關 history 與 wildcard barriers。沿用同一 Track A reverse engine，保留 static kill、Selective ownership、unsafe victim attribution、ABS/REL 與獨立已證明 lane 發布規則。
- 不可只 append 新 refs 或從舊 final set 刪 ref：舊 unsafe rows / victims 會影響可證明性。
- Cue/selection generation 改變後，舊任务不可發布晚到結果；新紫框快照完整後一次提交，不逐 member 慢慢補亮。
- Programmer/UPDATE 的 expensive 檢查與標記快路徑拆開；未確認新鮮狀態時 UPDATE fail closed，按下動作前再驗證，不可用陳舊 programmer data 授權寫入。

### 3. Pool 索引與差異繪製

索引：`(native Pool identity, ObjectIndex) -> visible button entries[]`，同物件可出現在多 display/grid。另建 native target identity -> reference alias 表，保留 Generator 的 alias fallback、碰撞 fail closed。

- 初次可見 grid 掃描一次建立索引；未命中先按 pool/identity 查表，不掃所有 refs。
- 穩定 view 的 selection/Cue 更新只處理 refs 的新增、刪除、紅/紫色變更；不重寫相同 W/H/Text/BackColor。
- scroll/resize/columns/PoolObject/Recall View 使 view generation 失效；驗證目標按鈕 ObjectIndex 與 Pool:Ptr，清除被回收或 hidden 的標記。
- 對已標記 tile 保留低成本驗證。對新 target，如果 hook 覆蓋未證實，需 O(visible buttons) 的 numeric ObjectIndex audit；不能宣稱 O(delta) 同時省掉 recycle 檢查。
- 不能監看 overlay 自己引起無窮 dirty loop。close/reload 必須 Unhook，清除本 plugin 的所有 frame，保留既有 restart cleanup。
- grid discovery 保留 bounded 與 hidden-grid rejection；不啟用舊 cue-wide cooked scanner。

### 4. 呼叫與排程

即時 loop 只處理輕量 selection/Cue generation、快照投影、必要 tile 更新；量測後選事件通知或約 10–20 ms 的輕量 polling。
這是設計候選，不是已證明的 native 排程保證。不要把整個現有 render loop 直接提速。
所有 native API 留在現有安全主執行上下文；不用 nested coroutine、額外 thread 或 realtime lock 包住大量讀取。

## 冷／暖驗證與 100 ms 驗收

### 必須分開的時間

`t0` 使用者輸入/host context 改變；`t1` plugin 偵測；`t2` 能力與 metadata 已備妥；`t3` 完整結果完成；`t4` 最後一個必要 overlay native 寫入完成；`t5` 畫面真正呈現。

驗收是 t5-t0，不是 t4-t1，也不是最短單次 resolver_slice。使用 native Time 計 wall-clock；os.clock 回退只可當 CPU 參考。
現有 resolver_total 含 yield 及周邊工作；tile_apply 含掃描、matching、建立與寫入。新增獨立累計：

- 每種 native API 次數與總時間：GetUIChannels、INDEX、Attribute/Feature/Parent、ToAddr/ObjectList、Group.Selection、GetPresetData、Ptr、UIChildren、Append、UI property writes。
- scope/normalization/reverse-engine CPU、programmer、signature、identity matching、Pool discovery、yield wall gap 各自分開。
- 固定樣本一次結束才輸出統計，不逐 channel/tick logging；量測 instrumentation 本身的額外成本。

實機矩陣（每種記 p50/p95/p99/max、cold/warm、call counts、正確性差集）：

| 案例 | 清空/保留狀態 | 預期驗證 |
|---|---|---|
| 真 cold 啟動 | plugin caches 全空，43 rows / 1295 members；記錄 host 是否剛載 Show | 包含身分、metadata、能力、首次 tile index/Append 的完整時間 |
| cold 新 Cue | 已暖部分資料，但目的 Cue 尚無快照 | 不能當 cached Cue 報告；最壞全部 member 受影響 |
| warm Cue revisit | 所有依賴 epoch 有效 | 應無 capability/reference 原生重讀；frame 差異發布 |
| warm selection | 空、1、2、210、1295；含 parent/child/nested Cell | 無 full stage resolve；部分 Group context、紅框與紫框均與基準一致 |
| view 改變 | scroll、resize、Recall、同物件多個 Pool | button recycle、hidden grid、alias、frame cleanup |
| 語意變更 | Recipe 新增/刪除/NEW CONTENT、Group、Preset、linked Preset、Patch | 完整失效；不能利用 stale cache 達標 |
| 連續動作 | Cue/selection 在計算期間再次改變 | 丟棄舊 generation，無晚到殘框 |
| 切 Sequence | 另一個 selected Sequence | 清除舊 scope；其他 playback 不污染結果 |

固定 Show/硬體至少各 100 次，保留首訪樣本而非只取暖態。可用 120/240 fps 螢幕錄影或外部 camera 對齊輸入與最後框呈現；只有 60 fps 時標註約一個 frame 的量測不確定性。以最大值 <=100 ms 驗收，不只平均值。

每次比較基準 v0.7.1.28 的完整 assignment/member/FG/layer、proven refs、selected refs、Group set、unsafe attribution，不只比較 final refs 數量。原本 9003/9006/2.14 個案與 4-ref 合成 fixture 都必須保留。

暖路徑可先設工程預算：偵測 <=20 ms，selection/快照投影 <=20 ms，差異套框 <=30 ms，呈現及餘裕 <=30 ms。這些是預算，不是現有量測結果；原生單次 selection read/Append 若超過預算仍須報失敗。

## 什麼時候才可認定 cold 受平台限制

先測最小且正確的必要 native 讀取迴圈，排除 panel、重複 identity、Pool 交叉掃描、固定 slice 等待。如果這個下限本身已 >100 ms，才能對這個硬體/Show/API 路徑說 cold 無法達標。

算術約束：1,295 members 即使把全部 100 ms 留給一次/member capability 呼叫，平均也只有約 77.2 微秒，還未算 channel/identity/metadata/UI；這不是量測，也不能單憑此斷言不可能。

若冷下限超標：

1. 常駐 compiler 在演出準備時预建 selected Sequence 的 member/metadata/Cue 快照，UI 開窗與正式操作只用已驗證暖快取。首次準備時間另列；不能把它包裝成 cold <=100 ms。
2. 在同一個長存 plugin 內保持服務及 UI 分離；跨 plugin 的 Lua state/快取共享不可先假設可用。
3. 若需落盤 cache，必須有完整依賴版本驗證；Show 名稱、fixture 數、sf_index 都不夠，native handles 不可跨載入序列化使用。沒有可靠 revision 時先限同次 Show session 的記憶體快取。
4. 若要求「真正全冷、任意 Patch/Recipe 修改後也 <=100 ms」，而必要讀取下限超標，才需要 MA 提供一致性批次 capability snapshot/變更 revision/批次 UI 更新等原生支援。未文件化 C++ hook、DLL 或 realtime lock 不是安全替代品。

## 實作優先序

1. 先修 Pool 交叉 identity 掃描、空 selection 重複 dirty、無變更 UI writes，做 marker mapping 等價測試與 recycle/Recall regression。
2. scope/group/selection 身分索引；把 stage cache 判斷移到真正的依賴驗證後、scope rebuild 前。
3. 加精準 native profile 與 numeric-channel A/B；驗證 hook 失效覆蓋。
4. 預編譯 per-member history、暖 Cue 快照與 selection 投影；保留既有 engine。
5. 實機 cold/warm 量測後才承諾可達的 <=100 ms 範圍。若 cold 超標，採準備期預熱並誠實標示未滿足 cold 目標。

## 本次驗證結果

- 呼叫計數工具在 Lua 5.4 通過；其載入的 production 原始檔未修改。
- 現有 workflow suite：88 assertions 通過。
- 額外嘗試直接執行現有 show_candidate.lua：Lua 5.4 在第 1155 行解析失敗，訊息為 too many local variables (limit is 200)。該檔與 HEAD 無差異，這是本次發現的既有測試入口限制，不能宣稱本次 candidate suite 全綠；後續實作前須先整理測試區塊 scope，再補效能／失效測試。
- production Lua/XML 與部署檔案 SHA256 相同；這只確認研究未改動已部署版本，並非新效能驗收。
- 研究檔案與 HANDOFF 執行 git diff --check；不進行 production 部署。

## 2026-09-29 follow-up: staged member rescans

The user's v0.7.1.29 video feedback says markers remain correct but loading
still takes particularly long. The video starts with the resolver already
PROVEN, so it does not expose the transition duration. Source inspection found
a repeat cost in newTrackARuntime.run: each 32-member staged slice iterated
every member in each Recipe's stored Group and filtered against that slice.
With 43 rows, a shared 1,295-member Group, and 41 slices, that is about
2.28 million membership probes, despite only 56,416 row/member candidates
belonging to the current slices.

v0.7.1.30 adds a slice-only membership path that iterates the current slice
and tests membership in each row's Group. The full unsliced path retains its
existing Group-driven loop, which is better for small Groups. This reduces the
identified redundant checks by roughly 40x for the observed workload shape.
That figure is a source-derived operation count, not a measured grandMA3
speedup; console timing and marker equivalence remain to be validated.

## 2026-09-29 adaptive slice direction

Review before console validation found that always iterating the active slice
could cost more than iterating a small Recipe Group. v0.7.1.31 records each
row's canonical Group member count once and chooses the smaller side for each
staged slice: slice-driven lookup for larger Groups, Group-driven lookup for
Groups smaller than the active slice. The unsliced path stays unchanged.

For the 43-row / 1,295-member shared-Group shape, expected membership probes
fall from 2,283,085 to 55,685. For Groups smaller than a slice, the prior
Group-driven loop is retained. These remain source-derived counts; console
latency and marker behavior still require real-world validation.

## 2026-09-29 follow-up: v0.7.1.31 timing and batching

The user's v0.7.1.31 video shows Cue 11 completing with 123 Recipe rows,
1,265 members, and 2,699.3 ms resolver total. The last displayed slice was
16.5 ms, scope was 111.1 ms, signature 18.5 ms, and the last Pool tile pass
46.1 ms. These are different scopes: the video does not report cumulative
metadata or member-UI time, and the tile figure is one scan, so it cannot be
multiplied across every resolver slice.

v0.7.1.32 raises metadata batches from 4 to 8 rows and member batches from
32 to 128, targeting fewer 10 ms pending yields while keeping a reverse batch
near the accepted 100-200 ms response budget. Recipe-structure polling backs
off to 500 ms only while a resolver task is pending; Sequence/Cue changes
still trigger immediate checks. Cumulative metadata, member-UI, and engine
times are now displayed and logged. These are unmeasured tuning changes; the
next grandMA3 run must verify latency and marker equivalence.

## 2026-09-29 follow-up: v0.7.1.32 console timing and v0.7.1.33 candidate

The user's v0.7.1.32 video ends at Cue 8 with PROVEN, 13 refs, and 2 selected
frames. The expanded panel reports 2,100.4 ms resolver total, 96/96 rows,
1,265 members, cumulative engine work of 608.8 ms, metadata 0 ms, and member
UI 0 ms. The final displayed scope was 96.4 ms, the current engine slice was
47.0 ms, and one Pool tile pass was 33.2 ms. The user reports some improvement
but confirms the 200 ms target is still not met. The 608.8 ms engine sum is
not the same scope as the 2,100.4 ms end-to-end elapsed time.

v0.7.1.33 adds a one-time member-to-row index for sparse Recipe Groups across
staged slices. Dense rows retain the prior adaptive Group/slice traversal.
The estimated row/member work per reverse slice is capped at 24,000, with a
maximum of 256 members; the batch limit shrinks as Recipe row count grows.
Selected members remain first in the ordered member list. When the final
metadata slice reaches the last row, the same refresh now continues into lane
resolution instead of yielding an empty extra cycle.

Local validation passed: candidate generation check, Lua/XML parsing, 88
workflow assertions, and 209 Track A candidate checks, including baseline vs
indexed-path equality for safe moving refs and member/lane ownership. This optimization has
not yet been measured on-console; the 100-200 ms user target remains open.

## 2026-09-30 follow-up: v0.7.1.33 Pool marker regression

The user's v0.7.1.33 video shows Cue 4 as PROVEN with 13 refs but only 4/13
Pool overlays. The first reported miss is `Preset 1.1 @ VISIBLE_POOL_TILE_NOT_FOUND`,
and the user reports that purple frames for Pool 9001–9012 no longer appear.
The visible Pool row and resolver references are both present in the video.

Inspection found that Sequence/Cue changes and changed marker references only
marked overlays dirty. The discovery path reused cached `PoolLayoutGrid`
handles while they remained valid and visible, so a newly opened/switched Pool
could be omitted. v0.7.1.34 marks the visible-grid list for rediscovery on both
stage-context changes and final marker-reference changes. The bounded display
tree walk remains in place.

Local validation passes with 89 workflow assertions, 209 Track A candidate
checks, Lua/XML parsing, candidate generation consistency, and `git diff
--check`. v0.7.1.34 was deployed to the grandMA3 plugin directory and all
three source/deployed SHA256 pairs match. Backup:
`C:/tmp/update-plugin-pre-0.7.1.34-20260930-001236`. The stale-grid explanation
remains a source-supported hypothesis pending on-console confirmation. The
100–200 ms latency target also remains open.
