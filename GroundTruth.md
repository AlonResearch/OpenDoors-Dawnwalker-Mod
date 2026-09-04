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

The active mod implementation operates on the **Dual-Layered Reactive Lifecycle & Low-Level Primitive Collision Interception Strategy** (v1.2.0):

```mermaid
flowchart TD
    A[Door in World: Closed & Untouched] -->|Player approaches & pushes open| B[SetDoorState: Open / OnApproachTrigger]
    B --> C{State == KeyLocked?}
    C -- Yes --> D[Preserve Narrative Lock 100%]
    C -- No --> E[Promote to OpenEvenInCombat (1)<br/>bInForcedOpen = true]
    E --> F[Player Enters Interior & Combat Engages]
    F --> G[Encounter calls SetCollisionEnabled / SetCollisionProfileName on InvisibleWallForCombat]
    G --> H[Mod Hook on PrimitiveComponent Intercepts:<br/>Forces NewType = NoCollision (0)<br/>Forces Profile = NoCollision]
    H --> I[Invisible Barrier Never Solidifies]
    F --> J[Encounter attempts door closure:<br/>SetDoorState -> Locked (2) & WasSystemicallyClosed]
    J --> K[Mod Hook on SetDoorState Intercepts:<br/>Redirects InNewState to OpenEvenInCombat (1)<br/>Clears WasSystemicallyClosed]
    K --> L[Doorway 100% Open & Traversable]
    I --> L
```

### Key Logic Rules
1. **Low-Level Collision Interception (`UPrimitiveComponent`)**:
   - Native hooks on `SetCollisionEnabled` and `SetCollisionProfileName` catch all runtime attempts by encounter managers to activate `InvisibleWallForCombat` or `LockedObstacle`.
   - Forces `NewType:set(0)` (`ECollisionEnabled::NoCollision`) and profile name to `'NoCollision'`, ensuring no invisible wall can ever physically block a doorway threshold.
2. **Zero Pre-Opening (Preserve World Immersion)**:
   - Doors remain 100% naturally closed at game startup and level streaming. No door is ever forced open before player approach.
3. **Ghost Closure Redirection (`SetDoorState`)**:
   - When combat begins, encounter managers attempt to slam doors shut (`WasSystemicallyClosed = true` or `InNewState = Locked (2)`).
   - The native hook on `SetDoorState` overrides `InNewState` to `OpenEvenInCombat (1)` and clears `WasSystemicallyClosed`, keeping the door swung open.
4. **Strict Narrative Lock Guard**:
   - Any door with `EDoorState::KeyLocked` (`3`) is strictly bypassed across all hooks. Quest barriers and locked dungeons behave 100% as vanilla.
5. **Continuous Active Sweep & Diagnostic Hotkey (F8)**:
   - On load/reload and level streaming (`InitGameState`), sweeps active memory to defuse any spawned barrier boxes.
   - Bound asynchronously via `RegisterKeyBindAsync(Key.F8, ...)`: triggers an immediate manual sweep and status check if needed.
6. **Loader Stability Profile**:
   - UE4SS v3.0.1-1111 (Dawnwalker compatibility build #18) loaded via `dwmapi.dll`.
   - `VTableLayout.ini` with narrow `LoadMap` offset at `0x4F0`.
   - Safe headless mode (`GuiConsoleEnabled = 0`, `ConsoleEnabled = 0`, `bUseUObjectArrayCache = false`).

---

## 5. Current Active Implementation

- [x] Reverse-engineered `Dawnwalker.exe` binary symbols and reflection tables.
- [x] Verified native `EDoorState` enum: `Open = 0`, `OpenEvenInCombat = 1`, `Locked = 2`, `KeyLocked = 3`.
- [x] Verified door components: `Mesh`, `LockedObstacle`, `TraversalAreaTrigger`, `InvisibleWallForCombat`.
- [x] Hooked `UPrimitiveComponent:SetCollisionEnabled` to intercept and force `NoCollision (0)`.
- [x] Hooked `UPrimitiveComponent:SetCollisionProfileName` to force `'NoCollision'`.
- [x] Implemented Dual-Layered Collision Interception architecture in `mods/OpenDoors/scripts/main.lua` (v1.2.0).
- [x] Intercepted `SetDoorState` to redirect combat closures to `OpenEvenInCombat (1)` and clear `WasSystemicallyClosed`.
- [x] Ensured doors start closed in vanilla state on game startup and level streaming.
- [x] Preserved narrative quest key locks (`EDoorState::KeyLocked = 3`).
- [ ] Milestone: In-game testing with user in the "Rayko, the Incorruptible" guard tower encounter.

