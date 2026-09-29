--[[--------------------------------------------------------------------------
    HunterTracker - WotLK 3.3.5a (Marksmanship)

    Class module for TrackerCore. It only describes WHAT to track; the shared
    engine lives in TrackerCore. Layout (top to bottom):
      1. Abilities (target debuffs / self aspects & procs, only when active)
      2. Mana bar (WotLK hunters use mana, not focus)
      3. Cooldowns (8 per row, wraps)
    No secondary row and no warning bar: hunters have no combo-point style
    resource, so both are omitted from the config.
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
        -- playerOnly: this DoT lands on the target, so only OUR copy should
        -- read as active - another hunter's Serpent Sting is not our damage.
        { name = "Serpent Sting",         icon = "Interface\\Icons\\Ability_Hunter_Quickshot", size = 46, playerOnly = true },
        { name = "Rapid Fire",            icon = "Interface\\Icons\\Ability_Hunter_RapidKilling" },
        -- Talent proc, only shown while the buff is actually up. alwaysShow
        -- builds the icon (it is not in the spellbook) without keeping a slot
        -- reserved when the proc is down.
        { name = "Improved Steady Shot",  icon = "Interface\\Icons\\Ability_Hunter_ImprovedSteadyShot", alwaysShow = true },
        { name = "Aspect of the Cheetah", icon = "Interface\\Icons\\Ability_Hunter_Cheetah", size = 46 },
        { name = "Aspect of the Pack",    icon = "Interface\\Icons\\Ability_Hunter_AspectofthePack", size = 46 }
    },

    -- Trueshot Aura and Aspect of the Dragonhawk are not "look at it when up"
    -- icons; what matters is being told when they are DOWN.
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
    },

    debugSpells = { "Chimera Shot", "Kill Shot", "Readiness" },
    debugExtra = function()
        print(string.format("  Mana: %d / %d",
            UnitPower("player", 0) or 0, UnitPowerMax("player", 0) or 0))
    end
})
