# GROUND_TRUTH.md — Technical System State

> **Rule for Agents**: This is the single source of technical truth for the Open Doors mod. When any implementation changes or an approach is superseded, immediately update this document and prune out stale or obsolete information.

---

## 1. Project Overview & Current Status

- **Mod Name**: Open Doors
- **Target Game**: *The Blood of Dawnwalker* (Rebel Wolves Sp. z o.o.)
- **Status**: Phase 1 — Reverse Engineering & Foundation Setup
- **Core Objective**: Prevent automatic door closures and invisible barrier lockouts when crossing thresholds into interior rooms, towers, and fortresses, allowing players freedom to retreat, peek, and navigate naturally.

---

## 2. Target Environment Specifications

| Attribute | Specification |
|---|---|
| **Game Installation** | `D:\Games\The Blood of Dawnwalker` |
| **Main Binary** | `Dawnwalker\Binaries\Win64\Dawnwalker.exe` |
| **Engine** | Unreal Engine 5 (UE 5.5.4.0) |
| **Engine Build Tag** | `dw1-pc-256181-shipping-patch2-all-CL-256181` |
| **Original Executable Name** | `Dawnwalker-Win64-Shipping.exe` |
| **Asset Packaging** | IoStore v8 (`Dawnwalker-Windows.pak`, `.ucas`, `.utoc`) |
| **IoStore Properties** | Compressed (Block Size: 256 KB), AES-256 Encrypted, Indexed (778,648 entries) |
| **Game Specific Modules** | `RebelSettings`, `RebelInput`, and custom `Rebel*` gameplay runtime classes |
| **User Save/Config Location** | `C:\Users\Alon-TUF\AppData\Local\Dawnwalker\Saved` |

---

## 3. Observed Phenomenon & In-Game Analysis

Analysis of user gameplay recording (`D:\Utils\Videos\NVIDIA\Dawnwalker\Dawnwalker 2026.09.04 - 17.15.58.03.mp4`):
1. **Context**: Quest *"The Firebrand"* (Objective: *"Search the guard post for any rebel allies"*).
2. **Action**: The player sprints up wooden steps to an open stone tower doorway.
3. **Trigger**:
   - The player crosses the doorway threshold into the circular room.
   - An encounter trigger activates (Boss/Miniboss bar appears: *"Rayko, the Incorruptible"*).
   - The wooden door immediately swings closed behind the player automatically, with no NPC physically touching or locking it.
4. **Result**:
   - The player turns around and attempts to walk back through the doorway.
   - An invisible wall / locked door collision completely blocks the exit.
   - The player is artificially trapped inside the tower.

### Technical Mechanics Identified
- **Trigger Volume**: A collision trigger volume (e.g. `BoxComponent` or `TriggerBox`) sits right across the entrance threshold.
- **Event Sequence**:
  1. `OnActorBeginOverlap(PlayerCharacter)` fires.
  2. Spawns/activates the encounter manager (`Rayko, the Incorruptible`).
  3. Sends `CloseDoor` / `LockDoor` signal to the referenced Door Actor.
  4. Activates collision on an entrance boundary blocker (or locks the door mesh collision with interaction disabled).

---

## 4. Mod Architecture & Implementation Paths

### Path A: Runtime Hooking via UE4SS / Native DLL (Primary Recommended)
- **Mechanism**: Inject an Unreal Engine reflection hook (`UE4SS` or custom proxy DLL such as `dxgi.dll` / `dwmapi.dll`).
- **Advantages**:
  - Does not require unpacking or repackaging 43+ GB of encrypted IoStore assets.
  - Dynamically hooks into `UObject::ProcessEvent` or specific `UFunction` calls (e.g., door closing events, encounter arena locking).
  - Can dump full game reflection metadata (UObjects, UClasses, UFunctions, Structs) into an SDK for precise symbol targeting.
  - Allows writing clean Lua or C++ logic to intercept and nullify the door close/lock signal.

### Path B: Asset Patch via IoStore / Pak (Secondary)
- **Mechanism**:
  1. Extract the AES-256 encryption key from `Dawnwalker.exe` memory.
  2. Unpack the relevant level / door blueprint / encounter volume asset from `Dawnwalker-Windows.utoc`/`.ucas`.
  3. Modify the blueprint event graph to remove the door lock and closure nodes.
  4. Package a high-priority override IoStore chunk (e.g. `Dawnwalker-Windows_P.pak` / `.utoc` / `.ucas`).
- **Trade-off**: Requires AES key extraction and maintaining asset compatibility across game patches.

---

## 5. Current Implementation State

- [x] Repository initialized with strict agent governance (`AGENTS.md`) and player documentation (`README.md`).
- [x] Verified game engine version: Unreal Engine 5.5.4 (Shipping).
- [x] Confirmed IoStore v8 encrypted/compressed structure.
- [x] Analyzed gameplay video to pinpoint exact trigger sequence on doorway crossing.
- [ ] Next Step: Deploy reflection dumper / runtime hook (UE4SS for UE 5.5) or dump memory strings/SDK to identify exact class names for doors and encounter locks.
