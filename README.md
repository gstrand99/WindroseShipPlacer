# WindroseShipPlacer

UE4SS **dev helper** that teleports your **already deployed** ship to preset berth positions next to the nearest dock/wharf. Position and rotation are relative to the dock’s facing, not the camera.

**Experimental** — for tuning slip/berth layout and screenshots. Does not change save data or dock UI. Use at your own risk; restart the game after script changes.

Requires [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) for Windrose (`R5\Binaries\Win64\ue4ss\`).

## Configuration (top of `Scripts\main.lua`)

All tunables are at the top of the script. After any edit, copy `main.lua` into the game mod folder and **restart the game** (no in-game reload on Windrose).

| Block | What you change |
|-------|------------------|
| **KEYBIND CONFIG** | `KEY_BERTH`, `MOD_SIDE_PLUS`, `MOD_SIDE_MINUS` |
| **DISTANCE CONFIG** | Max player→wharf, max ship→wharf, min ship→wharf pivot |
| **SHIP_BERTH_PROFILES** | Per-hull `front` / `side` dock-local offsets |

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

On success, the UE4SS console shows `[WindroseShipPlacer] Loaded...` and three `Registered keybind:` lines for the berth snaps.

## Applying script changes (no in-game reload)

On Windrose, **any** UE4SS Lua reload path tested so far has crashed with no error:

- **Ctrl+R** / console **Restart All Mods**
- **`RestartCurrentMod()`** (per-mod restart keybind)
- **`EnableAutoReloadingLuaMods = 1`** (hot reload on file save)

Turn hot reload **off** in `UE4SS-settings.ini`:

```ini
EnableAutoReloadingLuaMods = 0
```

**Stable workflow when tuning:**

1. Edit `Scripts\main.lua` in the repo (offsets, distances, or keybinds).
2. Run `deploy-ue4ss.ps1` (or copy `main.lua` into the game mod folder).
3. **Quit the game completely** and start it again.
4. Stand near the wharf with a **deployed** ship, press **F7** (and Shift/Alt+F7 for side), read the UE4SS log.

Do not use in-game reload buttons or per-mod restart while the game is running.

**Tip:** If you also use `WindroseShipSpawnLogger`, disable it or remove its line from `mods.txt` while testing— that mod binds **F7** to a dock scan and can conflict.

## Ship variants (stock / Brethren / BlackBeard)

Player hull blueprints live under `/Game/Gameplay/Water/Character/PlayerShips/` (e.g. `BP_Ship_Ketch_Default`, `BP_Ship_Ketch_Brethren`, `BP_Ship_Ketch_BlackBeard`). Faction skins use the **same berth profile** as stock (ketch / brig / frigate). The mod scans `*_Default_C` classes only; Brethren/BlackBeard hulls are still matched via `resolve_ship_profile` on the actor name.

Deploy the ship you want to position at the wharf, then press **F7** (or side binds). The console log shows the exact class and profile used.

## How it works

When you press a keybind, the script:

1. Finds your local player pawn.
2. Finds the nearest valid dock (`R5BuildingBlock_ShipDock`, `BP_ShipDock_01_C`, `BP_ShipDock_02_C`) within **max distance from the player** (if configured).
3. Finds the nearest deployed ship near that dock, outside the wharf pivot and within **max distance from the wharf** (if configured).
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

You must have a ship **deployed** in the world near the dock. If nothing moves, check the console for `No dock within … UU of player`, `No ship within … UU of dock`, or `No visible ship found near dock`.

### Getting a frigate for offset tuning

The placer only moves ships already in the world (`BP_Ship_Frigate_Default_C`). It does not grant ships.

1. **Dock UI (normal)** — At a wharf, open the ship dock panel, select **Frigate** in your ship list (you must own it from progression/crafting), then use **Deploy** so `BP_Ship_Frigate_Default_C` exists near the dock. Store any other hull first so F7 picks the frigate.
2. **Summon keybind** — Summons your **currently equipped** hull, not a specific class. Set equipped ship to frigate at the dock, then summon, then F7.
3. **Dev console (if cheats work)** — UE4SS console / in-game `~` and try: `Summon BP_Ship_Frigate_Default_C` (stand on open water near the dock). May require cheat-enabled build; class name from object dump.

After deploy, the log line should show `profile=frigate class=BP_Ship_Frigate_Default_C`.

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

## Distance limits

Edit the **DISTANCE CONFIG** block at the top of `Scripts\main.lua` (Unreal units). Current repo defaults:

```lua
local MAX_DOCK_DIST_FROM_PLAYER = 2000.0
local MAX_SHIP_DIST_FROM_DOCK = 5000.0
local MIN_SHIP_DIST_FROM_DOCK = 100.0
```

| Constant | Meaning |
|----------|---------|
| `MAX_DOCK_DIST_FROM_PLAYER` | Player must be within this distance of the wharf to snap. **`0` = no limit.** |
| `MAX_SHIP_DIST_FROM_DOCK` | Deployed ship must be within this distance of the wharf origin. **`0` = no limit.** |
| `MIN_SHIP_DIST_FROM_DOCK` | Ships closer than this to the wharf pivot are ignored (avoids snapping the dock actor). |

On a successful snap, the console prints `dock_dist=` and `ship_dist=` (linear UU) before the profile line — use those to tune max distances for your wharf layout.

## Per-ship berth offsets

In `Scripts\main.lua`, edit `SHIP_BERTH_PROFILES`. Each hull has its own row with **front** (F7) and **side** (Shift/Alt+F7) offsets.

| Profile key | Typical class | Front `forward` (repo default) |
|-------------|----------------|------------------------------|
| `ketch` | `BP_Ship_Ketch_*` | −1825 |
| `brig` | `BP_Ship_Brig_*` | −2350 |
| `frigate` | `BP_Ship_Frigate_*` | −2925 |
| `shallow_boat` | `BP_Ship_ShallowBoat_Default_C` | −600 |
| `default` | Unrecognized hull | −2625 |

Example structure:

```lua
ketch = {
    front = { forward = -1825.0, right = 50.0, up = -98.0 },
    side  = { forward = -750.0, right = -800.0, up = -98.0 },
},
```

Offsets are in **dock space**: **forward** = along the dock’s yaw, **right** = perpendicular, **up** = vertical (Z). Tune each hull at your wharf; values are not universal.

### Tuning offsets (edit → restart → test)

UE4SS only reads `main.lua` when the game starts. There is no in-game slider; each try is:

1. **Edit** `Scripts\main.lua` — change that hull’s `front` or `side` block in `SHIP_BERTH_PROFILES`, and/or distance limits (e.g. nudge `forward` by 100).
2. **Copy** `Scripts\main.lua` to `...\ue4ss\Mods\WindroseShipPlacer\Scripts\main.lua` (or run `deploy-ue4ss.ps1`).
3. **Quit and restart the game** (in-game reload crashes Windrose; see above).
4. **Deploy** only the hull you are tuning near a dock (within `MAX_SHIP_DIST_FROM_DOCK`).
5. Press **F7** (front) or **Shift+F7** / **Alt+F7** (side); check position/rotation and the log (`dock_dist`, `ship_dist`, profile line).
6. Repeat until that hull and berth look right.

**What the numbers mean (dock-local):**

- `forward` — along the dock’s facing; more negative usually moves the ship farther along the “back” axis used in the script (same convention as the old −2625 front preset).
- `right` — slide perpendicular to the dock.
- `up` — height (Z).

Tune **front** (F7) first, then **side** (Shift/Alt+F7) separately. Change one axis at a time so you can see the effect.

The UE4SS console prints which profile and offsets were used, for example:

`dock_dist=450.0 ship_dist=1200.0` then `Using profile=ketch class=BP_Ship_Ketch_BlackBeard_C front offsets forward=-1825.0 right=50.0 up=-98.0`

## Limitations

- Moves the nearest qualifying deployed ship only; does not spawn ships or fix dock Deploy/Store.
- Cheat `Summon` of ship BPs is unreliable; use wharf **Deploy** for testing.
- Offsets and distance limits are tuned per wharf/layout; repo defaults are a starting point.
- **No in-game reload** on Windrose (restart required). See above.
- Conflicts with **WindroseShipSpawnLogger** if both bind **F7** — disable the logger in `mods.txt` while using the placer.
- Multiplayer / dedicated server: untested; likely client-only.

## Files

```
WindroseShipPlacer/
  README.md
  Scripts/
    main.lua
```
