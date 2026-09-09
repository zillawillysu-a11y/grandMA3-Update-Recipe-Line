# Pool reference markers (v0.6.3.0)

The user video `C:\Users\willy\Videos\2026-09-09 03-05-18.mp4` shows a cyan update icon alternating with the underlying Preset tile. Frames were extracted at 4 fps and inspected. No public callable API for that exact native update animation was identified.

The local 2.3.2 installation provides these relevant references under `shared/resource`:

- `lib_plugins/systemtests/ui/uitf/wrappers/system_test_uitf_wrappers_pool.lua`: visible tiles use UIChildren and ObjectIndex; their objects resolve through PoolObject:Ptr(ObjectIndex).
- `lib_plugins/systemtests/ui/system_test_ui_pools.lua`: GetDisplayByIndex and native pool traversal.
- `lib_menus/ui_onpc/onpc_ui.uixml`: UIObject with small_frame0 texture and HasHover=No.
- `lib_menus/ui/content/tags_edit_content.uixml`: noninteractive UIObject.
- Group, Preset, Generator, World, Filter and MAtricks pool definitions have ReactToRecipeEdit, but this does not establish an independent blink setter.

The plugin uses temporary, noninteractive UIObject frames on matching visible pool buttons. Existing frames pulse between two visible theme colors every 0.25 seconds, while Pool UI traversal remains limited to every 0.5 seconds. It reads Recipe Selection, Values, MAtricks, Filter, World and Generator object references. Thus Values in All or other Preset pools are treated by object address, without assuming a numbered pool. Indirect dependencies inside a Preset/Generator are not recursively expanded. The installed texture set has dotted fill textures but no native dashed frame; segmented-frame emulation is avoided because it multiplies temporary UI objects per Pool button.

No Appearance, Show object, Programmer state or native update state is changed by marking. Markers are removed when references change, the tool stops or POOL BLINK is turned off. Selection/pool scrolling is rescanned. Runtime rendering of frames attached to native pool tiles remains unverified; offline tests establish mapping/lifecycle only. If a native tile rejects the child frame, the plugin skips it.
