-- Open Doors Mod for The Blood of Dawnwalker
-- Architecture: Promote-on-Open Native Lifecycle Strategy
-- Preserves narrative key-locked doors, keeps unvisited doors natural,
-- and prevents artificial combat lockout closures.

local MOD_NAME = 'OpenDoors'
local VERSION = '0.2.0'

print(string.format('[%s] Initializing version %s...', MOD_NAME, VERSION))

local EDoorState = {
    Invalid = 0,
    Open = 1,
    Locked = 2,
    OpenEvenInCombat = 3,
    TimeOpenByDay = 4,
    KeyLocked = 5,
    Disabled = 6,
    TimeOpenByNight = 7
}

local HookedFunctions = {}
-- Track doors opened during this session to distinguish natural doors from encounter lockouts
local OpenedDoors = {}

local function GetDoorId(door)
    if not door or not door:IsValid() then return nil end
    local name = nil
    pcall(function() name = door:GetFullName() end)
    return name
end

-- 1. Hook SetDoorState: Central State Machine
local function OnSetDoorStatePre(Context, InNewState, WasSystemicallyClosed, WasSilentlyClosed, OpeningActor, bInForcedOpen, bFromSave, InOpenDirection)
    local door = Context and Context:get() or nil
    local doorName = GetDoorId(door) or 'UnknownDoor'
    local state = InNewState and InNewState:get() or nil
    local systemic = WasSystemicallyClosed and WasSystemicallyClosed:get() or false

    print(string.format('[%s] SetDoorState called on %s (TargetState=%s, Systemic=%s)', MOD_NAME, doorName, tostring(state), tostring(systemic)))

    -- RULE A: Strictly preserve narrative quest locks (KeyLocked = 5)
    if state == EDoorState.KeyLocked then
        print(string.format('[%s] Preserving narrative KeyLocked state (5) on %s.', MOD_NAME, doorName))
        return
    end

    -- RULE B: Promote any naturally opened door to OpenEvenInCombat (3)
    if state == EDoorState.Open then
        print(string.format('[%s] Door opened! Promoting %s from Open (1) to OpenEvenInCombat (3).', MOD_NAME, doorName))
        OpenedDoors[doorName] = true
        if InNewState then
            InNewState:set(EDoorState.OpenEvenInCombat)
        end
        return
    end

    -- RULE C: Intercept artificial combat/encounter lockouts
    -- If combat triggers a systemic closure (WasSystemicallyClosed=true) OR tries to force Locked (2)
    -- on a door that was opened or is in combat area:
    if systemic == true or state == EDoorState.Locked then
        -- Check if this door is a narrative key door
        local currentState = nil
        if door and door:IsValid() then
            pcall(function() currentState = door.DoorState end)
        end

        if currentState == EDoorState.KeyLocked then
            print(string.format('[%s] Door %s is natively KeyLocked. Allowing lock.', MOD_NAME, doorName))
            return
        end

        print(string.format('[%s] Intercepted combat closure on %s! Neutralizing lock to OpenEvenInCombat (3).', MOD_NAME, doorName))
        if WasSystemicallyClosed then
            WasSystemicallyClosed:set(false)
        end
        if InNewState then
            InNewState:set(EDoorState.OpenEvenInCombat)
        end
        if bInForcedOpen then
            bInForcedOpen:set(true)
        end
        if door and door:IsValid() then
            pcall(function()
                door.DoorState = EDoorState.OpenEvenInCombat
                door.bForceDoorWideOpen = true
                if door.SetDoorForcedOpen then
                    door:SetDoorForcedOpen(true)
                end
            end)
        end
        return
    end
end

-- 2. Hook OnDoorStartedOpening: The instant a door is pushed, mark it OpenEvenInCombat
local function OnDoorStartedOpeningHook(Context)
    local door = Context and Context:get() or nil
    local doorName = GetDoorId(door) or 'UnknownDoor'

    print(string.format('[%s] OnDoorStartedOpening triggered on %s.', MOD_NAME, doorName))
    if not door or not door:IsValid() then return end

    local currentState = nil
    pcall(function() currentState = door.DoorState end)
    if currentState == EDoorState.KeyLocked then
        return
    end

    OpenedDoors[doorName] = true
    pcall(function()
        door.DoorState = EDoorState.OpenEvenInCombat
        door.bForceDoorWideOpen = true
    end)
end

-- 3. Hook OnDoorStartedClosing: Prevent artificial closing on opened doors
local function OnDoorStartedClosingHook(Context)
    local door = Context and Context:get() or nil
    local doorName = GetDoorId(door) or 'UnknownDoor'

    if not door or not door:IsValid() then return end

    local currentState = nil
    pcall(function() currentState = door.DoorState end)
    if currentState == EDoorState.KeyLocked then
        return
    end

    -- If this door was opened or is in combat, keep it open!
    if OpenedDoors[doorName] or currentState == EDoorState.OpenEvenInCombat or currentState == EDoorState.Open then
        print(string.format('[%s] OnDoorStartedClosing intercepted on %s! Forcing door to remain OpenEvenInCombat.', MOD_NAME, doorName))
        pcall(function()
            door.DoorState = EDoorState.OpenEvenInCombat
            door.bForceDoorWideOpen = true
            if door.SetDoorForcedOpen then
                door:SetDoorForcedOpen(true)
            end
        end)
    end
end

-- 4. Hook NotifyDoorStateChanged: Guard against out-of-band state flips
local function OnNotifyDoorStateChangedHook(Context, InNewState)
    local door = Context and Context:get() or nil
    local doorName = GetDoorId(door) or 'UnknownDoor'
    local state = InNewState and InNewState:get() or nil

    if state == EDoorState.KeyLocked then return end

    if (state == EDoorState.Locked) and (OpenedDoors[doorName] or state ~= EDoorState.KeyLocked) then
        print(string.format('[%s] NotifyDoorStateChanged (Locked) intercepted on %s. Enforcing OpenEvenInCombat.', MOD_NAME, doorName))
        if InNewState then
            InNewState:set(EDoorState.OpenEvenInCombat)
        end
        if door and door:IsValid() then
            pcall(function()
                door.DoorState = EDoorState.OpenEvenInCombat
                door.bForceDoorWideOpen = true
                if door.SetDoorForcedOpen then
                    door:SetDoorForcedOpen(true)
                end
            end)
        end
    end
end

-- Registration Helper
local function SafeHook(shortName, preHook, postHook)
    if HookedFunctions[shortName] then return true end

    local funcObj = FindObject('Function', shortName)
    if funcObj and funcObj:IsValid() then
        local fullName = funcObj:GetFullName()
        local cleanName = fullName:gsub('^%a+ ', '')
        local preId, postId = RegisterHook(cleanName, preHook, postHook)
        if preId then
            HookedFunctions[shortName] = true
            print(string.format('[%s] Successfully hooked %s (Pre: %s, Post: %s)', MOD_NAME, cleanName, tostring(preId), tostring(postId)))
            return true
        end
    end
    return false
end

local function RegisterAllDoorHooks()
    SafeHook('SetDoorState', OnSetDoorStatePre)
    SafeHook('OnDoorStartedOpening', OnDoorStartedOpeningHook)
    SafeHook('OnDoorStartedClosing', OnDoorStartedClosingHook)
    SafeHook('NotifyDoorStateChanged', OnNotifyDoorStateChangedHook)
end

-- Initial hook attempt
RegisterAllDoorHooks()

-- Retry hooks on World load and InitGameState
RegisterInitGameStatePostHook(function()
    print(string.format('[%s] InitGameState fired. Verifying door hooks...', MOD_NAME))
    RegisterAllDoorHooks()
end)

NotifyOnNewObject('/Script/Engine.World', function(world)
    print(string.format('[%s] World loaded (%s). Verifying door hooks...', MOD_NAME, world:GetFullName()))
    RegisterAllDoorHooks()
end)

-- 5. Diagnostic / Emergency Keybind: F8
-- Dumps all door states in the area to UE4SS.log and frees any stuck doors
RegisterKeyBindAsync(Key.F8, {}, function()
    print(string.format('[%s] === F8 PRESSED: INSPECTING ALL DOORS IN WORLD ===', MOD_NAME))
    local doors = FindAllOf('Door')
    if not doors or #doors == 0 then
        print(string.format('[%s] No doors found in active memory.', MOD_NAME))
        return
    end

    print(string.format('[%s] Found %d doors in active cell/world:', MOD_NAME, #doors))
    for i, door in ipairs(doors) do
        if door and door:IsValid() then
            local name = door:GetFullName()
            local state = 'unknown'
            local forcedOpen = 'unknown'
            pcall(function() state = tostring(door.DoorState) end)
            pcall(function() forcedOpen = tostring(door.bForceDoorWideOpen) end)

            print(string.format('[%s]   [%d] %s | State=%s | ForcedOpen=%s | TrackedOpened=%s',
                MOD_NAME, i, name, state, forcedOpen, tostring(OpenedDoors[name])))

            -- If door is currently locked but not KeyLocked (5), free it
            if state == '2' or state == tostring(EDoorState.Locked) then
                print(string.format('[%s]   -> Freeing locked door [%d]!', MOD_NAME, i))
                OpenedDoors[name] = true
                pcall(function()
                    door.DoorState = EDoorState.OpenEvenInCombat
                    door.bForceDoorWideOpen = true
                    if door.SetDoorForcedOpen then
                        door:SetDoorForcedOpen(true)
                    end
                end)
            end
        end
    end
    print(string.format('[%s] === END OF F8 SCAN ===', MOD_NAME))
end)

print(string.format('[%s] Setup complete. Promote-on-Open strategy active (F8 diagnostic available).', MOD_NAME))
