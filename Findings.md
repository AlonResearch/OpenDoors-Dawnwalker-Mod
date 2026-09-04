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

## 4. Final Resolution Strategy (v1.0.0 Release Architecture)

1. **Keep Component Pointers Valid (Zero Crashes):**
   - Strictly prohibit `K2_DestroyComponent` on `InvisibleWallForCombat` or `LockedObstacle`.
   - Preserving the UObject in memory prevents C++ encounter managers from dereferencing dangling/null pointers, completely eliminating `0xc0000005` access violation crashes.
2. **Active Engine Chaos Physics Neutralization:**
   - Instead of inert reflection property writes, invoke native engine physics methods:
     - `comp:K2_SetRelativeLocation({ X = 0.0, Y = 0.0, Z = -50000.0 }, false, {}, false)`
     - `comp:SetBoxExtent({ X = 0.0, Y = 0.0, Z = 0.0 }, false)`
     - `comp:SetCollisionProfileName(FName('NoCollision'), false)`
     - `comp:SetCollisionEnabled(0)`
     - `comp:SetCollisionResponseToAllChannels(0)`
     - `comp:SetCollisionResponseToChannel(2, 0)` (`ECC_Pawn` -> `ECR_Ignore`)
     - `comp:SetCollisionResponseToChannel(1, 0)` (`ECC_WorldDynamic` -> `ECR_Ignore`)
3. **Door Leaf (`Mesh`) Collision Pass-Through:**
   - Set `Mesh:SetCollisionResponseToChannel(2, 0)` (`ECC_Pawn` -> `ECR_Ignore`) when the door opens, preventing the physical wooden door leaf from snagging or catching the player's collision cylinder during combat traversal.
4. **Reactive Lifecycle Hooks:**
   - Intercept `/Script/DogwoodWorld.Door` events (`SetDoorState`, `NotifyDoorStateChanged`, `OnApproachTriggerBeginOverlap`, `OnTraversalAreaBeginOverlap`, `OnTraversalAreaEndOverlap`) to redirect encounter closures to `OpenEvenInCombat (1)` and trigger barrier defusal.
5. **Strict Quest Lock Guard:**
   - Any door in `EDoorState::KeyLocked (3)` is strictly bypassed, keeping narrative progression intact.

---

## 5. Live Memory Verification Data

Captured from active game session in `BP_CityDoor_B_Right_C_UAID_74563C676821AFBF02_1306103176`:

| Component | State Before Neutralization | State After Neutralization (v1.0.0) |
|---|---|---|
| `InvisibleWallForCombat` | `Loc=(180781.9, 328678.3, 18846.3)`, `Extent=(6, 68, 110)`, `Col=3` | `Loc=(180781.9, 328678.3, -31155.9)`, `Extent=(0, 0, 0)`, `Col=0`, `Dist=49989.3cm` |
| `LockedObstacle` | `Extent=(20, 60, 110)`, `Col=3` | `Extent=(0, 0, 0)`, `Col=0` |
| `Mesh` (Door Leaf) | `Profile=BlockAllWithoutClimb`, `Blocks Pawn` | `Pawn Channel (ECC_Pawn) = ECR_Ignore (0)` |
| Total World Barriers Defused | 0 | 44 active combat barriers across world |
| In-Game Retest Result | Threshold blocked by invisible wall | **100% Passable: Player walks/rolls through freely during combat** |

