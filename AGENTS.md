# AGENTS.md — Agent Operating Rules

This repository contains the **Open Doors** mod for *The Blood of Dawnwalker*. All AI agents working in this repository must strictly adhere to the following rules:

---

## 1. Ground Truth Synchronization & Pruning (CRITICAL)

- **Always Update Ground Truth**: Whenever any change to how the mod works or is implemented is made, immediately update [GROUND_TRUTH.md](GROUND_TRUTH.md).
- **Prune Stale Information**: Do **not** leave superseded, deprecated, or obsolete information in `GROUND_TRUTH.md`. When an approach or implementation detail changes, prune out the old text so `GROUND_TRUTH.md` represents strictly the current, verified truth of the codebase and implementation.

---

## 2. Changelog Maintenance

- **Log Every Iteration**: With every implementation change, update [CHANGELOG.md](CHANGELOG.md).
- **Track Deprecations Explicitly**: Explicitly record what was implemented (Added/Changed) and what was deprecated or removed (Deprecated/Removed) so iterative progress can be clearly audited.

---

## 3. Game Environment Facts

- **Target Game**: *The Blood of Dawnwalker* (Rebel Wolves Sp. z o.o.).
- **Engine**: Unreal Engine 5.5.4 (`dw1-pc-256181-shipping-patch2-all-CL-256181`).
- **Binary**: `Dawnwalker\Binaries\Win64\Dawnwalker.exe`.
- **Packaging Format**: IoStore v8 (`Dawnwalker-Windows.pak`, `.ucas`, `.utoc`), compressed and AES-256 encrypted.
- **Rule**: Never make assumptions based on older engines (UE4) or generic scripts without verifying against the exact UE 5.5.4 binaries and IoStore format.

---

## 4. Reverse Engineering & Modding Discipline

- **Non-Destructive Operations**: Never overwrite or delete original game files in `D:\Games\The Blood of Dawnwalker` without explicit user confirmation.
- **Backup Verification**: Always work via injected DLLs, loose override files, or staging directories before deploying patches.
- **Minimal Invasive Footprint**: Prefer hooks and targeted patches over wholesale asset replacements to preserve stability and future game update compatibility.
