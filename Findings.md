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

### C. Why the Invisible Wall Persisted After Property Writes
* In `v1.5.0`, setting `comp.RelativeLocation.Z = -50000.0` and `comp.BoxExtent.X = 0` via direct reflection table writes modified the UProperty values on the UObject, but did **not** notify Unreal Engine 5 Chaos Physics to update the registered physics body.
* In Chaos Physics, an already-registered `UBoxComponent` caches its collision shape and world transform matrix (`ComponentToWorld`). Without calling native engine physics functions (`K2_SetRelativeLocation`, `SetBoxExtent`, `SetCollisionEnabled`), the collision box remains in the active physics scene at the doorway threshold.
* Furthermore, the wooden door leaf (`Mesh`) carries `BlockAllWithoutClimb` (`Col=3`). Even when swung open, its collision hull can clip or snag on the player pawn's collision capsule.

---

## 4. Resolution Strategy (v1.6.0: Chaos Physics Neutralization)

1. **Keep Pointer Valid (Zero Crashes):** Do not delete `InvisibleWallForCombat` or `LockedObstacle` (`K2_DestroyComponent` strictly forbidden).
2. **Active Engine Chaos Physics Neutralization:**
   - Call `K2_SetRelativeLocation({ X = 0.0, Y = 0.0, Z = -50000.0 }, false, {}, false)` to physically relocate the Chaos physics body 500 meters underground (verified: moved to `Z = -31155.9`, 500m away).
   - Call `SetBoxExtent({ X = 0.0, Y = 0.0, Z = 0.0 }, false)` to zero the active collision shape (verified: `Extent = 0,0,0`).
   - Call `SetCollisionProfileName(FName('NoCollision'), false)` and `SetCollisionEnabled(0)`.
   - Call `SetCollisionResponseToAllChannels(0)` and `SetCollisionResponseToChannel(ECC_Pawn, ECR_Ignore)`.
3. **Door Leaf Pawn Pass-Through:**
   - When the door is in an open state, set `Mesh:SetCollisionResponseToChannel(ECC_Pawn, ECR_Ignore)` so the wooden door wing can never obstruct or catch the player's retreat.
4. **Reactive Lifecycle Hooks:**
   - All 5 native door functions (`SetDoorState`, `NotifyDoorStateChanged`, `OnApproachTriggerBeginOverlap`, `OnTraversalAreaBeginOverlap`, `OnTraversalAreaEndOverlap`) reactively enforce barrier defusal and `OpenEvenInCombat (1)`.

