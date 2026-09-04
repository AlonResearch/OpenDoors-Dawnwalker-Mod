# Ground Truth - System Implementation & Architecture State

> **Notice for AI Agents & Developers:** This is a **live document**. It MUST be updated whenever any change modifies mod logic, architecture, reverse-engineering findings, or hook definitions. Always document ONLY the current active implementation, strictly pruning deprecated logic and obsolete references.

---

## 1. System Overview & Objective

**Open Doors** is a quality-of-life and immersion mod for *The Blood of Dawnwalker* (Rebel Wolves).

### Core Problem
In the base game, doors in the world use a physical "stumble-to-open" / push-to-open model where the player simply walks through them without needing an interaction key. However, when entering an area where combat starts (such as the guard tower in *"Rayko, the Incorruptible"*), the game automatically slams the door shut and locks it via a systemic encounter event, trapping the player inside and disabling the push-to-open trigger.

### Objective
Ensure that doors remain in their natural state and never close or lock themselves:
1. Prevent systemic door closures (`WasSystemicallyClosed`) upon entering combat or encounter zones.
2. Ensure doors maintain their native push-to-open / stumble-to-open functionality both inside and outside of combat.
3. Keep opened doors in the native `EDoorState::OpenEvenInCombat` state.
4. **Zero interference with the player's combat input or interaction systems** (no prompts, keybind modifications, or loot interaction changes).

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
    KeyLocked         = 5,
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
- **Trigger**: When an encounter or combat begins, the encounter manager calls `SetDoorState` with `WasSystemicallyClosed = true` and `InNewState = EDoorState::Locked`.
- When the player only alerts guards (investigation phase without full combat), `WasSystemicallyClosed` is not called, leaving the door untouched.

---

## 4. Mod Implementation Architecture (Door-Focused, Native Primitives)

To ensure high stability and zero impact on player controls, the mod operates **exclusively on the door actor and its native state**:

1. **Systemic Closure Neutralization**:
   - Intercept calls to `UDogwoodBlueprintFunctionLibrary::SetDoorState`.
   - If `WasSystemicallyClosed == true` (automated combat/encounter lock), block the closure and preserve the door's current open state.
   - Legitimate narrative key locks (`EDoorState::KeyLocked`) remain untouched.

2. **Native State Promotion to `OpenEvenInCombat`**:
   - When a door opens via player movement/stumble (`OnDoorStartedOpening` or `OnDoorOpen`), set its state to `EDoorState::OpenEvenInCombat` (value `3`).
   - This informs the engine's internal state machines that this door is to remain traversable during combat.

3. **DoorTrigger & Push-to-Open Continuity**:
   - Keep `DoorTrigger` enabled in combat so that if a player ever approaches an unlocked closed door while fighting, walking into it continues to push it open without requiring any button press.

4. **Zero Combat Input Alterations**:
   - No modifications to player input mapping, HUD prompts, or `Player.Input.BlockInteractions`. Combat controls and loot behavior remain 100% vanilla.

---

## 5. Current Active Implementation

- [x] Reverse-engineered `Dawnwalker.exe` binary symbols and reflection tables.
- [x] Discovered native `EDoorState::OpenEvenInCombat` enum.
- [x] Identified `DogwoodBlueprintFunctionLibrary::SetDoorState` and `WasSystemicallyClosed` mechanic.
- [x] Confirmed push-to-open `DoorTrigger` architecture and pruned combat input modification concept.
- [ ] Milestone: Implement UE4SS Lua interceptor in `mods/OpenDoors/scripts/main.lua` targeting `SetDoorState` and `EDoorState::OpenEvenInCombat`.
