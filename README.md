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

On success, the UE4SS console shows `[WindroseShipPlacer] Loaded...` and three `Registered keybind:` lines.

**Tip:** If you also use `WindroseShipSpawnLogger`, disable it or remove its line from `mods.txt` while testing— that mod binds **F7** to a dock scan and can conflict.

## How it works

When you press a keybind, the script:

1. Finds your local player pawn.
2. Finds the nearest valid dock (`R5BuildingBlock_ShipDock`, `BP_ShipDock_01_C`, `BP_ShipDock_02_C`) by distance from the player.
3. Finds the nearest deployed ship near that dock (ignores ships within ~100 UU of the dock origin).
4. Computes a world position by offsetting from the dock in **dock-local** space (forward / right / up).
5. Sets the ship’s yaw to match the dock (or dock ± 90° for side berths).
6. Teleports the ship with `K2_SetActorLocationAndRotation`.

Berth offsets are tuned from in-game measurements; you can tweak them at the top of `Scripts\main.lua` (`BERTH_*` and `SIDE_*` constants).

## Keybinds (default)

| Input | Action |
|-------|--------|
| **F7** | Front berth, ship faces dock yaw |
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

## Changing berth position

In `Scripts\main.lua`, adjust:

- **Front berth:** `BERTH_FORWARD`, `BERTH_RIGHT`, `BERTH_UP`
- **Side berths:** `SIDE_FORWARD`, `SIDE_RIGHT`, `SIDE_UP`

Offsets are in dock space: **forward** = along the dock’s yaw, **right** = perpendicular, **up** = vertical (Z).

## Files

```
WindroseShipPlacer/
  README.md
  Scripts/
    main.lua
```
