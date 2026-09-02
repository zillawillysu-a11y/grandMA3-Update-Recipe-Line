# Dockable Plugin Window Research

## Result for grandMA3 2.3.2.0

A production UserPlugin should not attempt to register a custom Pool-style window on 2.3.2.0. No supported UserPlugin extension point was found for adding a `WindowType` and its backing `Menu`/`ComponentXML` to the Add Window dialog.

## Confirmed locally

- Available windows are declared in `shared/resource/default_window_types.xml` and exposed at runtime through `CurrentProfile().Windowtypes`.
- `Store ScreenContent <display> "<WindowType>" ...` creates an instance of an already registered type; it does not define a new type.
- A registered type such as `WindowPluginPool` is backed by a locked system Menu whose `ComponentXML` targets `PlaceHolder="UiScreen"`.
- The installed system-test helper `SystemTest.UI:storeWindow()` also stores only an existing named WindowType.
- The requested patopesto reference repository contains code for reading and resizing existing ScreenContent/ViewWidgets, but no example that registers a new WindowType from an ordinary UserPlugin.

## Rejected production approaches

- Editing `shared/resource/default_window_types.xml` or installing files under `shared/resource/lib_menus`: modifies the MA installation, is version/update fragile, and is not a portable UserPlugin deployment.
- Reusing an unrelated built-in WindowType and replacing its children: risks corrupting or destabilizing normal MA UI behavior.
- Treating `WindowPluginPool` as a custom-content host: it is the built-in Plugin object pool, not a generic Plugin UI container.

## Safe fallback

Use a compact `ModalOverlay` status bar with explicit `DETAIL`, `MOVE`, and `STOP` controls. It remains read-only with respect to Show data and requires no MA installation modification. A true dockable window can be reconsidered if a documented extension API appears in a later grandMA3 version.
