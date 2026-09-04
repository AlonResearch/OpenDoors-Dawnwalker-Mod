# Changelog

All notable changes to the **Open Doors** mod for *The Blood of Dawnwalker* will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- In-game verification of the "Rayko, the Incorruptible" guard tower encounter.
- Verify door push-to-open responsiveness during active combat.
- Standalone release package script for players.

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
