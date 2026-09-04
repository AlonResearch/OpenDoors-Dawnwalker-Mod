# Ground Truth - System Implementation & Architecture State

> **Notice for AI Agents & Developers:** This is a **live document**. It MUST be updated whenever any change modifies mod logic, architecture, reverse-engineering findings, or hook definitions. Always document ONLY the current active implementation, strictly pruning deprecated logic and obsolete references.

---

## 1. System Overview & Objective

**Open Doors** is a quality-of-life and immersion mod for *The Blood of Dawnwalker* (Rebel Wolves).

### Core Problem
In the base game, entering an interior room or watchtower and triggering combat (or an encounter like *"Rayko, the Incorruptible"*) causes the door to immediately swing shut behind the player and lock. Furthermore, entering combat disables the player's ability to interact with doors, trapping the player in an artificial arena lockout.

### Objective
Leverage the game's native primitives to:
1. Prevent systemic door closures (`WasSystemicallyClosed`) upon entering combat.
2. Maintain doors in the native `EDoorState::OpenEvenInCombat` state when opened.
3. Allow the player to interact with and reopen doors even while in combat mode (`Player.Input.BlockInteractions`).

---

## 2. Target Environment Specifications

| Component | Target Specification |
|---|---|
| **Engine** | Unreal Engine 5.5.4 (`dw1-pc-256181-shipping-patch2-all-CL-256181`) |
| **Developer** | Rebel Wolves Sp. z o.o. |
| **Executable** | `game/Dawnwalker/Binaries/Win64/Dawnwalker.exe` (`Dawnwalker-Win64-Shipping.exe`) |
| **Asset Packaging** | IoStore v8 (`game/Dawnwalker/Content/Paks/Dawnwalker-Windows.*`) |
| **Core Game Modules** | `DogwoodCombat`, `DogwoodAI`, `DogwoodWorld`, `RebelAI`, `RebelInput` |
| **Core Utility Library**| `DogwoodBlueprintFunctionLibrary` |

*Note: All paths in this repository are relative to the repository root via the `game/` directory junction.*

---

## 3. Verified Game Primitives & Mechanics

Reverse-engineering of `Dawnwalker.exe` has identified the exact engine primitives governing doors and combat lockouts:

### A. The Native Door State Enum (`EDoorState`)
```cpp
enum class EDoorState : uint8
{
    Invalid           = 0,
    Open              = 1,
    Locked            = 2,
    OpenEvenInCombat  = 3, // Native engine state designed to persist through combat!
    TimeOpenByDay     = 4,
    KeyLocked         = 5,
    Disabled          = 6,
    TimeOpenByNight   = 7
};
```

### B. The Systemic Closure Primitive
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
- **Trigger**: When an encounter or combat state begins (`RebelAI.Event.Combat.Started`), the encounter manager calls `SetDoorState` with `WasSystemicallyClosed = true` and `InNewState = EDoorState::Locked`.
- **Observation Verification**: When the player merely alerts enemies without triggering full combat mode, `WasSystemicallyClosed` is not called, confirming the closure is directly driven by the combat initiation sequence.

### C. Combat Interaction Lockout
- Entering combat tags the player with `Player.Input.BlockInteractions` and `Player.IsEffectivelyInCombat`.
- The interaction subsystem (`DISInteraction`, `GetInteractablePrompt`, `TriggerDISInteraction`) checks this tag and blocks input for opening doors.

---

## 4. Mod Implementation Architecture (Native Primitives First)

The mod applies a 3-pillar strategy targeting the game's native primitives:

1. **State Promotion to `OpenEvenInCombat`**:
   - When a door is opened by the player, ensure its target state is promoted to `EDoorState::OpenEvenInCombat` (value 3).
   - This uses the game's own native logic to instruct the engine not to shut the door during combat.

2. **Systemic Closure Neutralization**:
   - Intercept calls to `SetDoorState`.
   - If `WasSystemicallyClosed == true` (automated encounter/combat slam), suppress the state change or override `InNewState` to keep the door open, preserving normal narrative key-locked doors (`EDoorState::KeyLocked`).

3. **Combat Door Interaction Unlock**:
   - Override the interaction gate (`TriggerDISInteraction` / `GetInteractablePrompt`) for actors of type door, bypassing `Player.Input.BlockInteractions` so players can open closed doors at will during combat.

---

## 5. Current Active Implementation

- [x] Reverse-engineered `Dawnwalker.exe` binary symbols and reflection tables.
- [x] Discovered native `EDoorState::OpenEvenInCombat` enum.
- [x] Identified `DogwoodBlueprintFunctionLibrary::SetDoorState` and `WasSystemicallyClosed` mechanic.
- [x] Identified combat interaction blocker tag `Player.Input.BlockInteractions`.
- [ ] Milestone: Implement lightweight UE4SS Lua interceptor in `mods/OpenDoors` targeting `SetDoorState` and door interaction in combat.
