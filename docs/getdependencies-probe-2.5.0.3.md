# Cue / Part GetDependencies read-only probe — grandMA3 2.5.0.3

## 結論

**SUITABLE FOR CANDIDATE DISCOVERY**（直接／結構性引用）。

**NOT SUITABLE FOR FINAL ACTIVE/TRACKING REFERENCES**。

使用者已完成 grandMA3 **2.5.0.3** native 測試：直接 Recipe 的 Cue/Part graph 有 Preset、StandardRecipe、Group；Sequence 14 Cue 2 tracks Cue 1 時，Cue 與 Part 0 graph 都只有 root node，沒有 dependency edges。已知 tracked Preset **1.11** 與 previous Recipe 沒有回傳。

因此 GetDependencies 是 structural/database dependency API，不能作完整 playback provenance，也不能代替目前 tracking 掃描。候選探索結論限於直接／結構性引用，**不保證包含所有 inherited candidates**。production 不變。

## Native evidence — 2.5.0.3

來源為本次使用者實機回報；沒有完整原始 logs、repeat count 或分布，以下是使用者提供的近似值，不是代理重測或普遍 latency 保證。

| Scope | Observation | Cold | Warm |
|---|---|---|---|
| Direct Recipe Cue/Part | 直接 Preset、StandardRecipe、Group | 未另提供 | 未另提供 |
| Sequence 14 Cue 2 | tracks Cue 1；nodes=1、edges=0；missing Preset 1.11 / previous Recipe | 未綁定 case | 未綁定 case |
| Sequence 14 Cue 2 Part 0 | nodes=1、edges=0；missing Preset 1.11 / previous Recipe | 未綁定 case | 未綁定 case |
| Cue read timing（case 未指定） | 使用者回報 native 讀取時間 | ~0.063 ms | ~0.025 ms |
| Part read timing（case 未指定） | 使用者回報 native 讀取時間 | ~0.022 ms | ~0.019 ms |

nodes=1 是 probe 加入的 root，不是 API 回傳了 Cue/Part 本身。edges=0 表示沒有 dependency entries。此 inherited counterexample 已足以排除完整 final active/tracking 用途。其餘 override/release/disabled 等 native cases 未另提供結果，不補造紀錄。cold/warm 標籤保留使用者量測；下方 native cache coldness 與 clock 精度限制仍適用。原始 probe log 中固定 PARTIAL ONLY 字樣是初始標籤，此文件的新結論優先。

## 檔案與範圍

- [獨立 probe](../diagnostics/GetDependencies_Probe_2_5_0_3.lua)：讀取 selected Sequence、Current Cue、Part 與 Recipe 的獨立 dependency graphs，回傳 Lua report 並使用 `[GDProbe]` 記錄。
- [離線案例](../tests/getdependencies_probe.lua) 與 [runner](../tools/run_getdependencies_probe.py)：mock graphs 與失敗防護；沒有連接 grandMA3。
- Production `RecipeTracking_Inspector.lua`、`RecipeUpdate_Diagnostic.lua`、manifest、版本、紫框邏輯與 GetPresetData implementation 不變；未建立 production replacement。
- 已依後續部署要求提供 [獨立測試 Plugin XML](../diagnostics/getdependencies_probe_2_5_0_3.xml)。probe 本身不寫入 Plugin Pool；可由操作者匯入測試 Plugin 或從外部 Lua 檔載入。不執行 Cmd、Cook、Assign、Store、Go、Goto、Release、Clear、Off 或 selection/Programmer APIs；不註冊 hooks，不建立 UI，不改 Sequence、Cue、Recipe、Programmer 或 playback 狀態。
- probe 不呼叫 `GetPresetData()` 或 `GetPresetDataFast()`。native reads 全在呼叫者的 host 執行流程，沒有 nested coroutine。
- 禁止以 probe 自動建立測試 Show 或切換 Cue。測試用 Show 與 playback 操作由操作者準備；probe 只觀察。

## 技術依據與未驗證事項

主要依據為共用 Reference commit `63600a7563bb53a8525da692a8d0cdcea1540b9c` 下的 [2.5.0.3 functions dump](../.reference/ma3/DiDiDo-MA3-Developer-Reference/01_API_Dump/MA3_2.5.0.3/grandMA3_lua_functions.json)：

- `object.GetDependencies(handle)` 回傳 handles table；`object.Children/Parent/FindParent/ToAddr/AddrNative/Get/GetClass/Index` 提供物件讀取與描述。
- `objectfree.CompareHandle(h1,h2)` 回傳 boolean；不能用顯示地址字串替代 identity。
- `BuildDetails()` 可讀 build table；[version dump](../.reference/ma3/DiDiDo-MA3-Developer-Reference/01_API_Dump/MA3_2.5.0.3/grandMA3_version.json) 的 `BigVersion` 為 `2.5.0.3`。probe 必須吻合此完整值，不能只看 `Version()` 的 `2.5`。
- 官方 [GetDependencies 說明](https://help.malighting.com/grandMA3/2.5/HTML/lua_object_getdependencies.html) 說明的是物件 dependencies，沒有 active playback contract；該頁內容標示 Version 2.2，不是 2.5 專屬行為保證。
- 本機 vendor `C:/ProgramData/MALightingTechnology/gma3_2.5.0/shared/resource/lib_plugins/systemtests/db/system_test_listref.lua:28–45` 證明 Sequence→Preset dependencies 與 Preset→Cue Part references 的方向；沒有證明完整 Current Cue active set。
- 同版 `systemtests/help/system_test_helping_functions_db.lua:1926–1929,2281–2300` 用 `Time()` 計秒與 duration。本 probe 依此換算為 ms；dump 僅宣告 integer time，所以實際 clock 精度仍需觀察。沒有 Time 時輸出 `UNAVAILABLE`，不捏造 0 ms。

上述 MA system tests 在本輪只讀取其程式碼，沒有執行。沒有 API 證據可保證 GetDependencies 有 channel-independent 複雜度；它是 native synchronous call，Lua 工作上限不能中斷正在執行的單次 native read。

## Graph 結構與記錄規則

每個 root 有獨立 `cold` 與 `warm` graph：

- `current:cue`：只沿目前 Cue 的 GetDependencies edges。
- `current:part:0`、`current:part:1` 等：每個 Part 自己的 graph。
- `current:part:0:recipe:1` 等：Part 的 Recipe child，序號為 Children ordinal，**不是承諾原生 Recipe command index**。
- `history:1:cue`、`history:1:part:0` 等：僅讀取設定中明列的 earlier Cue；要求相同 selected Sequence、Cue.No 小於 Current Cue。沒有自動掃描全部歷史 Cues。

`CONTAINMENT` 紀錄 Cue→Part→Recipe，不混入 dependency edges。每條 `EDGE` 保留 from/to node ID 與原回傳 slot；共同引用、重複 slot、cycle 都保留。以 CompareHandle 去重 node；每個 unique node 的 GetDependencies 在單一 graph pass 讀一次。這是重複呼叫 API 所觀察的有向 graph，**不宣稱單次 API 的回傳是一份完整 transitive closure，也不宣稱物件樹的 child 就是 dependency**。

API contract 是 handles table。若回傳巢狀 Lua table、非 table、invalid handle、CompareHandle 失敗，記錄 incomplete，不 flatten 猜測。正常空 table 可作 empty graph；nil/error 不等同正常空集合。

Preset / Random / Generator / GeneratorRandom 分類為 Pool candidates；PhaserRecipe 是 `recipe_structure`，Shape/ValueSource 等保留為其他 dependency。不能把外層 Recipe 所引用的 Phaser Preset、內層 Shape、step Preset 當成同一來源。未知 class 一律保留原資料，candidate classifier 並非完整 MA class schema。

每個 root/node 記錄 Cue/Part scope、class、command address、native address、handle 字串、index、parent address/class、DataPool ancestor、CompareHandle self-check，以及是否匹配已知 reference。**parent 欄位是直接 parent，通常才是 Preset/Generator pool；pool 欄位是 DataPool ancestor**。無法解析的 metadata 明確標 unavailable，不拼造 object paths。

範圍上限：每 graph 128 nodes、256 edges、depth 6、8,000 traversal work；每 capture 24 roots、單層 128 children、最多 8 earlier Cues、每個 expected/excluded list 64 項；read wrapper 合計 25,000 API/受保護讀取 calls。超限或 cold/warm graph 改變時不能把結果視為完整 reference 集合。這些是保護性上限，不是 native latency 承諾。

## 執行方式與 ground truth

### 獨立測試 Plugin 部署

部署位置：`C:\ProgramData\MALightingTechnology\gma3_library\datapools\plugins\GetDependencies Probe 2.5.0.3`。只有 XML 與其 referenced Lua；正式 `Update Plugin` 資料夾不變。

在 grandMA3 Plugin Pool 的空白位置開啟 Import，選擇 Internal 儲存來源，進入 `GetDependencies Probe 2.5.0.3` 資料夾，匯入 `getdependencies_probe_2_5_0_3.xml`。匯入後名稱為 **GetDependencies Probe 2.5.0.3**。選好要觀察的 Sequence／Current Cue 後，按這個測試 Plugin；無參數或空參數預設執行 `direct_recipe`，只讀目前物件，不會自行切換 Cue。檔案部署不等於已匯入 Show 的 Plugin Pool。

在 **Command Line History** 查看 `[GDProbe]`；也可開啟 **System Monitor** 查 Lua error。複製完整 `[GDProbe] CASE=...` 至 `[GDProbe] END...` 區段，保留 NODE／EDGE／CHECK／ERROR 行。未填對照仍為 `UNVERIFIED`；出現 logs 不是 active-reference suitability 已通過。

部署驗證：XML parse、Lua parse、所有 ComponentLua 檔案存在、source/deployed SHA256 一致；production source與正式部署目錄另行比對保持不變。native 匯入／執行與 graph 結果仍待使用者實測。

### 外部 Lua 檔方式

Windows onPC 2.5.0.3 可在 Command Line 使用 Lua 載入外部檔案；本 repo 路徑如下。此命令不匯入 Plugin Pool：

```text
Lua "local f=assert(loadfile([[C:/Users/willy/Downloads/Update-Recipe-Line/grandMA3-Update-Recipe-Line/diagnostics/GetDependencies_Probe_2_5_0_3.lua]])); f()(nil, 'direct_recipe')"
```

這份 launch command 尚未在 native host 實測；若 host 禁止外部 loadfile 或路徑不可用，應回報錯誤，不自行改裝成 production Plugin。先在獨立測試環境使用；本輪沒有透過 OS 控制執行它。

probe 頂端 `CASES` 可填入既有 Show 的對照；修改的是 diagnostic 設定，不是 production code。也可對 `f()(nil, config_table)` 傳入設定，供離線 runner 或手動 Lua 使用。

```lua
-- 用實際地址替換下列示例；以下不是 native 測試結果。
CASES.inherited_recipe = {
    history_cues = {"Sequence 1 Cue 1"},
    expectations = {
        ["current:cue"] = {
            expected = {"Preset 25.303"}, excluded = {}, exhaustive = true
        },
        ["current:part:0"] = {
            expected = {"Preset 25.303"}, excluded = {}, exhaustive = true
        }
    }
}
```

每個 root 的 expected/excluded 都要**獨立**確認，不可把 Cue-wide truth 直接複製到所有 Parts。`expected` 是當前測試 scope 應 active 的 references；`excluded` 是已知被覆蓋、release 或 disabled 後不應 active 的 references。`exhaustive=true` 表示操作者確認 expected 為此 scope 的完整 Pool-reference 集合，其他 Pool candidates 才可判 false positive；沒有 exhaustive 則只列 unclassified。

每個地址必須由 ObjectList 唯一解析；解析失敗為 `INVALID_GROUND_TRUTH`，不是 API missing。匹配僅使用 CompareHandle。沒有 expectations 時為 `UNVERIFIED`，missing/false-positive counts 顯示 unavailable；即使 graph 為空也不宣告成功。只有明確 `expected={}`, `excluded={}`, `exhaustive=true` 才是已知 empty truth。

false positive / missing 是**相對於操作者提供的 active ground truth**，不是 probe 自己理解 tracking 的結論。結構性 Shape/PhaserRecipe 等節點會記錄，但不自動視為錯誤 Pool references；若操作者要檢查某個結構節點，可明列 expected/excluded。

## 十種案例與比較目的

| Case ID | 操作者準備／已知 truth | Probe 必須比較 | 本輪 native 結果 |
|---|---|---|---|
| direct_recipe | Current Cue Part enabled StandardRecipe 明確引用 A | Cue、Part、Recipe graph 能否找到同一 A | OBSERVED：Preset / StandardRecipe / Group |
| inherited_recipe | Earlier Cue 引用 A；Current Cue 對該 lane 無新資料且應繼承 A | current graph 是否含 A；earlier graph 的 A 不可自行補進 current 結果 | OBSERVED：Cue/Part 未含 inherited Preset 1.11 / previous Recipe |
| static_override | earlier Phaser/Generator A；current static B 覆蓋同 fixtures/attribute/layer | B 應存在；A 若仍出現，對 active-set 需求為 false positive | NOT RUN |
| release | 同 lane earlier A；Current Cue 已 release，active truth 不含 A | graph 是否保留 A；與 inherited baseline 比較 | NOT RUN |
| disabled_recipe | Recipe ingredient 仍指 A，但 Enabled=No，無其他 lane 使用 A | ingredients 有 A 不代表 active；dependency 保留 A 是否造成誤報 | NOT RUN |
| phaser_recipe | 外層 Preset A 含 PhaserRecipe/Shape/step Presets | 保留 graph layers；確認外層 A，不以 Shape/step Preset 冒充 A | NOT RUN |
| generator_random | 已知 Generator/Random A；Recipe 與 Pool 地址可能不同 | CompareHandle 與 known A；native parent/Pool metadata | NOT RUN |
| multi_part | Part 0 使用 A、Part 1 使用 B，各自 truth 不同 | 每 Part graph 分離，Cue graph 是否為 union、是否含額外 refs | NOT RUN |
| empty_part | 正常空 Part；或只含無相關 Pool reference 的內容 | 空 table 與 API failure 區分；unknown/structural deps 不自動判 active | NOT RUN |
| duplicate_reference | 相同 A 經多 Recipe/多 edges 出現 | 保留每條 edge、CompareHandle 去重 nodes；A 只匹配一次 | NOT RUN |

至少將 direct→inherited→override→release 置於同一已知 fixture/attribute/layer 的測試軌跡。跨 Part 或 abs/rel 的內容不能誤判相互覆蓋；release 與 disabled 的 negative truth 需排除其他仍使用 A 的 lane。操作者先確認畫面/既有已驗證 reference，不以 probe 輸出本身當 ground truth。

## Cold / warm 與結果讀法

每個 root 先讀一次完整 bounded graph，再讀第二次；讀取時間與個別 GetDependencies 時間都用 Time 記錄。文字 metadata、ObjectList ground truth 與 Printf 輸出在 graph 計時之外；graph 時間包含 traversal、identity comparison 與 class/validity reads，不只是 GetDependencies。

`cold` 精確含義是 **first probe pass**，不是已證明的 native cache miss。相同物件可能早已被 MA/UI、另一 root、先前執行或 playback 暖過；probe 不清 native cache、不重載 Show。`warm` 是立即重讀，沒有 Lua dependency-result cache。取得真正首次訪問與 cached revisit 的外部 wall-clock比較，仍需在 native 測試流程另行記錄。0 ms 可能是 clock resolution，不是免費；本輪沒有 native cold/warm 數字。

`stable` 比較 cold/warm edge multiset 的 handle identity 與 slot；若不同需丟棄。capture 開始／結束的 SelectedSequence、Current Cue handle 必須一致；它不能偵測「中途切出去又回來」或所有同地址 Show edits，因此操作者必須保持測試 scope 不變。完整 graph、穩定 context 與 CHECKED truth 仍不自動升級 suitability。

native 記錄應保留整段 `[GDProbe] CASE` 到 `END`，包括 ROOT/CONTAINMENT/NODE/EDGE/READ/INGREDIENT/MATCH/MISSING/FALSE_POSITIVE/ERROR；不要只保存 flattened candidate 名單。第二次試驗應保留 case id 與 ground truth，才能判斷 graph 是 database relations 還是會依 active playback 過濾。

## 本輪驗證

離線 fixtures 模擬兩類可能 graph，不預設 GetDependencies 的 native 行為：

- 支持直接引用、多 Part、PhaserRecipe 巢狀結構、Generator alias、duplicate/cycle 的完整記錄。
- 故意讓 inherited current graph 缺 A、override/release/disabled graph 保留 inactive A，確認 probe 報 missing/false positive，**不把 historical refs 補入 current 或把 database edge 當 active**。
- 另測 API error、invalid nested Lua table、無效 ground truth、沒有 timer、CompareHandle 失敗、target version 不符、context 變更、warm graph 變更、depth/node上限，以及未配置 empty truth。

Validation commands：

```powershell
python tools/run_getdependencies_probe.py
python tools/check_parse.py
python tools/run_workflow.py
git diff --check
```

本輪執行結果：**58 probe assertions PASS（MOCK ONLY）**、**86 production workflow assertions PASS**，兩份 production Lua 與 XML parse PASS；獨立 probe 另行 parse PASS。靜態檢查確認沒有上述 cooked/mutating API 呼叫，production Git content 與前一 checkpoint 相同，文件 links 與十案例表格結構通過檢查。

mock 結果不驗證 MA native dependency 完整度、active filtering、速度、crash freedom 或 playback 無負載影響。production regression assertions 的結果也不是此新 API 的實測。獨立 Plugin 包裝新增 empty-argument Pool-click 回歸檢查後為 **59 probe assertions PASS**。

## 後續判定門檻

- `SUITABLE FOR CANDIDATE DISCOVERY`：本次確認 direct structural 引用可探索；已明列 inherited references 缺漏，不能宣稱涵蓋完整 Cue candidates 或可取代 scan。
- `SUITABLE FOR FINAL ACTIVE REFERENCES`：native direct/inherited/override/release/disabled/multi-Part 全部和每 scope 的完整 active truth 相符，無 missing/false positive，且正式語意或足夠案例支持；不能只憑 direct Recipe 案例通過。
- `PARTIAL ONLY`：初始待實測時的標記；本次已由上方 direct-candidate 與 final-tracking 雙結論取代。
- `NOT SUITABLE`：native 顯示重要 candidates 缺漏，或資料/latency不符合用途且無可靠 bounded 補救。尚未取得這種否定結果。

Exact next action：移至獨立 [Generator / Random CompareHandle probe](comparehandle-probe-2.5.0.3.md)。GetDependencies 不替代 tracking；production 不變。
