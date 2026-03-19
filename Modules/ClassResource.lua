local AddonName, ns = ...
local WF = ns.WF
local L = ns.L or {}
local LSM = LibStub("LibSharedMedia-3.0", true)

local CR = CreateFrame("Frame")
WF.ClassResourceAPI = CR

local playerClass = select(2, UnitClass("player"))
local hasHealerSpec = (playerClass == "PALADIN" or playerClass == "PRIEST" or playerClass == "SHAMAN" or playerClass == "MONK" or playerClass == "DRUID" or playerClass == "EVOKER")

-- =========================================
-- [安全数据池与内存预分配]
-- =========================================
CR.CustomBars = {}
CR.ActiveAuraBars = {}
CR.chargeDurCache = {}
CR.spellMaxChargeCache = {}
CR.fastTrackedAuras = {}
CR.manualAuraTrackers = {}
CR.AuraBarPool = {}

local activeBuffFrames = {}
local targetAuraCache = {}
local playerAuraCache = {}
local BaseSpellCache = {}

local barDefaults = {
    power = { independent = false, barXOffset = 0, barYOffset = 0, height = 14, textEnable = true, textFormat = "AUTO", textAnchor = "CENTER", font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = true, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=0, g=0.5, b=1}, useCustomTexture = false, texture = "Blizzard", useCustomBgTexture = false, bgTexture = "Blizzard", bgColor = {r=0, g=0, b=0, a=0.5} },
    class = { independent = false, barXOffset = 0, barYOffset = 0, height = 12, textEnable = true, textFormat = "AUTO", textAnchor = "CENTER", font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = true, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=1, g=0.96, b=0.41}, useCustomTexture = false, texture = "Blizzard", useCustomBgTexture = false, bgTexture = "Blizzard", bgColor = {r=0, g=0, b=0, a=0.5} },
    mana = { independent = false, barXOffset = 0, barYOffset = 0, height = 10, textEnable = true, textFormat = "AUTO", textAnchor = "CENTER", font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, xOffset = 0, yOffset = 0, timerEnable = true, timerAnchor = "CENTER", timerXOffset = 0, timerYOffset = 0, useCustomColor = false, customColor = {r=0, g=0.5, b=1}, useCustomTexture = false, texture = "Blizzard", useCustomBgTexture = false, bgTexture = "Blizzard", bgColor = {r=0, g=0, b=0, a=0.5} },
    auraBar = { independent = false, barXOffset = 0, barYOffset = 0, height = 14, spacing = 1, growth = "UP", useCustomTexture = false, texture = "Blizzard", bgColor = {r=0.2, g=0.2, b=0.2, a=0.8}, font = "Expressway", fontSize = 12, outline = "OUTLINE", color = {r=1, g=1, b=1}, textPosition = "RIGHT", xOffset = -4, yOffset = 0, stackFont = "Expressway", stackFontSize = 14, stackOutline = "OUTLINE", stackColor = {r=1, g=1, b=1}, stackPosition = "LEFT", stackXOffset = 4, stackYOffset = 0 }
}
local defaults = { enable = true, hideElvUIBars = true, alignWithCD = false, alignYOffset = 1, widthOffset = 2, texture = "Blizzard", specConfigs = {} }

local DEFAULT_COLOR = {r=1, g=1, b=1}
local POWER_COLORS = { [0]={r=0,g=0.5,b=1}, [1]={r=1,g=0,b=0}, [2]={r=1,g=0.5,b=0.25}, [3]={r=1,g=1,b=0}, [4]={r=1,g=0.96,b=0.41}, [5]={r=0.8,g=0.1,b=0.2}, [7]={r=0.5,g=0.32,b=0.55}, [8]={r=0.3,g=0.52,b=0.9}, [9]={r=0.95,g=0.9,b=0.6}, [11]={r=0,g=0.5,b=1}, [12]={r=0.71,g=1,b=0.92}, [13]={r=0.4,g=0,b=0.8}, [16]={r=0.1,g=0.1,b=0.98}, [17]={r=0.79,g=0.26,b=0.99}, [18]={r=1,g=0.61,b=0}, [19]={r=0.4,g=0.8,b=1} }
local PLAYER_CLASS_COLOR = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass] or DEFAULT_COLOR

local function DeepMerge(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then if type(target[k]) ~= "table" then target[k] = {} end; DeepMerge(target[k], v)
        else if target[k] == nil then target[k] = v end end
    end
end

local function GetDB()
    if not WishFlexDB then WishFlexDB = {} end
    if type(WishFlexDB.classResource) ~= "table" then WishFlexDB.classResource = {} end
    DeepMerge(WishFlexDB.classResource, defaults)
    return WishFlexDB.classResource
end

local function GetSpellDB()
    if not WishFlexDB then WishFlexDB = {} end
    if not WishFlexDB.global then WishFlexDB.global = {} end
    if type(WishFlexDB.global.spellDB) ~= "table" then WishFlexDB.global.spellDB = {} end
    return WishFlexDB.global.spellDB
end

-- =========================================
-- [VFlow 黑科技核心：Arc Detector 解密引擎]
-- =========================================
local function IsSecret(v) return type(v) == "number" and issecretvalue and issecretvalue(v) end
local function IsSafeValue(val) if val == nil then return false end if type(issecretvalue) == "function" and issecretvalue(val) then return false end return true end

local function GetArcDetector(barFrame, threshold)
    barFrame._arcDetectors = barFrame._arcDetectors or {}
    local det = barFrame._arcDetectors[threshold]
    if det then return det end
    det = CreateFrame("StatusBar", nil, barFrame)
    det:SetSize(1, 1); det:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", 0, 0)
    det:SetAlpha(0); det:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    det:SetMinMaxValues(threshold - 1, threshold); det:EnableMouse(false)
    barFrame._arcDetectors[threshold] = det
    return det
end

local function GetSecretValueCount(barFrame, secretVal, maxVal)
    if not IsSecret(secretVal) then return tonumber(secretVal) or 0 end
    local m = (type(maxVal) == "number" and maxVal > 0) and maxVal or 10
    for i = 1, m do GetArcDetector(barFrame, i):SetValue(secretVal) end
    local count = 0
    for i = 1, m do
        local det = barFrame._arcDetectors[i]
        if det and det:GetStatusBarTexture():IsShown() then count = i else break end
    end
    return count
end

local function SafeFormatNum(v)
    local num = tonumber(v) or 0
    if num >= 1e6 then return string.format("%.1fm", num / 1e6):gsub("%.0m", "m")
    elseif num >= 1e3 then return string.format("%.1fk", num / 1e3):gsub("%.0k", "k")
    else return string.format("%.0f", num) end
end

-- =========================================
-- [环境、排版与数据获取]
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
CR.GetCurrentContextID = GetCurrentContextID

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
    
    if type(cfg.power) ~= "table" then cfg.power = {} end; DeepMerge(cfg.power, barDefaults.power)
    if type(cfg.class) ~= "table" then cfg.class = {} end; DeepMerge(cfg.class, barDefaults.class)
    if type(cfg.mana) ~= "table" then cfg.mana = {} end; DeepMerge(cfg.mana, barDefaults.mana)
    if type(cfg.auraBar) ~= "table" then cfg.auraBar = {} end; DeepMerge(cfg.auraBar, barDefaults.auraBar)
    return cfg
end

local function GetTargetWidth(cfg)
    local db = GetDB()
    if db.alignWithCD and WishFlexDB.cooldownCustom and WishFlexDB.cooldownCustom.Essential and _G.EssentialCooldownViewer then
        local cdDB = WishFlexDB.cooldownCustom.Essential
        local maxPerRow = tonumber(cdDB.maxPerRow) or 7
        local w = tonumber(cdDB.row1Width) or tonumber(cdDB.width) or 45
        local gap = tonumber(cdDB.iconGap) or 2
        return (maxPerRow * w) + ((maxPerRow - 1) * gap) + (tonumber(db.widthOffset) or 2)
    end
    return tonumber(cfg.width) or 250
end

local function GetSafeColor(cfg, defColor)
    if cfg and cfg.useCustomColor and type(cfg.customColor) == "table" and type(cfg.customColor.r) == "number" then return cfg.customColor end
    if type(defColor) == "table" and type(defColor.r) == "number" then return defColor end
    return DEFAULT_COLOR
end

local function GetPowerColor(pType) return POWER_COLORS[pType] or DEFAULT_COLOR end

-- =========================================
-- [框体生成与样式格式化]
-- =========================================
local function ApplyFontString(fs, fontPath, size, outline, anchor, x, y, r, g, b, a)
    if not fs then return end
    if outline == "NONE" then outline = "" end
    fs:SetFont(fontPath, size, outline)
    fs:SetTextColor(r or 1, g or 1, b or 1, a or 1)
    fs:ClearAllPoints()
    fs:SetPoint(anchor, fs:GetParent(), anchor, x or 0, y or 0)
    fs:SetJustifyH(anchor:match("LEFT") and "LEFT" or (anchor:match("RIGHT") and "RIGHT" or "CENTER"))
end

local function UpdateDividers(bar, maxVal)
    bar.dividers = bar.dividers or {}
    local numMax = tonumber(maxVal) or 1
    if numMax <= 0 then numMax = 1 end; if numMax > 20 then numMax = 20 end 
    local width = bar:GetWidth() or 250
    if bar._lastDividerMax == numMax and bar._lastDividerWidth == width then return end
    bar._lastDividerMax = numMax; bar._lastDividerWidth = width
    local numDividers = numMax > 1 and (numMax - 1) or 0
    local segWidth = width / numMax
    
    for i = 1, numDividers do
        if not bar.dividers[i] then
            local tex = bar:CreateTexture(nil, "OVERLAY", nil, 7)
            tex:SetColorTexture(0, 0, 0, 1); tex:SetWidth(1); bar.dividers[i] = tex
        end
        bar.dividers[i]:ClearAllPoints()
        bar.dividers[i]:SetPoint("TOPLEFT", bar, "TOPLEFT", segWidth * i, 0)
        bar.dividers[i]:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", segWidth * i, 0)
        bar.dividers[i]:Show()
    end
    for i = numDividers + 1, #bar.dividers do if bar.dividers[i] then bar.dividers[i]:Hide() end end
end

local function CreateStandardBar(name, parent)
    local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
    frame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8); frame:SetBackdropBorderColor(0, 0, 0, 1)

    local sb = CreateFrame("StatusBar", nil, frame)
    sb:SetPoint("TOPLEFT", 1, -1); sb:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.statusBar = sb
    
    local bg = sb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); sb.bg = bg

    local textFrame = CreateFrame("Frame", nil, frame)
    textFrame:SetAllPoints(frame); textFrame:SetFrameLevel(frame:GetFrameLevel() + 10)
    frame.textFrame = textFrame
    
    frame.text = textFrame:CreateFontString(nil, "OVERLAY") 
    frame.timerText = textFrame:CreateFontString(nil, "OVERLAY")
    frame.stackText = textFrame:CreateFontString(nil, "OVERLAY") 
    
    local cd = CreateFrame("Cooldown", nil, sb, "CooldownFrameTemplate")
    cd:SetAllPoints(); cd:SetDrawSwipe(false); cd:SetDrawEdge(false); cd:SetDrawBling(false); cd:SetHideCountdownNumbers(true)
    cd.noCooldownOverride = true; cd.noOCC = true; cd:SetFrameLevel(frame:GetFrameLevel() + 20); frame.cd = cd
    
    return frame
end

local function UpdateStatusBarVisuals(frame, cfg, globalTex, globalBg)
    local texName = (cfg.useCustomTexture and cfg.texture) and cfg.texture or globalTex
    local tex = (LSM and LSM:Fetch("statusbar", texName)) or "Interface\\TargetingFrame\\UI-StatusBar"
    frame.statusBar:SetStatusBarTexture(tex)
    
    local bgTexName = (cfg.useCustomBgTexture and cfg.bgTexture) and cfg.bgTexture or globalBg
    local bgTex = (LSM and LSM:Fetch("statusbar", bgTexName)) or tex
    frame.statusBar.bg:SetTexture(bgTex)
    
    local bgc = cfg.bgColor or {r=0, g=0, b=0, a=0.5}
    frame.statusBar.bg:SetVertexColor(bgc.r, bgc.g, bgc.b, bgc.a)

    local fontPath = (LSM and LSM:Fetch("font", cfg.font)) or STANDARD_TEXT_FONT
    local sFontPath = (LSM and LSM:Fetch("font", cfg.stackFont or cfg.font)) or STANDARD_TEXT_FONT
    
    ApplyFontString(frame.text, fontPath, cfg.fontSize or 12, cfg.outline, cfg.textAnchor or "CENTER", cfg.xOffset, cfg.yOffset, cfg.color and cfg.color.r, cfg.color and cfg.color.g, cfg.color and cfg.color.b)
    ApplyFontString(frame.timerText, fontPath, cfg.fontSize or 12, cfg.outline, cfg.timerAnchor or "CENTER", cfg.timerXOffset, cfg.timerYOffset, cfg.color and cfg.color.r, cfg.color and cfg.color.g, cfg.color and cfg.color.b)
    ApplyFontString(frame.stackText, sFontPath, cfg.stackFontSize or 14, cfg.stackOutline, cfg.stackPosition or "LEFT", cfg.stackXOffset, cfg.stackYOffset, cfg.stackColor and cfg.stackColor.r, cfg.stackColor and cfg.stackColor.g, cfg.stackColor and cfg.stackColor.b)
end

-- =========================================
-- [安全数值抓取与状态更新]
-- =========================================
function CR:UpdateAllStates()
    if not self.baseAnchor then return end
    local specCfg = GetCurrentSpecConfig()
    local pType = UnitPowerType("player")

    -- 1. 能量条
    if self.showPower then
        local rawMax = UnitPowerMax("player", pType)
        local rawCurr = UnitPower("player", pType)
        local safeMax = GetSecretValueCount(self.powerBar, rawMax, 100)
        local safeCurr = GetSecretValueCount(self.powerBar, rawCurr, safeMax)
        if safeMax <= 0 then safeMax = 1 end
        
        self.powerBar.statusBar:SetMinMaxValues(0, safeMax)
        self.powerBar.statusBar:SetValue(safeCurr)
        local c = specCfg.power.useCustomColor and specCfg.power.customColor or GetPowerColor(pType)
        self.powerBar.statusBar:SetStatusBarColor(c.r, c.g, c.b)
        UpdateDividers(self.powerBar.statusBar, 1)
        if specCfg.power.textEnable then self.powerBar.text:SetText(SafeFormatNum(safeCurr)); self.powerBar.text:Show() else self.powerBar.text:Hide() end
    end

    -- 2. 主资源条 (连击点/符文/冰刺等)
    if self.showClass then
        local rawCurr, rawMax = 0, 5
        pcall(function() 
            if playerClass == "ROGUE" or playerClass == "DRUID" then rawCurr = UnitPower("player", 4); rawMax = UnitPowerMax("player", 4)
            elseif playerClass == "PALADIN" then rawCurr = UnitPower("player", 9); rawMax = 5
            elseif playerClass == "MONK" then rawCurr = UnitPower("player", 12); rawMax = UnitPowerMax("player", 12)
            elseif playerClass == "MAGE" then rawCurr = UnitPower("player", 16); rawMax = 4
            elseif playerClass == "WARLOCK" then rawCurr = UnitPower("player", 7); rawMax = 5
            elseif playerClass == "EVOKER" then rawCurr = UnitPower("player", 19); rawMax = UnitPowerMax("player", 19)
            elseif playerClass == "DEATHKNIGHT" then rawCurr = UnitPower("player", 5); rawMax = 6
            end
        end)
        
        local safeMax = GetSecretValueCount(self.classBar, rawMax, 10)
        local safeCurr = GetSecretValueCount(self.classBar, rawCurr, safeMax)
        if safeMax <= 0 then safeMax = 5 end
        
        local c = specCfg.class.useCustomColor and specCfg.class.customColor or PLAYER_CLASS_COLOR
        self.classBar.statusBar:SetMinMaxValues(0, safeMax)
        self.classBar.statusBar:SetValue(safeCurr)
        self.classBar.statusBar:SetStatusBarColor(c.r, c.g, c.b)
        UpdateDividers(self.classBar.statusBar, safeMax)
        if specCfg.class.textEnable and safeCurr > 0 then self.classBar.text:SetText(safeCurr); self.classBar.text:Show() else self.classBar.text:Hide() end
    end

    -- 3. 额外法力条
    if self.showMana then
        local rawMax = UnitPowerMax("player", 0)
        local rawCurr = UnitPower("player", 0)
        local safeMax = GetSecretValueCount(self.manaBar, rawMax, 100)
        local safeCurr = GetSecretValueCount(self.manaBar, rawCurr, safeMax)
        if safeMax <= 0 then safeMax = 1 end
        
        self.manaBar.statusBar:SetMinMaxValues(0, safeMax)
        self.manaBar.statusBar:SetValue(safeCurr)
        local c = specCfg.mana.useCustomColor and specCfg.mana.customColor or POWER_COLORS[0]
        self.manaBar.statusBar:SetStatusBarColor(c.r, c.g, c.b)
        UpdateDividers(self.manaBar.statusBar, 1)
        if specCfg.mana.textEnable then self.manaBar.text:SetText(SafeFormatNum(safeCurr)); self.manaBar.text:Show() else self.manaBar.text:Hide() end
    end

    -- 4. 自定义光环监控 (Aura / Charge / Consume)
    for spellID, frame in pairs(self.CustomBars) do
        local v = frame.cfg
        local isCharge = (v.trackType == "charge")
        local isConsume = (v.trackType == "consume")
        local mode = v.mode or "time"
        
        local active = false
        local stacks, maxStacks = 0, v.maxStacks or 5
        local durObj = nil

        if isCharge then
            local cInfo = C_Spell.GetSpellCharges(spellID)
            if cInfo then
                active = (cInfo.currentCharges > 0)
                stacks = cInfo.currentCharges
                maxStacks = cInfo.maxCharges
                if IsSecret(maxStacks) then maxStacks = v.maxStacks or 2 end
                pcall(function() durObj = C_Spell.GetSpellChargeDuration(spellID) end)
                if durObj then active = true end
            end
        else
            -- 优先检测玩家自己
            local auraData = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
            if auraData then
                active = true; stacks = auraData.applications or 0
                pcall(function() durObj = C_UnitAuras.GetAuraDuration("player", auraData.auraInstanceID) end)
            else
                -- 检测目标身上的 Debuff
                for i = 1, 40 do
                    local d = C_UnitAuras.GetAuraDataByIndex("target", i, "HARMFUL")
                    if not d then break end
                    if d.spellId == spellID then
                        active = true; stacks = d.applications or 0
                        pcall(function() durObj = C_UnitAuras.GetAuraDuration("target", d.auraInstanceID) end)
                        break
                    end
                end
            end
        end

        local forceShow = (v.visibility == 2) or (v.visibility == 3 and InCombatLockdown())
        if active or forceShow then
            frame:Show()
            frame:SetAlpha(active and 1 or (v.inactiveAlpha or 1))

            local realStacks = GetSecretValueCount(frame, stacks, maxStacks)
            local c = v.color or {r=0, g=0.8, b=1, a=1}
            if v.useThresholdColor and realStacks >= (v.thresholdStacks or 3) then c = v.thresholdColor or {r=1,g=0,b=0,a=1} end
            
            frame.statusBar:SetStatusBarColor(c.r, c.g, c.b, c.a)
            frame.statusBar:SetReverseFill(v.reverseFill or false)
            
            if specCfg.textAuraStack and realStacks > 0 then frame.stackText:SetText(realStacks); frame.stackText:Show() else frame.stackText:Hide() end

            if mode == "time" then
                UpdateDividers(frame.statusBar, 1)
                frame.statusBar:SetMinMaxValues(0, 1)
                if active and durObj then
                    frame.statusBar:SetTimerDuration(durObj, 1, v.reverseFill and 1 or 0)
                    if specCfg.textAuraTimer then 
                        local remain = durObj.expirationTime - GetTime()
                        frame.timerText:SetText(remain > 0 and SafeFormatNum(remain) or "")
                        frame.timerText:Show()
                    else frame.timerText:Hide() end
                else
                    frame.statusBar:ClearTimerDuration()
                    frame.statusBar:SetValue(active and 1 or 0)
                    frame.timerText:Hide()
                end
            else
                -- Stack / Charge 模式
                frame.statusBar:ClearTimerDuration()
                UpdateDividers(frame.statusBar, maxStacks)
                frame.statusBar:SetMinMaxValues(0, maxStacks)
                frame.statusBar:SetValue(realStacks)
                
                -- VFlow 充能动画层
                if isCharge and durObj then
                    if not frame.rechargeOverlay then 
                        frame.rechargeOverlay = CreateFrame("StatusBar", nil, frame.statusBar)
                        frame.rechargeOverlay:SetFrameLevel(frame.statusBar:GetFrameLevel() + 1)
                    end
                    frame.rechargeOverlay:SetStatusBarTexture(frame.statusBar:GetStatusBarTexture():GetTexture())
                    frame.rechargeOverlay:SetStatusBarColor(c.r, c.g, c.b, c.a or 0.8)
                    frame.rechargeOverlay:SetReverseFill(v.reverseFill or false)
                    frame.rechargeOverlay:ClearAllPoints()
                    if v.reverseFill then frame.rechargeOverlay:SetPoint("RIGHT", frame.statusBar:GetStatusBarTexture(), "LEFT", 0, 0)
                    else frame.rechargeOverlay:SetPoint("LEFT", frame.statusBar:GetStatusBarTexture(), "RIGHT", 0, 0) end
                    frame.rechargeOverlay:SetWidth((frame:GetWidth() or 250) / maxStacks)
                    frame.rechargeOverlay:SetHeight(frame.statusBar:GetHeight())
                    frame.rechargeOverlay:SetTimerDuration(durObj, 0, Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime or 0)
                    frame.rechargeOverlay:Show()
                    
                    if specCfg.textAuraTimer then 
                        local remain = durObj.expirationTime - GetTime()
                        frame.timerText:SetText(remain > 0 and SafeFormatNum(remain) or "")
                        frame.timerText:Show()
                    else frame.timerText:Hide() end
                else
                    if frame.rechargeOverlay then frame.rechargeOverlay:Hide(); frame.rechargeOverlay:ClearTimerDuration() end
                    frame.timerText:Hide()
                end
            end
        else
            frame:Hide()
            frame.statusBar:ClearTimerDuration()
            if frame.rechargeOverlay then frame.rechargeOverlay:ClearTimerDuration() end
        end
    end
end

-- =========================================
-- [排版工厂：自定义监控池管理]
-- =========================================
function CR:BuildCustomBars()
    local sDB = GetSpellDB()
    local currentSpecID = GetCurrentContextID()
    local db = GetDB()
    
    for _, f in pairs(self.CustomBars) do f:Hide(); f.cfg = nil end

    for spellIDStr, data in pairs(sDB) do
        local v = data.auraBar
        if v and v.enable and (not data.class or data.class == "ALL" or data.class == playerClass) then
            local sSpec = data.spec or 0
            if sSpec == 0 or sSpec == currentSpecID then
                local spellID = tonumber(spellIDStr)
                if not self.CustomBars[spellID] then
                    self.CustomBars[spellID] = CreateStandardBar("WishFlexCustomBar_"..spellID, self.auraAnchor)
                end
                local frame = self.CustomBars[spellID]
                frame.spellID = spellID
                frame.cfg = v
            end
        end
    end
end

function CR:UpdateLayout()
    if not self.baseAnchor then return end
    local db = GetDB()
    if not db.enable then 
        self.baseAnchor:Hide(); self.powerAnchor:Hide(); self.classAnchor:Hide(); self.manaAnchor:Hide(); self.auraAnchor:Hide()
        return 
    end

    local specCfg = GetCurrentSpecConfig()
    self:BuildCustomBars()

    local targetWidth = GetTargetWidth(specCfg)
    self.baseAnchor:Show()
    self.baseAnchor:SetSize(targetWidth, 14)

    local globalTex = db.texture or "Blizzard"
    
    UpdateStatusBarVisuals(self.powerBar, specCfg.power, globalTex, globalTex)
    UpdateStatusBarVisuals(self.classBar, specCfg.class, globalTex, globalTex)
    UpdateStatusBarVisuals(self.manaBar, specCfg.mana, globalTex, globalTex)

    for _, frame in pairs(self.CustomBars) do
        local targetW = targetWidth
        local targetH = specCfg.auraBar.height or 14
        if frame.cfg.useCustomSize then targetW = frame.cfg.customWidth or targetW; targetH = frame.cfg.customHeight or targetH end
        frame:SetSize(targetW, targetH)
        UpdateStatusBarVisuals(frame, specCfg.auraBar, globalTex, globalTex)
    end

    self.showPower = specCfg.showPower and (GetSafeNumber(UnitPowerMax("player", UnitPowerType("player")), 0) > 0)
    self.showClass = specCfg.showClass
    self.showMana = specCfg.showMana and hasHealerSpec

    -- 基础条排版
    local stackOrder = {
        { bar = self.manaBar,     show = self.showMana,  cfg = specCfg.mana,    anchor = self.manaAnchor },
        { bar = self.powerBar,    show = self.showPower, cfg = specCfg.power,   anchor = self.powerAnchor },
        { bar = self.classBar,    show = self.showClass, cfg = specCfg.class,   anchor = self.classAnchor },
        { bar = self.auraAnchor,  show = specCfg.showAuraBar, cfg = specCfg.auraBar, anchor = self.auraAnchor, isAura = true }
    }

    local lastStackedFrame = nil
    for _, item in ipairs(stackOrder) do
        local f = item.bar
        if item.show and item.cfg then
            f:Show()
            if not item.isAura then f:SetSize(targetWidth, tonumber(item.cfg.height) or 14) else f:SetSize(targetWidth, 1) end
            f:ClearAllPoints()
            if item.cfg.independent then
                f:SetPoint("CENTER", item.anchor.mover or item.anchor, "CENTER", tonumber(item.cfg.barXOffset) or 0, tonumber(item.cfg.barYOffset) or 0)
            else
                if not lastStackedFrame then
                    if db.alignWithCD and WishFlexDB.cooldownCustom and WishFlexDB.cooldownCustom.Essential and _G.EssentialCooldownViewer then
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
            if not item.isAura then f:Hide() end
        end
    end

    -- 增益组排版
    local activeBars = {}
    for _, frame in pairs(self.CustomBars) do table.insert(activeBars, frame) end
    table.sort(activeBars, function(a, b) return a.spellID < b.spellID end)

    local stackedAuras = {}
    local splitAuras = {}

    for _, bar in ipairs(activeBars) do
        bar:ClearAllPoints()
        if bar.cfg.useHorizontalSplit then table.insert(splitAuras, bar)
        elseif bar.cfg.useIndependentPosition then bar:SetPoint("CENTER", self.auraAnchor, "CENTER", bar.cfg.customXOffset or 0, bar.cfg.customYOffset or 0)
        else table.insert(stackedAuras, bar) end
    end

    local numSplit = #splitAuras
    if numSplit > 0 then
        local gap = splitAuras[1].cfg.splitSpacing or 2
        local eachWidth = math.max(1, (targetWidth - (gap * (numSplit - 1))) / numSplit)
        local startX = -targetWidth / 2 + eachWidth / 2
        for i = 1, numSplit do
            local bar = splitAuras[i]
            bar:SetWidth(eachWidth) 
            bar:SetPoint("CENTER", self.auraAnchor, "CENTER", startX, bar.cfg.customYOffset or 0)
            startX = startX + eachWidth + gap
        end
    end

    for i = 1, #stackedAuras do
        local bar = stackedAuras[i]
        if i == 1 then bar:SetPoint("BOTTOM", self.auraAnchor, "BOTTOM", 0, 0)
        else
            local prev = stackedAuras[i-1]
            if specCfg.auraBar.growth == "UP" then bar:SetPoint("BOTTOM", prev, "TOP", 0, specCfg.auraBar.spacing or 1)
            else bar:SetPoint("TOP", prev, "BOTTOM", 0, -(specCfg.auraBar.spacing or 1)) end
        end
    end

    self:UpdateAllStates()
end

-- =========================================
-- [初始化注册]
-- =========================================
local function InitClassResource()
    GetDB() 

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

    CR.powerBar = CreateStandardBar("WishFlex_PowerBar", UIParent)
    CR.classBar = CreateStandardBar("WishFlex_ClassBar", UIParent)
    CR.manaBar = CreateStandardBar("WishFlex_ManaBar", UIParent)
    
    CR:RegisterEvent("PLAYER_ENTERING_WORLD")
    CR:RegisterEvent("UNIT_DISPLAYPOWER")
    CR:RegisterEvent("UNIT_MAXPOWER")
    CR:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    CR:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    CR:RegisterEvent("UNIT_POWER_UPDATE")
    CR:RegisterEvent("UNIT_POWER_FREQUENT")
    
    CR:SetScript("OnEvent", function(self, event, unit)
        if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "UPDATE_SHAPESHIFT_FORM" then self:UpdateLayout()
        elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" then if unit == "player" then self:UpdateAllStates() end
        end
    end)
    
    if EventRegistry then
        EventRegistry:RegisterCallback("UNIT_AURA", function(e, u) if u == "player" or u == "target" then CR:UpdateAllStates() end end)
        EventRegistry:RegisterCallback("PLAYER_TARGET_CHANGED", function() CR:UpdateAllStates() end)
        EventRegistry:RegisterCallback("SPELL_UPDATE_CHARGES", function() CR:UpdateAllStates() end)
        EventRegistry:RegisterCallback("SPELL_UPDATE_COOLDOWN", function() CR:UpdateAllStates() end)
    end
    
    -- 仅保留时间文本的极低频更新（节省 90% CPU 性能）
    local ticker = 0
    CR.baseAnchor:SetScript("OnUpdate", function(_, elapsed)
        ticker = ticker + elapsed
        if ticker >= 0.1 then
            ticker = 0
            CR:UpdateAllStates()
        end
    end)
    
    CR:UpdateLayout()
end

WF:RegisterModule("classResource", "资源条", InitClassResource)