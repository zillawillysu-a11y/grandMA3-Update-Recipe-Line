# Generator / Random CompareHandle probe — 2.5.0.3

狀態：**REAL-WORLD VALIDATION PENDING**。目前只完成獨立 probe 與離線驗證，沒有 native equality 結果；不改 production sameReference、tracking、Pool marker 或版本。未部署此新 Plugin。

## 目的與證據

比較 Recipe 的 Generator/Random handle 與實際可見 Generator Pool tile 的 `PoolObject:Ptr(ObjectIndex)`。即使 command/native address 不同，仍以 `CompareHandle()` 結果判斷 identity，不以名字、slot、native path 或 handle 字串猜測。

主要依據：[2.5.0.3 functions dump](../.reference/ma3/DiDiDo-MA3-Developer-Reference/01_API_Dump/MA3_2.5.0.3/grandMA3_lua_functions.json) 的 CompareHandle、Ptr、UIChildren、ObjectList、Parent、AddrNative、BuildDetails。MA 2.5 `system_test_helping_functions_db.lua:320,338,599` 使用 CompareHandle 比較 preset/integrated handles；Pool UI 取物件方式與目前專案一致。IsActuallyVisible 有 MA 2.5 UI system tests 證據，但不在該 functions dump；可見性未知時跳過，不假定 visible。

GetDependencies native 結果已更新為 structural candidates 可用、final active/tracking 不可用，見 [native evidence](getdependencies-probe-2.5.0.3.md)。本實驗只研究 identity，不重新處理 tracking provenance。

## 檔案與執行

- [Lua](../diagnostics/CompareHandle_Probe_2_5_0_3.lua)、[獨立 XML](../diagnostics/comparehandle_probe_2_5_0_3.xml)，測試 Plugin 名稱 **CompareHandle Probe 2.5.0.3**。
- [mock tests](../tests/comparehandle_probe.lua)、[runner](../tools/run_comparehandle_probe.py)。
- 本輪只建立 source，沒有複製到 grandMA3 Plugin folder、沒有匯入或執行 native Plugin。
- 只讀取 APIs 與 Printf；不呼叫 GetPresetData/GetPresetDataFast/GetDependencies、不寫 UI/Show/Recipe/Programmer、不發送 Cmd、不操作 playback、不註冊 hooks、不使用 nested coroutine。

預設無參數執行：只查看 Current Cue 的直接 StandardRecipe/Recipe rows，辨識 Generator（或 Values 中的 Generator）並重新發現可見 Generator Pool tiles；**不自動尋找 inherited Recipes**。測試時操作者應顯示 Generator Pool 並選好含直接 Generator Recipe 的 Cue。無 ground truth 的結果維持 UNVERIFIED，但仍完整記錄 equality 與地址差異。

若要測 earlier Recipe，傳 `recipe_addresses` 明確指定；不切 Cue。`pool_addresses` 可以補充 ObjectList-resolved targets，但會標示 **not UI tile evidence**，不能用它代替實際 UI tile case。

外部檔案手動執行（onPC，launch command 待 native 確認）：

```text
Lua "local f=assert(loadfile([[C:/Users/willy/Downloads/Update-Recipe-Line/grandMA3-Update-Recipe-Line/diagnostics/CompareHandle_Probe_2_5_0_3.lua]])); f()(nil)"
```

Controlled run 的 config 形狀如下；操作者用已知地址替換 placeholder，選定單一 Generator Recipe，提供相異 Generator 作 negative control。不是實機 fixture 或自動建立測試資料。

```lua
f()(nil, {
    recipe_addresses = {"<known StandardRecipe command address>"},
    expected_generator = "Generator <known slot>",
    other_generator = "Generator <different slot>"
})
```

每個輸出 `[CHProbe] RECIPE` 包含 Recipe address、field、Enabled、raw type/value、resolved class/command/native address、parent、DataPool ancestor、handle token、self/expected/other comparison。每個 POOL 記錄實際來源；PAIR 記錄 cold/warm、reverse、stability、command/native text 是否相同、時間與錯誤。到 Command Line History 複製 `[CHProbe] START` 至 END；Lua error 可在 System Monitor 查看。

## Native cases 與判定

1. **同一 Generator**：Recipe handle 與 Generator Pool tile 為 true；自己比自己為 true。
2. **不同 Generator**：positive control A、negative control B 為相異；Recipe A 與 tile B 必須 false。相同 index 不足以跨 DataPool 判 identity。
3. **地址 aliases**：保存 command/native 不同的實際 pair，驗證同一 native object 仍 true。若此 Show 兩種字串都相同，不能宣稱測到 alias case。
4. **handle vs string**：記錄 Recipe property raw_type；地址字串必須 ObjectList 唯一解析。nil/無法解析/多物件不作 equality 成功。
5. **Disabled Recipe**：仍可比較 identity；true 不代表 enabled、active 或 playback 正在使用。
6. **重複 tile／多 display**：逐 tile 保留結果，不把一個畫面的 success 推廣到所有畫面。
7. **Recall View 前後**：操作者 Recall，再重新執行，重新讀取 tiles；本 probe 不持有跨執行 UI handles，也不解決 production cache invalidation。
8. **不同 DataPool／deleted handle**：若已有測試 fixture，確認不同物件 false、失效 handle 報 error；probe 不自行建立、刪除、move 或重載 Show。

Controlled result 只有 supplied positive/negative controls 有效且相異、Recipe self/expected true、other false、找到對應 target、cold/warm/reverse 穩定且沒有 capture errors 時才標 `CONTROLLED_PAIR_PASS_NATIVE_CONFIRMATION_REQUIRED`；它表示本次 pair 通過檢查，不證明所有 Recipe/Pool wrappers 永遠可靠。UI 與 ObjectList 證據分開，native operator 需確認 log 的來源與已知物件。沒有對照為 UNVERIFIED；CompareHandle failure 不 fallback 到地址文字。

cold/warm 是首次與立即重複的 comparison calls，使用 Time（依 MA vendor seconds 用法）換算 ms，不保證 native cache miss；可能低於 clock 精度，缺 timer 為 unavailable。comparison 計時包含 validity reads，不含 discovery/metadata/logging；不等同整個 Plugin latency。每次最多 64 rows、16 refs、128 tiles、3000 UI nodes、depth20、16000 read-wrapper calls；超限與未知可見性都記錄，不能當作完整成功。

## Validation

```powershell
python tools/run_comparehandle_probe.py
python tools/run_getdependencies_probe.py
python tools/check_parse.py
python tools/run_workflow.py
```

**37 CompareHandle mock assertions PASS**；既有 **59 dependency probe assertions**、**86 production workflow assertions**、production Lua/XML parse 亦通過。新 Lua/XML 另行 parse 與 referenced files 檢查通過。

mock 驗證地址不同而 identity 相同、不同 Generator false、相同地址文字但不同 identity、string/Values fallback、disabled identity、UI title/empty slots、hidden/unknown visibility、ObjectList-only 標籤、無效 controls、API failure、wrong build、unstable comparisons 與 missing timer。結果不代表 native 測試已完成。native logs 通過上述 cases 後，再討論 production 局部採用 CompareHandle；本輪不修改 production。
