--[[--------------------------------------------------------------------------
    RogueTracker - WotLK 3.3.5a

    Class config for TrackerCore. Layout top to bottom:
      abilities, energy, combo points, cooldowns, poison warning.
--------------------------------------------------------------------------]]

TrackerCore:RegisterModule({
    addonName = "RogueTracker",
    dbName = "RogueTrackerDB",
    className = "ROGUE",
    printColor = "|cff00ff00",

    cooldowns = {
        { name = "Kick",                icon = "Interface\\Icons\\Ability_Kick", glowWhenReady = true },
        { name = "Adrenaline Rush",     icon = "Interface\\Icons\\Spell_Shadow_ShadowWordDominate", glowWhenReady = true },
        { name = "Blade Flurry",        icon = "Interface\\Icons\\Ability_Warrior_PunishingBlow", glowWhenReady = true },
        { name = "Cold Blood",          icon = "Interface\\Icons\\Spell_Ice_Lament" },
        { name = "Killing Spree",       icon = "Interface\\Icons\\Ability_Rogue_KillingSpree", glowWhenReady = true },
        { name = "Tricks of the Trade", icon = "Interface\\Icons\\Ability_Rogue_TricksOftheTrade" },
        { name = "Preparation",         icon = "Interface\\Icons\\Spell_Shadow_ShadeTrueSight" },
        { name = "Sprint",              icon = "Interface\\Icons\\Ability_Rogue_Sprint" },
        { name = "Vanish",              icon = "Interface\\Icons\\Ability_Vanish" },
        { name = "Blind",               icon = "Interface\\Icons\\Spell_Shadow_MindSteal" },
        { name = "Distract",            icon = "Interface\\Icons\\Ability_Rogue_Distract" },
        { name = "Dismantle",           icon = "Interface\\Icons\\Ability_Rogue_Dismantle" },
        { name = "Shadowstep",          icon = "Interface\\Icons\\Ability_Rogue_Shadowstep" },
        { name = "Shadow Dance",        icon = "Interface\\Icons\\Ability_Rogue_ShadowDance" },
        { name = "Evasion",             icon = "Interface\\Icons\\Spell_Shadow_ShadowWard" },
        { name = "Cloak of Shadows",    icon = "Interface\\Icons\\Spell_Shadow_NetherCloak" }
    },
    abilities = {
        { name = "Stealth",              icon = "Interface\\Icons\\Ability_Stealth" },
        { name = "Slice and Dice",       icon = "Interface\\Icons\\Ability_Rogue_SliceDice" },
        -- playerOnly: only our own Rupture counts, another rogue's is ignored.
        { name = "Rupture",              icon = "Interface\\Icons\\Ability_Rogue_Rupture", playerOnly = true },
        { name = "Expose Armor",         icon = "Interface\\Icons\\Ability_Warrior_Riposte" },
        { name = "Hunger for Blood",     icon = "Interface\\Icons\\Ability_Rogue_HungerforBlood" },
        { name = "Adrenaline Rush",      icon = "Interface\\Icons\\Spell_Shadow_ShadowWordDominate", size = 46 },
        { name = "Blade Flurry",         icon = "Interface\\Icons\\Ability_Warrior_PunishingBlow", size = 46 },
        { name = "Tricks of the Trade",  icon = "Interface\\Icons\\Ability_Rogue_TricksOftheTrade" },
        { name = "Shadow Dance",         icon = "Interface\\Icons\\Ability_Rogue_ShadowDance", size = 46 },
        { name = "Evasion",              icon = "Interface\\Icons\\Spell_Shadow_ShadowWard" },
        { name = "Cloak of Shadows",     icon = "Interface\\Icons\\Spell_Shadow_NetherCloak" },
        { name = "Sprint",               icon = "Interface\\Icons\\Ability_Rogue_Sprint" },
        { name = "Combat Potency",       icon = "Interface\\Icons\\Ability_Rogue_CombatPotency", alwaysShow = true }
    },

    iconSize = 32,
    abilityIconSize = 36,
    spacing = 4,
    maxCooldownsPerRow = 8,
    point = { "CENTER", 0, -100 },
    scale = 1.0,
    locked = false,

    resource = {
        powerType = 3,
        dynamicMax = false,
        max = 100,
        color = { 1, 0.8, 0.2 },
        height = 18
    },
    secondary = {
        type = "combo",
        count = 5,
        height = 18,
        color = { 1, 0.8, 0.2 }
    },
    warning = { type = "poison" }
})
