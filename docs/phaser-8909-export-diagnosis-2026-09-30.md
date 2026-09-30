# 8909 Shutter Shuffle 匯出診斷

2026-09-30。使用者提供 v0.7.1.35 的 Cue 4 截圖，以及本機 Preset `RRR.xml`、Sequence `SEQREF.xml`。本次唯讀解析 XML、對照 runtime；依使用者「先降時間，Phaser BUG 晚點修」的指示，未修改 Phaser 判定。

## 證據

- 截圖：Selection 0、Cue 4 Change、`Blocked: 25.8909 [PHASER_STRUCTURE_UNPROVEN]`，total 510.3 ms、累積 engine 193.7 ms、scope 76.5 ms、tiles 46.5 ms。
- `C:/ProgramData/MALightingTechnology/gma3_library/datapools/presets/RRR.xml`：Preset 名稱 Shutter Shuffle，**直接子物件為 3 條 PhaserRecipe**，不含依賴 Shape 內的 recipe。

| PhaserRecipe | 直接 steps 數 | Attributes |
|---|---:|---|
| Shutter1 | 3 | A: Shutter1 |
| StrobeDuration | 2 | A: StrobeDuration |
| StrobeRate | 2 | A: StrobeRate |

這三條引用 Snap New Shape。Shape 匯出兩個 step 的 RawValueAbs 是 100 / 0。Shutter1 的第 3 step 重用 Shape Step 1，沒有 Preset link；其餘來源連到 Beam.Strobe / Beam.Open。匯出展示了相對 Shape value-source 路徑，後續修復仍需核對 native 屬性的解析方式。

- `C:/ProgramData/MALightingTechnology/gma3_library/datapools/sequences/SEQREF.xml`：Sequence EP303_Ricky_beats，27 個直接 Cue、232 個直接 StandardRecipe/Recipe rows。Cue 4 的 Part 2 有兩條 `Enabled=Yes` Recipe，Selection 指向 All AG Tilt Head / AG ST Head Grid，Values 都指向 Song EFX.Shutter Shuffle。Cue 8、12、16、20 亦有相同兩組引用。
- Sequence dependency 中的 Shutter Shuffle Preset GUID 與 RRR.xml 頂層 Preset GUID 相同。
- 兩份 XML 都成功以 ElementTree 解析；未匯入、改寫或複製 Show 資料到 runtime，也未以 cooked export 取代 live proof。

## 具體程式限制

`tools/templates/show_track_a_runtime.lua` 的 `phaser()` walk 每遇到 PhaserRecipe 就增加 `recipes`、每個 step 增加共同 `stepCount`。結構 gate 為：

```lua
if mismatch or recipes~=1 or stepCount<1 or not next(steps) then return nil end
```

而失敗原因在 walk 前已設為 `PHASER_STRUCTURE_UNPROVEN`。如果 native children 與此匯出相同，recipes=3，這個 gate 必定拒絕，與使用者畫面一致。這是此案明確、足以解釋現象的結構限制；仍未宣稱其他 gate 都會通過或已修復。

8909 與先前 25.2001 的 `ACTIVE_CHANNEL_FIELD_measure` 是不同問題：8909 有結構化 PhaserRecipe，但為多條；25.2001 走 raw channel timing gate。不要把兩個原因混成一個修法。

## 後續修復需要

先按每條 PhaserRecipe 的各自 steps 完整證明 Attribute、ABS/REL、Shape 繼承、外部 Preset 依賴，再合併 FeatureGroup/layer。保留同 FG 多 Attribute 的覆蓋、moving/static 衝突、未知 REL、Self-link、Selective linked preset、unsafe override 等安全規則。

不可單純把 `recipes~=1` 改為 `recipes<1`：現有 `count(s.stepIds)~=stepCount` 使用共同總步數，遇到不同 Attribute / FG 和不同步數會錯判。需新增 3/2/2 steps 與不同 FG 的多 recipe 回歸，再取得 native 驗證。v0.7.1.36 只處理效能，這項 BUG 仍待後續實作。

## Additional exports supplied by user

`2302PHASER.xml` contains 11 Presets, 76 raw Phaser channels, 152 Steps and no PhaserRecipe children. Raw Dimmer channels contain `Measure="16777216"`; this supports the screenshot measure rejection, but XML integer encoding does not establish native API units or semantics. `SEQREFV3.xml` parses successfully and contains no PhaserRecipe nodes. Screenshot v35 also reports ACTIVE_VALUE_MASK_SHAPE; exported data alone does not prove native mask representation. These are separate from the three-recipe 8909 failure. Runtime parser remains unchanged.

`PHASERRECIPE.xml` parses successfully (100,318 bytes). Direct Preset structure:

| Preset name | Direct PhaserRecipe count |
|---|---:|
| Dimmer Strobe#3 | 1 |
| Dimmer Speed#7 | 1 |
| Dimmer Speed#8 | 1 |
| Dimmer Speed#9 | 1 |
| Dimmer R-#2 | 1 |
| Dimmer Speed#10 | 1 |
| Shutter Shuffle | 3 |
| Dimmer Sin#4 | 1 |
| Dimmer Sin#5 | 1 |
| Dimmer Sin#6 | 1 |

The range contains ten exported Presets; numeric positions are not inferred from order. Shutter Shuffle again has three direct recipes; the other exported Presets have one. The same structure gate therefore cannot explain every Phaser failure. AdaptiveMeasure and different Shape/step structures need individual native proof rather than blanket admission. Original exported files remain outside the repository and unchanged.
