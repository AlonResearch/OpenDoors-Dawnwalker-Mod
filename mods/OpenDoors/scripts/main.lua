-- Open Doors Mod for The Blood of Dawnwalker
-- Architecture: Complete Reactive Lifecycle & Low-Level Collision Interception (v1.2.0)
-- Engine Enums (UE5 Reflection):
-- 0 = EDoorState::Open
-- 1 = EDoorState::OpenEvenInCombat
-- 2 = EDoorState::Locked
-- 3 = EDoorState::KeyLocked (Narrative quest doors - strictly preserved)

local MOD_NAME = 'OpenDoors'
local VERSION = '1.2.0'
print(string.format('[%s] Initializing version %s (Surgical Barrier Interception)...', MOD_NAME, VERSION))

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

-- Defuse barrier component completely
local function NeutralizeBarrierComponent(comp)
    if not comp or not comp:IsValid() then return end
    pcall(function() comp:SetCollisionEnabled(0) end) -- ECollisionEnabled::NoCollision
    pcall(function() comp.BodyInstance.CollisionEnabled = 0 end)
    pcall(function() comp:SetCollisionProfileName(FName('NoCollision'), false) end)
    pcall(function() comp:SetCollisionResponseToAllChannels(0) end)
    pcall(function()
        if comp.SetBoxExtent then
            comp:SetBoxExtent({X = 0.0, Y = 0.0, Z = 0.0}, false)
        end
    end)
    pcall(function()
        local loc = comp:K2_GetComponentLocation()
        loc.Z = loc.Z - 50000.0
        comp:K2_SetWorldLocation(loc, false, nil, false)
    end)
end

-- Defuse all barriers attached to a door
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
                NeutralizeBarrierComponent(child)
            end
        end
    end
end

-- Sweep all doors and barrier components currently in active memory
local function SweepAndDefuseAllBarriers()
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
                    NeutralizeBarrierComponent(b)
                    count = count + 1
                end
            end
        end
    end
    print(string.format('[%s] Swept and neutralized %d active combat barriers in world.', MOD_NAME, count))
end

-- HOOK 1: Intercept SetCollisionEnabled on PrimitiveComponent
-- Prevents any encounter, script, or timeline from ever turning the barrier solid
local function OnSetCollisionEnabledPre(Context, NewType)
    local comp = Context and Context:get() or nil
    if not comp or not comp:IsValid() then return end

    local cname = comp:GetFName():ToString()
    if cname == 'InvisibleWallForCombat' or cname == 'LockedObstacle' then
        if NewType then
            NewType:set(0) -- Force ECollisionEnabled::NoCollision
        end
    end
end

local setColFn = FindObject('Function', 'SetCollisionEnabled')
if setColFn and setColFn:IsValid() then
    local cleanName = setColFn:GetFullName():gsub('^%a+ ', '')
    RegisterHook(cleanName, OnSetCollisionEnabledPre)
    print(string.format('[%s] Hooked native %s', MOD_NAME, cleanName))
end

-- HOOK 2: Intercept SetCollisionProfileName on PrimitiveComponent
-- Prevents the barrier from adopting any solid collision profile (BlockAll / Custom)
local function OnSetCollisionProfileNamePre(Context, InCollisionProfileName, bUpdateOverlaps)
    local comp = Context and Context:get() or nil
    if not comp or not comp:IsValid() then return end

    local cname = comp:GetFName():ToString()
    if cname == 'InvisibleWallForCombat' or cname == 'LockedObstacle' then
        pcall(function()
            InCollisionProfileName:set(FName('NoCollision'))
        end)
    end
end

local setProfileFn = FindObject('Function', 'SetCollisionProfileName')
if setProfileFn and setProfileFn:IsValid() then
    local cleanName = setProfileFn:GetFullName():gsub('^%a+ ', '')
    RegisterHook(cleanName, OnSetCollisionProfileNamePre)
    print(string.format('[%s] Hooked native %s', MOD_NAME, cleanName))
end

-- HOOK 3: Intercept SetDoorState
-- Prevents encounters from slamming doors shut, promotes natural openings to OpenEvenInCombat
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

    -- Encounter tries to lock/close door
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

-- HOOK 4: Intercept NotifyDoorStateChanged
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

-- HOOK 5: Approach Trigger overlap -> Pre-defuse combat barrier
local approachFunc = FindObject('Function', 'OnApproachTriggerBeginOverlap')
if approachFunc and approachFunc:IsValid() then
    local cleanName = approachFunc:GetFullName():gsub('^%a+ ', '')
    RegisterHook(cleanName, function(Context)
        local door = Context and Context:get() or nil
        if door and door:IsValid() then
            DefuseDoorBarriers(door)
        end
    end)
    print(string.format('[%s] Hooked native %s', MOD_NAME, cleanName))
end

-- Level Streaming / Initialization: Defuse invisible barriers ONLY (doors stay closed)
RegisterInitGameStatePostHook(function()
    print(string.format('[%s] InitGameState fired. Defusing barriers...', MOD_NAME))
    SweepAndDefuseAllBarriers()
end)

-- Immediate sweep on script load/reload
SweepAndDefuseAllBarriers()

-- F8 Diagnostic & Emergency Clean
RegisterKeyBindAsync(Key.F8, {}, function()
    print(string.format('[%s] === F8 EMERGENCY BARRIER SWEEP & STATUS CHECK ===', MOD_NAME))
    SweepAndDefuseAllBarriers()
    print(string.format('[%s] ====================================================', MOD_NAME))
end)

print(string.format('[%s] Mod loaded successfully. Barriers permanently defused.', MOD_NAME))
