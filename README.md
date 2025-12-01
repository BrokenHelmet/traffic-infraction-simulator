# Traffic Control Simulator

A 3D traffic management simulation game built with Godot 4.4, where players control traffic lights and manage vehicle flow through intersections.

![Version](https://img.shields.io/badge/version-1.16-blue)
![Godot](https://img.shields.io/badge/Godot-4.4-green)
![License](https://img.shields.io/badge/license-All%20Rights%20Reserved-red)

## Game Overview

Take control of traffic intersections and keep vehicles moving safely and efficiently. Master the art of traffic management through various challenging scenarios, from simple crossroads to complex multi-lane intersections.

### Key Features
- **Realistic Traffic Simulation**: Vehicles with varying speeds and behaviors
- **Pedestrian System**: Integrated pedestrian agents with crosswalk behavior and walk signals
- **Interactive Traffic Controls**: Click-and-hold traffic light system
- **Progressive Difficulty**: Multiple levels with increasing complexity
- **3D Environment**: Immersive overhead perspective with orbit camera controls
- **Configurable Levels**: Data-driven level system with customizable parameters
- **Multi-Vehicle Types**: Sedans, trucks, and emergency vehicles with unique characteristics
- **Professional Landing Screen**: Touch-to-start functionality with cross-platform support

## Getting Started

### Prerequisites
- Godot Engine 4.4 or later
- Compatible with Windows, macOS, Linux, and Android

### Installation
1. Clone this repository
2. Open the project in Godot Engine
3. Press F5 to run the game

### Controls
- **Traffic Lights**: Click and hold to change traffic light states
- **Camera Navigation**: Previous/Next/Reset buttons for predefined camera positions
- **Orbit Camera**: 
  - Desktop: Left-click drag to rotate, mouse wheel to zoom
  - Mobile: Single finger drag to rotate, pinch-to-zoom
- **Menu Navigation**: Touch anywhere to start from landing screen

## Project Structure

```
Traffic Control Simulator/
├── scenes/
│   ├── intersection/     # Main game scenes
│   ├── vehicles/         # Vehicle prefabs
│   ├── pedestrians/      # Pedestrian prefabs
│   └── ui/              # User interface elements
├── scripts/
│   ├── Main.gd          # Main game controller
│   ├── CameraManager.gd # Camera positioning and navigation system
│   ├── LevelConfig.gd   # Level configuration system
│   ├── TrafficLight.gd  # Traffic light logic
│   ├── Vehicle.gd       # Vehicle behavior
│   ├── Pedestrian.gd    # Pedestrian behavior
│   └── WorldSpaceButton.gd # 3D UI buttons
├── configs/             # Level configuration files
├── addons/              # Third-party plugins
└── android/             # Android build configuration
```

## Configuration System

The game uses a flexible configuration system for creating levels:

### Level Configuration (LevelConfig.gd)
Each level is defined by a `.tres` resource file containing:

**Basic Info:**
- Level name and description
- Welcome message and difficulty

**Vehicle Management:**
- Maximum concurrent vehicles
- Spawn rate and speed ranges
- Emergency vehicle settings

**Pedestrian Management:**
- Maximum concurrent pedestrians
- Pedestrian spawn rates and walking speeds
- Elderly and child pedestrian types

**Objectives & Limits:**
- Time limits and success conditions
- Collision tolerances
- Maximum wait times

### Example Usage
```gdscript
# Get random vehicle speed from config
var speed = level_config.get_random_vehicle_speed()

# Check if emergency vehicle should spawn
if level_config.should_spawn_emergency_vehicle():
	spawn_emergency_vehicle()
```

## Development Status

### Completed Features
- Professional landing screen with touch-to-start functionality
- Interactive traffic light control system with real-time vehicle response
- Vehicle spawning and movement with collision detection
- **Pedestrian spawning and management system with crosswalk behavior**
- Multi-vehicle type system (sedans, trucks, emergency vehicles)
- Level configuration system (resource-based, no class_name dependency)
- Camera positioning system with smooth transitions
- Orbit camera controls (touch/mouse rotation and zoom)
- 3D world-space UI buttons with cross-platform support
- Level selection menu with progressive difficulty scaling
- Vehicle-to-vehicle collision detection and following distances
- Multi-vehicle spawning system with intelligent batch controls
- Android touch support with comprehensive input handling
- **Pedestrian path discovery and walk signal integration**

### Current Development Focus
See DEVELOPMENT_NOTES.md for detailed technical information. Major remaining items:

- Time limits and level completion objectives
- Performance scoring and violation tracking system  
- Emergency vehicle priority override system
- Difficulty multipliers and level progression
- Sound system integration
- Visual feedback enhancements
- Tutorial system for new players

## Technical Details

### Architecture
- **MVC Pattern**: Clear separation between game logic, UI, and data
- **Resource-Based Configs**: Data-driven level design using Godot resources
- **Component System**: Modular scripts for different game elements

### Key Scripts
- `Main.gd`: Central game coordinator and level loader
- `LevelConfig.gd`: Level configuration and gameplay parameters
- `TrafficLight.gd`: Interactive traffic control logic
- `WorldSpaceButton.gd`: 3D UI system for traffic controls

### Known Limitations
- Custom `class_name` system has compatibility issues (workaround implemented)
- Some legacy configuration files need migration to new system

## Platform Support

- **Desktop**: Windows, macOS, Linux
- **Mobile**: Android (touch controls optimized)
- **Web**: WebGL support (planned)

## Contributing

This project is under active development. Please check the TODO comments in the codebase for areas that need attention.

## License

All Rights Reserved. This project and its contents are proprietary and confidential.

## Roadmap

### Phase 1: Core Gameplay (Current)
- Basic traffic control mechanics
- Vehicle spawning and movement
- Configuration system foundation

### Phase 2: Enhanced Features (Next)
- Visual setup (camera positions, UI layout)
- Environmental conditions (weather, time)
- Tutorial and guidance system

### Phase 3: Polish & Expansion (Future)
- Multiple intersection types
- Advanced vehicle AI
- Performance optimization
- Audio/visual effects

---

**Built with ❤️ using Godot Engine**
