--[[--------------------------------------------------------------------------
    MageTracker - WotLK 3.3.5a (Fire & Arcane)

    Class config for TrackerCore. Layout top to bottom: abilities, cooldowns.
    Fire and Arcane share one module; IsSpellKnown hides untalented entries.
--------------------------------------------------------------------------]]

TrackerCore:RegisterModule({
    addonName = "MageTracker",
    dbName = "MageTrackerDB",
    className = "MAGE",
    printColor = "|cff69ccf0",

    cooldowns = {
        { name = "Counterspell",      icon = "Interface\\Icons\\Spell_Frost_IceShock" },
        { name = "Blink",             icon = "Interface\\Icons\\Spell_Arcane_Blink" },
        { name = "Ice Block",         icon = "Interface\\Icons\\Spell_Frost_Frost" },
        { name = "Evocation",         icon = "Interface\\Icons\\Spell_Magic_ManaGain" },
        { name = "Mirror Image",      icon = "Interface\\Icons\\Spell_Magic_MirrorImage" },
        { name = "Invisibility",      icon = "Interface\\Icons\\Spell_Magic_LesserInvisibilty" },
        { name = "Presence of Mind",  icon = "Interface\\Icons\\Spell_Nature_EnchantArmor" },
        { name = "Arcane Power",      icon = "Interface\\Icons\\Spell_Nature_Lightning" },
        { name = "Arcane Barrage",    icon = "Interface\\Icons\\Ability_Mage_ArcaneBarrage" },
        { name = "Combustion",        icon = "Interface\\Icons\\Spell_Fire_SealOfFire" },
        { name = "Dragon's Breath",   icon = "Interface\\Icons\\Ability_Mage_DragonBreath" },
        { name = "Blast Wave",        icon = "Interface\\Icons\\Spell_Fire_SealOfFire" }
    },
    abilities = {
        -- Fire
        { name = "Hot Streak!",     icon = "Interface\\Icons\\Spell_Fire_FlameBolt", alwaysShow = true },
        -- Same +5% crit debuff as a warlock's Shadow Mastery (17800).
        { name = "Improved Scorch", icon = "Interface\\Icons\\Spell_Fire_SoulBurn", alwaysShow = true,
          altAuras = { { name = "Shadow Mastery", spellID = 17800 } } },
        -- playerOnly: only our own Living Bomb / Ignite counts.
        { name = "Living Bomb",     icon = "Interface\\Icons\\Ability_Mage_LivingBomb", playerOnly = true },
        { name = "Ignite",          icon = "Interface\\Icons\\Spell_Fire_Incinerate", alwaysShow = true, playerOnly = true },
        { name = "Combustion",      icon = "Interface\\Icons\\Spell_Fire_SealOfFire" },
        -- Arcane
        { name = "Arcane Blast",    spellID = 36032, icon = "Interface\\Icons\\Spell_Arcane_Blast", alwaysShow = true, showCount = true, size = 46 },
        { name = "Missile Barrage", icon = "Interface\\Icons\\Ability_Mage_MissileBarrage", alwaysShow = true },
        { name = "Arcane Power",    icon = "Interface\\Icons\\Spell_Nature_Lightning", size = 46 },
        { name = "Presence of Mind",icon = "Interface\\Icons\\Spell_Nature_EnchantArmor" },
        { name = "Focus Magic",     icon = "Interface\\Icons\\Spell_Arcane_MindMastery" },
        { name = "Slow",            icon = "Interface\\Icons\\Spell_Nature_Slow" },
        -- General
        { name = "Arcane Intellect",icon = "Interface\\Icons\\Spell_Holy_MagicalSentry" },
        { name = "Molten Armor",    icon = "Interface\\Icons\\Ability_Mage_MoltenArmor" },
        { name = "Mage Armor",      icon = "Interface\\Icons\\Ability_Mage_MageArmor" },
        { name = "Ice Armor",       icon = "Interface\\Icons\\Ability_Mage_IceArmor" },
        -- Extra procs / cooldown buffs
        { name = "Arcane Potency",  spellID = 57531, icon = "Interface\\Icons\\Spell_Arcane_ArcanePotency", alwaysShow = true },
        -- Quad Core: T10 Bloodmage set (Sanctified Bloodmage Leggings) proc
        { name = "Quad Core",       spellID = 70747, icon = "Interface\\Icons\\Spell_Nature_Invisibilty", alwaysShow = true },
        -- Pushing the Limit: T10 Bloodmage set proc
        { name = "Pushing the Limit", spellID = 70753, icon = "Interface\\Icons\\Spell_Fire_ElementalDevastation", alwaysShow = true, fixedIcon = true },
        { name = "Icy Veins",       icon = "Interface\\Icons\\Spell_Frost_ColdHearted", size = 46 }
    },

    iconSize = 32,
    abilityIconSize = 36,
    spacing = 4,
    maxCooldownsPerRow = 8,
    point = { "CENTER", 0, -100 },
    scale = 1.0,
    locked = false
})
