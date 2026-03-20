local AddonName, ns = ...
local WF = _G.WishFlex or ns.WF
local L = ns.L or {}
local LSM = LibStub("LibSharedMedia-3.0", true)

local CR = CreateFrame("Frame")
WF.ClassResourceAPI = CR

local playerClass = select(2, UnitClass("player"))
local hasHealerSpec = (playerClass == "PALADIN" or playerClass == "PRIEST" or playerClass == "SHAMAN" or playerClass == "MONK" or playerClass == "DRUID" or playerClass == "EVOKER")

function CR:RegisterEvent(event, func)
    if not self._events then self._events = {} end
    self._events[event] = func or event
    getmetatable(self).__index.RegisterEvent(self, event)
end
CR:SetScript("OnEvent", function(self, event, ...)
    local handler = self._events[event]
    if type(handler) == "function" then handler(self, event, ...)
    elseif type(handler) == "string" and type(self[handler]) == "function" then self[handler](self, event, ...) end
end)

local barDefaults = {
    power = { independent = false, barXOffset = 0, barYOffset = 0, height = 14, textEnable = true, textFormat = "AUTO", textAnchor = "CENTER", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = true, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=0, g=0.5, b=1}, useCustomTexture = false, texture = "Wish2", useCustomBgTexture = false, bgTexture = "Wish2", bgColor = {r=0, g=0, b=0, a=0.5} },
    class = { independent = false, barXOffset = 0, barYOffset = 0, height = 12, textEnable = true, textFormat = "AUTO", textAnchor = "CENTER", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = true, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=1, g=0.96, b=0.41}, useCustomColors = {}, customColors = {}, useCustomTexture = false, texture = "Wish2", useCustomBgTexture = false, bgTexture = "Wish2", bgColor = {r=0, g=0, b=0, a=0.5} },
    mana = { independent = false, barXOffset = 0, barYOffset = 0, height = 10, textEnable = true, textFormat = "AUTO", textAnchor = "CENTER", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = true, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=0, g=0.5, b=1}, useCustomTexture = false, texture = "Wish2", useCustomBgTexture = false, bgTexture = "Wish2", bgColor = {r=0, g=0, b=0, a=0.5} },
}

local defaults = {
    enable = true, alignWithCD = false, alignYOffset = 1, widthOffset = 0, texture = "Wish2", font = "Expressway", specConfigs = {},
    sortOrder = {"mana", "power", "class", "monitor"} 
}

local DEFAULT_COLOR = {r=1, g=1, b=1}
local POWER_COLORS = { [0]={r=0,g=0.5,b=1}, [1]={r=1,g=0,b=0}, [2]={r=1,g=0.5,b=0.25}, [3]={r=1,g=1,b=0}, [4]={r=1,g=0.96,b=0.41}, [5]={r=0.8,g=0.1,b=0.2}, [7]={r=0.5,g=0.32,b=0.55}, [8]={r=0.3,g=0.52,b=0.9}, [9]={r=0.95,g=0.9,b=0.6}, [11]={r=0,g=0.5,b=1}, [12]={r=0.71,g=1,b=0.92}, [13]={r=0.4,g=0,b=0.8}, [16]={r=0.1,g=0.1,b=0.98}, [17]={r=0.79,g=0.26,b=0.99}, [18]={r=1,g=0.61,b=0}, [19]={r=0.4,g=0.8,b=1} }

local PLAYER_CLASS_COLOR = DEFAULT_COLOR
local cc_cache = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass]
if cc_cache then PLAYER_CLASS_COLOR = {r=cc_cache.r, g=cc_cache.g, b=cc_cache.b} end

local function DeepMerge(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then if type(target[k]) ~= "table" then target[k] = {} end; DeepMerge(target[k], v)
        else if target[k] == nil then target[k] = v end end
    end
end

local function GetDB()
    if not WF.db.classResource then WF.db.classResource = {} end
    DeepMerge(WF.db.classResource, defaults)
    if not WF.db.classResource.sortOrder or #WF.db.classResource.sortOrder < 4 then WF.db.classResource.sortOrder = {"mana", "power", "class", "monitor"} end
    return WF.db.classResource
end

local function GetOnePixelSize()
    local screenHeight = select(2, GetPhysicalScreenSize()); if not screenHeight or screenHeight == 0 then return 1 end
    local uiScale = UIParent:GetEffectiveScale(); if not uiScale or uiScale == 0 then return 1 end
    return 768.0 / screenHeight / uiScale
end

local function PixelSnap(value)
    if not value then return 0 end
    local onePixel = GetOnePixelSize()
    if onePixel == 0 then return value end
    return math.floor(value / onePixel + 0.5) * onePixel
end

local function CreateBorderTex(parent, layer, subLevel)
    local tex = parent:CreateTexture(nil, layer, nil, subLevel)
    tex:SetTexture("Interface\\Buttons\\WHITE8x8")
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
    return tex
end

local function AddPixelBorder(frame)
    if not frame then return end
    if frame.backdrop then frame.backdrop:SetAlpha(0) end
    local m = GetOnePixelSize()
    if not frame.wishBorder then
        local border = CreateFrame("Frame", nil, frame)
        border:SetAllPoints(frame)
        border:SetFrameLevel(frame:GetFrameLevel() + 35) 
        
        local top = CreateBorderTex(border, "OVERLAY", 7); top:SetColorTexture(0, 0, 0, 1); top:SetPoint("TOPLEFT", border, "TOPLEFT", 0, 0); top:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, 0); top:SetHeight(m)
        local bottom = CreateBorderTex(border, "OVERLAY", 7); bottom:SetColorTexture(0, 0, 0, 1); bottom:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, 0); bottom:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, 0); bottom:SetHeight(m)
        local left = CreateBorderTex(border, "OVERLAY", 7); left:SetColorTexture(0, 0, 0, 1); left:SetPoint("TOPLEFT", border, "TOPLEFT", 0, -m); left:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, m); left:SetWidth(m)
        local right = CreateBorderTex(border, "OVERLAY", 7); right:SetColorTexture(0, 0, 0, 1); right:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, -m); right:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, m); right:SetWidth(m)
        
        frame.wishBorder = border
    end
end

local function IsSecret(v) return type(v) == "number" and issecretvalue and issecretvalue(v) end

local function SafeFormatNum(v)
    local num = tonumber(v) or 0
    if num >= 1e6 then return (string.format("%.1fm", num / 1e6):gsub("%.0m", "m"))
    elseif num >= 1e3 then return (string.format("%.1fk", num / 1e3):gsub("%.0k", "k"))
    else return string.format("%.0f", num) end
end

local function GetCurrentContextID()
    if playerClass == "DRUID" then
        local formID = GetShapeshiftFormID()
        if formID == 1 then return 1001 elseif formID == 5 then return 1002 elseif formID == 31 then return 1003 elseif formID == 3 or formID == 4 or formID == 27 then return 1004 else return 1000 end
    else
        local specIndex = GetSpecialization(); return specIndex and GetSpecializationInfo(specIndex) or 0
    end
end

local function GetCurrentSpecConfig(ctxId)
    local db = GetDB(); ctxId = ctxId or GetCurrentContextID()
    if not db.specConfigs then db.specConfigs = {} end
    if type(db.specConfigs[ctxId]) ~= "table" then db.specConfigs[ctxId] = {} end
    local cfg = db.specConfigs[ctxId]
    
    if cfg.width == nil then cfg.width = db.width or 250 end
    if cfg.yOffset == nil then cfg.yOffset = db.yOffset or 1 end
    if cfg.showPower == nil then cfg.showPower = true end
    if cfg.showClass == nil then cfg.showClass = true end
    if cfg.showMana == nil then cfg.showMana = false end

    if type(cfg.power) ~= "table" then cfg.power = {} end
    DeepMerge(cfg.power, barDefaults.power)
    if type(cfg.class) ~= "table" then cfg.class = {} end; DeepMerge(cfg.class, barDefaults.class)
    if type(cfg.mana) ~= "table" then cfg.mana = {} end; DeepMerge(cfg.mana, barDefaults.mana)
    return cfg
end

-- 【完美重构：提供全插件通用的计算宽度接口】
function CR:GetActiveWidth()
    local db = GetDB()
    local specCfg = GetCurrentSpecConfig(GetCurrentContextID())
    if db.alignWithCD and WF.db.cooldownCustom and WF.db.cooldownCustom.Essential then
        local cdDB = WF.db.cooldownCustom.Essential
        local maxPerRow = tonumber(cdDB.maxPerRow) or 7
        local w = PixelSnap(tonumber(cdDB.row1Width) or tonumber(cdDB.width) or 45)
        local gap = PixelSnap(tonumber(cdDB.iconGap) or 2)
        return (maxPerRow * w) + ((maxPerRow - 1) * gap) + (tonumber(db.widthOffset) or 0)
    end
    return tonumber(specCfg.width) or 250
end

local function GetSafeColor(cfg, defColor, isClassBar)
    if cfg then
        if isClassBar then if type(cfg.useCustomColors) == "table" and cfg.useCustomColors[playerClass] then local cc = type(cfg.customColors) == "table" and cfg.customColors[playerClass]; if cc and type(cc.r) == "number" then return cc end end
        elseif cfg.useCustomColor and type(cfg.customColor) == "table" and type(cfg.customColor.r) == "number" then return cfg.customColor end
    end
    if type(defColor) == "table" and type(defColor.r) == "number" then return defColor end; return DEFAULT_COLOR
end
local function GetPowerColor(pType) return POWER_COLORS[pType] or DEFAULT_COLOR end

local function GetClassResourceData()
    local spec = GetSpecializationInfo(GetSpecialization() or 1)
    local pType = UnitPowerType("player")
    local classColor = PLAYER_CLASS_COLOR
    
    if playerClass == "ROGUE" then return UnitPower("player", 4), UnitPowerMax("player", 4), classColor, true
    elseif playerClass == "PALADIN" then return UnitPower("player", 9), 5, classColor, true
    elseif playerClass == "WARLOCK" then 
        local maxTrue = 50; local currTrue = 0; local maxShards = 5; local curr = 0
        pcall(function() maxTrue = UnitPowerMax("player", 7, true); currTrue = UnitPower("player", 7, true); maxShards = UnitPowerMax("player", 7); curr = UnitPower("player", 7); if maxTrue and maxTrue > 0 and currTrue and maxShards then curr = (currTrue / maxTrue) * maxShards end end)
        return curr, maxShards, classColor, true
    elseif playerClass == "EVOKER" then 
        local maxEssence = 6; local curr = 0
        pcall(function() maxEssence = UnitPowerMax("player", 19) or 6; if type(maxEssence) ~= "number" or IsSecret(maxEssence) then maxEssence = 6 end; curr = UnitPower("player", 19) or 0; if type(curr) ~= "number" or IsSecret(curr) then curr = 0 end end)
        if not CR.evokerEssence then CR.evokerEssence = { count = curr, partial = 0, lastTick = GetTime() } end
        local now = GetTime(); local elapsed = now - CR.evokerEssence.lastTick; CR.evokerEssence.lastTick = now
        if curr > CR.evokerEssence.count then CR.evokerEssence.partial = 0 end
        CR.evokerEssence.count = curr
        if curr < maxEssence then local activeRegen = 0.2; pcall(function() if GetPowerRegenForPowerType then local _, active = GetPowerRegenForPowerType(19); if type(active) == "number" and active > 0 then activeRegen = active end end end); CR.evokerEssence.partial = CR.evokerEssence.partial + (activeRegen * elapsed); if CR.evokerEssence.partial >= 1 then CR.evokerEssence.partial = 0.99 end
        else CR.evokerEssence.partial = 0 end
        return curr + CR.evokerEssence.partial, maxEssence, classColor, true
    elseif playerClass == "DEATHKNIGHT" then 
        local readyRunes = 0; local highestPartial = 0; local maxRunes = 6
        pcall(function() maxRunes = UnitPowerMax("player", 5) or 6; if type(maxRunes) ~= "number" or IsSecret(maxRunes) then maxRunes = 6 end; for i = 1, maxRunes do local start, duration, runeReady = GetRuneCooldown(i); if runeReady then readyRunes = readyRunes + 1 else if start and duration and duration > 0 then local partial = math.max(0, math.min(0.99, (GetTime() - start) / duration)); if partial > highestPartial then highestPartial = partial end end end end end)
        return readyRunes + highestPartial, maxRunes, classColor, true
    elseif playerClass == "MAGE" and spec == 62 then return UnitPower("player", 16), 4, classColor, true
    elseif playerClass == "MONK" and spec == 269 then return UnitPower("player", 12), UnitPowerMax("player", 12), classColor, true
    elseif playerClass == "DRUID" and pType == 3 then return UnitPower("player", 4), 5, classColor, true
    elseif playerClass == "SHAMAN" and spec == 263 then local apps = 0; if C_UnitAuras.GetPlayerAuraBySpellID then local aura = C_UnitAuras.GetPlayerAuraBySpellID(344179); if aura then apps = aura.applications or 1 end end; return apps, 10, classColor, true
    elseif playerClass == "HUNTER" and spec == 255 then local apps = 0; if C_UnitAuras.GetPlayerAuraBySpellID then local aura = C_UnitAuras.GetPlayerAuraBySpellID(260286); if aura then apps = aura.applications or 1 end end; return apps, 3, classColor, true
    elseif playerClass == "WARRIOR" and spec == 72 then local apps = 0; if C_UnitAuras.GetPlayerAuraBySpellID then local aura = C_UnitAuras.GetPlayerAuraBySpellID(85739) or C_UnitAuras.GetPlayerAuraBySpellID(322166); if aura then apps = aura.applications or 1 end end; return apps, 4, classColor, true end
    return 0, 0, DEFAULT_COLOR, false
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
    
    local pSize = GetOnePixelSize()
    for i = 1, numDividers do
        if not bar.dividers[i] then 
            local tex = targetFrame:CreateTexture(nil, "OVERLAY", nil, 7)
            tex:SetColorTexture(0, 0, 0, 1)
            if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
            if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
            bar.dividers[i] = tex 
        end
        bar.dividers[i]:SetWidth(pSize)
        local offset = PixelSnap(segWidth * i)
        bar.dividers[i]:ClearAllPoints()
        bar.dividers[i]:SetPoint("TOPLEFT", targetFrame, "TOPLEFT", offset, 0)
        bar.dividers[i]:SetPoint("BOTTOMLEFT", targetFrame, "BOTTOMLEFT", offset, 0)
        bar.dividers[i]:Show()
    end
    for i = numDividers + 1, #bar.dividers do if bar.dividers[i] then bar.dividers[i]:Hide() end end
end

local function SafeSetDurationText(fontString, remaining)
    if not fontString then return end
    if not remaining then fontString:SetText(""); return end
    local ok, result = pcall(function() local num = tonumber(remaining); if num then if num >= 60 then return string.format("%dm", math.floor(num / 60)) elseif num >= 10 then return string.format("%d", math.floor(num)) else return string.format("%.1f", num) end end; return remaining end)
    if ok and result then fontString:SetText(result) else pcall(function() fontString:SetText(remaining) end) end
end

local function FormatSafeText(bar, textCfg, current, maxVal, isTime, pType, showText, durObj)
    if not bar.text or not bar.timerText then return end
    local globalFont = GetDB().font or "Expressway"
    local fontPath = LSM:Fetch("font", globalFont) or STANDARD_TEXT_FONT
    local fontSize = tonumber(textCfg.fontSize) or 12
    local fontOutline = textCfg.outline or "OUTLINE"
    
    if bar._lastFont ~= fontPath or bar._lastSize ~= fontSize or bar._lastOutline ~= fontOutline then
        bar.text:SetFont(fontPath, fontSize, fontOutline); bar.timerText:SetFont(fontPath, fontSize, fontOutline)
        bar._lastFont = fontPath; bar._lastSize = fontSize; bar._lastOutline = fontOutline
    end
    
    local c = textCfg.color or DEFAULT_COLOR
    if bar._lastColorR ~= c.r or bar._lastColorG ~= c.g or bar._lastColorB ~= c.b then bar.text:SetTextColor(c.r, c.g, c.b); bar.timerText:SetTextColor(c.r, c.g, c.b); bar._lastColorR = c.r; bar._lastColorG = c.g; bar._lastColorB = c.b end
    
    local mainAnchor = textCfg.textAnchor or "CENTER"; local timerAnchor = textCfg.timerAnchor or "CENTER"
    local showMain = (textCfg.textEnable ~= false) and (textCfg.textFormat ~= "NONE") and showText
    local showTimer = (textCfg.timerEnable ~= false) and showText

    bar.text:ClearAllPoints(); bar.text:SetPoint(mainAnchor, bar.textFrame, mainAnchor, tonumber(textCfg.xOffset) or 0, tonumber(textCfg.yOffset) or 0); bar.text:SetJustifyH(mainAnchor)
    bar.timerText:ClearAllPoints(); bar.timerText:SetPoint(timerAnchor, bar.textFrame, timerAnchor, tonumber(textCfg.timerXOffset) or 0, tonumber(textCfg.timerYOffset) or 0); bar.timerText:SetJustifyH(timerAnchor)

    if durObj and type(current) == "number" then
        local remain = nil; if type(durObj.GetRemainingDuration) == "function" then remain = durObj:GetRemainingDuration() elseif durObj.expirationTime then remain = durObj.expirationTime - GetTime() end
        if remain then if showMain then bar.text:SetFormattedText("%d", current); bar.text:Show() else bar.text:Hide() end; if showTimer then SafeSetDurationText(bar.timerText, remain); bar.timerText:Show() else bar.timerText:Hide() end; return end
    end

    bar.timerText:Hide()
    if not showMain then bar.text:Hide() return end
    bar.text:Show()

    local formatMode = textCfg.textFormat
    if formatMode == "AUTO" then if pType == 0 then formatMode = "PERCENT" else formatMode = "ABSOLUTE" end end

    if isTime then SafeSetDurationText(bar.text, current)
    elseif pType == 0 and formatMode == "PERCENT" then local scale = (_G.CurveConstants and _G.CurveConstants.ScaleTo100) or 100; local perc = UnitPowerPercent("player", pType, false, scale); if IsSecret(perc) then bar.text:SetFormattedText("%d", perc) else bar.text:SetFormattedText("%d", tonumber(perc) or 0) end
    elseif formatMode == "PERCENT" then
        if pType then local perc = UnitPowerPercent("player", pType, false); if IsSecret(perc) then bar.text:SetFormattedText("%d", perc) else bar.text:SetFormattedText("%d", tonumber(perc) or 0) end else if IsSecret(current) or IsSecret(maxVal) then bar.text:SetFormattedText("%d", current) else local cVal = tonumber(current) or 0; local mVal = tonumber(maxVal) or 1; if mVal <= 0 then mVal = 1 end; bar.text:SetFormattedText("%d", math.floor((cVal / mVal) * 100 + 0.5)) end end
    elseif formatMode == "BOTH" then if IsSecret(current) or IsSecret(maxVal) then bar.text:SetFormattedText("%d / %d", current, maxVal) else bar.text:SetText(SafeFormatNum(current) .. " / " .. SafeFormatNum(maxVal)) end
    else if IsSecret(current) then bar.text:SetFormattedText("%d", current) else bar.text:SetText(SafeFormatNum(current)) end end
end

local function UpdateBarValueSafe(sb, rawCurr, rawMax)
    if IsSecret(rawMax) or IsSecret(rawCurr) then sb:SetMinMaxValues(0, rawMax); sb:SetValue(rawCurr); sb._targetValue = nil; sb._currentValue = nil; return end
    local currentMax = select(2, sb:GetMinMaxValues())
    if IsSecret(currentMax) or type(currentMax) ~= "number" or currentMax ~= rawMax then sb:SetMinMaxValues(0, rawMax); sb._currentValue = rawCurr; sb._targetValue = rawCurr; sb:SetValue(rawCurr) else sb._targetValue = rawCurr end
end

function CR:UpdateLayout()
    if self.isRendering then return end
    self.isRendering = true
    
    self:WakeUp()
    if not self.baseAnchor then self.isRendering = false; return end
    
    local db = GetDB(); local currentContextID = GetCurrentContextID(); local specCfg = GetCurrentSpecConfig(currentContextID)
    self.cachedSpecCfg = specCfg
    local targetWidth = self:GetActiveWidth(); self.baseAnchor:SetSize(targetWidth, 14)

    local function ApplyBarGraphics(bar, barCfg)
        if not bar or not bar.statusBar or not barCfg then return end
        local texName = (barCfg.useCustomTexture and barCfg.texture and barCfg.texture ~= "") and barCfg.texture or db.texture
        local tex = LSM:Fetch("statusbar", texName) or "Interface\\TargetingFrame\\UI-StatusBar"
        bar.statusBar:SetStatusBarTexture(tex)
        if bar.statusBar.bg then
            local bgTexName = (barCfg.useCustomBgTexture and barCfg.bgTexture and barCfg.bgTexture ~= "") and barCfg.bgTexture or db.texture
            local bgTex = LSM:Fetch("statusbar", bgTexName) or "Interface\\TargetingFrame\\UI-StatusBar"
            bar.statusBar.bg:SetTexture(bgTex); local bgc = barCfg.bgColor or {r=0, g=0, b=0, a=0.5}; bar.statusBar.bg:SetVertexColor(bgc.r, bgc.g, bgc.b, bgc.a)
        end
    end

    pcall(ApplyBarGraphics, self.powerBar, specCfg.power)
    pcall(ApplyBarGraphics, self.classBar, specCfg.class)
    pcall(ApplyBarGraphics, self.manaBar, specCfg.mana)

    local pType = UnitPowerType("player"); local pMax = UnitPowerMax("player", pType); local validMax = IsSecret(pMax) or ((tonumber(pMax) or 0) > 0)
    self.showPower = specCfg.power and validMax and specCfg.showPower
    local _, _, _, hasClassDef = GetClassResourceData(); self.showClass = specCfg.class and hasClassDef and specCfg.showClass
    local manaMax = UnitPowerMax("player", 0); local validManaMax = IsSecret(manaMax) or ((tonumber(manaMax) or 0) > 0)
    self.showMana = hasHealerSpec and specCfg.mana and validManaMax and specCfg.showMana

    local wmShow = false
    local wmAnchor = nil
    local wmDB = WF.db.wishMonitor
    if WF.WishMonitorAPI and WF.WishMonitorAPI.baseAnchor then
        wmAnchor = WF.WishMonitorAPI.baseAnchor
        if db.enable and WF.WishMonitorAPI.ActiveFrames and #WF.WishMonitorAPI.ActiveFrames > 0 then wmShow = true end
    end

    local stackItems = {
        class = { frame = self.classBar, show = self.showClass, cfg = specCfg.class, anchor = self.classAnchor },
        power = { frame = self.powerBar, show = self.showPower, cfg = specCfg.power, anchor = self.powerAnchor },
        mana  = { frame = self.manaBar, show = self.showMana, cfg = specCfg.mana, anchor = self.manaAnchor },
        monitor = { frame = wmAnchor, show = wmShow, isMonitor = true }
    }

    local sortOrder = db.sortOrder or {"mana", "power", "class", "monitor"}
    local lastStackedFrame = nil

    for i = #sortOrder, 1, -1 do
        local key = sortOrder[i]
        local item = stackItems[key]
        
        if item and item.frame then
            if not item.isMonitor then
                if item.show then
                    item.frame.isForceHidden = false; item.frame:Show()
                    item.frame:SetSize(targetWidth, tonumber(item.cfg.height) or 14)
                else
                    item.frame.isForceHidden = true; item.frame:Hide()
                end
            end
            
            if item.show then
                local isInd = false
                local xOff, yOff = 0, 0
                
                if item.isMonitor then
                    isInd = false
                    xOff = 0
                    yOff = 0
                else
                    isInd = item.cfg.independent
                    xOff = tonumber(item.cfg.barXOffset) or 0
                    yOff = tonumber(item.cfg.barYOffset) or 0
                end
                
                item.frame:ClearAllPoints()
                if isInd then
                    if not item.isMonitor then
                        item.frame:SetPoint("CENTER", item.anchor.mover or item.anchor, "CENTER", xOff, yOff)
                    end
                else
                    if not lastStackedFrame then
                        if db.alignWithCD and _G.EssentialCooldownViewer then
                            item.frame:SetPoint("BOTTOM", _G.EssentialCooldownViewer, "TOP", xOff, (tonumber(db.alignYOffset) or 1) + yOff)
                        else
                            item.frame:SetPoint("CENTER", self.baseAnchor.mover or self.baseAnchor, "CENTER", xOff, yOff)
                        end
                    else
                        item.frame:SetPoint("BOTTOM", lastStackedFrame, "TOP", xOff, (tonumber(specCfg.yOffset) or 1) + yOff)
                    end
                    lastStackedFrame = item.frame
                end
            end
        end
    end
    
    self:DynamicTick()
    self.isRendering = false
end

function CR:DynamicTick()
    if not self.baseAnchor then return end
    local specCfg = self.cachedSpecCfg or GetCurrentSpecConfig(GetCurrentContextID()); if not specCfg then return end
    self.hasActiveTimer = false

    if self.showPower and specCfg.power then
        local pType = UnitPowerType("player"); local rawMax = UnitPowerMax("player", pType); local rawCurr = UnitPower("player", pType)
        if not IsSecret(rawMax) then if type(rawMax) ~= "number" or rawMax <= 0 then rawMax = 1 end end
        if type(rawCurr) ~= "number" then rawCurr = 0 end
        pcall(function() if rawCurr < rawMax then self.hasActiveTimer = true end end)
        
        local pColor = GetSafeColor(specCfg.power, GetPowerColor(pType), false)
        UpdateBarValueSafe(self.powerBar.statusBar, rawCurr, rawMax)
        self.powerBar.statusBar:SetStatusBarColor(pColor.r, pColor.g, pColor.b)
        self:UpdateDividers(self.powerBar, 1)
        
        local textCurr = rawCurr; pcall(function() textCurr = math.floor(rawCurr) end)
        FormatSafeText(self.powerBar, specCfg.power, textCurr, rawMax, false, pType, specCfg.textPower)

        if specCfg.power.thresholdLines then
            if not self.powerBar.thresholdLines then self.powerBar.thresholdLines = {} end
            local activeLines = 0
            for i = 1, 5 do
                local cfgLine = specCfg.power.thresholdLines[i]
                if cfgLine and cfgLine.enable and cfgLine.value > 0 and rawMax and rawMax > 0 and cfgLine.value <= rawMax then
                    activeLines = activeLines + 1
                    local tLine = self.powerBar.thresholdLines[activeLines]
                    if not tLine then tLine = self.powerBar.statusBar:CreateTexture(nil, "OVERLAY", nil, 7); self.powerBar.thresholdLines[activeLines] = tLine end
                    local barWidth = self.powerBar.statusBar:GetWidth(); if not barWidth or barWidth == 0 then barWidth = (self.powerBar:GetWidth() or 250) - 2 end
                    local posX = (cfgLine.value / rawMax) * barWidth; local tColor = cfgLine.color or {r=1, g=1, b=1, a=1}; local tThick = cfgLine.thickness or 1
                    tLine:SetColorTexture(tColor.r, tColor.g, tColor.b, tColor.a); tLine:SetWidth(tThick); tLine:ClearAllPoints()
                    tLine:SetPoint("TOPLEFT", self.powerBar.statusBar, "TOPLEFT", posX - (tThick/2), 0); tLine:SetPoint("BOTTOMLEFT", self.powerBar.statusBar, "BOTTOMLEFT", posX - (tThick/2), 0)
                    tLine:Show()
                end
            end
            for i = activeLines + 1, #(self.powerBar.thresholdLines or {}) do if self.powerBar.thresholdLines[i] then self.powerBar.thresholdLines[i]:Hide() end end
        end
    end

    if self.showClass and specCfg.class then
        local rawCurr, rawMax, cDefColor = GetClassResourceData()
        if not IsSecret(rawMax) then if type(rawMax) ~= "number" or rawMax <= 0 then rawMax = 1 end end
        if type(rawCurr) ~= "number" then rawCurr = 0 end
        pcall(function() if rawCurr < rawMax then self.hasActiveTimer = true end end)
        local cColor = GetSafeColor(specCfg.class, cDefColor, true)
        UpdateBarValueSafe(self.classBar.statusBar, rawCurr, rawMax); self.classBar.statusBar:SetStatusBarColor(cColor.r, cColor.g, cColor.b)
        self:UpdateDividers(self.classBar, rawMax)
        local textCurr = rawCurr; pcall(function() textCurr = math.floor(rawCurr) end)
        FormatSafeText(self.classBar, specCfg.class, textCurr, rawMax, false, nil, specCfg.textClass)
    end
    
    if self.showMana and specCfg.mana then
        local rawMax = UnitPowerMax("player", 0); local rawCurr = UnitPower("player", 0)
        if not IsSecret(rawMax) then if type(rawMax) ~= "number" or rawMax <= 0 then rawMax = 1 end end
        if type(rawCurr) ~= "number" then rawCurr = 0 end
        pcall(function() if rawCurr < rawMax then self.hasActiveTimer = true end end)
        local mColor = GetSafeColor(specCfg.mana, POWER_COLORS[0], false)
        UpdateBarValueSafe(self.manaBar.statusBar, rawCurr, rawMax); self.manaBar.statusBar:SetStatusBarColor(mColor.r, mColor.g, mColor.b)
        self:UpdateDividers(self.manaBar, 1)
        local textCurr = rawCurr; pcall(function() textCurr = math.floor(rawCurr) end)
        FormatSafeText(self.manaBar, specCfg.mana, textCurr, rawMax, false, 0, specCfg.textMana)
    end
end

function CR:CreateBarContainer(name, parent)
    local bar = CreateFrame("Frame", name, parent, "BackdropTemplate")
    AddPixelBorder(bar)
    local sb = CreateFrame("StatusBar", nil, bar)
    sb:SetAllPoints(bar)
    bar.statusBar = sb
    local bg = sb:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); sb.bg = bg
    local gridFrame = CreateFrame("Frame", nil, bar); gridFrame:SetAllPoints(bar); gridFrame:SetFrameLevel(bar:GetFrameLevel() + 15); bar.gridFrame = gridFrame
    local textFrame = CreateFrame("Frame", nil, bar); textFrame:SetAllPoints(bar); textFrame:SetFrameLevel(bar:GetFrameLevel() + 50); bar.textFrame = textFrame
    bar.text = textFrame:CreateFontString(nil, "OVERLAY"); bar.timerText = textFrame:CreateFontString(nil, "OVERLAY") 
    return bar
end

function CR:CreateAnchor(name, title, defaultY, height)
    local anchor = CreateFrame("Frame", name, UIParent)
    anchor:SetPoint("CENTER", UIParent, "CENTER", 0, defaultY); anchor:SetSize(250, height)
    if WF.CreateMover then 
        WF:CreateMover(anchor, name.."Mover", {"CENTER", UIParent, "CENTER", 0, defaultY}, 250, height, title) 
    end
    local moverName = name.."Mover"; local mover = _G[moverName]
    if mover then
        if WF.db.movers and WF.db.movers[moverName] then local p = WF.db.movers[moverName]; mover:ClearAllPoints(); mover:SetPoint(p.point, UIParent, p.relativePoint, p.xOfs, p.yOfs) end
        if not mover._wishSaveHooked then
            mover:HookScript("OnDragStop", function(self) if not WF.db.movers then WF.db.movers = {} end; local point, _, relativePoint, xOfs, yOfs = self:GetPoint(); WF.db.movers[self:GetName()] = { point = point, relativePoint = relativePoint, xOfs = xOfs, yOfs = yOfs } end)
            mover._wishSaveHooked = true
        end
    end
    return anchor
end

function CR:WakeUp(event, unit)
    if (event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT") and unit ~= "player" then return end
    self.idleTimer = 0; self.sleepMode = false
end

function CR:OnContextChanged()
    self.selectedSpecForConfig = GetCurrentContextID()
    self.cachedSpecCfg = GetCurrentSpecConfig(self.selectedSpecForConfig)
    self:UpdateLayout()
end

local function InitClassResource()
    GetDB()
    
    CR.baseAnchor = CR:CreateAnchor("WishFlex_BaseAnchor", "WishFlex: " .. (L["Global Layout Anchor"] or "全局排版起点"), -180, 14)
    CR.manaAnchor = CR:CreateAnchor("WishFlex_ManaAnchor", "WishFlex: [独立] " .. (L["Extra Mana Bar"] or "专属法力条"), -220, 10)
    CR.powerAnchor = CR:CreateAnchor("WishFlex_PowerAnchor", "WishFlex: [独立] " .. (L["Power Bar"] or "能量条"), -160, 14)
    CR.classAnchor = CR:CreateAnchor("WishFlex_ClassAnchor", "WishFlex: [独立] " .. (L["Class Resource Bar"] or "主资源条"), -140, 14)

    CR.powerBar = CR:CreateBarContainer("WishFlex_PowerBar", UIParent)
    CR.classBar = CR:CreateBarContainer("WishFlex_ClassBar", UIParent)
    CR.manaBar = CR:CreateBarContainer("WishFlex_ManaBar", UIParent)
    
    CR.AllBars = {CR.powerBar, CR.classBar, CR.manaBar}
    CR.showPower, CR.showClass, CR.showMana = false, false, false
    CR.idleTimer = 0; CR.sleepMode = false; CR.hasActiveTimer = false
    CR.isRendering = false
    
    if not WF.db.classResource.enable then
        for i = 1, #CR.AllBars do CR.AllBars[i]:Hide() end
    end
    
    CR:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateLayout")
    CR:RegisterEvent("UNIT_DISPLAYPOWER", "UpdateLayout")
    CR:RegisterEvent("UNIT_MAXPOWER", "UpdateLayout")
    CR:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnContextChanged")
    CR:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "OnContextChanged")
    CR:RegisterEvent("UNIT_POWER_UPDATE", "WakeUp")
    CR:RegisterEvent("UNIT_POWER_FREQUENT", "WakeUp")

    C_Timer.After(0.8, function()
        local CDMod = WF.CooldownCustomAPI or WF.CooldownCustom
        if CDMod and CDMod.TriggerLayout then 
            hooksecurefunc(CDMod, "TriggerLayout", function() if GetDB().alignWithCD then CR:UpdateLayout() end end) 
        end
        
        if WF.WishMonitorAPI then
            WF.WishMonitorAPI.UpdateAnchor = function() end 
            
            hooksecurefunc(WF.WishMonitorAPI, "Render", function()
                if not CR.isRendering then
                    CR:UpdateLayout()
                end
            end)
        end
        
        CR:UpdateLayout()
    end)
    
    CR:OnContextChanged()
    
    local ticker = 0; CR.frameTick = 0
    CR.baseAnchor:SetScript("OnUpdate", function(_, elapsed)
        if CR.sleepMode then return end
        CR.frameTick = CR.frameTick + 1
        local function SmoothBar(bar)
            if bar and bar.statusBar and not bar.isForceHidden then
                local sb = bar.statusBar
                if sb._targetValue and not IsSecret(sb._targetValue) then
                    sb._currentValue = sb._currentValue or sb:GetValue() or 0
                    if not IsSecret(sb._currentValue) then
                        pcall(function()
                            if sb._currentValue ~= sb._targetValue then
                                local diff = sb._targetValue - sb._currentValue
                                if math.abs(diff) < 0.01 then sb._currentValue = sb._targetValue else sb._currentValue = sb._currentValue + diff * 15 * elapsed end
                                sb:SetValue(sb._currentValue)
                            end
                        end)
                    end
                end
            end
        end
        for i = 1, #CR.AllBars do SmoothBar(CR.AllBars[i]) end
        ticker = ticker + elapsed; local interval = InCombatLockdown() and 0.05 or 0.2
        if ticker >= interval then ticker = 0; CR:DynamicTick(); if not InCombatLockdown() then CR.idleTimer = (CR.idleTimer or 0) + interval; if CR.idleTimer >= 2 and not CR.hasActiveTimer then CR.sleepMode = true end else CR.idleTimer = 0 end end
    end)
end

WF:RegisterModule("classResource", L["Class Resource"] or "资源条", InitClassResource)

-- =========================================================================
-- [UI 动态注入引擎与可视化排序器]
-- =========================================================================
if WF.UI then
    WF.UI:RegisterMenu({ id = "ClassResource", parent = "Combat", name = L["Class Resource"] or "职业资源条", type = "group", order = 25 })
    WF.UI:RegisterMenu({ id = "CR_Global", parent = "ClassResource", name = L["Global Settings"] or "全局设置", key = "classResource_Global", order = 1 })
    WF.UI:RegisterMenu({ id = "CR_Power", parent = "ClassResource", name = L["Power Bar"] or "能量条", key = "classResource_Power", order = 2 })
    WF.UI:RegisterMenu({ id = "CR_Class", parent = "ClassResource", name = L["Class Resource Bar"] or "主资源条", key = "classResource_Class", order = 3 })
    WF.UI:RegisterMenu({ id = "CR_Mana", parent = "ClassResource", name = L["Extra Mana Bar"] or "额外法力条", key = "classResource_Mana", order = 4 })

    local function GetSpecOptions()
        local opts = {}
        if playerClass == "DRUID" then opts = { {text = L["Humanoid / None"] or "人形态 / 无形态", value = 1000}, {text = L["Cat Form"] or "猎豹形态", value = 1001}, {text = L["Bear Form"] or "熊形态", value = 1002}, {text = L["Moonkin Form"] or "枭兽形态", value = 1003}, {text = L["Travel Form"] or "旅行形态", value = 1004} }
        else local classID = select(3, UnitClass("player")); for i = 1, GetNumSpecializationsForClassID(classID) do local id, name = GetSpecializationInfoForClassID(classID, i); if id and name then table.insert(opts, {text = name, value = id}) end end; table.insert(opts, {text = L["No Spec / General"] or "无专精 / 通用", value = 0}) end
        return opts
    end

    local function GetTextureOptions()
        local opts = {}
        if LSM then
            local list = LSM:List("statusbar")
            if list then for i = 1, #list do table.insert(opts, { text = list[i], value = list[i] }) end end
        end
        if #opts == 0 then table.insert(opts, {text = "Wish2", value = "Wish2"}) end
        return opts
    end
    
    local function ForceSetButtonText(btn, text)
        if not btn then return end
        pcall(function() if type(btn.SetText) == "function" then btn:SetText(text) end end)
        for _, region in pairs({btn:GetRegions()}) do if region:IsObjectType("FontString") then pcall(function() region:SetText(text) end) end end
    end

    WF.UI:RegisterPanel("classResource_Global", function(scrollChild, ColW)
        local db = GetDB()
        local tempDB = { spec = CR.selectedSpecForConfig or GetCurrentContextID() }
        local specCfg = GetCurrentSpecConfig(tempDB.spec)
        local y = -10
        
        CR.ExpandState = CR.ExpandState or { global = false }

        local tGlobal = L["Global Settings"] or "全局排版设置"
        local btnGlobal = scrollChild.CR_BtnGlobal
        if not btnGlobal then
            btnGlobal = WF.UI.Factory:CreateFlatButton(scrollChild, "", function() CR.ExpandState.global = not CR.ExpandState.global; WF.UI:RefreshCurrentPanel() end)
            scrollChild.CR_BtnGlobal = btnGlobal
        end
        ForceSetButtonText(btnGlobal, tGlobal)
        btnGlobal:ClearAllPoints(); btnGlobal:SetPoint("TOPLEFT", 15, y); btnGlobal:SetWidth(ColW * 1.5); btnGlobal:Show()
        y = y - 35

        if CR.ExpandState.global then
            local flatOpts = {
                { type = "toggle", key = "enable", db = db, text = L["Enable Module"] or "启用资源条 (总控全局及监控条开关)", requireReload = true },
                { type = "dropdown", key = "texture", db = db, text = L["Global Texture"] or "全局材质", options = GetTextureOptions() },
                { type = "dropdown", key = "font", db = db, text = L["Global Font"] or "全局字体", options = WF.UI.FontOptions },
                { type = "dropdown", key = "spec", db = tempDB, text = L["Select Context"] or "【核心】当前编辑的专精", options = GetSpecOptions() },
                { type = "slider", key = "width", db = specCfg, text = L["Fixed Width"] or "全局定宽 (取消吸附时生效)", min=50, max=600, step=1 },
                { type = "slider", key = "yOffset", db = specCfg, text = L["Stack Y Offset"] or "统一行堆叠间距", min=0, max=50, step=1 },
                { type = "toggle", key = "alignWithCD", db = db, text = L["Align With CD Manager"] or "自动吸附到冷却管理器" },
                { type = "slider", key = "alignYOffset", db = db, text = L["Align Y Offset"] or "吸附时基础 Y 轴偏移", min = -50, max = 50, step = 1 },
                { type = "slider", key = "widthOffset", db = db, text = L["Width Compensation"] or "吸附时宽度强行补偿", min = -10, max = 10, step = 1 },
            }
            
            y = WF.UI:RenderOptionsGroup(scrollChild, 15, y, ColW * 1.5, flatOpts, function(val) 
                if tempDB.spec ~= CR.selectedSpecForConfig then 
                    CR.selectedSpecForConfig = tempDB.spec
                    WF.UI:RefreshCurrentPanel() 
                else 
                    CR:UpdateLayout()
                    if WF.WishMonitorAPI and WF.WishMonitorAPI.TriggerUpdate then WF.WishMonitorAPI:TriggerUpdate() end
                end 
            end)
            y = y - 10
        end
        
        -- ==========================================
        -- [排版层级预览条 - 独立常驻]
        -- ==========================================
        local tLbl = scrollChild.CR_SortTitle or scrollChild:CreateFontString(nil, "OVERLAY")
        scrollChild.CR_SortTitle = tLbl
        tLbl:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE"); tLbl:SetPoint("TOPLEFT", 15, y)
        tLbl:SetText(L["Unified Sort Title"] or "|cff00ccff[模块层级与排版预览]|r (点击预览条可快速编辑对应设置)")
        y = y - 30
        
        local sortOrder = db.sortOrder
        local itemDefs = {
            mana = { name = L["Extra Mana Bar"] or "额外法力条", color = {r=0, g=0.5, b=1}, tab = "classResource_Mana" },
            power = { name = L["Power Bar"] or "能量条", color = PLAYER_CLASS_COLOR, tab = "classResource_Power" },
            class = { name = L["Class Resource Bar"] or "主资源条", color = {r=1, g=0.96, b=0.41}, tab = "classResource_Class" },
            monitor = { name = L["Custom Monitor"] or "自定义监控 (WishMonitor)", color = {r=0.2, g=0.8, b=0.2}, tab = "classResource_Monitor" }
        }

        for i, key in ipairs(sortOrder) do
            local def = itemDefs[key]
            if def then
                local row = scrollChild["CR_SortRow_"..i] or CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
                scrollChild["CR_SortRow_"..i] = row
                row:SetSize(ColW * 1.5, 30); row:ClearAllPoints(); row:SetPoint("TOPLEFT", 15, y); row:RegisterForClicks("LeftButtonUp")
                
                if not row.sb then
                    row.sb = CreateFrame("StatusBar", nil, row); row.sb:SetAllPoints()
                    local border = CreateFrame("Frame", nil, row.sb, "BackdropTemplate")
                    border:SetAllPoints(); border:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
                    border:SetBackdropBorderColor(0,0,0,1); row.border = border
                    row.text = row.sb:CreateFontString(nil, "OVERLAY"); row.text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
                    
                    row.btnUp = CreateFrame("Button", nil, row)
                    row.btnUp:SetSize(24, 24); row.btnUp:SetPoint("RIGHT", row, "RIGHT", -30, 0); row.btnUp:SetFrameLevel(row.sb:GetFrameLevel() + 20)
                    row.btnUp.Text = row.btnUp:CreateFontString(nil, "OVERLAY")
                    row.btnUp.Text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); row.btnUp.Text:SetPoint("CENTER", 0, 0); row.btnUp.Text:SetText("▲")
                    
                    row.btnDown = CreateFrame("Button", nil, row)
                    row.btnDown:SetSize(24, 24); row.btnDown:SetPoint("RIGHT", row, "RIGHT", -2, 0); row.btnDown:SetFrameLevel(row.sb:GetFrameLevel() + 20)
                    row.btnDown.Text = row.btnDown:CreateFontString(nil, "OVERLAY")
                    row.btnDown.Text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); row.btnDown.Text:SetPoint("CENTER", 0, 0); row.btnDown.Text:SetText("▼")
                    
                    row.enableBtn = CreateFrame("Button", nil, row)
                    row.enableBtn:SetSize(60, 20); row.enableBtn:SetPoint("RIGHT", row.btnUp, "LEFT", -10, 0); row.enableBtn:SetFrameLevel(row.sb:GetFrameLevel() + 20)
                    row.enableBtn.Text = row.enableBtn:CreateFontString(nil, "OVERLAY")
                    row.enableBtn.Text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); row.enableBtn.Text:SetPoint("CENTER", 0, 0)
                end
                
                row.sb:SetStatusBarTexture(LSM:Fetch("statusbar", db.texture) or "Interface\\TargetingFrame\\UI-StatusBar")
                row.sb:SetStatusBarColor(def.color.r, def.color.g, def.color.b, 0.8)
                row.text:SetText(i .. ". " .. def.name)
                
                row:SetScript("OnEnter", function() 
                    row.border:SetBackdropBorderColor(1, 0.8, 0, 1)
                    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                    GameTooltip:AddLine((L["Click to configure: "] or "点击进入详细设置: ") .. def.name, 1, 1, 1)
                    GameTooltip:Show()
                end)
                row:SetScript("OnLeave", function() row.border:SetBackdropBorderColor(0, 0, 0, 1); GameTooltip:Hide() end)
                row:SetScript("OnClick", function()
                    if def.tab then
                        WF.UI.CurrentNodeKey = def.tab
                        WF.UI:RefreshCurrentPanel()
                        if type(WF.UI.RefreshMenu) == "function" then WF.UI:RefreshMenu() end
                        if type(WF.UI.RenderMenu) == "function" then WF.UI:RenderMenu() end
                    end
                end)
                
                if key ~= "monitor" then
                    local state = false
                    if key == "mana" then state = specCfg.showMana elseif key == "power" then state = specCfg.showPower elseif key == "class" then state = specCfg.showClass end
                    row.enableBtn.Text:SetText(state and (L["Module Enabled"] or "|cff00ff00[ 已启用 ]|r") or (L["Module Disabled"] or "|cffff0000[ 已禁用 ]|r"))
                    row.enableBtn:SetScript("OnClick", function()
                        if key == "mana" then specCfg.showMana = not specCfg.showMana elseif key == "power" then specCfg.showPower = not specCfg.showPower elseif key == "class" then specCfg.showClass = not specCfg.showClass end
                        WF.UI:RefreshCurrentPanel(); CR:UpdateLayout()
                    end)
                    row.enableBtn:Show(); row.text:SetPoint("LEFT", row, "LEFT", 10, 0)
                else
                    row.enableBtn:Hide(); row.text:SetPoint("LEFT", row, "LEFT", 10, 0)
                end
                
                row.btnUp:SetScript("OnClick", function()
                    if i > 1 then local temp = db.sortOrder[i-1]; db.sortOrder[i-1] = db.sortOrder[i]; db.sortOrder[i] = temp; WF.UI:RefreshCurrentPanel(); CR:UpdateLayout() end
                end)
                row.btnUp:SetEnabled(i > 1); row.btnUp:SetAlpha(i > 1 and 1 or 0.3)
                
                row.btnDown:SetScript("OnClick", function()
                    if i < #sortOrder then local temp = db.sortOrder[i+1]; db.sortOrder[i+1] = db.sortOrder[i]; db.sortOrder[i] = temp; WF.UI:RefreshCurrentPanel(); CR:UpdateLayout() end
                end)
                row.btnDown:SetEnabled(i < #sortOrder); row.btnDown:SetAlpha(i < #sortOrder and 1 or 0.3)
                
                row:Show(); y = y - 35
            end
        end
        for i = #sortOrder + 1, 10 do if scrollChild["CR_SortRow_"..i] then scrollChild["CR_SortRow_"..i]:Hide() end end
        
        return y
    end)

    WF.UI:RegisterPanel("classResource_Power", function(scrollChild, ColW)
        local specId = CR.selectedSpecForConfig or GetCurrentContextID()
        local db = GetCurrentSpecConfig(specId)
        local lineDB = { line = CR.selectedThresholdLine or 1 }
        local opts = { 
            { type = "group", key = "p2", text = L["Visuals"] or "视觉选项", childs = {
                { type = "slider", key = "height", db = db.power, text = L["Height"] or "高度", min=2, max=50, step=1 },
                { type = "toggle", key = "useCustomColor", db = db.power, text = L["Custom Color"] or "自定义前景色" },
                { type = "color", key = "customColor", db = db.power, text = L["Color"] or "颜色" },
            }},
            { type = "group", key = "p3", text = L["Text Layout"] or "文字排版", childs = {
                { type = "toggle", key = "textPower", db = db, text = L["Show Text"] or "启用并显示该层文本" },
                { type = "dropdown", key = "textFormat", db = db.power, text = L["Format"] or "格式", options = { {text="AUTO", value="AUTO"}, {text="PERCENT", value="PERCENT"}, {text="ABSOLUTE", value="ABSOLUTE"}, {text="BOTH", value="BOTH"}, {text="NONE", value="NONE"} } },
                { type = "dropdown", key = "textAnchor", db = db.power, text = L["Anchor"] or "对齐", options = WF.UI.AnchorOptions },
                { type = "slider", key = "xOffset", db = db.power, text = L["X Offset"] or "X 偏移", min=-200, max=200, step=1 },
                { type = "slider", key = "yOffset", db = db.power, text = L["Y Offset"] or "Y 偏移", min=-100, max=100, step=1 },
                { type = "slider", key = "fontSize", db = db.power, text = L["Font Size"] or "大小", min=8, max=40, step=1 },
                { type = "color", key = "color", db = db.power, text = L["Font Color"] or "文字颜色" },
            }},
            { type = "group", key = "p4", text = L["Threshold Lines"] or "多重刻度线", childs = {
                { type = "dropdown", key = "line", db = lineDB, text = L["Select Line"] or "选择刻度线", options = { {text="1", value=1}, {text="2", value=2}, {text="3", value=3}, {text="4", value=4}, {text="5", value=5} } },
                { type = "toggle", key = "enable", db = db.power.thresholdLines[lineDB.line], text = L["Enable"] or "启用" },
                { type = "slider", key = "value", db = db.power.thresholdLines[lineDB.line], text = L["Value"] or "触发数值", min=1, max=1000, step=1 },
                { type = "slider", key = "thickness", db = db.power.thresholdLines[lineDB.line], text = L["Thickness"] or "粗细", min=1, max=10, step=1 },
                { type = "color", key = "color", db = db.power.thresholdLines[lineDB.line], text = L["Color"] or "颜色" },
            }}
        }
        return WF.UI:RenderOptionsGroup(scrollChild, 15, -10, ColW * 1.5, opts, function() if lineDB.line ~= CR.selectedThresholdLine then CR.selectedThresholdLine = lineDB.line; WF.UI:RefreshCurrentPanel() else CR:UpdateLayout() end end)
    end)

    WF.UI:RegisterPanel("classResource_Class", function(scrollChild, ColW)
        local specId = CR.selectedSpecForConfig or GetCurrentContextID()
        local db = GetCurrentSpecConfig(specId)
        local cDB = { tempC = db.class.customColors[playerClass] or {r=1,g=1,b=1}, tempE = db.class.useCustomColors[playerClass] or false }
        local opts = {
            { type = "group", key = "c2", text = L["Visuals"] or "视觉选项", childs = {
                { type = "slider", key = "height", db = db.class, text = L["Height"] or "高度", min=2, max=50, step=1 },
                { type = "toggle", key = "tempE", db = cDB, text = L["Custom Color"] or "自定义前景色" },
                { type = "color", key = "tempC", db = cDB, text = L["Color"] or "颜色" },
            }},
            { type = "group", key = "c3", text = L["Text Layout"] or "文字排版", childs = {
                { type = "toggle", key = "textClass", db = db, text = L["Show Text"] or "启用并显示该层文本" },
                { type = "dropdown", key = "textFormat", db = db.class, text = L["Format"] or "格式", options = { {text="AUTO", value="AUTO"}, {text="PERCENT", value="PERCENT"}, {text="ABSOLUTE", value="ABSOLUTE"}, {text="BOTH", value="BOTH"}, {text="NONE", value="NONE"} } },
                { type = "dropdown", key = "textAnchor", db = db.class, text = L["Anchor"] or "对齐", options = WF.UI.AnchorOptions },
                { type = "slider", key = "xOffset", db = db.class, text = L["X Offset"] or "X 偏移", min=-200, max=200, step=1 },
                { type = "slider", key = "yOffset", db = db.class, text = L["Y Offset"] or "Y 偏移", min=-100, max=100, step=1 },
                { type = "slider", key = "fontSize", db = db.class, text = L["Font Size"] or "大小", min=8, max=40, step=1 },
                { type = "color", key = "color", db = db.class, text = L["Font Color"] or "文字颜色" },
            }}
        }
        return WF.UI:RenderOptionsGroup(scrollChild, 15, -10, ColW * 1.5, opts, function() db.class.useCustomColors[playerClass] = cDB.tempE; db.class.customColors[playerClass] = cDB.tempC; CR:UpdateLayout() end)
    end)

    WF.UI:RegisterPanel("classResource_Mana", function(scrollChild, ColW)
        local specId = CR.selectedSpecForConfig or GetCurrentContextID()
        local db = GetCurrentSpecConfig(specId)
        local opts = {
            { type = "group", key = "m2", text = L["Visuals"] or "视觉选项", childs = {
                { type = "slider", key = "height", db = db.mana, text = L["Height"] or "高度", min=2, max=50, step=1 },
                { type = "toggle", key = "useCustomColor", db = db.mana, text = L["Custom Color"] or "自定义前景色" },
                { type = "color", key = "customColor", db = db.mana, text = L["Color"] or "颜色" },
            }},
            { type = "group", key = "m3", text = L["Text Layout"] or "文字排版", childs = {
                { type = "toggle", key = "textMana", db = db, text = L["Show Text"] or "启用并显示该层文本" },
                { type = "dropdown", key = "textFormat", db = db.mana, text = L["Format"] or "格式", options = { {text="AUTO", value="AUTO"}, {text="PERCENT", value="PERCENT"}, {text="ABSOLUTE", value="ABSOLUTE"}, {text="BOTH", value="BOTH"}, {text="NONE", value="NONE"} } },
                { type = "dropdown", key = "textAnchor", db = db.mana, text = L["Anchor"] or "对齐", options = WF.UI.AnchorOptions },
                { type = "slider", key = "xOffset", db = db.mana, text = L["X Offset"] or "X 偏移", min=-200, max=200, step=1 },
                { type = "slider", key = "yOffset", db = db.mana, text = L["Y Offset"] or "Y 偏移", min=-100, max=100, step=1 },
                { type = "slider", key = "fontSize", db = db.mana, text = L["Font Size"] or "大小", min=8, max=40, step=1 },
                { type = "color", key = "color", db = db.mana, text = L["Font Color"] or "文字颜色" },
            }}
        }
        return WF.UI:RenderOptionsGroup(scrollChild, 15, -10, ColW * 1.5, opts, function() CR:UpdateLayout() end)
    end)
end