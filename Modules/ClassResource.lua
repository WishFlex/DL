local AddonName, ns = ...
local WF = ns.WF
local L = ns.L

local LSM = LibStub("LibSharedMedia-3.0", true)
local CR = CreateFrame("Frame")
WF.ClassResourceAPI = CR

local playerClass = select(2, UnitClass("player"))
local hasHealerSpec = (playerClass == "PALADIN" or playerClass == "PRIEST" or playerClass == "SHAMAN" or playerClass == "MONK" or playerClass == "DRUID" or playerClass == "EVOKER")

-- =========================================
-- [默认配置表]
-- =========================================
local barDefaults = {
    power = { independent = false, barXOffset = 0, barYOffset = 0, height = 14, textEnable = true, textFormat = "AUTO", textAnchor = "CENTER", font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = true, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=0, g=0.5, b=1}, useCustomTexture = false, texture = "WishFlex-g1", useCustomBgTexture = false, bgTexture = "WishFlex-g1", bgColor = {r=0, g=0, b=0, a=0.5} },
    class = { independent = false, barXOffset = 0, barYOffset = 0, height = 12, textEnable = true, textFormat = "AUTO", textAnchor = "CENTER", font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = true, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=1, g=0.96, b=0.41}, useCustomColors = {}, customColors = {}, useCustomTexture = false, texture = "WishFlex-g1", useCustomBgTexture = false, bgTexture = "WishFlex-g1", bgColor = {r=0, g=0, b=0, a=0.5} },
    mana = { independent = false, barXOffset = 0, barYOffset = 0, height = 10, textEnable = true, textFormat = "AUTO", textAnchor = "CENTER", font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = true, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=0, g=0.5, b=1}, useCustomTexture = false, texture = "WishFlex-g1", useCustomBgTexture = false, bgTexture = "WishFlex-g1", bgColor = {r=0, g=0, b=0, a=0.5} },
    auraBar = { independent = false, barXOffset = 0, barYOffset = 0, height = 14, spacing = 1, growth = "UP", useCustomTexture = false, texture = "WishFlex-g1", bgColor = {r=0.2, g=0.2, b=0.2, a=0.8}, font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, textPosition = "RIGHT", xOffset = -4, yOffset = 0, stackFont = "Expressway", stackFontSize = 14, stackOutline = "OUTLINE", stackColor = {r=1, g=1, b=1}, stackPosition = "LEFT", stackXOffset = 4, stackYOffset = 0 }
}

local defaults = {
    enable = true, alignWithCD = false, alignYOffset = 1, hideElvUIBars = true, widthOffset = 2, texture = "WishFlex-g1", specConfigs = {},
}

-- 常量与缓存
local DEFAULT_COLOR = {r=1, g=1, b=1}
local POWER_COLORS = { [0]={r=0,g=0.5,b=1}, [1]={r=1,g=0,b=0}, [2]={r=1,g=0.5,b=0.25}, [3]={r=1,g=1,b=0}, [4]={r=1,g=0.96,b=0.41}, [5]={r=0.8,g=0.1,b=0.2}, [7]={r=0.5,g=0.32,b=0.55}, [8]={r=0.3,g=0.52,b=0.9}, [9]={r=0.95,g=0.9,b=0.6}, [11]={r=0,g=0.5,b=1}, [12]={r=0.71,g=1,b=0.92}, [13]={r=0.4,g=0,b=0.8}, [16]={r=0.1,g=0.1,b=0.98}, [17]={r=0.79,g=0.26,b=0.99}, [18]={r=1,g=0.61,b=0}, [19]={r=0.4,g=0.8,b=1} }

local PLAYER_CLASS_COLOR = DEFAULT_COLOR
local cc_cache = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass]
if cc_cache then PLAYER_CLASS_COLOR = {r=cc_cache.r, g=cc_cache.g, b=cc_cache.b} end

CR.AuraBarPool = {}
CR.ActiveAuraBars = {}
CR.chargeDurCache = {}
CR.spellMaxChargeCache = {} 
local activeBuffFrames = {}
local targetAuraCache = {}
local playerAuraCache = {}
local BaseSpellCache = {}
CR.fastTrackedAuras = {}
CR.manualAuraTrackers = {}

-- =========================================
-- [数据库工具]
-- =========================================
local function DeepMerge(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            DeepMerge(target[k], v)
        else
            if target[k] == nil then target[k] = v end
        end
    end
end

local function GetDB()
    if not WF.db.classResource then WF.db.classResource = {} end
    DeepMerge(WF.db.classResource, defaults)
    return WF.db.classResource
end

local function GetSpellDB()
    if not WishFlexDB.global then WishFlexDB.global = {} end
    if type(WishFlexDB.global.spellDB) ~= "table" then WishFlexDB.global.spellDB = {} end
    return WishFlexDB.global.spellDB
end

-- =========================================
-- [文本安全转换与格式化]
-- =========================================
local function IsSecret(v) return type(v) == "number" and issecretvalue and issecretvalue(v) end
local function IsSafeValue(val) if val == nil then return false end if type(issecretvalue) == "function" and issecretvalue(val) then return false end return true end

local function SafeFormatNum(v)
    local num = tonumber(v) or 0
    if num >= 1e6 then return string.format("%.1fm", num / 1e6):gsub("%.0m", "m")
    elseif num >= 1e3 then return string.format("%.1fk", num / 1e3):gsub("%.0k", "k")
    else return string.format("%.0f", num) end
end

local function SafeSetDurationText(fontString, remaining)
    if not fontString then return end
    if not remaining then fontString:SetText(""); return end
    local ok, result = pcall(function()
        local num = tonumber(remaining)
        if num then
            if num >= 60 then return string.format("%dm", math.floor(num / 60))
            elseif num >= 10 then return string.format("%d", math.floor(num))
            else return string.format("%.1f", num) end
        end
        return remaining 
    end)
    if ok and result then fontString:SetText(result) else pcall(function() fontString:SetText(remaining) end) end
end

local function SetStackTextSafe(fs, count, isCharge)
    if not fs then return end
    pcall(function()
        if IsSecret(count) then fs:SetFormattedText("%d", count)
        else
            local c = tonumber(count) or 0
            if isCharge then fs:SetText(tostring(c)) else fs:SetText(c > 0 and tostring(c) or "") end
        end
    end)
end

local function UpdateCustomAuraText(bar, buffID, fallbackStacks, isCharge)
    -- 武僧酒池特殊处理保留
    if playerClass == "MONK" and (buffID == 124275 or buffID == 124274 or buffID == 124273 or buffID == 115308) then
        local staggerVal = UnitStagger("player") or 0
        if staggerVal > 0 then
            if IsSecret(staggerVal) then bar.stackText:SetFormattedText("%d", staggerVal)
            else bar.stackText:SetText(SafeFormatNum(staggerVal)) end
        else bar.stackText:SetText("") end
        return true
    end
    SetStackTextSafe(bar.stackText, fallbackStacks, isCharge)
    return false
end

local function FormatSafeText(bar, textCfg, current, maxVal, isTime, pType, showText, durObj)
    if not bar.text or not bar.timerText then return end
    local fontPath = (LSM and LSM:Fetch("font", textCfg.font)) or STANDARD_TEXT_FONT
    local fontSize = tonumber(textCfg.fontSize) or 12
    local fontOutline = textCfg.outline or "OUTLINE"
    
    if bar._lastFont ~= fontPath or bar._lastSize ~= fontSize or bar._lastOutline ~= fontOutline then
        bar.text:SetFont(fontPath, fontSize, fontOutline)
        bar.timerText:SetFont(fontPath, fontSize, fontOutline)
        bar._lastFont = fontPath; bar._lastSize = fontSize; bar._lastOutline = fontOutline
    end
    
    local c = textCfg.color or DEFAULT_COLOR
    if bar._lastColorR ~= c.r or bar._lastColorG ~= c.g or bar._lastColorB ~= c.b then
        bar.text:SetTextColor(c.r, c.g, c.b)
        bar.timerText:SetTextColor(c.r, c.g, c.b)
        bar._lastColorR = c.r; bar._lastColorG = c.g; bar._lastColorB = c.b
    end
    
    local mainAnchor = textCfg.textAnchor or "CENTER"
    local timerAnchor = textCfg.timerAnchor or "CENTER"
    local showMain = (textCfg.textEnable ~= false) and (textCfg.textFormat ~= "NONE") and showText
    local showTimer = (textCfg.timerEnable ~= false) and showText

    bar.text:ClearAllPoints(); bar.text:SetPoint(mainAnchor, bar.textFrame, mainAnchor, tonumber(textCfg.xOffset) or 0, tonumber(textCfg.yOffset) or 0); bar.text:SetJustifyH(mainAnchor)
    bar.timerText:ClearAllPoints(); bar.timerText:SetPoint(timerAnchor, bar.textFrame, timerAnchor, tonumber(textCfg.timerXOffset) or 0, tonumber(textCfg.timerYOffset) or 0); bar.timerText:SetJustifyH(timerAnchor)

    if durObj and type(current) == "number" then
        local remain = nil
        if type(durObj.GetRemainingDuration) == "function" then remain = durObj:GetRemainingDuration()
        elseif durObj.expirationTime then remain = durObj.expirationTime - GetTime() end
        if remain then
            if showMain then bar.text:SetFormattedText("%d", current); bar.text:Show() else bar.text:Hide() end
            if showTimer then SafeSetDurationText(bar.timerText, remain); bar.timerText:Show() else bar.timerText:Hide() end
            return
        end
    end

    bar.timerText:Hide()
    if not showMain then bar.text:Hide() return end
    bar.text:Show()

    local formatMode = textCfg.textFormat
    if formatMode == "AUTO" then if pType == 0 then formatMode = "PERCENT" else formatMode = "ABSOLUTE" end end

    if isTime then SafeSetDurationText(bar.text, current)
    elseif pType == 0 and formatMode == "PERCENT" then
        local scale = (_G.CurveConstants and _G.CurveConstants.ScaleTo100) or 100
        local perc = UnitPowerPercent("player", pType, false, scale)
        if IsSecret(perc) then bar.text:SetFormattedText("%d", perc) else bar.text:SetFormattedText("%d", tonumber(perc) or 0) end
    elseif formatMode == "PERCENT" then
        if pType then
            local perc = UnitPowerPercent("player", pType, false)
            if IsSecret(perc) then bar.text:SetFormattedText("%d", perc) else bar.text:SetFormattedText("%d", tonumber(perc) or 0) end
        else
            if IsSecret(current) or IsSecret(maxVal) then bar.text:SetFormattedText("%d", current)
            else
                local cVal = tonumber(current) or 0; local mVal = tonumber(maxVal) or 1; if mVal <= 0 then mVal = 1 end
                bar.text:SetFormattedText("%d", math.floor((cVal / mVal) * 100 + 0.5))
            end
        end
    elseif formatMode == "BOTH" then
        if IsSecret(current) or IsSecret(maxVal) then bar.text:SetFormattedText("%d / %d", current, maxVal)
        else bar.text:SetText(SafeFormatNum(current) .. " / " .. SafeFormatNum(maxVal)) end
    else
        if IsSecret(current) then bar.text:SetFormattedText("%d", current) else bar.text:SetText(SafeFormatNum(current)) end
    end
end

local function UpdateBarValueSafe(sb, rawCurr, rawMax)
    if IsSecret(rawMax) or IsSecret(rawCurr) then
        sb:SetMinMaxValues(0, rawMax); sb:SetValue(rawCurr); sb._targetValue = nil; sb._currentValue = nil
        return
    end
    local currentMax = select(2, sb:GetMinMaxValues())
    if IsSecret(currentMax) or type(currentMax) ~= "number" or currentMax ~= rawMax then
        sb:SetMinMaxValues(0, rawMax); sb._currentValue = rawCurr; sb._targetValue = rawCurr; sb:SetValue(rawCurr)
    else sb._targetValue = rawCurr end
end

-- =========================================
-- [环境与上下文读取]
-- =========================================
local function GetCurrentContextID()
    if playerClass == "DRUID" then
        local formID = GetShapeshiftFormID()
        if formID == 1 then return 1001 elseif formID == 5 then return 1002 elseif formID == 31 then return 1003 elseif formID == 3 or formID == 4 or formID == 27 then return 1004 else return 1000 end
    else
        local specIndex = GetSpecialization()
        return specIndex and GetSpecializationInfo(specIndex) or 0
    end
end

local function GetCurrentSpecConfig(ctxId)
    local db = GetDB()
    ctxId = ctxId or GetCurrentContextID()
    if not db.specConfigs then db.specConfigs = {} end
    if type(db.specConfigs[ctxId]) ~= "table" then db.specConfigs[ctxId] = {} end
    local cfg = db.specConfigs[ctxId]
    
    if cfg.width == nil then cfg.width = db.width or 250 end
    if cfg.yOffset == nil then cfg.yOffset = db.yOffset or 1 end
    if cfg.showPower == nil then cfg.showPower = true end
    if cfg.showClass == nil then cfg.showClass = true end
    if cfg.showMana == nil then cfg.showMana = false end
    if cfg.showAuraBar == nil then cfg.showAuraBar = true end
    if cfg.textPower == nil then cfg.textPower = true end
    if cfg.textClass == nil then cfg.textClass = true end
    if cfg.textMana == nil then cfg.textMana = true end
    if cfg.textAuraTimer == nil then cfg.textAuraTimer = true end
    if cfg.textAuraStack == nil then cfg.textAuraStack = true end
    
    if type(cfg.power) ~= "table" then cfg.power = {} end
    DeepMerge(cfg.power, barDefaults.power)
    if type(cfg.power.thresholdLines) ~= "table" then
        cfg.power.thresholdLines = {
            {enable = false, value = 50, thickness = 1, color = {r=1, g=1, b=1, a=1}},
            {enable = false, value = 100, thickness = 1, color = {r=1, g=1, b=1, a=1}},
        }
    end
    if type(cfg.class) ~= "table" then cfg.class = {} end
    DeepMerge(cfg.class, barDefaults.class)
    if type(cfg.mana) ~= "table" then cfg.mana = {} end
    DeepMerge(cfg.mana, barDefaults.mana)
    if type(cfg.auraBar) ~= "table" then cfg.auraBar = {} end
    DeepMerge(cfg.auraBar, barDefaults.auraBar)

    return cfg
end

local function GetTargetWidth(cfg)
    local db = GetDB()
    if db.alignWithCD and WF.db.cooldownCustom and WF.db.cooldownCustom.Essential then
        local cdDB = WF.db.cooldownCustom.Essential
        local maxPerRow = tonumber(cdDB.maxPerRow) or 7
        local w = tonumber(cdDB.row1Width) or tonumber(cdDB.width) or 45
        local gap = tonumber(cdDB.iconGap) or 2
        return (maxPerRow * w) + ((maxPerRow - 1) * gap) + (tonumber(db.widthOffset) or 2)
    end
    return tonumber(cfg.width) or 250
end

local function GetSafeColor(cfg, defColor, isClassBar)
    if cfg then
        if isClassBar then
            if type(cfg.useCustomColors) == "table" and cfg.useCustomColors[playerClass] then
                local cc = type(cfg.customColors) == "table" and cfg.customColors[playerClass]
                if cc and type(cc.r) == "number" then return cc end
            end
        elseif cfg.useCustomColor and type(cfg.customColor) == "table" and type(cfg.customColor.r) == "number" then
            return cfg.customColor
        end
    end
    if type(defColor) == "table" and type(defColor.r) == "number" then return defColor end
    return DEFAULT_COLOR
end

local function GetPowerColor(pType) return POWER_COLORS[pType] or DEFAULT_COLOR end

-- =========================================
-- [游戏数据拉取 (完整职业适配)]
-- =========================================
local function GetClassResourceData()
    local spec = GetSpecializationInfo(GetSpecialization() or 1)
    local pType = UnitPowerType("player")
    local classColor = PLAYER_CLASS_COLOR
    
    if playerClass == "ROGUE" then return UnitPower("player", 4), UnitPowerMax("player", 4), classColor, true
    elseif playerClass == "PALADIN" then return UnitPower("player", 9), 5, classColor, true
    elseif playerClass == "WARLOCK" then 
        local maxTrue = 50; local currTrue = 0; local maxShards = 5; local curr = 0
        pcall(function()
            maxTrue = UnitPowerMax("player", 7, true); currTrue = UnitPower("player", 7, true); maxShards = UnitPowerMax("player", 7); curr = UnitPower("player", 7)
            if maxTrue and maxTrue > 0 and currTrue and maxShards then curr = (currTrue / maxTrue) * maxShards end
        end)
        return curr, maxShards, classColor, true
    elseif playerClass == "EVOKER" then 
        local maxEssence = 6; local curr = 0
        pcall(function()
            maxEssence = UnitPowerMax("player", 19) or 6; if type(maxEssence) ~= "number" or IsSecret(maxEssence) then maxEssence = 6 end
            curr = UnitPower("player", 19) or 0; if type(curr) ~= "number" or IsSecret(curr) then curr = 0 end
        end)
        if not CR.evokerEssence then CR.evokerEssence = { count = curr, partial = 0, lastTick = GetTime() } end
        local now = GetTime(); local elapsed = now - CR.evokerEssence.lastTick; CR.evokerEssence.lastTick = now
        if curr > CR.evokerEssence.count then CR.evokerEssence.partial = 0 end
        CR.evokerEssence.count = curr
        if curr < maxEssence then
            local activeRegen = 0.2 
            pcall(function() if GetPowerRegenForPowerType then local _, active = GetPowerRegenForPowerType(19); if type(active) == "number" and active > 0 then activeRegen = active end end end)
            CR.evokerEssence.partial = CR.evokerEssence.partial + (activeRegen * elapsed)
            if CR.evokerEssence.partial >= 1 then CR.evokerEssence.partial = 0.99 end
        else CR.evokerEssence.partial = 0 end
        return curr + CR.evokerEssence.partial, maxEssence, classColor, true
    elseif playerClass == "DEATHKNIGHT" then 
        local readyRunes = 0; local highestPartial = 0; local maxRunes = 6
        pcall(function()
            maxRunes = UnitPowerMax("player", 5) or 6; if type(maxRunes) ~= "number" or IsSecret(maxRunes) then maxRunes = 6 end
            for i = 1, maxRunes do
                local start, duration, runeReady = GetRuneCooldown(i)
                if runeReady then readyRunes = readyRunes + 1
                else if start and duration and duration > 0 then local partial = math.max(0, math.min(0.99, (GetTime() - start) / duration)); if partial > highestPartial then highestPartial = partial end end end
            end
        end)
        return readyRunes + highestPartial, maxRunes, classColor, true
    elseif playerClass == "MAGE" and spec == 62 then return UnitPower("player", 16), 4, classColor, true
    elseif playerClass == "MONK" and spec == 269 then return UnitPower("player", 12), UnitPowerMax("player", 12), classColor, true
    elseif playerClass == "DRUID" and pType == 3 then return UnitPower("player", 4), 5, classColor, true
    elseif playerClass == "SHAMAN" and spec == 263 then
        local apps = 0; if C_UnitAuras.GetPlayerAuraBySpellID then local aura = C_UnitAuras.GetPlayerAuraBySpellID(344179); if aura then apps = aura.applications or 1 end end
        return apps, 10, classColor, true
    elseif playerClass == "HUNTER" and spec == 255 then
        local apps = 0; if C_UnitAuras.GetPlayerAuraBySpellID then local aura = C_UnitAuras.GetPlayerAuraBySpellID(260286); if aura then apps = aura.applications or 1 end end
        return apps, 3, classColor, true
    elseif playerClass == "WARRIOR" and spec == 72 then
        local apps = 0; if C_UnitAuras.GetPlayerAuraBySpellID then local aura = C_UnitAuras.GetPlayerAuraBySpellID(85739) or C_UnitAuras.GetPlayerAuraBySpellID(322166); if aura then apps = aura.applications or 1 end end
        return apps, 4, classColor, true
    end
    return 0, 0, DEFAULT_COLOR, false
end

-- =========================================
-- [Aura (增益与冷却) 分析与缓存]
-- =========================================
local function GetBaseSpellFast(spellID)
    if not IsSafeValue(spellID) then return nil end
    if BaseSpellCache[spellID] == nil then
        local base = spellID
        pcall(function() if C_Spell and C_Spell.GetBaseSpell then base = C_Spell.GetBaseSpell(spellID) or spellID end end)
        BaseSpellCache[spellID] = base
    end
    return BaseSpellCache[spellID]
end

local function MatchesSpellID(info, targetID)
    if not info then return false end
    if IsSafeValue(info.spellID) and (info.spellID == targetID or info.overrideSpellID == targetID) then return true end
    if info.linkedSpellIDs then for i=1, #info.linkedSpellIDs do if IsSafeValue(info.linkedSpellIDs[i]) and info.linkedSpellIDs[i] == targetID then return true end end end
    return GetBaseSpellFast(info.spellID) == targetID
end

local function IsValidActiveAura(aura)
    if type(aura) ~= "table" then return false end
    return aura.auraInstanceID ~= nil
end

local function GetChargeData(spellID, maxFallback, color)
    local chargeInfo = C_Spell.GetSpellCharges(spellID)
    if not chargeInfo then return 0, maxFallback, color, false, maxFallback, true, 0, nil end
    local rawCur = chargeInfo.currentCharges or 0
    local maxC = chargeInfo.maxCharges
    if IsSecret(maxC) or type(maxC) ~= "number" then maxC = maxFallback end
    local durObj = nil
    pcall(function() durObj = C_Spell.GetSpellChargeDuration(spellID) end)
    return rawCur, maxC, color, false, maxC, true, rawCur, durObj
end

function CR:BuildAuraCache()
    wipe(CR.fastTrackedAuras)
    local dbSpells = GetSpellDB()
    local currentSpecID = 0
    pcall(function() currentSpecID = GetSpecializationInfo(GetSpecialization()) or 0 end)
    
    for k, spellData in pairs(dbSpells) do
        local v = spellData.auraBar
        if v and type(v) == "table" and (not spellData.class or spellData.class == "ALL" or spellData.class == playerClass) and v.enable ~= false then
            local sSpec = spellData.spec or 0
            if sSpec == 0 or sSpec == currentSpecID then
                local sid = tonumber(k); local bid = spellData.buffID or sid
                if sid then CR.fastTrackedAuras[sid] = true end
                if bid then CR.fastTrackedAuras[bid] = true end
            end
        end
    end
end

-- =========================================
-- [UI 绘制与布局]
-- =========================================
function CR:CreateBarContainer(name, parent)
    local bar = CreateFrame("Frame", name, parent, "BackdropTemplate")
    bar:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
    bar:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    bar:SetBackdropBorderColor(0, 0, 0, 1)

    local sb = CreateFrame("StatusBar", nil, bar)
    sb:SetPoint("TOPLEFT", 1, -1)
    sb:SetPoint("BOTTOMRIGHT", -1, 1)
    bar.statusBar = sb
    
    local bg = sb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    sb.bg = bg

    local gridFrame = CreateFrame("Frame", nil, bar)
    gridFrame:SetAllPoints(bar); gridFrame:SetFrameLevel(bar:GetFrameLevel() + 5)
    bar.gridFrame = gridFrame

    local textFrame = CreateFrame("Frame", nil, bar)
    textFrame:SetAllPoints(bar); textFrame:SetFrameLevel(bar:GetFrameLevel() + 10)
    bar.textFrame = textFrame
    bar.text = textFrame:CreateFontString(nil, "OVERLAY") 
    bar.timerText = textFrame:CreateFontString(nil, "OVERLAY") 
    return bar
end

function CR:UpdateDividers(bar, maxVal)
    bar.dividers = bar.dividers or {}
    local numMax = (IsSecret(maxVal) and 1) or (tonumber(maxVal) or 1)
    if numMax <= 0 then numMax = 1 end; if numMax > 20 then numMax = 20 end 
    local width = bar:GetWidth() or 250
    if bar._lastDividerMax == numMax and bar._lastDividerWidth == width then return end
    bar._lastDividerMax = numMax; bar._lastDividerWidth = width
    local numDividers = numMax > 1 and (numMax - 1) or 0
    local segWidth = width / numMax
    local targetFrame = bar.gridFrame or bar.textFrame or bar
    
    for i = 1, numDividers do
        if not bar.dividers[i] then
            local tex = targetFrame:CreateTexture(nil, "OVERLAY", nil, 7)
            tex:SetColorTexture(0, 0, 0, 1); tex:SetWidth(1); bar.dividers[i] = tex
        end
        bar.dividers[i]:ClearAllPoints()
        bar.dividers[i]:SetPoint("TOPLEFT", targetFrame, "TOPLEFT", segWidth * i, 0)
        bar.dividers[i]:SetPoint("BOTTOMLEFT", targetFrame, "BOTTOMLEFT", segWidth * i, 0)
        bar.dividers[i]:Show()
    end
    for i = numDividers + 1, #bar.dividers do if bar.dividers[i] then bar.dividers[i]:Hide() end end
end

local function SyncAuraBarVisuals(bar, auraCfg)
    if not auraCfg then return end
    if not bar.durationText then
        if bar.cd.timer and bar.cd.timer.text then bar.durationText = bar.cd.timer.text
        else for _, region in pairs({bar.cd:GetRegions()}) do if region:IsObjectType("FontString") then bar.durationText = region; break end end end
    end
    if bar.durationText then
        local fontPath = (LSM and LSM:Fetch('font', auraCfg.font)) or STANDARD_TEXT_FONT
        if bar.lastFont ~= fontPath or bar.lastSize ~= auraCfg.fontSize or bar.lastOutline ~= auraCfg.outline then
            bar.durationText:SetFont(fontPath, auraCfg.fontSize, auraCfg.outline)
            bar.lastFont, bar.lastSize, bar.lastOutline = fontPath, auraCfg.fontSize, auraCfg.outline
        end
        local tc = auraCfg.color or {r=1, g=1, b=1, a=1}
        bar.durationText:SetTextColor(tc.r, tc.g, tc.b, tc.a)
        local pos = auraCfg.textPosition or "RIGHT"; local x, y = auraCfg.xOffset or -4, auraCfg.yOffset or 0
        if bar._lastDurPos ~= pos or bar._lastDurX ~= x or bar._lastDurY ~= y then
            bar.durationText:ClearAllPoints(); bar.durationText:SetPoint(pos, bar, pos, x, y); bar.durationText:SetJustifyH(pos)
            bar._lastDurPos, bar._lastDurX, bar._lastDurY = pos, x, y
        end
    end
    
    local sFontPath = (LSM and LSM:Fetch('font', auraCfg.stackFont or "Expressway")) or STANDARD_TEXT_FONT
    local sSize = auraCfg.stackFontSize or 14; local sOutline = auraCfg.stackOutline or "OUTLINE"
    if bar.sLastFont ~= sFontPath or bar.sLastSize ~= sSize or bar.sLastOutline ~= sOutline then
        bar.stackText:SetFont(sFontPath, sSize, sOutline)
        bar.sLastFont, bar.sLastSize, bar.sLastOutline = sFontPath, sSize, sOutline
    end
    local sc = auraCfg.stackColor or {r=1, g=1, b=1, a=1}
    bar.stackText:SetTextColor(sc.r, sc.g, sc.b, sc.a)
    local sPos = auraCfg.stackPosition or "LEFT"; local sx, sy = auraCfg.stackXOffset or 4, auraCfg.stackYOffset or 0
    if bar._lastStackPos ~= sPos or bar._lastStackX ~= sx or bar._lastStackY ~= sy then
        bar.stackText:ClearAllPoints(); bar.stackText:SetPoint(sPos, bar, sPos, sx, sy); bar.stackText:SetJustifyH(sPos)
        bar._lastStackPos, bar._lastStackX, bar._lastStackY = sPos, sx, sy
    end
end

function CR:GetOrCreateAuraBar(index, specCfg)
    if not CR.AuraBarPool[index] then
        local bar = CreateFrame("Frame", "WishFlexAuraBar"..index, self.auraAnchor, "BackdropTemplate")
        bar:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
        bar:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        bar:SetBackdropBorderColor(0, 0, 0, 1)

        local statusBar = CreateFrame("StatusBar", nil, bar)
        statusBar:SetPoint("TOPLEFT", 1, -1); statusBar:SetPoint("BOTTOMRIGHT", -1, 1)
        statusBar:SetFrameLevel(bar:GetFrameLevel() + 1); bar.statusBar = statusBar
        
        local bg = statusBar:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bar.statusBar.bg = bg
        local gridFrame = CreateFrame("Frame", nil, bar); gridFrame:SetAllPoints(bar); gridFrame:SetFrameLevel(bar:GetFrameLevel() + 10); bar.gridFrame = gridFrame
        
        local cd = CreateFrame("Cooldown", nil, statusBar, "CooldownFrameTemplate")
        cd:SetAllPoints(); cd:SetDrawSwipe(false); cd:SetDrawEdge(false); cd:SetDrawBling(false); cd:SetHideCountdownNumbers(false)
        cd.noCooldownOverride = true; cd.noOCC = true; cd:SetFrameLevel(bar:GetFrameLevel() + 20); bar.cd = cd
        
        local textFrame = CreateFrame("Frame", nil, bar); textFrame:SetAllPoints(bar); textFrame:SetFrameLevel(bar:GetFrameLevel() + 30); bar.auraTextFrame = textFrame
        if not bar.stackText then bar.stackText = textFrame:CreateFontString(nil, "OVERLAY") end
        
        bar.lastAuraId = nil; bar._lastDurObj = nil
        CR.AuraBarPool[index] = bar
    end
    local bar = CR.AuraBarPool[index]
    
    if specCfg and specCfg.auraBar then
        bar:SetSize(GetTargetWidth(specCfg), specCfg.auraBar.height or 14)
        local texName = (specCfg.auraBar.useCustomTexture and specCfg.auraBar.texture and specCfg.auraBar.texture ~= "") and specCfg.auraBar.texture or GetDB().texture or "WishFlex-g1"
        local tex = (LSM and LSM:Fetch("statusbar", texName)) or "Interface\\TargetingFrame\\UI-StatusBar"
        bar.statusBar:SetStatusBarTexture(tex)
        bar.statusBar.bg:SetTexture(tex)
        SyncAuraBarVisuals(bar, specCfg.auraBar)
    end
    return bar
end

-- =========================================
-- [100% 完整无删减：AuraBar 核心追踪引擎]
-- =========================================
local auraUpdatePending = false
local function RequestUpdateAuraBars()
    if auraUpdatePending then return end
    auraUpdatePending = true
    C_Timer.After(InCombatLockdown() and 0.05 or 0.2, function() 
        auraUpdatePending = false
        CR:UpdateAuraBars() 
    end)
end

function CR:UpdateAuraBars()
    local db = GetDB()
    local specCfg = self.cachedSpecCfg or GetCurrentSpecConfig(GetCurrentContextID())
    local auraCfg = specCfg.auraBar
    if not auraCfg or not specCfg.showAuraBar then 
        for _, bar in ipairs(CR.AuraBarPool) do bar:Hide() end
        return 
    end
    
    local showAuraTimer = specCfg.textAuraTimer
    local showAuraStack = specCfg.textAuraStack
    
    wipe(activeBuffFrames); wipe(targetAuraCache); wipe(playerAuraCache)

    for _, viewer in ipairs({_G.BuffIconCooldownViewer, _G.BuffBarCooldownViewer}) do
        if viewer and viewer.itemFramePool then
            for f in viewer.itemFramePool:EnumerateActive() do if f.cooldownInfo then activeBuffFrames[#activeBuffFrames+1] = f end end
        end
    end

    local targetScanned = false; local playerScanned = false
    wipe(CR.ActiveAuraBars); wipe(CR.chargeDurCache)
    local activeCount = 0
    
    local currentSpecID = 0
    pcall(function() currentSpecID = GetSpecializationInfo(GetSpecialization()) or 0 end)

    for spellIDStr, spellData in pairs(GetSpellDB()) do
        local v = spellData.auraBar
        if v and (not spellData.class or spellData.class == "ALL" or spellData.class == playerClass) then
            local sSpec = spellData.spec or 0
            if sSpec == 0 or sSpec == currentSpecID then
                local spellID = tonumber(spellIDStr)
                local buffID = spellData.buffID or tonumber(spellID)
                local vis = v.visibility or (v.alwaysShow and 2 or 1)
                local forceShow = (vis == 2) or (vis == 3 and InCombatLockdown())
                local auraActive, auraInstanceID, unit = false, nil, "player"
                local isFakeBuff, fStart, fDur = false, 0, 0
                local auraData = nil; local currentDurObj = nil
                
                local trackType = v.trackType or "aura"
                local mode = v.mode or "time"
                local isCharge = (trackType == "charge")
                local isConsume = (trackType == "consume")
                if isCharge then mode = "stack" end 
                
                if isCharge then
                    local cInfo = C_Spell.GetSpellCharges(buffID)
                    if cInfo and type(cInfo.maxCharges) == "number" and not IsSecret(cInfo.maxCharges) then CR.spellMaxChargeCache[buffID] = cInfo.maxCharges end
                    local autoMax = CR.spellMaxChargeCache[buffID] or 2
                    if v.overrideMax then autoMax = v.maxStacks or 2 end
                    local exactCur, maxC, _, _, _, _, _, durObj = GetChargeData(buffID, autoMax, v.color)
                    
                    local hasChargeSafe = false
                    if IsSecret(exactCur) then hasChargeSafe = true else hasChargeSafe = (type(exactCur) == "number" and exactCur > 0) end
                    
                    if hasChargeSafe or durObj or forceShow then
                        auraActive = true
                        auraData = { applications = exactCur, maxCharges = maxC }
                        if durObj then auraInstanceID = tostring(buffID) .. "_charge"; currentDurObj = durObj end
                    end
                else
                    if (v.duration or 0) > 0 then
                        local tracker = CR.manualAuraTrackers[buffID]
                        if tracker and GetTime() < (tracker.start + tracker.dur) then auraActive = true; fStart, fDur = tracker.start, tracker.dur; isFakeBuff = true
                        else CR.manualAuraTrackers[buffID] = nil end
                    else
                        local buffFrame = nil
                        for i = 1, #activeBuffFrames do if MatchesSpellID(activeBuffFrames[i].cooldownInfo, buffID) then buffFrame = activeBuffFrames[i]; break end end
                        if buffFrame then
                            local tempID = buffFrame.auraInstanceID; local tempUnit = buffFrame.auraDataUnit or "player"
                            if IsSafeValue(tempID) then
                                pcall(function() auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(tempUnit, tempID) end)
                                if auraData and IsValidActiveAura(auraData) then auraActive = true; auraInstanceID = tempID; unit = tempUnit end
                            end
                        end
                        if not auraActive then
                            pcall(function() auraData = C_UnitAuras.GetPlayerAuraBySpellID(buffID) end)
                            if auraData and IsValidActiveAura(auraData) then auraActive = true; auraInstanceID = auraData.auraInstanceID; unit = "player"
                            else
                                if not playerScanned then
                                    playerScanned = true
                                    for _, filter in ipairs({"HELPFUL", "HARMFUL"}) do
                                        for i = 1, 40 do
                                            local aura; pcall(function() aura = C_UnitAuras.GetAuraDataByIndex("player", i, filter) end)
                                            if aura then
                                                if IsSafeValue(aura.spellId) then playerAuraCache[aura.spellId] = aura; local baseID = GetBaseSpellFast(aura.spellId); if baseID and baseID ~= aura.spellId then playerAuraCache[baseID] = aura end end
                                            else break end
                                        end
                                    end
                                end
                                local cachedAura = playerAuraCache[buffID]
                                if cachedAura and IsValidActiveAura(cachedAura) then auraData = cachedAura; auraActive = true; auraInstanceID = cachedAura.auraInstanceID; unit = "player"
                                elseif UnitExists("target") then
                                    if not targetScanned then
                                        targetScanned = true
                                        for _, filter in ipairs({"HELPFUL", "HARMFUL"}) do
                                            for i = 1, 40 do
                                                local aura; pcall(function() aura = C_UnitAuras.GetAuraDataByIndex("target", i, filter) end)
                                                if aura then
                                                    if IsSafeValue(aura.spellId) then targetAuraCache[aura.spellId] = aura; local baseID = GetBaseSpellFast(aura.spellId); if baseID and baseID ~= aura.spellId then targetAuraCache[baseID] = aura end end
                                                else break end
                                            end
                                        end
                                    end
                                    local tCached = targetAuraCache[buffID]
                                    if tCached and IsValidActiveAura(tCached) then auraData = tCached; auraActive = true; auraInstanceID = tCached.auraInstanceID; unit = "target" end
                                end
                            end
                        end
                    end
                end

                if auraActive or forceShow then
                    activeCount = activeCount + 1
                    local bar = CR:GetOrCreateAuraBar(activeCount, specCfg)
                    bar.mode = mode
                    bar.buffID = buffID 
                    
                    local targetW = GetTargetWidth(specCfg)
                    local targetH = auraCfg.height or 14
                    if v.useCustomSize then
                        targetW = v.customWidth or targetW
                        targetH = v.customHeight or targetH
                    end
                    bar:SetSize(targetW, targetH)
                    bar.isIndependent = v.useIndependentPosition
                    bar.isHorizontalSplit = v.useHorizontalSplit 
                    bar.customX = v.customXOffset or 0
                    bar.customY = v.customYOffset or 0
                    
                    if showAuraTimer then
                        bar.cd:SetHideCountdownNumbers(false)
                        if bar.durationText then bar.durationText:SetAlpha(1) end
                    else
                        bar.cd:SetHideCountdownNumbers(true)
                        if bar.durationText then bar.durationText:SetAlpha(0) end
                    end
                    if showAuraStack then bar.stackText:SetAlpha(1) else bar.stackText:SetAlpha(0) end
                    
                    if auraActive then bar:SetAlpha(1) else bar:SetAlpha(v.inactiveAlpha or 1) end
                    
                    local useThreshold = v.useThresholdColor
                    local thresholdStacks = v.thresholdStacks or 3
                    local thresholdColor = v.thresholdColor or {r=1,g=0,b=0,a=1}
                    
                    local st = (auraData and auraData.applications) or 0
                    if isCharge then st = (auraData and auraData.applications) or exactCur or 0 end
                    
                    local c = v.color or {r=0, g=0.8, b=1, a=1}
                    if useThreshold then pcall(function() if st >= thresholdStacks then c = thresholdColor end end) end
                    
                    bar.statusBar:SetStatusBarColor(c.r, c.g, c.b, c.a)
                    local bgC = v.bgColor or auraCfg.bgColor or {r=0.2, g=0.2, b=0.2, a=0.8}
                    bar.statusBar.bg:SetVertexColor(bgC.r, bgC.g, bgC.b, bgC.a)
                    bar.statusBar:SetReverseFill(v.reverseFill or false)

                    if bar.durationText then
                        local pos, x, y
                        if v.useCustomTextPosition then
                            pos = v.customTextPosition or "CENTER"
                            x = v.customTextXOffset or 0
                            y = v.customTextYOffset or 0
                        else
                            pos = auraCfg.textPosition or "RIGHT"
                            x = auraCfg.xOffset or -4
                            y = auraCfg.yOffset or 0
                        end
                        bar.durationText:ClearAllPoints()
                        bar.durationText:SetPoint(pos, bar, pos, x, y)
                        bar.durationText:SetJustifyH(pos)
                    end
                    
                    if bar.stackText then
                        local sPos, sX, sY
                        if v.useCustomTextPosition then
                            sPos = v.customStackPosition or "LEFT"
                            sX = v.customStackXOffset or 0
                            sY = v.customStackYOffset or 0
                        else
                            sPos = auraCfg.stackPosition or "LEFT"
                            sX = auraCfg.stackXOffset or 4
                            sY = auraCfg.stackYOffset or 0
                        end
                        bar.stackText:ClearAllPoints()
                        bar.stackText:SetPoint(sPos, bar, sPos, sX, sY)
                        bar.stackText:SetJustifyH(sPos)
                    end

                    pcall(function()
                        bar.cd:ClearAllPoints()
                        bar.cd:SetAllPoints(bar.statusBar)
                    end)
                    
                    if not auraActive then
                        if isCharge then
                            local maxS = CR.spellMaxChargeCache[buffID] or (auraData and auraData.maxCharges) or 2
                            if v.overrideMax then maxS = v.maxStacks or 2 end
                            if maxS <= 0 then maxS = 1 end
                            UpdateBarValueSafe(bar.statusBar, 0, maxS)
                            CR:UpdateDividers(bar, maxS)
                        elseif isConsume then
                            local maxS = v.maxStacks or 8
                            if maxS <= 0 then maxS = 1 end
                            UpdateBarValueSafe(bar.statusBar, 0, maxS)
                            CR:UpdateDividers(bar, mode == "stack" and maxS or 0)
                        elseif mode == "stack" then
                            local maxS = v.maxStacks or 8
                            if maxS <= 0 then maxS = 1 end
                            UpdateBarValueSafe(bar.statusBar, 0, maxS)
                            CR:UpdateDividers(bar, maxS)
                        else
                            UpdateBarValueSafe(bar.statusBar, 0, 1)
                            CR:UpdateDividers(bar, 0)
                        end
                        
                        pcall(function() 
                            bar.cd:Clear() 
                            if bar.statusBar.ClearTimerDuration then bar.statusBar:ClearTimerDuration() end
                            if bar.durationText then bar.durationText:SetText("") end
                        end)
                        bar.lastAuraId = nil; bar._lastDurObj = nil; bar._lastRechargingSlot = nil
                        
                        if bar.rechargeOverlay then 
                            bar.rechargeOverlay:Hide() 
                            pcall(function() if bar.rechargeOverlay.ClearTimerDuration then bar.rechargeOverlay:ClearTimerDuration() end end)
                        end
                        UpdateCustomAuraText(bar, buffID, 0, isCharge)
                    else
                        if isCharge then
                            local maxS = CR.spellMaxChargeCache[buffID] or (auraData and auraData.maxCharges) or 2
                            if v.overrideMax then maxS = v.maxStacks or 2 end
                            if maxS <= 0 then maxS = 1 end
                            
                            bar.statusBar:SetMinMaxValues(0, maxS)
                            bar.statusBar:SetValue(st)
                            bar.statusBar._targetValue = nil 
                            bar.statusBar._currentValue = st
                            
                            bar:SetClipsChildren(true)
                            bar.statusBar:SetClipsChildren(true)
                            CR:UpdateDividers(bar, maxS)
                            
                            local durObj = currentDurObj
                            if not durObj and auraInstanceID and not isCharge then durObj = C_UnitAuras.GetAuraDuration(unit, auraInstanceID) end
                            
                            if not bar.rechargeOverlay then
                                bar.rechargeOverlay = CreateFrame("StatusBar", nil, bar.statusBar)
                                bar.rechargeOverlay:SetFrameLevel(bar.statusBar:GetFrameLevel() + 1)
                            end
                            bar.rechargeOverlay:SetStatusBarTexture(bar.statusBar:GetStatusBarTexture():GetTexture())
                            bar.rechargeOverlay:SetStatusBarColor(c.r, c.g, c.b, c.a or 0.8)
                            local totalWidth = bar:GetWidth() or 250; local segWidth = totalWidth / maxS
                            
                            bar.rechargeOverlay:SetReverseFill(v.reverseFill or false)
                            bar.rechargeOverlay:ClearAllPoints()
                            if v.reverseFill then bar.rechargeOverlay:SetPoint("RIGHT", bar.statusBar:GetStatusBarTexture(), "LEFT", 0, 0)
                            else bar.rechargeOverlay:SetPoint("LEFT", bar.statusBar:GetStatusBarTexture(), "RIGHT", 0, 0) end
                            bar.rechargeOverlay:SetWidth(segWidth)
                            bar.rechargeOverlay:SetHeight(bar.statusBar:GetHeight())

                            if durObj then
                                pcall(function()
                                    bar.cd:ClearAllPoints()
                                    bar.cd:SetAllPoints(bar.rechargeOverlay)
                                    bar.cd:SetCooldownFromDurationObject(durObj)
                                    if bar.durationText then
                                        bar.durationText:ClearAllPoints()
                                        bar.durationText:SetPoint("CENTER", bar.rechargeOverlay, "CENTER", 0, 0)
                                        bar.durationText:SetJustifyH("CENTER")
                                        bar._lastDurPos = nil
                                    end
                                end)
                                pcall(function() bar.rechargeOverlay:SetTimerDuration(durObj, 0, Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime or 0) end)
                                bar.rechargeOverlay:Show()
                            else
                                bar.rechargeOverlay:Hide()
                                pcall(function() 
                                    bar.cd:ClearAllPoints(); bar.cd:SetAllPoints(bar.statusBar); bar.cd:Clear() 
                                    if bar.rechargeOverlay.ClearTimerDuration then bar.rechargeOverlay:ClearTimerDuration() end
                                    if bar.durationText then bar.durationText:SetText(""); bar._lastDurPos = nil end
                                end)
                            end
                            UpdateCustomAuraText(bar, buffID, st, true)
                            
                        elseif isConsume then
                            local maxS = v.maxStacks or 8
                            if maxS <= 0 then maxS = 1 end
                            UpdateBarValueSafe(bar.statusBar, st, maxS)
                            CR:UpdateDividers(bar, mode == "stack" and maxS or 0)
                            
                            if bar.rechargeOverlay then bar.rechargeOverlay:Hide() end
                            local durObj = currentDurObj
                            if not durObj and auraInstanceID then durObj = C_UnitAuras.GetAuraDuration(unit, auraInstanceID) end
                            
                            pcall(function() if bar.statusBar.ClearTimerDuration then bar.statusBar:ClearTimerDuration() end end)
                            if durObj then
                                bar.lastAuraId = auraInstanceID
                                if bar._lastDurObj ~= durObj then bar._lastDurObj = durObj; pcall(function() bar.cd:SetCooldownFromDurationObject(durObj) end) end
                            elseif isFakeBuff then pcall(function() bar.cd:SetCooldown(fStart, fDur) end)
                            else
                                if bar.lastAuraId ~= nil or bar._lastDurObj ~= nil then pcall(function() bar.cd:Clear(); if bar.durationText then bar.durationText:SetText("") end end); bar.lastAuraId = nil; bar._lastDurObj = nil end
                            end
                            UpdateCustomAuraText(bar, buffID, st, false)
                            
                        elseif mode == "stack" then
                            local maxS = v.maxStacks or 8
                            if maxS <= 0 then maxS = 1 end
                            UpdateBarValueSafe(bar.statusBar, st, maxS)
                            CR:UpdateDividers(bar, maxS)
                            if bar.rechargeOverlay then bar.rechargeOverlay:Hide() end
                            local durObj = currentDurObj
                            if not durObj and auraInstanceID then durObj = C_UnitAuras.GetAuraDuration(unit, auraInstanceID) end
                            if durObj then
                                bar.lastAuraId = auraInstanceID
                                if bar._lastDurObj ~= durObj then bar._lastDurObj = durObj; pcall(function() bar.statusBar:SetTimerDuration(durObj, 0, 1); if bar.statusBar.SetToTargetValue then bar.statusBar:SetToTargetValue() end; bar.cd:SetCooldownFromDurationObject(durObj) end) end
                            elseif isFakeBuff then pcall(function() bar.cd:SetCooldown(fStart, fDur) end)
                            else
                                if bar.lastAuraId ~= nil or bar._lastDurObj ~= nil then pcall(function() bar.cd:Clear(); if bar.statusBar.ClearTimerDuration then bar.statusBar:ClearTimerDuration() end; if bar.durationText then bar.durationText:SetText("") end end); bar.lastAuraId = nil; bar._lastDurObj = nil; bar._lastRechargingSlot = nil end
                            end
                            UpdateCustomAuraText(bar, buffID, st, false)
                        else
                            CR:UpdateDividers(bar, 0)
                            if bar.rechargeOverlay then bar.rechargeOverlay:Hide() end
                            local durObj = currentDurObj
                            if not durObj and auraInstanceID then durObj = C_UnitAuras.GetAuraDuration(unit, auraInstanceID) end
                            if durObj then
                                bar.lastAuraId = auraInstanceID
                                if bar._lastDurObj ~= durObj then bar._lastDurObj = durObj; pcall(function() bar.statusBar:SetTimerDuration(durObj, 0, 1); if bar.statusBar.SetToTargetValue then bar.statusBar:SetToTargetValue() end; bar.cd:SetCooldownFromDurationObject(durObj) end) end
                            elseif isFakeBuff then pcall(function() bar.cd:SetCooldown(fStart, fDur) end)
                            else
                                if bar.lastAuraId ~= nil or bar._lastDurObj ~= nil then pcall(function() bar.cd:Clear(); if bar.statusBar.ClearTimerDuration then bar.statusBar:ClearTimerDuration() end; if bar.durationText then bar.durationText:SetText("") end end); bar.lastAuraId = nil; bar._lastDurObj = nil; bar._lastRechargingSlot = nil end
                                UpdateBarValueSafe(bar.statusBar, 1, 1)
                            end
                            UpdateCustomAuraText(bar, buffID, st, false)
                        end
                    end
                    bar:Show()
                    CR.ActiveAuraBars[activeCount] = bar
                end
            end
        end
    end
    
    for i = activeCount + 1, #CR.AuraBarPool do
        local b = CR.AuraBarPool[i]
        b:Hide()
        pcall(function() 
            b.cd:ClearAllPoints(); b.cd:SetAllPoints(b.statusBar); b.cd:Clear() 
            if b.statusBar.ClearTimerDuration then b.statusBar:ClearTimerDuration() end
            if b.durationText then b.durationText:SetText(""); b._lastDurPos = nil end
            if b.rechargeOverlay and b.rechargeOverlay.ClearTimerDuration then b.rechargeOverlay:ClearTimerDuration() end
        end)
        b.lastAuraId = nil; b._lastDurObj = nil; b._lastRechargingSlot = nil
    end
    
    -- 100% 保留：水平裂变排版算法
    local stackedBars = {}
    local splitBars = {}
    
    for i = 1, activeCount do
        local bar = CR.ActiveAuraBars[i]
        bar:ClearAllPoints()
        if bar.isHorizontalSplit then splitBars[#splitBars + 1] = bar
        elseif bar.isIndependent then bar:SetPoint("CENTER", self.auraAnchor, "CENTER", bar.customX, bar.customY)
        else stackedBars[#stackedBars + 1] = bar end
    end

    local numSplit = #splitBars
    if numSplit > 0 then
        table.sort(splitBars, function(a, b) return (a.buffID or 0) < (b.buffID or 0) end)
        local totalWidth = GetTargetWidth(specCfg)
        local gap = 2
        pcall(function()
            local d = GetSpellDB()[tostring(splitBars[1].buffID)]
            if d and d.auraBar and d.auraBar.splitSpacing then gap = d.auraBar.splitSpacing end
        end)
        local eachWidth = (totalWidth - (gap * (numSplit - 1))) / numSplit
        if eachWidth < 1 then eachWidth = 1 end 
        local startX = -totalWidth / 2 + eachWidth / 2
        for i = 1, numSplit do
            local bar = splitBars[i]
            bar:SetWidth(eachWidth) 
            local yOffset = 0
            pcall(function() local d = GetSpellDB()[tostring(bar.buffID)]; if d and d.auraBar then yOffset = d.auraBar.customYOffset or 0 end end)
            bar:SetPoint("CENTER", self.auraAnchor, "CENTER", startX, yOffset)
            startX = startX + eachWidth + gap
        end
    end

    for i = 1, #stackedBars do
        local bar = stackedBars[i]
        if i == 1 then bar:SetPoint("BOTTOM", self.auraAnchor, "BOTTOM", 0, 0)
        else
            local prev = stackedBars[i-1]
            if auraCfg.growth == "UP" then bar:SetPoint("BOTTOM", prev, "TOP", 0, auraCfg.spacing or 1)
            else bar:SetPoint("TOP", prev, "BOTTOM", 0, -(auraCfg.spacing or 1)) end
        end
    end
end

-- =========================================
-- [全局更新引擎与排版]
-- =========================================
function CR:UpdateLayout()
    self:WakeUp()
    if not self.baseAnchor then return end
    
    local db = GetDB()
    local currentContextID = GetCurrentContextID()
    local specCfg = GetCurrentSpecConfig(currentContextID)
    self.cachedSpecCfg = specCfg

    self:BuildAuraCache()

    local targetWidth = GetTargetWidth(specCfg)
    self.baseAnchor:SetSize(targetWidth, 14)

    local function ApplyBarGraphics(bar, barCfg)
        if not bar or not bar.statusBar or not barCfg then return end
        local texName = (barCfg.useCustomTexture and barCfg.texture and barCfg.texture ~= "") and barCfg.texture or db.texture
        local tex = (LSM and LSM:Fetch("statusbar", texName)) or "Interface\\TargetingFrame\\UI-StatusBar"
        bar.statusBar:SetStatusBarTexture(tex)
        if bar.statusBar.bg then
            local bgTexName = (barCfg.useCustomBgTexture and barCfg.bgTexture and barCfg.bgTexture ~= "") and barCfg.bgTexture or db.texture
            local bgTex = (LSM and LSM:Fetch("statusbar", bgTexName)) or "Interface\\TargetingFrame\\UI-StatusBar"
            bar.statusBar.bg:SetTexture(bgTex)
            local bgc = barCfg.bgColor or {r=0, g=0, b=0, a=0.5}
            bar.statusBar.bg:SetVertexColor(bgc.r, bgc.g, bgc.b, bgc.a)
        end
    end

    ApplyBarGraphics(self.powerBar, specCfg.power)
    ApplyBarGraphics(self.classBar, specCfg.class)
    ApplyBarGraphics(self.manaBar, specCfg.mana)

    local pType = UnitPowerType("player")
    local pMax = UnitPowerMax("player", pType)
    local validMax = IsSecret(pMax) or ((tonumber(pMax) or 0) > 0)
    self.showPower = specCfg.power and validMax and specCfg.showPower
    
    local _, _, _, hasClassDef = GetClassResourceData()
    self.showClass = specCfg.class and hasClassDef and specCfg.showClass
    
    local manaMax = UnitPowerMax("player", 0)
    local validManaMax = IsSecret(manaMax) or ((tonumber(manaMax) or 0) > 0)
    self.showMana = hasHealerSpec and specCfg.mana and validManaMax and specCfg.showMana

    local stackOrder = {
        { bar = self.manaBar,     show = self.showMana,                  cfg = specCfg.mana,    anchor = self.manaAnchor },
        { bar = self.powerBar,    show = self.showPower,                 cfg = specCfg.power,   anchor = self.powerAnchor },
        { bar = self.classBar,    show = self.showClass,                 cfg = specCfg.class,   anchor = self.classAnchor },
        { bar = self.auraAnchor,  show = specCfg.showAuraBar,            cfg = specCfg.auraBar, anchor = self.auraAnchor, isAura = true }
    }

    local lastStackedFrame = nil
    for _, item in ipairs(stackOrder) do
        local f = item.bar
        if item.show and item.cfg then
            f.isForceHidden = false; f:Show()
            if not item.isAura then f:SetSize(targetWidth, tonumber(item.cfg.height) or 14) else f:SetSize(targetWidth, 1) end
            f:ClearAllPoints()
            if item.cfg.independent then
                f:SetPoint("CENTER", item.anchor.mover or item.anchor, "CENTER", tonumber(item.cfg.barXOffset) or 0, tonumber(item.cfg.barYOffset) or 0)
            else
                if not lastStackedFrame then
                    if db.alignWithCD and _G.EssentialCooldownViewer then
                        f:SetPoint("BOTTOM", _G.EssentialCooldownViewer, "TOP", tonumber(item.cfg.barXOffset) or 0, (tonumber(db.alignYOffset) or 1) + (tonumber(item.cfg.barYOffset) or 0))
                    else
                        f:SetPoint("CENTER", self.baseAnchor.mover or self.baseAnchor, "CENTER", tonumber(item.cfg.barXOffset) or 0, tonumber(item.cfg.barYOffset) or 0)
                    end
                else
                    f:SetPoint("BOTTOM", lastStackedFrame, "TOP", tonumber(item.cfg.barXOffset) or 0, (tonumber(specCfg.yOffset) or 1) + (tonumber(item.cfg.barYOffset) or 0))
                end
                lastStackedFrame = f
            end
        else
            if not item.isAura then f.isForceHidden = true; f:Hide() end
        end
    end
    self:DynamicTick()
    CR:UpdateAuraBars()
end

function CR:DynamicTick()
    if not self.baseAnchor then return end
    local specCfg = self.cachedSpecCfg or GetCurrentSpecConfig(GetCurrentContextID())
    if not specCfg then return end
    self.hasActiveTimer = false

    if self.showPower and specCfg.power then
        local pType = UnitPowerType("player")
        local rawMax = UnitPowerMax("player", pType)
        local rawCurr = UnitPower("player", pType)
        if not IsSecret(rawMax) then if type(rawMax) ~= "number" or rawMax <= 0 then rawMax = 1 end end
        if type(rawCurr) ~= "number" then rawCurr = 0 end
        pcall(function() if rawCurr < rawMax then self.hasActiveTimer = true end end)
        
        local pColor = GetSafeColor(specCfg.power, GetPowerColor(pType), false)
        UpdateBarValueSafe(self.powerBar.statusBar, rawCurr, rawMax)
        self.powerBar.statusBar:SetStatusBarColor(pColor.r, pColor.g, pColor.b)
        self:UpdateDividers(self.powerBar, 1)
        
        local textCurr = rawCurr
        pcall(function() textCurr = math.floor(rawCurr) end)
        FormatSafeText(self.powerBar, specCfg.power, textCurr, rawMax, false, pType, specCfg.textPower)

        if specCfg.power.thresholdLines then
            if not self.powerBar.thresholdLines then self.powerBar.thresholdLines = {} end
            local activeLines = 0
            for i = 1, 5 do
                local cfgLine = specCfg.power.thresholdLines[i]
                if cfgLine and cfgLine.enable and cfgLine.value > 0 and rawMax and rawMax > 0 and cfgLine.value <= rawMax then
                    activeLines = activeLines + 1
                    local tLine = self.powerBar.thresholdLines[activeLines]
                    if not tLine then
                        tLine = self.powerBar.statusBar:CreateTexture(nil, "OVERLAY", nil, 7)
                        self.powerBar.thresholdLines[activeLines] = tLine
                    end
                    local barWidth = self.powerBar.statusBar:GetWidth()
                    if not barWidth or barWidth == 0 then barWidth = (self.powerBar:GetWidth() or 250) - 2 end
                    local posX = (cfgLine.value / rawMax) * barWidth
                    local tColor = cfgLine.color or {r=1, g=1, b=1, a=1}
                    local tThick = cfgLine.thickness or 1
                    tLine:SetColorTexture(tColor.r, tColor.g, tColor.b, tColor.a)
                    tLine:SetWidth(tThick)
                    tLine:ClearAllPoints()
                    tLine:SetPoint("TOPLEFT", self.powerBar.statusBar, "TOPLEFT", posX - (tThick/2), 0)
                    tLine:SetPoint("BOTTOMLEFT", self.powerBar.statusBar, "BOTTOMLEFT", posX - (tThick/2), 0)
                    tLine:Show()
                end
            end
            for i = activeLines + 1, #(self.powerBar.thresholdLines or {}) do
                if self.powerBar.thresholdLines[i] then self.powerBar.thresholdLines[i]:Hide() end
            end
        end
    end

    if self.showClass and specCfg.class then
        local rawCurr, rawMax, cDefColor = GetClassResourceData()
        if not IsSecret(rawMax) then if type(rawMax) ~= "number" or rawMax <= 0 then rawMax = 1 end end
        if type(rawCurr) ~= "number" then rawCurr = 0 end
        pcall(function() if rawCurr < rawMax then self.hasActiveTimer = true end end)
        
        local cColor = GetSafeColor(specCfg.class, cDefColor, true)
        UpdateBarValueSafe(self.classBar.statusBar, rawCurr, rawMax)
        self.classBar.statusBar:SetStatusBarColor(cColor.r, cColor.g, cColor.b)
        self:UpdateDividers(self.classBar, rawMax)
        
        local textCurr = rawCurr
        pcall(function() textCurr = math.floor(rawCurr) end)
        FormatSafeText(self.classBar, specCfg.class, textCurr, rawMax, false, nil, specCfg.textClass)
    end
    
    if self.showMana and specCfg.mana then
        local rawMax = UnitPowerMax("player", 0)
        local rawCurr = UnitPower("player", 0)
        if not IsSecret(rawMax) then if type(rawMax) ~= "number" or rawMax <= 0 then rawMax = 1 end end
        if type(rawCurr) ~= "number" then rawCurr = 0 end
        pcall(function() if rawCurr < rawMax then self.hasActiveTimer = true end end)
        
        local mColor = GetSafeColor(specCfg.mana, POWER_COLORS[0], false)
        UpdateBarValueSafe(self.manaBar.statusBar, rawCurr, rawMax)
        self.manaBar.statusBar:SetStatusBarColor(mColor.r, mColor.g, mColor.b)
        self:UpdateDividers(self.manaBar, 1)
        
        local textCurr = rawCurr
        pcall(function() textCurr = math.floor(rawCurr) end)
        FormatSafeText(self.manaBar, specCfg.mana, textCurr, rawMax, false, 0, specCfg.textMana)
    end
    
    if playerClass == "MONK" then
        for i = 1, #CR.ActiveAuraBars do
            local bar = CR.ActiveAuraBars[i]
            if bar.buffID and (bar.buffID == 124275 or bar.buffID == 124274 or bar.buffID == 124273 or bar.buffID == 115308) then
                UpdateCustomAuraText(bar, bar.buffID, 0, false)
            end
        end
    end
end

function CR:WakeUp(event, unit)
    if (event == "UNIT_AURA" or event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_SPELLCAST_SUCCEEDED") and unit ~= "player" then return end
    self.idleTimer = 0
    self.sleepMode = false
end

function CR:OnContextChanged()
    self.selectedSpecForConfig = GetCurrentContextID()
    self.cachedSpecCfg = GetCurrentSpecConfig(self.selectedSpecForConfig)
    self:UpdateLayout()
end

local function InitClassResource()
    GetDB() 

    -- 创建所有的独立框体，并且对接我们的原生 EditMode 移动引擎
    CR.baseAnchor = CreateFrame("Frame", "WishFlex_BaseAnchor", UIParent)
    WF:CreateMover(CR.baseAnchor, "WishFlexBaseAnchorMover", {"CENTER", UIParent, "CENTER", 0, -180}, 250, 14, L["Class Resource Base Mover"] or "WishFlex: 全局排版起点(底层)")

    CR.manaAnchor = CreateFrame("Frame", "WishFlex_ManaAnchor", UIParent)
    WF:CreateMover(CR.manaAnchor, "WishFlexManaMover", {"CENTER", UIParent, "CENTER", 0, -220}, 250, 10, L["Class Resource Mana Mover"] or "WishFlex: [独立移动] 专属法力条")

    CR.powerAnchor = CreateFrame("Frame", "WishFlex_PowerAnchor", UIParent)
    WF:CreateMover(CR.powerAnchor, "WishFlexPowerMover", {"CENTER", UIParent, "CENTER", 0, -160}, 250, 14, L["Class Resource Power Mover"] or "WishFlex: [独立移动] 能量条")

    CR.classAnchor = CreateFrame("Frame", "WishFlex_ClassAnchor", UIParent)
    WF:CreateMover(CR.classAnchor, "WishFlexClassMover", {"CENTER", UIParent, "CENTER", 0, -140}, 250, 14, L["Class Resource Main Mover"] or "WishFlex: [独立移动] 主资源条")

    CR.auraAnchor = CreateFrame("Frame", "WishFlex_AuraAnchor", UIParent)
    WF:CreateMover(CR.auraAnchor, "WishFlexAuraMover", {"CENTER", UIParent, "CENTER", 0, -100}, 250, 14, L["Class Resource Aura Mover"] or "WishFlex: [独立移动] 增益组(Aura)")

    CR.powerBar = CR:CreateBarContainer("WishFlex_PowerBar", UIParent)
    CR.classBar = CR:CreateBarContainer("WishFlex_ClassBar", UIParent)
    CR.manaBar = CR:CreateBarContainer("WishFlex_ManaBar", UIParent)
    
    CR.AllBars = {CR.powerBar, CR.classBar, CR.manaBar}
    CR.showPower, CR.showClass, CR.showMana = false, false, false
    CR.idleTimer = 0; CR.sleepMode = false; CR.hasActiveTimer = false
    
    CR:RegisterEvent("PLAYER_ENTERING_WORLD")
    CR:RegisterEvent("UNIT_DISPLAYPOWER")
    CR:RegisterEvent("UNIT_MAXPOWER")
    CR:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    CR:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    CR:RegisterEvent("UNIT_POWER_UPDATE")
    CR:RegisterEvent("UNIT_POWER_FREQUENT")
    CR:SetScript("OnEvent", function(self, event, unit)
        if event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" then self:WakeUp(event, unit)
        elseif event == "PLAYER_ENTERING_WORLD" or event == "UNIT_DISPLAYPOWER" or event == "UNIT_MAXPOWER" then self:UpdateLayout()
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "UPDATE_SHAPESHIFT_FORM" then self:OnContextChanged() end
    end)
    
    EventRegistry:RegisterCallback("UNIT_AURA", function(e, u) if u == "player" or u == "target" then RequestUpdateAuraBars() end CR:WakeUp(e,u) end)
    EventRegistry:RegisterCallback("PLAYER_TARGET_CHANGED", function() RequestUpdateAuraBars(); CR:WakeUp() end)
    EventRegistry:RegisterCallback("PLAYER_REGEN_DISABLED", function() RequestUpdateAuraBars(); CR:WakeUp() end)
    EventRegistry:RegisterCallback("PLAYER_REGEN_ENABLED", function() RequestUpdateAuraBars(); CR:WakeUp() end)
    EventRegistry:RegisterCallback("SPELL_UPDATE_CHARGES", function(e) CR:DynamicTick(); RequestUpdateAuraBars(); CR:WakeUp(e) end)
    EventRegistry:RegisterCallback("SPELL_UPDATE_COOLDOWN", function(e) CR:DynamicTick(); RequestUpdateAuraBars(); CR:WakeUp(e) end)
    EventRegistry:RegisterCallback("UNIT_SPELLCAST_SUCCEEDED", function(e, unit, _, spellID) 
        if unit == "player" then RequestUpdateAuraBars(); CR:WakeUp(e, unit) end 
    end)
    
    CR:OnContextChanged()
    
    local ticker = 0
    CR.frameTick = 0
    CR.baseAnchor:SetScript("OnUpdate", function(_, elapsed)
        if CR.sleepMode then return end
        CR.frameTick = CR.frameTick + 1
        
        local SMOOTH_SPEED = 15
        local function SmoothBar(bar)
            if bar and bar.statusBar and not bar.isForceHidden then
                local sb = bar.statusBar
                if sb._targetValue and not IsSecret(sb._targetValue) then
                    sb._currentValue = sb._currentValue or sb:GetValue() or 0
                    if not IsSecret(sb._currentValue) then
                        pcall(function()
                            if sb._currentValue ~= sb._targetValue then
                                local diff = sb._targetValue - sb._currentValue
                                if math.abs(diff) < 0.01 then sb._currentValue = sb._targetValue
                                else sb._currentValue = sb._currentValue + diff * SMOOTH_SPEED * elapsed end
                                sb:SetValue(sb._currentValue)
                            end
                        end)
                    end
                end
            end
        end

        for i = 1, #CR.AllBars do SmoothBar(CR.AllBars[i]) end
        for i = 1, #CR.ActiveAuraBars do SmoothBar(CR.ActiveAuraBars[i]) end
        
        ticker = ticker + elapsed
        local interval = InCombatLockdown() and 0.05 or 0.2
        if ticker >= interval then
            ticker = 0
            CR:DynamicTick()
            if not InCombatLockdown() then
                CR.idleTimer = (CR.idleTimer or 0) + interval
                if CR.idleTimer >= 2 and not CR.hasActiveTimer then CR.sleepMode = true end
            else CR.idleTimer = 0 end
        end
    end)
end

WF:RegisterModule("classResource", L["Class Resource"] or "职业专属资源与能量", InitClassResource)