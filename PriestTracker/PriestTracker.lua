--[[--------------------------------------------------------------------------
    PriestTracker - WotLK 3.3.5a (Shadow)

    Class config for TrackerCore. Layout top to bottom: abilities, cooldowns.
--------------------------------------------------------------------------]]

TrackerCore:RegisterModule({
    addonName = "PriestTracker",
    dbName = "PriestTrackerDB",
    className = "PRIEST",
    printColor = "|cffffffff",

    cooldowns = {
        { name = "Shadow Word: Death", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordDeath",  glowWhenReady = true },
        { name = "Dispersion",         icon = "Interface\\Icons\\Spell_Shadow_Dispersion",       glowWhenReady = true },
        { name = "Inner Focus",        icon = "Interface\\Icons\\Spell_Frost_FrostWard",          glowWhenReady = true },
        { name = "Shadowfiend",        icon = "Interface\\Icons\\Spell_Shadow_Shadowfiend",       glowWhenReady = true },
        { name = "Psychic Horror",     icon = "Interface\\Icons\\Spell_Shadow_PsychicHorrors" },
        { name = "Psychic Scream",     icon = "Interface\\Icons\\Spell_Shadow_PsychicScream" },
        { name = "Silence",            icon = "Interface\\Icons\\Spell_Shadow_ImpPhaseShift" },
        { name = "Fade",               icon = "Interface\\Icons\\Spell_Magic_LesserInvisibilty" }
    },
    abilities = {
        { name = "Shadowform",          icon = "Interface\\Icons\\Spell_Shadow_Shadowform" },
        { name = "Shadow Weaving",      icon = "Interface\\Icons\\Spell_Shadow_BlackPlague", alwaysShow = true, showCount = true },
        { name = "Inner Focus",         icon = "Interface\\Icons\\Spell_Frost_FrostWard" },
        { name = "Dispersion",          icon = "Interface\\Icons\\Spell_Shadow_Dispersion" },
        -- playerOnly: only our own DoTs count.
        { name = "Vampiric Touch",      icon = "Interface\\Icons\\Spell_Shadow_VampiricTouch", size = 46, playerOnly = true },
        { name = "Shadow Word: Pain",   icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", size = 46, playerOnly = true },
        { name = "Devouring Plague",    icon = "Interface\\Icons\\Spell_Shadow_DevouringPlague", size = 46, playerOnly = true }
    },

    iconSize = 32,
    abilityIconSize = 36,
    spacing = 4,
    maxCooldownsPerRow = 8,
    point = { "CENTER", 0, -100 },
    scale = 1.0,
    locked = false
})
