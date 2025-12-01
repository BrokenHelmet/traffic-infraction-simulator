# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Essential Commands

### Godot Development

#### Linux (Ubuntu) Environment
```bash
# Set Godot path (required for all operations)
export GODOT_44="/home/daud/.var/app/io.github.MakovWait.Godots/data/godot/app_userdata/Godots/versions/Godot_v4_4_1-stable_linux_x86_64/Godot_v4.4.1-stable_linux.x86_64"

# Launch Godot editor
$GODOT_44 --editor .

# Run the game directly
$GODOT_44 scenes/intersection/TutorialLevel.tscn

# Export builds (requires preset names from export_presets.cfg)
$GODOT_44 --headless --export-release "Windows Desktop" builds/Windows/
$GODOT_44 --headless --export-release "Android" builds/android/

# Run headless for automation/testing
$GODOT_44 --headless
```

#### Windows Environment
```powershell
# Set Godot path (PowerShell) - Update path to your Godot installation
$env:GODOT_44 = "C:\\Godot\\Godot_v4.4.1-stable_win64.exe"

# Alternative: Add to PATH or use direct path
# $GODOT_44 = "godot"  # If Godot is in PATH

# Launch Godot editor
& $env:GODOT_44 --editor .

# Run the game directly
& $env:GODOT_44 scenes/intersection/TutorialLevel.tscn

# Export builds (requires preset names from export_presets.cfg)
& $env:GODOT_44 --headless --export-release "Windows Desktop" builds/Windows/
& $env:GODOT_44 --headless --export-release "Android" builds/android/

# Run headless for automation/testing
& $env:GODOT_44 --headless
```

#### Command Prompt (Windows Alternative)
```cmd
# Set Godot path (cmd) - Update path to your Godot installation
set GODOT_44=C:\\Godot\\Godot_v4.4.1-stable_win64.exe

# Launch Godot editor
%GODOT_44% --editor .

# Run the game directly
%GODOT_44% scenes/intersection/TutorialLevel.tscn

# Export builds
%GODOT_44% --headless --export-release "Windows Desktop" builds/Windows/
%GODOT_44% --headless --export-release "Android" builds/android/
```

### Testing Commands

#### Linux/macOS
```bash
# Run individual test files
$GODOT_44 --script tests/test_traffic_light_behavior.gd

# Test config loading system (use T key in-game)
# Press T in main menu to open config testing panel
```

#### Windows (PowerShell)
```powershell
# Run individual test files
& $env:GODOT_44 --script tests/test_traffic_light_behavior.gd

# Test config loading system (use T key in-game)
# Press T in main menu to open config testing panel
```

### Level Configuration Testing

#### Linux/macOS
```bash
# Load and validate all level configs
$GODOT_44 --script -e "
var configs = ['res://configs/levels/tutorial_01_easy.tres', 'res://configs/levels/tutorial_02_easy_medium.tres']
for path in configs:
  var config = ResourceLoader.load(path)
  if config and config.has_method('is_valid'): print('✅', path)
  else: print('❌', path)
"
```

#### Windows (PowerShell)
```powershell
# Load and validate all level configs
& $env:GODOT_44 --script -e "
var configs = ['res://configs/levels/tutorial_01_easy.tres', 'res://configs/levels/tutorial_02_easy_medium.tres']
for path in configs:
  var config = ResourceLoader.load(path)
  if config and config.has_method('is_valid'): print('✅', path)
  else: print('❌', path)
"
```

## High-Level Architecture

### Core Systems Overview
This is a **3D traffic management simulation** with multiple interconnected systems:

**Main.gd** - Central coordinator that orchestrates all systems:
- Level loading and configuration management
- Camera system initialization via CameraManager
- Game state management via GameManager
- UI creation and navigation flow

**CameraManager.gd** - Legacy camera system (350+ lines):
- FlyCamera integration with orbit controls
- Multi-position camera navigation from level configs
- Touch/mouse controls for mobile and desktop
- Smooth transitions and position management

**CameraRig.gd** - Modern camera system (1400+ lines):
- Pivot-based 3D camera with spherical coordinates
- Enhanced navigation UI with focus modes
- Toggle system for UI visibility control
- Traffic light auto-detection for camera positions
- Debug mode support for development

**GameManager.gd** - Vehicle spawning and gameplay mechanics:
- Data-driven vehicle spawning using LevelConfig
- Vehicle type configuration system with weighted selection
- Path occupation tracking (one vehicle per path)
- Traffic light integration and collision detection

**ScoreManager.gd** - "Time is Money" scoring system:
- Point-based efficiency scoring with time decay (vehicles: 10→-10 points, pedestrians: 5→-5 points)
- Dual-layer architecture: minimum completion requirements + efficiency star ratings
- Real-time agent tracking and movement state monitoring
- Level completion detection and star rating calculation (1-3 stars based on 30%, 60%, 100% efficiency)

**LevelConfig.gd** - Resource-based configuration system:
- **CRITICAL**: Uses generic `Resource` type (no `class_name` due to environment issues)
- Stores all gameplay parameters, camera positions, difficulty settings
- Validates and provides helper methods for gameplay integration

### Data Flow Architecture
```
LevelConfig.tres → Main.gd → CameraRig/CameraManager + GameManager + ScoreManager
                            ↓                         ↓                ↓
                    Camera Positions              Vehicle Spawning   Scoring Config
                    UI Navigation                 Traffic Control    Agent Tracking
                    Toggle Control                     ↓                ↓
                            ↓                 WorldSpaceButton ← TrafficLight.gd
                    CameraRig Navigation      (3D UI System)     (Light Control)
                    (Modern System)                  ↓                ↓
                            ↓                     Vehicle.gd ← Path3D (Movement)
                    Level Selection Toggle    (Collision Detection + Scoring Integration)
                                                        ↓
                                                  ScoreDisplay UI
                                                  (Real-time Score, Progress, Stars)
```

### Key Architectural Principles
1. **Resource-Based Configuration**: All levels use `.tres` files with LevelConfig.gd script
2. **Component Separation**: Camera, Game, and UI management are separate systems
3. **FlyCamera Integration**: Uses proper API (`set_rot()`/`get_rot()`) instead of direct manipulation
4. **Mobile-First Design**: Touch controls and responsive UI for cross-platform deployment

### Critical Technical Constraints
- **NO class_name declarations**: Use generic `Resource` types due to Godot environment compatibility
- **Always validate methods**: Use `has_method()` before calling custom methods
- **FlyCamera API compliance**: Never directly manipulate `rotation_degrees`, use `set_rot()/get_rot()`
- **Path occupation logic**: Maximum one vehicle per Path3D to prevent collisions

## Project Structure Essentials

### Core Scene Hierarchy
- `scenes/Main.tscn` - Application entry point with landing screen
- `scenes/intersection/TutorialLevel.tscn` - Main gameplay scene with traffic intersection
- `scenes/vehicles/SaloonBase.tscn` - Vehicle prefab with CharacterBody3D
- `scenes/pedestrians/PedestrianBase.tscn` - Pedestrian prefab with simplified movement
- `scenes/ui/` - UI components including WorldSpaceButton for 3D controls

### Configuration System
- `configs/levels/` - Level configuration files (.tres) using LevelConfig.gd
- `configs/vehicle_types/` - Vehicle type configurations for different vehicle behaviors
- All configs use `type="Resource"` in .tres files (not custom class names)

### Scripts Organization
- `scripts/Main.gd` - Central controller with CameraRig integration
- `scripts/CameraRig.gd` - Modern pivot-based camera system (1400+ lines)
- `scripts/CameraManager.gd` - Legacy camera system (750+ lines with orbit controls)
- `scripts/SplashScreenController.gd` - Splash screen with video support
- `scripts/GameManager.gd` - Vehicle and gameplay management
- `scripts/ScoreManager.gd` - "Time is Money" scoring system with point decay
- `scripts/ScoreDisplayController.gd` - Real-time scoring UI controller
- `scripts/LevelConfig.gd` - Resource configuration script with scoring requirements
- `scripts/Vehicle.gd` - Vehicle behavior with collision detection and scoring integration
- `scripts/Pedestrian.gd` - Pedestrian behavior with walk signal detection and simplified movement
- `scripts/TrafficLight.gd` - Traffic light control logic

## Level Configuration System

### Creating New Levels
1. Create new `.tres` file in `configs/levels/`
2. Set `script = preload("res://scripts/LevelConfig.gd")`
3. Configure properties: `max_vehicles`, `vehicle_spawn_rate`, `camera_positions`, etc.
4. Add camera positions array with position/rotation dictionaries
5. Test using in-game config panel (T key) or level selector

### Camera Position Format
```gdscript
camera_positions = Array[Dictionary]([{
  "position": Vector3(-12, 10, 20),
  "rotation": Vector3(-30, 0, 0)
}])
```

## Mobile Development

### Android Build Process
1. Configure Android SDK in Godot project settings
2. Use export preset "Android" (already configured)
3. Build: `$GODOT_44 --headless --export-release "Android" builds/android/game.apk`
4. Touch controls are implemented for traffic lights and camera

### Cross-Platform Considerations
- Touch controls work alongside mouse/keyboard
- UI scales for different screen sizes
- Camera orbit system supports both pinch-zoom and mouse wheel

## Common Development Workflows

### Adding New Vehicle Types
1. Create new resource in `configs/vehicle_types/`
2. Follow existing pattern (SedanConfig.tres, TruckConfig.tres)
3. Update GameManager's `_load_vehicle_type_configs()` array
4. Test with different difficulty levels

### Debugging Traffic Issues
- **Enable Targeted Debug Output**: Use script-specific debug flags rather than raw print statements
- **ScoreDisplay Issues**: Check ScoreDisplayController retry mechanism if score/vehicle counts not showing
- **Vehicle Collision Detection**: Enable `debug_collision_detection = true` in Vehicle.gd inspector
- **Traffic Light Behavior**: Enable `debug_light_changes = true` in TrafficLight.gd inspector
- **Raycast Detection Issues**: Enable `debug_raycast = true` in Vehicle.gd for detailed collision detection analysis
- **Traffic Light System**: Traffic lights now use clearance mode for vehicles in intersections
- **Crosswalk Management**: Vehicles in intersection area always continue to clear crosswalk safely
- **UI Creation Issues**: Enable `debug_ui = true` in Main.gd inspector to see runtime UI generation
- **Level Loading Problems**: Enable `debug_level_loading = true` in Main.gd inspector
- **Use level config testing panel (T key)** for configuration validation
- **Console Spam**: Disable all debug flags by default, enable only specific categories as needed

### Performance Testing
- Monitor FPS with 10+ vehicles simultaneously (target: 60fps)
- Test on both desktop and Android for platform-specific issues
- Use level selector to test different traffic densities

### Debug System Workflows

#### Systematic Debug Approach
1. **Start Clean**: Ensure all debug flags are `false` for clean console output
2. **Enable Specific Categories**: Turn on only the debug flags relevant to your issue:
   - `debug_ui` in Main.gd for UI creation issues
   - `debug_level_loading` in Main.gd for config/level loading problems
   - `debug_video` in SplashScreenController for splash screen issues
   - `debug_collision_detection` in Vehicle.gd for traffic behavior issues
3. **Check Script Prefixes**: Debug output includes `[ScriptName-NodeName]` for easy source identification
4. **State-Based Logging**: Debug messages only appear on state changes, not every frame

#### Common Debug Flag Combinations
```gdscript
# For ScoreDisplay timing issues:
ScoreDisplayController: debug_score_search = true, debug_score_display = true

# For vehicle traffic behavior:
Vehicle.gd: debug_collision_detection = true, debug_traffic_lights = true, debug_raycast = true

# For traffic light state debugging:
TrafficLight.gd: debug_light_changes = true, debug_vehicle_detection = true

# For pedestrian behavior:
Pedestrian.gd: debug_collision_detection = true, debug_walk_signals = true

# For UI creation problems:
Main.gd: debug_ui = true, debug_config = true

# For splash screen issues:
SplashScreenController: debug_mode = true, debug_video = true

# For raycast collision detection issues:
Vehicle.gd: debug_raycast = true, debug_collision_detection = true
```

### Scoring System Testing
- Use debug flags in ScoreManager.gd (debug_scoring, debug_completion, debug_time_decay)
- Watch real-time scoring UI in top-right during gameplay
- Test point decay by creating traffic jams (vehicles waiting at red lights)
- Validate completion requirements vs efficiency scoring balance
- Run test_scoring_system.gd for component validation

### CameraRig Toggle System
- **Level Selection Open**: CameraRig UI automatically hidden to prevent confusion
- **Level Selection Closed**: CameraRig UI restored for navigation
- **Debug Mode**: Set `debug_mode = true` in CameraRig inspector for detailed console output
- **Manual Control**: Use `set_camera_rig_enabled()` and `set_ui_visible()` methods for custom control
- **Auto-Detection**: Main.gd automatically finds and manages CameraRig in loaded levels

## Cross-Platform Development

### Platform Compatibility Notes
- **File Paths**: All paths use forward slashes (/) in Godot resource paths (res://)
- **Line Endings**: Repository uses LF (Unix-style) line endings for consistency
- **Case Sensitivity**: Windows is case-insensitive, Linux/macOS are case-sensitive - use consistent casing
- **Export Presets**: Configured for Windows Desktop and Android builds
- **Godot Version**: Project requires Godot 4.4.1 or later on all platforms

### Windows Setup Instructions
1. Download Godot 4.4.1+ from official website
2. Extract to a folder like `C:\Godot\`
3. Update GODOT_44 environment variable in commands above
4. Ensure Windows Defender/antivirus allows Godot execution
5. For Android builds: Configure Android SDK in Godot project settings

### Development Environment Requirements
- **Linux**: Flatpak installation of Godot via io.github.MakovWait.Godots
- **Windows**: Official Godot 4.4.1+ executable
- **Git**: Configure `core.autocrlf=false` to preserve LF line endings
- **IDE**: Any text editor with GDScript support (recommended: VS Code with Godot extension)

## Pause System

### Pause Manager Integration
- **Pause System**: pause-manager addon provides comprehensive pause functionality
- **Input Actions**: ESC key bound to both `ui_cancel` and `pause` actions
- **Pause Modes**: Supports tree-based pausing, group-based pausing, and event handler systems
- **Status**: COMPLETE - Fully integrated with all game systems

### Pause System Commands

#### Testing Pause System
```bash
# Run pause system examples
$GODOT_44 addons/pause-manager/examples/example_scene.tscn
$GODOT_44 addons/pause-manager/examples/example_pause_menu_scene.tscn
```

### Pause System Integration Status
- ✅ **Addon Installation**: Complete pause-manager system installed
- ✅ **Input Configuration**: ESC key pause actions configured
- ✅ **Example Validation**: Test scenes working without errors
- ✅ **Game Integration**: Main.gd integration complete with signal-based control
- ✅ **UI Implementation**: PauseOverlay with Resume/Restart/Menu options
- ✅ **System Pausability**: GameManager, ScoreManager, timers all respect pause
- ✅ **Traffic Light Handling**: State preserved during pause, input disabled
- ✅ **Camera Integration**: CameraRig pause support with control disabling

## Version Information
- **Current Version**: 1.16
- **Godot Version**: 4.4 (project runs on 4.4.1)
- **Target Platforms**: Windows, Linux, macOS, Android
- **Key Plugins**: sk_fly_camera for camera system, pause-manager for pause functionality

## Important Files to Monitor
- `DEVELOPMENT_NOTES.md` - Detailed technical documentation (internal only)
- `README.md` - User-facing project documentation
- `project.godot` - Godot project configuration
- `export_presets.cfg` - Build and export settings
