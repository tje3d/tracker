--[[--------------------------------------------------------------------------
    WarlockTracker - WotLK 3.3.5a (Affliction, Destruction & Demonology)

    Class module for TrackerCore. It only describes WHAT to track; the shared
    engine lives in TrackerCore. All three specs share one module because every
    entry is filtered through IsSpellKnown, so only the talents this character
    actually has ever appear (and the list survives a respec). Layout (top to
    bottom):
      1. Abilities (DoTs/curses on the target, self buffs & procs, only while
         active)
      2. Cooldowns (8 per row, wraps)
    No mana bar (per request) and no secondary row (soul shards are
    pet-agnostic items, not a tracked power).
--------------------------------------------------------------------------]]

TrackerCore:RegisterModule({
    addonName = "WarlockTracker",
    dbName = "WarlockTrackerDB",
    className = "WARLOCK",
    printColor = "|cff8788ee",

    -- 17 cooldowns, most-used first (8 per row, wraps). Cross-spec entries
    -- are harmless: IsSpellKnown hides the ones this character never learned.
    cooldowns = {
        { name = "Haunt",                   icon = "Interface\\Icons\\Ability_Warlock_Haunt",           glowWhenReady = true },
        { name = "Death Coil",              icon = "Interface\\Icons\\Spell_Shadow_DeathCoil" },
        { name = "Howl of Terror",          icon = "Interface\\Icons\\Spell_Shadow_HowlofTerror" },
        { name = "Banish",                  icon = "Interface\\Icons\\Spell_Shadow_Cripple" },
        { name = "Shadowfury",              icon = "Interface\\Icons\\Spell_Shadow_Shadowfury",             glowWhenReady = true },
        { name = "Shadowflame",             icon = "Interface\\Icons\\Spell_Fire_Incinerate" },
        { name = "Conflagrate",             icon = "Interface\\Icons\\Spell_Fire_Fireball",                 glowWhenReady = true },
        { name = "Chaos Bolt",              icon = "Interface\\Icons\\Spell_Chaos_BlueLightning",           glowWhenReady = true },
        { name = "Shadowburn",              icon = "Interface\\Icons\\Spell_Shadow_ScourgeBuild" },
        { name = "Metamorphosis",           icon = "Interface\\Icons\\Spell_Shadow_DemonForm",              glowWhenReady = true },
        { name = "Demonic Empowerment",     icon = "Interface\\Icons\\Spell_Shadow_DemonicEmpowerment",     glowWhenReady = true },
        { name = "Fel Domination",          icon = "Interface\\Icons\\Spell_Nature_RemoveCurse",            glowWhenReady = true },
        { name = "Demonic Circle: Teleport",icon = "Interface\\Icons\\Spell_Shadow_DemonicCircleTeleport", glowWhenReady = true },
        { name = "Summon Infernal",         icon = "Interface\\Icons\\Spell_Shadow_SummonInfernal" },
        { name = "Summon Doomguard",        icon = "Interface\\Icons\\Spell_Shadow_SummonVoidWalker" },
        { name = "Shadow Ward",             icon = "Interface\\Icons\\Spell_Shadow_AntiShadow" },
        { name = "Soulshatter",             icon = "Interface\\Icons\\Spell_Shadow_SoulLeech" }
    },
    -- Aura row: everything here is only shown while it is actually up on the
    -- player or the target, with remaining time and a clock sweep. Entries with
    -- alwaysShow are procs/effects that are not learnable spells, so
    -- IsSpellKnown would otherwise never build their icon.
    abilities = {
        -- Affliction - the maintained DoTs/curses stay on screen and go grayscale
        -- while they are missing from the target.
        -- playerOnly: these land on the target, so only OUR copy should count
        -- as active - a second warlock's Corruption/UA/curse is not our damage.
        { name = "Unstable Affliction",  icon = "Interface\\Icons\\Spell_Shadow_UnstableAffliction_3", size = 46, alwaysVisible = true, playerOnly = true },
        { name = "Corruption",           icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", size = 46, alwaysVisible = true, playerOnly = true },
        -- Only one curse can be active, so they form a group: whichever is up
        -- is shown, the rest are hidden; all show grayscale when none is up.
        { name = "Curse of Agony",       icon = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras",      size = 46, alwaysVisible = true, group = "curse", playerOnly = true },
        { name = "Curse of the Elements",icon = "Interface\\Icons\\Spell_Shadow_ChillTouch",          alwaysVisible = true, group = "curse", playerOnly = true },
        { name = "Curse of Doom",        icon = "Interface\\Icons\\Spell_Shadow_CurseOfMannoroth",    alwaysVisible = true, group = "curse", playerOnly = true },
        { name = "Curse of Tongues",     icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges",       alwaysVisible = true, group = "curse", playerOnly = true },
        { name = "Haunt",                icon = "Interface\\Icons\\Ability_Warlock_Haunt",             size = 46, alwaysVisible = true, playerOnly = true },
        { name = "Siphon Life",          icon = "Interface\\Icons\\Spell_Shadow_Requiem",              playerOnly = true },
        { name = "Seed of Corruption",   icon = "Interface\\Icons\\Spell_Shadow_SeedOfDestruction",    playerOnly = true },
        -- Nightfall makes the next Shadow Bolt instant; the proc is "Shadow Trance".
        { name = "Shadow Trance",        icon = "Interface\\Icons\\Spell_Shadow_TwistedFaith", alwaysShow = true },
        { name = "Eradication",          icon = "Interface\\Icons\\ability_warlock_eradication", alwaysShow = true },
        -- Destruction
        { name = "Immolate",             icon = "Interface\\Icons\\Spell_Fire_Immolation",             size = 46, playerOnly = true },
        { name = "Backdraft",            icon = "Interface\\Icons\\Spell_Fire_Fire",                   alwaysShow = true, showCount = true },
        { name = "Molten Core",          icon = "Interface\\Icons\\Spell_Fire_Fireball",               alwaysShow = true, showCount = true },
        -- Improved Shadow Bolt applies "Shadow Mastery": +5% spell crit taken,
        -- the same effect as a mage's Improved Scorch.
        { name = "Shadow Mastery",       spellID = 17800, icon = "Interface\\Icons\\Spell_Shadow_ShadowBolt", alwaysShow = true },
        { name = "Nether Protection",    icon = "Interface\\Icons\\Spell_Shadow_NetherProtection",     alwaysShow = true },
        { name = "Backlash",             icon = "Interface\\Icons\\Spell_Fire_Fire",                   alwaysShow = true },
        -- Demonology
        { name = "Metamorphosis",        icon = "Interface\\Icons\\Spell_Shadow_DemonForm",            size = 46 },
        { name = "Decimation",           icon = "Interface\\Icons\\Spell_Shadow_ShadowBolt",           alwaysShow = true },
        { name = "Demonic Pact",         icon = "Interface\\Icons\\Spell_Shadow_DemonicPact",          alwaysShow = true },
        { name = "Fel Domination",       icon = "Interface\\Icons\\Spell_Nature_RemoveCurse",          alwaysShow = true },
        -- General self buffs
        -- Glyph of Life Tap leaves a "Life Tap" buff (63321) that boosts spell power.
        { name = "Life Tap",             spellID = 63321, icon = "Interface\\Icons\\Spell_Shadow_BurningSpirit", alwaysVisible = true },
        { name = "Soul Link",            icon = "Interface\\Icons\\Spell_Shadow_GrimWard" },
        { name = "Fel Armor",            icon = "Interface\\Icons\\Spell_Shadow_FelArmour" },
        { name = "Demon Armor",          icon = "Interface\\Icons\\Spell_Shadow_RagingScream" },
        { name = "Shadow Ward",          icon = "Interface\\Icons\\Spell_Shadow_AntiShadow" }
    },

    iconSize = 32,
    abilityIconSize = 36,
    spacing = 4,
    maxCooldownsPerRow = 8,
    blinkThreshold = 5,
    point = { "CENTER", 0, -100 },
    scale = 1.0,
    locked = false,

    -- No resource bar for the warlock HUD.

    debugSpells = { "Metamorphosis", "Chaos Bolt", "Haunt", "Shadow Trance" },
    debugExtra = function()
        local shards = GetItemCount and GetItemCount(6265) or 0
        print("  Soul Shards: " .. tostring(shards))
    end
})
