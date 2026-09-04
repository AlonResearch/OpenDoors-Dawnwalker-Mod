# Ground Truth - System Implementation & Architecture State

> **Notice for AI Agents & Developers:** This is a **live document**. It MUST be updated whenever any change modifies mod logic, architecture, reverse-engineering findings, or hook definitions. Always document ONLY the current active implementation, strictly pruning deprecated logic and obsolete references.

---

## 1. System Overview & Objective

**Open Doors** is a quality-of-life and immersion mod for *The Blood of Dawnwalker* (Rebel Wolves).

### Core Problem
In the base game, doors in the world use a physical "stumble-to-open" / push-to-open model where the player walks through them without needing an interaction key. However, when entering an area where combat starts (such as the guard tower in *"Rayko, the Incorruptible"*), the game automatically slams the door shut and locks it via a systemic encounter event, trapping the player inside and disabling the push-to-open trigger.

### Objective
Ensure that doors remain in their natural state and never close or lock themselves:
1. Prevent systemic door closures (`WasSystemicallyClosed`) upon entering combat or encounter zones.
2. Ensure doors maintain their native push-to-open / stumble-to-open functionality both inside and outside of combat.
3. Keep opened doors in the native `EDoorState::OpenEvenInCombat` state.
4. **Preserve Narrative Locks**: Legitimate quest doors and narrative locks (`EDoorState::KeyLocked`) behave 100% normally.
5. **Zero Performance Impact**: Zero-polling, purely event-driven architecture with zero idle CPU overhead.
6. **Zero combat input interference**: Combat controls and loot interactions remain 100% vanilla.

---

## 2. Target Environment Specifications

| Component | Target Specification |
|---|---|
| **Engine** | Unreal Engine 5.5.4 (`dw1-pc-256181-shipping-patch2-all-CL-256181`) |
| **Developer** | Rebel Wolves Sp. z o.o. |
| **Executable** | `game/Dawnwalker/Binaries/Win64/Dawnwalker.exe` (`Dawnwalker-Win64-Shipping.exe`) |
| **Runtime Loader** | UE4SS v3.0.1-1111 (Dawnwalker Compatibility Release / Mod #18) loaded via `dwmapi.dll` |
| **Loader Profile** | Game-tuned with `VTableLayout.ini` (`LoadMap` override at `0x4F0`), custom `FName` and `ProcessLocalScriptFunction` signatures |
| **Active Mod Location** | `mods/OpenDoors/scripts/main.lua` (linked to `game/Dawnwalker/Binaries/Win64/ue4ss/Mods/OpenDoors`) |
| **Door Utility Library**| `DogwoodBlueprintFunctionLibrary` |
| **Door Triggers** | `DoorTrigger`, `SecondWingDoorTrigger` |

*Note: All paths in this repository are relative to the repository root via the `game/` directory junction.*

---

## 3. Verified Game Primitives & Mechanics

Reverse-engineering of `Dawnwalker.exe` has identified the exact door and encounter primitives:

### A. Push-to-Open & Stumble Mechanism
- Doors in *The Blood of Dawnwalker* do not require manual button presses to traverse; they use `DoorTrigger` collision volumes that trigger `OnDoorStartedOpening` and swing open when approached or stumbled upon.
- When combat begins, the door is systemically forced into `EDoorState::Locked`, which closes the door, disables the `DoorTrigger`, and solidifies the door mesh collision into an impassable obstacle.

### B. The Native Door State Enum (`EDoorState`)
```cpp
enum class EDoorState : uint8
{
    Invalid           = 0,
    Open              = 1,
    Locked            = 2,
    OpenEvenInCombat  = 3, // Native engine state: keeps door open & traversable in combat
    TimeOpenByDay     = 4,
    KeyLocked         = 5, // Narrative quest door state (requires key item)
    Disabled          = 6,
    TimeOpenByNight   = 7
};
```

### C. The Systemic Closure Primitive
The central engine function controlling doors is:
```cpp
UDogwoodBlueprintFunctionLibrary::SetDoorState(
    EDoorState InNewState,
    bool WasSystemicallyClosed, // Triggered true when encounter/combat forces door shut
    bool WasSilentlyClosed,
    AActor* OpeningActor,
    bool bInForcedOpen,
    bool bFromSave,
    EDoorOpenDirection InOpenDirection
);
```

---

## 4. Mod Implementation Architecture (`mods/OpenDoors/scripts/main.lua`)

The active mod implementation operates on the **Promote-on-Open Native Lifecycle Strategy**:

```mermaid
flowchart TD
    A[Door in World: Closed] -->|Player walks through / pushes| B[OnDoorStartedOpening / SetDoorState]
    B --> C{State == KeyLocked?}
    C -- Yes --> D[Preserve Narrative Quest Lock]
    C -- No --> E[Promote to OpenEvenInCombat (3)<br/>Set bForceDoorWideOpen = true]
    E --> F[Combat Encounter Triggers]
    F --> G{Encounter Attempts Closure?}
    G -- Yes: SetDoorState / OnDoorStartedClosing --> H[Mod Intercepts & Enforces OpenEvenInCombat]
    H --> I[Door Remains Open & Traversable]
```

### Key Logic Rules
1. **Promote-on-Open**:
   - Closed and unvisited doors remain completely natural.
   - The moment a player pushes through a door (`OnDoorStartedOpening` or `SetDoorState` -> `Open`), the mod marks it as opened and promotes its state to `EDoorState::OpenEvenInCombat` (`3`) with `bForceDoorWideOpen = true`.
2. **Ghost Closure Neutralization**:
   - When combat begins, encounter managers attempt to slam doors shut (`WasSystemicallyClosed = true` or `InNewState = Locked`).
   - The mod intercepts `SetDoorState`, `OnDoorStartedClosing`, and `NotifyDoorStateChanged`, overriding the closure to `OpenEvenInCombat` (`3`) and clearing `WasSystemicallyClosed`.
3. **Strict Narrative Lock Guard**:
   - Any door with `EDoorState::KeyLocked` (`5`) is strictly bypassed across all hooks. Quest barriers and locked dungeons behave 100% as vanilla.
4. **Emergency / Diagnostic Hotkey (F8)**:
   - Bound asynchronously via `RegisterKeyBindAsync(Key.F8, ...)`:
   - Dumps all door actors in memory to `UE4SS.log` with their current states, names, and whether they were opened.
   - Frees any stuck door to `OpenEvenInCombat` without restarting the game.
5. **Loader Stability Profile**:
   - UE4SS v3.0.1-1111 (Dawnwalker compatibility build #18) loaded via `dwmapi.dll`.
   - `VTableLayout.ini` with narrow `LoadMap` offset at `0x4F0`.
   - Safe headless mode (`GuiConsoleEnabled = 0`, `ConsoleEnabled = 0`, `bUseUObjectArrayCache = false`).

---

## 5. Current Active Implementation

- [x] Reverse-engineered `Dawnwalker.exe` binary symbols and reflection tables.
- [x] Discovered native `EDoorState::OpenEvenInCombat` enum (`3`).
- [x] Deployed community-verified Dawnwalker UE4SS build (#18) resolving startup crashes.
- [x] Implemented Promote-on-Open native lifecycle architecture in `mods/OpenDoors/scripts/main.lua`.
- [x] Multi-layered reactive hooks on `SetDoorState`, `OnDoorStartedOpening`, `OnDoorStartedClosing`, and `NotifyDoorStateChanged`.
- [x] Added in-game F8 diagnostic and emergency unlock hotkey.
- [x] Verified narrative key-lock guard (`EDoorState.KeyLocked = 5`).
- [ ] Milestone: In-game testing with user in the "Rayko, the Incorruptible" guard tower encounter.
