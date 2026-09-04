# Changelog

All notable changes to the **Open Doors** mod for *The Blood of Dawnwalker* will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- Deploy UE4SS runtime loader to `game/Dawnwalker/Binaries/Win64/`.
- Implement Lua hook in `mods/OpenDoors/scripts/main.lua` to:
  1. Intercept `DogwoodBlueprintFunctionLibrary::SetDoorState` and suppress `WasSystemicallyClosed == true`.
  2. Maintain opened doors in `EDoorState::OpenEvenInCombat`.
  3. Ensure `DoorTrigger` keeps doors push-to-open during combat.
- In-game verification in the "Rayko, the Incorruptible" guard tower encounter.

---

## [0.1.5] - 2026-09-04

### Added
- **Story-Lock Preservation Guarantee**:
  - Integrated `EDoorType::Quest` and `EDoorState::KeyLocked` into the architecture.
  - Confirmed that story-blocked doors (requiring keys or quest milestones) are locked with `WasSystemicallyClosed = false` and remain completely untouched by the mod.
  - Only doors that were legitimately openable and get slammed shut by combat encounter triggers (`WasSystemicallyClosed = true`) are kept open.

---

## [0.1.4] - 2026-09-04

### Changed
- **Door-Centric Architecture**: Refactored the mod logic to focus exclusively on the Door actor and its native push-to-open / stumble-to-open triggers (`DoorTrigger`), leaving player combat input 100% vanilla.
- **Push-to-Open Continuity**: Confirmed that doors open automatically upon physical approach without requiring button presses. Ensured the mod allows doors to be pushed open in combat without prompts.

### Deprecated
- **Player Combat Interaction Modification**: Deprecated and pruned any attempts to alter `Player.Input.BlockInteractions` or player interaction prompts during combat, preventing unwanted UI prompts (e.g. loot) or input interference during combat.

---

## [0.1.3] - 2026-09-04

### Added
- **Discovery of Native Door Primitives**:
  - Uncovered native `EDoorState` reflection enum in `game/Dawnwalker/Binaries/Win64/Dawnwalker.exe`, revealing `EDoorState::OpenEvenInCombat` (value 3).
  - Identified `UDogwoodBlueprintFunctionLibrary::SetDoorState` and the `WasSystemicallyClosed` parameter responsible for automated encounter door locks.
  - Isolated the combat interaction blocker tag `Player.Input.BlockInteractions` and interaction dispatch framework (`DISInteraction`).

---

## [0.1.2] - 2026-09-04

### Added
- **Update-Resilient Engineering Standards**: Added explicit rules to `AGENTS.md` and `GroundTruth.md` establishing a "Native Primitives First" development philosophy.

---

## [0.1.1] - 2026-09-04

### Changed
- **Privacy & Path Normalization**: Stripped all machine-specific absolute paths from all repository documentation.
- **Junction Standard**: Standardized on relative `game/` path using a local directory junction (`mklink /J game <path>`).

---

## [0.1.0] - 2026-09-04

### Added
- **Repository Setup**: Initialized Git repository and documentation suite.
- **Target Profiling**: Identified Unreal Engine 5.5.4.0 and IoStore v8 container format.
