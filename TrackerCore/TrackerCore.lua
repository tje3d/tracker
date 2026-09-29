--[[--------------------------------------------------------------------------
    TrackerCore - WotLK 3.3.5a

    Shared engine + class-module loader for the class trackers
    (RogueTracker, DKTracker, and any future ones).

    Each class module is a separate addon that only ships a CONFIG table and
    calls TrackerCore:RegisterModule(config). This file owns everything else:
    spellbook scanning, aura lookup, icon factory, the shared glow/blink
    drivers, layout, the 10 Hz refresh loop, events and slash commands.

    The loader picks the module matching the player's class at PLAYER_LOGIN
    and LoadAddOn()s it, so rogue code only ever runs on rogues, DK code only
    on death knights, and so on. Add new classes to MODULES below.
--------------------------------------------------------------------------]]

local CORE_NAME = "TrackerCore"
local Core = CreateFrame("Frame")
_G[CORE_NAME] = Core

-- class token -> module addon folder name. Extend this when adding a tracker.
local MODULES = {
    ROGUE       = "RogueTracker",
    DEATHKNIGHT = "DKTracker",
    HUNTER      = "HunterTracker",
    MAGE        = "MageTracker",
    PRIEST      = "PriestTracker",
    WARRIOR     = "WarriorTracker",
    WARLOCK     = "WarlockTracker",
    DRUID       = "DruidTracker"
}

-- Buffs other classes can put on the player. Shown by every tracker while they
-- are active. alwaysShow because this character cannot learn them, so
-- IsSpellKnown would otherwise never build the icons.
local COMMON_ABILITIES = {
    { name = "Hand of Freedom",    icon = "Interface\\Icons\\Spell_Holy_SealOfValor",      alwaysShow = true },
    { name = "Hand of Protection", icon = "Interface\\Icons\\Spell_Holy_SealOfProtection", alwaysShow = true },
    { name = "Hand of Salvation",  icon = "Interface\\Icons\\Spell_Holy_SealOfSalvation",  alwaysShow = true },
    { name = "Hand of Sacrifice",  icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",  alwaysShow = true },
    { name = "Power Infusion",     icon = "Interface\\Icons\\Spell_Holy_PowerInfusion",    alwaysShow = true }
}

Core.pending = {}       -- module configs registered before login
Core.initialized = {}   -- addon names that have been built already
Core.loggedIn = false

-- ===========================================================================
-- SHARED COMMAND
--
-- /tracker forwards to the active class module's handler, so lock/unlock/
-- reset/etc. work the same on every class through one command.
-- ===========================================================================
function Core:DispatchSlash(msg)
    if self.slashHandler then
        self.slashHandler(msg)
    else
        print("|cff8888ffTrackerCore|r: No tracker is active for your class.")
    end
end

_G["SLASH_TRACKERCORE1"] = "/tracker"
SlashCmdList["TRACKERCORE"] = function(msg) Core:DispatchSlash(msg) end

-- ===========================================================================
-- MODULE REGISTRATION
-- ===========================================================================
function Core:RegisterModule(config)
    if self.loggedIn then
        self:InitModule(config)
    else
        self.pending[config.className] = config
    end
end

-- ===========================================================================
-- THE ENGINE
--
-- config schema (all sizes default where noted):
--   addonName, dbName, className, printColor (command is shared: /tracker)
--   cooldowns, abilities. Any entry may add size = N
--   for a bigger icon, spellID = N to also match the aura by ID (and for
--   reliable icon lookup), alwaysShow = true
--   when it is a proc aura rather than a learnable spell, or showCount = true
--   to print the aura's stack count in the corner. Abilities may also add
--   altAuras = { { name, spellID }, ... } for other classes' auras that have
--   the identical effect (e.g. a warlock's Shadow Mastery for Improved Scorch)
--   or alwaysVisible = true to keep the icon in the row even while the aura is
--   down, drawn desaturated as a missing/upkeep reminder, playerOnly = true to
--   match only auras cast by the player (so another caster's copy of a DoT on
--   the target is never mistaken for yours), and group = "name" for
--   mutually-exclusive auras (only the active member of a group is shown)
--   iconSize, abilityIconSize, spacing, maxCooldownsPerRow
--   point, scale, locked, blinkThreshold
--   resource  = optional: { powerType, dynamicMax, max, color, height }
--   secondary = optional: { type = "combo"|"rune", count, height, color,
--                 colors, dim, fallbackType, order }
--   warning   = optional: { type = "poison"|"upkeep"|"auras",
--                 name, text, prefix, auras = { {name, text}, ... } }
--   debugSpells, debugExtra
-- ===========================================================================
function Core:InitModule(CONFIG)
    if self.initialized[CONFIG.addonName] then return end

    local _, playerClass = UnitClass("player")
    if playerClass ~= CONFIG.className then return end
    self.initialized[CONFIG.addonName] = true

    local ADDON_NAME = CONFIG.addonName
    local PREFIX = CONFIG.printColor .. ADDON_NAME .. "|r"
    local BLINK_THRESHOLD = CONFIG.blinkThreshold or 5

    -- =======================================================================
    -- DATABASE
    --
    -- The store lives in TrackerCoreDB, which is declared by the always-loaded
    -- core. SavedVariables owned by a LoadOnDemand addon are not reliably
    -- restored before that addon's code runs, which is why a module's own
    -- variable (RogueTrackerDB/DKTrackerDB) lost the saved position every
    -- login. On first run the old per-module variable is adopted as-is so
    -- existing setups keep their position, scale and lock state.
    -- =======================================================================
    local db
    local function InitializeDB()
        if not TrackerCoreDB then TrackerCoreDB = {} end
        local store = TrackerCoreDB[CONFIG.addonName]
        if not store then
            store = _G[CONFIG.dbName] or {}
            TrackerCoreDB[CONFIG.addonName] = store
        end
        db = store
        db.point = db.point or { CONFIG.point[1], CONFIG.point[2], CONFIG.point[3] }
        db.scale = db.scale or CONFIG.scale
        db.locked = db.locked or CONFIG.locked
        if db.forceShow == nil then db.forceShow = false end
    end

    -- =======================================================================
    -- SPELLBOOK SCANNING (4 methods, very robust)
    --
    -- PERF: full spellbook scans and 120-slot action bar scans are hoisted
    -- into name sets built at most once per generation and every answer is
    -- memoized, so a rebuild costs one pass no matter how many spells.
    -- =======================================================================
    local spellbookNames
    local actionBarNames
    local knownVal, knownGen = {}, {}
    local knownGeneration = 0

    local function InvalidateSpellKnowledge()
        knownGeneration = knownGeneration + 1
        spellbookNames = nil
        actionBarNames = nil
    end

    local function GetSpellbookNames()
        if not spellbookNames then
            spellbookNames = {}
            local i = 1
            while true do
                local name = GetSpellName(i, BOOKTYPE_SPELL)
                if not name then break end
                spellbookNames[name] = true
                i = i + 1
            end
        end
        return spellbookNames
    end

    local function GetActionBarNames()
        if not actionBarNames then
            actionBarNames = {}
            for slot = 1, 120 do
                local actionType, id = GetActionInfo(slot)
                if actionType == "spell" and id then
                    local actionSpellName = GetSpellInfo(id)
                    if actionSpellName then actionBarNames[actionSpellName] = true end
                end
            end
        end
        return actionBarNames
    end

    local function IsSpellKnown(spellName)
        if not spellName or spellName == "" then return false end
        if db and db.forceShow then return true end

        if knownGen[spellName] == knownGeneration then
            return knownVal[spellName]
        end

        local known

        -- Method 1: Scan spellbook by name
        if GetSpellbookNames()[spellName] then
            known = true
        else
            -- Method 2: Get spell ID via GetSpellInfo, then IsSpellKnown/IsPlayerSpell
            known = false
            local _, _, spellID = GetSpellInfo(spellName)
            if spellID then
                if IsSpellKnown and IsSpellKnown(spellID) then
                    known = true
                elseif IsPlayerSpell and IsPlayerSpell(spellID) then
                    known = true
                end
            end

            -- Method 3: Check action bars
            if not known and GetActionBarNames()[spellName] then
                known = true
            end

            -- Method 4: GetSpellCooldown returns valid data only for known spells
            if not known then
                local ok, start, duration, enabled = pcall(GetSpellCooldown, spellName)
                if ok and start and duration and enabled ~= nil then
                    known = true
                end
            end
        end

        knownVal[spellName] = known
        knownGen[spellName] = knownGeneration
        return known
    end

    -- An entry may set alwaysShow when it is a proc aura rather than a
    -- learnable spell (set bonuses, talent procs). Those are not in the
    -- spellbook, so IsSpellKnown misses them and the icon would never be
    -- built. It is still only shown while its aura is actually active.
    local function IsTracked(data)
        return data.alwaysShow or IsSpellKnown(data.name)
    end

    -- Cheap signature of exactly which tracked spells exist right now so an
    -- unchanged rebuild can be skipped entirely.
    local function ComputeKnownSignature()
        local signature = (db and db.forceShow) and 1 or 0

        local list = CONFIG.cooldowns
        for i = 1, #list do
            signature = signature * 2 + (IsTracked(list[i]) and 1 or 0)
        end

        list = CONFIG.abilities
        for i = 1, #list do
            signature = signature * 2 + (IsTracked(list[i]) and 1 or 0)
        end

        return signature
    end

    local function FilterKnown(configList)
        local known = {}
        for _, data in ipairs(configList) do
            if IsTracked(data) then
                table.insert(known, data)
            end
        end
        return known
    end

    -- Safe icon texture lookup: dynamic first (spellID when given, else name),
    -- hardcoded second, fallback last. Entries may set fixedIcon = true to
    -- force their hardcoded icon when the client/DBC reports a wrong one.
    local function GetIconTexture(data)
        if data.fixedIcon and data.icon and data.icon ~= "" then
            return data.icon
        end
        local ok, tex = pcall(GetSpellTexture, data.spellID or data.name)
        if ok and tex and tex ~= "" then
            return tex
        end
        if data.icon and data.icon ~= "" then
            return data.icon
        end
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    -- =======================================================================
    -- UI ELEMENTS
    -- =======================================================================
    local mainFrame
    local elements = {
        cooldowns = {}, abilities = {},
        resource = nil, secondary = {}
    }

    local ICON_ROWS = { "cooldowns", "abilities" }
    local activeAbilities = {}
    local lastAbilitySignature = -1
    local lastBuildSignature = -1

    -- =======================================================================
    -- SHARED PROC GLOW DRIVER (single OnUpdate for every glowing icon)
    -- =======================================================================
    local GLOW_ALPHA_INTERVAL = 1 / 30
    local glowActive, glowActiveCount = {}, 0
    local glowDriver, glowAlphaElapsed = nil, 0

    local function ClearGlowIcons()
        for i = 1, glowActiveCount do glowActive[i] = nil end
        glowActiveCount = 0
        if glowDriver then glowDriver:Hide() end
    end

    local function OnGlowUpdate(_, dt)
        for i = 1, glowActiveCount do
            local icon = glowActive[i]

            icon.glowTick = icon.glowTick + dt
            if icon.glowTick >= 0.1 then
                icon.glowTick = 0
                icon.glowFrame = (icon.glowFrame + 1) % 8
                local w = 1 / 8
                icon.glowShine:SetTexCoord(icon.glowFrame * w, (icon.glowFrame + 1) * w, 0, 1)
            end

            icon.glowPulseTick = icon.glowPulseTick + dt
        end

        glowAlphaElapsed = glowAlphaElapsed + dt
        if glowAlphaElapsed >= GLOW_ALPHA_INTERVAL then
            glowAlphaElapsed = 0
            for i = 1, glowActiveCount do
                local icon = glowActive[i]
                icon.glowFill:SetAlpha(0.3 + 0.15 * math.sin(icon.glowPulseTick * 4))
            end
        end
    end

    local function GetGlowDriver()
        if not glowDriver then
            glowDriver = CreateFrame("Frame", nil, mainFrame or UIParent)
            glowDriver:Hide()
            glowDriver:SetScript("OnUpdate", OnGlowUpdate)
        end
        return glowDriver
    end

    local function IconStopGlow(self)
        if not self.glowFill then return end
        self.glowFill:Hide()
        self.glowShine:Hide()
        for i = 1, glowActiveCount do
            if glowActive[i] == self then
                glowActive[i] = glowActive[glowActiveCount]
                glowActive[glowActiveCount] = nil
                glowActiveCount = glowActiveCount - 1
                break
            end
        end
        if glowActiveCount == 0 and glowDriver then glowDriver:Hide() end
    end

    local function IconStartGlow(self)
        if self.glowFill and self.glowFill:IsShown() then return end

        if not self.glowFill then
            local glowFill = self:CreateTexture(nil, "OVERLAY", nil, 5)
            glowFill:SetTexture("Interface\\Buttons\\WHITE8X8")
            glowFill:SetBlendMode("ADD")
            glowFill:SetVertexColor(1, 0.75, 0)
            glowFill:SetAllPoints(self)
            glowFill:Hide()
            self.glowFill = glowFill

            local glowShine = self:CreateTexture(nil, "OVERLAY", nil, 6)
            glowShine:SetTexture("Interface\\Buttons\\UI-AutoCastButton")
            glowShine:SetBlendMode("ADD")
            glowShine:SetVertexColor(1, 0.85, 0)
            glowShine:SetAllPoints(self)
            glowShine:SetTexCoord(0, 1/8, 0, 1)
            glowShine:Hide()
            self.glowShine = glowShine
        end

        self.glowFrame = 0
        self.glowTick = 0
        self.glowPulseTick = 0
        self.glowFill:SetAlpha(0.3)
        self.glowFill:Show()
        self.glowShine:Show()

        glowActiveCount = glowActiveCount + 1
        glowActive[glowActiveCount] = self
        GetGlowDriver():Show()
    end

    -- =======================================================================
    -- SHARED ABILITY BLINK DRIVER
    --
    -- Abilities under BLINK_THRESHOLD seconds pulse their icon alpha through a
    -- single shared OnUpdate. Nothing runs unless at least one is expiring.
    -- =======================================================================
    local blinkActive, blinkActiveCount = {}, 0
    local blinkDriver

    local function ClearBlinkIcons()
        for i = 1, blinkActiveCount do
            local icon = blinkActive[i]
            if icon and icon.texture then icon.texture:SetAlpha(1) end
            blinkActive[i] = nil
        end
        blinkActiveCount = 0
        if blinkDriver then blinkDriver:Hide() end
    end

    local function OnBlinkUpdate()
        local alpha = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(GetTime() * 9))
        for i = 1, blinkActiveCount do
            blinkActive[i].texture:SetAlpha(alpha)
        end
    end

    local function IconStopBlink(self)
        if not self.rtBlinking then return end
        self.rtBlinking = false
        self.texture:SetAlpha(1)
        for i = 1, blinkActiveCount do
            if blinkActive[i] == self then
                blinkActive[i] = blinkActive[blinkActiveCount]
                blinkActive[blinkActiveCount] = nil
                blinkActiveCount = blinkActiveCount - 1
                break
            end
        end
        if blinkActiveCount == 0 and blinkDriver then blinkDriver:Hide() end
    end

    local function IconStartBlink(self)
        if self.rtBlinking then return end
        self.rtBlinking = true
        if not blinkDriver then
            blinkDriver = CreateFrame("Frame", nil, mainFrame or UIParent)
            blinkDriver:Hide()
            blinkDriver:SetScript("OnUpdate", OnBlinkUpdate)
        end
        blinkActiveCount = blinkActiveCount + 1
        blinkActive[blinkActiveCount] = self
        blinkDriver:Show()
    end

    local function ClearUI()
        ClearGlowIcons()
        ClearBlinkIcons()
        for i = 1, #activeAbilities do activeAbilities[i].frame = nil end
        lastAbilitySignature = -1
        elements.rtComboPoints = nil

        for _, row in ipairs(ICON_ROWS) do
            for i = #elements[row], 1, -1 do
                local f = elements[row][i].frame
                if f then f:Hide(); f:SetParent(nil) end
                elements[row][i] = nil
            end
        end
        if elements.resource then
            if elements.resource.container then
                elements.resource.container:Hide()
                elements.resource.container:SetParent(nil)
            end
            elements.resource = nil
        end
        for i = #elements.secondary, 1, -1 do
            local sec = elements.secondary[i]
            if sec and sec.parent then sec.parent:Hide(); sec.parent:SetParent(nil) end
            elements.secondary[i] = nil
        end
    end

    -- =======================================================================
    -- ICON FACTORY
    -- =======================================================================
    local function CreateIcon(parent, size)
        local f = CreateFrame("Frame", nil, parent)
        f:SetSize(size, size)

        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(0.05, 0.05, 0.05, 0.9)

        local tex = f:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", 1, -1)
        tex:SetPoint("BOTTOMRIGHT", -1, 1)
        f.texture = tex

        -- Text and gold border sit on a frame above the cooldown sweep
        -- (created just below at frameLevel+1); otherwise the clock hand
        -- draws over the timer.
        local overlay = CreateFrame("Frame", nil, f)
        overlay:SetAllPoints(f)
        overlay:SetFrameLevel(f:GetFrameLevel() + 2)

        local text = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER", overlay, "CENTER", 0, 0)
        text:SetTextColor(1, 1, 1)
        f.text = text

        -- Small stack counter, bottom-right corner. Only used by abilities
        -- that ask for it (data.showCount).
        local countText = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        countText:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -1, 2)
        countText:SetTextColor(1, 1, 1)
        countText:Hide()
        f.countText = countText

        local border = overlay:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        border:SetBlendMode("ADD")
        border:SetVertexColor(1, 0.8, 0)
        local borderScale = size / 36
        border:SetSize(64 * borderScale, 64 * borderScale)
        border:SetPoint("CENTER", overlay, "CENTER", 0, 0)
        border:Hide()
        f.border = border

        local cooldown = CreateFrame("Cooldown", nil, f)
        cooldown:SetAllPoints(f)
        cooldown:SetFrameLevel(f:GetFrameLevel() + 1)
        cooldown:SetReverse(false)
        cooldown:Hide()
        f.cooldownFrame = cooldown

        f.StartGlow = IconStartGlow
        f.StopGlow = IconStopGlow

        return f
    end

    -- =======================================================================
    -- MAIN FRAME
    -- =======================================================================
    local function GetRowWidth()
        return CONFIG.maxCooldownsPerRow * CONFIG.iconSize
             + (CONFIG.maxCooldownsPerRow - 1) * CONFIG.spacing
    end

    local function CreateMainFrame()
        local rowWidth = GetRowWidth()
        mainFrame = CreateFrame("Frame", ADDON_NAME .. "Frame", UIParent)
        mainFrame:SetSize(rowWidth + 20, 500)
        mainFrame:SetPoint(db.point[1], UIParent, db.point[1], db.point[2], db.point[3])
        mainFrame:SetScale(db.scale)
        mainFrame:SetMovable(true)

        local function ApplyMouseState()
            if db.locked then
                mainFrame:EnableMouse(false)
            else
                mainFrame:EnableMouse(true)
            end
        end

        mainFrame.ApplyMouseState = ApplyMouseState
        ApplyMouseState()

        mainFrame:RegisterForDrag("LeftButton")
        mainFrame:SetScript("OnDragStart", function(self)
            if not db.locked then self:StartMoving() end
        end)
        mainFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local point, _, _, x, y = self:GetPoint()
            db.point = { point, x, y }
        end)

        -- Warning bar (poison or missing upkeep) - optional. Created once and
        -- re-anchored at the end of the content by BuildUI; hidden while
        -- nothing is wrong.
        if CONFIG.warning then
            local warn = CreateFrame("Frame", nil, mainFrame)
            warn:SetSize(rowWidth, 16)
            warn:SetPoint("TOP", mainFrame, "TOP", 0, -10)

            local warnBorder = warn:CreateTexture(nil, "BACKGROUND")
            warnBorder:SetPoint("TOPLEFT", -1, 1)
            warnBorder:SetPoint("BOTTOMRIGHT", 1, -1)
            warnBorder:SetTexture(0.35, 0.35, 0.35, 1)

            local warnBg = warn:CreateTexture(nil, "BORDER")
            warnBg:SetAllPoints()
            warnBg:SetTexture(0.25, 0.02, 0.02, 0.9)

            local warnText = warn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            warnText:SetAllPoints(warn)
            warnText:SetTextColor(1, 0.2, 0.2)
            warn.text = warnText

            warn:EnableMouse(false)
            warn:Hide()
            mainFrame.warn = warn
        end
    end

    -- =======================================================================
    -- BUILD HELPERS
    -- =======================================================================
    local function BuildIconGrid(configList, startY, elementsTable, maxPerRow)
        local size = CONFIG.iconSize
        local spacing = CONFIG.spacing
        local known = FilterKnown(configList)
        local count = #known
        if count == 0 then return 0 end

        maxPerRow = maxPerRow or 999
        local numRows = math.ceil(count / maxPerRow)

        for row = 1, numRows do
            local rowStart = (row - 1) * maxPerRow + 1
            local rowEnd = math.min(row * maxPerRow, count)
            local rowCount = rowEnd - rowStart + 1

            local totalWidth = (size * rowCount) + (spacing * (rowCount - 1))
            local startX = -(totalWidth / 2) + (size / 2)
            local y = startY - (row - 1) * (size + spacing)

            for i = rowStart, rowEnd do
                local data = known[i]
                local slot = i - rowStart
                local icon = CreateIcon(mainFrame, size)
                icon:SetPoint("TOP", mainFrame, "TOP", startX + slot * (size + spacing), y)
                icon.texture:SetTexture(GetIconTexture(data))
                table.insert(elementsTable, { frame = icon, name = data.name, glowWhenReady = data.glowWhenReady })
            end
        end

        return numRows
    end

    local function BuildTopSection(startY)
        local spacing = CONFIG.spacing
        local abilitySize = CONFIG.abilityIconSize
        local rowWidth = GetRowWidth()
        local currentY = startY

        -- ===== 1. Abilities (fixed space reserved; positioned dynamically) =====
        -- An ability may ask for a bigger icon via data.size (important
        -- debuffs/buffs). Reserve the tallest so the row never overlaps what
        -- comes after it.
        local abilityRowHeight = 0
        for _, data in ipairs(CONFIG.abilities) do
            local s = data.size or abilitySize
            if s > abilityRowHeight then abilityRowHeight = s end
        end
        if abilityRowHeight == 0 then abilityRowHeight = abilitySize end
        elements.abilityRowY = currentY
        elements.abilityRowHeight = abilityRowHeight
        currentY = currentY - abilityRowHeight - 5

        -- ===== 2. Resource bar (energy / runic power / mana) - optional =====
        local res = CONFIG.resource
        if res then
            local barHeight = res.height or 18
            local resContainer = CreateFrame("Frame", nil, mainFrame)
            resContainer:SetSize(rowWidth, barHeight)
            resContainer:SetPoint("TOP", mainFrame, "TOP", 0, currentY)

            local resBorder = resContainer:CreateTexture(nil, "BACKGROUND")
            resBorder:SetPoint("TOPLEFT", -1, 1)
            resBorder:SetPoint("BOTTOMRIGHT", 1, -1)
            resBorder:SetTexture(0.35, 0.35, 0.35, 1)

            local resBg = resContainer:CreateTexture(nil, "BORDER")
            resBg:SetAllPoints()
            resBg:SetTexture(0.05, 0.05, 0.05, 0.9)

            local resBar = CreateFrame("StatusBar", nil, resContainer)
            resBar:SetSize(rowWidth - 4, barHeight - 4)
            resBar:SetPoint("CENTER", resContainer, "CENTER", 0, 0)
            resBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            resBar:SetStatusBarColor(res.color[1], res.color[2], res.color[3])
            resBar:SetMinMaxValues(0, res.max or 100)
            resBar:SetValue(0)

            local resInner = resBar:CreateTexture(nil, "BACKGROUND")
            resInner:SetAllPoints()
            resInner:SetTexture(0.08, 0.08, 0.08, 1)

            local resText = resBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            resText:SetPoint("CENTER", resBar, "CENTER", 0, 0)
            resText:SetTextColor(1, 1, 1)
            resText:SetText("0")

            elements.resource = { frame = resBar, text = resText, container = resContainer }

            currentY = currentY - barHeight - 5
        end

        -- ===== 3. Secondary row (combo points / runes) - optional =====
        local sec = CONFIG.secondary
        if sec then
            local secCount = sec.count
            local secHeight = sec.height
            local secWidth = (rowWidth - (secCount - 1) * spacing) / secCount
            local secStartX = -rowWidth / 2

            for i = 1, secCount do
                local slot = CreateFrame("Frame", nil, mainFrame)
                slot:SetSize(secWidth, secHeight)
                slot:SetPoint("TOPLEFT", mainFrame, "TOP",
                    secStartX + (i - 1) * (secWidth + spacing), currentY)

                local sBorder = slot:CreateTexture(nil, "BACKGROUND")
                sBorder:SetPoint("TOPLEFT", -1, 1)
                sBorder:SetPoint("BOTTOMRIGHT", 1, -1)
                sBorder:SetTexture(0.35, 0.35, 0.35, 1)

                local sBg = slot:CreateTexture(nil, "BORDER")
                sBg:SetAllPoints()
                sBg:SetTexture(0.05, 0.05, 0.05, 0.9)

                local fill = slot:CreateTexture(nil, "ARTWORK")
                local cdText
                if sec.type == "rune" then
                    -- Rune: left-anchored bar whose width is driven from UpdateUI
                    fill:SetPoint("TOPLEFT", 1, -1)
                    fill:SetPoint("BOTTOMLEFT", 1, 1)
                    fill:SetTexture(1, 1, 1)
                    fill:SetWidth(0)

                    -- Seconds remaining while the rune recharges (no sweep).
                    cdText = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    cdText:SetPoint("CENTER", slot, "CENTER", 0, 0)
                    cdText:SetTextColor(1, 1, 1)
                    cdText:Hide()
                else
                    fill:SetPoint("TOPLEFT", 1, -1)
                    fill:SetPoint("BOTTOMRIGHT", -1, 1)
                    fill:SetTexture(sec.color[1], sec.color[2], sec.color[3])
                    fill:Hide()
                end

                elements.secondary[i] = {
                    fill = fill, parent = slot, fillMax = secWidth - 2,
                    cooldownText = cdText
                }
            end

            currentY = currentY - secHeight - 5
        end

        return currentY
    end

    -- =======================================================================
    -- BUILD UI
    -- =======================================================================
    local function BuildUI(force)
        InvalidateSpellKnowledge()
        local signature = ComputeKnownSignature()
        if not force and mainFrame and signature == lastBuildSignature then
            return
        end
        lastBuildSignature = signature

        ClearUI()

        local size = CONFIG.iconSize
        local spacing = CONFIG.spacing

        local currentY = BuildTopSection(0)

        -- ===== Create ALL ability icons (hidden; positioned dynamically) =====
        local function BuildAbility(data)
            if IsTracked(data) then
                local icon = CreateIcon(mainFrame, data.size or CONFIG.abilityIconSize)
                icon.texture:SetTexture(GetIconTexture(data))
                icon:Hide()
                table.insert(elements.abilities, {
                    frame = icon, name = data.name, size = data.size,
                    showCount = data.showCount, spellID = data.spellID,
                    altAuras = data.altAuras, alwaysVisible = data.alwaysVisible,
                    group = data.group, playerOnly = data.playerOnly
                })
            end
        end

        for _, data in ipairs(CONFIG.abilities) do BuildAbility(data) end
        -- Shared external buffs, shown on every tracker.
        for _, data in ipairs(COMMON_ABILITIES) do BuildAbility(data) end

        -- ===== Cooldowns =====
        local cdRows = BuildIconGrid(CONFIG.cooldowns, currentY, elements.cooldowns, CONFIG.maxCooldownsPerRow)
        if cdRows > 0 then
            currentY = currentY - cdRows * (size + spacing) - 5
        end

        -- ===== Warning (anchored under everything else) =====
        if mainFrame.warn then
            mainFrame.warn:ClearAllPoints()
            mainFrame.warn:SetPoint("TOP", mainFrame, "TOP", 0, currentY)
        end
    end

    -- =======================================================================
    -- UPDATE LOGIC
    -- =======================================================================
    local function FormatTime(seconds)
        if seconds >= 60 then
            return string.format("%dm", math.floor(seconds / 60))
        elseif seconds >= 10 then
            return string.format("%d", math.floor(seconds))
        else
            return string.format("%.1f", seconds)
        end
    end

    -- =======================================================================
    -- AURA LOOKUP
    --
    -- Each unit is scanned once per refresh into reusable tables (no
    -- allocation), then every tracked spell is a table lookup.
    -- =======================================================================
    local AURA_SCAN_LIMIT = 40
    local PERMANENT_REMAINING = math.huge

    local function NewAuraCache()
        return {
            seen = {}, count = 0, remaining = {}, start = {}, duration = {}, stacks = {}, caster = {},
            idSeen = {}, idCount = 0, idRemaining = {}, idStart = {}, idDuration = {}, idStacks = {}, idCaster = {}
        }
    end

    local playerHelpful = NewAuraCache()
    local playerHarmful = NewAuraCache()
    local targetHelpful = NewAuraCache()
    local targetHarmful = NewAuraCache()

    local auraNow = 0
    local auraPlayerReady, auraTargetReady = false, false

    local function CollectAuras(cache, unit, filter)
        local seen, remaining = cache.seen, cache.remaining
        local start, duration = cache.start, cache.duration
        local stacks, caster = cache.stacks, cache.caster

        for i = 1, cache.count do
            local name = seen[i]
            seen[i] = nil
            remaining[name], start[name], duration[name], stacks[name], caster[name] = nil, nil, nil, nil, nil
        end
        cache.count = 0

        -- Auras are also indexed by their spell ID so entries can match a
        -- specific rank/effect (e.g. Arcane Blast's stacking debuff 36032)
        -- instead of relying on the displayed name.
        local idSeen = cache.idSeen
        local idRemaining, idStart = cache.idRemaining, cache.idStart
        local idDuration, idStacks, idCaster = cache.idDuration, cache.idStacks, cache.idCaster

        for i = 1, cache.idCount do
            local id = idSeen[i]
            idSeen[i] = nil
            if id then
                idRemaining[id], idStart[id], idDuration[id], idStacks[id], idCaster[id] = nil, nil, nil, nil, nil
            end
        end
        cache.idCount = 0

        for i = 1, AURA_SCAN_LIMIT do
            local name, _, _, auraCount, _, auraDuration, expirationTime, auraCaster, _, _, spellId =
                UnitAura(unit, i, filter)
            if not name then break end

            local timed = auraDuration or 0
            local rem, auraStart
            if timed > 0 then
                local expiration = expirationTime or 0
                rem = expiration - auraNow
                auraStart = expiration - timed
            else
                -- Permanent aura (e.g. Stealth): no clock, always active.
                rem = PERMANENT_REMAINING
                auraStart = 0
            end
            local count = auraCount or 0
            -- The same spell can be present from several casters (two
            -- warlocks' Corruption on one target). Keep the player's own
            -- copy, so entries with playerOnly never mistake someone else's
            -- DoT for ours.
            local preferPlayer = (auraCaster == "player") and (remaining[name] ~= nil) and (caster[name] ~= "player")

            if remaining[name] == nil then
                remaining[name], start[name], duration[name], stacks[name] = rem, auraStart, timed, count
                caster[name] = auraCaster
                cache.count = cache.count + 1
                seen[cache.count] = name
            elseif preferPlayer then
                remaining[name], start[name], duration[name], stacks[name] = rem, auraStart, timed, count
                caster[name] = auraCaster
            end

            if spellId then
                local idPreferPlayer = (auraCaster == "player") and (idRemaining[spellId] ~= nil) and (idCaster[spellId] ~= "player")
                if idRemaining[spellId] == nil then
                    idRemaining[spellId], idStart[spellId] = rem, auraStart
                    idDuration[spellId], idStacks[spellId] = timed, count
                    idCaster[spellId] = auraCaster
                    cache.idCount = cache.idCount + 1
                    idSeen[cache.idCount] = spellId
                elseif idPreferPlayer then
                    idRemaining[spellId], idStart[spellId] = rem, auraStart
                    idDuration[spellId], idStacks[spellId] = timed, count
                    idCaster[spellId] = auraCaster
                end
            end
        end
    end

    -- playerOnly: when true, only an aura whose caster is the player matches.
    -- Used for the warlock's damage-over-time debuffs, so another caster's
    -- Corruption/Unstable Affliction/Curse of Agony never reads as ours.
    local function LookupAura(cache, spellName, spellID, playerOnly)
        -- Prefer an explicit spell ID when the entry supplies one.
        if spellID then
            local remaining = cache.idRemaining[spellID]
            if remaining ~= nil and not (playerOnly and cache.idCaster[spellID] ~= "player") then
                if remaining > 0 then
                    return true, remaining, cache.idStart[spellID], cache.idDuration[spellID], cache.idStacks[spellID]
                end
                return true, 0, 0, 0, cache.idStacks[spellID]
            end
        end
        local remaining = cache.remaining[spellName]
        if remaining == nil then return false, 0, 0, 0, 0 end
        if playerOnly and cache.caster[spellName] ~= "player" then
            return false, 0, 0, 0, 0
        end
        if remaining > 0 then
            return true, remaining, cache.start[spellName], cache.duration[spellName], cache.stacks[spellName]
        end
        return true, 0, 0, 0, cache.stacks[spellName]
    end

    local function GetPlayerAura(spellName, spellID, playerOnly)
        if not auraPlayerReady then
            auraPlayerReady = true
            CollectAuras(playerHelpful, "player", "HELPFUL")
            CollectAuras(playerHarmful, "player", "HARMFUL")
        end
        -- Buffs first, then debuffs, so a spell an effect is tracked whether
        -- the client files it as helpful or harmful on the player.
        local found, remaining, auraStart, auraDuration, auraCount =
            LookupAura(playerHelpful, spellName, spellID, playerOnly)
        if found then return found, remaining, auraStart, auraDuration, auraCount end
        return LookupAura(playerHarmful, spellName, spellID, playerOnly)
    end

    local function GetTargetAura(spellName, spellID, playerOnly)
        if not auraTargetReady then
            auraTargetReady = true
            CollectAuras(targetHelpful, "target", "HELPFUL")
            CollectAuras(targetHarmful, "target", "HARMFUL")
        end
        local found, remaining, auraStart, auraDuration, auraCount =
            LookupAura(targetHelpful, spellName, spellID, playerOnly)
        if found then return found, remaining, auraStart, auraDuration, auraCount end
        return LookupAura(targetHarmful, spellName, spellID, playerOnly)
    end

    -- An ability may list altAuras = { { name, spellID }, ... }: other auras
    -- that grant the exact same effect even though a different class cast them
    -- (e.g. a warlock's "Shadow Mastery" debuff gives the same +5% spell crit
    -- as a mage's "Improved Scorch", so one icon can stand in for both). The
    -- primary aura is checked first, then every alternate; first match wins.
    local function FindAbilityAura(data)
        local playerOnly = data.playerOnly
        local found, remaining, auraStart, auraDuration, auraCount =
            GetPlayerAura(data.name, data.spellID, playerOnly)
        if found then return found, remaining, auraStart, auraDuration, auraCount end
        found, remaining, auraStart, auraDuration, auraCount =
            GetTargetAura(data.name, data.spellID, playerOnly)
        if found then return found, remaining, auraStart, auraDuration, auraCount end

        local alts = data.altAuras
        if alts then
            for i = 1, #alts do
                local alt = alts[i]
                found, remaining, auraStart, auraDuration, auraCount =
                    GetPlayerAura(alt.name, alt.spellID)
                if found then return found, remaining, auraStart, auraDuration, auraCount end
                found, remaining, auraStart, auraDuration, auraCount =
                    GetTargetAura(alt.name, alt.spellID)
                if found then return found, remaining, auraStart, auraDuration, auraCount end
            end
        end
        return false, 0, 0, 0, 0
    end

    local function UpdateUI()
        if not mainFrame then return end

        local nowTime = GetTime()
        auraNow = nowTime
        auraPlayerReady, auraTargetReady = false, false

        -- Cooldowns (GCD filtered, with proc glow + clock sweep)
        local inCombat = UnitAffectingCombat("player")
        local cooldowns = elements.cooldowns
        for i = 1, #cooldowns do
            local data = cooldowns[i]
            local frame = data.frame

            local remaining = 0
            local start, duration = GetSpellCooldown(data.name)
            if start and duration then
                remaining = (start + duration) - nowTime
                if remaining > 0 and remaining <= 2.0 and duration <= 2.0 then
                    remaining = 0
                end
            end

            if remaining > 0 then
                local text = FormatTime(remaining)
                if data.rtText ~= text then
                    data.rtText = text
                    frame.text:SetText(text)
                end
                if not data.rtDimmed then
                    data.rtDimmed = true
                    frame.texture:SetVertexColor(0.5, 0.5, 0.5)
                end
                -- A real cooldown's remaining time ticks down every refresh.
                -- A few spells report a frozen one (Raise Dead while the ghoul
                -- is up sits at a constant 30s): show the number, but never
                -- start a sweep for something that is not counting down, and
                -- never restart a running sweep (jitter made it creep forward
                -- and snap back).
                local prevRemaining = data.rtLastRemaining
                local ticking = (prevRemaining ~= nil) and (remaining < prevRemaining - 0.05)

                if ticking then
                    local newCooldown = (data.rtStart == nil)
                        or (remaining > prevRemaining + 0.2)
                        or (math.abs(duration - (data.rtDuration or 0)) > 0.25)
                    if newCooldown then
                        data.rtStart, data.rtDuration = start, duration
                        frame.cooldownFrame:SetCooldown(start, duration)
                    end
                    if not data.rtCooldownShown then
                        data.rtCooldownShown = true
                        frame.cooldownFrame:Show()
                    end
                elseif data.rtCooldownShown or data.rtStart ~= 0 then
                    data.rtCooldownShown = false
                    data.rtStart, data.rtDuration = 0, 0
                    frame.cooldownFrame:SetCooldown(0, 0)
                    frame.cooldownFrame:Hide()
                end
                data.rtLastRemaining = remaining
            else
                if data.rtText ~= "" then
                    data.rtText = ""
                    frame.text:SetText("")
                end
                if data.rtDimmed then
                    data.rtDimmed = false
                    frame.texture:SetVertexColor(1, 1, 1)
                end
                if data.rtCooldownShown or data.rtStart ~= 0 then
                    data.rtCooldownShown = false
                    data.rtStart, data.rtDuration = 0, 0
                    data.rtLastRemaining = nil
                    frame.cooldownFrame:SetCooldown(0, 0)
                    frame.cooldownFrame:Hide()
                end
            end

            -- Proc glow
            if data.glowWhenReady then
                local shouldGlow = inCombat and remaining == 0
                if data.rtGlowing ~= shouldGlow then
                    data.rtGlowing = shouldGlow
                    if shouldGlow then
                        frame:StartGlow()
                    else
                        frame:StopGlow()
                    end
                end
            end
        end

        -- Abilities - ACTIVE ones (plus alwaysVisible reminders) CENTERED
        do
            local abilitySize = CONFIG.abilityIconSize
            local spacing = CONFIG.spacing
            local count = 0

            -- Mutually-exclusive groups (e.g. a warlock's curses, only one of
            -- which can be up at a time). When any member of a group is active
            -- the other members are hidden, even if they are alwaysVisible.
            local activeGroups = {}
            for i = 1, #elements.abilities do
                local data = elements.abilities[i]
                if data.group then
                    local found, remaining = FindAbilityAura(data)
                    if found and remaining > 0 then
                        activeGroups[data.group] = true
                    end
                end
            end

            for i = 1, #elements.abilities do
                local data = elements.abilities[i]
                local found, remaining, auraStart, auraDuration, auraCount = FindAbilityAura(data)
                local active = found and remaining > 0
                local suppressed = data.group and activeGroups[data.group] and not active

                -- alwaysVisible abilities keep their slot even while the aura
                -- is down, so they render desaturated as a "missing" reminder.
                if (active or data.alwaysVisible) and not suppressed then
                    count = count + 1
                    local entry = activeAbilities[count]
                    if not entry then
                        entry = {}
                        activeAbilities[count] = entry
                    end
                    entry.frame = data.frame
                    entry.index = i
                    entry.size = data.size
                    entry.active = active
                    entry.remaining = active and remaining or 0
                    entry.start = active and auraStart or 0
                    entry.duration = active and auraDuration or 0
                    entry.count = auraCount
                    entry.showCount = data.showCount
                else
                    data.frame:Hide()
                    IconStopBlink(data.frame)
                    if data.frame.cooldownFrame then
                        data.frame.cooldownFrame:Hide()
                    end
                end
            end

            if count > 0 then
                local signature = 0
                for i = 1, count do
                    signature = signature * 64 + activeAbilities[i].index
                end
                local relayout = (signature ~= lastAbilitySignature)
                lastAbilitySignature = signature

                -- Variable-sized icons: centre the row by summing real widths,
                -- bottom edges aligned so bigger icons grow upward.
                local rowBottom = (elements.abilityRowY or 0) - (elements.abilityRowHeight or abilitySize)
                local cursorX
                if relayout then
                    local totalWidth = spacing * (count - 1)
                    for i = 1, count do
                        totalWidth = totalWidth + (activeAbilities[i].size or abilitySize)
                    end
                    cursorX = -(totalWidth / 2)
                end

                for i = 1, count do
                    local entry = activeAbilities[i]
                    local frame = entry.frame

                    if relayout then
                        local s = entry.size or abilitySize
                        frame:ClearAllPoints()
                        frame:SetPoint("BOTTOM", mainFrame, "TOP", cursorX + s / 2, rowBottom)
                        cursorX = cursorX + s + spacing
                    end

                    frame:Show()
                    frame.border:Hide()

                    -- Active: full colour + timer. Visible-but-missing: grayscale,
                    -- no timer or clock, so it reads as an upkeep reminder.
                    if entry.active then
                        frame.texture:SetDesaturated(false)
                        frame.texture:SetVertexColor(1, 1, 1)
                    else
                        frame.texture:SetDesaturated(true)
                        frame.texture:SetVertexColor(0.55, 0.55, 0.55)
                    end

                    if entry.active and entry.duration > 0 and entry.remaining < BLINK_THRESHOLD then
                        IconStartBlink(frame)
                    else
                        IconStopBlink(frame)
                    end

                    local text = (entry.active and entry.duration > 0) and FormatTime(entry.remaining) or ""
                    if frame.rtText ~= text then
                        frame.rtText = text
                        frame.text:SetText(text)
                    end

                    -- Optional stack count in the corner (data.showCount).
                    if entry.showCount and entry.count and entry.count > 1 then
                        if frame.rtCount ~= entry.count then
                            frame.rtCount = entry.count
                            frame.countText:SetText(entry.count)
                        end
                        if not frame.rtCountShown then
                            frame.rtCountShown = true
                            frame.countText:Show()
                        end
                    elseif frame.rtCountShown then
                        frame.rtCountShown = false
                        frame.rtCount = nil
                        frame.countText:Hide()
                    end

                    -- Clock sweep for the buff/debuff duration
                    if frame.cooldownFrame then
                        if entry.active and entry.duration > 0 then
                            frame.cooldownFrame:Show()
                            if frame.rtStart ~= entry.start or frame.rtDuration ~= entry.duration then
                                frame.rtStart, frame.rtDuration = entry.start, entry.duration
                                frame.cooldownFrame:SetCooldown(entry.start, entry.duration)
                            end
                        else
                            frame.cooldownFrame:Hide()
                            frame.rtStart, frame.rtDuration = 0, 0
                        end
                    end
                end
            else
                lastAbilitySignature = 0
            end
        end

        -- Resource (energy / runic power)
        local resource = elements.resource
        if resource then
            local res = CONFIG.resource
            local value = UnitPower("player", res.powerType) or 0
            if res.dynamicMax then
                local maxValue = UnitPowerMax("player", res.powerType) or (res.max or 100)
                if maxValue < 1 then maxValue = 1 end
                if resource.rtMax ~= maxValue then
                    resource.rtMax = maxValue
                    resource.frame:SetMinMaxValues(0, maxValue)
                end
            end
            if resource.rtValue ~= value then
                resource.rtValue = value
                resource.frame:SetValue(value)
                resource.text:SetText(tostring(value))
            end
        end

        -- Secondary row (combo points / runes) - optional
        local sec = CONFIG.secondary
        if sec and sec.type == "rune" then
            local runeColors = sec.colors
            local runeFallback = sec.fallbackType
            local runeOrder = sec.order
            local runeDim = sec.dim
            for i = 1, sec.count do
                local rune = elements.secondary[i]
                -- order maps the on-screen slot to the client's rune index, so a
                -- fixed layout (blood blood frost frost unholy unholy) renders
                -- regardless of the client's native slot order.
                local slot = runeOrder and runeOrder[i] or i
                if rune then
                    local start, duration, ready = GetRuneCooldown(slot)

                    -- Seconds remaining while recharging (number only).
                    if rune.cooldownText then
                        if start and not ready and duration and duration > 0 then
                            if not rune.rtCdShown then
                                rune.rtCdShown = true
                                rune.cooldownText:Show()
                            end
                            local remaining = (start + duration) - nowTime
                            if remaining < 0 then remaining = 0 end
                            local text = FormatTime(remaining)
                            if rune.rtCdText ~= text then
                                rune.rtCdText = text
                                rune.cooldownText:SetText(text)
                            end
                        elseif rune.rtCdShown then
                            rune.rtCdShown = false
                            rune.rtCdText = nil
                            rune.cooldownText:Hide()
                        end
                    end

                    if start then
                        local fraction
                        if ready or not duration or duration <= 0 then
                            fraction = ready and 1 or 0
                        else
                            fraction = (nowTime - start) / duration
                            if fraction < 0 then fraction = 0 elseif fraction > 1 then fraction = 1 end
                        end

                        local quant = math.floor(fraction * 64)
                        local runeType = GetRuneType(slot) or rune.rtType or runeFallback[slot] or 1

                        if rune.rtQuant ~= quant or rune.rtType ~= runeType or rune.rtReady ~= ready then
                            rune.rtQuant, rune.rtType, rune.rtReady = quant, runeType, ready

                            local color = runeColors[runeType] or runeColors[1]
                            local scale = ready and 1 or runeDim
                            rune.fill:SetVertexColor(color[1] * scale, color[2] * scale, color[3] * scale)
                            rune.fill:SetWidth(rune.fillMax * (quant / 64))
                        end
                    end
                end
            end
        elseif sec then
            local cp = GetComboPoints("player", "target")
            if elements.rtComboPoints ~= cp then
                elements.rtComboPoints = cp
                for i = 1, sec.count do
                    local point = elements.secondary[i]
                    if point then
                        local shouldShow = (i <= cp)
                        if point.rtShown ~= shouldShow then
                            point.rtShown = shouldShow
                            if shouldShow then
                                point.fill:Show()
                            else
                                point.fill:Hide()
                            end
                        end
                    end
                end
            end
        end

        -- Warning bar
        do
            local warn = mainFrame.warn
            if warn then
                local text
                if CONFIG.warning.type == "upkeep" then
                    -- Missing while the tracked upkeep buff has actually fallen off
                    local found, remaining = GetPlayerAura(CONFIG.warning.name)
                    text = (found and remaining > 0) and "" or CONFIG.warning.text
                elseif CONFIG.warning.type == "auras" then
                    -- Any number of upkeep buffs; names whichever are missing.
                    -- Entries whose spell is not even known (a talent this
                    -- character did not take) are skipped.
                    local missing = ""
                    for _, entry in ipairs(CONFIG.warning.auras) do
                        if IsSpellKnown(entry.name) then
                            local found, remaining = GetPlayerAura(entry.name)
                            if not (found and remaining > 0) then
                                missing = (missing ~= "") and (missing .. " + " .. entry.text) or entry.text
                            end
                        end
                    end
                    text = (missing ~= "") and ((CONFIG.warning.prefix or "MISSING: ") .. missing) or ""
                else
                    -- Poison. GetWeaponEnchantInfo reports the temporary enchant
                    -- on each weapon; a hand only counts when a weapon is
                    -- actually equipped there - an empty off-hand needs no poison.
                    local hasMH, _, _, hasOH = GetWeaponEnchantInfo()
                    local missing = ""
                    if not hasMH and GetInventoryItemLink("player", 16) then
                        missing = "Main Hand"
                    end
                    if not hasOH and GetInventoryItemLink("player", 17) then
                        missing = (missing ~= "") and (missing .. " + Off Hand") or "Off Hand"
                    end
                    text = (missing ~= "") and ("POISON: " .. missing) or ""
                end

                if warn.rtText ~= text then
                    warn.rtText = text
                    if text == "" then
                        warn:Hide()
                    else
                        warn.text:SetText(text)
                        warn:Show()
                    end
                end
            end
        end
    end

    -- =======================================================================
    -- EVENT HANDLING
    --
    -- All aura/combo/rune state is polled at 10 Hz anyway, so UNIT_AURA,
    -- PLAYER_TARGET_CHANGED and their friends are not registered; the tick is
    -- the single refresh point. Worst case a change shows 100 ms later.
    -- =======================================================================
    local UPDATE_INTERVAL = 0.1
    local updateElapsed = 0

    local function OnUpdateFrame(_, elapsed)
        updateElapsed = updateElapsed + elapsed
        if updateElapsed >= UPDATE_INTERVAL then
            updateElapsed = 0
            UpdateUI()
        end
    end

    local moduleFrame = CreateFrame("Frame", ADDON_NAME)
    _G[ADDON_NAME] = moduleFrame

    local function OnEvent(_, event)
        if event == "SPELLS_CHANGED"
            or event == "CHARACTER_POINTS_CHANGED"
            or event == "PLAYER_TALENT_UPDATE"
            or event == "ACTIONBAR_SLOT_CHANGED"
            or event == "PLAYER_ENTERING_WORLD" then
            -- BuildUI is a no-op when the known-spell set is unchanged.
            BuildUI(); UpdateUI()
        end
    end

    moduleFrame:SetScript("OnEvent", OnEvent)
    moduleFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    moduleFrame:RegisterEvent("SPELLS_CHANGED")
    moduleFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
    moduleFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    moduleFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")

    InitializeDB()
    CreateMainFrame()
    BuildUI()

    mainFrame:SetScript("OnUpdate", OnUpdateFrame)

    -- =======================================================================
    -- SLASH COMMAND HANDLER
    --
    -- Every class shares the single "/tracker" entry point (registered once by
    -- the core); this module's handler is what it forwards to.
    -- =======================================================================
    local function HandleSlash(msg)
        msg = string.lower(msg or "")
        if msg == "lock" then
            db.locked = true
            if mainFrame and mainFrame.ApplyMouseState then mainFrame:ApplyMouseState() end
            print(PREFIX .. ": Locked. Click-through enabled.")
        elseif msg == "unlock" then
            db.locked = false
            if mainFrame and mainFrame.ApplyMouseState then mainFrame:ApplyMouseState() end
            print(PREFIX .. ": Unlocked. Drag to move.")
        elseif msg == "reset" then
            db.point = { "CENTER", 0, -100 }
            mainFrame:ClearAllPoints()
            mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
            print(PREFIX .. ": Position reset.")
        elseif msg == "rebuild" then
            BuildUI(true); UpdateUI()
            print(PREFIX .. ": Rebuilt.")
        elseif msg == "force" then
            db.forceShow = not db.forceShow
            BuildUI(); UpdateUI()
            print(PREFIX .. ": Force-show " ..
                (db.forceShow and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"))
        elseif msg == "debug" then
            print(PREFIX .. " Debug:|r")
            for _, name in ipairs(CONFIG.debugSpells or {}) do
                print("  " .. name .. " known: " .. tostring(IsSpellKnown(name)))
            end
            local first = CONFIG.debugSpells and CONFIG.debugSpells[1]
            if first then
                local _, _, spellID = GetSpellInfo(first)
                print("  " .. first .. " spellID: " .. tostring(spellID))
                local ok, tex = pcall(GetSpellTexture, first)
                print("  " .. first .. " texture (dynamic): " .. tostring(ok and tex or "FAILED"))
            end
            if CONFIG.debugExtra then CONFIG.debugExtra(elements, CONFIG) end
        elseif msg == "debugauras" then
            print(PREFIX .. " Player buffs:|r")
            for i = 1, AURA_SCAN_LIMIT do
                local name, _, _, count, _, duration, _, _, _, _, spellId =
                    UnitAura("player", i, "HELPFUL")
                if not name then break end
                print(string.format("  [%d] %s  x%d  id=%s  %.1fs",
                    i, name, count or 0, tostring(spellId), duration or 0))
            end
            print(PREFIX .. " Player debuffs:|r")
            for i = 1, AURA_SCAN_LIMIT do
                local name, _, _, count, _, duration, _, _, _, _, spellId =
                    UnitAura("player", i, "HARMFUL")
                if not name then break end
                print(string.format("  [%d] %s  x%d  id=%s  %.1fs",
                    i, name, count or 0, tostring(spellId), duration or 0))
            end
            print(PREFIX .. " Tracked abilities:|r")
            for i = 1, #elements.abilities do
                local data = elements.abilities[i]
                local found, remaining = FindAbilityAura(data)
                print(string.format("  %s (id=%s): found=%s rem=%.1f",
                    data.name, tostring(data.spellID), tostring(found), remaining or 0))
            end
        elseif msg == "scale" then
            local scale = tonumber(strmatch(msg, "scale (%d+%.?%d*)"))
            if scale then
                db.scale = math.max(0.5, math.min(2.0, scale))
                mainFrame:SetScale(db.scale)
                print(PREFIX .. ": Scale set to " .. db.scale)
            else
                print(PREFIX .. ": Usage: /tracker scale <0.5-2.0>")
            end
        elseif msg == "debugglow" then
            print(PREFIX .. " Glow Debug:|r")
            print("  In combat: " .. tostring(UnitAffectingCombat("player")))
            print("  Cooldown elements count: " .. #elements.cooldowns)
            for i, data in ipairs(elements.cooldowns) do
                if data.glowWhenReady then
                    local start, duration = GetSpellCooldown(data.name)
                    local remaining = 0
                    if start and duration then
                        remaining = (start + duration) - GetTime()
                        if remaining <= 2.0 and duration <= 2.0 then remaining = 0 end
                    end
                    print(string.format("  [%d] %s  glowWhenReady=%s  remaining=%.2f",
                        i, data.name, tostring(data.glowWhenReady), remaining))
                end
            end
        elseif msg == "forceglow" then
            for _, data in ipairs(elements.cooldowns) do
                if data.frame.StartGlow then
                    data.frame:StartGlow()
                end
            end
            print(PREFIX .. ": Forced glow on ALL cooldowns for 3 seconds.")
            local t = 0
            local f = CreateFrame("Frame")
            f:SetScript("OnUpdate", function(self, dt)
                t = t + dt
                if t >= 3 then
                    for _, d in ipairs(elements.cooldowns) do
                        if d.frame.StopGlow then d.frame:StopGlow() end
                    end
                    self:SetScript("OnUpdate", nil)
                end
            end)
        else
            print(PREFIX .. " Commands:|r")
            print("  /tracker lock | unlock | reset | rebuild | force | debug | debugauras | scale <n>")
        end
    end

    -- Shared "/tracker" entry point forwards to whichever module is active.
    self.slashHandler = HandleSlash
    self.activePrefix = PREFIX

    print(PREFIX .. " loaded. Type /tracker for help.")
end

-- ===========================================================================
-- CLASS-MODULE LOADER
-- ===========================================================================
local function OnCoreEvent(self, event)
    if event ~= "PLAYER_LOGIN" then return end
    self.loggedIn = true

    local _, class = UnitClass("player")
    local config = self.pending[class]
    if config then
        -- Module was loaded normally; just build it now.
        self:InitModule(config)
    else
        -- Module is LoadOnDemand: pull in the one for this class.
        local addon = MODULES[class]
        if addon then
            LoadAddOn(addon)
            if IsAddOnLoaded and not IsAddOnLoaded(addon) then
                print("|cff8888ffTrackerCore|r: could not load " .. addon .. ".")
            end
        end
    end

    self:UnregisterEvent("PLAYER_LOGIN")
end

Core:SetScript("OnEvent", OnCoreEvent)
Core:RegisterEvent("PLAYER_LOGIN")
