# AGENTS.md

Minimal, essential operational guidelines for AI agents working in the **Open Doors** mod repository for *The Blood of Dawnwalker*.

---

## 1. Core Guidelines & Documentation Maintenance

- **`GroundTruth.md` (Live State Document)**:
  - You MUST update `GroundTruth.md` whenever you change mod logic, architecture, reverse-engineering findings, or hook definitions.
  - Explain ONLY current active implementation, and **strictly prune deprecated logic and stale references**.
  - Keep target structures, verified engine offsets/classes, and active hooks accurate and concise.

- **`Changelog.md` (Live Change Log)**:
  - You MUST record changes in `Changelog.md` with every iteration before making a commit.
  - Follow standard `[YYYY-MM-DD]` entry format with categories: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`.

- **`AGENTS.md` Lean Principle**:
  - Keep this file (`AGENTS.md`) minimal. Only add rules that address persistent behavioral friction or critical invariants.

---

## 2. Privacy & Environment Standards

- **Zero Machine-Specific Paths (Public GitHub Rule)**:
  - Never hardcode absolute user/machine paths (e.g. drive letters or personal usernames) in committed repository files.
  - Always use the relative linked directory path `game/` (e.g. `game/Dawnwalker/Binaries/Win64/Dawnwalker.exe`).

- **Workspace Junction Setup**:
  - The local game installation is accessed via a directory junction:
    ```cmd
    mklink /J game "<path-to-Dawnwalker-root>"
    ```
  - The `game/` folder is excluded by `.gitignore` and must never be committed.

---

## 3. Resilience & Native Primitives Rule (Update-Proof Philosophy)

- **Zero Brittle Memory Offsets**: Never rely on hardcoded memory addresses, assembly patch patterns (AOB), or compiler-specific function offsets that break when the game executable is updated or recompiled.
- **Use the Game's Native Primitives**:
  - Target the game's high-level engine primitives: the Unreal Engine reflection system (`UClass`, `UFunction`, `FProperty`), base actor properties (e.g. door lock flags, collision profiles), and native gameplay tags.
  - Hook functions by symbolic name (`FName`) or manipulate base component properties rather than patching compiled code.
- **Root-Level Archetype Target**: Target the master/parent door and encounter classes (e.g. `BP_DoorBase` or `ARebelDoor`) so all derived instances across the entire game world inherit the behavior naturally without per-level overrides.
- **Non-Destructive Integrity**: Never overwrite, replace, or delete original game files.
