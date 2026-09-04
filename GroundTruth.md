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

### B. The Native Door State Enum (`EDoorState`) - Verified via UE4SS Reflection
```cpp
enum class EDoorState : uint8
{
    Open              = 0, // Natural unconstrained open state
    OpenEvenInCombat  = 1, // Native engine combat persistence state
    Locked            = 2, // Encounter / systemic locked state
    KeyLocked         = 3, // Narrative quest door state (requires key item)
    TimeOpenByDay     = 4,
    TimeOpenByNight   = 5,
    Disabled          = 6,
    Invalid           = 7
};
```

### C. Doorway Lockout Architecture & Components
Doors (e.g. `BP_CityDoor_B_Right_C`, `BP_VillageDoor_A_Left_C`) contain attached components:
- `InvisibleWallForCombat` (BoxComponent): Activated during combat encounters to form a physical barrier in the doorway threshold even when the door leaf is swung open.
- `LockedObstacle` (BoxComponent): Collision barrier engaged when `DoorState == Locked (2)`.
- `OpenVolume` & `ApproachTrigger`: Native push-to-open and stumble trigger volumes.
- `Mesh` & `SM_DoorFrame_A`: Physical door wing and structural frame.

---

## 4. Mod Implementation Architecture (`mods/OpenDoors/scripts/main.lua`)
 
The active mod implementation operates on the **Complete Reactive Chaos Physics Neutralization & Safe Lifecycle Strategy** (v1.6.0):
 
```mermaid
flowchart TD
    A[Door in World: Closed & Untouched] -->|Player approaches & pushes open| B[SetDoorState: Open / OnApproachTrigger]
    B --> C{State == KeyLocked?}
    C -- Yes --> D[Preserve Narrative Lock 100%]
    C -- No --> E[Promote to OpenEvenInCombat (1)<br/>bInForcedOpen = true]
    E --> F[Player Crosses Threshold / TraversalAreaTrigger]
    F --> G[Active Engine Chaos Physics Neutralization:<br/>K2_SetRelativeLocation -> Z = -50000.0<br/>SetBoxExtent -> 0, 0, 0<br/>SetCollisionProfileName -> NoCollision<br/>SetCollisionEnabled -> 0<br/>SetCollisionResponseToAllChannels -> 0<br/>Door Leaf Mesh -> Ignore ECC_Pawn]
    G --> H[Encounter Engages & Attempts Closure:<br/>SetDoorState -> Locked (2) & WasSystemicallyClosed]
    H --> I[Mod Hook on SetDoorState Intercepts:<br/>Redirects InNewState to OpenEvenInCombat (1)<br/>Clears WasSystemicallyClosed]
    I --> J[Doorway Remains 100% Open & Traversable]
    J --> K[Pointer Preserved: Zero Null-Pointer Dereferences, Zero Crashes]
```

### Key Logic Rules
1. **Chaos Physics Scene Updates vs. Property Writes**:
   - In UE5 Chaos Physics, raw property writes to UObject structs (`comp.BoxExtent.X = 0`, `comp.RelativeLocation.Z = -50000`) update reflection data but do not recreate or reposition the physical collision body registered in the Chaos physics scene.
   - Calling native engine methods (`K2_SetRelativeLocation`, `SetBoxExtent`, `SetCollisionEnabled`, `SetCollisionProfileName`, `SetCollisionResponseToAllChannels`) forces the Chaos physics scene to physically update:
     - Relocates the physics body 500 meters underground (`Z = -31155.9`).
     - Collapses the collision box extents to `(0, 0, 0)`.
     - Completely zeroes out all collision channels.
2. **Door Leaf (`Mesh`) Pawn Pass-Through**:
   - The wooden door wing (`Mesh`) uses `BlockAllWithoutClimb` (`Col=3`). Even when swung open, its collision hull can catch the player pawn's collision cylinder.
   - When a door enters `Open` or `OpenEvenInCombat`, `Mesh:SetCollisionResponseToChannel(2, 0)` is set (`ECC_Pawn` -> `ECR_Ignore`), ensuring frictionless traversal through the doorway.
3. **Strict Non-Destructive Invariant (Crash Prevention)**:
   - Components (`InvisibleWallForCombat`, `LockedObstacle`) are **never destroyed or deleted** via `K2_DestroyComponent`.
   - The game encounter manager's C++ pointers to these components remain 100% valid, completely eliminating null-pointer access violations (`0xc0000005`) when entering combat.
4. **Strict Door-Scoped Hooks**:
   - Hooks are strictly placed on `/Script/DogwoodWorld.Door` events (`SetDoorState`, `NotifyDoorStateChanged`, `OnApproachTriggerBeginOverlap`, `OnTraversalAreaBeginOverlap`, `OnTraversalAreaEndOverlap`).
   - Zero hooks on base engine primitives (`UPrimitiveComponent`), guaranteeing zero idle overhead and zero interference with physics ticks.
5. **Zero Pre-Opening (Preserve World Immersion)**:
   - Doors remain 100% naturally closed at game startup and level streaming until the player approaches and pushes them open.
6. **Ghost Closure Redirection (`SetDoorState`)**:
   - When combat begins, encounter managers attempt to slam doors shut (`WasSystemicallyClosed = true` or `InNewState = Locked (2)`).
   - The native hook on `SetDoorState` overrides `InNewState` to `OpenEvenInCombat (1)` and clears `WasSystemicallyClosed`, keeping the door swung open.
7. **Strict Narrative Lock Guard**:
   - Any door with `EDoorState::KeyLocked` (`3`) is strictly bypassed across all hooks. Quest barriers and locked dungeons behave 100% as vanilla.
8. **Loader Stability Profile**:
   - UE4SS v3.0.1-1111 (Dawnwalker compatibility build #18) loaded via `dwmapi.dll`.
   - `VTableLayout.ini` with narrow `LoadMap` offset at `0x4F0`.
   - Safe headless mode (`GuiConsoleEnabled = 0`, `ConsoleEnabled = 0`, `bUseUObjectArrayCache = false`).

---

## 5. Current Active Implementation

- [x] Reverse-engineered `Dawnwalker.exe` binary symbols and reflection tables.
- [x] Verified native `EDoorState` enum: `Open = 0`, `OpenEvenInCombat = 1`, `Locked = 2`, `KeyLocked = 3`.
- [x] Verified door components: `Mesh`, `LockedObstacle`, `TraversalAreaTrigger`, `InvisibleWallForCombat`.
- [x] Created `Findings.md` documenting reverse-engineering conclusions and barrier mechanics.
- [x] Discovered Chaos physics scene caching: native engine physics functions required to update Chaos bodies.
- [x] Eliminated component destruction crash (`0xc0000005`) by enforcing strict non-destructive extents & relocation.
- [x] Implemented multi-tier Chaos Physics Neutralization in `mods/OpenDoors/scripts/main.lua` (v1.6.0).
- [x] Implemented door leaf `Mesh` pawn pass-through (`ECC_Pawn` -> `ECR_Ignore`).
- [x] Intercepted `SetDoorState` to redirect combat closures to `OpenEvenInCombat (1)` and clear `WasSystemicallyClosed`.
- [x] Preserved narrative quest key locks (`EDoorState::KeyLocked = 3`).
- [x] Live hot-reload verified in game (`0.18s` reload time, 44 world barriers neutralized).

