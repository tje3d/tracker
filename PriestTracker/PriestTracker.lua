--[[--------------------------------------------------------------------------
    PriestTracker - WotLK 3.3.5a (Shadow)

    Class module for TrackerCore. It only describes WHAT to track; the shared
    engine lives in TrackerCore. Layout (top to bottom):
      1. Abilities (self buffs/procs & target DoTs, only when active)
      2. Cooldowns (8 per row, wraps)
    No mana bar (per request) and no secondary row.
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
        -- playerOnly: these DoTs land on the target, so only OUR copy should
        -- read as active - another priest's VT/SW:P/Devouring Plague is not
        -- our damage.
        { name = "Vampiric Touch",      icon = "Interface\\Icons\\Spell_Shadow_VampiricTouch", size = 46, playerOnly = true },
        { name = "Shadow Word: Pain",   icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", size = 46, playerOnly = true },
        { name = "Devouring Plague",    icon = "Interface\\Icons\\Spell_Shadow_DevouringPlague", size = 46, playerOnly = true }
    },

    iconSize = 32,
    abilityIconSize = 36,
    spacing = 4,
    maxCooldownsPerRow = 8,
    blinkThreshold = 5,
    point = { "CENTER", 0, -100 },
    scale = 1.0,
    locked = false,

    -- No resource bar for the shadow priest HUD.

    debugSpells = { "Shadowform", "Dispersion", "Shadowfiend" }
})
