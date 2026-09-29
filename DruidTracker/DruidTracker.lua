--[[--------------------------------------------------------------------------
    DruidTracker - WotLK 3.3.5a (Balance)

    Class module for TrackerCore. It only describes WHAT to track; the shared
    engine lives in TrackerCore. Layout (top to bottom):
      1. Abilities (target DoTs/debuffs, self procs & buffs, only when active)
      2. Cooldowns (8 per row, wraps)
    No mana bar and no secondary row (no combo-point style resource).
--------------------------------------------------------------------------]]

TrackerCore:RegisterModule({
    addonName = "DruidTracker",
    dbName = "DruidTrackerDB",
    className = "DRUID",
    printColor = "|cffff7c0a",

    -- 14 cooldowns, most-used first (8 per row, wraps). Cross-tree entries are
    -- harmless: IsSpellKnown hides the ones this character never learned.
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
    -- Aura row: everything here is only shown while it is actually up on the
    -- player or the target, with remaining time and a clock sweep.
    abilities = {
        -- Balance - the maintained target DoTs stay on screen and go grayscale
        -- while they are missing from the target. playerOnly: these land on the
        -- target, so only OUR copy should read as active - another druid's
        -- Moonfire/Insect Swarm is not our damage.
        { name = "Moonfire",        icon = "Interface\\Icons\\Spell_Nature_StarFall",       size = 46, alwaysVisible = true, playerOnly = true },
        { name = "Insect Swarm",    icon = "Interface\\Icons\\Spell_Nature_InsectSwarm",    size = 46, alwaysVisible = true, playerOnly = true },
        -- Earth and Moon is applied by our Wrath/Starfire; it never appears in
        -- the spellbook, so alwaysShow builds the icon. It does not deal damage,
        -- so it is not restricted to our own cast.
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
    blinkThreshold = 5,
    point = { "CENTER", 0, -100 },
    scale = 1.0,
    locked = false,

    debugSpells = { "Starfall", "Force of Nature", "Typhoon", "Eclipse (Solar)" }
})
