# Traffic Infraction Simulator

A 3D incident inspection game built with Godot 4.4. Players take the role of an officer examining a scene and identifying safety infractions by tapping on the objects that constitute violations.

![Godot](https://img.shields.io/badge/Godot-4.4-green)
![License](https://img.shields.io/badge/license-All%20Rights%20Reserved-red)

---

## Game Overview

The player is placed in a 3D environment containing a scene with a number of hidden safety infractions. The objective is to identify all violations by tapping on the offending objects before time runs out and without exceeding a false positive limit. Each correct identification scores points; incorrect taps drain the battery (false positive allowance).

### Core Loop
1. Player enters a scene
2. Camera can be orbited to inspect the environment
3. Player taps on objects they believe are infractions
4. Correct taps score points and register the find
5. Incorrect taps deduct from the battery (false positive count)
6. Round ends when all infractions are found, the battery depletes, or time expires
7. Score is rated 1–3 stars based on performance

---

## Getting Started

### Prerequisites
- Godot Engine 4.4.1 or later
- Compatible with Windows, macOS, Linux, and Android

### Running the Project
1. Open the project folder in Godot Engine 4.4
2. Press F5, or run `scenes/app_root.tscn` directly
3. The splash screen plays, followed by the landing screen
4. Tap or click to proceed into the game level

### Controls
- **Inspect Object**: Tap / left-click on a 3D object
- **Camera Orbit**: Single finger drag (mobile) / left-click drag (desktop)
- **Camera Zoom**: Pinch (mobile) / mouse wheel (desktop)
- **Pause**: ESC key or pause button

---

## Project Structure

```
Traffic Infraction Simulator/
├── scenes/
│   ├── app_root.tscn           # Application entry point
│   ├── intersection/
│   │   ├── game_level_base.tscn  # Base level template (camera, manager, ground)
│   │   └── OverheadTrafficLight.tscn
│   ├── levels/
│   │   └── Level_1.tscn        # First playable level (road scene with ambulance)
│   ├── cameras/
│   │   └── CameraRig.tscn      # Orbit camera prefab
│   ├── ui/
│   │   ├── ui_game_hud.tscn    # In-game HUD (score, message feed)
│   │   ├── ScoreDisplay.tscn   # Infraction scoring overlay
│   │   ├── LandingScreen.tscn
│   │   ├── PauseOverlay.tscn
│   │   └── LevelOver.tscn
│   └── SplashScreen.tscn
├── scripts/
│   ├── app_controller.gd             # Root app lifecycle manager
│   ├── main_landing_level.gd         # Level base controller
│   ├── gameplay_manager.gd           # Session state and spawning (legacy — partial)
│   ├── incident_inspection_action.gd # Clickable infraction node (extends Clickable3D)
│   ├── infraction_data.gd            # Data container for infraction metadata
│   ├── infraction_score_manager.gd   # Scoring, false positives, round completion
│   ├── infraction_score_display.gd   # UI controller for scoring overlay
│   ├── clickable_3d.gd               # Base class for tappable 3D objects
│   ├── mobile_clickable_3d_manager.gd# Raycast manager for touch/click input
│   ├── level_input_handler.gd        # Alternate mouse input system (currently orphaned)
│   ├── ui_game_hud.gd                # HUD controller
│   ├── screen_landing.gd             # Landing screen controller
│   ├── splash_screen_controller.gd   # Splash screen with optional video
│   ├── camera_rig.gd                 # Orbit camera logic
│   └── PauseOverlayController.gd
├── configs/
│   └── levels/                 # LevelConfig .tres resource files
└── assets/
    ├── kenney_city-kit-roads/  # Road tile assets
    ├── kenney_car-kit/         # Vehicle models
    └── kenney_ui-pack/         # UI assets and fonts
```

---

## Architecture

### App Lifecycle
```
app_root.tscn (AppController)
  ├── SplashScreen  →  plays on launch, emits splash_completed
  ├── LandingScreen →  waits for tap, emits start_game_requested
  ├── LevelContainer → holds the instantiated level at runtime
  └── GameHUD        → shown during gameplay, receives score updates
```

### Per-Level Structure
```
game_level_base.tscn (MainLandingLevel)
  ├── GameplayManager          → session state, spawn timers (legacy from fork)
  ├── Clickable3DManager       → MobileClickable3DManager, handles all tap raycasts
  ├── CameraRig                → orbit camera
  ├── UI Menu / PauseOverlay
  └── [Level scene instanced here, e.g. Level_1.tscn]
        ├── RoadNodes           → environment geometry
        ├── OverheadTrafficLight
        └── Infraction_1 (IncidentInspectionAction)
              ├── [3D model, e.g. ambulance.glb]
              └── StaticBody3D / CollisionShape3D
```

### Infraction Detection Flow
```
Player tap
  → MobileClickable3DManager._input()
  → Raycast into scene
  → Hit collider parent checked for Clickable3D
  → IncidentInspectionAction.on_click()
  → InfractionScoreManager.register_infraction_found(node name)
  → Signals: score_updated, infraction_found, round_completed
  → InfractionScoreDisplay updates UI
```

### Scoring System
- `InfractionScoreManager` auto-detects `IncidentInspectionAction` nodes in the scene tree at round start
- Each correct identification: `+10 points`
- Each false positive: `-5 points`
- Max false positives: `3` (configurable via export)
- Star thresholds calculated as percentages of the perfect score (40% / 70% / 100%)
- Round ends on: all found, battery depleted (false positive limit reached), or time expired

---

## Known Issues (MVP Backlog)

See `DEVELOPMENT_NOTES.md` for detailed context and proposed fixes.

- `InfractionScoreManager` returns `total_infractions = 0` on init because the auto-detect searches for `IncidentInspectionAction` class nodes but the scene structure may not match — needs validation
- `ScoreDisplay.tscn` and `InfractionScoreManager` are not yet added to `game_level_base.tscn`
- `level_input_handler.gd` (mouse-based, collision-layer system) is orphaned — the active input system is `mobile_clickable_3d_manager.gd`
- False positives only fire on drag-then-release; tapping a non-infraction environment object currently does nothing
- `gameplay_manager.gd` contains vehicle/pedestrian spawning logic carried over from the fork that is not relevant to this game mode

---

## Platform Support

- **Desktop**: Windows, macOS, Linux
- **Mobile**: Android (primary target — touch controls)
- **Web**: Not currently targeted

---

## License

All Rights Reserved. Proprietary and confidential.
