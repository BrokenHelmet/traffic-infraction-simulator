# PROJECT_ARCHITECTURE.md — Traffic Infraction Simulator

Internal technical reference. Not for distribution.

---

## Project Identity

**Traffic Infraction Simulator** is a Godot 4.4 game where players take the role of an officer examining a 3D scene and identifying safety infractions by tapping on offending objects. It is forked from Traffic Control Simulator (TCS), reusing its camera, input, app lifecycle, and UI infrastructure while replacing the traffic management game mode entirely with infraction inspection.

All documentation in this repository reflects the current game. The fork origin is noted here for context only.

---

## Environment Setup

### Linux
```bash
export GODOT_44="/home/daud/.var/app/io.github.MakovWait.Godots/data/godot/app_userdata/Godots/versions/Godot_v4_4_1-stable_linux_x86_64/Godot_v4.4.1-stable_linux.x86_64"

$GODOT_44 --editor .                          # Open editor
$GODOT_44 scenes/app_root.tscn                # Run full app
$GODOT_44 scenes/levels/Level_1.tscn          # Run level directly (fastest for iteration)
$GODOT_44 --headless --export-release "Android" builds/android/game.apk
```

### Windows (PowerShell)
```powershell
$env:GODOT_44 = "C:\Godot\Godot_v4.4.1-stable_win64.exe"
& $env:GODOT_44 --editor .
& $env:GODOT_44 scenes/app_root.tscn
& $env:GODOT_44 scenes/levels/Level_1.tscn
```

- Godot version: **4.4.1**
- Target platforms: Android (primary), Windows, Linux, macOS
- Git line endings: LF (configure `core.autocrlf=false` on Windows)

---

## App Lifecycle

Entry point: `scenes/app_root.tscn` → `scripts/app_controller.gd`

```
app_root.tscn (AppController)
  ├── SplashScreen    →  plays on launch, emits splash_completed
  ├── LandingScreen   →  waits for tap/click, emits start_game_requested
  ├── LevelContainer  →  holds the instantiated level at runtime
  └── GameHUD         →  shown during gameplay, receives score updates
```

Flow: `SplashScreen` completes → `LandingScreen` becomes visible → player taps → `AppController` instantiates the level into `LevelContainer` and shows `GameHUD`.

---

## Scene Structure

### Core Scenes

| Scene | Script | Role |
|---|---|---|
| `scenes/app_root.tscn` | `app_controller.gd` | Root. Manages full app lifecycle. |
| `scenes/intersection/game_level_base.tscn` | `main_landing_level.gd` | Level template. Camera, managers, ground plane, pause system. Level content instanced as a child at runtime. |
| `scenes/levels/Level_1.tscn` | — | First playable level. Road layout, traffic light prop, one infraction (ambulance). |
| `scenes/cameras/CameraRig.tscn` | `camera_rig.gd` | Orbit camera prefab. Included in `game_level_base.tscn`. |
| `scenes/ui/ui_game_hud.tscn` | `ui_game_hud.gd` | In-game HUD. Score label and message feed. Child of `app_root.tscn`. |
| `scenes/ui/ScoreDisplay.tscn` | `infraction_score_display.gd` | Infraction scoring overlay (score, found/total, battery, stars). **Not yet placed in scene — MVP TODO.** |
| `scenes/SplashScreen.tscn` | `splash_screen_controller.gd` | Optional video or static splash. |
| `scenes/ui/LandingScreen.tscn` | `screen_landing.gd` | Title screen with pulse animation. |
| `scenes/ui/PauseOverlay.tscn` | `PauseOverlayController.gd` | Pause menu (Resume / Restart / Menu). |

### Per-Level Scene Hierarchy

```
game_level_base.tscn (MainLandingLevel)
  ├── GameplayManager           → session state (see Legacy Systems)
  ├── Clickable3DManager        → MobileClickable3DManager, handles all tap raycasts
  ├── CameraRig                 → orbit camera
  ├── GroundPlane               → procedural ground mesh
  ├── PauseManager              → pause-manager addon node
  └── UI Menu / PauseOverlay
        └── [Level content, e.g. Level_1.tscn instanced here]
              ├── RoadNodes           → environment geometry
              ├── OverheadTrafficLight → prop only (logic not active)
              └── Infraction_1        → IncidentInspectionAction node
                    ├── ambulance.glb   → visual model
                    └── StaticBody3D
                          └── CollisionShape3D
```

---

## Key Scripts

| Script | Class | Role |
|---|---|---|
| `app_controller.gd` | — | Root lifecycle manager. Splash → landing → level. Holds global score state. |
| `main_landing_level.gd` | — | Level base controller. Wires level config and gameplay manager. |
| `mobile_clickable_3d_manager.gd` | — | **Active input system.** Raycasts on touch and mouse, finds parent `Clickable3D` of hit collider, calls `on_click()` or `on_long_press()`. Tracks elapsed touch time for long-press detection. |
| `clickable_3d.gd` | `Clickable3D` | Base class for tappable 3D objects. Exposes `clicked` and `long_pressed` signals. |
| `incident_inspection_action.gd` | `IncidentInspectionAction` | Extends `Clickable3D`. Represents one infraction in the scene. On `on_click()`, calls `InfractionScoreManager.register_infraction_found(name)`. |
| `infraction_data.gd` | `Infraction` | Data container (name, point value, description). Attached to `CollisionObject3D` nodes. Used by the legacy `level_input_handler` system — may be removable. |
| `infraction_score_manager.gd` | `InfractionScoreManager` | Scoring engine. Auto-detects `IncidentInspectionAction` nodes on `_ready()`. Tracks score, found infractions, false positives. Emits: `score_updated`, `infraction_found`, `false_positive_flagged`, `round_completed`. Must be in group `score_manager`. |
| `infraction_score_display.gd` | `InfractionScoreDisplay` | UI controller for `ScoreDisplay.tscn`. Connects to `InfractionScoreManager` signals. Displays score, found/total infractions, battery, star rating. |
| `ui_game_hud.gd` | — | HUD controller. `update_score()`, `display_infraction_msg()`, `display_penalty_msg()`. |
| `screen_landing.gd` | — | Landing screen. Pulse animation, tap/click/key to start, fades out and emits `start_game_requested`. |
| `camera_rig.gd` | — | Pivot-based orbit camera. Touch and mouse support. Zoom, pan, rotate. |
| `gameplay_manager.gd` | — | Session state. Partially legacy from fork — see Legacy Systems. |
| `level_input_handler.gd` | — | **Orphaned.** Older mouse + collision-layer raycast system. Not connected to any scene. Do not use. |

---

## Infraction Detection Flow

```
Player tap / click
  → MobileClickable3DManager._input()
      → _raycast_to_clickable(screen_pos)
          → PhysicsRayQueryParameters3D cast into scene
          → result["collider"].get_parent() checked for Clickable3D
      → IncidentInspectionAction.on_click(hit_position)
          → InfractionScoreManager.register_infraction_found(node.name)
              → score updated, found_infractions dict updated
              → emits: infraction_found(id, points)
              → emits: score_updated(new_score)
              → check_round_complete()
                  → emits: round_completed(success, score, stars, message)
  → InfractionScoreDisplay._on_infraction_found()
  → InfractionScoreDisplay._on_score_updated()
```

If the raycast hits something but `get_parent()` returns no `Clickable3D`, a false positive should be registered. **This is currently not wired — see Known Issues.**

---

## Infraction Node Structure

Every clickable infraction in a level scene must follow this exact structure for the input system to detect it correctly:

```
[Node3D]  ← attach incident_inspection_action.gd here
  ├── [MeshInstance3D or GLB]   ← visual model
  └── [StaticBody3D]
        └── [CollisionShape3D]  ← sized to the model
```

`MobileClickable3DManager` hits the `StaticBody3D` via raycast and checks `collider.get_parent()` for `Clickable3D`. The `StaticBody3D` must be a **direct child** of the `IncidentInspectionAction` node.

---

## Scoring System

`InfractionScoreManager` auto-detects all `IncidentInspectionAction` nodes in the scene tree on `_ready()` and uses the count as `total_infractions`.

| Event | Effect |
|---|---|
| Correct tap | +10 points |
| False positive | -5 points |
| False positive limit reached | Round fails immediately |

- Default false positive limit: `3` (export var, configurable per level)
- Star thresholds: 1★ = 40% of perfect score, 2★ = 70%, 3★ = 100%
- Round end conditions: all infractions found, battery depleted, or time expired (`check_time_expired()` must be called by a timer)

---

## Adding a New Infraction to a Level

1. In the level scene, add a `Node3D`
2. Attach `scripts/incident_inspection_action.gd`
3. Set `incident_name` in the Inspector
4. Add a mesh or GLB model as a child (visual)
5. Add a `StaticBody3D` child, then a `CollisionShape3D` under that, sized to the model
6. `InfractionScoreManager` will auto-detect it at round start — no manual registration needed

---

## Debug Flags

All scripts use `@export var debug_X: bool` flags, toggled in the Inspector. Keep all `false` by default; enable only what you need.

| Script | Flag | Output |
|---|---|---|
| `infraction_score_manager.gd` | `debug_scoring` | Score updates, infraction registration, round init |
| `infraction_score_manager.gd` | `debug_completion` | Round completion events, false positive limit |
| `infraction_score_display.gd` | `debug_score_ui` | Signal receipts, display updates |
| `app_controller.gd` | `debug_mode` | Level load and lifecycle events |
| `camera_rig.gd` | `debug_mode` | Camera position and rotation state |

Debug output prefixes follow the format `[ClassName]` for easy filtering in the Output panel.

---

## Known Issues & MVP Backlog

### Must fix for a demonstrable MVP

- [ ] `InfractionScoreManager` node not yet added to `game_level_base.tscn` — add it and assign to group `score_manager`
- [ ] `ScoreDisplay.tscn` not yet placed in the level UI — add to `game_level_base.tscn` UI layer
- [ ] Auto-detection of infractions may return `total_infractions = 0` — run with `debug_scoring = true` and verify the count on launch
- [ ] False positives do not fire on a missed tap — in `mobile_clickable_3d_manager.gd`, add `score_manager.register_false_positive()` when raycast returns no `Clickable3D`
- [ ] `round_completed` signal not yet connected to anything visible — wire to a temporary print or LevelOver screen to confirm the round ends correctly
- [ ] Only one infraction in `Level_1.tscn` — add at least one more to make the round non-trivial

### Good to address soon

- [ ] `gameplay_manager.gd` carries vehicle/pedestrian spawning logic from the fork — audit and strip what isn't needed; the session state and `level_completed` signal are worth keeping
- [ ] `level_input_handler.gd` is orphaned — confirm it is not connected anywhere and delete it
- [ ] `infraction_data.gd` is only used by `level_input_handler` — may be removable once that file is deleted
- [ ] `ScoreDisplayController.gd` and `score_manager_legacy.gd` are TCS scoring files — not used, safe to remove

---

## Legacy Systems (from Fork)

| System | Files | Status |
|---|---|---|
| Vehicle spawning | `gameplay_manager.gd` | Partial — session state is useful, vehicle/pedestrian spawning is not. Audit before modifying. |
| Old input handler | `level_input_handler.gd` | Orphaned. Replaced by `mobile_clickable_3d_manager.gd`. Safe to delete. |
| Infraction data component | `infraction_data.gd` | Used only by `level_input_handler`. Likely removable. |
| Legacy scoring | `ScoreDisplayController.gd`, `score_manager_legacy.gd` | TCS system. Not used. Safe to delete. |
| Pedestrian system | `Pedestrian.gd`, `PedestrianManager.gd` | Not used in this game mode. Retained from fork. |
| Vehicle system | `Vehicle.gd`, `VehicleTypeConfig.gd` | Not used in this game mode. Retained from fork. |
| Traffic light logic | `TrafficLight.gd`, `TrafficControlExample.gd` | Traffic light appears as a prop in `Level_1.tscn` only. Logic not active. |
| Level config system | `LevelConfig.gd`, `configs/levels/*.tres` | Built for TCS parameters. May be repurposed for infraction levels or replaced. |

---

## Code Conventions

- **No `class_name` on Resource subclasses** — Godot's class registration is unreliable for Resources in this environment. Use `type="Resource"` in `.tres` files and validate with `has_method()` before calling methods on loaded resources.
- **`class_name` works on Node subclasses** — `Clickable3D`, `IncidentInspectionAction`, `InfractionScoreManager`, `InfractionScoreDisplay`, and `Infraction` all declare `class_name` and it works correctly.
- **Group-based node lookup** — systems find each other via `get_tree().get_first_node_in_group()` rather than hardcoded paths (e.g. the `score_manager` group).
- **Debug flags over raw prints** — use `@export var debug_X: bool` per-script. Do not leave loose `print()` calls in production paths.

---

## Quick Validation Checklist (on resume)

Run through this before making any changes:

1. Press F5 on `app_root.tscn` — confirm splash → landing → level loads without errors
2. Tap the ambulance in the level — confirm `"SUCCESS: Incident detected"` prints in Output
3. Check `InfractionScoreManager` output with `debug_scoring = true` — confirm `total_infractions` is not 0
4. Confirm `InfractionScoreDisplay` is visible and updates on tap
5. Tap an empty area — check whether a false positive registers (currently broken)
6. Find all infractions — confirm `round_completed` fires

---

## Addons

- **pause-manager** — tree-based pause system. ESC key bound to `ui_cancel` and `pause` actions. Integrated via `PauseManager` node in `game_level_base.tscn`. Pause overlay provides Resume / Restart / Menu options.
