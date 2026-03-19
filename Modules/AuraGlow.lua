local AddonName, ns = ...
local WF = ns.WF
local L = ns.L

-- =========================================
-- [外部库与本地化]
-- =========================================
local LSM = LibStub("LibSharedMedia-3.0", true)
local LCG = LibStub("LibCustomGlow-1.0", true)

local AuraGlowMod = CreateFrame("Frame")
AuraGlowMod.hiddenAuras = {}
local BaseSpellCache = {}
local targetAuraCache = {}

local activeSkillFrames = {}
local activeBuffFrames = {}
local playerClass = select(2, UnitClass("player"))

local OverlayFrames = {}       
local IndependentFrames = {}   
AuraGlowMod.trackedAuras = {} 
AuraGlowMod.manualTrackers = {} 

-- =========================================
-- [默认配置]
-- =========================================
local DefaultConfig = {
    enable = true,
    independent = { size = 45, gap = 2, growth = "LEFT" },
    text = { font = "Expressway", fontSize = 20, fontOutline = "OUTLINE", color = {r = 1, g = 0.82, b = 0}, textAnchor = "CENTER", offsetX = 0, offsetY = 0 },
    independentText = { enable = false, font = "Expressway", fontSize = 20, fontOutline = "OUTLINE", color = {r = 1, g = 0.82, b = 0}, textAnchor = "CENTER", offsetX = 0, offsetY = 0 },
    
    glowEnable = true, glowType = "pixel", glowUseCustomColor = false, glowColor = {r = 1, g = 0.82, b = 0, a = 1},
    glowPixelLines = 8, glowPixelFrequency = 0.25, glowPixelLength = 0, glowPixelThickness = 2, glowPixelXOffset = 0, glowPixelYOffset = 0,
    glowAutocastParticles = 4, glowAutocastFrequency = 0.2, glowAutocastScale = 1, glowAutocastXOffset = 0, glowAutocastYOffset = 0,
    glowButtonFrequency = 0, glowProcDuration = 1, glowProcXOffset = 0, glowProcYOffset = 0,
}

-- =========================================
-- [核心工具函数]
-- =========================================
local function GetSpellDB()
    if not WishFlexDB.global then WishFlexDB.global = {} end
    if type(WishFlexDB.global.spellDB) ~= "table" then WishFlexDB.global.spellDB = {} end
    return WishFlexDB.global.spellDB
end

local function IsSafeValue(val) return val ~= nil and (type(issecretvalue) ~= "function" or not issecretvalue(val)) end

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
    if info.linkedSpellIDs then 
        for i = 1, #info.linkedSpellIDs do 
            if IsSafeValue(info.linkedSpellIDs[i]) and info.linkedSpellIDs[i] == targetID then return true end 
        end 
    end
    return GetBaseSpellFast(info.spellID) == targetID
end

local function VerifyAuraAlive(checkID, checkUnit)
    if not IsSafeValue(checkID) then return false end
    local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(checkUnit, checkID)
    return auraData ~= nil
end

local function GetCropCoords(w, h)
    local l, r, t, b = 0.08, 0.92, 0.08, 0.92 -- 原生裁切比例
    if not w or not h or h == 0 or w == 0 then return l, r, t, b end
    local ratio = w / h
    if math.abs(ratio - 1) < 0.05 then return l, r, t, b end
    if ratio > 1 then
        local crop = (1 - (1/ratio)) / 2; return l, r, t + (b - t) * crop, b - (b - t) * crop
    else
        local crop = (1 - ratio) / 2; return l + (r - l) * crop, r - (r - l) * crop, t, b
    end
end

-- =========================================
-- [UI 视觉与渲染]
-- =========================================
local function SyncTextAndVisuals(frame)
    local globalCfg = WF.db.auraGlow.text
    local indCfg = WF.db.auraGlow.independentText
    local cfg = (frame.isIndependent and indCfg.enable) and indCfg or globalCfg

    local fontPath = (LSM and LSM:Fetch('font', cfg.font)) or STANDARD_TEXT_FONT
    if frame.lastFont ~= fontPath or frame.lastSize ~= cfg.fontSize or frame.lastOutline ~= cfg.fontOutline then
        frame.durationText:SetFont(fontPath, cfg.fontSize, cfg.fontOutline)
        frame.lastFont, frame.lastSize, frame.lastOutline = fontPath, cfg.fontSize, cfg.fontOutline
    end
    if frame.lastR ~= cfg.color.r or frame.lastG ~= cfg.color.g or frame.lastB ~= cfg.color.b then
        frame.durationText:SetTextColor(cfg.color.r, cfg.color.g, cfg.color.b)
        frame.lastR, frame.lastG, frame.lastB = cfg.color.r, cfg.color.g, cfg.color.b
    end
    
    local anchor = cfg.textAnchor or "CENTER"
    if frame.lastOffsetX ~= cfg.offsetX or frame.lastOffsetY ~= cfg.offsetY or frame.lastAnchor ~= anchor then
        frame.durationText:ClearAllPoints()
        frame.durationText:SetPoint(anchor, frame, anchor, cfg.offsetX, cfg.offsetY)
        frame.lastOffsetX, frame.lastOffsetY = cfg.offsetX, cfg.offsetY
        frame.lastAnchor = anchor
    end
end

local function SnapOverlayToFrame(overlay, sourceFrame)
    if sourceFrame and sourceFrame:IsVisible() then
        if sourceFrame.GetCenter then
            local cx, cy = sourceFrame:GetCenter()
            if cx and cy then
                local scale = sourceFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
                overlay:SetScale(scale)
                local rawW, rawH = 45, 45
                pcall(function() rawW = sourceFrame:GetWidth(); rawH = sourceFrame:GetHeight() end)
                if rawW < 1 or rawH < 1 then rawW, rawH = 45, 45 end
                overlay:SetSize(rawW, rawH)
                if overlay.iconTex then overlay.iconTex:SetTexCoord(GetCropCoords(rawW, rawH)) end
                overlay:ClearAllPoints()
                overlay:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
                
                overlay:SetFrameStrata("HIGH")
                overlay:SetFrameLevel(sourceFrame:GetFrameLevel() + 20)
                if overlay.cd then overlay.cd:SetFrameLevel(overlay:GetFrameLevel() + 1) end
                
                return true
            end
        end
    end
    return false
end

local function ApplyCustomGlowToFrame(frame, glowKey)
    local cfg = WF.db.auraGlow
    if not LCG then return end
    
    LCG.PixelGlow_Stop(frame, glowKey)
    LCG.AutoCastGlow_Stop(frame, glowKey)
    LCG.ButtonGlow_Stop(frame)
    LCG.ProcGlow_Stop(frame, glowKey)

    if not cfg.glowEnable then return end
    
    local c = cfg.glowColor or {r=1, g=1, b=1, a=1}
    local colorArr = cfg.glowUseCustomColor and {c.r, c.g, c.b, c.a} or nil
    local t = cfg.glowType or "pixel"
    
    if t == "pixel" then
        local len = cfg.glowPixelLength; if len == 0 then len = nil end
        LCG.PixelGlow_Start(frame, colorArr, cfg.glowPixelLines, cfg.glowPixelFrequency, len, cfg.glowPixelThickness, cfg.glowPixelXOffset, cfg.glowPixelYOffset, false, glowKey)
    elseif t == "autocast" then
        LCG.AutoCastGlow_Start(frame, colorArr, cfg.glowAutocastParticles, cfg.glowAutocastFrequency, cfg.glowAutocastScale, cfg.glowAutocastXOffset, cfg.glowAutocastYOffset, glowKey)
    elseif t == "button" then
        local freq = cfg.glowButtonFrequency; if freq == 0 then freq = nil end
        LCG.ButtonGlow_Start(frame, colorArr, freq)
    elseif t == "proc" then
        LCG.ProcGlow_Start(frame, {color = colorArr, duration = cfg.glowProcDuration, xOffset = cfg.glowProcXOffset, yOffset = cfg.glowProcYOffset, key = glowKey})
    end
end

local function ToggleGlow(frame, glowKey, shouldGlow, forceRefresh)
    if not frame or not LCG then return end
    if shouldGlow then
        if not frame._isGlowing or forceRefresh then
            frame._isGlowing = true
            ApplyCustomGlowToFrame(frame, glowKey)
        end
    else
        if frame._isGlowing or forceRefresh then
            frame._isGlowing = false
            LCG.PixelGlow_Stop(frame, glowKey)
            LCG.AutoCastGlow_Stop(frame, glowKey)
            LCG.ButtonGlow_Stop(frame)
            LCG.ProcGlow_Stop(frame, glowKey)
        end
    end
end

local function CreateBaseFrame(spellID, isIndependent)
    local frame = CreateFrame("Frame", nil, UIParent, isIndependent and "BackdropTemplate" or nil)
    frame:SetFrameStrata("HIGH") 
    frame.isIndependent = isIndependent
    
    if isIndependent then 
        -- 原生黑边框
        frame:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
        frame:SetBackdropBorderColor(0, 0, 0, 1)
    end
    
    local iconTex = frame:CreateTexture(nil, "ARTWORK")
    iconTex:SetAllPoints(frame)
    if isIndependent then
        iconTex:SetPoint("TOPLEFT", 1, -1)
        iconTex:SetPoint("BOTTOMRIGHT", -1, 1)
    end
    
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if spellInfo and spellInfo.iconID then iconTex:SetTexture(spellInfo.iconID) end
    frame.iconTex = iconTex
    
    local cd = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cd:SetAllPoints()
    cd:SetDrawSwipe(true)  
    cd:SetReverse(true)
    cd:SetDrawEdge(false); cd:SetDrawBling(false); cd:SetHideCountdownNumbers(false)
    cd.noCooldownOverride = true; cd.noOCC = true
    frame.cd = cd
    
    for _, region in pairs({cd:GetRegions()}) do
        if region:IsObjectType("FontString") then frame.durationText = region break end
    end
    if not frame.durationText then frame.durationText = cd:CreateFontString(nil, "OVERLAY") end
    
    return frame
end

local function GetOverlay(spellID)
    if not OverlayFrames[spellID] then
        OverlayFrames[spellID] = CreateBaseFrame(spellID, false)
        OverlayFrames[spellID]:SetScript("OnUpdate", function(self)
            if self.sourceFrame and SnapOverlayToFrame(self, self.sourceFrame) then
                SyncTextAndVisuals(self)
            else
                self:Hide()
            end
        end)
    end
    return OverlayFrames[spellID]
end

local function GetIndependentIcon(spellID)
    if not IndependentFrames[spellID] then
        IndependentFrames[spellID] = CreateBaseFrame(spellID, true)
        IndependentFrames[spellID]:SetScript("OnUpdate", function(self) SyncTextAndVisuals(self) end)
    end
    return IndependentFrames[spellID]
end

-- =========================================
-- [更新与布局逻辑]
-- =========================================
function AuraGlowMod:UpdateGlows(forceUpdate)
    if not WF.db.auraGlow.enable then 
        for _, f in pairs(OverlayFrames) do ToggleGlow(f, "WishAuraOverlayGlow", false, true); f:Hide() end
        for _, f in pairs(IndependentFrames) do ToggleGlow(f, "WishAuraIndGlow", false, true); f:Hide() end
        return 
    end
    
    wipe(activeSkillFrames)
    wipe(activeBuffFrames)
    wipe(targetAuraCache)

    for _, viewer in ipairs({_G.EssentialCooldownViewer, _G.UtilityCooldownViewer}) do
        if viewer and viewer.itemFramePool then
            for f in viewer.itemFramePool:EnumerateActive() do
                if f:IsVisible() and f.cooldownInfo then activeSkillFrames[#activeSkillFrames+1] = f end
            end
        end
    end

    for _, viewer in ipairs({_G.BuffIconCooldownViewer, _G.BuffBarCooldownViewer}) do
        if viewer and viewer.itemFramePool then
            for f in viewer.itemFramePool:EnumerateActive() do
                if f.cooldownInfo then activeBuffFrames[#activeBuffFrames+1] = f end
            end
        end
    end

    local targetScanned = false
    local validCombatState = InCombatLockdown() or (UnitExists("target") and UnitCanAttack("player", "target"))
    local activeIndependentIcons = {}

    local currentSpecID = 0
    pcall(function() currentSpecID = GetSpecializationInfo(GetSpecialization()) or 0 end)

    for spellIDStr, spellData in pairs(GetSpellDB()) do
        local spellID = tonumber(spellIDStr)
        if spellData.auraGlow and (not spellData.class or spellData.class == "ALL" or spellData.class == playerClass) then
            local sSpec = spellData.spec or 0
            if sSpec == 0 or sSpec == currentSpecID then
                local wantGlow = spellData.auraGlow.glowEnable
                local wantIcon = spellData.auraGlow.iconEnable
                local wantIconGlow = spellData.auraGlow.iconGlowEnable ~= false 

                if wantGlow or wantIcon then
                    local buffID = spellData.buffID or spellID
                    local customDuration = spellData.auraGlow.duration or 0
                    
                    local skillFrame = nil
                    if wantGlow then
                        for i = 1, #activeSkillFrames do
                            if MatchesSpellID(activeSkillFrames[i].cooldownInfo, spellID) then skillFrame = activeSkillFrames[i]; break end
                        end
                    end

                    if wantIcon or (wantGlow and skillFrame and skillFrame:IsVisible()) then
                        local auraActive = false
                        local auraInstanceID = nil
                        local unit = "player"
                        
                        if customDuration > 0 then
                            local tracker = self.manualTrackers[buffID]
                            if tracker and GetTime() < (tracker.start + tracker.dur) then auraActive = true else self.manualTrackers[buffID] = nil end
                        else
                            local buffFrame = nil
                            for i = 1, #activeBuffFrames do
                                if MatchesSpellID(activeBuffFrames[i].cooldownInfo, buffID) then buffFrame = activeBuffFrames[i]; break end
                            end
                            if buffFrame then
                                local tempID = buffFrame.auraInstanceID; local tempUnit = buffFrame.auraDataUnit or "player"
                                if IsSafeValue(tempID) and VerifyAuraAlive(tempID, tempUnit) then
                                    auraInstanceID, unit, auraActive = tempID, tempUnit, true
                                    self.trackedAuras[buffID] = self.trackedAuras[buffID] or {}; self.trackedAuras[buffID].id = auraInstanceID; self.trackedAuras[buffID].unit = unit
                                end
                            end
                            if not auraActive and self.trackedAuras[buffID] then
                                local t = self.trackedAuras[buffID]
                                if VerifyAuraAlive(t.id, t.unit) then auraActive, auraInstanceID, unit = true, t.id, t.unit else self.trackedAuras[buffID] = nil end
                            end
                            if not auraActive then
                                local auraData = C_UnitAuras.GetPlayerAuraBySpellID(buffID)
                                if auraData and IsSafeValue(auraData.auraInstanceID) then
                                    auraActive, auraInstanceID, unit = true, auraData.auraInstanceID, "player"
                                    self.trackedAuras[buffID] = self.trackedAuras[buffID] or {}; self.trackedAuras[buffID].id = auraInstanceID; self.trackedAuras[buffID].unit = unit
                                elseif UnitExists("target") then
                                    if not targetScanned then
                                        targetScanned = true
                                        for _, filter in ipairs({"HELPFUL", "HARMFUL"}) do
                                            for i = 1, 40 do
                                                local aura = C_UnitAuras.GetAuraDataByIndex("target", i, filter)
                                                if not aura then break end
                                                if IsSafeValue(aura.spellId) and IsSafeValue(aura.auraInstanceID) then targetAuraCache[aura.spellId] = aura.auraInstanceID end
                                            end
                                        end
                                    end
                                    if targetAuraCache[buffID] then
                                        auraActive, auraInstanceID, unit = true, targetAuraCache[buffID], "target"
                                        self.trackedAuras[buffID] = self.trackedAuras[buffID] or {}; self.trackedAuras[buffID].id = auraInstanceID; self.trackedAuras[buffID].unit = unit
                                    end
                                end
                            end
                        end
                        
                        if auraActive and validCombatState then
                            local durObj = nil
                            if customDuration > 0 then
                                local tracker = self.manualTrackers[buffID]
                                if tracker then durObj = { start = tracker.start, dur = tracker.dur } end
                            elseif auraInstanceID then
                                durObj = C_UnitAuras.GetAuraDuration(unit, auraInstanceID)
                            end

                            if wantIcon then
                                local indIcon = GetIndependentIcon(spellID)
                                indIcon:Show()
                                if durObj and durObj.dur then pcall(function() indIcon.cd:SetCooldown(durObj.start, durObj.dur) end)
                                elseif durObj then pcall(function() indIcon.cd:SetCooldownFromDurationObject(durObj) end) end
                                
                                ToggleGlow(indIcon, "WishAuraIndGlow", wantIconGlow, forceUpdate)
                                activeIndependentIcons[#activeIndependentIcons+1] = indIcon
                            else
                                if IndependentFrames[spellID] then ToggleGlow(IndependentFrames[spellID], "WishAuraIndGlow", false, forceUpdate); IndependentFrames[spellID]:Hide() end
                            end

                            if wantGlow and skillFrame and skillFrame:IsVisible() then
                                local overlay = GetOverlay(spellID)
                                overlay.sourceFrame = skillFrame
                                if SnapOverlayToFrame(overlay, skillFrame) then
                                    overlay:Show()
                                    if durObj and durObj.dur then pcall(function() overlay.cd:SetCooldown(durObj.start, durObj.dur) end)
                                    elseif durObj then pcall(function() overlay.cd:SetCooldownFromDurationObject(durObj) end) end
                                    ToggleGlow(overlay, "WishAuraOverlayGlow", true, forceUpdate)
                                else
                                    if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); OverlayFrames[spellID]:Hide() end
                                end
                            else
                                if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); OverlayFrames[spellID]:Hide() end
                            end
                            
                        else
                            if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); if OverlayFrames[spellID].cd then OverlayFrames[spellID].cd:Clear() end; OverlayFrames[spellID]:Hide() end
                            if IndependentFrames[spellID] then ToggleGlow(IndependentFrames[spellID], "WishAuraIndGlow", false, forceUpdate); if IndependentFrames[spellID].cd then IndependentFrames[spellID].cd:Clear() end; IndependentFrames[spellID]:Hide() end
                        end
                    else
                        if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); OverlayFrames[spellID]:Hide() end
                        if IndependentFrames[spellID] then ToggleGlow(IndependentFrames[spellID], "WishAuraIndGlow", false, forceUpdate); IndependentFrames[spellID]:Hide() end
                    end
                else
                    if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); OverlayFrames[spellID]:Hide() end
                    if IndependentFrames[spellID] then ToggleGlow(IndependentFrames[spellID], "WishAuraIndGlow", false, forceUpdate); IndependentFrames[spellID]:Hide() end
                end
            else
                if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); OverlayFrames[spellID]:Hide() end
                if IndependentFrames[spellID] then ToggleGlow(IndependentFrames[spellID], "WishAuraIndGlow", false, forceUpdate); IndependentFrames[spellID]:Hide() end
            end
        else
            if OverlayFrames[spellID] then ToggleGlow(OverlayFrames[spellID], "WishAuraOverlayGlow", false, forceUpdate); OverlayFrames[spellID]:Hide() end
            if IndependentFrames[spellID] then ToggleGlow(IndependentFrames[spellID], "WishAuraIndGlow", false, forceUpdate); IndependentFrames[spellID]:Hide() end
        end
    end

    if self.AuraGlowAnchor then
        local cfg = WF.db.auraGlow.independent
        local s = cfg.size or 45; local gap = cfg.gap or 2; local growth = cfg.growth or "LEFT"
        local numIcons = #activeIndependentIcons
        
        local startX = 0
        if growth == "CENTER_HORIZONTAL" and numIcons > 0 then
            local totalWidth = (numIcons * s) + ((numIcons - 1) * gap)
            startX = - (totalWidth / 2) + (s / 2)
        end
        
        for i, icon in ipairs(activeIndependentIcons) do
            icon:ClearAllPoints()
            icon:SetScale(1)
            icon:SetSize(s, s)
            if icon.iconTex then icon.iconTex:SetTexCoord(GetCropCoords(s, s)) end
            
            if growth == "CENTER_HORIZONTAL" then
                local currentOffsetX = startX + (i - 1) * (s + gap)
                icon:SetPoint("CENTER", self.AuraGlowAnchor, "CENTER", currentOffsetX, 0)
            else
                if i == 1 then
                    icon:SetPoint("CENTER", self.AuraGlowAnchor, "CENTER", 0, 0)
                else
                    local prev = activeIndependentIcons[i-1]
                    if growth == "LEFT" then icon:SetPoint("RIGHT", prev, "LEFT", -gap, 0)
                    elseif growth == "RIGHT" then icon:SetPoint("LEFT", prev, "RIGHT", gap, 0)
                    elseif growth == "UP" then icon:SetPoint("BOTTOM", prev, "TOP", 0, gap)
                    elseif growth == "DOWN" then icon:SetPoint("TOP", prev, "BOTTOM", 0, -gap) end
                end
            end
        end
    end
end

-- =========================================
-- [事件与初始化系统]
-- =========================================
local updatePending = false
local function RequestUpdateGlows()
    if updatePending then return end
    updatePending = true
    local delay = InCombatLockdown() and 0.08 or 0.3
    C_Timer.After(delay, function() updatePending = false; AuraGlowMod:UpdateGlows() end)
end

AuraGlowMod:SetScript("OnEvent", function(self, event, unit, _, spellID)
    if event == "UNIT_AURA" then
        if not InCombatLockdown() and unit ~= "player" then return end
        if unit == "player" or unit == "target" then RequestUpdateGlows() end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit ~= "player" or not WF.db.auraGlow.enable then return end
        local currentSpecID = 0
        pcall(function() currentSpecID = GetSpecializationInfo(GetSpecialization()) or 0 end)
        local triggered = false
        for sIDStr, spellData in pairs(GetSpellDB()) do
            if spellData.auraGlow and (spellData.auraGlow.glowEnable or spellData.auraGlow.iconEnable) and (not spellData.class or spellData.class == "ALL" or spellData.class == playerClass) then
                local sSpec = spellData.spec or 0
                if sSpec == 0 or sSpec == currentSpecID then
                    local sID = tonumber(sIDStr)
                    local bID = spellData.buffID or sID
                    local dur = spellData.auraGlow.duration or 0
                    
                    if dur > 0 and (spellID == sID or spellID == bID) then
                        self.manualTrackers = self.manualTrackers or {}
                        self.manualTrackers[bID] = { start = GetTime(), dur = dur }
                        triggered = true
                    end
                end
            end
        end
        if triggered then RequestUpdateGlows() end
    else
        RequestUpdateGlows()
    end
end)

local function SafeHook(object, funcName, callback)
    if object and object[funcName] and type(object[funcName]) == "function" then hooksecurefunc(object, funcName, callback) end
end

local function InitAuraGlow()
    -- 1. 确保配置存在
    if not WF.db.auraGlow then WF.db.auraGlow = {} end
    for k, v in pairs(DefaultConfig) do
        if WF.db.auraGlow[k] == nil then WF.db.auraGlow[k] = v end
    end
    for k, v in pairs(DefaultConfig.independent) do
        if WF.db.auraGlow.independent[k] == nil then WF.db.auraGlow.independent[k] = v end
    end
    
    if not WF.db.auraGlow.enable then return end

    -- 2. 创建独立锚点框架
    AuraGlowMod.AuraGlowAnchor = CreateFrame("Frame", "WishFlex_AuraGlowIconAnchor", UIParent)
    AuraGlowMod.AuraGlowAnchor:SetPoint("CENTER", UIParent, "CENTER", 180, 0)
    AuraGlowMod.AuraGlowAnchor:SetSize(45, 45)
    
    -- 简易锚点预留 (稍后统一写 UI 拖动功能)
    local mover = CreateFrame("Frame", "WishFlexAuraGlowIconMover", UIParent)
    mover:SetSize(45, 45)
    mover:SetPoint("CENTER", UIParent, "CENTER", 180, 0)
    mover.isWishFlexMover = true 
    AuraGlowMod.AuraGlowAnchor.mover = mover
    AuraGlowMod.AuraGlowAnchor:SetPoint("CENTER", mover, "CENTER")

    -- 3. 注册事件
    AuraGlowMod:RegisterEvent("UNIT_AURA")
    AuraGlowMod:RegisterEvent("PLAYER_TARGET_CHANGED")
    AuraGlowMod:RegisterEvent("PLAYER_REGEN_DISABLED")
    AuraGlowMod:RegisterEvent("PLAYER_REGEN_ENABLED")
    AuraGlowMod:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    AuraGlowMod:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    
    -- 4. 挂钩暴雪原生冷却框架
    local viewers = { _G.BuffIconCooldownViewer, _G.EssentialCooldownViewer, _G.UtilityCooldownViewer, _G.BuffBarCooldownViewer }
    for _, viewer in ipairs(viewers) do
        if viewer then
            SafeHook(viewer, "RefreshData", RequestUpdateGlows)
            SafeHook(viewer, "UpdateLayout", RequestUpdateGlows)
            SafeHook(viewer, "Layout", RequestUpdateGlows)
            if viewer.itemFramePool then
                SafeHook(viewer.itemFramePool, "Acquire", RequestUpdateGlows)
                SafeHook(viewer.itemFramePool, "Release", RequestUpdateGlows)
            end
        end
    end

    RequestUpdateGlows()
end

-- 注册到 WishFlex 核心
WF:RegisterModule("auraGlow", L["Aura Glow"] or "技能状态高亮", InitAuraGlow)