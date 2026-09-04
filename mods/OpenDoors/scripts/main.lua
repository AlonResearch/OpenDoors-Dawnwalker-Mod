-- Open Doors Mod for The Blood of Dawnwalker
-- Architecture: Realistic Event-Driven Passive Lifecycle
-- Engine Enums (UE5 Reflection):
-- 0 = EDoorState::Open
-- 1 = EDoorState::OpenEvenInCombat
-- 2 = EDoorState::Locked
-- 3 = EDoorState::KeyLocked (Narrative quest doors - strictly preserved)

local MOD_NAME = 'OpenDoors'
local VERSION = '1.1.0'
print(string.format('[%s] Initializing version %s (Realistic Passive Lifecycle)...', MOD_NAME, VERSION))

local EDoorState = {
    Open = 0,
    OpenEvenInCombat = 1,
    Locked = 2,
    KeyLocked = 3,
    TimeOpenByDay = 4,
    TimeOpenByNight = 5,
    Disabled = 6,
    Invalid = 7
}

-- Defuse InvisibleWallForCombat and LockedObstacle without opening or moving the door leaf
local function DefuseDoorBarriers(door)
    if not door or not door:IsValid() then return end

    local currentState = nil
    pcall(function() currentState = door.DoorState end)

    -- Strictly preserve narrative quest locks
    if currentState == EDoorState.KeyLocked then
        return
    end

    local root = door.RootComponent
    if not root or not root:IsValid() then return end

    local children = root.AttachChildren
    if not children then return end

    for i = 1, #children do
        local child = children[i]
        if child and child:IsValid() then
            local cname = child:GetFName():ToString()
            if cname == 'InvisibleWallForCombat' or cname == 'LockedObstacle' then
                pcall(function()
                    child:SetCollisionEnabled(0) -- NoCollision
                    child:SetCollisionResponseToAllChannels(0) -- Ignore all channels
                end)
                pcall(function()
                    if child.SetBoxExtent then
                        child:SetBoxExtent({X = 0.0, Y = 0.0, Z = 0.0}, false)
                    end
                end)
                pcall(function()
                    local loc = child:K2_GetComponentLocation()
                    loc.Z = loc.Z - 50000.0
                    child:K2_SetWorldLocation(loc, false, nil, false)
                end)
            end
        end
    end
end

-- Hook SetDoorState: The core authority for door state transitions
-- Intercepts encounter closures and promotes natural openings to OpenEvenInCombat
local function OnSetDoorStatePre(Context, InNewState, WasSystemicallyClosed, WasSilentlyClosed, OpeningActor, bInForcedOpen, bFromSave, InOpenDirection)
    local door = Context and Context:get() or nil
    if not door or not door:IsValid() then return end

    local targetState = InNewState and InNewState:get() or nil
    local currentDoorState = nil
    pcall(function() currentDoorState = door.DoorState end)

    -- RULE 1: Strictly preserve narrative quest doors (KeyLocked = 3)
    if targetState == EDoorState.KeyLocked or currentDoorState == EDoorState.KeyLocked then
        return
    end

    -- RULE 2: Natural opening by player -> promote to OpenEvenInCombat (1)
    if targetState == EDoorState.Open then
        if InNewState then
            InNewState:set(EDoorState.OpenEvenInCombat)
        end
        if bInForcedOpen then
            bInForcedOpen:set(true)
        end
        DefuseDoorBarriers(door)
        return
    end

    -- RULE 3: Combat encounter attempts to lock or systemically slam the door shut
    local isSystemicClose = WasSystemicallyClosed and WasSystemicallyClosed:get() == true
    if targetState == EDoorState.Locked or isSystemicClose then
        -- Override close: keep door open and traversable in combat
        if InNewState then
            InNewState:set(EDoorState.OpenEvenInCombat)
        end
        if WasSystemicallyClosed then
            WasSystemicallyClosed:set(false)
        end
        if WasSilentlyClosed then
            WasSilentlyClosed:set(false)
        end
        if bInForcedOpen then
            bInForcedOpen:set(true)
        end

        DefuseDoorBarriers(door)
        return
    end
end

local setDoorStateFunc = FindObject('Function', 'SetDoorState')
if setDoorStateFunc and setDoorStateFunc:IsValid() then
    local fullName = setDoorStateFunc:GetFullName()
    local cleanName = fullName:gsub('^%a+ ', '')
    RegisterHook(cleanName, OnSetDoorStatePre)
    print(string.format('[%s] Hooked native %s', MOD_NAME, cleanName))
else
    print(string.format('[%s] WARNING: SetDoorState function not found to hook', MOD_NAME))
end

-- Hook NotifyDoorStateChanged to ensure barrier defusal on any state transition
local notifyFunc = FindObject('Function', 'NotifyDoorStateChanged')
if notifyFunc and notifyFunc:IsValid() then
    local fullName = notifyFunc:GetFullName()
    local cleanName = fullName:gsub('^%a+ ', '')
    RegisterHook(cleanName, function(Context)
        local door = Context and Context:get() or nil
        if door and door:IsValid() then
            local state = nil
            pcall(function() state = door.DoorState end)
            if state and state ~= EDoorState.KeyLocked then
                if state == EDoorState.Locked then
                    pcall(function() door.DoorState = EDoorState.OpenEvenInCombat end)
                end
                DefuseDoorBarriers(door)
            end
        end
    end)
    print(string.format('[%s] Hooked native %s', MOD_NAME, cleanName))
end

-- Hook Approach Trigger: Pre-defuse combat barrier when player approaches a door
local approachFunc = FindObject('Function', 'OnApproachTriggerBeginOverlap')
if approachFunc and approachFunc:IsValid() then
    local fullName = approachFunc:GetFullName()
    local cleanName = fullName:gsub('^%a+ ', '')
    RegisterHook(cleanName, function(Context)
        local door = Context and Context:get() or nil
        if door and door:IsValid() then
            DefuseDoorBarriers(door)
        end
    end)
    print(string.format('[%s] Hooked native %s', MOD_NAME, cleanName))
end

-- Level Streaming / Initialization: Defuse invisible barriers ONLY
-- NOTE: Doors remain closed in their natural vanilla state! We do NOT open them.
local function OnLevelStreaming()
    local doors = FindAllOf('Door')
    if not doors then return end
    local count = 0
    for _, d in ipairs(doors) do
        if d and d:IsValid() then
            local state = nil
            pcall(function() state = d.DoorState end)
            if state ~= EDoorState.KeyLocked then
                DefuseDoorBarriers(d)
                count = count + 1
            end
        end
    end
    print(string.format('[%s] Streamed level: defused barriers on %d doors (doors stay naturally closed).', MOD_NAME, count))
end

RegisterInitGameStatePostHook(function()
    print(string.format('[%s] InitGameState fired.', MOD_NAME))
    OnLevelStreaming()
end)

-- Diagnostic Status Key (F8): Read-only status report for the nearest door
RegisterKeyBindAsync(Key.F8, {}, function()
    print(string.format('[%s] ==========================================', MOD_NAME))
    print(string.format('[%s] === F8 DIAGNOSTIC DOOR INSPECTION ===', MOD_NAME))
    print(string.format('[%s] ==========================================', MOD_NAME))

    local pc = nil
    pcall(function() pc = GetPlayerController() end)
    local pawn = nil
    if pc and pc:IsValid() then
        pcall(function() pawn = pc.Pawn or pc.AcknowledgedPawn end)
    end
    if not pawn or not pawn:IsValid() then
        local pawns = FindAllOf('PlayerCharacter') or FindAllOf('Character')
        if pawns and #pawns > 0 then
            for _, p in ipairs(pawns) do
                if p and p:IsValid() and p:IsPlayerControlled() then pawn = p break end
            end
        end
    end

    if not pawn or not pawn:IsValid() then
        print(string.format('[%s] Player pawn not found.', MOD_NAME))
        return
    end

    local pLoc = pawn:K2_GetActorLocation()
    local doors = FindAllOf('Door') or {}
    local nearest, minDist = nil, 999999
    for _, d in ipairs(doors) do
        if d and d:IsValid() then
            local dLoc = d:K2_GetActorLocation()
            local dist = math.sqrt((pLoc.X-dLoc.X)^2 + (pLoc.Y-dLoc.Y)^2 + (pLoc.Z-dLoc.Z)^2)
            if dist < minDist then minDist = dist nearest = d end
        end
    end

    if not nearest then
        print(string.format('[%s] No door found in memory.', MOD_NAME))
        return
    end

    print(string.format('[%s] Nearest Door: %s (Dist: %.1f cm)', MOD_NAME, nearest:GetFullName(), minDist))
    print(string.format('[%s]   DoorState: %s', MOD_NAME, tostring(nearest.DoorState)))
    print(string.format('[%s]   bForceDoorWideOpen: %s', MOD_NAME, tostring(nearest.bForceDoorWideOpen)))

    local root = nearest.RootComponent
    if root and root:IsValid() then
        local children = root.AttachChildren
        if children then
            for i = 1, #children do
                local c = children[i]
                if c and c:IsValid() then
                    local cname = c:GetFName():ToString()
                    if cname:find('Barrier') or cname:find('Wall') or cname:find('Obstacle') or cname:find('Trigger') or cname:find('Mesh') then
                        local col = 'N/A'
                        pcall(function() col = tostring(c:GetCollisionEnabled()) end)
                        print(string.format('[%s]   Component [%s]: Col=%s', MOD_NAME, cname, col))
                    end
                end
            end
        end
    end
    print(string.format('[%s] ==========================================', MOD_NAME))
end)

print(string.format('[%s] Mod loaded successfully. Realistic passive doors active.', MOD_NAME))
