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

## 3. Game Environment Facts & Mod Discipline

- **Target Engine**: Unreal Engine 5.5.4 (`dw1-pc-256181-shipping-patch2-all-CL-256181`, Rebel Wolves).
- **Executable**: `game/Dawnwalker/Binaries/Win64/Dawnwalker.exe`.
- **Packaging Format**: IoStore v8 (`game/Dawnwalker/Content/Paks/Dawnwalker-Windows.*`), compressed (256 KB) and AES-256 encrypted.
- **Reverse Engineering Rule**:
  - Favor lightweight runtime hooks (e.g. UE4SS / reflection-based interception) over invasive asset repacking where possible.
  - Never overwrite or delete original game files.
