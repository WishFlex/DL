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

local function GetCurrentSpecID()
    local spec = GetSpecialization()
    if spec then
        local id = GetSpecializationInfo(spec)
        return id or 0
    end
    return 0
end

local function IsSecret(v)
    return type(v) == "number" and issecretvalue and issecretvalue(v)
end
local function IsSafeValue(val)
    if val == nil then return false end
    if type(issecretvalue) == "function" and issecretvalue(val) then return false end
    return true
end

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
WM.ExpandState = WM.ExpandState or { global = false, add = true, edit = true, free = false }

local function ForceSetButtonText(btn, text)
    if not btn then return end
    pcall(function() if type(btn.SetText) == "function" then btn:SetText(text) end end)
    for _, region in pairs({btn:GetRegions()}) do
        if region:IsObjectType("FontString") then
            pcall(function() region:SetText(text) end)
        end
    end
end

local function SyncHideOriginal(spellIDStr, hide)
    local CC = WF.CooldownCustomAPI or WF.CooldownCustom
    if CC and type(CC.TriggerLayout) == "function" then pcall(function() CC:TriggerLayout() end) end
    if _G.EssentialCooldownViewer and type(_G.EssentialCooldownViewer.UpdateLayout) == "function" then pcall(function() _G.EssentialCooldownViewer:UpdateLayout() end) end
    if _G.UtilityCooldownViewer and type(_G.UtilityCooldownViewer.UpdateLayout) == "function" then pcall(function() _G.UtilityCooldownViewer:UpdateLayout() end) end
    if _G.BuffIconCooldownViewer and type(_G.BuffIconCooldownViewer.UpdateLayout) == "function" then pcall(function() _G.BuffIconCooldownViewer:UpdateLayout() end) end
    if _G.BuffBarCooldownViewer and type(_G.BuffBarCooldownViewer.UpdateLayout) == "function" then pcall(function() _G.BuffBarCooldownViewer:UpdateLayout() end) end
end

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

local defaults = {
    skills = {}, buffs = {},
    freeLayout = { enable = false, layoutMode = "SPLIT", spacing = 1, yOffset = 0 }
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

local function GetGlobalVisuals()
    local crDB = WF.db.classResource
    if crDB then return crDB.texture or "Wish2", crDB.font or "Expressway", crDB.fontSize or 12 end
    return "Wish2", "Expressway", 12
end

function WM:UpdateAnchor()
    if not self.baseAnchor then return end
    local crDB = WF.db.classResource or {}
    if crDB.attachToResource and WF.ClassResourceAPI then return end

    self.baseAnchor:ClearAllPoints()
    local mover = _G["WishFlex_MonitorAnchorMover"]
    if mover then self.baseAnchor:SetPoint("CENTER", mover, "CENTER", 0, 0)
    else self.baseAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, -50) end
end

-- 【完美 1 像素抗锯齿渲染分割线】
function WM:UpdateDividers(f, numMax, width)
    f.dividerFrame = f.dividerFrame or CreateFrame("Frame", nil, f)
    f.dividerFrame:SetAllPoints()
    f.dividerFrame:SetFrameLevel(f:GetFrameLevel() + 15)
    
    f.dividers = f.dividers or {}
    local pixelSize = GetOnePixelSize()
    numMax = tonumber(numMax) or 1
    
    if numMax <= 1 then 
        for _, d in ipairs(f.dividers) do d:Hide() end 
        return 
    end 
    
    local exactSeg = width / numMax
    for i = 1, numMax - 1 do
        if not f.dividers[i] then 
            local tex = f.dividerFrame:CreateTexture(nil, "OVERLAY", nil, 7)
            tex:SetColorTexture(0, 0, 0, 1)
            if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
            if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
            f.dividers[i] = tex 
        end
        f.dividers[i]:SetWidth(pixelSize)
        local offset = PixelSnap(exactSeg * i)
        f.dividers[i]:ClearAllPoints()
        f.dividers[i]:SetPoint("TOPLEFT", f.dividerFrame, "TOPLEFT", offset, 0)
        f.dividers[i]:SetPoint("BOTTOMLEFT", f.dividerFrame, "BOTTOMLEFT", offset, 0)
        f.dividers[i]:Show()
    end
    for i = numMax, #f.dividers do if f.dividers[i] then f.dividers[i]:Hide() end end
end

function WM:GetFrame(index)
    if not self.FramePool[index] then
        local f = CreateFrame("Frame", "WishFlexMonitor_"..index, self.baseAnchor)
        f.bg = f:CreateTexture(nil, "BACKGROUND"); f.bg:SetAllPoints()
        
        f.iconFrame = CreateFrame("Frame", nil, f)
        f.iconFrame:SetFrameLevel(f:GetFrameLevel() + 1)
        f.icon = f.iconFrame:CreateTexture(nil, "ARTWORK")
        f.icon:SetAllPoints(); f.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        
        f.chargeBar = CreateFrame("StatusBar", nil, f)
        f.chargeBar:SetFrameLevel(f:GetFrameLevel() + 1); f.chargeBar:SetAllPoints()
        
        f.refreshCharge = CreateFrame("StatusBar", nil, f)
        f.refreshCharge:SetFrameLevel(f:GetFrameLevel() + 1)
        
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
        f.sbBorder = AddBoxBorder(f)
        
        f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
        f.cd:SetDrawSwipe(false); f.cd:SetDrawEdge(false); f.cd:SetDrawBling(false)
        f.cd.noCooldownOverride = true; f.cd.noOCC = true; f.cd.skipElvUICooldown = true
        f.cd:SetHideCountdownNumbers(false)
        f.cd:SetFrameLevel(f:GetFrameLevel() + 20)
        
        -- 【核心修复：文本层级拔高到 50，绝不被边框或分割线覆盖】
        local textFrame = CreateFrame("Frame", nil, f)
        textFrame:SetAllPoints(); textFrame:SetFrameLevel(f:GetFrameLevel() + 50)
        f.stackText = textFrame:CreateFontString(nil, "OVERLAY")
        f.timerText = textFrame:CreateFontString(nil, "OVERLAY")
        
        self.FramePool[index] = f
    end
    return self.FramePool[index]
end

local function SetTextAnchor(fontString, anchorPos, parent)
    if not fontString then return end
    fontString:ClearAllPoints()
    if anchorPos == "LEFT" then 
        fontString:SetPoint("LEFT", parent, "LEFT", 4, 0); fontString:SetJustifyH("LEFT")
    elseif anchorPos == "RIGHT" then 
        fontString:SetPoint("RIGHT", parent, "RIGHT", -4, 0); fontString:SetJustifyH("RIGHT")
    elseif anchorPos == "CENTER" then 
        fontString:SetPoint("CENTER", parent, "CENTER", 0, 0); fontString:SetJustifyH("CENTER")
    elseif anchorPos == "TOP" then 
        fontString:SetPoint("BOTTOM", parent, "TOP", 0, 4); fontString:SetJustifyH("CENTER")
    elseif anchorPos == "BOTTOM" then 
        fontString:SetPoint("TOP", parent, "BOTTOM", 0, -4); fontString:SetJustifyH("CENTER")
    end
end

function WM:ApplyFrameStyle(f, db, cfg, spellID)
    local gTexName, gFontPath, gFontSize = GetGlobalVisuals()
    local tex = LSM:Fetch("statusbar", gTexName) or "Interface\\Buttons\\WHITE8x8"
    
    f.bg:SetTexture(tex)
    local c = cfg.color or {r=0, g=0.8, b=1, a=1}
    f.bg:SetVertexColor(0.15, 0.15, 0.15, 0.9)
    
    local reverse = cfg.reverseFill and true or false
    f.chargeBar:SetReverseFill(reverse)
    f.refreshCharge:SetReverseFill(reverse)

    f.chargeBar:SetStatusBarTexture(tex)
    f.chargeBar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
    
    f.refreshCharge:SetStatusBarTexture(tex)
    f.refreshCharge:SetStatusBarColor(c.r, c.g, c.b, c.a or 0.8)

    local font = LSM:Fetch("font", gFontPath) or STANDARD_TEXT_FONT
    f.stackText:SetFont(font, gFontSize + 2, "OUTLINE"); f.stackText:SetTextColor(1, 1, 1, 1)

    if not f.timerText then
        if f.cd.timer and f.cd.timer.text then f.timerText = f.cd.timer.text
        else for _, region in pairs({f.cd:GetRegions()}) do if region:IsObjectType("FontString") then f.timerText = region; break end end end
    end
    
    if f.timerText then
        if f.timerText.FontTemplate then f.timerText:FontTemplate(font, gFontSize, "OUTLINE")
        else f.timerText:SetFont(font, gFontSize, "OUTLINE") end
        f.timerText:SetTextColor(1, 1, 1, 1)
    end

    local spellInfo = nil; pcall(function() spellInfo = C_Spell.GetSpellInfo(spellID) end)
    if spellInfo then f.icon:SetTexture(spellInfo.iconID) end

    local crDB = WF.db.classResource or {}
    local fWidth = (cfg.width and cfg.width > 0) and cfg.width or (crDB.width or 250)
    if (not cfg.width or cfg.width == 0) and crDB.attachToResource and WF.ClassResourceAPI and WF.ClassResourceAPI.baseAnchor then
        fWidth = WF.ClassResourceAPI.baseAnchor:GetWidth()
    end
    
    local fHeight = (cfg.height and cfg.height > 0) and cfg.height or (crDB.height or 14)
    local snapW = PixelSnap(fWidth)
    local snapH = PixelSnap(fHeight)
    
    f.calcWidth = snapW; f.calcHeight = snapH
    f:SetSize(snapW, snapH)
    
    local tAnchor = cfg.timerAnchor or "RIGHT"
    local sAnchor = cfg.stackAnchor or "LEFT"
    
    local showStack = (cfg.showStackText == true)
    local showTimer = (cfg.showTimerText ~= false)

    if cfg.useStatusBar then
        f.iconFrame:Hide()
        f.cd:ClearAllPoints(); f.cd:SetAllPoints(f)
        f.cd:SetDrawSwipe(false); f.cd:Show()
        
        f.bg:Show(); f.sbBorder:Show()
        SetTextAnchor(f.stackText, sAnchor, f)
        if f.timerText then SetTextAnchor(f.timerText, tAnchor, f) end
    else
        f.iconFrame:ClearAllPoints(); f.iconFrame:SetSize(snapH, snapH)
        f.iconFrame:SetPoint("CENTER", f, "CENTER", 0, 0); f.iconFrame:Show()
        
        f.cd:ClearAllPoints(); f.cd:SetAllPoints(f.iconFrame)
        f.cd:SetDrawSwipe(true); f.cd:Show()
        
        f.bg:Hide(); f.sbBorder:Hide(); f.chargeBar:Hide(); f.refreshCharge:Hide()
        
        SetTextAnchor(f.stackText, "BOTTOM", f.iconFrame)
        if f.timerText then SetTextAnchor(f.timerText, "CENTER", f.iconFrame) end
    end
    
    if showTimer then f.cd:SetHideCountdownNumbers(false); if f.timerText then f.timerText:Show() end
    else f.cd:SetHideCountdownNumbers(true); if f.timerText then f.timerText:Hide() end end
    
    if not showStack then f.stackText:Hide() end
end

function WM:Render()
    if not self.baseAnchor then return end
    
    -- 【一键受控】如果资源条全局开关被关闭，监控条自动跟随隐藏，强制阻断！
    local crDB = WF.db.classResource
    if crDB and crDB.enable == false then
        for i = 1, #self.FramePool do self.FramePool[i]:Hide() end
        return
    end

    local db = GetDB()
    wipe(self.ActiveFrames)
    local activeCount = 0
    WM.spellMaxChargeCache = WM.spellMaxChargeCache or {}
    
    local currentSpecID = GetCurrentSpecID()
    
    local function ProcessItem(spellIDStr, cfg, isBuff)
        if not cfg.enable then return end
        
        if not cfg.allSpecs then
            if not cfg.specID or cfg.specID == 0 then cfg.specID = currentSpecID end
            if cfg.specID ~= currentSpecID then return end
        end

        local spellID = tonumber(spellIDStr)
        local isActive, rawCount, maxVal, durObjC = false, 0, 1, nil
        
        if isBuff then
            local unit = cfg.unit or "player"
            local cdID = WM.SpellToCD[spellID]
            local instID = nil
            for i = 1, #WM.ActiveBuffFrames do
                local frame = WM.ActiveBuffFrames[i]
                if frame.cooldownID == cdID or (frame.cooldownInfo and frame.cooldownInfo.cooldownID == cdID) then
                    instID = frame.auraInstanceID; unit = frame.auraDataUnit or unit; break
                end
            end
            
            if instID and IsSafeValue(instID) then
                pcall(function() 
                    local data = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, instID)
                    if data then isActive = true; rawCount = data.applications or 0; durObjC = C_UnitAuras.GetAuraDuration(unit, instID) end
                end)
            end
            
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
                    if cInfo then
                        local dur = cInfo.duration
                        if IsSecret(dur) or (tonumber(dur) and tonumber(dur) > 1.5) then 
                            isActive = true; durObjC = C_Spell.GetSpellCooldownDuration(spellID) 
                        end
                    end
                end)
            elseif cfg.trackType == "charge" then
                pcall(function()
                    local chInfo = C_Spell.GetSpellCharges(spellID)
                    if chInfo then
                        if type(chInfo.maxCharges) == "number" and not IsSecret(chInfo.maxCharges) then WM.spellMaxChargeCache[spellID] = chInfo.maxCharges end
                        maxVal = WM.spellMaxChargeCache[spellID] or chInfo.maxCharges or 1
                        rawCount = chInfo.currentCharges or 0
                        pcall(function() durObjC = C_Spell.GetSpellChargeDuration(spellID) end)
                        if IsSecret(rawCount) or (tonumber(rawCount) or 0) > 0 or durObjC then isActive = true end
                    end
                end)
            end
        end
        
        if isActive or cfg.alwaysShow then
            activeCount = activeCount + 1
            local f = self:GetFrame(activeCount)
            f.cfg = cfg
            self:ApplyFrameStyle(f, db, cfg, spellID)
            
            if type(maxVal) == "number" and not IsSecret(maxVal) then f.cachedMaxVal = maxVal end
            local safeMax = f.cachedMaxVal or 1; if safeMax < 1 then safeMax = 1 end
            f.maxVal = safeMax
            
            local safeCount = 0
            if type(rawCount) == "number" and not IsSecret(rawCount) then 
                safeCount = rawCount
            else
                local exact = 0
                if f.chargeBar:GetValue() and f.chargeBar:GetValue() > 0 then exact = math.floor(f.chargeBar:GetValue() + 0.5) end
                safeCount = exact
            end
            
            pcall(function()
                if cfg.showStackText == true then
                    if IsSecret(rawCount) then f.stackText:SetFormattedText("%d", rawCount); f.stackText:Show()
                    else local numC = tonumber(rawCount) or 0; if numC > 0 then f.stackText:SetText(numC); f.stackText:Show() else f.stackText:Hide() end end
                else
                    f.stackText:Hide()
                end
            end)
            
            if isActive then
                if cfg.useStatusBar then
                    if isBuff and cfg.mode == "stack" then
                        f.chargeBar:Show(); f.refreshCharge:Hide()
                        pcall(function() if f.chargeBar.ClearTimerDuration then f.chargeBar:ClearTimerDuration() end end)
                        f.chargeBar:SetMinMaxValues(0, safeMax)
                        pcall(function() f.chargeBar:SetValue(rawCount) end)
                        self:UpdateDividers(f, safeMax, f.calcWidth)
                        
                        if cfg.dynamicTimer and f.timerText and safeMax > 1 then
                            f.timerText:ClearAllPoints()
                            local cellWidth = f.calcWidth / safeMax
                            local rc = 0
                            pcall(function() if not IsSecret(rawCount) then rc = tonumber(rawCount) or 0 end end)
                            local currentCell = rc > 0 and (rc - 1) or 0
                            if currentCell >= safeMax then currentCell = safeMax - 1 end
                            if cfg.reverseFill then f.timerText:SetPoint("CENTER", f.chargeBar, "RIGHT", -((currentCell * cellWidth) + (cellWidth / 2)), 0)
                            else f.timerText:SetPoint("CENTER", f.chargeBar, "LEFT", (currentCell * cellWidth) + (cellWidth / 2), 0) end
                            f.timerText:SetJustifyH("CENTER")
                        end

                    elseif cfg.trackType == "charge" then
                        f.chargeBar:Show()
                        pcall(function() if f.chargeBar.ClearTimerDuration then f.chargeBar:ClearTimerDuration() end end)
                        f.chargeBar:SetMinMaxValues(0, safeMax)
                        pcall(function() f.chargeBar:SetValue(rawCount) end) 

                        local needsRecharge = false
                        if IsSecret(rawCount) then needsRecharge = true elseif type(rawCount) == "number" and rawCount < safeMax then needsRecharge = true end

                        if needsRecharge and durObjC then
                            f.refreshCharge:SetSize(f.calcWidth / safeMax, f.calcHeight)
                            f.refreshCharge:ClearAllPoints()
                            if cfg.reverseFill then f.refreshCharge:SetPoint("RIGHT", f.chargeBar:GetStatusBarTexture(), "LEFT", 0, 0)
                            else f.refreshCharge:SetPoint("LEFT", f.chargeBar:GetStatusBarTexture(), "RIGHT", 0, 0) end
                            
                            pcall(function()
                                f.refreshCharge:SetMinMaxValues(0, 1)
                                local dir = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime or 0
                                f.refreshCharge:SetTimerDuration(durObjC, 0, dir)
                            end)
                            f.refreshCharge:Show()
                        else
                            f.refreshCharge:Hide()
                            pcall(function() if f.refreshCharge.ClearTimerDuration then f.refreshCharge:ClearTimerDuration() end end)
                        end
                        self:UpdateDividers(f, safeMax, f.calcWidth)
                        
                        if cfg.dynamicTimer and f.timerText and safeMax > 1 then
                            f.timerText:ClearAllPoints()
                            f.timerText:SetPoint("CENTER", f.refreshCharge, "CENTER", 0, 0)
                            f.timerText:SetJustifyH("CENTER")
                        end

                    else
                        f.chargeBar:Show(); f.refreshCharge:Hide()
                        self:UpdateDividers(f, 0, f.calcWidth)
                        pcall(function() if f.refreshCharge.ClearTimerDuration then f.refreshCharge:ClearTimerDuration() end end)
                        pcall(function()
                            f.chargeBar:SetMinMaxValues(0, 1)
                            if durObjC then f.chargeBar:SetTimerDuration(durObjC); if f.chargeBar.SetToTargetValue then f.chargeBar:SetToTargetValue() end
                            else if f.chargeBar.ClearTimerDuration then f.chargeBar:ClearTimerDuration() end; f.chargeBar:SetValue(1) end
                        end)
                    end
                end
                
                pcall(function()
                    if durObjC then
                        if f.cd.SetCooldownFromDurationObject then pcall(function() f.cd:SetCooldownFromDurationObject(durObjC) end)
                        else
                            local st, dur
                            if type(durObjC.GetCooldownStartTime) == "function" then pcall(function() st = durObjC:GetCooldownStartTime(); dur = durObjC:GetCooldownDuration() end)
                            else pcall(function() st = durObjC.startTime; dur = durObjC.duration end) end
                            if st and dur and (IsSecret(dur) or (tonumber(dur) and tonumber(dur) > 0)) then f.cd:SetCooldown(st, dur) else f.cd:Clear() end
                        end
                    else f.cd:Clear() end
                end)
                f:SetAlpha(1)
            else
                f.cd:Clear()
                if cfg.useStatusBar then
                    f.chargeBar:Show(); f.refreshCharge:Hide()
                    self:UpdateDividers(f, safeMax, f.calcWidth)
                    pcall(function() if f.chargeBar.ClearTimerDuration then f.chargeBar:ClearTimerDuration() end end)
                    pcall(function() if f.refreshCharge.ClearTimerDuration then f.refreshCharge:ClearTimerDuration() end end)
                    f.chargeBar:SetMinMaxValues(0, safeMax); f.chargeBar:SetValue(0)
                    f.chargeBar:SetStatusBarColor(0.4, 0.4, 0.4, 0.8) 
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
    
    -- ==================== 阵列排版与自由中心分组 ====================
    local layoutFrames = {}
    local freeLayoutFrames = {}
    
    for _, f in ipairs(self.ActiveFrames) do
        f:ClearAllPoints()
        if f.cfg.independent then
            f:SetPoint("CENTER", UIParent, "CENTER", PixelSnap(f.cfg.indX or 0), PixelSnap(f.cfg.indY or 0))
            self:UpdateDividers(f, f.maxVal or 1, f.calcWidth)
            if f.cfg.trackType == "charge" and f.refreshCharge then f.refreshCharge:SetSize(f.calcWidth / (f.maxVal or 1), f.calcHeight) end
        elseif db.freeLayout.enable and f.cfg.inFreeLayout then
            table.insert(freeLayoutFrames, f)
        else
            table.insert(layoutFrames, f)
        end
    end

    local freeCount = #freeLayoutFrames
    if freeCount > 0 then
        local layoutMode = db.freeLayout.layoutMode or "SPLIT"
        local crDB = WF.db.classResource or {}
        local targetWidth = crDB.width or 250
        if crDB.attachToResource and WF.ClassResourceAPI and WF.ClassResourceAPI.baseAnchor then
            targetWidth = WF.ClassResourceAPI.baseAnchor:GetWidth()
        end
        local spacing = PixelSnap(db.freeLayout.spacing or 1)
        local yOff = PixelSnap(db.freeLayout.yOffset or 0)
        
        if layoutMode == "SPLIT" then
            local eachWidth = (targetWidth - (freeCount - 1) * spacing) / freeCount
            if eachWidth < 1 then eachWidth = 1 end
            local startX = -targetWidth / 2 + eachWidth / 2
            
            for _, f in ipairs(freeLayoutFrames) do
                f:SetSize(PixelSnap(eachWidth), PixelSnap(f.calcHeight))
                f.calcWidth = PixelSnap(eachWidth)
                self:UpdateDividers(f, f.maxVal or 1, f.calcWidth)
                if f.cfg.trackType == "charge" and f.refreshCharge then f.refreshCharge:SetSize(f.calcWidth / (f.maxVal or 1), f.calcHeight) end
                
                f:SetPoint("CENTER", self.baseAnchor, "TOP", startX, yOff)
                startX = startX + eachWidth + spacing
            end
        else
            local totalWidth = 0
            for _, f in ipairs(freeLayoutFrames) do totalWidth = totalWidth + f.calcWidth end
            totalWidth = totalWidth + (freeCount - 1) * spacing
            local startX = -totalWidth / 2
            
            for _, f in ipairs(freeLayoutFrames) do
                self:UpdateDividers(f, f.maxVal or 1, f.calcWidth)
                if f.cfg.trackType == "charge" and f.refreshCharge then f.refreshCharge:SetSize(f.calcWidth / (f.maxVal or 1), f.calcHeight) end
                
                f:SetPoint("LEFT", self.baseAnchor, "TOP", startX, yOff)
                startX = startX + f.calcWidth + spacing
            end
        end
    end

    local count = #layoutFrames
    if count > 0 then
        local crDB = WF.db.classResource or {}
        local growth = crDB.growth or "HCENTER"
        local spacing = PixelSnap(crDB.spacing or 1)
        
        if growth == "HCENTER" then
            local totalWidth = 0
            for _, f in ipairs(layoutFrames) do 
                self:UpdateDividers(f, f.maxVal or 1, f.calcWidth)
                if f.cfg.trackType == "charge" and f.refreshCharge then f.refreshCharge:SetSize(f.calcWidth / (f.maxVal or 1), f.calcHeight) end
                totalWidth = totalWidth + f.calcWidth 
            end
            totalWidth = totalWidth + (count - 1) * spacing
            local startX = -totalWidth / 2
            for _, f in ipairs(layoutFrames) do
                f:SetPoint("LEFT", self.baseAnchor, "CENTER", startX, 0)
                startX = startX + f.calcWidth + spacing
            end
        else
            for i, f in ipairs(layoutFrames) do
                self:UpdateDividers(f, f.maxVal or 1, f.calcWidth)
                if f.cfg.trackType == "charge" and f.refreshCharge then f.refreshCharge:SetSize(f.calcWidth / (f.maxVal or 1), f.calcHeight) end
                
                if growth == "LEFT" then
                    if i == 1 then f:SetPoint("RIGHT", self.baseAnchor, "RIGHT", 0, 0) else f:SetPoint("RIGHT", layoutFrames[i-1], "LEFT", -spacing, 0) end
                elseif growth == "RIGHT" then
                    if i == 1 then f:SetPoint("LEFT", self.baseAnchor, "LEFT", 0, 0) else f:SetPoint("LEFT", layoutFrames[i-1], "RIGHT", spacing, 0) end
                elseif growth == "UP" then
                    if i == 1 then f:SetPoint("BOTTOM", self.baseAnchor, "BOTTOM", 0, 0) else f:SetPoint("BOTTOM", layoutFrames[i-1], "TOP", 0, spacing) end
                elseif growth == "DOWN" then
                    if i == 1 then f:SetPoint("TOP", self.baseAnchor, "TOP", 0, 0) else f:SetPoint("TOP", layoutFrames[i-1], "BOTTOM", 0, -spacing) end
                end
            end
        end
    end
end

function WM:TriggerUpdate()
    if self.updatePending then return end
    self.updatePending = true
    C_Timer.After(0.05, function() self.updatePending = false; WM:ScanViewers(); self:Render() end)
end

-- =========================================
-- [初始化机制]
-- =========================================
local function InitWishMonitor()
    GetDB()
    local anchor = CreateFrame("Frame", "WishFlex_MonitorAnchor", UIParent)
    anchor:SetSize(250, 14)
    WM.baseAnchor = anchor
    
    if WF.CreateMover then WF:CreateMover(anchor, "WishFlex_MonitorAnchorMover", {"CENTER", UIParent, "CENTER", 0, -50}, 250, 14, "WishFlex: " .. (L["Custom Monitor"] or "自定义监控")) end
    
    WM:RegisterEvent("PLAYER_ENTERING_WORLD", function() 
        C_Timer.After(0.5, function() WM:TriggerUpdate() end) 
    end)
    
    WM:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function()
        C_Timer.After(0.5, function()
            local currentSpec = GetCurrentSpecID()
            local function validate(selID, dbStore)
                if selID and dbStore[selID] then
                    local cfg = dbStore[selID]
                    if not cfg.allSpecs and cfg.specID and cfg.specID ~= 0 and cfg.specID ~= currentSpec then return nil end
                end
                return selID
            end
            WM.selectedSkillID = validate(WM.selectedSkillID, GetDB().skills)
            WM.selectedBuffID = validate(WM.selectedBuffID, GetDB().buffs)
            WM:TriggerUpdate() 
            if WF.UI and WF.UI.CurrentNodeKey == "classResource_Monitor" then WF.UI:RefreshCurrentPanel() end
        end)
    end)
    
    WM:RegisterEvent("TRAIT_CONFIG_UPDATED", function() WM:TriggerUpdate() end)
    WM:RegisterEvent("UNIT_AURA", function(self, e, unit) if unit == "player" or unit == "target" then WM:TriggerUpdate() end end)
    WM:RegisterEvent("PLAYER_TARGET_CHANGED", function() WM:TriggerUpdate() end)
    WM:RegisterEvent("SPELL_UPDATE_COOLDOWN", "TriggerUpdate")
    WM:RegisterEvent("SPELL_UPDATE_CHARGES", "TriggerUpdate")
    
    C_Timer.After(1, function()
        WM:UpdateAnchor()
        for _, vName in ipairs({"EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer"}) do
            local viewer = _G[vName]
            if viewer and viewer.UpdateLayout then hooksecurefunc(viewer, "UpdateLayout", function() WM:TriggerUpdate() end) end
        end
    end)
end

WF:RegisterModule("wishMonitor", L["Custom Monitor"] or "自定义监控", InitWishMonitor)

-- =========================================================================
-- [UI 面板引擎重构]
-- =========================================================================
if WF.UI then
    WF.UI:RegisterMenu({ id = "CR_Monitor", parent = "ClassResource", name = L["Custom Monitor"] or "自定义监控", key = "classResource_Monitor", order = 5 })

    local function RenderIconGrid(scrollChild, poolName, y, ColW, scanData, dbStore, selectedID, isFreeMode)
        local list = {}; local seen = {}
        local currentSpec = GetCurrentSpecID()
        
        if isFreeMode then
            for idStr, cfg in pairs(dbStore) do
                if cfg.enable and (cfg.allSpecs or not cfg.specID or cfg.specID == 0 or cfg.specID == currentSpec) then
                    local numId = tonumber(idStr); local si = nil; pcall(function() si = C_Spell.GetSpellInfo(numId) end)
                    local icon = si and si.iconID or 134400; local name = si and si.name or idStr
                    if scanData[idStr] then icon = scanData[idStr].icon; name = scanData[idStr].name end
                    table.insert(list, {idStr = idStr, name = name, icon = icon})
                end
            end
        else
            for idStr, info in pairs(scanData) do
                local cfg = dbStore[idStr]
                local isValid = true
                if cfg and not cfg.allSpecs and cfg.specID and cfg.specID ~= 0 and cfg.specID ~= currentSpec then isValid = false end
                if isValid and not seen[idStr] then seen[idStr] = true; table.insert(list, {idStr = idStr, name = info.name, icon = info.icon}) end
            end
            for idStr, cfg in pairs(dbStore) do
                if not seen[idStr] then
                    if cfg.allSpecs or not cfg.specID or cfg.specID == 0 or cfg.specID == currentSpec then
                        if cfg.enable then
                            seen[idStr] = true
                            local numId = tonumber(idStr); local si = nil; pcall(function() si = C_Spell.GetSpellInfo(numId) end)
                            table.insert(list, {idStr = idStr, name = si and si.name or tostring(numId), icon = si and si.iconID or 134400})
                        else dbStore[idStr] = nil end
                    end
                end
            end
        end
        table.sort(list, function(a, b) return a.name < b.name end)

        local ICON_SIZE, PADDING = 36, 6
        local MAX_COLS = math.floor((ColW * 1.5) / (ICON_SIZE + PADDING))

        if not scrollChild[poolName] then scrollChild[poolName] = {} end
        for _, btn in ipairs(scrollChild[poolName]) do btn:Hide() end

        local row, col = 0, 0
        for i, item in ipairs(list) do
            local btn = scrollChild[poolName][i]
            if not btn then
                btn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
                btn:SetSize(ICON_SIZE, ICON_SIZE)
                btn:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
                local tex = btn:CreateTexture(nil, "BACKGROUND")
                tex:SetPoint("TOPLEFT", 1, -1); tex:SetPoint("BOTTOMRIGHT", -1, 1)
                tex:SetTexCoord(0.1, 0.9, 0.1, 0.9); btn.tex = tex; btn:RegisterForClicks("AnyUp")
                scrollChild[poolName][i] = btn
            end

            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", 15 + col * (ICON_SIZE + PADDING), y - row * (ICON_SIZE + PADDING))
            btn.tex:SetTexture(item.icon)

            if isFreeMode then
                if dbStore[item.idStr] and dbStore[item.idStr].inFreeLayout then btn:SetBackdropBorderColor(0.2, 0.85, 0.3, 1) else btn:SetBackdropBorderColor(0, 0, 0, 1) end
            else
                if item.idStr == selectedID then btn:SetBackdropBorderColor(0.2, 0.6, 1, 1)
                elseif dbStore[item.idStr] and dbStore[item.idStr].enable then btn:SetBackdropBorderColor(0.2, 0.85, 0.3, 1)
                else btn:SetBackdropBorderColor(0, 0, 0, 1) end
            end

            btn:SetScript("OnClick", function(self, button) 
                if isFreeMode then
                    if dbStore[item.idStr] then
                        dbStore[item.idStr].inFreeLayout = not dbStore[item.idStr].inFreeLayout
                        WF.UI:RefreshCurrentPanel(); WM:TriggerUpdate()
                    end
                else
                    local idStr = item.idStr
                    if not dbStore[idStr] then
                        if WM.CurrentTab == "skill" then dbStore[idStr] = { enable = false, specID = GetCurrentSpecID(), allSpecs = false, trackType = "cooldown", alwaysShow = true, useStatusBar = true, color = {r=1,g=0.5,b=0,a=1}, showStackText = false, showTimerText = true, hideOriginal = false }
                        else dbStore[idStr] = { enable = false, specID = GetCurrentSpecID(), allSpecs = false, unit = "player", mode = "time", maxStacks = 5, alwaysShow = true, useStatusBar = true, color = {r=0,g=0.8,b=1,a=1}, showStackText = false, showTimerText = true, hideOriginal = false } end
                    end
                    if button == "RightButton" then 
                        dbStore[idStr].enable = not dbStore[idStr].enable
                    else
                        if WM.CurrentTab == "skill" then WM.selectedSkillID = idStr else WM.selectedBuffID = idStr end
                        WM.ExpandState.edit = true
                    end
                    WF.UI:RefreshCurrentPanel(); WM:TriggerUpdate()
                end
            end)
            
            btn:SetScript("OnEnter", function() GameTooltip:SetOwner(btn, "ANCHOR_RIGHT"); GameTooltip:SetSpellByID(tonumber(item.idStr)); GameTooltip:AddLine(" ")
                if isFreeMode then GameTooltip:AddLine(L["Left Click: Add/Remove Free Layout"] or "|cff00ffcc[左键]|r 加入/移出自由排列组", 1,1,1)
                else GameTooltip:AddLine(L["Left Click: Edit"] or "|cff00ffcc[左键]|r 编辑监控参数", 1,1,1); GameTooltip:AddLine(L["Right Click: Toggle"] or "|cffffaa00[右键]|r 快速启用/禁用", 1,1,1) end
                GameTooltip:Show() 
            end)
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
        
        if scrollChild.WMT_Skill then scrollChild.WMT_Skill:Hide(); scrollChild.WMT_Buff:Hide() end
        if scrollChild.WM_EditBox then scrollChild.WM_EditBox:Hide(); scrollChild.WM_AddBtn:Hide(); scrollChild.WM_ScanBtn:Hide() end
        if scrollChild.WM_SelTitle then scrollChild.WM_SelTitle:Hide(); scrollChild.WM_DelBtn:Hide() end
        if scrollChild.WM_FreeDesc then scrollChild.WM_FreeDesc:Hide(); scrollChild.WM_FreeDesc2:Hide(); scrollChild.WM_FreeDescHelp:Hide() end
        if scrollChild.WM_GridPool then for _, b in ipairs(scrollChild.WM_GridPool) do b:Hide() end end
        if scrollChild.WM_FreeGridPool_S then for _, b in ipairs(scrollChild.WM_FreeGridPool_S) do b:Hide() end end
        if scrollChild.WM_FreeGridPool_B then for _, b in ipairs(scrollChild.WM_FreeGridPool_B) do b:Hide() end end
        
        -- ================== 分类一：全局指示信息 ==================
        local helpText = scrollChild.WM_Help or scrollChild:CreateFontString(nil, "OVERLAY")
        scrollChild.WM_Help = helpText
        helpText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        helpText:SetPoint("TOPLEFT", 15, y)
        helpText:SetWidth(ColW * 1.5)
        helpText:SetJustifyH("LEFT")
        helpText:SetText(L["Monitor Integration Help"] or "|cff00ccff[模块已深度整合]|r 全局材质、字体、宽度、以及屏幕上的排版层级，已完全交由 |cff00ff00[职业资源条 -> 全局设置]|r 统一控制。在这里你只需要专注添加技能！")
        helpText:Show()
        y = y - 40

        -- ================== 分类二：添加与管理监控 ==================
        local tAdd = L["Add Monitor"] or "添加与管理监控"
        local btnAdd = scrollChild.WM_BtnAddHeader
        if not btnAdd then
            btnAdd = WF.UI.Factory:CreateFlatButton(scrollChild, tAdd, function() WM.ExpandState.add = not WM.ExpandState.add; WF.UI:RefreshCurrentPanel() end)
            scrollChild.WM_BtnAddHeader = btnAdd
        end
        ForceSetButtonText(btnAdd, tAdd)
        btnAdd:ClearAllPoints()
        btnAdd:SetPoint("TOPLEFT", 15, y); btnAdd:SetWidth(ColW * 1.5); btnAdd:Show()
        y = y - 35

        if WM.ExpandState.add then
            local tabWidth = (ColW * 1.5 - 10) / 2
            local tabSkill = scrollChild.WMT_Skill or WF.UI.Factory:CreateFlatButton(scrollChild, L["Skill Cooldown Monitor"] or "■ 技能冷却", function() WM.CurrentTab = "skill"; WF.UI:RefreshCurrentPanel() end)
            scrollChild.WMT_Skill = tabSkill
            tabSkill:ClearAllPoints(); tabSkill:SetPoint("TOPLEFT", 15, y); tabSkill:SetWidth(tabWidth); tabSkill:Show()

            local tabBuff = scrollChild.WMT_Buff or WF.UI.Factory:CreateFlatButton(scrollChild, L["Aura Buff Monitor"] or "■ 光环增益", function() WM.CurrentTab = "buff"; WF.UI:RefreshCurrentPanel() end)
            scrollChild.WMT_Buff = tabBuff
            tabBuff:ClearAllPoints(); tabBuff:SetPoint("LEFT", tabSkill, "RIGHT", 10, 0); tabBuff:SetWidth(tabWidth); tabBuff:Show()
            
            if WM.CurrentTab == "skill" then tabSkill:SetBackdropBorderColor(0.2, 0.85, 0.3, 1); tabBuff:SetBackdropBorderColor(0, 0, 0, 1) else tabSkill:SetBackdropBorderColor(0, 0, 0, 1); tabBuff:SetBackdropBorderColor(0.2, 0.85, 0.3, 1) end
            y = y - 40
            
            if WM.CurrentTab == "skill" then y = RenderIconGrid(scrollChild, "WM_GridPool", y, ColW, WM.TrackedSkills, db.skills, WM.selectedSkillID, false)
            else y = RenderIconGrid(scrollChild, "WM_GridPool", y, ColW, WM.TrackedBuffs, db.buffs, WM.selectedBuffID, false) end
            y = y - 15
            
            local editBox = scrollChild.WM_EditBox
            if not editBox then
                editBox = CreateFrame("EditBox", nil, scrollChild, "BackdropTemplate"); editBox:SetSize(120, 24); editBox:SetAutoFocus(false)
                editBox:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); editBox:SetTextInsets(5, 5, 0, 0); editBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
                editBox:SetBackdropColor(0.05, 0.05, 0.05, 1); editBox:SetBackdropBorderColor(0, 0, 0, 1)
                editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end); editBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
                scrollChild.WM_EditBox = editBox
            end
            
            local totalInputWidth = 120 + 10 + 120 + 10 + 120
            local startX = 15 + ((ColW * 1.5) - totalInputWidth) / 2
            editBox:ClearAllPoints(); editBox:SetPoint("TOPLEFT", startX, y); editBox:Show()
            
            local btnAddID = scrollChild.WM_AddBtn or WF.UI.Factory:CreateFlatButton(scrollChild, L["Manual Add ID"] or "手动添加ID", function() 
                local id = tonumber(editBox:GetText()); if id then
                    local idStr = tostring(id); local dbStore = (WM.CurrentTab == "skill") and db.skills or db.buffs
                    if not dbStore[idStr] then
                        if WM.CurrentTab == "skill" then dbStore[idStr] = { enable = true, specID = GetCurrentSpecID(), allSpecs = false, trackType = "cooldown", useStatusBar = true, alwaysShow = true, color = {r=1,g=0.5,b=0,a=1}, showStackText = false, showTimerText = true, hideOriginal = false }
                        else dbStore[idStr] = { enable = true, specID = GetCurrentSpecID(), allSpecs = false, unit = "player", useStatusBar = true, mode = "time", maxStacks = 5, alwaysShow = true, color = {r=0,g=0.8,b=1,a=1}, showStackText = false, showTimerText = true, hideOriginal = false } end
                    end
                    if WM.CurrentTab == "skill" then WM.selectedSkillID = idStr else WM.selectedBuffID = idStr end
                    WM.ExpandState.edit = true
                    editBox:SetText(""); WF.UI:RefreshCurrentPanel(); WM:TriggerUpdate()
                end
            end)
            scrollChild.WM_AddBtn = btnAddID
            btnAddID:ClearAllPoints(); btnAddID:SetPoint("LEFT", editBox, "RIGHT", 10, 0); btnAddID:SetWidth(120); btnAddID:Show()
            
            local scanBtn = scrollChild.WM_ScanBtn or WF.UI.Factory:CreateFlatButton(scrollChild, L["Rescan Cache"] or "重新扫描缓存", function() WM:ScanViewers(true) end)
            scrollChild.WM_ScanBtn = scanBtn
            scanBtn:ClearAllPoints(); scanBtn:SetPoint("LEFT", btnAddID, "RIGHT", 10, 0); scanBtn:SetWidth(120); scanBtn:Show()
            y = y - 40
        end

        -- ================== 分类三：当前监控设置 ==================
        local selectedID = (WM.CurrentTab == "skill") and WM.selectedSkillID or WM.selectedBuffID
        local dbStore = (WM.CurrentTab == "skill") and db.skills or db.buffs

        if selectedID and dbStore[selectedID] then
            local d = dbStore[selectedID]
            local name = "Unknown"; pcall(function() name = C_Spell.GetSpellName(tonumber(selectedID)) or "Unknown" end)
            
            local tEdit = (L["Monitor Settings"] or "当前监控设置") .. " : " .. name
            local btnEdit = scrollChild.WM_BtnEditHeader
            if not btnEdit then
                btnEdit = WF.UI.Factory:CreateFlatButton(scrollChild, tEdit, function() WM.ExpandState.edit = not WM.ExpandState.edit; WF.UI:RefreshCurrentPanel() end)
                scrollChild.WM_BtnEditHeader = btnEdit
            end
            ForceSetButtonText(btnEdit, tEdit)
            btnEdit:ClearAllPoints()
            btnEdit:SetPoint("TOPLEFT", 15, y); btnEdit:SetWidth(ColW * 1.5); btnEdit:Show()
            y = y - 35

            if WM.ExpandState.edit then
                local anchorOptions = { 
                    {text=L["Right"] or "右侧", value="RIGHT"}, 
                    {text=L["Left"] or "左侧", value="LEFT"}, 
                    {text=L["Center"] or "居中", value="CENTER"}, 
                    {text=L["Top Outside"] or "顶部外侧", value="TOP"}, 
                    {text=L["Bottom Outside"] or "底部外侧", value="BOTTOM"} 
                }
                
                local commonOpts = {
                    { type = "toggle", key = "allSpecs", db = d, text = L["Share All Specs"] or "所有专精共享此监控" },
                    { type = "toggle", key = "alwaysShow", db = d, text = L["Always Show Background"] or "常驻底框预览 (配置时打开)" },
                    { type = "toggle", key = "hideOriginal", db = d, text = L["Hide Original Cooldown/Aura"] or "在原版冷却管理器中隐藏该图标" },
                    { type = "toggle", key = "useStatusBar", db = d, text = L["Enable Smooth Status Bar Mode"] or "启用进度条模式" },
                    { type = "color", key = "color", db = d, text = L["Custom Foreground Color"] or "专属前景色" },
                    { type = "toggle", key = "reverseFill", db = d, text = L["Reverse Fill"] or "启用反向动画" },
                    { type = "slider", key = "width", db = d, text = L["Independent Width"] or "独立宽度 (0=跟随全局)", min=0, max=600, step=1 },
                    { type = "slider", key = "height", db = d, text = L["Independent Height"] or "独立高度 (0=跟随全局)", min=0, max=50, step=1 },
                    { type = "toggle", key = "showStackText", db = d, text = L["Enable Stack Text"] or "启用层数文本显示" },
                    { type = "dropdown", key = "stackAnchor", db = d, text = L["Stack Text Anchor"] or "独立层数文本位置", options = anchorOptions },
                    { type = "toggle", key = "showTimerText", db = d, text = L["Enable Timer Text"] or "启用倒计时文本显示" },
                    { type = "toggle", key = "dynamicTimer", db = d, text = L["Dynamic Timer Position"] or "动态时间文本 (自动跟随当前格子)" },
                    { type = "dropdown", key = "timerAnchor", db = d, text = L["Timer Text Anchor"] or "独立时间文本位置", options = anchorOptions },
                    { type = "toggle", key = "independent", db = d, text = L["Independent Positioning"] or "完全独立移动" },
                    { type = "slider", key = "indX", db = d, text = L["Independent X Offset"] or "独立 X 轴偏移", min=-1000, max=1000, step=1 },
                    { type = "slider", key = "indY", db = d, text = L["Independent Y Offset"] or "独立 Y 轴偏移", min=-1000, max=1000, step=1 },
                }
                
                local opts = {}
                if WM.CurrentTab == "skill" then
                    opts = { { type = "dropdown", key = "trackType", db = d, text = L["Monitor Type"] or "监控类型", options = { {text=L["Cooldown Monitor"] or "普通冷却", value="cooldown"}, {text=L["Charge Monitor & Auto-Slice"] or "充能与切分", value="charge"} } } }
                    for _, opt in ipairs(commonOpts) do table.insert(opts, opt) end
                else
                    opts = {
                        { type = "dropdown", key = "mode", db = d, text = L["Status Bar Mechanism"] or "机制", options = { {text=L["Smooth Time Reduction"] or "按时间平滑", value="time"}, {text=L["Grid Slice by Stacks"] or "按层数网格叠加", value="stack"} } },
                        { type = "slider", key = "maxStacks", db = d, text = L["Max Stacks Grid Slices"] or "层数格子上限", min=1, max=20, step=1 },
                        { type = "dropdown", key = "unit", db = d, text = L["Monitor Target Unit"] or "目标", options = { {text=L["Player"] or "玩家自身", value="player"}, {text=L["Current Target"] or "当前目标", value="target"} } },
                    }
                    for _, opt in ipairs(commonOpts) do table.insert(opts, opt) end
                end

                y = WF.UI:RenderOptionsGroup(scrollChild, 15, y, ColW*1.5, opts, function(v) 
                    if d.hideOriginal ~= nil then SyncHideOriginal(selectedID, d.hideOriginal) end
                    WM:TriggerUpdate(); 
                    if v == "UI_REFRESH" then WF.UI:RefreshCurrentPanel() end 
                end)
                
                local delBtn = scrollChild.WM_DelBtn or WF.UI.Factory:CreateFlatButton(scrollChild, L["Delete This Config"] or "彻底删除此配置", function() 
                    dbStore[selectedID] = nil
                    if WM.CurrentTab == "skill" then WM.selectedSkillID = nil else WM.selectedBuffID = nil end
                    WF.UI:RefreshCurrentPanel(); WM:TriggerUpdate() 
                end)
                scrollChild.WM_DelBtn = delBtn
                delBtn:ClearAllPoints(); delBtn:SetPoint("TOPLEFT", 15, y - 10); delBtn:Show(); y = y - 50
            end
        else
            if scrollChild.WM_BtnEditHeader then scrollChild.WM_BtnEditHeader:Hide() end
        end

        -- ================== 分类四：自由排列组 ==================
        local tFree = L["Free Layout"] or "自由排列组 (吸附平分宽度)"
        local btnFree = scrollChild.WM_BtnFreeHeader
        if not btnFree then
            btnFree = WF.UI.Factory:CreateFlatButton(scrollChild, tFree, function() WM.ExpandState.free = not WM.ExpandState.free; WF.UI:RefreshCurrentPanel() end)
            scrollChild.WM_BtnFreeHeader = btnFree
        end
        ForceSetButtonText(btnFree, tFree)
        btnFree:ClearAllPoints()
        btnFree:SetPoint("TOPLEFT", 15, y); btnFree:SetWidth(ColW * 1.5); btnFree:Show()
        y = y - 35

        if WM.ExpandState.free then
            local freeOpts = {
                { type = "toggle", key = "enable", db = db.freeLayout, text = L["Enable Free Layout"] or "启用该组" },
                { type = "dropdown", key = "layoutMode", db = db.freeLayout, text = L["Layout Mode"] or "排版模式", options = { 
                    {text=L["Dynamic Split (Auto-fill)"] or "动态平分宽度 (随激活数量自适应)", value="SPLIT"}, 
                    {text=L["Pack Center (Keep original width)"] or "固定宽度居中", value="PACK"} 
                } },
                { type = "slider", key = "spacing", db = db.freeLayout, text = L["Free Layout Spacing"] or "组内间距", min=0, max=50, step=1 },
                { type = "slider", key = "yOffset", db = db.freeLayout, text = L["Free Layout Y Offset"] or "整体 Y 轴偏移", min=-200, max=200, step=1 },
            }
            y = WF.UI:RenderOptionsGroup(scrollChild, 15, y, ColW * 1.5, freeOpts, function() WM:TriggerUpdate() end)
            
            local freeDesc = scrollChild.WM_FreeDesc or scrollChild:CreateFontString(nil, "OVERLAY")
            scrollChild.WM_FreeDesc = freeDesc; freeDesc:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); 
            freeDesc:ClearAllPoints(); freeDesc:SetPoint("TOPLEFT", 15, y)
            freeDesc:SetText(L["Free Layout Skills Desc"] or "|cff00ffcc[技能]|r 点击加入/移出自由排版组 (绿框为已加入):")
            freeDesc:Show()
            y = y - 25
            y = RenderIconGrid(scrollChild, "WM_FreeGridPool_S", y, ColW, WM.TrackedSkills, db.skills, nil, true)
            
            local freeDesc2 = scrollChild.WM_FreeDesc2 or scrollChild:CreateFontString(nil, "OVERLAY")
            scrollChild.WM_FreeDesc2 = freeDesc2; freeDesc2:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); 
            freeDesc2:ClearAllPoints(); freeDesc2:SetPoint("TOPLEFT", 15, y)
            freeDesc2:SetText(L["Free Layout Buffs Desc"] or "|cff00ffcc[增益]|r 点击加入/移出自由排版组 (绿框为已加入):")
            freeDesc2:Show()
            y = y - 25
            y = RenderIconGrid(scrollChild, "WM_FreeGridPool_B", y, ColW, WM.TrackedBuffs, db.buffs, nil, true)
            y = y - 10
            
            local freeDescHelp = scrollChild.WM_FreeDescHelp or scrollChild:CreateFontString(nil, "OVERLAY")
            scrollChild.WM_FreeDescHelp = freeDescHelp; freeDescHelp:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); 
            freeDescHelp:ClearAllPoints(); freeDescHelp:SetPoint("TOPLEFT", 15, y)
            freeDescHelp:SetWidth(ColW * 1.5 - 30); freeDescHelp:SetJustifyH("LEFT")
            freeDescHelp:SetText(
                (L["Layout Mode Help Title"] or "|cff00ccff[排版模式说明]|r") .. "\n" .. 
                (L["SPLIT Help"] or "|cffffaa00动态平分宽度|r：组内激活的监控条会自动平分资源条总宽。触发1个则100%宽，触发2个则各50%宽。") .. "\n" ..
                (L["PACK Help"] or "|cffffaa00固定宽度居中|r：监控条保持自己独立的宽度设置，并整体在资源条上方居中紧凑排列。")
            )
            freeDescHelp:Show()
            y = y - 70
        end

        return y
    end)
end