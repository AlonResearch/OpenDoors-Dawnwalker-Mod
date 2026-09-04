# Doorway Barrier & Combat Lockout Findings

**Mod:** Open Doors  
**Target:** *The Blood of Dawnwalker* (UE 5.5.4)  
**Location Tested:** Guard Tower Encounter (*"Rayko, the Incorruptible"*)  
**Door Actor:** `BP_CityDoor_B_Right_C` (inherits from `/Script/DogwoodWorld.Door`)

---

## 1. Summary of Discovery

During combat encounters, two distinct mechanics trap the player inside the arena:

| Mechanic | Responsible Element | Observed Behavior |
|---|---|---|
| **Door Closure** | `Door:SetDoorState` | Automatically changes `DoorState` to `Locked (2)` with `WasSystemicallyClosed = true`. |
| **Invisible Wall** | `Child [7]: InvisibleWallForCombat` | A hidden `BoxComponent` positioned directly in the doorway threshold that the encounter script activates (`Col=3` / `Custom` / `BlockAll`). |

---

## 2. Live Engine Reflection & Component Layout

Inspecting `BP_CityDoor_B_Right_C` in live memory revealed its full component hierarchy:

- `[1] Origin` (`SceneComponent`)
- `[2] ApproachTrigger` (`BoxComponent`) — Push-to-open detection
- `[3] OpenVolume` (`BoxComponent`) — Stumble volume
- `[4] Mesh` (`StaticMeshComponent`) — The wooden door leaf (`BlockAllWithoutClimb`)
- `[5] LockedObstacle` (`BoxComponent`) — Systemic lock barrier
- `[6] TraversalAreaTrigger` (`BoxComponent`) — Threshold traversal detector
- `[7] InvisibleWallForCombat` (`BoxComponent`) — **The Invisible Wall** (`Col=3`)
- `[13] SM_DoorFrame_A` (`StaticMeshComponent`) — Stone doorway frame

---

## 3. Verified Root Causes

### A. Why the Invisible Wall Exists
* The wooden door leaf (`Mesh`) opens cleanly when approached, but when the player crosses `TraversalAreaTrigger` and triggers combat with Rayko, the encounter manager enables collision on **`InvisibleWallForCombat`**.
* Even while the wooden door remains visually swung open, this invisible collision box physically blocks player traversal across the threshold.

### B. Why `K2_DestroyComponent` Caused Crashes
* When we completely destroyed `InvisibleWallForCombat` via `K2_DestroyComponent`, entering the room caused an immediate crash (`0xc0000005` Access Violation).
* **Cause:** The encounter manager in C++ holds a direct pointer to `door->InvisibleWallForCombat`. Dereferencing the deleted component caused a fatal null-pointer exception.
* **Invariant:** Components must **never be deleted/destroyed**.

### C. Why the Invisible Wall Returned
* In `v1.4.0`, after removing `K2_DestroyComponent`, the crash stopped completely, but the invisible wall returned because the encounter manager re-asserts collision on `InvisibleWallForCombat` when combat begins.

---

## 4. Resolution Strategy

1. **Keep Pointer Valid (Zero Crashes):** Do not delete `InvisibleWallForCombat`.
2. **Eliminate Physical Footprint:**
   - Override `SetCollisionResponseToChannel(ECC_Pawn, ECR_Ignore)` and `SetCollisionResponseToAllChannels(ECR_Ignore)`.
   - Set box extents to `(0, 0, 0)` so it has zero volume.
   - Relocate its position underground (`Z = -50000.0`).
3. **Intercept State Re-Activation:**
   - Intercept the combat encounter trigger when it attempts to activate the barrier or close the door.
