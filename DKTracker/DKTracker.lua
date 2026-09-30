--[[--------------------------------------------------------------------------
    DKTracker - WotLK 3.3.5a (Unholy)

    Class config for TrackerCore. Layout top to bottom:
      abilities, runic power, runes, cooldowns, Horn of Winter warning.
--------------------------------------------------------------------------]]

TrackerCore:RegisterModule({
    addonName = "DKTracker",
    dbName = "DKTrackerDB",
    className = "DEATHKNIGHT",
    printColor = "|cffc41e3a",

    -- 15 cooldowns, most-used first. IsSpellKnown hides untalented entries.
    cooldowns = {
        { name = "Mind Freeze",         icon = "Interface\\Icons\\Spell_Frost_MindFreeze",              glowWhenReady = true },
        { name = "Death Grip",          icon = "Interface\\Icons\\Spell_DeathKnight_DeathGrip",         glowWhenReady = true },
        { name = "Anti-Magic Shell",    icon = "Interface\\Icons\\Spell_Shadow_AntiMagicShell",         glowWhenReady = true },
        { name = "Icebound Fortitude",  icon = "Interface\\Icons\\Spell_DeathKnight_IceBoundFortitude", glowWhenReady = true },
        { name = "Blood Tap",           icon = "Interface\\Icons\\Spell_DeathKnight_BloodTap",          glowWhenReady = true },
        { name = "Empower Rune Weapon", icon = "Interface\\Icons\\Spell_DeathKnight_EmpowerRuneWeapon", glowWhenReady = true },
        { name = "Summon Gargoyle",     icon = "Interface\\Icons\\Spell_DeathKnight_SummonGargoyle",    glowWhenReady = true },
        { name = "Army of the Dead",    icon = "Interface\\Icons\\Spell_DeathKnight_ArmyOfTheDead",     glowWhenReady = true },
        { name = "Strangulate",         icon = "Interface\\Icons\\Spell_DeathKnight_Strangulate" },
        { name = "Death Coil",          icon = "Interface\\Icons\\Spell_Shadow_DeathCoil" },
        { name = "Raise Dead",          icon = "Interface\\Icons\\Spell_DeathKnight_RaiseDead" },
        { name = "Lichborne",           icon = "Interface\\Icons\\Spell_Shadow_RaiseDead",              glowWhenReady = true },
        { name = "Anti-Magic Zone",     icon = "Interface\\Icons\\Spell_DeathKnight_AntiMagicZone",     glowWhenReady = true },
        { name = "Ghoul Frenzy",        icon = "Interface\\Icons\\Ability_GhoulFrenzy" },
        { name = "Hysteria",            icon = "Interface\\Icons\\Spell_DeathKnight_Hysteria" },
        { name = "Mark of Blood",       icon = "Interface\\Icons\\Spell_DeathKnight_MarkOfBlood" }
    },
    -- Only shown while up on the player or target.
    abilities = {
        { name = "Blood Presence",   icon = "Interface\\Icons\\Spell_DeathKnight_BloodPresence" },
        { name = "Frost Presence",   icon = "Interface\\Icons\\Spell_DeathKnight_FrostPresence" },
        { name = "Unholy Presence",  icon = "Interface\\Icons\\Spell_DeathKnight_UnholyPresence" },
        -- playerOnly: only our own disease counts.
        { name = "Frost Fever",      icon = "Interface\\Icons\\Spell_DeathKnight_FrostFever", size = 46, alwaysVisible = true, playerOnly = true },
        { name = "Blood Plague",     icon = "Interface\\Icons\\Spell_DeathKnight_BloodPlague", size = 46, alwaysVisible = true, playerOnly = true },
        { name = "Bone Shield",      icon = "Interface\\Icons\\Spell_DeathKnight_BoneShield", alwaysVisible = true },
        { name = "Horn of Winter",   icon = "Interface\\Icons\\Spell_DeathKnight_HornofWinter", alwaysVisible = true },
        { name = "Summon Gargoyle",  icon = "Interface\\Icons\\Spell_DeathKnight_SummonGargoyle" },
        { name = "Unholy Blight",    icon = "Interface\\Icons\\Spell_Shadow_UnholyBlight" },
        -- Talent proc, not in the spellbook. Any rank shares the aura name.
        { name = "Desolation",       icon = "Interface\\Icons\\Spell_Shadow_ShadowWordDominate", alwaysShow = true }
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
        powerType = 6,          -- Runic Power
        dynamicMax = true,      -- Runic Power Mastery raises the cap
        max = 100,
        color = { 0.25, 0.6, 1 },
        height = 18
    },
    secondary = {
        type = "rune",
        count = 6,
        height = 18,
        -- GetRuneType: 1 = blood, 2 = unholy, 3 = frost, 4 = death.
        colors = {
            [1] = { 0.78, 0.11, 0.11 },  -- blood: red
            [2] = { 0.42, 0.79, 0.24 },  -- unholy: green
            [3] = { 0.33, 0.60, 0.90 },  -- frost: blue
            [4] = { 0.60, 0.30, 0.80 }   -- death: purple
        },
        dim = 0.55,
        -- Fallback when GetRuneType has no answer (death runes are forgotten
        -- across a login). IDs 1-2 blood, 3-4 unholy, 5-6 frost.
        fallbackType = { [1] = 1, [2] = 1, [3] = 2, [4] = 2, [5] = 3, [6] = 3 },
        -- Screen order left to right: blood, blood, frost, frost, unholy, unholy.
        order = { 1, 2, 5, 6, 3, 4 }
    },
    warning = {
        type = "upkeep",
        name = "Horn of Winter",
        text = "MISSING: HORN OF WINTER"
    }
})
