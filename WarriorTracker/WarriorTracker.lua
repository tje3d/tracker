--[[--------------------------------------------------------------------------
    WarriorTracker - WotLK 3.3.5a (Fury)

    Class module for TrackerCore. It only describes WHAT to track; the shared
    engine lives in TrackerCore. Layout (top to bottom):
      1. Abilities (self buffs/procs & target debuffs, only when active)
      2. Rage bar
      3. Cooldowns (8 per row, wraps)
    No secondary row (no combo-point style resource).
--------------------------------------------------------------------------]]

TrackerCore:RegisterModule({
    addonName = "WarriorTracker",
    dbName = "WarriorTrackerDB",
    className = "WARRIOR",
    printColor = "|cffc79c6e",

    cooldowns = {
        { name = "Bloodthirst",     icon = "Interface\\Icons\\Spell_Nature_BloodLust",           glowWhenReady = true },
        { name = "Whirlwind",       icon = "Interface\\Icons\\Ability_Whirlwind",                glowWhenReady = true },
        { name = "Execute",         icon = "Interface\\Icons\\Ability_Warrior_Execute",          glowWhenReady = true },
        { name = "Slam",            icon = "Interface\\Icons\\Ability_Warrior_DecisiveStrike" },
        { name = "Bloodrage",       icon = "Interface\\Icons\\Ability_Racial_BloodRage",         glowWhenReady = true },
        { name = "Recklessness",    icon = "Interface\\Icons\\Ability_CriticalStrike",            glowWhenReady = true },
        { name = "Death Wish",      icon = "Interface\\Icons\\Spell_Shadow_DeathPact",            glowWhenReady = true },
        { name = "Berserker Rage",  icon = "Interface\\Icons\\Spell_Nature_AncestralGuardian",    glowWhenReady = true },
        { name = "Shattering Throw",icon = "Interface\\Icons\\Ability_Warrior_ShatteringThrow",   glowWhenReady = true },
        { name = "Pummel",          icon = "Interface\\Icons\\Ability_Warrior_PunishingBlow",     glowWhenReady = true },
        { name = "Intimidating Shout", icon = "Interface\\Icons\\Ability_GolemThunderClap" },
        { name = "Piercing Howl",   icon = "Interface\\Icons\\Spell_Shadow_DeathScream" },
        { name = "Intercept",       icon = "Interface\\Icons\\Ability_Rogue_Sprint" },
        { name = "Heroic Throw",    icon = "Interface\\Icons\\INV_Weapon_Shortblade_46" },
        { name = "Victory Rush",    icon = "Interface\\Icons\\Ability_Warrior_Devastate" },
        { name = "Cleave",          icon = "Interface\\Icons\\Ability_Warrior_Cleave" }
    },
    abilities = {
        { name = "Battle Shout",    icon = "Interface\\Icons\\Ability_Warrior_BattleShout" },
        { name = "Berserker Rage",  icon = "Interface\\Icons\\Spell_Nature_AncestralGuardian" },
        { name = "Recklessness",    icon = "Interface\\Icons\\Ability_CriticalStrike" },
        { name = "Death Wish",      icon = "Interface\\Icons\\Spell_Shadow_DeathPact" },
        { name = "Enrage",          icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy",         alwaysShow = true },
        { name = "Sudden Death",    icon = "Interface\\Icons\\Ability_Warrior_ImprovedDisciplines", alwaysShow = true },
        { name = "Bloodsurge",      icon = "Interface\\Icons\\Ability_Warrior_Bloodsurge",        alwaysShow = true },
        { name = "Flurry",          icon = "Interface\\Icons\\Ability_GhoulFrenzy",               alwaysShow = true, showCount = true },
        { name = "Rampage",         icon = "Interface\\Icons\\Ability_Warrior_Rampage",           showCount = true },
        -- playerOnly: this bleed lands on the target, so only OUR copy should
        -- read as active - another warrior's Deep Wounds is not our damage.
        { name = "Deep Wounds",     icon = "Interface\\Icons\\Ability_BackStab",                  alwaysShow = true, playerOnly = true },
        { name = "Sunder Armor",    icon = "Interface\\Icons\\Ability_Warrior_Sunder",            alwaysShow = true, showCount = true }
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
        powerType = 1,          -- Rage
        dynamicMax = true,
        max = 100,
        color = { 0.85, 0.2, 0.15 },
        height = 18
    },

    debugSpells = { "Bloodthirst", "Recklessness", "Death Wish" },
    debugExtra = function()
        print(string.format("  Rage: %d / %d",
            UnitPower("player", 1) or 0, UnitPowerMax("player", 1) or 0))
    end
})
