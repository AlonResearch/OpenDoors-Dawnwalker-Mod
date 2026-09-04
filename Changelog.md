# Changelog

All notable changes to the **Open Doors** mod for *The Blood of Dawnwalker* will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- Deploy UE4SS runtime hook into `game/Dawnwalker/Binaries/Win64/`.
- Enumerate live `UObject` and `UFunction` names for doors and encounter barriers.
- Implement Lua hook to prevent automatic door closure and barrier collision engagement.

---

## [0.1.2] - 2026-09-04

### Added
- **Update-Resilient Engineering Standards**: Added explicit rules to `AGENTS.md` and `GroundTruth.md` establishing a "Native Primitives First" development philosophy:
  - Banned brittle memory addresses, AOB pattern-scans, and compiler-dependent offsets.
  - Standardized on high-level Unreal Engine reflection symbols (`FName`), root parent archetype targets, and native property manipulation (`bCanBeLocked`, collision profiles) to ensure forward compatibility across future game updates.

---

## [0.1.1] - 2026-09-04

### Changed
- **Privacy & Path Normalization**: Stripped all machine-specific absolute paths from all repository documentation (`README.md`, `GroundTruth.md`, `AGENTS.md`).
- **Junction Standard**: Standardized on relative `game/` path using a local directory junction (`mklink /J game <path>`), ignored via `.gitignore`.
- **Documentation Refactoring**: Lean, unbloated documentation structure aligned with project standards (`GroundTruth.md`, `Changelog.md`, `AGENTS.md`).

---

## [0.1.0] - 2026-09-04

### Added
- **Repository Setup**: Initialized Git repository, `README.md`, `GroundTruth.md`, `AGENTS.md`, `Changelog.md`, and `.gitignore`.
- **Target Profiling**: Identified Unreal Engine 5.5.4.0 (`dw1-pc-256181-shipping-patch2-all-CL-256181`) and IoStore v8 container format (AES-256 encrypted, compressed).
- **Gameplay Analysis**: Analyzed gameplay footage to isolate the doorway trigger sequence and automatic closure mechanism in the guard post stone tower.
