# Ground Truth - System Implementation & Architecture State

> **Notice for AI Agents & Developers:** This is a **live document**. It MUST be updated whenever any change modifies mod logic, architecture, reverse-engineering findings, or hook definitions. Always document ONLY the current active implementation, strictly pruning deprecated logic and obsolete references.

---

## 1. System Overview & Objective

**Open Doors** is a quality-of-life and immersion mod for *The Blood of Dawnwalker* (Rebel Wolves).

### Core Problem
In the base game, doors use a physical "push-to-open" / stumble-to-open model where the player walks through them without pressing any buttons. However, entering an area that triggers combat (such as the guard tower in *"Rayko, the Incorruptible"*) causes an automatic encounter script to slam the door shut and lock it behind the player, creating an artificial arena lockout.

### Objective
Ensure that doors remain in their natural state:
1. Prevent systemic encounter closures (`WasSystemicallyClosed == true`) from locking the player in.
2. Maintain push-to-open functionality on openable doors during combat.
3. **Preserve Story & Quest Locks**: Genuine story-blocked doors (requiring keys, quest progression, or tagged `EDoorType::Quest` / `EDoorState::KeyLocked`) **remain strictly locked**.
4. **Zero interference with player combat controls or interaction systems**.

---

## 2. Target Environment Specifications

| Component | Target Specification |
|---|---|
| **Engine** | Unreal Engine 5.5.4 (`dw1-pc-256181-shipping-patch2-all-CL-256181`) |
| **Developer** | Rebel Wolves Sp. z o.o. |
| **Executable** | `game/Dawnwalker/Binaries/Win64/Dawnwalker.exe` (`Dawnwalker-Win64-Shipping.exe`) |
| **Asset Packaging** | IoStore v8 (`game/Dawnwalker/Content/Paks/Dawnwalker-Windows.*`) |
| **Door Utility Library**| `DogwoodBlueprintFunctionLibrary` |
| **Door Triggers** | `DoorTrigger`, `SecondWingDoorTrigger` |

*Note: All paths in this repository are relative to the repository root via the `game/` directory junction.*

---

## 3. Verified Game Primitives & Mechanics

### A. Push-to-Open & Stumble Mechanism
- Unlocked doors in *The Blood of Dawnwalker* do not require manual button prompts; approaching or stumbling into them triggers `DoorTrigger`, which fires `OnDoorStartedOpening` and swings the door open.
- When combat begins, the encounter script forces the door into `EDoorState::Locked`, closing it, disabling the `DoorTrigger`, and solidifying the collision.

### B. The Native Door State & Type Enums
```cpp
enum class EDoorType : uint8
{
    Regular = 0,
    Quest   = 1  // Native tag for story/quest doors
};

enum class EDoorState : uint8
{
    Invalid           = 0,
    Open              = 1,
    Locked            = 2, // Generic/combat lock
    OpenEvenInCombat  = 3, // Native engine state: persists through combat
    TimeOpenByDay     = 4,
    KeyLocked         = 5, // Requires key / quest item to unlock
    Disabled          = 6,
    TimeOpenByNight   = 7
};
```

### C. The Systemic Closure Primitive
```cpp
UDogwoodBlueprintFunctionLibrary::SetDoorState(
    EDoorState InNewState,
    bool WasSystemicallyClosed, // TRUE only when an encounter/combat event forces the door shut
    bool WasSilentlyClosed,
    AActor* OpeningActor,
    bool bInForcedOpen,
    bool bFromSave,
    EDoorOpenDirection InOpenDirection
);
```

---

## 4. Mod Implementation Architecture (Door-Focused, Native Primitives)

### Story-Lock Preservation Guarantee
The mod cleanly separates **artificial combat locks** from **genuine story/quest barriers**:
- **Story-Locked Doors (`EDoorType::Quest`, `EDoorState::KeyLocked`)**:
  - These doors were locked by level design before combat ever occurred (`WasSystemicallyClosed == false`).
  - They require keys (`SetDoorUnlockingItem`) or quest milestones.
  - **The mod ignores these completely**; they remain locked exactly as intended by the developers.
- **Combat Arena Lockouts (`WasSystemicallyClosed == true`)**:
  - These are doors that were unlocked/open, but get slammed shut purely because combat or an encounter started.
  - **The mod intercepts this specific flag**, preventing the automatic closure and keeping the door traversable.

### Active Mechanics
1. **Neutralize Systemic Closures**: Intercept `SetDoorState`. If `WasSystemicallyClosed == true`, block the forced lock and keep the door open.
2. **Promote to `EDoorState::OpenEvenInCombat`**: When a regular door opens, set its native state to `OpenEvenInCombat` (value `3`).
3. **Continuous Push-to-Open**: Ensure `DoorTrigger` remains active during combat on regular unlocked doors so walking into them continues to open them.
4. **Zero Combat Input Alterations**: Player input, combat bindings, and HUD prompts remain 100% vanilla.

---

## 5. Current Active Implementation

- [x] Reverse-engineered `Dawnwalker.exe` binary symbols and reflection tables.
- [x] Verified `EDoorType::Quest` and `EDoorState::KeyLocked` primitives ensuring story doors remain locked.
- [x] Identified `WasSystemicallyClosed` as the precise discriminator for combat-only locks.
- [ ] Milestone: Deploy UE4SS in `game/Dawnwalker/Binaries/Win64/` and install `mods/OpenDoors/scripts/main.lua` to intercept `WasSystemicallyClosed`.
