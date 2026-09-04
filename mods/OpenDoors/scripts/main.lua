-- Open Doors Mod for The Blood of Dawnwalker
-- Architecture: Safe Non-Destructive Door & Barrier Control (v1.4.0)
-- Strict Invariant: Never destroy components (prevents null pointer crashes)
-- Strict Invariant: Only hook Door-specific functions (zero idle overhead, stable physics)

local MOD_NAME = 'OpenDoors'
local VERSION = '1.4.0'
print(string.format('[%s] Initializing version %s (Safe Non-Destructive Architecture)...', MOD_NAME, VERSION))

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

-- Safely neutralize a barrier component WITHOUT destroying it
-- Zero extents + underground relocation guarantees it can NEVER collide with the player,
-- while preserving the pointer so the game encounter engine never crashes!
local function NeutralizeBarrierSafe(comp)
    if not comp or not comp:IsValid() then return end

    -- 1. Disable collision and ignore all channels
    pcall(function() comp:SetCollisionEnabled(0) end) -- ECollisionEnabled::NoCollision
    pcall(function() comp.BodyInstance.CollisionEnabled = 0 end)
    pcall(function() comp:SetCollisionProfileName(FName('NoCollision'), false) end)
    pcall(function() comp:SetCollisionResponseToAllChannels(0) end) -- ECR_Ignore

    -- 2. Zero out the box extents (size becomes 0 x 0 x 0)
    pcall(function()
        if comp.SetBoxExtent then
            comp:SetBoxExtent({X = 0.0, Y = 0.0, Z = 0.0}, false)
        end
    end)

    -- 3. Move the box 500 meters underground so it is completely removed from the doorway
    pcall(function()
        comp:K2_SetRelativeLocation({X = 0.0, Y = 0.0, Z = -50000.0}, false, nil, false)
    end)
end

-- Defuse barriers for a specific door
local function DefuseDoorBarriers(door)
    if not door or not door:IsValid() then return end

    local currentState = nil
    pcall(function() currentState = door.DoorState end)

    -- Strictly preserve narrative quest locks (KeyLocked = 3)
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
                NeutralizeBarrierSafe(child)
            end
        end
    end
end

-- Sweep barriers on level streaming / load
local function SweepAllDoorBarriers()
    local doors = FindAllOf('Door') or {}
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
    print(string.format('[%s] Safely neutralized combat barriers on %d doors.', MOD_NAME, count))
end

-- HOOK 1: SetDoorState
-- The master state controller: prevents door from locking/closing during combat
local function OnSetDoorStatePre(Context, InNewState, WasSystemicallyClosed, WasSilentlyClosed, OpeningActor, bInForcedOpen, bFromSave, InOpenDirection)
    local door = Context and Context:get() or nil
    if not door or not door:IsValid() then return end

    local targetState = InNewState and InNewState:get() or nil
    local currentDoorState = nil
    pcall(function() currentDoorState = door.DoorState end)

    -- Preserve narrative key locks
    if targetState == EDoorState.KeyLocked or currentDoorState == EDoorState.KeyLocked then
        return
    end

    -- Player opens door naturally
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

    -- Encounter attempts to lock/slam door shut
    local isSystemicClose = WasSystemicallyClosed and WasSystemicallyClosed:get() == true
    if targetState == EDoorState.Locked or isSystemicClose then
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
    local cleanName = setDoorStateFunc:GetFullName():gsub('^%a+ ', '')
    RegisterHook(cleanName, OnSetDoorStatePre)
    print(string.format('[%s] Hooked native %s', MOD_NAME, cleanName))
end

-- HOOK 2: NotifyDoorStateChanged
local notifyFunc = FindObject('Function', 'NotifyDoorStateChanged')
if notifyFunc and notifyFunc:IsValid() then
    local cleanName = notifyFunc:GetFullName():gsub('^%a+ ', '')
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

-- HOOK 3: Approach Trigger -> Pre-open & pre-defuse
local approachFunc = FindObject('Function', 'OnApproachTriggerBeginOverlap')
if approachFunc and approachFunc:IsValid() then
    local cleanName = approachFunc:GetFullName():gsub('^%a+ ', '')
    RegisterHook(cleanName, function(Context)
        local door = Context and Context:get() or nil
        if door and door:IsValid() then
            local state = nil
            pcall(function() state = door.DoorState end)
            if state ~= EDoorState.KeyLocked then
                pcall(function()
                    door.DoorState = EDoorState.OpenEvenInCombat
                    door.bForceDoorWideOpen = true
                end)
                DefuseDoorBarriers(door)
            end
        end
    end)
    print(string.format('[%s] Hooked native %s', MOD_NAME, cleanName))
end

-- HOOK 4: Traversal Area Trigger -> Defuse barriers when player crosses threshold
local traversalBeginFunc = FindObject('Function', 'OnTraversalAreaBeginOverlap')
if traversalBeginFunc and traversalBeginFunc:IsValid() then
    local cleanName = traversalBeginFunc:GetFullName():gsub('^%a+ ', '')
    RegisterHook(cleanName, function(Context)
        local door = Context and Context:get() or nil
        if door and door:IsValid() then
            DefuseDoorBarriers(door)
        end
    end)
    print(string.format('[%s] Hooked native %s', MOD_NAME, cleanName))
end

local traversalEndFunc = FindObject('Function', 'OnTraversalAreaEndOverlap')
if traversalEndFunc and traversalEndFunc:IsValid() then
    local cleanName = traversalEndFunc:GetFullName():gsub('^%a+ ', '')
    RegisterHook(cleanName, function(Context)
        local door = Context and Context:get() or nil
        if door and door:IsValid() then
            -- Keep door open and barrier defused when exiting traversal zone
            local state = nil
            pcall(function() state = door.DoorState end)
            if state ~= EDoorState.KeyLocked then
                pcall(function()
                    door.DoorState = EDoorState.OpenEvenInCombat
                    door.bForceDoorWideOpen = true
                end)
                DefuseDoorBarriers(door)
            end
        end
    end)
    print(string.format('[%s] Hooked native %s', MOD_NAME, cleanName))
end

-- Level Streaming / Initialization
RegisterInitGameStatePostHook(function()
    print(string.format('[%s] InitGameState fired. Performing safe barrier defusal...', MOD_NAME))
    SweepAllDoorBarriers()
end)

-- Initial sweep on load
SweepAllDoorBarriers()

-- F8 Emergency Key: Manual unlock & barrier sweep
RegisterKeyBindAsync(Key.F8, {}, function()
    print(string.format('[%s] === F8 EMERGENCY UNLOCK & BARRIER DEFUSAL ===', MOD_NAME))
    SweepAllDoorBarriers()
    local doors = FindAllOf('Door') or {}
    for _, d in ipairs(doors) do
        if d and d:IsValid() then
            local state = nil
            pcall(function() state = d.DoorState end)
            if state ~= EDoorState.KeyLocked then
                pcall(function()
                    d.DoorState = EDoorState.OpenEvenInCombat
                    d.bForceDoorWideOpen = true
                end)
                DefuseDoorBarriers(d)
            end
        end
    end
    print(string.format('[%s] Unlocked doors to OpenEvenInCombat (1) & defused barriers.', MOD_NAME))
    print(string.format('[%s] ====================================================', MOD_NAME))
end)

print(string.format('[%s] Mod loaded successfully (v%s). Safe, crash-free architecture active.', MOD_NAME, VERSION))
