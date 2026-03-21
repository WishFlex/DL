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

local function IsSecret(v) return type(v) == "number" and issecretvalue and issecretvalue(v) end
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
WM.SpellToCD = {}
WM.ActiveBuffFrames = {}
WM.ActiveSkillFrames = {}

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
    WM.HasScanned = true
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
end

local defaults = {
    skills = {}, buffs = {},
    freeLayout = { spacing = 15, yOffset = 0, height = 0 },
    globalLayout = { growth = "DOWN", spacing = 18 },
    sortOrder = {}
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

local function GetAlignTargetAndWidth()
    local targetFrame, targetWidth = nil, nil
    if WF.ClassResourceAPI and WF.db.classResource and WF.db.classResource.enable then
        local cr = WF.ClassResourceAPI
        local sortOrder = WF.db.classResource.sortOrder or {"mana", "power", "class", "monitor"}
        for i = #sortOrder, 1, -1 do
            local key = sortOrder[i]
            if key == "mana" and cr.showMana and cr.manaBar and not cr.manaBar.isForceHidden then targetFrame = cr.manaBar
            elseif key == "power" and cr.showPower and cr.powerBar and not cr.powerBar.isForceHidden then targetFrame = cr.powerBar
            elseif key == "class" and cr.showClass and cr.classBar and not cr.classBar.isForceHidden then targetFrame = cr.classBar
            end
        end
    end
    if not targetFrame then if _G.EssentialCooldownViewer then targetFrame = _G.EssentialCooldownViewer end end
    if targetFrame then
        targetWidth = targetFrame:GetWidth()
        if not targetWidth or targetWidth == 0 then
            if targetFrame == _G.EssentialCooldownViewer then
                local c = WF.db.cooldownCustom and WF.db.cooldownCustom.Essential or {}
                local maxPerRow = tonumber(c.maxPerRow) or 7; local w = tonumber(c.row1Width) or 45; local gap = tonumber(c.iconGap) or 2
                targetWidth = (maxPerRow * w) + ((maxPerRow - 1) * gap)
            elseif WF.ClassResourceAPI then targetWidth = WF.ClassResourceAPI:GetActiveWidth() end
        end
    end
    return targetFrame, targetWidth
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

function WM:UpdateDividers(f, numMax, width)
    f.dividerFrame = f.dividerFrame or CreateFrame("Frame", nil, f)
    f.dividerFrame:SetAllPoints(); f.dividerFrame:SetFrameLevel(f:GetFrameLevel() + 15)
    f.dividers = f.dividers or {}
    local pixelSize = GetOnePixelSize(); numMax = tonumber(numMax) or 1
    if numMax <= 1 then for _, d in ipairs(f.dividers) do d:Hide() end; return end 
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
        
        f.iconFrame = CreateFrame("Frame", nil, f); f.iconFrame:SetFrameLevel(f:GetFrameLevel() + 1)
        f.icon = f.iconFrame:CreateTexture(nil, "ARTWORK")
        f.icon:SetAllPoints(); f.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        
        f.chargeBar = CreateFrame("StatusBar", nil, f); f.chargeBar:SetFrameLevel(f:GetFrameLevel() + 1); f.chargeBar:SetAllPoints()
        f.refreshCharge = CreateFrame("StatusBar", nil, f); f.refreshCharge:SetFrameLevel(f:GetFrameLevel() + 1)
        
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
        f.iconBorder = AddBoxBorder(f.iconFrame); f.sbBorder = AddBoxBorder(f)
        
        f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
        f.cd:SetDrawSwipe(false); f.cd:SetDrawEdge(false); f.cd:SetDrawBling(false)
        f.cd.noCooldownOverride = true; f.cd.noOCC = true; f.cd.skipElvUICooldown = true
        f.cd:SetHideCountdownNumbers(false); f.cd:SetFrameLevel(f:GetFrameLevel() + 20)
        
        local textFrame = CreateFrame("Frame", nil, f)
        textFrame:SetAllPoints(); textFrame:SetFrameLevel(f:GetFrameLevel() + 50)
        f.stackText = textFrame:CreateFontString(nil, "OVERLAY")
        f.nameText = textFrame:CreateFontString(nil, "OVERLAY") 
        
        self.FramePool[index] = f
    end
    return self.FramePool[index]
end

local function SetTextAnchor(fontString, anchorPos, parent)
    if not fontString then return end
    fontString:ClearAllPoints()
    if anchorPos == "LEFT" then fontString:SetPoint("LEFT", parent, "LEFT", 4, 0); fontString:SetJustifyH("LEFT")
    elseif anchorPos == "RIGHT" then fontString:SetPoint("RIGHT", parent, "RIGHT", -4, 0); fontString:SetJustifyH("RIGHT")
    elseif anchorPos == "CENTER" then fontString:SetPoint("CENTER", parent, "CENTER", 0, 0); fontString:SetJustifyH("CENTER")
    elseif anchorPos == "TOP" then fontString:SetPoint("BOTTOM", parent, "TOP", 0, 4); fontString:SetJustifyH("CENTER")
    elseif anchorPos == "BOTTOM" then fontString:SetPoint("TOP", parent, "BOTTOM", 0, -4); fontString:SetJustifyH("CENTER") end
end

function WM:ApplyFrameStyle(f, db, cfg, spellID)
    local gTexName, gFontPath, gFontSize = GetGlobalVisuals()
    local tex = LSM:Fetch("statusbar", gTexName) or "Interface\\Buttons\\WHITE8x8"
    local crDB = WF.db.classResource or {}
    
    local alignTarget, alignWidth = nil, nil
    if cfg.alignWithResource then alignTarget, alignWidth = GetAlignTargetAndWidth() end

    local fWidth = (cfg.width and cfg.width > 0) and cfg.width or (crDB.width or 250)
    if cfg.alignWithResource and alignWidth then fWidth = alignWidth
    elseif (not cfg.width or cfg.width == 0) and crDB.attachToResource and WF.ClassResourceAPI and WF.ClassResourceAPI.baseAnchor then fWidth = WF.ClassResourceAPI.baseAnchor:GetWidth() end
    
    local fHeight = (cfg.height and cfg.height > 0) and cfg.height or (crDB.height or 14)
    if cfg.alignWithResource and alignTarget then if not (cfg.height and cfg.height > 0) then fHeight = alignTarget:GetHeight(); if not fHeight or fHeight == 0 then fHeight = 14 end end end
    
    f.bg:SetTexture(tex); local c = cfg.color or {r=0, g=0.8, b=1, a=1}; f.bg:SetVertexColor(0.15, 0.15, 0.15, 0.9)
    local reverse = cfg.reverseFill and true or false
    f.chargeBar:SetReverseFill(reverse); f.refreshCharge:SetReverseFill(reverse)
    f.chargeBar:SetStatusBarTexture(tex); f.chargeBar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
    f.refreshCharge:SetStatusBarTexture(tex); f.refreshCharge:SetStatusBarColor(c.r, c.g, c.b, c.a or 0.8)

    local font = LSM:Fetch("font", gFontPath) or STANDARD_TEXT_FONT
    local finalFontSize = (cfg.fontSize and cfg.fontSize > 0) and cfg.fontSize or gFontSize
    f.stackText:SetFont(font, finalFontSize + 2, "OUTLINE"); f.stackText:SetTextColor(1, 1, 1, 1)

    if not f.timerText then
        if f.cd.timer and f.cd.timer.text then f.timerText = f.cd.timer.text
        else for _, region in pairs({f.cd:GetRegions()}) do if region:IsObjectType("FontString") then f.timerText = region; break end end end
    end
    if f.timerText then
        if f.timerText.FontTemplate then f.timerText:FontTemplate(font, finalFontSize, "OUTLINE") else f.timerText:SetFont(font, finalFontSize, "OUTLINE") end
        f.timerText:SetTextColor(1, 1, 1, 1)
    end

    local spellInfo = nil; pcall(function() spellInfo = C_Spell.GetSpellInfo(spellID) end)
    if spellInfo then f.icon:SetTexture(spellInfo.iconID) end

    -- 彻底隐藏每个监控条自己的技能名字
    f.nameText:Hide()

    local snapW = PixelSnap(fWidth); local snapH = PixelSnap(fHeight)
    f.calcWidth = snapW; f.calcHeight = snapH
    f:SetSize(snapW, snapH)
    
    local tAnchor = cfg.timerAnchor or "RIGHT"; local sAnchor = cfg.stackAnchor or "LEFT"
    local showStack = (cfg.showStackText == true); local showTimer = (cfg.showTimerText ~= false)

    if showTimer then f.cd:SetHideCountdownNumbers(false); if f.timerText then f.timerText:Show() end
    else f.cd:SetHideCountdownNumbers(true); if f.timerText then f.timerText:Hide() end end

    if cfg.useStatusBar then
        f.iconFrame:Hide(); f.cd:SetDrawSwipe(false); f.cd:Show()
        f.bg:Show(); f.sbBorder:Show()
        SetTextAnchor(f.stackText, sAnchor, f)
        if not cfg.dynamicTimer and f.timerText then SetTextAnchor(f.timerText, tAnchor, f) end
    else
        f.iconFrame:ClearAllPoints(); f.iconFrame:SetSize(snapH, snapH)
        f.iconFrame:SetPoint("CENTER", f, "CENTER", 0, 0); f.iconFrame:Show()
        f.cd:ClearAllPoints(); f.cd:SetAllPoints(f.iconFrame)
        f.cd:SetDrawSwipe(true); f.cd:Show()
        f.bg:Hide(); f.sbBorder:Hide(); f.chargeBar:Hide(); f.refreshCharge:Hide()
        SetTextAnchor(f.stackText, "BOTTOM", f.iconFrame)
        if f.timerText then SetTextAnchor(f.timerText, "CENTER", f.iconFrame) end
    end
    if not showStack then f.stackText:Hide() end
end

function WM:Render()
    if not self.baseAnchor then return end
    local crDB = WF.db.classResource
    if crDB and crDB.enable == false then for i = 1, #self.FramePool do self.FramePool[i]:Hide() end; return end
    local db = GetDB(); wipe(self.ActiveFrames)
    local activeCount = 0; WM.spellMaxChargeCache = WM.spellMaxChargeCache or {}
    local currentSpecID = GetCurrentSpecID()
    
    local function ProcessItem(spellIDStr, cfg, isBuff)
        if not cfg.enable then return end
        if not cfg.allSpecs then if not cfg.specID or cfg.specID == 0 then cfg.specID = currentSpecID end; if cfg.specID ~= currentSpecID then return end end
        local spellID = tonumber(spellIDStr); local isActive, rawCount, maxVal, durObjC = false, 0, 1, nil
        
        if isBuff then
            -- 强制锁定监控目标为自身
            local unit = "player"; local cdID = WM.SpellToCD[spellID]; local instID = nil
            for i = 1, #WM.ActiveBuffFrames do
                local frame = WM.ActiveBuffFrames[i]
                if frame.cooldownID == cdID or (frame.cooldownInfo and frame.cooldownInfo.cooldownID == cdID) then instID = frame.auraInstanceID; break end
            end
            if instID and IsSafeValue(instID) then pcall(function() local data = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, instID); if data then isActive = true; rawCount = data.applications or 0; durObjC = C_UnitAuras.GetAuraDuration(unit, instID) end end) end
            if not isActive then pcall(function() local data = C_UnitAuras.GetPlayerAuraBySpellID(spellID); if data then isActive = true; rawCount = data.applications or 0; durObjC = data end end) end
            maxVal = (cfg.mode == "stack") and (tonumber(cfg.maxStacks) or 5) or 1
        else
            if cfg.trackType == "cooldown" then pcall(function() local cInfo = C_Spell.GetSpellCooldown(spellID); if cInfo then local dur = cInfo.duration; if IsSecret(dur) or (tonumber(dur) and tonumber(dur) > 1.5) then isActive = true; durObjC = C_Spell.GetSpellCooldownDuration(spellID) end end end)
            elseif cfg.trackType == "charge" then pcall(function() local chInfo = C_Spell.GetSpellCharges(spellID); if chInfo then if type(chInfo.maxCharges) == "number" and not IsSecret(chInfo.maxCharges) then WM.spellMaxChargeCache[spellID] = chInfo.maxCharges end; maxVal = WM.spellMaxChargeCache[spellID] or chInfo.maxCharges or 1; rawCount = chInfo.currentCharges or 0; pcall(function() durObjC = C_Spell.GetSpellChargeDuration(spellID) end); if IsSecret(rawCount) or (tonumber(rawCount) or 0) > 0 or durObjC then isActive = true end end end) end
        end
        
        if isActive or cfg.alwaysShow then
            activeCount = activeCount + 1; local f = self:GetFrame(activeCount); f.cfg = cfg; f.spellID = spellID 
            self:ApplyFrameStyle(f, db, cfg, spellID)
            if type(maxVal) == "number" and not IsSecret(maxVal) then f.cachedMaxVal = maxVal end
            local safeMax = f.cachedMaxVal or 1; if safeMax < 1 then safeMax = 1 end; f.maxVal = safeMax
            
            local safeCount = 0; if type(rawCount) == "number" and not IsSecret(rawCount) then safeCount = rawCount else local exact = 0; local cbVal = f.chargeBar:GetValue(); if cbVal and not IsSecret(cbVal) and cbVal > 0 then exact = math.floor(cbVal + 0.5) end; safeCount = exact end
            
            pcall(function() if cfg.showStackText == true then if IsSecret(rawCount) then f.stackText:SetFormattedText("%d", rawCount); f.stackText:Show() else local numC = tonumber(rawCount) or 0; if not IsSecret(numC) and numC > 0 then f.stackText:SetText(numC); f.stackText:Show() else f.stackText:Hide() end end else f.stackText:Hide() end end)
            
            if isActive then
                if cfg.useStatusBar then
                    if isBuff and cfg.mode == "stack" then
                        f.chargeBar:Show(); f.refreshCharge:Hide()
                        pcall(function() if f.chargeBar.ClearTimerDuration then f.chargeBar:ClearTimerDuration() end end)
                        f.chargeBar:SetMinMaxValues(0, safeMax); pcall(function() f.chargeBar:SetValue(rawCount) end); self:UpdateDividers(f, safeMax, f.calcWidth)
                        
                        if cfg.dynamicTimer and safeMax > 1 then
                            local cellWidth = f.calcWidth / safeMax; local rc = 0; if not IsSecret(rawCount) then rc = tonumber(rawCount) or 0 end
                            local currentCell = 0; if rc > 0 then currentCell = rc - 1 end; if currentCell >= safeMax then currentCell = safeMax - 1 end
                            f.cd:ClearAllPoints(); f.cd:SetSize(cellWidth, f.calcHeight)
                            if cfg.reverseFill then f.cd:SetPoint("RIGHT", f.chargeBar, "RIGHT", -(currentCell * cellWidth), 0) else f.cd:SetPoint("LEFT", f.chargeBar, "LEFT", (currentCell * cellWidth), 0) end
                            if f.timerText then f.timerText:ClearAllPoints(); f.timerText:SetPoint("CENTER", f.cd, "CENTER", 0, 0); f.timerText:SetJustifyH("CENTER") end
                        else f.cd:ClearAllPoints(); f.cd:SetAllPoints(f.chargeBar) end
                    elseif cfg.trackType == "charge" then
                        f.chargeBar:Show()
                        pcall(function() if f.chargeBar.ClearTimerDuration then f.chargeBar:ClearTimerDuration() end end)
                        f.chargeBar:SetMinMaxValues(0, safeMax); pcall(function() f.chargeBar:SetValue(rawCount) end) 

                        local needsRecharge = false
                        if IsSecret(rawCount) then needsRecharge = true elseif type(rawCount) == "number" and rawCount < safeMax then needsRecharge = true end
                        if needsRecharge and durObjC then
                            f.refreshCharge:SetSize(f.calcWidth / safeMax, f.calcHeight); f.refreshCharge:ClearAllPoints()
                            if cfg.reverseFill then f.refreshCharge:SetPoint("RIGHT", f.chargeBar:GetStatusBarTexture(), "LEFT", 0, 0) else f.refreshCharge:SetPoint("LEFT", f.chargeBar:GetStatusBarTexture(), "RIGHT", 0, 0) end
                            pcall(function() f.refreshCharge:SetMinMaxValues(0, 1); local dir = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime or 0; f.refreshCharge:SetTimerDuration(durObjC, 0, dir) end)
                            f.refreshCharge:Show()
                            if cfg.dynamicTimer and safeMax > 1 then f.cd:ClearAllPoints(); f.cd:SetAllPoints(f.refreshCharge); if f.timerText then f.timerText:ClearAllPoints(); f.timerText:SetPoint("CENTER", f.cd, "CENTER", 0, 0); f.timerText:SetJustifyH("CENTER") end
                            else f.cd:ClearAllPoints(); f.cd:SetAllPoints(f.statusBar or f) end
                        else
                            f.refreshCharge:Hide(); pcall(function() if f.refreshCharge.ClearTimerDuration then f.refreshCharge:ClearTimerDuration() end end)
                            f.cd:ClearAllPoints(); f.cd:SetAllPoints(f.chargeBar)
                        end
                        self:UpdateDividers(f, safeMax, f.calcWidth)
                    else
                        f.chargeBar:Show(); f.refreshCharge:Hide(); self:UpdateDividers(f, 0, f.calcWidth)
                        pcall(function() if f.refreshCharge.ClearTimerDuration then f.refreshCharge:ClearTimerDuration() end end)
                        pcall(function() f.chargeBar:SetMinMaxValues(0, 1); if durObjC then f.chargeBar:SetTimerDuration(durObjC); if f.chargeBar.SetToTargetValue then f.chargeBar:SetToTargetValue() end else if f.chargeBar.ClearTimerDuration then f.chargeBar:ClearTimerDuration() end; f.chargeBar:SetValue(1) end end)
                        f.cd:ClearAllPoints(); f.cd:SetAllPoints(f.chargeBar)
                    end
                end
                
                pcall(function() if durObjC then if f.cd.SetCooldownFromDurationObject then pcall(function() f.cd:SetCooldownFromDurationObject(durObjC) end) else local st, dur; if type(durObjC.GetCooldownStartTime) == "function" then pcall(function() st = durObjC:GetCooldownStartTime(); dur = durObjC:GetCooldownDuration() end) else pcall(function() st = durObjC.startTime; dur = durObjC.duration end) end; if st and dur and (IsSecret(dur) or (tonumber(dur) and tonumber(dur) > 0)) then f.cd:SetCooldown(st, dur) else f.cd:Clear() end end else f.cd:Clear() end end)
                f:SetAlpha(1)
            else
                f.cd:Clear()
                if cfg.useStatusBar then
                    f.chargeBar:Show(); f.refreshCharge:Hide(); self:UpdateDividers(f, safeMax, f.calcWidth)
                    pcall(function() if f.chargeBar.ClearTimerDuration then f.chargeBar:ClearTimerDuration() end end)
                    pcall(function() if f.refreshCharge.ClearTimerDuration then f.refreshCharge:ClearTimerDuration() end end)
                    f.chargeBar:SetMinMaxValues(0, safeMax); f.chargeBar:SetValue(0); f.chargeBar:SetStatusBarColor(0.4, 0.4, 0.4, 0.8) 
                    f.cd:ClearAllPoints(); f.cd:SetAllPoints(f.chargeBar)
                end
                f:SetAlpha(0.6)
            end
            
            f:Show(); table.insert(self.ActiveFrames, f)
        end
    end

    for id, cfg in pairs(db.skills) do ProcessItem(id, cfg, false) end
    for id, cfg in pairs(db.buffs) do ProcessItem(id, cfg, true) end
    for i = activeCount + 1, #self.FramePool do self.FramePool[i]:Hide() end
    
    local layoutFrames = {}; local freeLayoutFrames = {}; local alignedFrames = {} 
    
    for _, f in ipairs(self.ActiveFrames) do
        f:ClearAllPoints()
        if f.cfg.inFreeLayout then table.insert(freeLayoutFrames, f)
        elseif f.cfg.alignWithResource then table.insert(alignedFrames, f)
        elseif f.cfg.independent then f:SetPoint("CENTER", UIParent, "CENTER", PixelSnap(f.cfg.indX or 0), PixelSnap(f.cfg.indY or 0)); self:UpdateDividers(f, f.maxVal or 1, f.calcWidth); if f.cfg.trackType == "charge" and f.refreshCharge then f.refreshCharge:SetSize(f.calcWidth / (f.maxVal or 1), f.calcHeight) end
        else table.insert(layoutFrames, f) end
    end

    db.sortOrder = db.sortOrder or {}
    local function GetSortIndex(spellID) local targetID = tostring(spellID); for i, id in ipairs(db.sortOrder) do if tostring(id) == targetID then return i end end; return 9999 end

    local function SortFrames(frames) table.sort(frames, function(a, b) local idxA = GetSortIndex(a.spellID); local idxB = GetSortIndex(b.spellID); if idxA == idxB then return (a.spellID or 0) < (b.spellID or 0) end; return idxA < idxB end) end
    SortFrames(alignedFrames); SortFrames(layoutFrames); SortFrames(freeLayoutFrames)

    local globalLayout = db.globalLayout or { growth = "DOWN", spacing = 18 }
    local globalGrowth = globalLayout.growth or "DOWN"
    local globalSpacing = PixelSnap(globalLayout.spacing or 18)

    local lastAlignedFrame = nil; local globalAlignTarget = GetAlignTargetAndWidth()
    local yOff = 2
    if WF.db.classResource and WF.db.classResource.specConfigs then local specCfg = WF.db.classResource.specConfigs[GetCurrentSpecID()]; if specCfg and specCfg.yOffset then yOff = specCfg.yOffset end end
    
    if globalGrowth == "UP" then
        for i = #alignedFrames, 1, -1 do
            local f = alignedFrames[i]; self:UpdateDividers(f, f.maxVal or 1, f.calcWidth); if f.cfg.trackType == "charge" and f.refreshCharge then f.refreshCharge:SetSize(f.calcWidth / (f.maxVal or 1), f.calcHeight) end
            if not lastAlignedFrame then if globalAlignTarget then f:SetPoint("BOTTOM", globalAlignTarget, "TOP", 0, yOff) else f:SetPoint("CENTER", self.baseAnchor, "CENTER", 0, 0) end else f:SetPoint("BOTTOM", lastAlignedFrame, "TOP", 0, globalSpacing) end
            lastAlignedFrame = f
        end
    else
        for i = 1, #alignedFrames do
            local f = alignedFrames[i]; self:UpdateDividers(f, f.maxVal or 1, f.calcWidth); if f.cfg.trackType == "charge" and f.refreshCharge then f.refreshCharge:SetSize(f.calcWidth / (f.maxVal or 1), f.calcHeight) end
            if not lastAlignedFrame then if globalAlignTarget then f:SetPoint("TOP", globalAlignTarget, "BOTTOM", 0, -yOff) else f:SetPoint("CENTER", self.baseAnchor, "CENTER", 0, 0) end else f:SetPoint("TOP", lastAlignedFrame, "BOTTOM", 0, -globalSpacing) end
            lastAlignedFrame = f
        end
    end

    local freeCount = #freeLayoutFrames
    if freeCount > 0 then
        local targetWidth = 250; local globalAlignTarget, globalAlignWidth = GetAlignTargetAndWidth()
        if globalAlignWidth and globalAlignWidth > 0 then targetWidth = globalAlignWidth 
        else local crDB = WF.db.classResource or {}; if crDB.attachToResource and WF.ClassResourceAPI and WF.ClassResourceAPI.baseAnchor then targetWidth = WF.ClassResourceAPI.baseAnchor:GetWidth() elseif crDB.width then targetWidth = crDB.width end end

        local spacing = PixelSnap(db.freeLayout.spacing or 1); local yOffFree = PixelSnap(db.freeLayout.yOffset or 0); local freeH = db.freeLayout.height 
        local eachWidth = (targetWidth - (freeCount - 1) * spacing) / freeCount; if eachWidth < 1 then eachWidth = 1 end
        local totalWidth = (eachWidth * freeCount) + (spacing * (freeCount - 1))
        local startX = -totalWidth / 2 + eachWidth / 2
        
        for _, f in ipairs(freeLayoutFrames) do
            local finalH = f.calcHeight; if freeH and freeH > 0 then finalH = PixelSnap(freeH) end
            f:SetSize(PixelSnap(eachWidth), finalH); f.calcWidth = PixelSnap(eachWidth); f.calcHeight = finalH
            self:UpdateDividers(f, f.maxVal or 1, f.calcWidth); if f.cfg.trackType == "charge" and f.refreshCharge then f.refreshCharge:SetSize(f.calcWidth / (f.maxVal or 1), f.calcHeight) end
            f:SetPoint("CENTER", self.baseAnchor, "CENTER", startX, yOffFree); startX = startX + eachWidth + spacing
        end
    end

    local count = #layoutFrames
    if count > 0 then
        local crDB = WF.db.classResource or {}; local growth = crDB.growth or "HCENTER"; local spacing = PixelSnap(crDB.spacing or 1)
        local targetList = {}
        if growth == "UP" or growth == "LEFT" then for i = #layoutFrames, 1, -1 do table.insert(targetList, layoutFrames[i]) end else for i = 1, #layoutFrames do table.insert(targetList, layoutFrames[i]) end end

        if growth == "HCENTER" then
            local totalWidth = 0; for _, f in ipairs(targetList) do self:UpdateDividers(f, f.maxVal or 1, f.calcWidth); if f.cfg.trackType == "charge" and f.refreshCharge then f.refreshCharge:SetSize(f.calcWidth / (f.maxVal or 1), f.calcHeight) end; totalWidth = totalWidth + f.calcWidth end
            totalWidth = totalWidth + (count - 1) * spacing; local startX = -totalWidth / 2
            for _, f in ipairs(targetList) do f:SetPoint("LEFT", self.baseAnchor, "CENTER", startX, 0); startX = startX + f.calcWidth + spacing end
        else
            for i, f in ipairs(targetList) do
                self:UpdateDividers(f, f.maxVal or 1, f.calcWidth); if f.cfg.trackType == "charge" and f.refreshCharge then f.refreshCharge:SetSize(f.calcWidth / (f.maxVal or 1), f.calcHeight) end
                if growth == "LEFT" then if i == 1 then f:SetPoint("RIGHT", self.baseAnchor, "RIGHT", 0, 0) else f:SetPoint("RIGHT", targetList[i-1], "LEFT", -spacing, 0) end
                elseif growth == "RIGHT" then if i == 1 then f:SetPoint("LEFT", self.baseAnchor, "LEFT", 0, 0) else f:SetPoint("LEFT", targetList[i-1], "RIGHT", spacing, 0) end
                elseif growth == "UP" then if i == 1 then f:SetPoint("BOTTOM", self.baseAnchor, "BOTTOM", 0, 0) else f:SetPoint("BOTTOM", targetList[i-1], "TOP", 0, spacing) end
                elseif growth == "DOWN" then if i == 1 then f:SetPoint("TOP", self.baseAnchor, "TOP", 0, 0) else f:SetPoint("TOP", targetList[i-1], "BOTTOM", 0, -spacing) end end
            end
        end
    end
end

function WM:TriggerUpdate()
    if self.updatePending then return end
    self.updatePending = true
    C_Timer.After(0.05, function() self.updatePending = false; WM:ScanViewers(false); self:Render() end)
end

local function InitWishMonitor()
    GetDB()
    local anchor = CreateFrame("Frame", "WishFlex_MonitorAnchor", UIParent)
    anchor:SetSize(250, 14); WM.baseAnchor = anchor
    if WF.CreateMover then WF:CreateMover(anchor, "WishFlex_MonitorAnchorMover", {"CENTER", UIParent, "CENTER", 0, -50}, 250, 14, "WishFlex: " .. (L["Custom Monitor"] or "自定义监控")) end
    
    WM:RegisterEvent("PLAYER_ENTERING_WORLD", function() C_Timer.After(0.5, function() WM:TriggerUpdate() end) end)
    WM:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function()
        C_Timer.After(0.5, function()
            local currentSpec = GetCurrentSpecID()
            local function validate(selID, dbStore) if selID and dbStore[selID] then local cfg = dbStore[selID]; if not cfg.allSpecs and cfg.specID and cfg.specID ~= 0 and cfg.specID ~= currentSpec then return nil end end return selID end
            WM.selectedSkillID = validate(WM.selectedSkillID, GetDB().skills); WM.selectedBuffID = validate(WM.selectedBuffID, GetDB().buffs)
            WM:TriggerUpdate() 
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

function WM:GetPreviewData()
    local db = GetDB()
    local currentSpec = GetCurrentSpecID()
    local list = {}
    
    local function AddItems(source, isBuff)
        for idStr, cfg in pairs(source) do
            if cfg.enable and (cfg.allSpecs or not cfg.specID or cfg.specID == 0 or cfg.specID == currentSpec) then
                local si = nil; pcall(function() si = C_Spell.GetSpellInfo(tonumber(idStr)) end)
                table.insert(list, {
                    idStr = idStr, spellID = tonumber(idStr), name = si and si.name or idStr,
                    height = cfg.height, color = cfg.color or {r=0,g=0.8,b=1,a=1},
                    showStack = cfg.showStackText, showTimer = cfg.showTimerText,
                    fontSize = cfg.fontSize, stackAnchor = cfg.stackAnchor, timerAnchor = cfg.timerAnchor
                })
            end
        end
    end
    AddItems(db.skills, false); AddItems(db.buffs, true)
    
    local function GetSortIndex(spellID)
        local targetID = tostring(spellID)
        for i, id in ipairs(db.sortOrder) do if tostring(id) == targetID then return i end end
        return 9999
    end
    table.sort(list, function(a, b)
        local idxA = GetSortIndex(a.spellID); local idxB = GetSortIndex(b.spellID)
        if idxA == idxB then return (a.spellID or 0) < (b.spellID or 0) end
        return idxA < idxB
    end)
    
    return list, db.globalLayout.growth or "DOWN", db.globalLayout.spacing or 18
end

WM.ExpandState = WM.ExpandState or { global = false, add = false, edit = false, free = false }
WM.CurrentTab = WM.CurrentTab or "skill"

local function RenderIconGrid(parentFrame, poolName, y, rightX, ColW, scanData, dbStore, selectedID, isFreeMode, callback)
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

    local poolOwner = WF.ScrollChild
    if not poolOwner[poolName] then poolOwner[poolName] = {} end
    for _, btn in ipairs(poolOwner[poolName]) do btn:Hide() end

    local row, col = 0, 0
    for i, item in ipairs(list) do
        local btn = poolOwner[poolName][i]
        if not btn then
            btn = CreateFrame("Button", nil, parentFrame, "BackdropTemplate")
            btn:SetSize(ICON_SIZE, ICON_SIZE); btn:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
            local tex = btn:CreateTexture(nil, "BACKGROUND")
            tex:SetPoint("TOPLEFT", 1, -1); tex:SetPoint("BOTTOMRIGHT", -1, 1)
            tex:SetTexCoord(0.1, 0.9, 0.1, 0.9); btn.tex = tex; btn:RegisterForClicks("AnyUp")
            poolOwner[poolName][i] = btn
        end

        btn:SetParent(parentFrame)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", rightX + col * (ICON_SIZE + PADDING), y - row * (ICON_SIZE + PADDING))
        btn.tex:SetTexture(item.icon)

        if isFreeMode then if dbStore[item.idStr] and dbStore[item.idStr].inFreeLayout then btn:SetBackdropBorderColor(0.2, 0.85, 0.3, 1) else btn:SetBackdropBorderColor(0, 0, 0, 1) end
        else
            if item.idStr == selectedID then btn:SetBackdropBorderColor(0.2, 0.6, 1, 1)
            elseif dbStore[item.idStr] and dbStore[item.idStr].enable then btn:SetBackdropBorderColor(0.2, 0.85, 0.3, 1)
            else btn:SetBackdropBorderColor(0, 0, 0, 1) end
        end

        btn:SetScript("OnClick", function(self, button) 
            if isFreeMode then
                if dbStore[item.idStr] then 
                    dbStore[item.idStr].inFreeLayout = not dbStore[item.idStr].inFreeLayout
                    callback("WM_UPDATE")
                    C_Timer.After(0.05, function() callback("UI_REFRESH") end)
                end
            else
                local idStr = item.idStr
                if not dbStore[idStr] then
                    if WM.CurrentTab == "skill" then dbStore[idStr] = { enable = false, specID = GetCurrentSpecID(), allSpecs = false, trackType = "cooldown", alwaysShow = true, useStatusBar = true, color = {r=1,g=0.5,b=0,a=1}, showStackText = false, showTimerText = true, hideOriginal = false, alignWithResource = false }
                    else dbStore[idStr] = { enable = false, specID = GetCurrentSpecID(), allSpecs = false, mode = "time", maxStacks = 5, alwaysShow = true, useStatusBar = true, color = {r=0,g=0.8,b=1,a=1}, showStackText = false, showTimerText = true, hideOriginal = false, alignWithResource = false } end
                end
                if button == "RightButton" then 
                    dbStore[idStr].enable = not dbStore[idStr].enable
                else
                    if WM.CurrentTab == "skill" then WM.selectedSkillID = idStr else WM.selectedBuffID = idStr end
                    WM.ExpandState.edit = true
                end
                callback("WM_UPDATE")
                C_Timer.After(0.05, function() callback("UI_REFRESH") end) 
            end
        end)
        
        btn:SetScript("OnEnter", function() GameTooltip:SetOwner(btn, "ANCHOR_RIGHT"); GameTooltip:SetSpellByID(tonumber(item.idStr)); GameTooltip:AddLine(" ")
            if isFreeMode then GameTooltip:AddLine(L["Left Click: Add/Remove Free Layout"] or "|cff00ffcc[左键]|r 加入/移出自由排列组", 1,1,1)
            else GameTooltip:AddLine(L["Left Click: Edit"] or "|cff00ffcc[左键]|r 编辑监控参数", 1,1,1); GameTooltip:AddLine(L["Right Click: Toggle"] or "|cffffaa00[右键]|r 快速启用/禁用", 1,1,1) end
            GameTooltip:Show() 
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        btn:Show()

        col = col + 1; if col >= MAX_COLS then col = 0; row = row + 1 end
    end

    if #list == 0 then return y end
    local totalRows = col == 0 and row or row + 1
    return y - totalRows * (ICON_SIZE + PADDING) - 15
end

local function RenderSortList(parentFrame, poolName, startY, rightX, ColW, sortList, callback)
    local ITEM_HEIGHT = 28; local PADDING = 2; local TOTAL_H = ITEM_HEIGHT + PADDING; local width = ColW * 1.5
    local poolOwner = WF.ScrollChild; if not poolOwner[poolName] then poolOwner[poolName] = {} end
    local pool = poolOwner[poolName]
    for _, row in ipairs(pool) do row:Hide(); row:SetScript("OnUpdate", nil) end

    for i, idStr in ipairs(sortList) do
        local row = pool[i]
        if not row then
            row = CreateFrame("Button", nil, parentFrame, "BackdropTemplate")
            row:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
            row:SetBackdropColor(0.1, 0.1, 0.1, 0.8); row:SetBackdropBorderColor(0, 0, 0, 1)

            local icon = row:CreateTexture(nil, "ARTWORK"); icon:SetSize(20, 20); icon:SetPoint("LEFT", 4, 0); icon:SetTexCoord(0.1, 0.9, 0.1, 0.9); row.icon = icon
            local name = row:CreateFontString(nil, "OVERLAY"); name:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); name:SetPoint("LEFT", icon, "RIGHT", 8, 0); name:SetJustifyH("LEFT"); row.name = name
            local dragHandle = row:CreateFontString(nil, "OVERLAY"); dragHandle:SetFont(STANDARD_TEXT_FONT, 18, "OUTLINE"); dragHandle:SetText("≡"); dragHandle:SetPoint("RIGHT", row, "RIGHT", -10, 0); dragHandle:SetTextColor(0.6, 0.6, 0.6); row.dragHandle = dragHandle
            pool[i] = row
        end

        row:SetParent(parentFrame); row:SetSize(width, ITEM_HEIGHT); row:ClearAllPoints()
        local defY = startY - (i - 1) * TOTAL_H; row:SetPoint("TOPLEFT", rightX, defY)

        local spellInfo = nil; pcall(function() spellInfo = C_Spell.GetSpellInfo(tonumber(idStr)) end)
        row.icon:SetTexture(spellInfo and spellInfo.iconID or 134400); row.name:SetText(spellInfo and spellInfo.name or tostring(idStr))
        row.originalIndex = i; row.targetIndex = i; row.idStr = idStr

        row:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 0.8, 0, 1); self.dragHandle:SetTextColor(1, 1, 1); GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); local si = nil; pcall(function() si = C_Spell.GetSpellInfo(tonumber(self.idStr)) end); GameTooltip:AddLine((L["Click to configure: "] or "点击进入详细设置: ") .. (si and si.name or tostring(self.idStr)), 1, 1, 1); GameTooltip:AddLine(L["Drag to sort"] or "按住可拖拽进行排序", 0.2, 0.8, 1); GameTooltip:Show() end)
        row:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0, 0, 0, 1); if not self.isDragging then self.dragHandle:SetTextColor(0.6, 0.6, 0.6) end; GameTooltip:Hide() end)

        row:SetScript("OnMouseDown", function(self)
            self.isDragging = true; self.hasMoved = false; self:SetFrameStrata("DIALOG"); self:SetBackdropBorderColor(0.2, 0.8, 1, 1); self.dragHandle:SetTextColor(0.2, 0.8, 1)
            local _, cy = GetCursorPosition(); self.dragOffset = select(5, self:GetPoint()) - (cy / self:GetEffectiveScale())
        end)

        row:SetScript("OnMouseUp", function(self)
            if not self.isDragging then return end
            self.isDragging = false; self:SetFrameStrata("MEDIUM"); self:SetBackdropBorderColor(0, 0, 0, 1); self.dragHandle:SetTextColor(0.6, 0.6, 0.6)

            if not self.hasMoved then
                local dbStore = GetDB()
                if dbStore.skills[self.idStr] then WM.CurrentTab = "skill"; WM.selectedSkillID = self.idStr
                elseif dbStore.buffs[self.idStr] then WM.CurrentTab = "buff"; WM.selectedBuffID = self.idStr end
                WM.ExpandState.edit = true; 
                C_Timer.After(0.05, function() callback("UI_REFRESH") end)
                self:ClearAllPoints(); self:SetPoint("TOPLEFT", rightX, startY - (self.originalIndex - 1) * TOTAL_H)
                return
            end

            if self.targetIndex ~= self.originalIndex then
                local removed = table.remove(sortList, self.originalIndex)
                table.insert(sortList, self.targetIndex, removed)
                callback("WM_UPDATE")
            else self:ClearAllPoints(); self:SetPoint("TOPLEFT", rightX, startY - (self.originalIndex - 1) * TOTAL_H) end
        end)

        row:SetScript("OnUpdate", function(self)
            if not self.isDragging then return end
            local _, cy = GetCursorPosition(); local newY = (cy / self:GetEffectiveScale()) + self.dragOffset
            if math.abs(newY - (startY - (self.originalIndex - 1) * TOTAL_H)) > 3 then self.hasMoved = true end
            local maxTop = startY; local maxBot = startY - (#sortList - 1) * TOTAL_H
            if newY > maxTop then newY = maxTop end; if newY < maxBot then newY = maxBot end

            self:ClearAllPoints(); self:SetPoint("TOPLEFT", rightX, newY)

            local calcIndex = math.floor((startY - newY + (ITEM_HEIGHT/2)) / TOTAL_H) + 1
            if calcIndex < 1 then calcIndex = 1 end; if calcIndex > #sortList then calcIndex = #sortList end

            if self.targetIndex ~= calcIndex then
                self.targetIndex = calcIndex
                for j, otherRow in ipairs(pool) do
                    if otherRow:IsShown() and otherRow ~= self then
                        local shiftIdx = otherRow.originalIndex
                        if otherRow.originalIndex > self.originalIndex and otherRow.originalIndex <= self.targetIndex then shiftIdx = otherRow.originalIndex - 1
                        elseif otherRow.originalIndex < self.originalIndex and otherRow.originalIndex >= self.targetIndex then shiftIdx = otherRow.originalIndex + 1 end
                        local targetY = startY - (shiftIdx - 1) * TOTAL_H
                        WF.UI:Animate(otherRow, "slide", 0.15, function(ease) local currY = select(5, otherRow:GetPoint()) or targetY; local nextY = currY + (targetY - currY) * ease; otherRow:ClearAllPoints(); otherRow:SetPoint("TOPLEFT", rightX, nextY) end)
                    end
                end
            end
        end)
        row:Show()
    end
    if #sortList == 0 then return startY end
    return startY - #sortList * TOTAL_H - 10
end

function WM:RenderOptions(scrollChild, rightX, rightY, rightColW, callback)
    local db = GetDB()
    local ColW = rightColW / 1.5
    local y = rightY
    
    local uiElements = { "WMT_Skill", "WMT_Buff", "WM_EditBox", "WM_AddBtn", "WM_ScanBtn", "WM_DelBtn" }
    for _, name in ipairs(uiElements) do if scrollChild[name] then scrollChild[name]:Hide() end end

    db.sortOrder = db.sortOrder or {}
    local currentSpec = GetCurrentSpecID()
    local function IsActiveForSpec(cfg)
        if not cfg.enable then return false end
        if cfg.allSpecs then return true end
        local sID = cfg.specID or 0; if sID == 0 then return true end
        return sID == currentSpec
    end

    local activeIDs = {}
    for id, cfg in pairs(db.skills) do if IsActiveForSpec(cfg) then activeIDs[id] = true end end
    for id, cfg in pairs(db.buffs) do if IsActiveForSpec(cfg) then activeIDs[id] = true end end

    local newSort = {}; local seenInSort = {}
    for _, id in ipairs(db.sortOrder) do if activeIDs[id] then table.insert(newSort, id); seenInSort[id] = true end end
    for id in pairs(activeIDs) do if not seenInSort[id] then table.insert(newSort, id) end end
    db.sortOrder = newSort

    -- ================== 分类一：全局排版与排序 ==================
    local btnGlobal, nextY
    btnGlobal, y = WF.UI.Factory:CreateGroupHeader(scrollChild, rightX, y, rightColW, L["Global Layout & Sorting"] or "全局排版与排序 (决定条的上下层级与方向)", WM.ExpandState.global, function() WM.ExpandState.global = not WM.ExpandState.global; C_Timer.After(0.05, function() callback("UI_REFRESH") end) end)

    if WM.ExpandState.global then
        local cy = 0
        local globalOpts = {
            { type = "dropdown", key = "growth", db = db.globalLayout, text = L["Aligned Growth Direction"] or "自动对齐组 增长方向", options = { {text=L["Grow Up"] or "向上堆叠 (UP)", value="UP"}, {text=L["Grow Down"] or "向下堆叠 (DOWN)", value="DOWN"} } },
            { type = "slider", key = "spacing", db = db.globalLayout, text = L["Aligned Spacing"] or "对齐组 垂直间距", min=0, max=50, step=1 },
        }
        cy = WF.UI:RenderOptionsGroup(scrollChild, rightX, y, rightColW, globalOpts, function() callback("WM_UPDATE") end)

        local sortDesc = scrollChild.WM_SortDesc or scrollChild:CreateFontString(nil, "OVERLAY")
        scrollChild.WM_SortDesc = sortDesc; sortDesc:SetParent(scrollChild)
        sortDesc:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); sortDesc:ClearAllPoints(); sortDesc:SetPoint("TOPLEFT", rightX, cy)
        sortDesc:SetText(L["Active Sort List"] or "|cffffaa00[当前专精激活列表]|r 按住可拖拽排序")
        sortDesc:Show(); cy = cy - 25
        y = RenderSortList(scrollChild, "WM_SortPool", cy, rightX, ColW, db.sortOrder, callback)
    else
        if scrollChild.WM_SortDesc then scrollChild.WM_SortDesc:Hide() end
        if scrollChild.WM_SortPool then for _, b in ipairs(scrollChild.WM_SortPool) do b:Hide() end end
    end

    -- ================== 分类二：添加与管理监控 ==================
    local btnAdd
    btnAdd, y = WF.UI.Factory:CreateGroupHeader(scrollChild, rightX, y, rightColW, L["Add Monitor"] or "添加与管理监控", WM.ExpandState.add, function() WM.ExpandState.add = not WM.ExpandState.add; C_Timer.After(0.05, function() callback("UI_REFRESH") end) end)

    if WM.ExpandState.add then
        local cy = y
        local tabWidth = (rightColW - 10) / 2
        
        local tabSkill = scrollChild.WMT_Skill or WF.UI.Factory:CreateFlatButton(scrollChild, L["Skill Cooldown Monitor"] or "■ 技能冷却", function() WM.CurrentTab = "skill"; C_Timer.After(0.05, function() callback("UI_REFRESH") end) end)
        scrollChild.WMT_Skill = tabSkill; tabSkill:SetParent(scrollChild); tabSkill:ClearAllPoints(); tabSkill:SetPoint("TOPLEFT", rightX, cy); tabSkill:SetWidth(tabWidth); tabSkill:Show()

        local tabBuff = scrollChild.WMT_Buff or WF.UI.Factory:CreateFlatButton(scrollChild, L["Aura Buff Monitor"] or "■ 光环增益", function() WM.CurrentTab = "buff"; C_Timer.After(0.05, function() callback("UI_REFRESH") end) end)
        scrollChild.WMT_Buff = tabBuff; tabBuff:SetParent(scrollChild); tabBuff:ClearAllPoints(); tabBuff:SetPoint("LEFT", tabSkill, "RIGHT", 10, 0); tabBuff:SetWidth(tabWidth); tabBuff:Show()
        
        if WM.CurrentTab == "skill" then tabSkill:SetBackdropBorderColor(0.2, 0.85, 0.3, 1); tabBuff:SetBackdropBorderColor(0, 0, 0, 1) else tabSkill:SetBackdropBorderColor(0, 0, 0, 1); tabBuff:SetBackdropBorderColor(0.2, 0.85, 0.3, 1) end
        cy = cy - 40
        
        if WM.CurrentTab == "skill" then cy = RenderIconGrid(scrollChild, "WM_GridPool", cy, rightX, ColW, WM.TrackedSkills, db.skills, WM.selectedSkillID, false, callback)
        else cy = RenderIconGrid(scrollChild, "WM_GridPool", cy, rightX, ColW, WM.TrackedBuffs, db.buffs, WM.selectedBuffID, false, callback) end
        cy = cy - 15
        
        local editBox = scrollChild.WM_EditBox
        if not editBox then
            editBox = CreateFrame("EditBox", nil, scrollChild, "BackdropTemplate"); editBox:SetSize(120, 24); editBox:SetAutoFocus(false)
            editBox:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); editBox:SetTextInsets(5, 5, 0, 0); editBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            editBox:SetBackdropColor(0.05, 0.05, 0.05, 1); editBox:SetBackdropBorderColor(0, 0, 0, 1)
            editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end); editBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
            scrollChild.WM_EditBox = editBox
        end
        editBox:SetParent(scrollChild)
        local totalInputWidth = 120 + 10 + 120 + 10 + 120
        local startX = rightX + (rightColW - totalInputWidth) / 2
        editBox:ClearAllPoints(); editBox:SetPoint("TOPLEFT", startX, cy); editBox:Show()
        
        local btnAddID = scrollChild.WM_AddBtn or WF.UI.Factory:CreateFlatButton(scrollChild, L["Manual Add ID"] or "手动添加ID", function() 
            local id = tonumber(editBox:GetText()); if id then
                local idStr = tostring(id); local dbStore = (WM.CurrentTab == "skill") and db.skills or db.buffs
                if not dbStore[idStr] then
                    if WM.CurrentTab == "skill" then dbStore[idStr] = { enable = true, specID = GetCurrentSpecID(), allSpecs = false, trackType = "cooldown", useStatusBar = true, alwaysShow = true, color = {r=1,g=0.5,b=0,a=1}, showStackText = false, showTimerText = true, hideOriginal = false, alignWithResource = false }
                    else dbStore[idStr] = { enable = true, specID = GetCurrentSpecID(), allSpecs = false, useStatusBar = true, mode = "time", maxStacks = 5, alwaysShow = true, color = {r=0,g=0.8,b=1,a=1}, showStackText = false, showTimerText = true, hideOriginal = false, alignWithResource = false } end
                end
                if WM.CurrentTab == "skill" then WM.selectedSkillID = idStr else WM.selectedBuffID = idStr end
                WM.ExpandState.edit = true; editBox:SetText("")
                callback("WM_UPDATE")
                C_Timer.After(0.05, function() callback("UI_REFRESH") end) 
            end
        end)
        scrollChild.WM_AddBtn = btnAddID; btnAddID:SetParent(scrollChild); btnAddID:ClearAllPoints(); btnAddID:SetPoint("LEFT", editBox, "RIGHT", 10, 0); btnAddID:SetWidth(120); btnAddID:Show()
        
        local scanBtn = scrollChild.WM_ScanBtn or WF.UI.Factory:CreateFlatButton(scrollChild, L["Rescan Cache"] or "重新扫描缓存", function() 
            WM:ScanViewers(true)
            callback("WM_UPDATE")
            C_Timer.After(0.05, function() callback("UI_REFRESH") end)
        end)
        scrollChild.WM_ScanBtn = scanBtn; scanBtn:SetParent(scrollChild); scanBtn:ClearAllPoints(); scanBtn:SetPoint("LEFT", btnAddID, "RIGHT", 10, 0); scanBtn:SetWidth(120); scanBtn:Show()
        y = cy - 40
    end

    -- ================== 分类三：当前监控设置 ==================
    local selectedID = (WM.CurrentTab == "skill") and WM.selectedSkillID or WM.selectedBuffID
    local dbStore = (WM.CurrentTab == "skill") and db.skills or db.buffs

    if selectedID and dbStore[selectedID] then
        local d = dbStore[selectedID]
        local name = "Unknown"; pcall(function() name = C_Spell.GetSpellName(tonumber(selectedID)) or "Unknown" end)
        
        local btnEdit; btnEdit, y = WF.UI.Factory:CreateGroupHeader(scrollChild, rightX, y, rightColW, (L["Monitor Settings"] or "当前监控设置") .. " : " .. name, WM.ExpandState.edit, function() WM.ExpandState.edit = not WM.ExpandState.edit; C_Timer.After(0.05, function() callback("UI_REFRESH") end) end)

        if WM.ExpandState.edit then
            local cy = y
            local anchorOptions = { {text=L["Right"] or "右侧", value="RIGHT"}, {text=L["Left"] or "左侧", value="LEFT"}, {text=L["Center"] or "居中", value="CENTER"}, {text=L["Top Outside"] or "顶部外侧", value="TOP"}, {text=L["Bottom Outside"] or "底部外侧", value="BOTTOM"} }
            
            -- [核心修改点] 删除了名字开关和目标下拉框，保证清爽
            local commonOpts = {
                { type = "toggle", key = "allSpecs", db = d, text = L["Share All Specs"] or "所有专精共享此监控" },
                { type = "toggle", key = "alwaysShow", db = d, text = L["Always Show Background"] or "常驻底框预览 (配置时打开)" },
                { type = "toggle", key = "hideOriginal", db = d, text = L["Hide Original Cooldown/Aura"] or "在原版冷却管理器中隐藏该图标" },
                { type = "toggle", key = "useStatusBar", db = d, text = L["Enable Smooth Status Bar Mode"] or "启用进度条模式" },
                { type = "color", key = "color", db = d, text = L["Custom Foreground Color"] or "专属前景色" },
                { type = "toggle", key = "reverseFill", db = d, text = L["Reverse Fill"] or "启用反向动画" },
                { type = "toggle", key = "alignWithResource", db = d, text = L["Align To Top Resource"] or "自动对齐资源条/冷却第一行" },
            }
            
            if not d.alignWithResource then
                table.insert(commonOpts, { type = "slider", key = "width", db = d, text = L["Independent Width"] or "独立宽度 (0=跟随全局)", min=0, max=600, step=1 })
                table.insert(commonOpts, { type = "toggle", key = "independent", db = d, text = L["Independent Positioning"] or "完全独立移动" })
                table.insert(commonOpts, { type = "slider", key = "indX", db = d, text = L["Independent X Offset"] or "独立 X 轴偏移", min=-1000, max=1000, step=1 })
                table.insert(commonOpts, { type = "slider", key = "indY", db = d, text = L["Independent Y Offset"] or "独立 Y 轴偏移", min=-1000, max=1000, step=1 })
            end
            
            table.insert(commonOpts, { type = "slider", key = "height", db = d, text = L["Independent Height"] or "独立高度 (0=跟随全局)", min=0, max=50, step=1 })
            table.insert(commonOpts, { type = "slider", key = "fontSize", db = d, text = L["Font Size"] or "独立字体大小 (0=跟随全局)", min=0, max=64, step=1 })
            table.insert(commonOpts, { type = "toggle", key = "showStackText", db = d, text = L["Enable Stack Text"] or "启用层数文本显示" })
            table.insert(commonOpts, { type = "dropdown", key = "stackAnchor", db = d, text = L["Stack Text Anchor"] or "独立层数文本位置", options = anchorOptions })
            table.insert(commonOpts, { type = "toggle", key = "showTimerText", db = d, text = L["Enable Timer Text"] or "启用倒计时文本显示" })
            table.insert(commonOpts, { type = "toggle", key = "dynamicTimer", db = d, text = L["Dynamic Timer Position"] or "动态时间文本 (自动跟随当前格子)" })
            table.insert(commonOpts, { type = "dropdown", key = "timerAnchor", db = d, text = L["Timer Text Anchor"] or "独立时间文本位置", options = anchorOptions })

            local opts = {}
            if WM.CurrentTab == "skill" then
                opts = { { type = "dropdown", key = "trackType", db = d, text = L["Monitor Type"] or "监控类型", options = { {text=L["Cooldown Monitor"] or "普通冷却", value="cooldown"}, {text=L["Charge Monitor & Auto-Slice"] or "充能与切分", value="charge"} } } }
                for _, opt in ipairs(commonOpts) do table.insert(opts, opt) end
            else
                opts = {
                    { type = "dropdown", key = "mode", db = d, text = L["Status Bar Mechanism"] or "机制", options = { {text=L["Smooth Time Reduction"] or "按时间平滑", value="time"}, {text=L["Grid Slice by Stacks"] or "按层数网格叠加", value="stack"} } },
                    { type = "slider", key = "maxStacks", db = d, text = L["Max Stacks Grid Slices"] or "层数格子上限", min=1, max=20, step=1 },
                }
                for _, opt in ipairs(commonOpts) do table.insert(opts, opt) end
            end

            cy = WF.UI:RenderOptionsGroup(scrollChild, rightX, cy, rightColW, opts, function(v) 
                if d.hideOriginal ~= nil then SyncHideOriginal(selectedID, d.hideOriginal) end
                callback("WM_UPDATE")
            end)
            
            local delBtn = scrollChild.WM_DelBtn or WF.UI.Factory:CreateFlatButton(scrollChild, L["Delete This Config"] or "彻底删除此配置", function() 
                dbStore[selectedID] = nil; if WM.CurrentTab == "skill" then WM.selectedSkillID = nil else WM.selectedBuffID = nil end
                callback("WM_UPDATE")
                C_Timer.After(0.05, function() callback("UI_REFRESH") end) 
            end)
            scrollChild.WM_DelBtn = delBtn; delBtn:SetParent(scrollChild); delBtn:ClearAllPoints(); delBtn:SetPoint("TOPLEFT", rightX, cy - 10); delBtn:Show()
            y = cy - 50
        else
            if scrollChild.WM_DelBtn then scrollChild.WM_DelBtn:Hide() end
        end
    else
        if scrollChild.WM_BtnEditHeader then scrollChild.WM_BtnEditHeader:Hide() end
        if scrollChild.WM_DelBtn then scrollChild.WM_DelBtn:Hide() end
    end

    -- ================== 分类四：自由排列组 ==================
    local btnFree; btnFree, y = WF.UI.Factory:CreateGroupHeader(scrollChild, rightX, y, rightColW, L["Free Layout"] or "自由排列组 (动态宽度平分)", WM.ExpandState.free, function() WM.ExpandState.free = not WM.ExpandState.free; C_Timer.After(0.05, function() callback("UI_REFRESH") end) end)

    if WM.ExpandState.free then
        local cy = y
        local freeOpts = {
            { type = "slider", key = "spacing", db = db.freeLayout, text = L["Free Layout Spacing"] or "组内间距", min=0, max=50, step=1 },
            { type = "slider", key = "yOffset", db = db.freeLayout, text = L["Free Layout Y Offset"] or "整体 Y 轴偏移", min=-200, max=200, step=1 },
            { type = "slider", key = "height", db = db.freeLayout, text = L["Free Layout Group Height"] or "整组统一高度 (0=跟随各自)", min=0, max=100, step=1 },
        }
        cy = WF.UI:RenderOptionsGroup(scrollChild, rightX, cy, rightColW, freeOpts, function() callback("WM_UPDATE") end)
        
        local freeDesc = scrollChild.WM_FreeDesc or scrollChild:CreateFontString(nil, "OVERLAY")
        scrollChild.WM_FreeDesc = freeDesc; freeDesc:SetParent(scrollChild); freeDesc:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        freeDesc:ClearAllPoints(); freeDesc:SetPoint("TOPLEFT", rightX, cy); freeDesc:SetText(L["Free Layout Skills Desc"] or "|cff00ffcc[技能]|r 点击加入/移出自由排版组 (绿框为已加入):"); freeDesc:Show(); cy = cy - 25
        cy = RenderIconGrid(scrollChild, "WM_FreeGridPool_S", cy, rightX, ColW, WM.TrackedSkills, db.skills, nil, true, callback)
        
        local freeDesc2 = scrollChild.WM_FreeDesc2 or scrollChild:CreateFontString(nil, "OVERLAY")
        scrollChild.WM_FreeDesc2 = freeDesc2; freeDesc2:SetParent(scrollChild); freeDesc2:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        freeDesc2:ClearAllPoints(); freeDesc2:SetPoint("TOPLEFT", rightX, cy); freeDesc2:SetText(L["Free Layout Buffs Desc"] or "|cff00ffcc[增益]|r 点击加入/移出自由排版组 (绿框为已加入):"); freeDesc2:Show(); cy = cy - 25
        cy = RenderIconGrid(scrollChild, "WM_FreeGridPool_B", cy, rightX, ColW, WM.TrackedBuffs, db.buffs, nil, true, callback)
        y = cy - 10
    else
        if scrollChild.WM_FreeDesc then scrollChild.WM_FreeDesc:Hide() end
        if scrollChild.WM_FreeDesc2 then scrollChild.WM_FreeDesc2:Hide() end
    end

    local helpText = scrollChild.WM_Help or scrollChild:CreateFontString(nil, "OVERLAY")
    scrollChild.WM_Help = helpText; helpText:SetParent(scrollChild); helpText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    helpText:SetPoint("TOPLEFT", rightX, y); helpText:SetWidth(rightColW); helpText:SetJustifyH("LEFT")
    helpText:SetText(L["Monitor Integration Help"] or "|cff00ccff[模块已深度整合]|r 全局材质、字体、宽度、以及屏幕上的排版层级，已完全交由 |cff00ff00[职业资源条 -> 全局设置]|r 统一控制。由于条上方需要显示技能名，强烈建议将这里的堆叠方向保持为向下 (DOWN) 并设置合理的间距。")
    helpText:Show(); y = y - 40

    return y
end