# Changelog

All notable changes to the **Open Doors** mod for *The Blood of Dawnwalker* will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- Deploy UE4SS runtime loader to `game/Dawnwalker/Binaries/Win64/`.
- Implement Lua hook in `mods/OpenDoors/scripts/main.lua` to promote opened doors to `EDoorState::OpenEvenInCombat` and suppress `WasSystemicallyClosed`.
- Test in-game behavior during the "Rayko, the Incorruptible" guard tower encounter.

---

## [0.1.3] - 2026-09-04

### Added
- **Discovery of Native Door Primitives**:
  - Uncovered native `EDoorState` reflection enum in `game/Dawnwalker/Binaries/Win64/Dawnwalker.exe`, revealing `EDoorState::OpenEvenInCombat` (value 3).
  - Identified `UDogwoodBlueprintFunctionLibrary::SetDoorState` and the `WasSystemicallyClosed` parameter responsible for automated encounter door locks.
  - Isolated the combat interaction blocker tag `Player.Input.BlockInteractions` and interaction dispatch framework (`DISInteraction`).
- **Technical Strategy Finalization**: Formulated the 3-pillar native primitive approach in `GroundTruth.md` (State Promotion, Systemic Closure Interception, Combat Interaction Unlock).

---

## [0.1.2] - 2026-09-04

### Added
- **Update-Resilient Engineering Standards**: Added explicit rules to `AGENTS.md` and `GroundTruth.md` establishing a "Native Primitives First" development philosophy.

---

## [0.1.1] - 2026-09-04

### Changed
- **Privacy & Path Normalization**: Stripped all machine-specific absolute paths from all repository documentation.
- **Junction Standard**: Standardized on relative `game/` path using a local directory junction (`mklink /J game <path>`).
- **Documentation Refactoring**: Lean, unbloated documentation structure aligned with project standards.

---

## [0.1.0] - 2026-09-04

### Added
- **Repository Setup**: Initialized Git repository and documentation suite.
- **Target Profiling**: Identified Unreal Engine 5.5.4.0 and IoStore v8 container format.
