# Ground Truth - System Implementation & Architecture State

> **Notice for AI Agents & Developers:** This is a **live document**. It MUST be updated whenever any change modifies mod logic, architecture, reverse-engineering findings, or hook definitions. Always document ONLY the current active implementation, strictly pruning deprecated logic and obsolete references.

---

## 1. System Overview & Objective

**Open Doors** is a quality-of-life and immersion mod for *The Blood of Dawnwalker* (Rebel Wolves).

### Core Problem
In the base game, crossing doorway thresholds into interior locations (e.g. watchtowers, fortress chambers) triggers automatic door closures and invisible barrier collisions behind the player. Even if the player opened the door themselves and no enemy physically locks it, the entrance slams shut and seals, preventing tactical retreat, scouting, or peeking.

### Objective
Disable automated door closure triggers and barrier collision volumes for non-boss interior transitions, allowing doors to stay open and players to enter and exit freely.

---

## 2. Target Environment Specifications

The mod targets the shipping PC build of the game:

| Component | Target Specification |
|---|---|
| **Engine** | Unreal Engine 5.5.4 (`dw1-pc-256181-shipping-patch2-all-CL-256181`) |
| **Developer** | Rebel Wolves Sp. z o.o. |
| **Executable** | `game/Dawnwalker/Binaries/Win64/Dawnwalker.exe` (`Dawnwalker-Win64-Shipping.exe`) |
| **Asset Packaging** | IoStore v8 (`game/Dawnwalker/Content/Paks/Dawnwalker-Windows.*`) |
| **Container Flags** | Compressed (256 KB blocks), AES-256 Encrypted, Indexed (778,648 entries) |
| **Custom Modules** | `RebelSettings`, `RebelInput`, and `Rebel*` gameplay runtime classes |

*Note: All paths in this repository are relative to the repository root, where `game/` is a local directory junction pointing to the game installation.*

---

## 3. Gameplay Breakdown & Trigger Mechanics

Analysis of baseline gameplay footage:
- **Location**: Guard post stone tower during the quest *"The Firebrand"*.
- **Sequence**:
  1. Player opens the wooden door and walks through the threshold.
  2. Crossing the threshold activates the encounter trigger (*"Rayko, the Incorruptible"*).
  3. The wooden door immediately swings closed automatically without an NPC interacting with it.
  4. An invisible barrier / locked collision engages at the doorframe, preventing the player from backing out.
- **Engine Trigger Structure**:
  - Threshold trigger volume fires `OnActorBeginOverlap`.
  - Encounter state initiates and invokes a close/lock event on the door actor.
  - Collision state is updated on the doorway volume to block player egress.

---

## 4. Modding Architecture & Strategy

### Primary Approach: Runtime Reflection Hooking (UE4SS)
- **Mechanism**: Inject an Unreal Engine reflection hook via a proxy DLL (e.g. `dwmapi.dll` or `dxgi.dll`) in `game/Dawnwalker/Binaries/Win64/`.
- **Advantages**:
  - No need to unpack, decrypt, or repackage 43+ GB of AES-encrypted IoStore containers.
  - Directly inspects live `UObject` and `UFunction` hierarchies in memory.
  - Intercepts door closure and locking functions via lightweight Lua / C++ hooks.
  - Keeps doors interactive from both sides without breaking game updates.

### Secondary Approach: IoStore Asset Patching
- Extract the AES-256 key from process memory, unpack the relevant blueprint/level assets, edit the event graph, and stage a high-priority `.pak`/`.ucas` override chunk. Maintained as fallback if reflection hooks conflict with engine updates.

---

## 5. Current Active Implementation

- **Repository Structure**: Established with zero machine-specific paths, relative `game/` junction, and strict agent rules.
- **Engine Verification**: Confirmed UE 5.5.4 binary profile and IoStore v8 encryption status.
- **Current Milestone**: Phase 2 — Preparing reflection dumper / UE4SS integration in `game/Dawnwalker/Binaries/Win64/` to identify door actor classes and event signatures.
