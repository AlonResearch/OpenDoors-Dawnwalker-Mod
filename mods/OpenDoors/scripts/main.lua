-- Open Doors Mod for The Blood of Dawnwalker
-- Architecture: Direct Reflection Property Modification & Safe Lifecycle (v1.5.0)
-- 100% Non-Destructive: Never destroys components, preventing null-pointer crashes (0xc0000005)
-- Direct Memory Writes: Modifies RelativeLocation.Z (-50000), BoxExtent (0,0,0), BodyInstance.CollisionEnabled (0)

local MOD_NAME = 'OpenDoors'
local VERSION = '1.5.0'
print(string.format('[%s] Initializing version %s (Direct Property Architecture)...', MOD_NAME, VERSION))

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

-- Surgical Barrier Neutralization via Direct Reflection Memory Writes
local function NeutralizeBarrierSafe(comp)
    if not comp or not comp:IsValid() then return end

    pcall(function()
        -- 1. Move 500 meters underground
        if comp.RelativeLocation then
            comp.RelativeLocation.Z = -50000.0
        end

        -- 2. Zero out the box extents (size becomes 0 x 0 x 0)
        if comp.BoxExtent then
            comp.BoxExtent.X = 0.0
            comp.BoxExtent.Y = 0.0
            comp.BoxExtent.Z = 0.0
        end

        -- 3. Set collision to NoCollision (0) directly in PhysX/Chaos BodyInstance
        if comp.BodyInstance then
            comp.BodyInstance.CollisionEnabled = 0
        end

        -- 4. Engine function fallbacks
        pcall(function() comp:SetCollisionEnabled(0) end)
        pcall(function() comp:SetCollisionProfileName(FName('NoCollision'), false) end)
        pcall(function() comp:SetCollisionResponseToAllChannels(0) end)
    end)
end

-- Defuse all barriers attached to a door
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

-- Sweep all doors and barrier components across the active world
local function SweepAllDoorBarriers()
    local allBoxes = FindAllOf('BoxComponent') or {}
    local count = 0
    for _, b in ipairs(allBoxes) do
        if b and b:IsValid() then
            local bname = b:GetFName():ToString()
            if bname == 'InvisibleWallForCombat' or bname == 'LockedObstacle' then
                local outer = b:GetOuter()
                local isKeyLocked = false
                if outer and outer:IsValid() then
                    pcall(function()
                        if outer.DoorState == EDoorState.KeyLocked then
                            isKeyLocked = true
                        end
                    end)
                end
                if not isKeyLocked then
                    NeutralizeBarrierSafe(b)
                    count = count + 1
                end
            end
        end
    end
    print(string.format('[%s] Defused %d active combat barriers in world via direct memory write.', MOD_NAME, count))
end

-- HOOK 1: SetDoorState
-- Prevents encounters from locking/closing doors, promotes openings to OpenEvenInCombat
local function OnSetDoorStatePre(Context, InNewState, WasSystemicallyClosed, WasSilentlyClosed, OpeningActor, bInForcedOpen, bFromSave, InOpenDirection)
    local door = Context and Context:get() or nil
    if not door or not door:IsValid() then return end

    local targetState = InNewState and InNewState:get() or nil
    local currentDoorState = nil
    pcall(function() currentDoorState = door.DoorState end)

    -- RULE: Strictly preserve narrative quest doors (KeyLocked = 3)
    if targetState == EDoorState.KeyLocked or currentDoorState == EDoorState.KeyLocked then
        return
    end

    -- Natural player opening -> promote to OpenEvenInCombat (1)
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

    -- Encounter tries to lock/close door -> keep open
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

-- HOOK 4: Traversal Area Trigger
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
    print(string.format('[%s] InitGameState fired. Defusing barriers...', MOD_NAME))
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
    print(string.format('[%s] All doors unlocked to OpenEvenInCombat (1).', MOD_NAME))
    print(string.format('[%s] ====================================================', MOD_NAME))
end)

print(string.format('[%s] Mod loaded successfully (v%s). Crash-free direct property defusal active.', MOD_NAME, VERSION))
