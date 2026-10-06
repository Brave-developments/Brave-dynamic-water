local activeDisaster = nil
local currentOceanLevel = Config.Ocean.defaultLevel

local function DebugPrint(...)
    if not Config.Debug then return end

    local parts = {}
    for i = 1, select('#', ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end

    print(('[%s:server:debug] %s'):format(Config.BrandName, table.concat(parts, ' ')))
end

local function HasPermission(source)
    if source == 0 then
        DebugPrint('Permission check', 'source=console', 'allowed=true')
        return true
    end

    local aces = Config.Permissions and Config.Permissions.aces or {}
    for i = 1, #aces do
        local ace = aces[i]
        local allowed = IsPlayerAceAllowed(source, ace)

        DebugPrint('Permission check', 'source=', source, 'ace=', ace, 'allowed=', allowed)

        if allowed then
            return true
        end
    end

    return false
end

local function GetPermissionText()
    local aces = Config.Permissions and Config.Permissions.aces or {}
    return table.concat(aces, ', ')
end

local function Notify(source, message)
    if source == 0 then
        print(('[%s] %s'):format(Config.BrandName, message))
        return
    end

    TriggerClientEvent('chat:addMessage', source, {
        args = { Config.BrandName, message }
    })
end

local function GetDisaster(disasterName)
    disasterName = disasterName and disasterName:lower()
    DebugPrint('GetDisaster', 'name=', disasterName)

    if not disasterName or not Config.Disasters[disasterName] then
        return nil, nil
    end

    local disaster = Config.Disasters[disasterName]
    if not Config.EnabledPacks[disaster.pack] then
        return nil, ('%s is disabled.'):format(disaster.pack or 'Pack')
    end

    return disasterName, disaster
end

local function BuildDisasterPayload(disasterName, disaster)
    local countdown = tonumber(disaster.countdown) or 0

    return {
        name = disasterName,
        label = disaster.label or disasterName,
        data = disaster,
        startsAt = os.time() + countdown,
        endsAt = os.time() + countdown + (tonumber(disaster.duration) or 0)
    }
end

local function StartDisaster(source, disasterName)
    DebugPrint('StartDisaster command received', 'source=', source, 'name=', disasterName)

    if not HasPermission(source) then
        Notify(source, ('Missing txAdmin permission. Required ACE: %s'):format(GetPermissionText()))
        return
    end

    local resolvedName, disasterOrError = GetDisaster(disasterName)
    if not resolvedName then
        Notify(source, disasterOrError or ('Usage: /%s [disaster]'):format(Config.Commands.disaster))
        return
    end

    activeDisaster = BuildDisasterPayload(resolvedName, disasterOrError)
    DebugPrint('Broadcasting disaster start', activeDisaster.name, activeDisaster.label, 'startsAt=', activeDisaster.startsAt, 'endsAt=', activeDisaster.endsAt)
    TriggerClientEvent('dynamicwater:client:StartDisaster', -1, activeDisaster)
    Notify(source, ('Started %s.'):format(activeDisaster.label))
end

local function StopDisaster(source)
    DebugPrint('StopDisaster command received', 'source=', source)

    if not HasPermission(source) then
        Notify(source, ('Missing txAdmin permission. Required ACE: %s'):format(GetPermissionText()))
        return
    end

    activeDisaster = nil
    DebugPrint('Broadcasting disaster stop')
    TriggerClientEvent('dynamicwater:client:StopDisaster', -1)
    Notify(source, 'Stopped active disaster.')
end

local function SetOceanLevel(source, level)
    DebugPrint('SetOceanLevel command received', 'source=', source, 'level=', level)

    if not HasPermission(source) then
        Notify(source, ('Missing txAdmin permission. Required ACE: %s'):format(GetPermissionText()))
        return
    end

    if level == 'reset' then
        currentOceanLevel = Config.Ocean.resetLevel
    else
        currentOceanLevel = tonumber(level)
    end

    if not currentOceanLevel then
        Notify(source, ('Usage: /%s [level|reset]'):format(Config.Commands.oceanLevel))
        return
    end

    TriggerClientEvent('dynamicwater:client:SetOceanLevel', -1, currentOceanLevel)
    DebugPrint('Broadcasting ocean level', currentOceanLevel)

    if currentOceanLevel > Config.Ocean.safeMaxLevel then
        Notify(source, ('Ocean level set to %.2f. Levels above %.2f are at your own risk.'):format(currentOceanLevel, Config.Ocean.safeMaxLevel))
        return
    end

    Notify(source, ('Ocean level set to %.2f.'):format(currentOceanLevel))
end

RegisterNetEvent('dynamicwater:server:RequestState', function()
    local src = source
    DebugPrint('Client requested state', 'source=', src, 'ocean=', currentOceanLevel, 'active=', activeDisaster and activeDisaster.name or 'none')

    TriggerClientEvent('dynamicwater:client:SetOceanLevel', src, currentOceanLevel)

    if activeDisaster then
        TriggerClientEvent('dynamicwater:client:StartDisaster', src, activeDisaster)
    end
end)

RegisterCommand(Config.Commands.disaster, function(source, args)
    DebugPrint('Command fired', Config.Commands.disaster, 'source=', source, 'arg1=', args and args[1] or 'nil')
    StartDisaster(source, args[1])
end)

RegisterCommand(Config.Commands.stop, function(source)
    DebugPrint('Command fired', Config.Commands.stop, 'source=', source)
    StopDisaster(source)
end)

RegisterCommand(Config.Commands.oceanLevel, function(source, args)
    DebugPrint('Command fired', Config.Commands.oceanLevel, 'source=', source, 'arg1=', args and args[1] or 'nil')
    SetOceanLevel(source, args[1])
end)

RegisterCommand(Config.Commands.tsunami, function(source, args)
    DebugPrint('Command fired', Config.Commands.tsunami, 'source=', source, 'arg1=', args and args[1] or 'nil')
    StartDisaster(source, args[1] or 'tsunami')
end)

RegisterCommand(Config.Commands.stopTsunami, function(source)
    DebugPrint('Command fired', Config.Commands.stopTsunami, 'source=', source)
    StopDisaster(source)
end)

CreateThread(function()
    DebugPrint('Resource started. Commands:', ('/%s'):format(Config.Commands.disaster), ('/%s'):format(Config.Commands.stop), ('/%s'):format(Config.Commands.oceanLevel), ('/%s'):format(Config.Commands.tsunami), ('/%s'):format(Config.Commands.stopTsunami))
    DebugPrint('txAdmin ACEs accepted:', GetPermissionText())
end)
