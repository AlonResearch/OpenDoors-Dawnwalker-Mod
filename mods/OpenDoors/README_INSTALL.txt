================================================================================
Open Doors — The Blood of Dawnwalker Mod (v1.0.0)
================================================================================

Freedom to enter. Freedom to leave.
Eliminates artificial combat door closures, self-locking gates, and invisible
doorway barrier walls.

--------------------------------------------------------------------------------
REQUIREMENTS
--------------------------------------------------------------------------------
1. The Blood of Dawnwalker (Steam / PC)
2. UE4SS (Unreal Engine 4/5 Scripting System)
   - Recommended (Game-Tuned): Dawnwalker UE4SS (Nexus Mod #18)
     https://www.nexusmods.com/thebloodofdawnwalker/mods/18
   - Upstream Official Project: RE-UE4SS v3.0+
     https://github.com/UE4SS-RE/RE-UE4SS

--------------------------------------------------------------------------------
QUICK INSTALLATION (FOOLPROOF)
--------------------------------------------------------------------------------
Method A: Drag & Drop (Recommended)
1. Locate your game directory:
   - On Steam: Right-click "The Blood of Dawnwalker" -> Manage -> Browse local files.
2. Extract this ZIP archive directly into your game directory!
   - The files will automatically land in:
     Dawnwalker\Binaries\Win64\ue4ss\Mods\OpenDoors\
3. That's it! Because 'enabled.txt' is included inside the OpenDoors folder,
   UE4SS automatically detects and loads the mod.

Method B: Manual Copy
1. Copy the "OpenDoors" folder.
2. Paste it into your UE4SS Mods folder:
   <GameRoot>\Dawnwalker\Binaries\Win64\ue4ss\Mods\
3. (Optional) Open <GameRoot>\Dawnwalker\Binaries\Win64\ue4ss\Mods\mods.txt
   and ensure this line exists:
   OpenDoors : 1

--------------------------------------------------------------------------------
HOW TO VERIFY IT IS WORKING
--------------------------------------------------------------------------------
1. Launch the game.
2. Approach any door (e.g. guard tower in "Rayko, the Incorruptible").
3. Push through the door.
4. When combat engages, the door will stay swung open and you can freely walk,
   roll, and retreat through the open doorway back outside into the courtyard.
5. (Optional) Check your log file at:
   Dawnwalker\Binaries\Win64\ue4ss\UE4SS.log
   You should see:
   [Lua] [OpenDoors] Mod loaded successfully (v1.0.0).

--------------------------------------------------------------------------------
HOTKEYS & DIAGNOSTICS
--------------------------------------------------------------------------------
- The mod is 100% autonomous and requires NO key presses during normal play.
- F8: Optional emergency sweep & diagnostic key. Pressing F8 logs the nearest
  door status to UE4SS.log and ensures all doors are unlocked.

--------------------------------------------------------------------------------
NOTE ON ENEMY AI & PATHFINDING LEASH
--------------------------------------------------------------------------------
If enemies, mobs, or bosses stop pursuing you after you retreat back through
the doorway, this is NOT a bug with Open Doors!
In the base game, encounter developers built AI routines assuming the player
would be locked inside. Thus, enemy pursuit boundaries (leashes) and navigation
meshes are often confined to the interior room.
Stepping outside into the courtyard may cause enemies to reach their native
boundary and stop. While this enables tactical retreats, it can be cheesy.
We are actively researching broader AI chase/pathfinding extensions for an
upcoming release or companion mod!

--------------------------------------------------------------------------------
UNINSTALL
--------------------------------------------------------------------------------
Simply delete the "OpenDoors" folder from:
Dawnwalker\Binaries\Win64\ue4ss\Mods\OpenDoors\
================================================================================
