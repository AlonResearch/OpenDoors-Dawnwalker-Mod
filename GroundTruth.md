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
| **Runtime Loader** | UE4SS v3.0.1 (Experimental UE 5.5 build) loaded via `dwmapi.dll` |
| **Loader Profile** | Safe mode: `GuiConsoleEnabled=0`, `ConsoleEnabled=0`, `bUseUObjectArrayCache=false` |
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

The active mod implementation operates directly on `UDogwoodBlueprintFunctionLibrary::SetDoorState` through UE4SS reflection hooks:

```mermaid
flowchart TD
    A[Native SetDoorState Called] --> B{InNewState == KeyLocked (5)?}
    B -- Yes --> C[Allow Normal Narrative Lock]
    B -- No --> D{WasSystemicallyClosed == true?}
    D -- Yes --> E[Intercept & Nullify Systemic Lock:<br/>WasSystemicallyClosed = false<br/>InNewState = OpenEvenInCombat (3)]
    D -- No --> F{InNewState == Open (1)?}
    F -- Yes --> G[Promote to OpenEvenInCombat (3)]
    F -- No --> H[Execute Unchanged]
```

### Key Logic Rules
1. **Narrative Key Lock Guard**:
   - If `InNewState == EDoorState.KeyLocked` (5), the hook returns immediately without altering arguments. Quest gates, key-required doors, and story locks function untouched.
2. **Systemic Closure Neutralization**:
   - If `WasSystemicallyClosed == true`, the hook calls `WasSystemicallyClosed:set(false)` and `InNewState:set(EDoorState.OpenEvenInCombat)` (3).
   - This prevents the encounter manager from forcing the door into a locked state, keeping the door open, unblocking collision, and leaving the push-to-open `DoorTrigger` active.
3. **Open Promotion**:
   - If `InNewState == EDoorState.Open` (1), the hook promotes it to `OpenEvenInCombat` (3), informing the engine's state machine that this door should never auto-close if combat ensues.
4. **Loader Stability Profile**:
   - Disabled all default C++ mods (`KismetDebuggerMod`, `EventViewerMod`, etc.) which conflict with UE 5.5 Kismet bytecode.
   - Disabled DirectX 12 ImGui overlay hook (`GuiConsoleEnabled = 0`) to avoid conflicts with simultaneous XeSS, DLSS, and AMD FidelityFX Frame Generation.
   - Set `bUseUObjectArrayCache = false` to eliminate GUObjectArray race conditions during early engine startup.

---

## 5. Current Active Implementation

- [x] Reverse-engineered `Dawnwalker.exe` binary symbols and reflection tables.
- [x] Discovered native `EDoorState::OpenEvenInCombat` enum.
- [x] Identified `DogwoodBlueprintFunctionLibrary::SetDoorState` and `WasSystemicallyClosed` mechanic.
- [x] Deployed UE4SS v3.0.1 (Experimental UE 5.5 build) via `dwmapi.dll` into `game/Dawnwalker/Binaries/Win64/`.
- [x] Hardened UE4SS settings (safe headless mode, disabled default C++ hooks, disabled DX12 overlay).
- [x] Created `mods/OpenDoors/scripts/main.lua` and linked via junction to UE4SS Mods.
- [x] Verified narrative key-lock guard (`EDoorState.KeyLocked = 5`).
- [ ] Milestone: In-game testing with user in the "Rayko, the Incorruptible" guard tower encounter.
