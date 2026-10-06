local resourceName = GetCurrentResourceName()
local activeDisaster = nil
local activeToken = 0
local currentOceanLevel = Config.Ocean.defaultLevel
local waterThreadActive = false
local vehicleThreadActive = false
local originalWeather = nil
local originalBlackout = false

local function DebugPrint(...)
    if not Config.Debug then return end

    local parts = {}
    for i = 1, select('#', ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end

    print(('[%s:client:debug] %s'):format(Config.BrandName, table.concat(parts, ' ')))
end

local function Notify(message)
    TriggerEvent('chat:addMessage', {
        args = { Config.BrandName, message }
    })
end

local function PlaySound(soundName, volume, loop)
    if not Config.Sound.enabled or not soundName then return end

    DebugPrint('PlaySound', soundName, 'volume=', volume or Config.Sound.defaultVolume, 'loop=', loop == true)

    SendNUIMessage({
        action = 'play',
        sound = soundName,
        volume = volume or Config.Sound.defaultVolume,
        loop = loop == true
    })
end

local function StopSound(soundName)
    DebugPrint('StopSound', soundName or 'all')

    SendNUIMessage({
        action = soundName and 'stop' or 'stopAll',
        sound = soundName
    })
end

local function PrintWaterStats()
    print(('water quad count: %s'):format(GetWaterQuadCount()))
    print(('calming quad count: %s'):format(GetCalmingQuadCount()))
    print(('wave quad count: %s'):format(GetWaveQuadCount()))
end

local function LoadFloodWater()
    DebugPrint('LoadFloodWater called')

    local success = LoadWaterFromPath(resourceName, 'flood.xml')
    if success ~= 1 then
        print('Failed to load flood.xml, does the file exist within the resource?')
        return false
    end

    PrintWaterStats()
    return true
end

local function SetOceanLevel(level)
    level = tonumber(level) or Config.Ocean.defaultLevel
    currentOceanLevel = level
    DebugPrint('SetOceanLevel', level)

    local waterQuadCount = GetWaterQuadCount()
    for i = 1, waterQuadCount do
        SetWaterQuadLevel(i, level)
    end
end

local function ResetOcean()
    DebugPrint('ResetOcean')
    currentOceanLevel = Config.Ocean.resetLevel
    ResetWater()
end

local function RampOceanLevel(targetLevel, stepAmount, stepWait, token)
    if waterThreadActive then
        DebugPrint('RampOceanLevel skipped because thread is already active')
        return
    end

    waterThreadActive = true
    DebugPrint('RampOceanLevel started', 'target=', targetLevel, 'step=', stepAmount, 'wait=', stepWait)

    CreateThread(function()
        targetLevel = tonumber(targetLevel) or currentOceanLevel
        stepAmount = tonumber(stepAmount) or Config.Ocean.stepAmount
        stepWait = tonumber(stepWait) or Config.Ocean.stepWait

        while activeDisaster and token == activeToken and math.abs(currentOceanLevel - targetLevel) > 0.01 do
            if currentOceanLevel < targetLevel then
                SetOceanLevel(math.min(currentOceanLevel + stepAmount, targetLevel))
            else
                SetOceanLevel(math.max(currentOceanLevel - stepAmount, targetLevel))
            end

            Wait(stepWait)
        end

        waterThreadActive = false
        DebugPrint('RampOceanLevel stopped', 'current=', currentOceanLevel)
    end)
end

local function ApplyWeather(disaster)
    if not disaster.weather and not disaster.windSpeed and not disaster.rainLevel then return end

    DebugPrint('ApplyWeather', disaster.weather or 'none', 'rain=', disaster.rainLevel or 0.0, 'wind=', disaster.windSpeed or 0.0)

    originalWeather = originalWeather or Config.Weather and Config.Weather.resetWeather or 'CLEAR'

    if disaster.weather then
        SetWeatherTypeNowPersist(disaster.weather)
    end

    SetRainLevel(disaster.rainLevel or 0.0)
    SetWindSpeed(disaster.windSpeed or 0.0)
end

local function ResetWeather()
    DebugPrint('ResetWeather')
    SetWeatherTypeNowPersist(originalWeather or 'CLEAR')
    SetRainLevel(0.0)
    SetWindSpeed(0.0)
    originalWeather = nil
end

local function ApplyVisuals(disaster)
    DebugPrint('ApplyVisuals', 'blackout=', disaster.blackout == true, 'timecycle=', disaster.timecycle or 'none')

    if disaster.blackout then
        originalBlackout = true
        SetArtificialLightsState(true)
    end

    if disaster.timecycle then
        SetTimecycleModifier(disaster.timecycle)
        SetTimecycleModifierStrength(0.85)
    end
end

local function ResetVisuals()
    DebugPrint('ResetVisuals')

    if originalBlackout then
        SetArtificialLightsState(false)
        originalBlackout = false
    end

    ClearTimecycleModifier()
    StopGameplayCamShaking(true)
end

local function IsVehicleSubmerged(vehicle)
    if not DoesEntityExist(vehicle) or not IsEntityInWater(vehicle) then
        return false
    end

    local coords = GetEntityCoords(vehicle)
    local success, waterHeight = GetWaterHeight(coords.x, coords.y, coords.z + 10.0)

    return success and waterHeight and waterHeight > coords.z + 0.35
end

local function DisableSubmergedVehicle(vehicle)
    DebugPrint('DisableSubmergedVehicle', vehicle)

    SetVehicleEngineOn(vehicle, false, true, true)
    SetVehicleEngineHealth(vehicle, Config.VehicleFailure.engineHealth)
    SetVehicleBodyHealth(vehicle, Config.VehicleFailure.bodyHealth)

    if Config.VehicleFailure.disableDriveable then
        SetVehicleUndriveable(vehicle, true)
    end

    if Config.VehicleFailure.forceNpcDriversToLeave then
        local driver = GetPedInVehicleSeat(vehicle, -1)
        if driver ~= 0 and not IsPedAPlayer(driver) then
            TaskLeaveVehicle(driver, vehicle, 4160)
        end
    end
end

local function StartVehicleThread(token)
    if vehicleThreadActive or not Config.VehicleFailure.enabled then
        DebugPrint('StartVehicleThread skipped', 'active=', vehicleThreadActive, 'enabled=', Config.VehicleFailure.enabled)
        return
    end

    vehicleThreadActive = true
    DebugPrint('StartVehicleThread')

    CreateThread(function()
        while activeDisaster and token == activeToken do
            local vehicles = GetGamePool('CVehicle')

            for i = 1, #vehicles do
                if IsVehicleSubmerged(vehicles[i]) then
                    DisableSubmergedVehicle(vehicles[i])
                end
            end

            Wait(Config.VehicleFailure.checkInterval)
        end

        vehicleThreadActive = false
        DebugPrint('Vehicle thread stopped')
    end)
end

local function StartPedWaterThread(token)
    DebugPrint('StartPedWaterThread')

    CreateThread(function()
        while activeDisaster and token == activeToken do
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local waterQuad = GetWaterQuadAtCoords_3d(coords.x, coords.y, coords.z)

            if waterQuad ~= -1 then
                local allPeds = GetGamePool('CPed')
                for i = 1, #allPeds do
                    SetPedConfigFlag(allPeds[i], 65, true)
                    SetPedDiesInWater(allPeds[i], true)
                end
            end

            Wait(5000)
        end
    end)
end

local function IsOutside()
    return GetInteriorFromEntity(PlayerPedId()) == 0
end

local function StartClimateDamage(disaster, token)
    if not disaster.damageOutside then return end

    DebugPrint('StartClimateDamage', 'amount=', disaster.damageAmount, 'interval=', disaster.damageInterval)

    CreateThread(function()
        while activeDisaster and token == activeToken do
            if IsOutside() then
                local ped = PlayerPedId()
                local health = GetEntityHealth(ped)
                if health > 110 then
                    SetEntityHealth(ped, health - (tonumber(disaster.damageAmount) or 1))
                end
            end

            Wait(tonumber(disaster.damageInterval) or 8000)
        end
    end)
end

local function PushNearbyVehicles()
    local vehicles = GetGamePool('CVehicle')
    local playerCoords = GetEntityCoords(PlayerPedId())

    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if #(GetEntityCoords(vehicle) - playerCoords) < 120.0 then
            ApplyForceToEntity(vehicle, 1, math.random(-8, 8) + 0.0, math.random(-8, 8) + 0.0, 1.5, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
        end
    end
end

local function StartEarthquake(disaster, token)
    if not disaster.earthquake and not disaster.cameraShake and not disaster.ragdollChance then return end

    DebugPrint('StartEarthquake')

    CreateThread(function()
        while activeDisaster and token == activeToken do
            ShakeGameplayCam(disaster.cameraShake or 'LARGE_EXPLOSION_SHAKE', disaster.cameraShakeIntensity or 0.35)

            if math.random(100) <= (tonumber(disaster.ragdollChance) or 0) then
                SetPedToRagdoll(PlayerPedId(), 1200, 1800, 0, false, false, false)
            end

            if disaster.pushVehicles then
                PushNearbyVehicles()
            end

            Wait(tonumber(disaster.loopWait) or 2000)
        end
    end)
end

local function GetRandomImpactCoords(radius)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local angle = math.random() * math.pi * 2
    local distance = math.random(30, math.floor(radius or 150.0))
    local x = playerCoords.x + math.cos(angle) * distance
    local y = playerCoords.y + math.sin(angle) * distance
    local success, groundZ = GetGroundZFor_3dCoord(x, y, playerCoords.z + 250.0, false)

    return vector3(x, y, success and groundZ or playerCoords.z)
end

local function RequestModelSafe(model)
    if not model or not IsModelInCdimage(model) then return false end

    RequestModel(model)

    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then
            return false
        end

        Wait(0)
    end

    return true
end

local function SpawnMeteorProjectile(disaster, impactCoords)
    local model = disaster.projectileModel or 'w_lr_rpg_rocket'
    if type(model) == 'string' then
        model = GetHashKey(model)
    end

    local spawnHeight = tonumber(disaster.projectileSpawnHeight) or 180.0
    local travelTime = tonumber(disaster.projectileTravelTime) or 1800
    local startCoords = vector3(
        impactCoords.x + math.random(-80, 80),
        impactCoords.y + math.random(-80, 80),
        impactCoords.z + spawnHeight
    )

    if disaster.warningFlare then
        DrawLightWithRange(impactCoords.x, impactCoords.y, impactCoords.z + 2.0, 255, 80, 30, 35.0, 8.0)
    end

    if not RequestModelSafe(model) then
        return nil
    end

    local projectile = CreateObjectNoOffset(model, startCoords.x, startCoords.y, startCoords.z, false, false, false)
    if not DoesEntityExist(projectile) then
        SetModelAsNoLongerNeeded(model)
        return nil
    end

    SetEntityCollision(projectile, false, false)
    SetEntityDynamic(projectile, false)
    SetEntityLodDist(projectile, 1000)

    local heading = GetHeadingFromVector_2d(impactCoords.x - startCoords.x, impactCoords.y - startCoords.y)
    SetEntityHeading(projectile, heading)

    CreateThread(function()
        local startedAt = GetGameTimer()

        while DoesEntityExist(projectile) do
            local elapsed = GetGameTimer() - startedAt
            local progress = math.min(elapsed / travelTime, 1.0)
            local x = startCoords.x + (impactCoords.x - startCoords.x) * progress
            local y = startCoords.y + (impactCoords.y - startCoords.y) * progress
            local z = startCoords.z + (impactCoords.z - startCoords.z) * progress

            SetEntityCoordsNoOffset(projectile, x, y, z, false, false, false)

            local playerCoords = GetEntityCoords(PlayerPedId())
            local distance = #(playerCoords - vector3(x, y, z))
            local visibleDistance = tonumber(disaster.projectileVisibleDistance) or 900.0
            local distanceScale = 1.0 + math.min(distance / visibleDistance, 1.0) * ((tonumber(disaster.projectileFarScaleMultiplier) or 2.0) - 1.0)

            if disaster.projectileFireball and distance <= visibleDistance then
                local fireballScale = (tonumber(disaster.projectileFireballScale) or 3.5) * distanceScale
                DrawMarker(28, x, y, z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, fireballScale, fireballScale, fireballScale, 255, 85, 20, 210, false, false, 2, false, nil, nil, false)
            end

            if disaster.projectileTrail and distance <= visibleDistance then
                local trailScale = (tonumber(disaster.projectileTrailScale) or 1.4) * distanceScale
                DrawLightWithRange(x, y, z, 255, 120, 40, 20.0, 5.0)

                for i = 1, 4 do
                    local trailProgress = math.max(progress - (i * 0.025), 0.0)
                    local tx = startCoords.x + (impactCoords.x - startCoords.x) * trailProgress
                    local ty = startCoords.y + (impactCoords.y - startCoords.y) * trailProgress
                    local tz = startCoords.z + (impactCoords.z - startCoords.z) * trailProgress
                    local alpha = 150 - (i * 25)

                    DrawMarker(28, tx, ty, tz, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, trailScale, trailScale, trailScale, 255, 140, 35, alpha, false, false, 2, false, nil, nil, false)
                end
            end

            if progress >= 1.0 then
                DeleteEntity(projectile)
                SetModelAsNoLongerNeeded(model)
                break
            end

            Wait(0)
        end
    end)

    return projectile
end

local function StartMeteorRain(disaster, token)
    if not disaster.meteor and activeDisaster.name ~= 'meteor_rain' then return end

    DebugPrint('StartMeteorRain')

    CreateThread(function()
        while activeDisaster and token == activeToken do
            local projectilesPerWave = tonumber(disaster.projectilesPerWave) or 1

            for i = 1, projectilesPerWave do
                CreateThread(function()
                    local impactCoords = GetRandomImpactCoords(disaster.impactRadius)
                    SpawnMeteorProjectile(disaster, impactCoords)
                    Wait(math.max(250, tonumber(disaster.projectileTravelTime) or 1800))
                    AddExplosion(impactCoords.x, impactCoords.y, impactCoords.z, disaster.explosionType or 29, disaster.explosionDamageScale or 1.0, true, false, 1.0)
                end)

                Wait(180)
            end

            Wait(tonumber(disaster.impactInterval) or 2500)
        end
    end)
end

local function RunCountdown(payload, token)
    local startsAt = tonumber(payload.startsAt) or 0
    DebugPrint('RunCountdown', payload.label, 'startsAt=', startsAt)

    if startsAt <= 0 then return true end

    while token == activeToken do
        local remaining = startsAt - GetCloudTimeAsInt()
        if remaining <= 0 then return true end

        for i = 1, #Config.CountdownWarnings do
            if remaining == Config.CountdownWarnings[i] then
                Notify(('%s starts in %s seconds. Get to safety.'):format(payload.label, remaining))
                break
            end
        end

        Wait(1000)
    end

    return false
end

local function StopDisaster()
    DebugPrint('StopDisaster')
    activeToken = activeToken + 1
    activeDisaster = nil
    ResetOcean()
    ResetWeather()
    ResetVisuals()
    StopSound()
end

local function StartDisaster(payload)
    DebugPrint('StartDisaster event payload', payload and payload.name or 'nil')

    if not payload then
        DebugPrint('StartDisaster aborted: nil payload')
        return
    end

    StopDisaster()
    LoadFloodWater()

    activeDisaster = payload
    local token = activeToken
    local disaster = payload.data or {}

    CreateThread(function()
        if not RunCountdown(payload, token) then return end
        if not activeDisaster or token ~= activeToken then return end

        DebugPrint('Disaster activated', payload.name, payload.label)
        Notify(('%s is now active.'):format(payload.label))
        PlaySound(disaster.sound, disaster.soundVolume, true)
        ApplyWeather(disaster)
        ApplyVisuals(disaster)
        StartEarthquake(disaster, token)
        StartMeteorRain(disaster, token)
        StartClimateDamage(disaster, token)
        StartVehicleThread(token)
        StartPedWaterThread(token)

        if disaster.oceanLevel then
            if disaster.oceanStartLevel then
                SetOceanLevel(disaster.oceanStartLevel)
            end

            RampOceanLevel(disaster.oceanLevel, disaster.oceanStepAmount, disaster.oceanStepWait, token)
        end

        local endsAt = tonumber(payload.endsAt) or 0
        while activeDisaster and token == activeToken and endsAt > 0 and GetCloudTimeAsInt() < endsAt do
            Wait(1000)
        end

        if activeDisaster and token == activeToken and endsAt > 0 then
            Notify(('%s has ended.'):format(payload.label))
            StopDisaster()
        end
    end)
end

AddEventHandler('onClientResourceStart', function(startedResourceName)
    if resourceName ~= startedResourceName then return end

    DebugPrint('Client resource started, requesting server state')
    LoadFloodWater()
    TriggerServerEvent('dynamicwater:server:RequestState')
end)

AddEventHandler('onClientResourceStop', function(stoppedResourceName)
    if resourceName ~= stoppedResourceName then return end

    StopDisaster()
end)

RegisterNetEvent('dynamicwater:client:StartDisaster', function(payload)
    DebugPrint('Received StartDisaster event', payload and payload.name or 'nil')
    StartDisaster(payload)
end)

RegisterNetEvent('dynamicwater:client:StopDisaster', function()
    DebugPrint('Received StopDisaster event')
    StopDisaster()
    Notify('Active disaster stopped.')
end)

RegisterNetEvent('dynamicwater:client:SetOceanLevel', function(level)
    DebugPrint('Received SetOceanLevel event', level)
    LoadFloodWater()
    SetOceanLevel(level)
end)

RegisterCommand(Config.Commands.loadWater, function()
    DebugPrint('Local command fired', Config.Commands.loadWater)
    LoadFloodWater()
end)

RegisterCommand(Config.Commands.resetWater, function()
    DebugPrint('Local command fired', Config.Commands.resetWater)
    StopDisaster()
end)

RegisterCommand('stopflood', function()
    DebugPrint('Local command fired stopflood')
    StopDisaster()
end)

RegisterCommand(Config.Commands.localFlood, function(_, args)
    DebugPrint('Local command fired', Config.Commands.localFlood, 'arg1=', args and args[1] or 'nil')

    local disaster = Config.Disasters.tsunami
    local level = tonumber(args[1]) or disaster.oceanLevel

    StartDisaster({
        name = 'local_flood',
        label = 'Local Flood',
        data = {
            oceanLevel = level,
            oceanStepAmount = disaster.oceanStepAmount,
            oceanStepWait = disaster.oceanStepWait,
            weather = disaster.weather,
            rainLevel = disaster.rainLevel,
            windSpeed = disaster.windSpeed,
            sound = disaster.sound
        },
        startsAt = 0,
        endsAt = 0
    })
end)

CreateThread(function()
    DebugPrint('Client commands registered:', ('/%s'):format(Config.Commands.loadWater), ('/%s'):format(Config.Commands.resetWater), '/stopflood', ('/%s'):format(Config.Commands.localFlood))
end)
