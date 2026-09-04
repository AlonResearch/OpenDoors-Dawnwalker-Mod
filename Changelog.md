# Changelog

All notable changes to the **Open Doors** mod for *The Blood of Dawnwalker* will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-09-04

### Changed
- **Realistic Passive Door Lifecycle**:
  - Removed startup door-opening sweeps. Unvisited doors now remain 100% naturally closed until the player approaches and pushes them open.
  - Defused `InvisibleWallForCombat` and `LockedObstacle` by setting collision to `NoCollision (0)`, collision response to all channels to `Ignore (0)`, zeroing box extents to `(0, 0, 0)`, and moving the obstacle away from the doorway threshold.
  - Intercepted `SetDoorState` to redirect combat closure attempts (`Locked` / `WasSystemicallyClosed = true`) to `OpenEvenInCombat (1)` while clearing closure flags.
  - Added pre-defusal hook on `OnApproachTriggerBeginOverlap` for immediate threshold cleanliness on approach.
  - Re-scoped `F8` to a non-intrusive read-only diagnostic inspector for the nearest door.

## [1.0.0] - 2026-09-04
 
### Added
- **Fully Autonomous Passive Door Management**:
  - Eliminated manual hotkeys (F8 is now strictly an optional diagnostic status check).
  - Automatically configures all doors across the active world and newly streamed level cells (`InitGameState`).
  - Automatically neutralizes `InvisibleWallForCombat` and `LockedObstacle` on all non-quest doors.
  - Corrected `EDoorState` enum definition from live UE4SS memory reflection:
    - `0 = Open`
    - `1 = OpenEvenInCombat` (True combat persistence state)
    - `2 = Locked`
    - `3 = KeyLocked` (Narrative quest lock)
  - Intercepts native `SetDoorState` events to override systemic closure attempts to `OpenEvenInCombat (1)`.
  - Strictly preserves narrative quest locks (`KeyLocked = 3`).

## [0.3.0] - 2026-09-04

### Added
- **Promote-on-Open Native Lifecycle Architecture (`mods/OpenDoors/scripts/main.lua`)**:
  - Unvisited and closed doors remain completely natural until the player traverses them.
  - **Hook `OnDoorStartedOpening`**: The moment a player pushes through a door, the mod immediately sets `DoorState = OpenEvenInCombat (3)` and `bForceDoorWideOpen = true`.
  - **Hook `OnDoorStartedClosing`**: Intercepts artificial combat closing attempts on opened doors and keeps them open.
  - **Hook `NotifyDoorStateChanged`**: Prevents out-of-band transitions to `Locked (2)` on non-narrative doors.
  - **Hook `SetDoorState`**: Comprehensive state override for `Locked (2)` and `WasSystemicallyClosed = true` to `OpenEvenInCombat (3)`.
  - **Emergency & Diagnostic Hotkey (`F8`)**: Bound asynchronous keybind to log all door instances in active memory to `UE4SS.log` and unlock any non-key doors if stuck.
  - **Strict Narrative Lock Protection**: Doors with `EDoorState::KeyLocked (5)` are 100% untouched across all hooks.

## [0.2.3] - 2026-09-04

### Added
- **Integration of Dawnwalker-Specific UE4SS (Mod #18)**:
  - Deployed community-verified UE4SS v3.0.1 package specifically calibrated for *The Blood of Dawnwalker*.
  - Configured `ue4ss/VTableLayout.ini` with narrow `UEngine::LoadMap` offset override at `0x4F0`.
  - Added build-tested signatures for `FName_Constructor` and `ProcessLocalScriptFunction`.
  - Linked `mods/OpenDoors` to `game/Dawnwalker/Binaries/Win64/ue4ss/Mods/OpenDoors` via directory junction.
  - Enabled `OpenDoors : 1` in `mods.txt` and `mods.json`.

### Fixed
- **Startup Access Violation (`0xc0000005`)**:
  - Eliminated the startup crash previously caused by generic/uncalibrated reflection scanners by deploying the official game-tuned compatibility framework. Verified complete startup, object construction, and mod initialization in `UE4SS.log`.

---

## [0.2.2] - 2026-09-04

### Fixed
- **Startup Crash Resolution (`0xc0000005`)**:
  - Identified faulting module offset in minidump caused by default UE4SS C++ debugger mods (`KismetDebuggerMod`, `EventViewerMod`) hooking early into UE 5.5 Kismet bytecode, and DirectX 12 ImGui overlay conflicts with the game's active DLSS/FSR frame generation pipeline.
  - Disabled all bundled default C++ mods in `mods.txt` leaving exclusively `OpenDoors : 1`.
  - Configured `UE4SS-settings.ini` to safe headless mode (`ConsoleEnabled = 0`, `GuiConsoleEnabled = 0`, `bUseUObjectArrayCache = false`).

---

## [0.2.1] - 2026-09-04

### Added
- **Zero-Polling & Performance Standards**: Added Section 4 to `AGENTS.md` and updated `GroundTruth.md` enforcing a strict zero-polling architectural rule:
  - Banned continuous `Tick` hooks, polling loops, and distance scanner threads.
  - Guaranteed zero idle CPU overhead: logic executes strictly on-demand when the native `SetDoorState` event fires.

---

## [0.2.0] - 2026-09-04

### Added
- **Core Runtime Hook (`mods/OpenDoors/scripts/main.lua`)**:
  - Implemented dynamic hook on `UDogwoodBlueprintFunctionLibrary::SetDoorState`.
  - **Narrative Lock Guard**: Explicitly inspects `InNewState == EDoorState.KeyLocked` (5). When detected, the hook returns immediately, ensuring story quest gates and key-locked doors require their legitimate keys.
  - **Systemic Lock Neutralization**: Automatically intercepts calls where `WasSystemicallyClosed == true`, clearing the systemic flag and promoting `InNewState` to `EDoorState.OpenEvenInCombat` (3).
  - **Push-to-Open Promotion**: Automatically promotes normal door opening events (`EDoorState.Open = 1`) to `OpenEvenInCombat` (3) so the door naturally remains open if combat begins later.
- **Loader Deployment & Junction**:
  - Deployed UE4SS (UE 5.5 experimental build) via `dwmapi.dll` into `game/Dawnwalker/Binaries/Win64/`.
  - Linked `game/Dawnwalker/Binaries/Win64/ue4ss/Mods/OpenDoors` directly to `mods/OpenDoors` via a Windows directory junction.
  - Enabled `OpenDoors : 1` in `mods.txt`.

---

## [0.1.4] - 2026-09-04

### Changed
- **Door-Centric Architecture**: Refactored the mod logic to focus exclusively on the Door actor and its native push-to-open / stumble-to-open triggers (`DoorTrigger`), leaving player combat input 100% vanilla.

---

## [0.1.3] - 2026-09-04

### Added
- **Discovery of Native Door Primitives**: Uncovered native `EDoorState` reflection enum in `Dawnwalker.exe` (`OpenEvenInCombat = 3`), `SetDoorState`, and `WasSystemicallyClosed`.

---

## [0.1.2] - 2026-09-04

### Added
- **Update-Resilient Engineering Standards**: Added explicit rules to `AGENTS.md` and `GroundTruth.md` establishing a "Native Primitives First" development philosophy.

---

## [0.1.1] - 2026-09-04

### Changed
- **Privacy & Path Normalization**: Stripped all machine-specific absolute paths. Standardized on relative `game/` junction.

---

## [0.1.0] - 2026-09-04

### Added
- **Repository Setup**: Initialized Git repository and documentation suite.
