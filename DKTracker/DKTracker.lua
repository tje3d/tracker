--[[--------------------------------------------------------------------------
    DKTracker - WotLK 3.3.5a (Unholy Death Knight)

    Class module for TrackerCore. It only describes WHAT to track; the shared
    engine lives in TrackerCore. Layout (top to bottom):
      1. Abilities (only visible when active on target/player)
      2. Runic Power bar
      3. Runes (6 wide rectangles, colored by rune type)
      4. Cooldowns (8 per row, wraps)
      5. Missing-upkeep warning (only when Horn of Winter is not up)
--------------------------------------------------------------------------]]

TrackerCore:RegisterModule({
    addonName = "DKTracker",
    dbName = "DKTrackerDB",
    className = "DEATHKNIGHT",
    printColor = "|cffc41e3a",

    -- 16 cooldowns = exactly two rows of 8, most-used first so the top row is
    -- the one that matters at a glance. Every entry is filtered through
    -- IsSpellKnown, so talents from a tree this character has not specced into
    -- simply never appear; keeping cross-tree entries is harmless and the list
    -- still works after a respec.
    cooldowns = {
        { name = "Mind Freeze",         icon = "Interface\\Icons\\Spell_Frost_MindFreeze",              glowWhenReady = true },
        { name = "Death Grip",          icon = "Interface\\Icons\\Spell_DeathKnight_DeathGrip",         glowWhenReady = true },
        { name = "Anti-Magic Shell",    icon = "Interface\\Icons\\Spell_Shadow_AntiMagicShell",         glowWhenReady = true },
        { name = "Icebound Fortitude",  icon = "Interface\\Icons\\Spell_DeathKnight_IceBoundFortitude", glowWhenReady = true },
        { name = "Blood Tap",           icon = "Interface\\Icons\\Spell_DeathKnight_BloodTap",          glowWhenReady = true },
        { name = "Empower Rune Weapon", icon = "Interface\\Icons\\Spell_DeathKnight_EmpowerRuneWeapon", glowWhenReady = true },
        { name = "Summon Gargoyle",     icon = "Interface\\Icons\\Spell_DeathKnight_SummonGargoyle",    glowWhenReady = true },
        { name = "Army of the Dead",    icon = "Interface\\Icons\\Spell_DeathKnight_ArmyOfTheDead",     glowWhenReady = true },
        { name = "Chains of Ice",       icon = "Interface\\Icons\\Spell_Frost_ChainsOfIce" },
        { name = "Strangulate",         icon = "Interface\\Icons\\Spell_DeathKnight_Strangulate" },
        { name = "Death Coil",          icon = "Interface\\Icons\\Spell_Shadow_DeathCoil" },
        { name = "Raise Dead",          icon = "Interface\\Icons\\Spell_DeathKnight_RaiseDead" },
        { name = "Lichborne",           icon = "Interface\\Icons\\Spell_Shadow_RaiseDead",              glowWhenReady = true },
        { name = "Anti-Magic Zone",     icon = "Interface\\Icons\\Spell_DeathKnight_AntiMagicZone",     glowWhenReady = true },
        { name = "Ghoul Frenzy",        icon = "Interface\\Icons\\Ability_GhoulFrenzy" },
        { name = "Hysteria",            icon = "Interface\\Icons\\Spell_DeathKnight_Hysteria" }
    },
    -- Aura row: only what is actually up on the player or the target is shown,
    -- with its remaining time and a clock sweep.
    abilities = {
        { name = "Blood Presence",   icon = "Interface\\Icons\\Spell_DeathKnight_BloodPresence" },
        { name = "Frost Presence",   icon = "Interface\\Icons\\Spell_DeathKnight_FrostPresence" },
        { name = "Unholy Presence",  icon = "Interface\\Icons\\Spell_DeathKnight_UnholyPresence" },
        -- playerOnly: these diseases land on the target, so only OUR copy
        -- should read as active - a second DK's Frost Fever/Blood Plague is
        -- not our damage.
        { name = "Frost Fever",      icon = "Interface\\Icons\\Spell_DeathKnight_FrostFever", size = 46, alwaysVisible = true, playerOnly = true },
        { name = "Blood Plague",     icon = "Interface\\Icons\\Spell_DeathKnight_BloodPlague", size = 46, alwaysVisible = true, playerOnly = true },
        { name = "Bone Shield",      icon = "Interface\\Icons\\Spell_DeathKnight_BoneShield", alwaysVisible = true },
        { name = "Horn of Winter",   icon = "Interface\\Icons\\Spell_DeathKnight_HornofWinter", alwaysVisible = true },
        { name = "Summon Gargoyle",  icon = "Interface\\Icons\\Spell_DeathKnight_SummonGargoyle" },
        { name = "Unholy Blight",    icon = "Interface\\Icons\\Spell_Shadow_UnholyBlight" }
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
        -- Only used when GetRuneType has no answer yet (the client forgets
        -- death runes across a login). Fixed 3.3.5 layout: rune IDs 1-2 blood,
        -- 3-4 unholy, 5-6 frost.
        fallbackType = { [1] = 1, [2] = 1, [3] = 2, [4] = 2, [5] = 3, [6] = 3 },
        -- Draw order left to right: blood, blood, frost, frost, unholy, unholy.
        -- Each entry is the client rune slot shown in that on-screen position.
        order = { 1, 2, 5, 6, 3, 4 }
    },
    warning = {
        type = "upkeep",
        name = "Horn of Winter",
        text = "MISSING: HORN OF WINTER"
    },

    debugSpells = { "Summon Gargoyle", "Bone Shield", "Death Grip" },
    debugExtra = function(elements, CONFIG)
        print(string.format("  Runic Power: %d / %d",
            UnitPower("player", 6) or 0, UnitPowerMax("player", 6) or 100))
        for i = 1, CONFIG.secondary.count do
            local start, duration, ready = GetRuneCooldown(i)
            local remaining = 0
            if start and duration and not ready then
                remaining = math.max(0, (start + duration) - GetTime())
            end
            print(string.format("  Rune [%d] type=%s ready=%s  %.2fs",
                i, tostring(GetRuneType(i)), tostring(ready), remaining))
        end
    end
})
