--[[--------------------------------------------------------------------------
    PaladinTracker - WotLK 3.3.5a (Retribution)

    Class config for TrackerCore. Layout top to bottom:
      rotation queue, abilities, mana, cooldowns, seal/aura warning.

    The rotation queue is the Clash-system priority list from RetRotation:
    Judgement first, then Divine Storm, Crusader Strike, Consecration,
    Exorcism, Holy Wrath. Hammer of Wrath heads the list while the
    target is in execute range (<20% HP). While Seal of Command is up
    the AoE list takes over.
--------------------------------------------------------------------------]]

TrackerCore:RegisterModule({
    addonName = "PaladinTracker",
    dbName = "PaladinTrackerDB",
    className = "PALADIN",
    printColor = "|cfff58cba",

    cooldowns = {
        { name = "Crusader Strike",   icon = "Interface\\Icons\\Spell_Holy_SearingLight",   glowWhenReady = true },
        { name = "Divine Storm",      icon = "Interface\\Icons\\Spell_Holy_DivineStorm",    glowWhenReady = true },
        { name = "Hammer of Wrath",   icon = "Interface\\Icons\\Spell_Holy_Excorcism",      glowWhenReady = true },
        { name = "Consecration",      icon = "Interface\\Icons\\Spell_Holy_Consecration",   glowWhenReady = true },
        { name = "Holy Wrath",        icon = "Interface\\Icons\\Spell_Holy_HolyWrath",      glowWhenReady = true },
        { name = "Avenging Wrath",    icon = "Interface\\Icons\\Spell_Holy_AvengingWrath",  glowWhenReady = true },
        { name = "Divine Plea",       icon = "Interface\\Icons\\Spell_Holy_DivinePlea",     glowWhenReady = true },
        { name = "Hammer of Justice", icon = "Interface\\Icons\\Spell_Holy_HammerOfJustice", glowWhenReady = true },
        { name = "Repentance",        icon = "Interface\\Icons\\Spell_Holy_Repentance" },
        { name = "Rebuke",            icon = "Interface\\Icons\\Spell_Holy_Rebuke",         glowWhenReady = true },
        { name = "Hand of Reckoning", icon = "Interface\\Icons\\Spell_Holy_HandOfReckoning" },
        { name = "Divine Protection", icon = "Interface\\Icons\\Spell_Holy_DivineProtection" },
        { name = "Divine Shield",     icon = "Interface\\Icons\\Spell_Holy_DivineShield" },
        { name = "Lay on Hands",      icon = "Interface\\Icons\\Spell_Holy_LayOnHands" }
    },
    abilities = {
        -- Seals are mutually exclusive: only the active one shows.
        -- Vengeance (Alliance) and Corruption (Horde) are the same
        -- seal; both are listed so each faction's copy is tracked.
        { name = "Seal of Command",       icon = "Interface\\Icons\\Spell_Holy_SealOfCommand",       group = "seal" },
        { name = "Seal of Vengeance",     icon = "Interface\\Icons\\Spell_Holy_SealOfVengeance",     group = "seal", spellID = 31801 },
        { name = "Seal of Corruption",    icon = "Interface\\Icons\\Spell_Holy_SealOfVengeance",     group = "seal", spellID = 53736 },
        { name = "Seal of Righteousness", icon = "Interface\\Icons\\Spell_Holy_RighteousnessAura",   group = "seal" },
        { name = "Seal of Wisdom",        icon = "Interface\\Icons\\Spell_Holy_SealOfWisdom",        group = "seal" },
        { name = "Seal of Light",         icon = "Interface\\Icons\\Spell_Holy_SealOfLight",         group = "seal" },
        { name = "Seal of Justice",       icon = "Interface\\Icons\\Spell_Holy_SealOfJustice",       group = "seal" },
        -- Auras are mutually exclusive too.
        { name = "Devotion Aura",      icon = "Interface\\Icons\\Spell_Holy_DevotionAura",      group = "aura" },
        { name = "Retribution Aura",   icon = "Interface\\Icons\\Spell_Holy_RetributionAura",   group = "aura" },
        { name = "Concentration Aura", icon = "Interface\\Icons\\Spell_Holy_ConcentrationAura", group = "aura" },
        { name = "Sanctity Aura",      icon = "Interface\\Icons\\Spell_Holy_SanctityAura",      group = "aura" },
        { name = "Crusader Aura",      icon = "Interface\\Icons\\Spell_Holy_CrusaderAura",      group = "aura" },
        { name = "Righteous Fury",     icon = "Interface\\Icons\\Spell_Holy_RighteousFury" },
        -- Talent procs, not in the spellbook. spellID resolves the art.
        { name = "Art of War",            icon = "Interface\\Icons\\Ability_Paladin_ArtofWar", alwaysShow = true, size = 46, spellID = 59578 },
        -- Applied to the judged target while Seal of Wisdom is up.
        { name = "Judgement of the Wise", icon = "Interface\\Icons\\Spell_Holy_SealOfWisdom", spellID = 53408 }
    },

    -- Clash-style rotation queue (engine feature, see TrackerCore).
    rotation = {
        icons = 5,          -- queue length
        iconSize = 36,
        glowNext = true,    -- glow the head of the queue while it is ready
        -- Single-target priority, highest first.
        list = {
            { name = "Hammer of Wrath", spellID = 24275, execute = true },  -- <20% HP only
            { name = "Judgement",       spellID = 20271 },
            { name = "Divine Storm",    spellID = 53385 },
            { name = "Crusader Strike", spellID = 35395 },
            { name = "Consecration",    spellID = 26573 },
            { name = "Exorcism",        spellID = 879 },
            { name = "Holy Wrath",      spellID = 2812, undeadOnly = true }  -- undead targets only
        },
        -- AoE mode: replaces `list` while the buff is up on the player.
        aoeBuff = { name = "Seal of Command", spellID = 20375 },
        aoeList = {
            { name = "Hammer of Wrath", spellID = 24275, execute = true },
            { name = "Judgement",       spellID = 20271 },
            { name = "Divine Storm",    spellID = 53385 },
            { name = "Consecration",    spellID = 26573 },
            { name = "Crusader Strike", spellID = 35395 },
            { name = "Holy Wrath",      spellID = 2812, undeadOnly = true },  -- undead targets only
            { name = "Exorcism",        spellID = 879 }
        }
    },

    iconSize = 32,
    abilityIconSize = 36,
    spacing = 4,
    maxCooldownsPerRow = 8,
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

    -- family: seals and auras are mutually exclusive, so the group is
    -- only reported when none of its members is up.
    warning = {
        type = "auras",
        prefix = "MISSING: ",
        auras = {
            { name = "Seal of Command",        spellID = 20375, family = "seal", text = "SEAL" },
            { name = "Seal of Vengeance",      spellID = 31801, family = "seal" },
            { name = "Seal of Corruption",     spellID = 53736, family = "seal" },
            { name = "Seal of Righteousness",  spellID = 21084, family = "seal" },
            { name = "Seal of Wisdom",         spellID = 20166, family = "seal" },
            { name = "Seal of Light",          spellID = 20164, family = "seal" },
            { name = "Seal of Justice",        spellID = 20165, family = "seal" },
            { name = "Devotion Aura",          spellID = 465,   family = "aura", text = "AURA" },
            { name = "Retribution Aura",       spellID = 7294,  family = "aura" },
            { name = "Concentration Aura",     spellID = 19746, family = "aura" },
            { name = "Sanctity Aura",          spellID = 20218, family = "aura" },
            { name = "Crusader Aura",          spellID = 32223, family = "aura" },
            { name = "Fire Resistance Aura",   spellID = 19891, family = "aura" },
            { name = "Frost Resistance Aura",  spellID = 19876, family = "aura" },
            { name = "Shadow Resistance Aura", spellID = 19877, family = "aura" }
        }
    }
})
