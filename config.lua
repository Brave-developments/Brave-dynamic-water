Config = {}

Config.BrandName = 'Zindro Disasters'
Config.Debug = true

Config.Permissions = {
    -- txAdmin commonly grants admins broad ACE command access through group.admin.
    -- The txadmin.menu.* checks cover servers that expose txAdmin menu ACEs directly.
    aces = {
        'command',
        'txadmin.menu.view',
        'txadmin.menu.playerMode'
    }
}

Config.Commands = {
    disaster = 'disaster',
    stop = 'stopdisaster',
    oceanLevel = 'oceanlevel',
    tsunami = 'tsunami',
    stopTsunami = 'stoptsunami',
    localFlood = 'flood',
    loadWater = 'loadwater',
    resetWater = 'resetwater'
}

Config.EnabledPacks = {
    CoreDisasters = true,
    Stormfront = true,
    ApocalypseProtocol = true,
    ClimateExtremes = true,
    OceanSurge = true
}

Config.CountdownWarnings = { 180, 120, 60, 30, 10, 5, 4, 3, 2, 1 }

Config.Sound = {
    enabled = true,
    defaultVolume = 0.65
}

Config.Ocean = {
    safeMaxLevel = 10.0,
    defaultLevel = 0.0,
    resetLevel = 0.0,
    stepWait = 100,
    stepAmount = 0.1
}

Config.VehicleFailure = {
    enabled = true,
    checkInterval = 1500,
    engineHealth = -4000.0,
    bodyHealth = 100.0,
    disableDriveable = true,
    forceNpcDriversToLeave = true
}

Config.Disasters = {
    earthquake = {
        label = 'Earthquake',
        pack = 'CoreDisasters',
        duration = 120,
        countdown = 30,
        sound = 'earthquake',
        soundVolume = 0.7,
        cameraShake = 'LARGE_EXPLOSION_SHAKE',
        cameraShakeIntensity = 0.45,
        ragdollChance = 18,
        loopWait = 1800
    },
    storm = {
        label = 'Storm',
        pack = 'CoreDisasters',
        duration = 180,
        countdown = 30,
        sound = 'storm',
        weather = 'THUNDER',
        rainLevel = 1.0,
        windSpeed = 12.0
    },
    meteor_rain = {
        label = 'Meteor Rain',
        pack = 'CoreDisasters',
        duration = 180,
        countdown = 45,
        sound = 'meteor',
        impactRadius = 170.0,
        impactInterval = 900,
        projectilesPerWave = 4,
        projectileModel = 'w_lr_rpg_rocket',
        projectileSpawnHeight = 240.0,
        projectileTravelTime = 5500,
        projectileTrail = true,
        projectileFireball = true,
        projectileFireballScale = 3.5,
        projectileTrailScale = 1.4,
        projectileVisibleDistance = 900.0,
        projectileFarScaleMultiplier = 2.0,
        warningFlare = true,
        explosionType = 29,
        explosionDamageScale = 2.0
    },
    power_outage = {
        label = 'Power Outage',
        pack = 'Stormfront',
        duration = 300,
        countdown = 30,
        sound = 'power_outage',
        blackout = true
    },
    hurricane = {
        label = 'Hurricane',
        pack = 'Stormfront',
        duration = 300,
        countdown = 60,
        sound = 'hurricane',
        weather = 'THUNDER',
        rainLevel = 1.0,
        windSpeed = 24.0,
        cameraShake = 'SKY_DIVING_SHAKE',
        cameraShakeIntensity = 0.35,
        pushVehicles = true,
        loopWait = 2200
    },
    sandstorm = {
        label = 'Sandstorm',
        pack = 'Stormfront',
        duration = 240,
        countdown = 45,
        sound = 'sandstorm',
        weather = 'FOGGY',
        windSpeed = 16.0,
        timecycle = 'sandstorm',
        visibilityNotice = true
    },
    worlds_end = {
        label = 'The Worlds End',
        pack = 'ApocalypseProtocol',
        duration = 600,
        countdown = 120,
        sound = 'worlds_end',
        weather = 'THUNDER',
        rainLevel = 1.0,
        windSpeed = 28.0,
        blackout = true,
        earthquake = true,
        meteor = true,
        oceanLevel = 400.0,
        oceanStepAmount = 0.12,
        oceanStepWait = 90,
        impactRadius = 220.0,
        impactInterval = 650,
        projectilesPerWave = 7,
        projectileModel = 'w_lr_rpg_rocket',
        projectileSpawnHeight = 260.0,
        projectileTravelTime = 4500,
        projectileTrail = true,
        projectileFireball = true,
        projectileFireballScale = 4.0,
        projectileTrailScale = 1.7,
        projectileVisibleDistance = 1100.0,
        projectileFarScaleMultiplier = 2.2,
        warningFlare = true,
        explosionType = 29,
        explosionDamageScale = 2.5
    },
    extreme_cold = {
        label = 'Extreme Cold',
        pack = 'ClimateExtremes',
        duration = 300,
        countdown = 45,
        sound = 'cold',
        weather = 'XMAS',
        timecycle = 'prologue_ending_fog',
        damageOutside = true,
        damageAmount = 2,
        damageInterval = 8000
    },
    heatwave = {
        label = 'Extreme Heatwave',
        pack = 'ClimateExtremes',
        duration = 300,
        countdown = 45,
        sound = 'heatwave',
        weather = 'EXTRASUNNY',
        timecycle = 'BarryFadeOut',
        damageOutside = true,
        damageAmount = 2,
        damageInterval = 8000
    },
    tsunami = {
        label = 'Tsunami',
        pack = 'OceanSurge',
        duration = 600,
        countdown = 120,
        sound = 'siren',
        rainLevel = 1.0,
        windSpeed = 14.0,
        oceanStartLevel = 50.0,
        oceanLevel = 420.0,
        oceanStepAmount = 0.05,
        oceanStepWait = 100
    }
}
