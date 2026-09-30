--[[--------------------------------------------------------------------------
    HunterTracker - WotLK 3.3.5a (Marksmanship)

    Class config for TrackerCore. Layout top to bottom: abilities, mana, cooldowns.
--------------------------------------------------------------------------]]

TrackerCore:RegisterModule({
    addonName = "HunterTracker",
    dbName = "HunterTrackerDB",
    className = "HUNTER",
    printColor = "|cffabd473",

    cooldowns = {
        { name = "Kill Shot",         icon = "Interface\\Icons\\Ability_Hunter_Assassinate",   glowWhenReady = true },
        { name = "Chimera Shot",      icon = "Interface\\Icons\\Ability_Hunter_ChimeraShot",   glowWhenReady = true },
        { name = "Aimed Shot",        icon = "Interface\\Icons\\Ability_Hunter_SniperShot",    glowWhenReady = true },
        { name = "Arcane Shot",       icon = "Interface\\Icons\\Ability_ImpalingBolt" },
        { name = "Serpent Sting",     icon = "Interface\\Icons\\Ability_Hunter_Quickshot" },
        { name = "Rapid Fire",        icon = "Interface\\Icons\\Ability_Hunter_RapidKilling",  glowWhenReady = true },
        { name = "Readiness",         icon = "Interface\\Icons\\Ability_Hunter_Readiness",     glowWhenReady = true },
        { name = "Silencing Shot",    icon = "Interface\\Icons\\Ability_Hunter_SilencingShot", glowWhenReady = true },
        { name = "Deterrence",        icon = "Interface\\Icons\\Ability_Hunter_CombatExperience" },
        { name = "Disengage",         icon = "Interface\\Icons\\Ability_Hunter_Disengage" },
        { name = "Feign Death",       icon = "Interface\\Icons\\Ability_Rogue_FeignDeath" },
        { name = "Misdirection",      icon = "Interface\\Icons\\Ability_Hunter_Misdirection" },
        { name = "Scatter Shot",      icon = "Interface\\Icons\\Ability_GolemStormBolt" },
        { name = "Multi-Shot",        icon = "Interface\\Icons\\Ability_Hunter_MultiShot" }
    },
    abilities = {
        { name = "Hunter's Mark",         icon = "Interface\\Icons\\Ability_Hunter_SniperShot" },
        -- playerOnly: only our own Serpent Sting counts.
        { name = "Serpent Sting",         icon = "Interface\\Icons\\Ability_Hunter_Quickshot", size = 46, playerOnly = true },
        { name = "Rapid Fire",            icon = "Interface\\Icons\\Ability_Hunter_RapidKilling" },
        -- Talent proc; alwaysShow builds the icon.
        { name = "Improved Steady Shot",  icon = "Interface\\Icons\\Ability_Hunter_ImprovedSteadyShot", alwaysShow = true },
        { name = "Aspect of the Cheetah", icon = "Interface\\Icons\\Ability_Hunter_Cheetah", size = 46 },
        { name = "Aspect of the Pack",    icon = "Interface\\Icons\\Ability_Hunter_AspectofthePack", size = 46 }
    },

    -- Warn when these are down, instead of showing them while up.
    warning = {
        type = "auras",
        prefix = "MISSING: ",
        auras = {
            { name = "Trueshot Aura",            text = "Trueshot Aura" },
            { name = "Aspect of the Dragonhawk", text = "Dragonhawk" }
        }
    },

    iconSize = 32,
    abilityIconSize = 36,
    spacing = 4,
    maxCooldownsPerRow = 8,
    blinkThreshold = 5,
    point = { "CENTER", 0, -100 },
    scale = 1.0,
    locked = false,

    resource = {
        powerType = 0,          -- Mana
        dynamicMax = true,      -- max mana scales with Intellect
        max = 100,
        color = { 0.25, 0.45, 0.85 },
        height = 18
    }
})
