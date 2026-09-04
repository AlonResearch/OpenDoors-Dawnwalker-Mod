-- Open Doors Mod for The Blood of Dawnwalker
-- Uses native engine primitives (EDoorState::OpenEvenInCombat) to prevent combat lockouts
-- while fully preserving narrative key-locked doors and vanilla combat controls.

local MOD_NAME = "OpenDoors"
local VERSION = "0.1.4"

print(string.format("[%s] Initializing version %s...", MOD_NAME, VERSION))

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

local function OnSetDoorStatePre(Context, InNewState, WasSystemicallyClosed, WasSilentlyClosed, OpeningActor, bInForcedOpen, bFromSave, InOpenDirection)
    local state = InNewState and InNewState:get() or nil
    local systemic = WasSystemicallyClosed and WasSystemicallyClosed:get() or false

    -- 1. Preserve Narrative Key-Locked Doors
    -- Narrative quest doors explicitly use EDoorState::KeyLocked (5). We never bypass these.
    if state == EDoorState.KeyLocked then
        print(string.format("[%s] Narrative Key-Locked door state detected (KeyLocked=5). Preserving normal quest logic.", MOD_NAME))
        return
    end

    -- 2. Intercept Systemic Encounter / Combat Closures
    -- When the game enters combat or triggers an encounter lockout, it passes WasSystemicallyClosed = true.
    if systemic == true then
        print(string.format("[%s] Intercepted systemic closure (WasSystemicallyClosed=true, TargetState=%s). Overriding to OpenEvenInCombat (3).", MOD_NAME, tostring(state)))
        if WasSystemicallyClosed then
            WasSystemicallyClosed:set(false)
        end
        if InNewState then
            InNewState:set(EDoorState.OpenEvenInCombat)
        end
        return
    end

    -- 3. Promote Opened Doors to Persist Through Future Combat
    -- When a door naturally opens (e.g. player stumbles into it or pushes it open),
    -- promote it to OpenEvenInCombat so the engine natively treats it as open during future fights.
    if state == EDoorState.Open then
        print(string.format("[%s] Promoting opened door from Open (1) to OpenEvenInCombat (3).", MOD_NAME))
        InNewState:set(EDoorState.OpenEvenInCombat)
    end
end

local function TryHookDoorFunctions()
    if HookedFunctions["SetDoorState"] then return true end

    -- Search for the SetDoorState function object in the engine's reflection table
    local setDoorStateFunc = FindObject("Function", "SetDoorState")
    if setDoorStateFunc and setDoorStateFunc:IsValid() then
        local fullName = setDoorStateFunc:GetFullName()
        -- Remove the type prefix (e.g. "Function /Script/...") to pass to RegisterHook
        local cleanName = fullName:gsub("^%a+ ", "")
        print(string.format("[%s] Found SetDoorState function: %s", MOD_NAME, cleanName))

        local preId, postId = RegisterHook(cleanName, OnSetDoorStatePre)
        if preId then
            HookedFunctions["SetDoorState"] = true
            print(string.format("[%s] Successfully hooked SetDoorState (PreId: %s)", MOD_NAME, tostring(preId)))
            return true
        else
            print(string.format("[%s] Failed to register hook on %s", MOD_NAME, cleanName))
        end
    end
    return false
end

-- Attempt immediate hook if already in memory
if not TryHookDoorFunctions() then
    print(string.format("[%s] SetDoorState not yet resident. Registering game init hooks...", MOD_NAME))

    RegisterInitGameStatePostHook(function()
        print(string.format("[%s] InitGameState fired. Attempting hook...", MOD_NAME))
        TryHookDoorFunctions()
    end)

    NotifyOnNewObject("/Script/Engine.World", function(world)
        print(string.format("[%s] New World loaded (%s). Verifying hooks...", MOD_NAME, world:GetFullName()))
        TryHookDoorFunctions()
    end)
end

print(string.format("[%s] Setup complete. Native primitives active.", MOD_NAME))
