# Changelog

All notable changes to the **Open Doors** mod for *The Blood of Dawnwalker* will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- Deploy runtime reflection dumper / UE4SS to enumerate door, encounter, and collision classes.
- Implement runtime hook to intercept automatic door closure events.
- Disable doorway collision barriers for interior fortress transitions.

---

## [0.1.0] - 2026-09-04

### Added
- **Repository Setup**: Initialized project repository with structured documentation:
  - `README.md`: User-facing philosophy, rationale, and feature roadmap.
  - `GROUND_TRUTH.md`: Technical documentation of the game engine, container formats, and trigger mechanics.
  - `AGENTS.md`: Agent operating rules enforcing strict ground truth synchronization, pruning of stale data, and changelog updates.
  - `CHANGELOG.md`: Iteration tracking.
- **Engine & Binary Profiling**:
  - Identified game executable as Unreal Engine 5.5.4.0 (`dw1-pc-256181-shipping-patch2-all-CL-256181`) developed by Rebel Wolves.
  - Analyzed container format: IoStore v8 (`.pak`, `.ucas`, `.utoc`) with 256 KB compression blocks and AES-256 encryption.
- **Gameplay Footage Analysis**:
  - Analyzed user video (`Dawnwalker 2026.09.04 - 17.15.58.03.mp4`).
  - Isolated exact trigger event during "The Firebrand" quest at the guard post stone tower ("Rayko, the Incorruptible" encounter).
  - Identified threshold collision trigger causing automatic door closure and player lock-in.

### Deprecated
- *None in this release (initial setup).*
