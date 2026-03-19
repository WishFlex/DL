local AddonName, ns = ...
local WF = _G.WishFlex or ns.WF
local L = ns.L or {}
local LSM = LibStub("LibSharedMedia-3.0", true)

local WM = CreateFrame("Frame")
WF.WishMonitorAPI = WM

local PP_Scale = 1
local function GetOnePixelSize()
    local screenHeight = select(2, GetPhysicalScreenSize()); if not screenHeight or screenHeight == 0 then return 1 end
    local uiScale = UIParent:GetEffectiveScale(); if not uiScale or uiScale == 0 then return 1 end
    PP_Scale = 768.0 / screenHeight / uiScale
    return PP_Scale
end
local function PixelSnap(value)
    if not value then return 0 end
    GetOnePixelSize()
    return math.floor(value / PP_Scale + 0.5) * PP_Scale
end

-- =========================================
-- [VFlow 核心1：ArcDetector 机密值洗白器]
-- =========================================
local function IsSafeValue(val)
    if val == nil then return false end
    if type(issecretvalue) == "function" and issecretvalue(val) then return false end
    return true
end

function WM:DecodeSecret(parent, secretVal, limit)
    if not issecretvalue or not issecretvalue(secretVal) then return tonumber(secretVal) or 0 end
    local l = tonumber(limit) or 10
    if l < 1 then l = 1 end
    if l > 20 then l = 20 end
    
    parent._arcs = parent._arcs or {}
    for i = 1, l do
        local det = parent._arcs[i]
        if not det then
            det = CreateFrame("StatusBar", nil, parent)
            det:SetSize(1, 1); det:SetPoint("BOTTOMLEFT"); det:SetAlpha(0)
            det:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
            parent._arcs[i] = det
        end
        det:SetMinMaxValues(i - 1, i)
        pcall(function() det:SetValue(secretVal) end)
    end
    
    local exact = 0
    for i = 1, l do
        if parent._arcs[i] and parent._arcs[i]:GetStatusBarTexture() and parent._arcs[i]:GetStatusBarTexture():IsShown() then exact = i else break end
    end
    return exact
end

-- =========================================
-- [状态与映射]
-- =========================================
function WM:RegisterEvent(event, func)
    if not self._events then self._events = {} end
    self._events[event] = func or event
    getmetatable(self).__index.RegisterEvent(self, event)
end
WM:SetScript("OnEvent", function(self, event, ...)
    local handler = self._events[event]
    if type(handler) == "function" then handler(self, event, ...)
    elseif type(handler) == "string" and type(self[handler]) == "function" then self[handler](self, event, ...) end
end)

WM.TrackedSkills = {}
WM.TrackedBuffs = {}
WM.ActiveFrames = {}
WM.FramePool = {}
WM.CurrentTab = "skill"
WM.selectedSkillID = nil
WM.selectedBuffID = nil
WM.SpellToCD = {}
WM.ActiveBuffFrames = {}
WM.ActiveSkillFrames = {}
WM.PlayerAuraCache = {}

-- =========================================
-- [VFlow 核心2：纯血扫描器 (SkillScanner / BuffScanner)]
-- =========================================
local function ResolveVFlowSpellID(info, isAura)
    if not info then return nil end
    if isAura then
        if info.linkedSpellIDs and info.linkedSpellIDs[1] then return info.linkedSpellIDs[1] end
        return info.overrideSpellID or info.spellID
    else
        if info.overrideSpellID and info.overrideSpellID > 0 then return info.overrideSpellID end
        local baseID = info.spellID
        if baseID and baseID > 0 then
            local over; pcall(function() over = C_Spell.GetOverrideSpell(baseID) end)
            if over and over > 0 and over ~= baseID then return over end
        end
        if info.linkedSpellIDs and info.linkedSpellIDs[1] and info.linkedSpellIDs[1] > 0 then return info.linkedSpellIDs[1] end
        return baseID
    end
end

function WM:ScanViewers(isFromUI)
    wipe(WM.TrackedSkills)
    wipe(WM.TrackedBuffs)
    wipe(WM.SpellToCD)
    wipe(WM.ActiveBuffFrames)
    wipe(WM.ActiveSkillFrames)

    local function ProcessViewer(viewerName, isAura)
        local viewer = _G[viewerName]
        if viewer and viewer.itemFramePool then
            for frame in viewer.itemFramePool:EnumerateActive() do
                local cdID = frame.cooldownID or (frame.cooldownInfo and frame.cooldownInfo.cooldownID)
                if cdID then
                    local info; pcall(function() info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID) end)
                    local spellID = ResolveVFlowSpellID(info, isAura)
                    if spellID and spellID > 0 then
                        WM.SpellToCD[spellID] = cdID
                        if isAura then WM.ActiveBuffFrames[#WM.ActiveBuffFrames+1] = frame
                        else WM.ActiveSkillFrames[#WM.ActiveSkillFrames+1] = frame end
                        
                        pcall(function()
                            local sInfo = C_Spell.GetSpellInfo(spellID)
                            if sInfo and sInfo.name then
                                if isAura then WM.TrackedBuffs[tostring(spellID)] = { name = sInfo.name, icon = sInfo.iconID }
                                else WM.TrackedSkills[tostring(spellID)] = { name = sInfo.name, icon = sInfo.iconID } end
                            end
                        end)
                    end
                end
            end
        end
    end

    ProcessViewer("EssentialCooldownViewer", false)
    ProcessViewer("UtilityCooldownViewer", false)
    ProcessViewer("BuffIconCooldownViewer", true)
    ProcessViewer("BuffBarCooldownViewer", true)

    if not isFromUI and WF.UI and WF.UI.CurrentNodeKey == "classResource_Monitor" then 
        WF.UI:RefreshCurrentPanel() 
    end
end

-- =========================================
-- [数据库与默认值]
-- =========================================
local defaults = {
    attachToResource = true, attachX = 0, attachY = 2,
    width = 250, height = 14, spacing = 2, growth = "UP",
    texture = "WishFlex-g1", font = "Expressway", fontSize = 12,
    skills = {}, buffs = {}
}

local function DeepMerge(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then if type(target[k]) ~= "table" then target[k] = {} end; DeepMerge(target[k], v)
        else if target[k] == nil then target[k] = v end end
    end
end

local function GetDB()
    if not WF.db.wishMonitor then WF.db.wishMonitor = {} end
    DeepMerge(WF.db.wishMonitor, defaults)
    return WF.db.wishMonitor
end

-- =========================================
-- [网格切分引擎]
-- =========================================
function WM:UpdateDividers(f, maxVal, width)
    f.dividers = f.dividers or {}
    local numMax = 1
    pcall(function() if not IsSecret(maxVal) then numMax = tonumber(maxVal) or 1 end end)
    if numMax <= 0 then numMax = 1 end; if numMax > 20 then numMax = 20 end 
    
    if numMax <= 1 then 
        for _, d in ipairs(f.dividers) do d:Hide() end 
        return 
    end 
    
    local pixelSize = GetOnePixelSize()
    local exactSeg = width / numMax
    
    for i = 1, numMax - 1 do
        if not f.dividers[i] then 
            local tex = f.sb:CreateTexture(nil, "OVERLAY", nil, 7)
            tex:SetColorTexture(0, 0, 0, 1); f.dividers[i] = tex 
        end
        f.dividers[i]:SetWidth(pixelSize); f.dividers[i]:ClearAllPoints()
        local offset = PixelSnap(exactSeg * i)
        f.dividers[i]:SetPoint("TOPLEFT", f.sb, "TOPLEFT", offset, 0)
        f.dividers[i]:SetPoint("BOTTOMLEFT", f.sb, "BOTTOMLEFT", offset, 0)
        f.dividers[i]:Show()
    end
    for i = numMax, #f.dividers do if f.dividers[i] then f.dividers[i]:Hide() end end
end

function WM:UpdateAnchor()
    if not self.baseAnchor then return end
    local db = GetDB()
    self.baseAnchor:ClearAllPoints()
    if db.attachToResource and WF.ClassResourceAPI and WF.ClassResourceAPI.baseAnchor then
        local CR = WF.ClassResourceAPI; local topFrame = CR.baseAnchor
        if CR.classBar and CR.classBar:IsShown() then topFrame = CR.classBar
        elseif CR.powerBar and CR.powerBar:IsShown() then topFrame = CR.powerBar
        elseif CR.manaBar and CR.manaBar:IsShown() then topFrame = CR.manaBar end
        self.baseAnchor:SetPoint("BOTTOM", topFrame, "TOP", PixelSnap(db.attachX or 0), PixelSnap(db.attachY or 2))
    else
        local mover = _G["WishFlex_MonitorAnchorMover"]
        if mover then self.baseAnchor:SetPoint("CENTER", mover, "CENTER", 0, 0)
        else self.baseAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, -50) end
    end
end

-- =========================================
-- [VFlow 核心3：双轨渲染框架]
-- =========================================
function WM:GetFrame(index)
    if not self.FramePool[index] then
        local f = CreateFrame("Frame", "WishFlexMonitor_"..index, self.baseAnchor)
        
        f.iconFrame = CreateFrame("Frame", nil, f)
        f.iconFrame:SetFrameLevel(f:GetFrameLevel() + 1)
        f.icon = f.iconFrame:CreateTexture(nil, "ARTWORK")
        f.icon:SetAllPoints(); f.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        
        f.sb = CreateFrame("StatusBar", nil, f)
        f.sb:SetFrameLevel(f:GetFrameLevel() + 1)
        f.bg = f.sb:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAllPoints()
        
        -- 【VFlow 核心：充能副条】
        f.rechargeOverlay = CreateFrame("StatusBar", nil, f.sb)
        f.rechargeOverlay:SetFrameLevel(f.sb:GetFrameLevel() + 1)
        
        local function AddBoxBorder(target)
            local border = CreateFrame("Frame", nil, target)
            border:SetAllPoints(); border:SetFrameLevel(target:GetFrameLevel() + 5)
            local m = GetOnePixelSize()
            local function DrawLine(p1, p2, x, y, w, h)
                local t = border:CreateTexture(nil, "OVERLAY")
                t:SetColorTexture(0,0,0,1); t:SetPoint(p1, border, p1, x, y); t:SetPoint(p2, border, p2, x, y)
                if w then t:SetWidth(m) end; if h then t:SetHeight(m) end
            end
            DrawLine("TOPLEFT", "TOPRIGHT", 0, 0, nil, 1); DrawLine("BOTTOMLEFT", "BOTTOMRIGHT", 0, 0, nil, 1)
            DrawLine("TOPLEFT", "BOTTOMLEFT", 0, 0, 1, nil); DrawLine("TOPRIGHT", "BOTTOMRIGHT", 0, 0, 1, nil)
            return border
        end
        f.iconBorder = AddBoxBorder(f.iconFrame)
        f.sbBorder = AddBoxBorder(f.sb)
        
        f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
        f.cd:SetDrawSwipe(true); f.cd:SetDrawEdge(false); f.cd:SetDrawBling(false)
        f.cd.noCooldownOverride = true; f.cd.noOCC = true
        -- 【关键修复】：彻底隐藏暴雪自带的巨大黄色冷却数字！
        f.cd:SetHideCountdownNumbers(true) 
        f.cd:SetFrameLevel(f:GetFrameLevel() + 20)
        
        local textFrame = CreateFrame("Frame", nil, f)
        textFrame:SetAllPoints(); textFrame:SetFrameLevel(f:GetFrameLevel() + 30)
        f.stackText = textFrame:CreateFontString(nil, "OVERLAY")
        f.timerText = textFrame:CreateFontString(nil, "OVERLAY")
        
        self.FramePool[index] = f
    end
    return self.FramePool[index]
end

function WM:ApplyFrameStyle(f, db, cfg, spellID)
    local tex = LSM:Fetch("statusbar", db.texture) or "Interface\\Buttons\\WHITE8x8"
    f.sb:SetStatusBarTexture(tex); f.bg:SetTexture(tex)
    f.rechargeOverlay:SetStatusBarTexture(tex)
    
    local c = cfg.color or {r=0, g=0.8, b=1, a=1}
    f.baseColor = c 
    f.sb:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
    f.rechargeOverlay:SetStatusBarColor(c.r, c.g, c.b, c.a or 0.8)
    f.bg:SetVertexColor(0.15, 0.15, 0.15, 0.9)
    
    local font = LSM:Fetch("font", db.font) or STANDARD_TEXT_FONT
    f.stackText:SetFont(font, db.fontSize + 2, "OUTLINE"); f.stackText:SetTextColor(1, 1, 1, 1)
    f.timerText:SetFont(font, db.fontSize, "OUTLINE"); f.timerText:SetTextColor(1, 1, 1, 1)

    local spellInfo = nil; pcall(function() spellInfo = C_Spell.GetSpellInfo(spellID) end)
    if spellInfo then f.icon:SetTexture(spellInfo.iconID) end

    local fWidth = (cfg.width and cfg.width > 0) and cfg.width or db.width
    if (not cfg.width or cfg.width == 0) and db.attachToResource and WF.ClassResourceAPI and WF.ClassResourceAPI.baseAnchor then
        fWidth = WF.ClassResourceAPI.baseAnchor:GetWidth()
    end
    
    local fHeight = (cfg.height and cfg.height > 0) and cfg.height or db.height
    local snapW = PixelSnap(fWidth)
    local snapH = PixelSnap(fHeight)
    
    f.calcWidth = snapW; f.calcHeight = snapH
    f:SetSize(snapW, snapH)
    
    if cfg.useStatusBar then
        f.iconFrame:Hide(); f.cd:Hide()
        f.sb:ClearAllPoints(); f.sb:SetAllPoints(f)
        f.sb:Show(); f.bg:Show(); f.sbBorder:Show()
        
        f.cd:ClearAllPoints(); f.cd:SetAllPoints(f.sb)
        f.cd:SetDrawSwipe(false)
        
        f.stackText:ClearAllPoints(); f.stackText:SetPoint("LEFT", f.sb, "LEFT", 4, 0)
        f.timerText:ClearAllPoints(); f.timerText:SetPoint("RIGHT", f.sb, "RIGHT", -4, 0); f.timerText:SetJustifyH("RIGHT")
        f.timerText:Show()
    else
        f.iconFrame:ClearAllPoints(); f.iconFrame:SetSize(snapH, snapH)
        f.iconFrame:SetPoint("CENTER", f, "CENTER", 0, 0); f.iconFrame:Show()
        f.sb:Hide(); f.bg:Hide(); f.sbBorder:Hide(); f.rechargeOverlay:Hide()
        
        f.cd:ClearAllPoints(); f.cd:SetAllPoints(f.iconFrame)
        f.cd:SetDrawSwipe(true); f.cd:Show()
        
        f.stackText:ClearAllPoints(); f.stackText:SetPoint("BOTTOMRIGHT", f.iconFrame, "BOTTOMRIGHT", 2, -2)
        f.timerText:ClearAllPoints(); f.timerText:SetPoint("CENTER", f.iconFrame, "CENTER", 0, 0); f.timerText:SetJustifyH("CENTER")
        f.timerText:Show()
    end
end

-- =========================================
-- [VFlow 核心4：安全数据抓取与 C 引擎动画]
-- =========================================
local function UpdateBarValueSafe(sb, rawCurr, rawMax)
    if not sb then return end
    pcall(function()
        if IsSecret(rawMax) or IsSecret(rawCurr) then 
            sb:SetMinMaxValues(0, rawMax); sb:SetValue(rawCurr)
        else
            local rMax = tonumber(rawMax) or 1; local rCur = tonumber(rawCurr) or 0
            if rMax <= 0 then rMax = 1 end
            sb:SetMinMaxValues(0, rMax); sb:SetValue(rCur)
        end
    end)
end

function WM:Render()
    if not self.baseAnchor then return end
    local db = GetDB()
    wipe(self.ActiveFrames)
    local activeCount = 0
    
    local function ProcessItem(spellIDStr, cfg, isBuff)
        if not cfg.enable then return end
        local spellID = tonumber(spellIDStr)
        local isActive, rawCount, maxVal, durObjC = false, 0, 1, nil
        
        if isBuff then
            local unit = cfg.unit or "player"
            local cdID = WM.SpellToCD[spellID]
            
            -- 从底层Viewer拿取实例ID，杜绝崩溃
            local instID = nil
            for i = 1, #WM.ActiveBuffFrames do
                local frame = WM.ActiveBuffFrames[i]
                if frame.cooldownID == cdID or (frame.cooldownInfo and frame.cooldownInfo.cooldownID == cdID) then
                    instID = frame.auraInstanceID
                    unit = frame.auraDataUnit or unit
                    break
                end
            end
            
            if instID and IsSafeValue(instID) then
                pcall(function() 
                    local data = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, instID)
                    if data then isActive = true; rawCount = data.applications or 0; durObjC = C_UnitAuras.GetAuraDuration(unit, instID) end
                end)
            end
            
            -- 脱战也能起效
            if not isActive then
                pcall(function() 
                    local data = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
                    if data then isActive = true; rawCount = data.applications or 0; durObjC = data end
                end)
            end
            maxVal = (cfg.mode == "stack") and (tonumber(cfg.maxStacks) or 5) or 1
        else
            if cfg.trackType == "cooldown" then
                pcall(function()
                    local cInfo = C_Spell.GetSpellCooldown(spellID)
                    if cInfo and (IsSecret(cInfo.duration) or cInfo.duration > 1.5) then 
                        isActive = true; durObjC = C_Spell.GetSpellCooldownDuration(spellID) 
                    end
                end)
            elseif cfg.trackType == "charge" then
                pcall(function()
                    local chInfo = C_Spell.GetSpellCharges(spellID)
                    if chInfo then
                        maxVal = chInfo.maxCharges or 1
                        rawCount = chInfo.currentCharges or 0
                        local numC = tonumber(rawCount) or 0
                        if numC > 0 or (chInfo.cooldownDuration and chInfo.cooldownDuration > 0) then
                            isActive = true
                            if chInfo.cooldownDuration > 0 then durObjC = C_Spell.GetSpellChargeDuration(spellID) end
                        end
                        if IsSecret(rawCount) then isActive = true end
                    end
                end)
            end
        end
        
        if isActive or cfg.alwaysShow then
            activeCount = activeCount + 1
            local f = self:GetFrame(activeCount)
            self:ApplyFrameStyle(f, db, cfg, spellID)
            
            -- 洗白机密值
            local safeMax = self:DecodeSecret(self.baseAnchor, maxVal, 20)
            if safeMax < 1 then safeMax = 1 end
            local safeCount = self:DecodeSecret(self.baseAnchor, rawCount, safeMax)
            
            f.safeCount = safeCount; f.maxVal = safeMax
            f.isBuff = isBuff; f.cfg = cfg; f.durationObj = durObjC
            
            if safeCount > 0 then f.stackText:SetText(safeCount); f.stackText:Show() else f.stackText:Hide() end
            
            if isActive then
                f.sb:SetStatusBarColor(f.baseColor.r, f.baseColor.g, f.baseColor.b, f.baseColor.a or 1)
                
                if cfg.useStatusBar then
                    if cfg.trackType == "charge" then
                        UpdateBarValueSafe(f.sb, safeCount, safeMax)
                        self:UpdateDividers(f, safeMax, f.calcWidth)
                        pcall(function() if f.sb.ClearTimerDuration then f.sb:ClearTimerDuration() end end)
                        
                        -- 【VFlow 原生充能副条】交由 C 引擎处理平滑动画！
                        if safeCount < safeMax and durObjC then
                            local segW = f.calcWidth / safeMax
                            f.rechargeOverlay:SetSize(segW, f.calcHeight)
                            f.rechargeOverlay:ClearAllPoints()
                            f.rechargeOverlay:SetPoint("LEFT", f.sb:GetStatusBarTexture(), "RIGHT", 0, 0)
                            pcall(function()
                                f.rechargeOverlay:SetMinMaxValues(0, 1)
                                f.rechargeOverlay:SetTimerDuration(durObjC)
                            end)
                            f.rechargeOverlay:Show()
                        else
                            f.rechargeOverlay:Hide()
                        end

                    elseif isBuff and cfg.mode == "stack" then
                        UpdateBarValueSafe(f.sb, safeCount, safeMax)
                        self:UpdateDividers(f, safeMax, f.calcWidth)
                        pcall(function() if f.sb.ClearTimerDuration then f.sb:ClearTimerDuration() end end)
                        f.rechargeOverlay:Hide()
                    else
                        self:UpdateDividers(f, 0, f.calcWidth)
                        f.rechargeOverlay:Hide()
                        pcall(function()
                            if durObjC then
                                f.sb:SetMinMaxValues(0, 1)
                                f.sb:SetTimerDuration(durObjC) -- 原生持续时间倒数！
                                if f.sb.SetToTargetValue then f.sb:SetToTargetValue() end
                            else
                                if f.sb.ClearTimerDuration then f.sb:ClearTimerDuration() end
                                UpdateBarValueSafe(f.sb, 1, 1)
                            end
                        end)
                    end
                end
                
                pcall(function()
                    if durObjC then
                        local st, dur
                        pcall(function() st = durObjC:GetCooldownStartTime(); dur = durObjC:GetCooldownDuration() end)
                        if not st then pcall(function() st = durObjC.startTime; dur = durObjC.duration end) end
                        if st and dur and dur > 0 then f.cd:SetCooldown(st, dur) else f.cd:Clear() end
                    else f.cd:Clear() end
                end)
                
                f.cd.noCooldownOverride = (not cfg.useStatusBar and cfg.trackType == "charge") and false or true
                f:SetAlpha(1)
            else
                f.cd:Clear()
                if cfg.useStatusBar then
                    local sMax = (cfg.mode == "stack" or cfg.trackType == "charge") and safeMax or 1
                    self:UpdateDividers(f, sMax, f.calcWidth)
                    UpdateBarValueSafe(f.sb, 0, sMax)
                    pcall(function() if f.sb.ClearTimerDuration then f.sb:ClearTimerDuration() end end)
                    f.sb:SetStatusBarColor(0.4, 0.4, 0.4, 0.8) 
                    f.rechargeOverlay:Hide()
                    pcall(function() if f.rechargeOverlay.ClearTimerDuration then f.rechargeOverlay:ClearTimerDuration() end end)
                end
                f:SetAlpha(0.6)
            end
            
            f:Show()
            table.insert(self.ActiveFrames, f)
        end
    end

    for id, cfg in pairs(db.skills) do ProcessItem(id, cfg, false) end
    for id, cfg in pairs(db.buffs) do ProcessItem(id, cfg, true) end
    
    for i = activeCount + 1, #self.FramePool do self.FramePool[i]:Hide() end
    
    for i, f in ipairs(self.ActiveFrames) do
        f:ClearAllPoints()
        if i == 1 then f:SetPoint("BOTTOM", self.baseAnchor, "BOTTOM", 0, 0)
        else
            local prev = self.ActiveFrames[i-1]
            if db.growth == "UP" then f:SetPoint("BOTTOM", prev, "TOP", 0, PixelSnap(db.spacing or 2))
            else f:SetPoint("TOP", prev, "BOTTOM", 0, PixelSnap(-(db.spacing or 2))) end
        end
    end
    self:UpdateAnchor()
end

function WM:TriggerUpdate()
    if self.updatePending then return end
    self.updatePending = true
    C_Timer.After(0.05, function() self.updatePending = false; WM:ScanViewers(); self:Render() end)
end

-- =========================================
-- [时间倒数文字 (全 pcall 安全区)]
-- =========================================
local function SafeFormatTime(remain)
    local ok, res = pcall(function()
        local r = tonumber(remain)
        if not r or r <= 0 then return "" end
        if r >= 60 then return string.format("%dm", math.floor(r / 60))
        elseif r >= 10 then return string.format("%d", math.floor(r))
        else return string.format("%.1f", r) end
    end)
    return ok and res or ""
end

local _updateFrame = CreateFrame("Frame")
local _elapsed = 0
_updateFrame:SetScript("OnUpdate", function(_, dt)
    _elapsed = _elapsed + dt
    if _elapsed < 0.1 then return end
    _elapsed = 0

    local now = GetTime()
    for _, f in ipairs(WM.ActiveFrames) do
        if f:IsShown() and f.durationObj then
            pcall(function()
                local st, dur, remain
                if type(f.durationObj.GetRemainingDuration) == "function" then
                    pcall(function() remain = f.durationObj:GetRemainingDuration() end)
                else
                    pcall(function() st = f.durationObj.startTime; dur = f.durationObj.duration end)
                    if not st and f.durationObj.expirationTime and dur then st = f.durationObj.expirationTime - dur end
                    if st and dur then remain = dur - (now - st) end
                end
                
                if remain and remain > 0 and remain < 3600 then f.timerText:SetText(SafeFormatTime(remain))
                else f.timerText:SetText("") end
            end)
        end
    end
end)

-- =========================================
-- [初始化机制]
-- =========================================
local function InitWishMonitor()
    GetDB()
    local anchor = CreateFrame("Frame", "WishFlex_MonitorAnchor", UIParent)
    anchor:SetSize(250, 14)
    WM.baseAnchor = anchor
    
    if WF.CreateMover then WF:CreateMover(anchor, "WishFlex_MonitorAnchorMover", {"CENTER", UIParent, "CENTER", 0, -50}, 250, 14, "WishFlex: 自定义监控独立锚点") end
    
    WM:RegisterEvent("PLAYER_ENTERING_WORLD", function() WM:TriggerUpdate() end)
    WM:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function() WM:TriggerUpdate() end)
    WM:RegisterEvent("TRAIT_CONFIG_UPDATED", function() WM:TriggerUpdate() end)
    
    WM:RegisterEvent("UNIT_AURA", function(self, e, unit) if unit == "player" or unit == "target" then WM:TriggerUpdate() end end)
    WM:RegisterEvent("PLAYER_TARGET_CHANGED", function() WM:TriggerUpdate() end)
    WM:RegisterEvent("SPELL_UPDATE_COOLDOWN", "TriggerUpdate")
    WM:RegisterEvent("SPELL_UPDATE_CHARGES", "TriggerUpdate")
    
    C_Timer.After(1, function()
        if WF.ClassResourceAPI and WF.ClassResourceAPI.UpdateLayout then hooksecurefunc(WF.ClassResourceAPI, "UpdateLayout", function() WM:UpdateAnchor(); WM:TriggerUpdate() end) end
        WM:UpdateAnchor()
        
        for _, vName in ipairs({"EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer"}) do
            local viewer = _G[vName]
            if viewer and viewer.UpdateLayout then hooksecurefunc(viewer, "UpdateLayout", function() WM:TriggerUpdate() end) end
        end
    end)
end

WF:RegisterModule("wishMonitor", L["Custom Monitor"] or "自定义监控", InitWishMonitor)

-- =========================================================================
-- [UI 设置面板：自动清洗垃圾配置]
-- =========================================================================
if WF.UI then
    WF.UI:RegisterMenu({ id = "CR_Monitor", parent = "ClassResource", name = L["Custom Monitor"] or "自定义监控", key = "classResource_Monitor", order = 5 })

    local function GetTextureOptions()
        local opts = {}
        if LSM then local list = LSM:List("statusbar"); if list then for i = 1, #list do table.insert(opts, { text = list[i], value = list[i] }) end end end
        if #opts == 0 then table.insert(opts, {text = "WishFlex-g1", value = "WishFlex-g1"}) end
        return opts
    end

    local function RenderIconGrid(scrollChild, y, ColW, scanData, dbStore, selectedID)
        local list = {}; local seen = {}
        
        for idStr, info in pairs(scanData) do
            if not seen[idStr] then seen[idStr] = true; table.insert(list, {idStr = idStr, name = info.name, icon = info.icon}) end
        end
        
        -- 【核心修复】：只展示玩家手动开启的，或者当前存在于扫描器里的。其余全作为垃圾清洗掉！
        for idStr, cfg in pairs(dbStore) do
            if not seen[idStr] then
                if cfg.enable then
                    seen[idStr] = true
                    local numId = tonumber(idStr); local si = nil; pcall(function() si = C_Spell.GetSpellInfo(numId) end)
                    table.insert(list, {idStr = idStr, name = si and si.name or tostring(numId), icon = si and si.iconID or 134400})
                else
                    dbStore[idStr] = nil -- 自动清理历史版本的垃圾数据！
                end
            end
        end
        table.sort(list, function(a, b) return a.name < b.name end)

        local ICON_SIZE, PADDING = 36, 6
        local MAX_COLS = math.floor((ColW * 1.5) / (ICON_SIZE + PADDING))

        if not scrollChild.WM_GridPool then scrollChild.WM_GridPool = {} end
        for _, btn in ipairs(scrollChild.WM_GridPool) do btn:Hide() end

        local row, col = 0, 0
        for i, item in ipairs(list) do
            local btn = scrollChild.WM_GridPool[i]
            if not btn then
                btn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
                btn:SetSize(ICON_SIZE, ICON_SIZE)
                btn:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
                local tex = btn:CreateTexture(nil, "BACKGROUND")
                tex:SetPoint("TOPLEFT", 1, -1); tex:SetPoint("BOTTOMRIGHT", -1, 1)
                tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
                btn.tex = tex
                
                btn:RegisterForClicks("AnyUp")
                scrollChild.WM_GridPool[i] = btn
            end

            btn:SetPoint("TOPLEFT", 15 + col * (ICON_SIZE + PADDING), y - row * (ICON_SIZE + PADDING))
            btn.tex:SetTexture(item.icon)

            if item.idStr == selectedID then btn:SetBackdropBorderColor(0.2, 0.6, 1, 1)
            elseif dbStore[item.idStr] and dbStore[item.idStr].enable then btn:SetBackdropBorderColor(0.2, 0.85, 0.3, 1)
            else btn:SetBackdropBorderColor(0, 0, 0, 1) end

            btn:SetScript("OnClick", function(self, button) 
                local idStr = item.idStr
                if not dbStore[idStr] then
                    if WM.CurrentTab == "skill" then dbStore[idStr] = { enable = false, trackType = "cooldown", alwaysShow = true, useStatusBar = true, color = {r=1,g=0.5,b=0,a=1} }
                    else dbStore[idStr] = { enable = false, unit = "player", mode = "time", maxStacks = 5, alwaysShow = true, useStatusBar = true, color = {r=0,g=0.8,b=1,a=1} } end
                end
                
                if button == "RightButton" then
                    dbStore[idStr].enable = not dbStore[idStr].enable
                else
                    if WM.CurrentTab == "skill" then WM.selectedSkillID = idStr else WM.selectedBuffID = idStr end
                end
                WF.UI:RefreshCurrentPanel(); WM:TriggerUpdate()
            end)
            
            btn:SetScript("OnEnter", function() GameTooltip:SetOwner(btn, "ANCHOR_RIGHT"); GameTooltip:SetSpellByID(tonumber(item.idStr)); GameTooltip:AddLine(" "); GameTooltip:AddLine("|cff00ffcc[左键]|r 编辑监控参数", 1,1,1); GameTooltip:AddLine("|cffffaa00[右键]|r 快速启用/禁用", 1,1,1); GameTooltip:Show() end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            btn:Show()

            col = col + 1
            if col >= MAX_COLS then col = 0; row = row + 1 end
        end

        if #list == 0 then return y end
        local totalRows = col == 0 and row or row + 1
        return y - totalRows * (ICON_SIZE + PADDING) - 15
    end

    WF.UI:RegisterPanel("classResource_Monitor", function(scrollChild, ColW)
        local db = GetDB()
        local y = -10
        
        if not WM.HasScanned then WM:ScanViewers(true) end
        
        local globalOpts = {
            { type = "toggle", key = "attachToResource", db = db, text = L["Attach to Class Resource"] or "智能吸附在资源条顶部" },
            { type = "slider", key = "attachX", db = db, text = L["Attach X Offset"] or "吸附 X 偏移", min=-200, max=200, step=1 },
            { type = "slider", key = "attachY", db = db, text = L["Attach Y Offset"] or "吸附 Y 偏移 (推荐2)", min=-100, max=100, step=1 },
            { type = "slider", key = "width", db = db, text = L["Global Width"] or "全局统一宽度 (未吸附时生效)", min=50, max=600, step=1 },
            { type = "slider", key = "height", db = db, text = L["Global Height"] or "全局统一高度", min=2, max=50, step=1 },
            { type = "slider", key = "spacing", db = db, text = L["Bar Spacing"] or "监控条堆叠间距", min=0, max=50, step=1 },
            { type = "dropdown", key = "growth", db = db, text = L["Growth Direction"] or "增长方向", options = { {text="UP", value="UP"}, {text="DOWN", value="DOWN"} } },
            { type = "dropdown", key = "texture", db = db, text = L["Bar Texture"] or "材质", options = GetTextureOptions() },
            { type = "dropdown", key = "font", db = db, text = L["Font"] or "字体", options = WF.UI.FontOptions },
            { type = "slider", key = "fontSize", db = db, text = L["Font Size"] or "字体大小", min=8, max=40, step=1 },
        }
        y = WF.UI:RenderOptionsGroup(scrollChild, 15, y, ColW * 1.5, { { type = "group", key = "wm_global", text = L["Global Settings"] or "全局排版设置", childs = globalOpts } }, function() WM:TriggerUpdate() end)
        y = y - 30
        
        local tabSkill = scrollChild.WMT_Skill or WF.UI.Factory:CreateFlatButton(scrollChild, "■ 技能冷却监控", function() WM.CurrentTab = "skill"; WF.UI:RefreshCurrentPanel() end)
        scrollChild.WMT_Skill = tabSkill; tabSkill:SetPoint("TOPLEFT", 15, y); tabSkill:SetWidth(150); tabSkill:Show()

        local tabBuff = scrollChild.WMT_Buff or WF.UI.Factory:CreateFlatButton(scrollChild, "■ 光环增益监控", function() WM.CurrentTab = "buff"; WF.UI:RefreshCurrentPanel() end)
        scrollChild.WMT_Buff = tabBuff; tabBuff:SetPoint("LEFT", tabSkill, "RIGHT", 10, 0); tabBuff:SetWidth(150); tabBuff:Show()
        
        if WM.CurrentTab == "skill" then
            tabSkill:SetBackdropBorderColor(0.2, 0.85, 0.3, 1); tabBuff:SetBackdropBorderColor(0, 0, 0, 1)
        else
            tabSkill:SetBackdropBorderColor(0, 0, 0, 1); tabBuff:SetBackdropBorderColor(0.2, 0.85, 0.3, 1)
        end
        y = y - 40
        
        local editBox = scrollChild.WM_EditBox
        if not editBox then
            editBox = CreateFrame("EditBox", nil, scrollChild, "BackdropTemplate")
            editBox:SetSize(120, 24); editBox:SetPoint("TOPLEFT", 15, y); editBox:SetAutoFocus(false)
            editBox:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); editBox:SetTextInsets(5, 5, 0, 0)
            editBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            editBox:SetBackdropColor(0.05, 0.05, 0.05, 1); editBox:SetBackdropBorderColor(0, 0, 0, 1)
            editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            editBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
            scrollChild.WM_EditBox = editBox
        end
        editBox:Show()
        
        local addBtn = scrollChild.WM_AddBtn or WF.UI.Factory:CreateFlatButton(scrollChild, "手动添加ID", function() 
            local id = tonumber(editBox:GetText())
            if id then
                local idStr = tostring(id)
                local dbStore = (WM.CurrentTab == "skill") and db.skills or db.buffs
                if not dbStore[idStr] then
                    if WM.CurrentTab == "skill" then dbStore[idStr] = { enable = true, trackType = "cooldown", useStatusBar = true, alwaysShow = true, color = {r=1,g=0.5,b=0,a=1} }
                    else dbStore[idStr] = { enable = true, unit = "player", useStatusBar = true, mode = "time", maxStacks = 5, alwaysShow = true, color = {r=0,g=0.8,b=1,a=1} } end
                end
                if WM.CurrentTab == "skill" then WM.selectedSkillID = idStr else WM.selectedBuffID = idStr end
                editBox:SetText(""); WF.UI:RefreshCurrentPanel(); WM:TriggerUpdate()
            end
        end)
        scrollChild.WM_AddBtn = addBtn; addBtn:SetPoint("LEFT", editBox, "RIGHT", 10, 0); addBtn:SetWidth(100); addBtn:Show()
        
        local scanBtn = scrollChild.WM_ScanBtn or WF.UI.Factory:CreateFlatButton(scrollChild, "重新扫描缓存", function() WM:ScanViewers(true) end)
        scrollChild.WM_ScanBtn = scanBtn; scanBtn:SetPoint("LEFT", addBtn, "RIGHT", 10, 0); scanBtn:SetWidth(100); scanBtn:Show()
        y = y - 40
        
        if WM.CurrentTab == "skill" then
            y = RenderIconGrid(scrollChild, y, ColW, WM.TrackedSkills, db.skills, WM.selectedSkillID)
        else
            y = RenderIconGrid(scrollChild, y, ColW, WM.TrackedBuffs, db.buffs, WM.selectedBuffID)
        end

        local selectedID = (WM.CurrentTab == "skill") and WM.selectedSkillID or WM.selectedBuffID
        local dbStore = (WM.CurrentTab == "skill") and db.skills or db.buffs

        if selectedID and dbStore[selectedID] then
            local d = dbStore[selectedID]
            local name = "未知"; pcall(function() name = C_Spell.GetSpellName(tonumber(selectedID)) or "未知" end)
            
            local opts = {}
            if WM.CurrentTab == "skill" then
                opts = {
                    { type = "toggle", key = "alwaysShow", db = d, text = "未冷却时常驻底框预览 (推荐配置时打开)" },
                    { type = "toggle", key = "useStatusBar", db = d, text = "启用纯平滑进度条模式 (关闭则为方形纯图标)" },
                    { type = "dropdown", key = "trackType", db = d, text = "监控类型", options = { {text="冷却监控 (Cooldown)", value="cooldown"}, {text="充能监控与自动切分 (Charge)", value="charge"} } },
                    { type = "color", key = "color", db = d, text = "专属前景色" },
                    { type = "slider", key = "height", db = d, text = "独立高度 (0=跟随全局)", min=0, max=50, step=1 },
                }
            else
                opts = {
                    { type = "toggle", key = "alwaysShow", db = d, text = "未激活时常驻底框预览 (推荐配置时打开)" },
                    { type = "toggle", key = "useStatusBar", db = d, text = "启用纯平滑进度条模式 (关闭则为方形纯图标)" },
                    { type = "dropdown", key = "mode", db = d, text = "进度条机制 (仅在纯条模式下生效)", options = { {text="按时间平滑缩减 (Time)", value="time"}, {text="按层数网格自动切分/法师冰刺 (Stack)", value="stack"} } },
                    { type = "slider", key = "maxStacks", db = d, text = "最大层数切分格子数 (仅Stack模式生效)", min=1, max=20, step=1 },
                    { type = "dropdown", key = "unit", db = d, text = "监控目标单位", options = { {text="玩家自身 (Player)", value="player"}, {text="当前目标 (Target)", value="target"} } },
                    { type = "color", key = "color", db = d, text = "专属前景色" },
                    { type = "slider", key = "height", db = d, text = "独立高度 (0=跟随全局)", min=0, max=50, step=1 },
                }
            end

            local tLbl = scrollChild.WM_SelTitle or scrollChild:CreateFontString(nil, "OVERLAY")
            scrollChild.WM_SelTitle = tLbl; tLbl:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE"); tLbl:SetPoint("TOPLEFT", 15, y)
            tLbl:SetText("正在编辑: |cffffaa00" .. name .. "|r (" .. selectedID .. ")")
            tLbl:Show()
            y = y - 30
            
            y = WF.UI:RenderOptionsGroup(scrollChild, 15, y, ColW*1.5, opts, function(v) WM:TriggerUpdate(); if v == "UI_REFRESH" then WF.UI:RefreshCurrentPanel() end end)
            
            local delBtn = scrollChild.WM_DelBtn or WF.UI.Factory:CreateFlatButton(scrollChild, "彻底删除此配置", function() 
                dbStore[selectedID] = nil
                if WM.CurrentTab == "skill" then WM.selectedSkillID = nil else WM.selectedBuffID = nil end
                WF.UI:RefreshCurrentPanel(); WM:TriggerUpdate() 
            end)
            scrollChild.WM_DelBtn = delBtn; delBtn:SetPoint("TOPLEFT", 15, y - 10); delBtn:Show(); y = y - 50
        else
            if scrollChild.WM_SelTitle then scrollChild.WM_SelTitle:Hide() end
            if scrollChild.WM_DelBtn then scrollChild.WM_DelBtn:Hide() end
        end
        
        return y
    end)
end