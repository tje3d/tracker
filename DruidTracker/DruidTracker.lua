--[[--------------------------------------------------------------------------
    DruidTracker - WotLK 3.3.5a (Balance)

    Class config for TrackerCore. Layout top to bottom: abilities, cooldowns.
--------------------------------------------------------------------------]]

TrackerCore:RegisterModule({
    addonName = "DruidTracker",
    dbName = "DruidTrackerDB",
    className = "DRUID",
    printColor = "|cffff7c0a",

    -- 14 cooldowns, most-used first. IsSpellKnown hides untalented entries.
    cooldowns = {
        { name = "Starfall",           icon = "Interface\\Icons\\Ability_Druid_Starfall",           glowWhenReady = true },
        { name = "Force of Nature",    icon = "Interface\\Icons\\Ability_Druid_ForceofNature",      glowWhenReady = true },
        { name = "Typhoon",            icon = "Interface\\Icons\\Ability_Druid_Typhoon",            glowWhenReady = true },
        { name = "Barkskin",           icon = "Interface\\Icons\\Spell_Nature_StoneClawTotem",      glowWhenReady = true },
        { name = "Nature's Grasp",     icon = "Interface\\Icons\\Spell_Nature_NaturesWrath" },
        { name = "Innervate",          icon = "Interface\\Icons\\Spell_Nature_Lightning" },
        { name = "Rebirth",            icon = "Interface\\Icons\\Spell_Nature_Reincarnation" },
        { name = "Cyclone",            icon = "Interface\\Icons\\Spell_Nature_EarthBind" },
        { name = "Entangling Roots",   icon = "Interface\\Icons\\Spell_Nature_StrangleVines" },
        { name = "Hibernate",          icon = "Interface\\Icons\\Spell_Nature_Sleep" },
        { name = "Tranquility",        icon = "Interface\\Icons\\Spell_Nature_Tranquility" },
        { name = "Nature's Swiftness", icon = "Interface\\Icons\\Spell_Nature_RavenForm" },
        { name = "Dash",               icon = "Interface\\Icons\\Ability_Druid_Sprint" },
        { name = "Challenging Roar",   icon = "Interface\\Icons\\Ability_Druid_ChallengingRoar" }
    },
    -- Only shown while up on the player or target.
    abilities = {
        -- Maintained target DoTs; greyscale while missing.
        -- playerOnly: only our own copy counts.
        { name = "Moonfire",        icon = "Interface\\Icons\\Spell_Nature_StarFall",       size = 46, alwaysVisible = true, playerOnly = true },
        { name = "Insect Swarm",    icon = "Interface\\Icons\\Spell_Nature_InsectSwarm",    size = 46, alwaysVisible = true, playerOnly = true },
        -- Applied by our Wrath/Starfire, so alwaysShow (not in the spellbook).
        { name = "Earth and Moon",  icon = "Interface\\Icons\\Ability_Druid_EarthandSky",  alwaysShow = true },
        { name = "Faerie Fire",     icon = "Interface\\Icons\\Spell_Nature_FaerieFire" },
        -- Eclipse procs (Solar/Lunar) share one talent but are separate auras.
        { name = "Eclipse (Solar)", spellID = 48517, icon = "Interface\\Icons\\Ability_Druid_Eclipse",       alwaysShow = true, size = 46 },
        { name = "Eclipse (Lunar)", spellID = 48518, icon = "Interface\\Icons\\Ability_Druid_EclipseOrange", alwaysShow = true, size = 46 },
        { name = "Nature's Grace",  icon = "Interface\\Icons\\Spell_Nature_NaturesBlessing", alwaysShow = true },
        { name = "Owlkin Frenzy",   icon = "Interface\\Icons\\Ability_Druid_OwlkinFrenzy",   alwaysShow = true },
        -- General self buffs / forms
        { name = "Starfall",        icon = "Interface\\Icons\\Ability_Druid_Starfall",      size = 46 },
        { name = "Moonkin Form",    icon = "Interface\\Icons\\Spell_Nature_ForceOfNature", alwaysVisible = true },
        { name = "Mark of the Wild",icon = "Interface\\Icons\\Spell_Nature_Regeneration" },
        { name = "Thorns",          icon = "Interface\\Icons\\Spell_Nature_Thorns" }
    },

    iconSize = 32,
    abilityIconSize = 36,
    spacing = 4,
    maxCooldownsPerRow = 8,
    point = { "CENTER", 0, -100 },
    scale = 1.0,
    locked = false
})
