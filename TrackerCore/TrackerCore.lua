--[[--------------------------------------------------------------------------
    TrackerCore - WotLK 3.3.5a

    Shared engine for the class trackers. Each <Class>Tracker is a separate
    LoadOnDemand addon that only calls TrackerCore:RegisterModule(config).
    Everything else lives here: spellbook scanning, aura lookup, the icon
    factory, glow, layout, the refresh loop and /tracker.

    Add new classes to MODULES below.
--------------------------------------------------------------------------]]

local CORE_NAME = "TrackerCore"
local Core = CreateFrame("Frame")
_G[CORE_NAME] = Core

-- class token -> module addon name
local MODULES = {
    ROGUE       = "RogueTracker",
    DEATHKNIGHT = "DKTracker",
    HUNTER      = "HunterTracker",
    MAGE        = "MageTracker",
    PRIEST      = "PriestTracker",
    WARRIOR     = "WarriorTracker",
    WARLOCK     = "WarlockTracker",
    DRUID       = "DruidTracker",
    PALADIN     = "PaladinTracker"
}

-- Buffs other classes cast on the player, shown by every tracker.
-- alwaysShow because we cannot learn them ourselves.
local COMMON_ABILITIES = {
    { name = "Hand of Freedom",    icon = "Interface\\Icons\\Spell_Holy_SealOfValor",      alwaysShow = true },
    { name = "Hand of Protection", icon = "Interface\\Icons\\Spell_Holy_SealOfProtection", alwaysShow = true },
    { name = "Hand of Salvation",  icon = "Interface\\Icons\\Spell_Holy_SealOfSalvation",  alwaysShow = true },
    { name = "Hand of Sacrifice",  icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",  alwaysShow = true },
    { name = "Power Infusion",     icon = "Interface\\Icons\\Spell_Holy_PowerInfusion",    alwaysShow = true },
    -- Hysteria can be given to any class, so every tracker watches for it.
    -- The giver's own tracker may also list it as a cooldown; that is the
    -- "can I cast it" timer, this is the "do I have it" buff.
    { name = "Hysteria",           icon = "Interface\\Icons\\Spell_DeathKnight_Hysteria",  alwaysShow = true, size = 46 }
}

Core.pending = {}       -- module configs registered before login
Core.initialized = {}   -- addon names that have been built already
Core.loggedIn = false

-- ===========================================================================
-- SHARED COMMAND
-- /tracker forwards to the active class module's handler.
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
-- config:
--   addonName, dbName, className, printColor
--   cooldowns, abilities (see entry options below)
--   iconSize, abilityIconSize, spacing, maxCooldownsPerRow
--   point, scale, locked, swipeLayers
--   resource, secondary, warning
--   rotation (optional): Clash-style "next spell" queue. Keys:
--     icons, iconSize, spacing, glowNext, list, aoeBuff, aoeList.
--     list entries take "name" and "execute" (target below 20% HP);
--     aoeList replaces list while aoeBuff is up on the player;
--     undeadOnly entries need an undead target.
--
-- entry options:
--   size          bigger icon
--   spellID       match the aura by ID
--   alwaysShow    build a proc aura that is not in the spellbook
--   showCount     show the aura stack count
--   altAuras      another class's aura with the same effect
--   alwaysVisible keep the slot while missing, drawn grey
--   playerOnly    only count auras you cast
--   group         mutually-exclusive auras; only the active one shows
-- ===========================================================================
function Core:InitModule(CONFIG)
    if self.initialized[CONFIG.addonName] then return end

    local _, playerClass = UnitClass("player")
    if playerClass ~= CONFIG.className then return end
    self.initialized[CONFIG.addonName] = true

    local ADDON_NAME = CONFIG.addonName
    local PREFIX = CONFIG.printColor .. ADDON_NAME .. "|r"

    -- =======================================================================
    -- DATABASE
    -- Saved in TrackerCoreDB. A LoadOnDemand addon's own saved variables are
    -- not ready early enough, so we adopt the old per-module table on first
    -- run to keep existing position/scale/lock.
    -- =======================================================================
    -- The frame used to be a fixed 500 tall and anchored by CENTER, so its top
    -- edge (where everything is laid out from) depended on that height and the
    -- empty lower half still swallowed mouse clicks. Anchor by the top edge
    -- instead: then the height can track the content and the icons never move.
    local LEGACY_FRAME_HEIGHT = 500

    local function IsTopAnchored(point)
        return type(point) == "string" and string.find(point, "TOP", 1, true) ~= nil
    end

    -- How far down the frame the anchor sits, as a fraction of its height.
    local function AnchorFraction(point)
        if type(point) == "string" then
            if string.find(point, "TOP", 1, true) then return 0 end
            if string.find(point, "BOTTOM", 1, true) then return 1 end
        end
        return 0.5   -- CENTER, MIDDLE, LEFT, RIGHT
    end

    -- Rewrite an old height-dependent point (CENTER/BOTTOM/...) as the
    -- equivalent TOP point, keeping the frame's top edge exactly where it was.
    local function ToTopPoint(point, x, y, frameHeight)
        if IsTopAnchored(point) then return point, x, y end
        return "TOP", x, y + AnchorFraction(point) * (frameHeight - UIParent:GetHeight())
    end

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
        db.point[1], db.point[2], db.point[3] =
            ToTopPoint(db.point[1], db.point[2], db.point[3], LEGACY_FRAME_HEIGHT)
        db.scale = db.scale or CONFIG.scale
        db.locked = db.locked or CONFIG.locked
        if db.swipeLayers == nil then db.swipeLayers = CONFIG.swipeLayers or 2 end
    end

    -- =======================================================================
    -- SPELLBOOK SCANNING
    -- Spellbook and action bar are scanned once per generation, then every
    -- answer is cached.
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

        if knownGen[spellName] == knownGeneration then
            return knownVal[spellName]
        end

        local known

        -- 1: spellbook by name
        if GetSpellbookNames()[spellName] then
            known = true
        else
            -- 2: IsSpellKnown/IsPlayerSpell via the spell ID
            known = false
            local _, _, spellID = GetSpellInfo(spellName)
            if spellID then
                if IsSpellKnown and IsSpellKnown(spellID) then
                    known = true
                elseif IsPlayerSpell and IsPlayerSpell(spellID) then
                    known = true
                end
            end

            -- 3: action bars
            if not known and GetActionBarNames()[spellName] then
                known = true
            end

            -- 4: GetSpellCooldown only returns data for known spells
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

    -- alwaysShow: procs and set bonuses that are not in the spellbook.
    local function IsTracked(data)
        return data.alwaysShow or IsSpellKnown(data.name)
    end

    -- Signature of the currently-known spells, so an unchanged rebuild is skipped.
    local function ComputeKnownSignature()
        local signature = 0

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

    -- Icon lookup: spell texture first, then the hardcoded path. fixedIcon
    -- skips the lookup for spells the client reports wrongly.
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
    local rotQueue = {}   -- rotation entries, rebuilt every tick

    -- =======================================================================
    -- PROC GLOW
    -- One OnUpdate drives every glowing icon.
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

    local function ClearUI()
        ClearGlowIcons()
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
        if elements.rotation then
            for i = #elements.rotation, 1, -1 do
                local slot = elements.rotation[i]
                if slot.frame then
                    slot.frame:Hide()
                    slot.frame:SetParent(nil)
                end
                elements.rotation[i] = nil
            end
            elements.rotation = nil
        end
    end

    -- =======================================================================
    -- ICON FACTORY
    -- =======================================================================
    -- Only the frame and border need resizing; everything else is anchored.
    local function IconSetSize(self, size)
        self.rtSize = size
        self:SetSize(size, size)
        if self.border then
            local borderScale = size / 36
            self.border:SetSize(64 * borderScale, 64 * borderScale)
        end
    end

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

        -- Text and border sit above the sweep so it never covers the timer.
        local overlay = CreateFrame("Frame", nil, f)
        overlay:SetAllPoints(f)
        overlay:SetFrameLevel(f:GetFrameLevel() + 2)

        local text = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER", overlay, "CENTER", 0, 0)
        text:SetTextColor(1, 1, 1)
        f.text = text

        -- Stack counter, bottom-right. Only abilities with showCount use it.
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

        -- Cooldown sweep (ElvUI nameplate style): a vertical bar whose dark
        -- shade descends from the top as the timer runs out. swipeLayers only
        -- sets the shade opacity; 3.3.5 has no color API for the native
        -- Cooldown widget.
        local layers = db.swipeLayers or 2
        if layers < 1 then layers = 1 end

        local sweep = CreateFrame("StatusBar", nil, f)
        sweep:SetAllPoints(f)
        sweep:SetFrameLevel(f:GetFrameLevel() + 1)
        sweep:SetOrientation("VERTICAL")
        sweep:SetMinMaxValues(0, 1)
        sweep:SetValue(1)
        sweep:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        sweep:SetStatusBarColor(0, 0, 0, 0) -- transparent: the icon shows through

        local shade = sweep:CreateTexture(nil, "BACKGROUND")
        shade:SetTexture(0, 0, 0, 1)
        shade:SetAlpha(math.min(0.85, 0.25 + 0.2 * layers))
        shade:SetPoint("TOPLEFT", sweep, "TOPLEFT", 0, 0)
        shade:SetPoint("BOTTOMRIGHT", sweep:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
        sweep.shade = shade

        -- A StatusBar does not animate on its own, so advance it every frame.
        sweep:SetScript("OnUpdate", function(self)
            local start, duration = self.startTime, self.duration
            if not start or not duration or duration <= 0 then return end
            local remaining = (start + duration) - GetTime()
            if remaining < 0 then remaining = 0 end
            self:SetValue(remaining)
        end)
        sweep:Hide()

        f.sweepFrames = { sweep }
        f.cooldownFrame = sweep

        f.StartGlow = IconStartGlow
        f.StopGlow = IconStopGlow
        f.SetIconSize = IconSetSize

        return f
    end

    -- The sweep OnUpdate reads these fields to drive the fill.
    local function SweepSet(frame, start, duration)
        local frames = frame.sweepFrames
        for i = 1, #frames do
            local sweep = frames[i]
            sweep.startTime = start
            sweep.duration = duration
            sweep:SetMinMaxValues(0, duration)
            sweep:SetValue(duration)
        end
    end

    local function SweepShow(frame)
        local frames = frame.sweepFrames
        for i = 1, #frames do frames[i]:Show() end
    end

    local function SweepHide(frame)
        local frames = frame.sweepFrames
        for i = 1, #frames do
            local sweep = frames[i]
            sweep.startTime, sweep.duration = nil, nil
            sweep:SetValue(1)
            sweep:Hide()
        end
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
        -- Height is provisional; BuildUI resizes the frame to fit its content.
        mainFrame:SetSize(rowWidth + 20, CONFIG.iconSize)
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
            if point then point, x, y = ToTopPoint(point, x, y, self:GetHeight()) end
            db.point = { point or "CENTER", x or 0, y or 0 }
        end)

        -- Optional warning bar; re-anchored under the content by BuildUI.
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

        -- Reserve the tallest ability size so the row never overlaps the
        -- sections below; the icons themselves are positioned dynamically.
        local abilityRowHeight = 0
        for _, data in ipairs(CONFIG.abilities) do
            local s = data.size or abilitySize
            if s > abilityRowHeight then abilityRowHeight = s end
        end
        if abilityRowHeight == 0 then abilityRowHeight = abilitySize end
        elements.abilityRowY = currentY
        elements.abilityRowHeight = abilityRowHeight
        currentY = currentY - abilityRowHeight - 5

        -- Rotation row (optional): the next spells to cast. The queue
        -- is re-sorted every tick by cooldown left; the config
        -- priority breaks ties.
        local rot = CONFIG.rotation
        if rot then
            local rotSize = rot.iconSize or CONFIG.abilityIconSize
            local rotSpacing = rot.spacing or spacing
            local rotCount = rot.icons or 5
            local totalWidth = (rotSize * rotCount) + (rotSpacing * (rotCount - 1))
            local startX = -(totalWidth / 2) + (rotSize / 2)

            -- Spell art and the client-side spell name never change
            -- at runtime: resolve both once. Matching by the name
            -- GetSpellInfo reports for the spell ID keeps the queue
            -- working on localized spellbooks, the same way
            -- RetRotation matches by ID.
            local function PrepareList(list)
                if list then
                    for _, entry in ipairs(list) do
                        if entry.spellID then
                            entry.rtName = GetSpellInfo(entry.spellID) or entry.name
                        else
                            entry.rtName = entry.name
                        end
                        -- Resolve the art by name first (the lookup the
                        -- cooldown row uses), then by spell ID.
                        local ok, tex = pcall(GetSpellTexture, entry.rtName)
                        if ok and tex and tex ~= "" then
                            entry.rtTexture = tex
                        else
                            entry.rtTexture = GetIconTexture(entry)
                        end
                    end
                end
            end
            PrepareList(rot.list)
            PrepareList(rot.aoeList)

            elements.rotation = {}
            for i = 1, rotCount do
                local icon = CreateIcon(mainFrame, rotSize)
                icon:SetPoint("TOP", mainFrame, "TOP",
                    startX + (i - 1) * (rotSize + rotSpacing), currentY)
                icon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                icon:Hide()
                elements.rotation[i] = { frame = icon }
            end

            currentY = currentY - rotSize - 5
        end

        -- Resource bar (optional)
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

        -- Secondary row: combo points or runes (optional)
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
                    -- Width is driven from UpdateUI.
                    fill:SetPoint("TOPLEFT", 1, -1)
                    fill:SetPoint("BOTTOMLEFT", 1, 1)
                    fill:SetTexture(1, 1, 1)
                    fill:SetWidth(0)

                    -- Recharge seconds.
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
    local function BuildUI()
        InvalidateSpellKnowledge()
        local signature = ComputeKnownSignature()
        if mainFrame and signature == lastBuildSignature then
            return
        end
        lastBuildSignature = signature

        ClearUI()

        local size = CONFIG.iconSize
        local spacing = CONFIG.spacing

        local currentY = BuildTopSection(0)

        -- Build every ability icon up front; they stay hidden until active.
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
        for _, data in ipairs(COMMON_ABILITIES) do BuildAbility(data) end

        local cdRows = BuildIconGrid(CONFIG.cooldowns, currentY, elements.cooldowns, CONFIG.maxCooldownsPerRow)
        if cdRows > 0 then
            currentY = currentY - cdRows * (size + spacing) - 5
        end

        if mainFrame.warn then
            mainFrame.warn:ClearAllPoints()
            mainFrame.warn:SetPoint("TOP", mainFrame, "TOP", 0, currentY)
            currentY = currentY - 16   -- the warning bar is 16 tall
        end

        -- Size the frame to what was actually laid out. The mouse region while
        -- unlocked is the frame, so a fixed tall frame left an invisible block
        -- over the action bars. Everything is anchored to the frame's top edge,
        -- so shrinking it never moves the icons.
        local contentHeight = -currentY
        if contentHeight < CONFIG.iconSize then contentHeight = CONFIG.iconSize end
        mainFrame:SetHeight(contentHeight)
    end

    -- =======================================================================
    -- UPDATE LOGIC
    -- =======================================================================
    -- Undead check for the rotation (Holy Wrath). UnitCreatureType is
    -- localized in 3.3.5a and there is no creature-type ID API, so the
    -- known strings for the major clients are matched; enUS is the
    -- reference.
    local UNDEAD_TYPES = {
        ["Undead"] = true,      -- enUS
        ["Untoter"] = true,     -- deDE
        ["Mort-vivant"] = true, -- frFR
        ["No-muerto"] = true,   -- esES
        ["No muerto"] = true,   -- esMX
        ["Нежить"] = true,      -- ruRU
        ["亡灵"] = true,         -- zhCN
        ["不死"] = true,         -- zhTW
        ["언데드"] = true       -- koKR
    }

    local function IsUndead(unit)
        return UNDEAD_TYPES[UnitCreatureType(unit) or ""] == true
    end

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
    -- Each unit is scanned once per refresh into reusable tables, then every
    -- tracked spell is a plain table lookup.
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

        -- Also indexed by spell ID, so an entry can match a specific rank.
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
                -- No duration (e.g. Stealth): always active, no clock.
                rem = PERMANENT_REMAINING
                auraStart = 0
            end
            local count = auraCount or 0
            -- The same spell can be on the target from several casters. Keep
            -- our own copy when we can.
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

    -- playerOnly: only match an aura the player cast.
    local function LookupAura(cache, spellName, spellID, playerOnly)
        -- Prefer the spell ID when the entry gives one.
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
        -- Buffs first, then debuffs.
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

    -- altAuras: other auras with the same effect from other classes.
    -- Primary aura first, then each alternate; first match wins.
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

        -- Cooldowns (GCD filtered)
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
                -- Some spells report a frozen cooldown (e.g. Raise Dead while
                -- the ghoul is up). Show the number, but only sweep while it
                -- is actually counting down.
                local prevRemaining = data.rtLastRemaining
                local ticking = (prevRemaining ~= nil) and (remaining < prevRemaining - 0.05)

                if ticking then
                    local newCooldown = (data.rtStart == nil)
                        or (remaining > prevRemaining + 0.2)
                        or (math.abs(duration - (data.rtDuration or 0)) > 0.25)
                    if newCooldown then
                        data.rtStart, data.rtDuration = start, duration
                        SweepSet(frame, start, duration)
                    end
                    if not data.rtCooldownShown then
                        data.rtCooldownShown = true
                        SweepShow(frame)
                    end
                elseif data.rtCooldownShown or data.rtStart ~= 0 then
                    data.rtCooldownShown = false
                    data.rtStart, data.rtDuration = 0, 0
                    SweepHide(frame)
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
                    SweepHide(frame)
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

        -- Rotation queue: the next spells to cast, Clash-style.
        -- Soonest ready first; the config priority breaks ties.
        local rotation = elements.rotation
        if rotation then
            local cfg = CONFIG.rotation

            -- AoE mode: the buff swaps the priority list.
            local list = cfg.list
            if cfg.aoeBuff and cfg.aoeList then
                if GetPlayerAura(cfg.aoeBuff.name, cfg.aoeBuff.spellID) then
                    list = cfg.aoeList
                end
            end

            -- Rebuild the queue from scratch every tick.
            for k in pairs(rotQueue) do rotQueue[k] = nil end
            local count = 0
            for i, entry in ipairs(list) do
                -- Match by the name the client itself reports for
                -- the spell ID, so localized and rank-suffixed
                -- spellbooks resolve the same way as RetRotation.
                local spellName = entry.rtName or entry.name
                -- RetRotation's inclusion test: GetSpellCooldown only
                -- returns data for spells the player can use, so no
                -- separate spellbook check is needed.
                local start, duration = GetSpellCooldown(spellName)
                if not start then
                    -- The client may report a different name for the
                    -- ID; fall back to the configured name.
                    spellName = entry.name
                    start, duration = GetSpellCooldown(spellName)
                end

                if start and duration then
                    -- "execute" entries only count in execute range.
                    local skip = false
                    if entry.execute then
                        local maxHealth = UnitHealthMax("target")
                        skip = not (UnitCanAttack("player", "target")
                            and maxHealth > 0
                            and (UnitHealth("target") / maxHealth) <= 0.2)
                    end
                    -- undeadOnly entries need an undead target.
                    if not skip and entry.undeadOnly and not IsUndead("target") then
                        skip = true
                    end

                    if not skip then
                        local cdLeft = 0
                        if duration > 0 then
                            cdLeft = (start + duration) - nowTime
                            if cdLeft < 0 then cdLeft = 0 end
                            -- GCD-scale cooldowns count as ready.
                            if cdLeft > 0 and cdLeft <= 2.0 and duration <= 2.0 then
                                cdLeft = 0
                            end
                        end

                        count = count + 1
                        local item = rotQueue[count]
                        if not item then
                            item = {}
                            rotQueue[count] = item
                        end
                        item.index = i
                        item.entry = entry
                        item.cdLeft = cdLeft
                        item.start = start
                        item.duration = duration
                        item.nomana = select(2, IsUsableSpell(spellName))
                    end
                end
            end

            table.sort(rotQueue, function(a, b)
                if math.abs(a.cdLeft - b.cdLeft) < 0.1 then
                    return a.index < b.index
                end
                return a.cdLeft < b.cdLeft
            end)

            local show = math.min(count, #rotation)
            for i = 1, #rotation do
                local slot = rotation[i]
                local frame = slot.frame
                local item = (i <= show) and rotQueue[i] or nil

                if item then
                    frame:Show()

                    -- Head of the queue: full alpha, the rest queue up dimmer.
                    local head = (i == 1)
                    local alpha = head and 1 or 0.6
                    if frame:GetAlpha() ~= alpha then frame:SetAlpha(alpha) end

                    if slot.rtTexture ~= item.entry.rtTexture then
                        slot.rtTexture = item.entry.rtTexture
                        frame.texture:SetTexture(item.entry.rtTexture)
                    end

                    local cdLeft = item.cdLeft
                    if cdLeft > 0 then
                        local text = FormatTime(cdLeft)
                        if slot.rtText ~= text then
                            slot.rtText = text
                            frame.text:SetText(text)
                        end
                        if slot.rtStart ~= item.start or slot.rtDuration ~= item.duration then
                            slot.rtStart, slot.rtDuration = item.start, item.duration
                            SweepSet(frame, item.start, item.duration)
                        end
                        if not slot.rtSweepShown then
                            slot.rtSweepShown = true
                            SweepShow(frame)
                        end
                    else
                        if slot.rtText ~= "" then
                            slot.rtText = ""
                            frame.text:SetText("")
                        end
                        if slot.rtSweepShown then
                            slot.rtSweepShown = false
                            slot.rtStart, slot.rtDuration = 0, 0
                            SweepHide(frame)
                        end
                    end

                    -- Tint: out of mana first, then on cooldown.
                    local tint = 0
                    if item.nomana then
                        tint = 1
                    elseif cdLeft > 0 then
                        tint = 2
                    end
                    if slot.rtTint ~= tint then
                        slot.rtTint = tint
                        if tint == 1 then
                            frame.texture:SetVertexColor(0.5, 0.5, 1.0)
                        elseif tint == 2 then
                            frame.texture:SetVertexColor(0.55, 0.55, 0.55)
                        else
                            frame.texture:SetVertexColor(1, 1, 1)
                        end
                    end

                    -- The head glows while it is ready to cast.
                    local shouldGlow = head and (cdLeft <= 0.1) and (cfg.glowNext ~= false)
                    if slot.rtGlow ~= shouldGlow then
                        slot.rtGlow = shouldGlow
                        if shouldGlow then
                            frame:StartGlow()
                        else
                            frame:StopGlow()
                        end
                    end
                else
                    frame:Hide()
                    if slot.rtSweepShown then
                        slot.rtSweepShown = false
                        slot.rtStart, slot.rtDuration = 0, 0
                        SweepHide(frame)
                    end
                    if slot.rtGlow then
                        slot.rtGlow = false
                        frame:StopGlow()
                    end
                    slot.rtTexture = nil
                end
            end
        end

        -- Abilities: active ones plus alwaysVisible reminders, centred
        do
            local abilitySize = CONFIG.abilityIconSize
            local spacing = CONFIG.spacing
            local count = 0

            -- Mutually-exclusive groups (e.g. curses). If one member is up,
            -- the others stay hidden even when alwaysVisible.
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

                -- alwaysVisible keeps its slot while down, drawn grey.
                if (active or data.alwaysVisible) and not suppressed then
                    count = count + 1
                    local entry = activeAbilities[count]
                    if not entry then
                        entry = {}
                        activeAbilities[count] = entry
                    end
                    entry.frame = data.frame
                    entry.index = i
                    -- Only an active aura takes its configured size.
                    entry.size = active and data.size or abilitySize
                    entry.active = active
                    entry.remaining = active and remaining or 0
                    entry.start = active and auraStart or 0
                    entry.duration = active and auraDuration or 0
                    entry.count = auraCount
                    entry.showCount = data.showCount
                else
                    data.frame:Hide()
                    if data.frame.sweepFrames then
                        SweepHide(data.frame)
                    end
                end
            end

            if count > 0 then
                -- Include each size so swapping between a sized active icon
                -- and a normal grayscale reminder triggers a relayout.
                local sigParts = {}
                for i = 1, count do
                    local e = activeAbilities[i]
                    sigParts[i] = e.index .. ":" .. (e.size or 0)
                end
                local signature = table.concat(sigParts, ",")
                local relayout = (signature ~= lastAbilitySignature)
                lastAbilitySignature = signature

                -- Centre the row by summing real widths; bigger icons grow upward.
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
                        if frame.rtSize ~= s then
                            frame:SetIconSize(s)
                        end
                        frame:ClearAllPoints()
                        frame:SetPoint("BOTTOM", mainFrame, "TOP", cursorX + s / 2, rowBottom)
                        cursorX = cursorX + s + spacing
                    end

                    frame:Show()
                    frame.border:Hide()

                    -- Active: colour + timer. Missing: grey, no timer or sweep.
                    if entry.active then
                        frame.texture:SetDesaturated(false)
                        frame.texture:SetVertexColor(1, 1, 1)
                    else
                        frame.texture:SetDesaturated(true)
                        frame.texture:SetVertexColor(0.55, 0.55, 0.55)
                    end

                    local text = (entry.active and entry.duration > 0) and FormatTime(entry.remaining) or ""
                    if frame.rtText ~= text then
                        frame.rtText = text
                        frame.text:SetText(text)
                    end

                    -- Stack count (showCount).
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

                    -- Sweep for the buff/debuff duration
                    if frame.sweepFrames then
                        if entry.active and entry.duration > 0 then
                            SweepShow(frame)
                            if frame.rtStart ~= entry.start or frame.rtDuration ~= entry.duration then
                                frame.rtStart, frame.rtDuration = entry.start, entry.duration
                                SweepSet(frame, entry.start, entry.duration)
                            end
                        else
                            SweepHide(frame)
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

        -- Secondary row (optional)
        local sec = CONFIG.secondary
        if sec and sec.type == "rune" then
            local runeColors = sec.colors
            local runeFallback = sec.fallbackType
            local runeOrder = sec.order
            local runeDim = sec.dim
            for i = 1, sec.count do
                local rune = elements.secondary[i]
                -- order maps the screen slot to a rune index, fixing the layout.
                local slot = runeOrder and runeOrder[i] or i
                if rune then
                    local start, duration, ready = GetRuneCooldown(slot)

                    -- Recharge seconds.
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
                    local found, remaining = GetPlayerAura(CONFIG.warning.name)
                    text = (found and remaining > 0) and "" or CONFIG.warning.text
                elseif CONFIG.warning.type == "auras" then
                    -- Name every missing upkeep buff; skip spells we don't know.
                    -- `family` groups mutually-exclusive buffs (seals, auras):
                    -- the family is only missing when none of its members is up.
                    local missing = ""
                    local familyOrder, familyState = {}, {}
                    for _, entry in ipairs(CONFIG.warning.auras) do
                        if IsSpellKnown(entry.name) then
                            local found, remaining = GetPlayerAura(entry.name, entry.spellID)
                            if entry.family then
                                local state = familyState[entry.family]
                                if not state then
                                    state = { found = false, text = entry.text or entry.family }
                                    familyState[entry.family] = state
                                    familyOrder[#familyOrder + 1] = state
                                end
                                if found and remaining > 0 then state.found = true end
                            elseif not (found and remaining > 0) then
                                missing = (missing ~= "") and (missing .. " + " .. entry.text) or entry.text
                            end
                        end
                    end
                    for i = 1, #familyOrder do
                        local state = familyOrder[i]
                        if not state.found then
                            missing = (missing ~= "") and (missing .. " + " .. state.text) or state.text
                        end
                    end
                    text = (missing ~= "") and ((CONFIG.warning.prefix or "MISSING: ") .. missing) or ""
                else
                    -- Poison. An empty hand needs no poison.
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
    -- EVENTS
    -- Everything is polled at 10 Hz, so aura/target events are not registered.
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
    -- =======================================================================
    -- UI scale, driven from the command line. Applied to mainFrame, so every
    -- icon, bar and warning under it scales together.
    local MIN_SCALE, MAX_SCALE = 0.5, 2.0
    local SCALE_STEP = 0.1

    -- Round to 2 decimals so repeated up/down does not drift.
    local function RoundScale(value)
        return math.floor(value * 100 + 0.5) / 100
    end

    -- Forgiving number parsing: take the first number in the text, so "1.5",
    -- "1,5" (comma decimal), "<1.5>" (the placeholder brackets) and
    -- "scale N 1.5" all resolve to the size the player meant.
    local function ParseScale(text)
        return tonumber((text:gsub(",", ".")):match("%-?%d*%.?%d+"))
    end

    local function ApplyScale(value)
        if value < MIN_SCALE then value = MIN_SCALE end
        if value > MAX_SCALE then value = MAX_SCALE end
        value = RoundScale(value)
        db.scale = value
        if mainFrame then mainFrame:SetScale(value) end
        print(string.format("%s: UI scale set to %.2f.", PREFIX, value))
    end

    local function HandleScale(argument)
        if argument == "" then
            print(string.format("%s: UI scale is %.2f (%.1f - %.1f). Use /tracker scale <n> | up | down.",
                PREFIX, db.scale or CONFIG.scale, MIN_SCALE, MAX_SCALE))
        elseif argument == "up" then
            ApplyScale((db.scale or 1) + SCALE_STEP)
        elseif argument == "down" then
            ApplyScale((db.scale or 1) - SCALE_STEP)
        else
            local value = ParseScale(argument)
            if value then
                ApplyScale(value)
            else
                print(string.format("%s: Usage: /tracker scale <%.1f-%.1f> | up | down", PREFIX, MIN_SCALE, MAX_SCALE))
            end
        end
    end

    local function HandleSlash(msg)
        msg = string.lower(msg or "")

        local command, argument = string.match(msg, "^%s*(%S+)%s*(.-)%s*$")
        command = command or ""
        argument = argument or ""

        if command == "lock" then
            db.locked = true
            if mainFrame and mainFrame.ApplyMouseState then mainFrame:ApplyMouseState() end
            print(PREFIX .. ": Locked. Click-through enabled.")
        elseif command == "unlock" then
            db.locked = false
            if mainFrame and mainFrame.ApplyMouseState then mainFrame:ApplyMouseState() end
            print(PREFIX .. ": Unlocked. Drag to move.")
        elseif command == "reset" then
            -- Same on-screen spot the old CENTER reset landed on, now TOP-based
            -- so the size no longer shifts it.
            local _, x, y = ToTopPoint("CENTER", 0, -100, LEGACY_FRAME_HEIGHT)
            db.point = { "TOP", x, y }
            mainFrame:ClearAllPoints()
            mainFrame:SetPoint("TOP", UIParent, "TOP", x, y)
            print(PREFIX .. ": Position reset.")
        elseif command == "scale" then
            HandleScale(argument)
        else
            print(PREFIX .. " Commands: /tracker lock | unlock | reset | scale <n|up|down>")
        end
    end

    self.slashHandler = HandleSlash

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
        self:InitModule(config)
    else
        -- LoadOnDemand module: load the one for this class.
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
