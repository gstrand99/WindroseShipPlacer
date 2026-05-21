# WindroseShipPlacer

UE4SS dev mod that moves your deployed ship to preset berth positions next to the nearest dock/wharf. Position and rotation are always relative to the dock’s facing, not the camera.

Requires [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) installed for Windrose.

## Install

1. Copy this entire folder into your game UE4SS mods directory:
   ```
   <Windrose>\R5\Binaries\Win64\ue4ss\Mods\WindroseShipPlacer\
   ```
   The layout must be `WindroseShipPlacer\Scripts\main.lua`.

2. Enable the mod in `ue4ss\Mods\mods.txt`:
   ```text
   WindroseShipPlacer : 1
   ```

3. Restart the game (UE4SS loads scripts on startup).

Only `Scripts\main.lua` belongs in the game mod folder. Do not copy `README.md` or other repo files there.

**Local deploy (optional):** If you have a personal `deploy-ue4ss.ps1` (gitignored, not on GitHub), run it from this folder to copy `main.lua` into your game `Mods` path and update `mods.txt`.

On success, the UE4SS console shows `[WindroseShipPlacer] Loaded...` and the berth/reload keybind registration lines.

## Reload this mod only (avoid “Restart All Mods”)

UE4SS **Ctrl+R** and the console **Restart All Mods** button reload every mod and often crash Windrose. Prefer one of these:

### In-game: Ctrl+F5

This mod registers **Ctrl+F5** → `RestartCurrentMod()`, which reloads **only** `WindroseShipPlacer` (re-runs `main.lua`, clears old keybinds/hooks for this mod).

**Tuning workflow:**

1. Edit `Scripts\main.lua` in the repo.
2. Run `deploy-ue4ss.ps1` (or copy `main.lua` to the game mod folder).
3. In-game, press **Ctrl+F5** (do not use Ctrl+R).
4. Press **F7** to test the new offsets.

Change `KEY_RELOAD_MOD` / `MOD_RELOAD_MOD` at the top of `main.lua` if Ctrl+F5 conflicts with something else.

### UE4SS setting: auto-reload on file save

In `<Windrose>\R5\Binaries\Win64\ue4ss\UE4SS-settings.ini`, under `[General]`, set:

```ini
EnableAutoReloadingLuaMods = 1
```

When enabled, saving a file under `Mods\WindroseShipPlacer\Scripts\` reloads **only that mod** (same as `RestartCurrentMod` for that folder). Requires a UE4SS build that includes this option (recent RE-UE4SS releases).

After `deploy-ue4ss.ps1`, saving is enough if auto-reload is on; otherwise use **Ctrl+F5**.

### Lua debugger (if available)

Some UE4SS builds show a per-mod **Restart** button on the Mods tab in the Lua debugger GUI.

**Tip:** If you also use `WindroseShipSpawnLogger`, disable it or remove its line from `mods.txt` while testing— that mod binds **F7** to a dock scan and can conflict.

## How it works

When you press a keybind, the script:

1. Finds your local player pawn.
2. Finds the nearest valid dock (`R5BuildingBlock_ShipDock`, `BP_ShipDock_01_C`, `BP_ShipDock_02_C`) by distance from the player.
3. Finds the nearest deployed ship near that dock (ignores ships within ~100 UU of the dock origin).
4. Computes a world position by offsetting from the dock in **dock-local** space (forward / right / up).
5. Sets the ship’s yaw to dock + 180° on F7 front berth, or dock ± 90° for side berths.
6. Teleports the ship with `K2_SetActorLocationAndRotation`.

Berth offsets are per hull type in `SHIP_BERTH_PROFILES` at the top of `Scripts\main.lua`. Each profile has **front** and **side** dock-local offsets; the mod picks the profile from the ship class it finds.

## Keybinds (default)

| Input | Action |
|-------|--------|
| **F7** | Front berth, ship faces dock yaw + 180° (bow out from the wharf) |
| **Shift+F7** | Side berth, ship faces dock yaw + 90° |
| **Alt+F7** | Side berth, ship faces dock yaw − 90° |

You must have a ship **deployed** in the world near the dock. If nothing moves, check the console for `No dock found` or `No visible ship found near dock`.

## Changing keybinds

Edit the **KEYBIND CONFIG** block at the top of `Scripts\main.lua`:

```lua
local KEY_BERTH = Key.F7
local MOD_SIDE_PLUS = { ModifierKey.SHIFT }
local MOD_SIDE_MINUS = { ModifierKey.ALT }
```

- `KEY_BERTH` — key used for all three actions (modifiers distinguish side berths).
- `MOD_SIDE_PLUS` / `MOD_SIDE_MINUS` — modifier tables for the two side snaps; use `nil` for no modifier on a bind you do not use.

UE4SS key names follow the `Key.*` enum (e.g. `Key.F6`, `Key.F8`). Modifiers: `ModifierKey.SHIFT`, `ModifierKey.ALT`, `ModifierKey.CONTROL`.

Copy the updated `main.lua` into your game mod folder and **restart the game**.

## Per-ship berth offsets

In `Scripts\main.lua`, edit `SHIP_BERTH_PROFILES`. Each hull has its own row:

| Profile key | Typical class |
|-------------|----------------|
| `ketch` | `BP_Ship_Ketch_Default_C` |
| `ketch_moored` | `BP_Ship_Ketch_Moored_C` (moored ketch variant) |
| `brig` | `BP_Ship_Brig_Default_C` |
| `frigate` | `BP_Ship_Frigate_Default_C` |
| `shallow_boat` | `BP_Ship_ShallowBoat_Default_C` |
| `default` | Unknown / `R5ShipPawnBase` fallback |

Example structure:

```lua
ketch = {
    front = { forward = -2625.0, right = 50.0, up = -98.0 },
    side  = { forward = -1200.0, right = -1200.0, up = -98.0 },
},
```

Offsets are in **dock space**: **forward** = along the dock’s yaw, **right** = perpendicular, **up** = vertical (Z). All profiles start with the same legacy defaults; tune each hull separately.

### Tuning offsets (edit → restart → test)

UE4SS only reads `main.lua` when the game starts. There is no in-game slider; each try is:

1. **Edit** `Scripts\main.lua` — change numbers in that hull’s `front` or `side` block inside `SHIP_BERTH_PROFILES` (e.g. nudge `forward` by 100, test again).
2. **Copy** only `Scripts\main.lua` into your live mod folder (or run your local `deploy-ue4ss.ps1`):
   `...\ue4ss\Mods\WindroseShipPlacer\Scripts\main.lua`
3. **Reload the script** — run `deploy-ue4ss.ps1`, then press **Ctrl+F5** in-game (reloads only this mod). Or enable `EnableAutoReloadingLuaMods` in `UE4SS-settings.ini` so saving `main.lua` reloads automatically. Full game restart is only needed if reload fails or you changed `mods.txt`.
4. **Deploy** only the hull you are tuning near a dock.
5. Press **F7** (front) or **Shift+F7** / **Alt+F7** (side) and check position/rotation at the wharf.
6. Repeat from step 1 until that hull looks right, then move on to the next hull or side berth.

**What the numbers mean (dock-local):**

- `forward` — along the dock’s facing; more negative usually moves the ship farther along the “back” axis used in the script (same convention as the old −2625 front preset).
- `right` — slide perpendicular to the dock.
- `up` — height (Z).

Tune **front** (F7) first, then **side** (Shift/Alt+F7) separately. Change one axis at a time so you can see the effect.

The UE4SS console prints which profile and offsets were used, for example:

`Using profile=ketch class=BP_Ship_Ketch_Default_C front offsets forward=-2625.0 right=50.0 up=-98.0`

## Files

```
WindroseShipPlacer/
  README.md
  Scripts/
    main.lua
```
