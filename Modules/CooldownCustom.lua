local AddonName, ns = ...
local WF = _G.WishFlex or ns.WF
local L = ns.L or {}
local LSM = LibStub("LibSharedMedia-3.0", true)
local LCG = LibStub("LibCustomGlow-1.0", true)
local CDMod = {}
CDMod.hiddenAuras = {}
local BaseSpellCache = {}

local DEFAULT_SWIPE_COLOR = {r = 0, g = 0, b = 0, a = 0.8}
local DEFAULT_ACTIVE_AURA_COLOR = {r = 1, g = 0.95, b = 0.57, a = 0.69}
local DEFAULT_CD_COLOR = {r = 1, g = 0.82, b = 0}
local DEFAULT_STACK_COLOR = {r = 1, g = 1, b = 1}

local DefaultConfig = {
    enable = true, countFont = "Expressway", countFontOutline = "OUTLINE", countFontColor = DEFAULT_STACK_COLOR,
    swipeColor = DEFAULT_SWIPE_COLOR, activeAuraColor = DEFAULT_ACTIVE_AURA_COLOR, reverseSwipe = true,
    Utility = { attachToPlayer = false, attachX = 0, attachY = 1, width = 45, height = 30, iconGap = 2, growth = "CENTER_HORIZONTAL", cdFontSize = 18, cdFontColor = DEFAULT_CD_COLOR, cdPosition = "CENTER", cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackPosition = "BOTTOMRIGHT", stackXOffset = 0, stackYOffset = 0 },
    BuffBar = { width = 150, height = 24, iconGap = 2, growth = "DOWN", cdFontSize = 18, cdFontColor = DEFAULT_CD_COLOR, cdPosition = "CENTER", cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackPosition = "BOTTOMRIGHT", stackXOffset = 0, stackYOffset = 0 },
    BuffIcon = { width = 45, height = 45, iconGap = 2, growth = "CENTER_HORIZONTAL", cdFontSize = 18, cdFontColor = DEFAULT_CD_COLOR, cdPosition = "CENTER", cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackPosition = "BOTTOMRIGHT", stackXOffset = 0, stackYOffset = 0 }, 
    Essential = { enableCustomLayout = true, maxPerRow = 7, iconGap = 2, rowYGap = 2, row1Width = 45, row1Height = 45, row1CdFontSize = 18, row1CdFontColor = DEFAULT_CD_COLOR, row1CdPosition = "CENTER", row1CdXOffset = 0, row1CdYOffset = 0, row1StackFontSize = 14, row1StackFontColor = DEFAULT_STACK_COLOR, row1StackPosition = "BOTTOMRIGHT", row1StackXOffset = 0, row1StackYOffset = 0, row2Width = 40, row2Height = 40, row2IconGap = 2, row2CdFontSize = 18, row2CdFontColor = DEFAULT_CD_COLOR, row2CdPosition = "CENTER", row2CdXOffset = 0, row2CdYOffset = 0, row2StackFontSize = 14, row2StackFontColor = DEFAULT_STACK_COLOR, row2StackPosition = "BOTTOMRIGHT", row2StackXOffset = 0, row2StackYOffset = 0 }
}

-- ========================================================
-- [完美像素引擎 VFlow 同款] 
-- ========================================================
local function GetOnePixelSize()
    local screenHeight = select(2, GetPhysicalScreenSize())
    if not screenHeight or screenHeight == 0 then return 1 end
    local uiScale = UIParent:GetEffectiveScale()
    if not uiScale or uiScale == 0 then return 1 end
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

local function AddElvUIBorder(frame)
    if not frame then return end
    if frame.backdrop then frame.backdrop:SetAlpha(0) end

    local m = GetOnePixelSize()
    local anchorTarget = (frame.Icon and (frame.Icon.Icon or frame.Icon)) or frame
    
    if not frame.wishBorder then
        local border = CreateFrame("Frame", nil, frame)
        border:SetAllPoints(anchorTarget)
        border:SetFrameLevel(frame:GetFrameLevel() + 1) 

        local top = CreateBorderTex(border, "OVERLAY", 7)
        top:SetColorTexture(0, 0, 0, 1)
        top:SetPoint("TOPLEFT", border, "TOPLEFT", 0, 0)
        top:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, 0)
        top:SetHeight(m)

        local bottom = CreateBorderTex(border, "OVERLAY", 7)
        bottom:SetColorTexture(0, 0, 0, 1)
        bottom:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, 0)
        bottom:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, 0)
        bottom:SetHeight(m)

        local left = CreateBorderTex(border, "OVERLAY", 7)
        left:SetColorTexture(0, 0, 0, 1)
        left:SetPoint("TOPLEFT", border, "TOPLEFT", 0, -m)
        left:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, m)
        left:SetWidth(m)

        local right = CreateBorderTex(border, "OVERLAY", 7)
        right:SetColorTexture(0, 0, 0, 1)
        right:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, -m)
        right:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, m)
        right:SetWidth(m)

        frame.wishBorder = border
    end
    
    if frame.Icon then
        local tex = frame.Icon.Icon or frame.Icon
        if type(tex) == "table" and tex.SetDrawLayer then tex:SetDrawLayer("ARTWORK", 1) end
    end

    if frame.Bar then
        if not frame.wishBarBorder then
            local barBorder = CreateFrame("Frame", nil, frame.Bar)
            barBorder:SetAllPoints(frame.Bar)
            barBorder:SetFrameLevel(frame.Bar:GetFrameLevel() + 1)

            local top = CreateBorderTex(barBorder, "OVERLAY", 7)
            top:SetColorTexture(0, 0, 0, 1)
            top:SetPoint("TOPLEFT", barBorder, "TOPLEFT", 0, 0)
            top:SetPoint("TOPRIGHT", barBorder, "TOPRIGHT", 0, 0)
            top:SetHeight(m)

            local bottom = CreateBorderTex(barBorder, "OVERLAY", 7)
            bottom:SetColorTexture(0, 0, 0, 1)
            bottom:SetPoint("BOTTOMLEFT", barBorder, "BOTTOMLEFT", 0, 0)
            bottom:SetPoint("BOTTOMRIGHT", barBorder, "BOTTOMRIGHT", 0, 0)
            bottom:SetHeight(m)

            local left = CreateBorderTex(barBorder, "OVERLAY", 7)
            left:SetColorTexture(0, 0, 0, 1)
            left:SetPoint("TOPLEFT", barBorder, "TOPLEFT", 0, -m)
            left:SetPoint("BOTTOMLEFT", barBorder, "BOTTOMLEFT", 0, m)
            left:SetWidth(m)

            local right = CreateBorderTex(barBorder, "OVERLAY", 7)
            right:SetColorTexture(0, 0, 0, 1)
            right:SetPoint("TOPRIGHT", barBorder, "TOPRIGHT", 0, -m)
            right:SetPoint("BOTTOMRIGHT", barBorder, "BOTTOMRIGHT", 0, m)
            right:SetWidth(m)

            frame.wishBarBorder = barBorder
        end
    end
end

local function WeldToMover(frame, anchorFrame)
    if frame and anchorFrame then frame:ClearAllPoints(); frame:SetPoint("CENTER", anchorFrame, "CENTER") end
end

local BURST_THROTTLE = 0.033; local WATCHDOG_THROTTLE = 0.25; local BURST_TICKS = 5; local IDLE_DISABLE_SEC = 2.0
local layoutEngine = CreateFrame("Frame"); local engineEnabled = false; local layoutDirty = true
local burstTicksRemaining = 0; local lastActivityTime = 0; local nextUpdateTime = 0; local lastLayoutHash = ""

local function PhysicalHideFrame(frame) if not frame then return end; frame:SetAlpha(0); if frame.Icon then frame.Icon:SetAlpha(0) end; frame:EnableMouse(false); frame:ClearAllPoints(); frame:SetPoint("CENTER", UIParent, "CENTER", -5000, 0); frame._wishFlexHidden = true end
local function GetLayoutStateHash()
    local hash = ""; local viewers = { _G.UtilityCooldownViewer, _G.EssentialCooldownViewer, _G.BuffIconCooldownViewer, _G.BuffBarCooldownViewer }
    for _, viewer in ipairs(viewers) do if viewer and viewer.itemFramePool then local c = 0; for f in viewer.itemFramePool:EnumerateActive() do if f:IsShown() then local sid = (f.cooldownInfo and f.cooldownInfo.spellID) or 0; local idx = f.layoutIndex or 0; local hidden = f._wishFlexHidden and 1 or 0; hash = hash .. sid .. ":" .. idx .. ":" .. hidden .. "|"; c = c + 1 end end; hash = hash .. "C:" .. c .. "|" end end
    return hash
end

function CDMod:MarkLayoutDirty()
    layoutDirty = true; burstTicksRemaining = BURST_TICKS; lastActivityTime = GetTime(); nextUpdateTime = 0
    if not engineEnabled then layoutEngine:SetScript("OnUpdate", self.OnUpdateEngine); engineEnabled = true end
end
WF.TriggerCooldownLayout = function() CDMod:MarkLayoutDirty() end

function CDMod.OnUpdateEngine()
    local now = GetTime(); local throttle = (layoutDirty or burstTicksRemaining > 0) and BURST_THROTTLE or WATCHDOG_THROTTLE
    if now < nextUpdateTime then return end; nextUpdateTime = now + throttle
    if layoutDirty or burstTicksRemaining > 0 then
        CDMod:BuildHiddenCache(); local currentHash = GetLayoutStateHash()
        if currentHash ~= lastLayoutHash or layoutDirty then lastLayoutHash = currentHash; CDMod:UpdateAllLayouts(); CDMod:ForceBuffsLayout() end
        if burstTicksRemaining > 0 then burstTicksRemaining = burstTicksRemaining - 1 elseif (now - lastActivityTime) >= IDLE_DISABLE_SEC then layoutEngine:SetScript("OnUpdate", nil); engineEnabled = false end
        layoutDirty = false; lastActivityTime = now
    end
end

local function IsSafeValue(val) return val ~= nil and (type(issecretvalue) ~= "function" or not issecretvalue(val)) end
local function GetBaseSpellFast(spellID) if not IsSafeValue(spellID) then return nil end; if BaseSpellCache[spellID] == nil then local base = spellID; pcall(function() if C_Spell and C_Spell.GetBaseSpell then base = C_Spell.GetBaseSpell(spellID) or spellID end end); BaseSpellCache[spellID] = base end; return BaseSpellCache[spellID] end
function CDMod:BuildHiddenCache()
    wipe(self.hiddenAuras); local playerClass = select(2, UnitClass("player"))
    if not WishFlexDB.global then WishFlexDB.global = {} end; local spellDB = WishFlexDB.global.spellDB
    if spellDB then for k, v in pairs(spellDB) do if type(v) == "table" and v.hideOriginal ~= false then if not v.class or v.class == "ALL" or v.class == playerClass then local sid = tonumber(k); local bid = v.buffID or sid; if sid then self.hiddenAuras[sid] = true end; if bid then self.hiddenAuras[bid] = true end end end end end
end
local function ShouldHideFrame(info)
    if not info then return false end
    if IsSafeValue(info.spellID) then if CDMod.hiddenAuras[info.spellID] or CDMod.hiddenAuras[info.overrideSpellID] then return true end; local baseID = GetBaseSpellFast(info.spellID); if baseID and CDMod.hiddenAuras[baseID] then return true end end
    if info.linkedSpellIDs then for i = 1, #info.linkedSpellIDs do local lid = info.linkedSpellIDs[i]; if IsSafeValue(lid) and CDMod.hiddenAuras[lid] then return true end end end
    return false
end

local function SetupFrameGlow(frame)
    if not frame then return end
    if frame.SpellActivationAlert and not frame._wf_glowHooked then
        frame._wf_glowHooked = true
        frame.SpellActivationAlert:SetAlpha(0) 
        hooksecurefunc(frame.SpellActivationAlert, "Show", function(self)
            self:SetAlpha(0); if WF.GlowAPI then WF.GlowAPI:Show(frame) end
        end)
        hooksecurefunc(frame.SpellActivationAlert, "Hide", function(self)
            if WF.GlowAPI then WF.GlowAPI:Hide(frame) end
        end)
        if frame.SpellActivationAlert:IsShown() then
            if WF.GlowAPI then WF.GlowAPI:Show(frame) end
        end
    end
end

function CDMod.ApplyTexCoord(texture, w, h) 
    if not texture or not w or not h or h == 0 then return end
    local ratio = w / h
    if ratio == 1 then texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    elseif ratio > 1 then local offset = (1 - (h/w)) / 2 * 0.84; texture:SetTexCoord(0.08, 0.92, 0.08 + offset, 0.92 - offset)
    else local offset = (1 - (w/h)) / 2 * 0.84; texture:SetTexCoord(0.08 + offset, 0.92 - offset, 0.08, 0.92) end
end

local function SafeEquals(v, expected) return (type(v) ~= "number" or not (issecretvalue and issecretvalue(v))) and v == expected end
local function SafeHide(self) if self:IsShown() then self:Hide(); self:SetAlpha(0) end end

local function SuppressDebuffBorder(f)
    if not f or f._wishBorderSuppressed then return end; f._wishBorderSuppressed = true
    local borders = { f.DebuffBorder, f.Border, f.IconBorder, f.IconOverlay, f.overlay, f.ExpireBorder, f.Icon and f.Icon.Border, f.Icon and f.Icon.IconBorder, f.Icon and f.Icon.DebuffBorder }
    for i = 1, #borders do local border = borders[i]; if border then border:Hide(); border:SetAlpha(0); hooksecurefunc(border, "Show", SafeHide) end end
    if f.DebuffBorder and f.DebuffBorder.UpdateFromAuraData then hooksecurefunc(f.DebuffBorder, "UpdateFromAuraData", SafeHide) end
    for i = 1, select("#", f:GetRegions()) do local region = select(i, f:GetRegions()); if region and region.IsObjectType and region:IsObjectType("Texture") then if SafeEquals(region:GetAtlas(), "UI-HUD-CoolDownManager-IconOverlay") or SafeEquals(region:GetTexture(), 6707800) then region:SetAlpha(0); region:Hide(); hooksecurefunc(region, "Show", SafeHide) end end end
end

local function SortByLayoutIndex(a, b) return (a.layoutIndex or 999) < (b.layoutIndex or 999) end

local function StaticUpdateSwipeColor(self) 
    local b = self:GetParent(); local cddb = WF.db.cooldownCustom; 
    if b and b.wasSetFromAura then 
        local ac = cddb.activeAuraColor or DEFAULT_ACTIVE_AURA_COLOR; self:SetSwipeColor(ac.r, ac.g, ac.b, ac.a) 
    else 
        local sc = cddb.swipeColor or DEFAULT_SWIPE_COLOR; self:SetSwipeColor(sc.r, sc.g, sc.b, sc.a) 
    end 
end

function CDMod:ApplySwipeSettings(frame) 
    if not frame or not frame.Cooldown then return end
    local db = WF.db.cooldownCustom; 
    local rev = db.reverseSwipe; if rev == nil then rev = true end
    frame.Cooldown:SetReverse(rev)
    frame.Cooldown:SetDrawEdge(false)
    frame.Cooldown:SetDrawBling(false)
    frame.Cooldown:SetUseCircularEdge(false)
    frame.Cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8x8")
    local anchor = (frame.Icon and (frame.Icon.Icon or frame.Icon)) or frame
    frame.Cooldown:ClearAllPoints()
    frame.Cooldown:SetAllPoints(anchor)
    frame.Cooldown:SetFrameLevel(frame:GetFrameLevel() + 2)

    if not frame.Cooldown._wishSwipeHooked then 
        hooksecurefunc(frame.Cooldown, "SetCooldown", StaticUpdateSwipeColor)
        if frame.Cooldown.SetCooldownFromDurationObject then hooksecurefunc(frame.Cooldown, "SetCooldownFromDurationObject", StaticUpdateSwipeColor) end
        frame.Cooldown._wishSwipeHooked = true 
    end
    
    if frame.wasSetFromAura then 
        local ac = db.activeAuraColor or DEFAULT_ACTIVE_AURA_COLOR; frame.Cooldown:SetSwipeColor(ac.r, ac.g, ac.b, ac.a) 
    else 
        local sc = db.swipeColor or DEFAULT_SWIPE_COLOR; frame.Cooldown:SetSwipeColor(sc.r, sc.g, sc.b, sc.a) 
    end 
end

local function FormatText(t, isStack, cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY, fontPath, outline, frame) if not t or type(t) ~= "table" or not t.SetFont then return end; local size = isStack and stackSize or cdSize; local color = isStack and stackColor or cdColor; local pos = isStack and stackPos or cdPos or "CENTER"; local ox = isStack and stackX or cdX or 0; local oy = isStack and stackY or cdY or 0; t:SetFont(fontPath, size, outline); t:SetTextColor(color.r, color.g, color.b); t:ClearAllPoints(); t:SetPoint(pos, frame.Icon or frame, pos, ox, oy); t:SetDrawLayer("OVERLAY", 7) end

function CDMod:ApplyText(frame, category, rowIndex)
    local db = WF.db.cooldownCustom; local cfg = db[category]; if not cfg then return end
    local fontPath = (LSM and LSM:Fetch('font', db.countFont)) or STANDARD_TEXT_FONT; local outline = db.countFontOutline or "OUTLINE"
    local cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY
    if category == "Essential" then if rowIndex == 2 then cdSize, cdColor, cdPos, cdX, cdY = cfg.row2CdFontSize, cfg.row2CdFontColor, cfg.row2CdPosition or "CENTER", cfg.row2CdXOffset or 0, cfg.row2CdYOffset or 0; stackSize, stackColor, stackPos, stackX, stackY = cfg.row2StackFontSize, cfg.row2StackFontColor, cfg.row2StackPosition or "BOTTOMRIGHT", cfg.row2StackXOffset or 0, cfg.row2StackYOffset or 0 else cdSize, cdColor, cdPos, cdX, cdY = cfg.row1CdFontSize, cfg.row1CdFontColor, cfg.row1CdPosition or "CENTER", cfg.row1CdXOffset or 0, cfg.row1CdYOffset or 0; stackSize, stackColor, stackPos, stackX, stackY = cfg.row1StackFontSize, cfg.row1StackFontColor, cfg.row1StackPosition or "BOTTOMRIGHT", cfg.row1StackXOffset or 0, cfg.row1StackYOffset or 0 end
    else cdSize, cdColor, cdPos, cdX, cdY = cfg.cdFontSize, cfg.cdFontColor, cfg.cdPosition or "CENTER", cfg.cdXOffset or 0, cfg.cdYOffset or 0; stackSize, stackColor, stackPos, stackX, stackY = cfg.stackFontSize, cfg.stackFontColor, cfg.stackPosition or "BOTTOMRIGHT", cfg.stackXOffset or 0, cfg.stackYOffset or 0 end
    local stackText = (frame.Applications and frame.Applications.Applications) or (frame.ChargeCount and frame.ChargeCount.Current) or frame.Count
    if frame.Cooldown then if frame.Cooldown.timer and frame.Cooldown.timer.text then FormatText(frame.Cooldown.timer.text, false, cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY, fontPath, outline, frame) end; for k = 1, select("#", frame.Cooldown:GetRegions()) do local region = select(k, frame.Cooldown:GetRegions()); if region and region.IsObjectType and region:IsObjectType("FontString") then FormatText(region, false, cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY, fontPath, outline, frame) end end end
    FormatText(stackText, true, cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY, fontPath, outline, frame)
end

function CDMod:ImmediateStyleFrame(frame, category)
    if not frame then return end
    if (category == "BuffIcon" or category == "BuffBar") and ShouldHideFrame(frame.cooldownInfo) then PhysicalHideFrame(frame); return end
    if frame._wishFlexHidden then frame._wishFlexHidden = false; frame:SetAlpha(1); if frame.Icon then frame.Icon:SetAlpha(1) end; frame:EnableMouse(true) end
    SuppressDebuffBorder(frame); self:ApplyText(frame, category, 1); self:ApplySwipeSettings(frame)
    local db = WF.db.cooldownCustom; local cfg = db[category]
    if cfg then 
        local w = PixelSnap(cfg.width or cfg.row1Width or 45)
        local h = PixelSnap(cfg.height or cfg.row1Height or 45)
        frame:SetSize(w, h); 
        if frame.Icon then 
            local iconObj = frame.Icon.Icon or frame.Icon; CDMod.ApplyTexCoord(iconObj, w, h); 
            if frame.Bar then 
                local gap = PixelSnap(cfg.iconGap or 2)
                frame.Icon:SetSize(h, h); 
                frame.Bar:SetSize(math.max(1, w - h - gap), h); 
                frame.Bar:ClearAllPoints(); frame.Bar:SetPoint("LEFT", frame.Icon, "RIGHT", gap, 0) 
            end 
        end 
    end
    AddElvUIBorder(frame)
    SetupFrameGlow(frame)
end

local cachedIcons = {}; local cachedFrames = {}; local cachedR1 = {}; local cachedR2 = {}
local function DoLayoutBuffs(viewerName, key, isVertical)
    local db = WF.db.cooldownCustom; local container = _G[viewerName]; if not container or not container:IsShown() then return end
    local targetAnchor = _G["WishFlex_Anchor_"..key]
    
    if targetAnchor then WeldToMover(container, targetAnchor) end
    
    wipe(cachedIcons); local count = 0
    if container.itemFramePool then for f in container.itemFramePool:EnumerateActive() do if f:IsShown() then if ShouldHideFrame(f.cooldownInfo) then PhysicalHideFrame(f) else if f._wishFlexHidden then f._wishFlexHidden = false; f:SetAlpha(1); if f.Icon then f.Icon:SetAlpha(1) end; f:EnableMouse(true) end; count = count + 1; cachedIcons[count] = f; SuppressDebuffBorder(f); CDMod:ApplyText(f, key); CDMod:ApplySwipeSettings(f) end end end end 
    if count == 0 then return end; table.sort(cachedIcons, SortByLayoutIndex)
    
    local cfg = db[key]; 
    local w = PixelSnap(cfg.width or 45)
    local h = PixelSnap(cfg.height or 45)
    local gap = PixelSnap(cfg.iconGap or 2)
    local growth = cfg.growth or (isVertical and "DOWN" or "CENTER_HORIZONTAL")
    
    local totalW = (count * w) + math.max(0, (count - 1) * gap); local totalH = (count * h) + math.max(0, (count - 1) * gap)
    
    container:SetSize(math.max(1, isVertical and w or totalW), math.max(1, isVertical and totalH or h))
    if targetAnchor then targetAnchor:SetSize(container:GetSize()); if targetAnchor.mover then targetAnchor.mover:SetSize(targetAnchor:GetSize()) end end

    if isVertical then
        local startY = (totalH / 2) - (h / 2)
        for i = 1, count do local f = cachedIcons[i]; f:ClearAllPoints(); f:SetSize(w, h); if growth == "UP" then f:SetPoint("CENTER", container, "CENTER", 0, -startY + (i - 1) * (h + gap)) else f:SetPoint("CENTER", container, "CENTER", 0, startY - (i - 1) * (h + gap)) end; if f.Icon then local iconObj = f.Icon.Icon or f.Icon; if not f.Bar then f.Icon:SetSize(w, h); CDMod.ApplyTexCoord(iconObj, w, h) else f.Icon:SetSize(h, h); f.Bar:SetSize(math.max(1, w - h - gap), h); f.Bar:ClearAllPoints(); f.Bar:SetPoint("LEFT", f.Icon, "RIGHT", gap, 0); if iconObj then CDMod.ApplyTexCoord(iconObj, h, h) end end end; AddElvUIBorder(f); SetupFrameGlow(f) end
    else
        local startX = -(totalW / 2) + (w / 2)
        for i = 1, count do local f = cachedIcons[i]; f:ClearAllPoints(); f:SetSize(w, h); if growth == "LEFT" then f:SetPoint("CENTER", container, "CENTER", -startX - (i - 1) * (w + gap), 0) elseif growth == "RIGHT" then f:SetPoint("CENTER", container, "CENTER", startX + (i - 1) * (w + gap), 0) else f:SetPoint("CENTER", container, "CENTER", startX + (i - 1) * (w + gap), 0) end; if f.Icon then local iconObj = f.Icon.Icon or f.Icon; if not f.Bar then f.Icon:SetSize(w, h); CDMod.ApplyTexCoord(iconObj, w, h) else f.Icon:SetSize(h, h); f.Bar:SetSize(math.max(1, w - h - gap), h); f.Bar:ClearAllPoints(); f.Bar:SetPoint("LEFT", f.Icon, "RIGHT", gap, 0); if iconObj then CDMod.ApplyTexCoord(iconObj, h, h) end end end; AddElvUIBorder(f); SetupFrameGlow(f) end
    end
    container:Show(); container:SetAlpha(1)
end

function CDMod:ForceBuffsLayout() DoLayoutBuffs("BuffIconCooldownViewer", "BuffIcon", false); DoLayoutBuffs("BuffBarCooldownViewer", "BuffBar", true) end

WF.UpdateCooldownGlows = function()
    local viewers = { _G.UtilityCooldownViewer, _G.EssentialCooldownViewer, _G.BuffIconCooldownViewer, _G.BuffBarCooldownViewer }
    for _, viewer in ipairs(viewers) do
        if viewer and viewer.itemFramePool then
            for f in viewer.itemFramePool:EnumerateActive() do
                if f and f.SpellActivationAlert and f.SpellActivationAlert:IsShown() and WF.GlowAPI then
                    WF.GlowAPI:Show(f)
                end
            end
        end
    end
end

function CDMod:UpdateAllLayouts()
    local db = WF.db.cooldownCustom
    local r1Mover = _G["WishFlex_Anchor_EssentialMover"]; local r2Mover = _G["WishFlex_Anchor_EssentialR2Mover"]
    if r1Mover and r2Mover then r2Mover:ClearAllPoints(); r2Mover:SetPoint("TOP", r1Mover, "BOTTOM", 0, -(db.Essential.rowYGap or 2)) end

    local function LayoutViewer(viewer, cfg, cat)
        if not viewer or not viewer.itemFramePool then return end
        local targetAnchor = _G["WishFlex_Anchor_"..cat]; local attachToPlayer = (cat == "Utility" and cfg.attachToPlayer)
        
        if not attachToPlayer and targetAnchor then WeldToMover(viewer, targetAnchor) end
        
        wipe(cachedFrames); local count = 0
        for f in viewer.itemFramePool:EnumerateActive() do 
            if f:IsShown() then 
                f:Show(); f:SetAlpha(1)
                if f._wishFlexHidden then f._wishFlexHidden = false; if f.Icon then f.Icon:SetAlpha(1) end; f:EnableMouse(true) end
                count = count + 1; cachedFrames[count] = f; SuppressDebuffBorder(f); self:ApplyText(f, cat, 1); self:ApplySwipeSettings(f); SetupFrameGlow(f)
            end 
        end
        if count == 0 then return end; table.sort(cachedFrames, SortByLayoutIndex)
        
        local w = PixelSnap(cfg.width or 45)
        local h = PixelSnap(cfg.height or 30)
        local gap = PixelSnap(cfg.iconGap or 2)
        
        local growth = attachToPlayer and "LEFT" or (cfg.growth or "CENTER_HORIZONTAL"); local totalW = (count * w) + math.max(0, (count - 1) * gap)
        
        viewer:SetSize(math.max(1, totalW), math.max(1, h))
        if not attachToPlayer and targetAnchor then targetAnchor:SetSize(viewer:GetSize()); if targetAnchor.mover then targetAnchor.mover:SetSize(targetAnchor:GetSize()) end end

        local anchorFrame = nil
        if attachToPlayer then if _G.ElvUF_Player then anchorFrame = _G.ElvUF_Player.backdrop or _G.ElvUF_Player elseif _G.PlayerFrame then anchorFrame = _G.PlayerFrame end end

        if attachToPlayer and anchorFrame then
            viewer:ClearAllPoints(); viewer:SetPoint("BOTTOMRIGHT", anchorFrame, "TOPRIGHT", cfg.attachX or 0, cfg.attachY or 1)
            for i = 1, count do local f = cachedFrames[i]; f:ClearAllPoints(); f:SetSize(w, h); f:SetPoint("RIGHT", viewer, "RIGHT", -((i - 1) * (w + gap)), 0); if f.Icon then CDMod.ApplyTexCoord(f.Icon.Icon or f.Icon, w, h) end; AddElvUIBorder(f) end
        else
            local startX = -(totalW / 2) + (w / 2)
            for i = 1, count do local f = cachedFrames[i]; f:ClearAllPoints(); f:SetSize(w, h); if growth == "LEFT" then f:SetPoint("CENTER", viewer, "CENTER", -startX - (i - 1) * (w + gap), 0) elseif growth == "RIGHT" then f:SetPoint("CENTER", viewer, "CENTER", startX + (i - 1) * (w + gap), 0) else f:SetPoint("CENTER", viewer, "CENTER", startX + (i - 1) * (w + gap), 0) end; if f.Icon then CDMod.ApplyTexCoord(f.Icon.Icon or f.Icon, w, h) end; AddElvUIBorder(f) end
        end
        viewer:Show(); viewer:SetAlpha(1)
    end
    
    LayoutViewer(_G.UtilityCooldownViewer, db.Utility, "Utility")

    local eViewer = _G.EssentialCooldownViewer
    if eViewer and eViewer.itemFramePool then
        local targetAnchor = _G["WishFlex_Anchor_Essential"]
        
        if targetAnchor then WeldToMover(eViewer, targetAnchor) end
        
        wipe(cachedFrames); local count = 0
        for f in eViewer.itemFramePool:EnumerateActive() do 
            if f:IsShown() then 
                f:Show(); f:SetAlpha(1)
                if f._wishFlexHidden then f._wishFlexHidden = false; if f.Icon then f.Icon:SetAlpha(1) end; f:EnableMouse(true) end
                count = count + 1; cachedFrames[count] = f 
            end 
        end
        
        if count > 0 then
            table.sort(cachedFrames, SortByLayoutIndex); local cfgE = db.Essential
            if cfgE.enableCustomLayout then
                wipe(cachedR1); wipe(cachedR2); local r1c, r2c = 0, 0
                for i = 1, count do local f = cachedFrames[i]; if i <= cfgE.maxPerRow then r1c = r1c + 1; cachedR1[r1c] = f else r2c = r2c + 1; cachedR2[r2c] = f end end
                
                local w1 = PixelSnap(cfgE.row1Width or 45)
                local h1 = PixelSnap(cfgE.row1Height or 45)
                local gap = PixelSnap(cfgE.iconGap or 2)
                
                local totalW1 = (r1c * w1) + math.max(0, (r1c - 1) * gap); local startX1 = -(totalW1 / 2) + (w1 / 2)
                eViewer:SetSize(math.max(1, totalW1), math.max(1, h1))
                if targetAnchor then targetAnchor:SetSize(math.max(1, totalW1), math.max(1, h1)); if targetAnchor.mover then targetAnchor.mover:SetSize(targetAnchor:GetSize()) end end

                for i = 1, r1c do 
                    local f = cachedR1[i]
                    f:ClearAllPoints()
                    local xOff = startX1 + (i - 1) * (w1 + gap)
                    if targetAnchor then f:SetPoint("CENTER", targetAnchor, "CENTER", xOff, 0) else f:SetPoint("CENTER", eViewer, "CENTER", xOff, 0) end
                    f:SetSize(w1, h1); if f.Icon then CDMod.ApplyTexCoord(f.Icon.Icon or f.Icon, w1, h1) end
                    SuppressDebuffBorder(f); self:ApplyText(f, "Essential", 1); self:ApplySwipeSettings(f); AddElvUIBorder(f); SetupFrameGlow(f)
                end
                
                local r2Anchor = _G["WishFlex_Anchor_EssentialR2"]
                if r2Anchor then
                    WeldToMover(r2Anchor, r2Anchor.mover)
                    
                    local w2 = PixelSnap(cfgE.row2Width or 40)
                    local h2 = PixelSnap(cfgE.row2Height or 40)
                    local gap2 = PixelSnap(cfgE.row2IconGap or 2)
                    
                    local totalW2 = (r2c * w2) + math.max(0, (r2c - 1) * gap2); local startX2 = -(totalW2 / 2) + (w2 / 2)
                    r2Anchor:SetSize(math.max(1, totalW2), math.max(1, h2)); if r2Anchor.mover then r2Anchor.mover:SetSize(r2Anchor:GetSize()) end
                    
                    for i = 1, r2c do 
                        local f = cachedR2[i]
                        f:ClearAllPoints(); f:SetPoint("CENTER", r2Anchor, "CENTER", startX2 + (i - 1) * (w2 + gap2), 0); f:SetSize(w2, h2); if f.Icon then CDMod.ApplyTexCoord(f.Icon.Icon or f.Icon, w2, h2) end
                        SuppressDebuffBorder(f); self:ApplyText(f, "Essential", 2); self:ApplySwipeSettings(f); AddElvUIBorder(f); SetupFrameGlow(f)
                    end
                end
            end
            eViewer:Show(); eViewer:SetAlpha(1)
        end
    end
end

local function InitCooldownCustom()
    if not WF.db.cooldownCustom then WF.db.cooldownCustom = {} end
    for k, v in pairs(DefaultConfig) do if WF.db.cooldownCustom[k] == nil then WF.db.cooldownCustom[k] = v end end
    for _, k in ipairs({"Essential", "Utility", "BuffBar", "BuffIcon"}) do for subK, subV in pairs(DefaultConfig[k]) do if WF.db.cooldownCustom[k][subK] == nil then WF.db.cooldownCustom[k][subK] = subV end end end
    if not WF.db.cooldownCustom.enable then return end
    
    -- [引擎注入] 确保独立版的拖拽数据库存在
    if not WF.db.movers then WF.db.movers = {} end

    local anchors = {
        { name = "WishFlex_Anchor_Utility", title = "冷却：功能型法术", point = {"CENTER", UIParent, "CENTER", 0, -100} },
        { name = "WishFlex_Anchor_Essential", title = "冷却：核心/爆发", point = {"TOP", UIParent, "CENTER", 0, -60} },
        { name = "WishFlex_Anchor_EssentialR2", title = "冷却：核心第2排", point = {"TOP", UIParent, "CENTER", 0, 0} },
        { name = "WishFlex_Anchor_BuffIcon", title = "冷却：增益图标", point = {"BOTTOM", UIParent, "CENTER", 0, 60} },
        { name = "WishFlex_Anchor_BuffBar", title = "冷却：增益条", point = {"CENTER", UIParent, "CENTER", 0, 150} }
    }
    
    for _, a in ipairs(anchors) do
        local frame = CreateFrame("Frame", a.name, UIParent)
        WF:CreateMover(frame, a.name.."Mover", a.point, 45, 45, a.title)
        
        -- [核心修复：注入坐标记忆引擎]
        local moverName = a.name.."Mover"
        local mover = _G[moverName]
        if mover then
            -- 1. 从数据库读取记忆坐标并恢复
            if WF.db.movers[moverName] then
                local p = WF.db.movers[moverName]
                mover:ClearAllPoints()
                mover:SetPoint(p.point, UIParent, p.relativePoint, p.xOfs, p.yOfs)
            end
            
            -- 2. 挂钩拖动结束事件，每次拖动完自动写入数据库
            if not mover._wishSaveHooked then
                mover:HookScript("OnDragStop", function(self)
                    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
                    WF.db.movers[self:GetName()] = {
                        point = point,
                        relativePoint = relativePoint,
                        xOfs = xOfs,
                        yOfs = yOfs
                    }
                end)
                mover._wishSaveHooked = true
            end
        end
    end

    _G["WishFlex_Anchor_EssentialR2Mover"]:ClearAllPoints()
    _G["WishFlex_Anchor_EssentialR2Mover"]:SetPoint("TOP", _G["WishFlex_Anchor_EssentialMover"], "BOTTOM", 0, -(WF.db.cooldownCustom.Essential.rowYGap or 2))

    local viewers = { EssentialCooldownViewer = "Essential", UtilityCooldownViewer = "Utility", BuffIconCooldownViewer = "BuffIcon", BuffBarCooldownViewer = "BuffBar" }
    for vName, cat in pairs(viewers) do 
        local v = _G[vName]; 
        if v then 
            if v.OnAcquireItemFrame then hooksecurefunc(v, "OnAcquireItemFrame", function(_, frame) CDMod:ImmediateStyleFrame(frame, cat); CDMod:MarkLayoutDirty() end) end; 
            v.UpdateLayout = function() CDMod:MarkLayoutDirty() end; v.Layout = function() CDMod:MarkLayoutDirty() end
        end 
    end

    local mixins = { {"BuffIcon", _G.CooldownViewerBuffIconItemMixin}, {"Essential", _G.CooldownViewerEssentialItemMixin}, {"Utility", _G.CooldownViewerUtilityItemMixin}, {"BuffBar", _G.CooldownViewerBuffBarItemMixin} }
    for _, data in ipairs(mixins) do local cat, mixin = data[1], data[2]; if mixin then if mixin.OnCooldownIDSet then hooksecurefunc(mixin, "OnCooldownIDSet", function(frame) CDMod:ImmediateStyleFrame(frame, cat); CDMod:MarkLayoutDirty() end) end; if mixin.OnActiveStateChanged then hooksecurefunc(mixin, "OnActiveStateChanged", function(frame) CDMod:ImmediateStyleFrame(frame, cat); CDMod:MarkLayoutDirty() end) end end end
    CDMod:MarkLayoutDirty()
end
WF:RegisterModule("cooldownCustom", L["Cooldown Custom"] or "冷却管理器", InitCooldownCustom)


-- =========================================================================
-- [冷却管理器模块 - UI 面板动态注入]
-- =========================================================================
if WF.UI then
    WF.UI:RegisterMenu({ id = "Combat", name = L["Combat"] or "战斗组件", type = "root", icon = "Interface\\AddOns\\WishFlex\\Media\\Icons\\zd", order = 10 })
    WF.UI:RegisterMenu({ id = "CDManager", parent = "Combat", name = L["Cooldown Manager"] or "冷却管理器", type = "group", order = 20 })
    WF.UI:RegisterMenu({ id = "CD_Global", parent = "CDManager", name = L["Global Settings"] or "全局设置", key = "cooldownCustom_Global", order = 1 })
    WF.UI:RegisterMenu({ id = "CD_Essential", parent = "CDManager", name = L["Essential Skills"] or "核心与爆发", key = "cooldownCustom_Essential", order = 3 })
    WF.UI:RegisterMenu({ id = "CD_Utility", parent = "CDManager", name = L["Utility Skills"] or "功能型法术", key = "cooldownCustom_Utility", order = 4 })
    WF.UI:RegisterMenu({ id = "CD_BuffIcon", parent = "CDManager", name = L["Buff Icons"] or "增益图标", key = "cooldownCustom_BuffIcon", order = 5 })
    WF.UI:RegisterMenu({ id = "CD_BuffBar", parent = "CDManager", name = L["Buff Bars"] or "增益条", key = "cooldownCustom_BuffBar", order = 6 })

    local function HandleCDChange(val)
        if WF.TriggerCooldownLayout then WF.TriggerCooldownLayout() end
        if val == "UI_REFRESH" then WF.UI:RefreshCurrentPanel() end
    end

    WF.UI:RegisterPanel("cooldownCustom_Global", function(scrollChild, ColW)
        local db = WF.db.cooldownCustom or {}; if not db.Essential then db.Essential = {} end
        local opts = {
            { type = "group", key = "cd_global_base", text = L["Global Settings"] or "全局设置", childs = {
                { type = "toggle", key = "enable", db = db, text = L["Enable Module"] or "启用模块", requireReload = true },
                { type = "dropdown", key = "countFont", db = db, text = L["Global Font"] or "全局字体", options = WF.UI.FontOptions },
                { type = "color", key = "swipeColor", db = db, text = L["Default Swipe Color"] or "默认冷却遮罩颜色" },
                { type = "color", key = "activeAuraColor", db = db, text = L["Active Swipe Color"] or "激活时冷却遮罩颜色" },
                { type = "toggle", key = "reverseSwipe", db = db, text = L["Reverse Swipe"] or "反转冷却转圈方向" },
                { type = "toggle", key = "enableCustomLayout", db = db.Essential, text = L["Enable Split Layout"] or "启用核心爆发分排布局" },
                { type = "slider", key = "rowYGap", db = db.Essential, min = 0, max = 50, step = 1, text = L["Row Y Gap"] or "第二排Y轴间距" },
            }}
        }
        return WF.UI:RenderOptionsGroup(scrollChild, 15, -10, ColW * 2, opts, HandleCDChange)
    end)

    WF.UI:RegisterPanel("cooldownCustom_Essential", function(scrollChild, ColW)
        local db = WF.db.cooldownCustom or {}; if not db.Essential then db.Essential = {} end
        local leftOpts = {
            { type = "group", key = "ess_row1", text = L["Row 1 Settings"] or "第一排设置", childs = {
                { type = "slider", key = "maxPerRow", db = db.Essential, min = 1, max = 20, step = 1, text = L["Max Per Row"] or "每排最大图标数" },
                { type = "slider", key = "iconGap", db = db.Essential, min = 0, max = 50, step = 1, text = L["Icon Gap"] or "图标间距" },
                { type = "slider", key = "row1Width", db = db.Essential, min = 10, max = 100, step = 1, text = L["Width"] or "宽度" },
                { type = "slider", key = "row1Height", db = db.Essential, min = 10, max = 100, step = 1, text = L["Height"] or "高度" },
                WF.UI:GetTextOptions(db.Essential, "row1Stack", L["Stack Text"] or "层数文本", "ess_row1_stack"),
                WF.UI:GetTextOptions(db.Essential, "row1Cd", L["CD Text"] or "冷却文本", "ess_row1_cd"),
            }}
        }
        local rightOpts = {
            { type = "group", key = "ess_row2", text = L["Row 2 Settings"] or "第二排设置", childs = {
                { type = "slider", key = "row2IconGap", db = db.Essential, min = 0, max = 50, step = 1, text = L["Icon Gap"] or "图标间距" },
                { type = "slider", key = "row2Width", db = db.Essential, min = 10, max = 100, step = 1, text = L["Width"] or "宽度" },
                { type = "slider", key = "row2Height", db = db.Essential, min = 10, max = 100, step = 1, text = L["Height"] or "高度" },
                WF.UI:GetTextOptions(db.Essential, "row2Stack", L["Stack Text"] or "层数文本", "ess_row2_stack"),
                WF.UI:GetTextOptions(db.Essential, "row2Cd", L["CD Text"] or "冷却文本", "ess_row2_cd"),
            }}
        }
        local ly = WF.UI:RenderOptionsGroup(scrollChild, 15, -10, ColW, leftOpts, HandleCDChange)
        local ry = WF.UI:RenderOptionsGroup(scrollChild, 335, -10, ColW, rightOpts, HandleCDChange)
        return math.min(ly, ry)
    end)

    WF.UI:RegisterPanel("cooldownCustom_Utility", function(scrollChild, ColW)
        local db = WF.db.cooldownCustom or {}; if not db.Utility then db.Utility = {} end
        local opts = {
            { type = "group", key = "util_base", text = L["Utility Skills"] or "功能型法术", childs = {
                { type = "toggle", key = "attachToPlayer", db = db.Utility, text = L["Attach To Player"] or "吸附到玩家血条" },
                { type = "slider", key = "iconGap", db = db.Utility, min = 0, max = 50, step = 1, text = L["Icon Gap"] or "图标间距" },
                { type = "slider", key = "width", db = db.Utility, min = 10, max = 100, step = 1, text = L["Width"] or "宽度" },
                { type = "slider", key = "height", db = db.Utility, min = 10, max = 100, step = 1, text = L["Height"] or "高度" },
                WF.UI:GetTextOptions(db.Utility, "stack", L["Stack Text"] or "层数文本", "util_stack"),
                WF.UI:GetTextOptions(db.Utility, "cd", L["CD Text"] or "冷却文本", "util_cd"),
            }}
        }
        return WF.UI:RenderOptionsGroup(scrollChild, 15, -10, ColW * 1.5, opts, HandleCDChange)
    end)

    WF.UI:RegisterPanel("cooldownCustom_BuffIcon", function(scrollChild, ColW)
        local db = WF.db.cooldownCustom or {}; if not db.BuffIcon then db.BuffIcon = {} end
        local opts = {
            { type = "group", key = "icon_base", text = L["Buff Icons"] or "增益图标", childs = {
                { type = "slider", key = "width", db = db.BuffIcon, min = 10, max = 100, step = 1, text = L["Width"] or "宽度" },
                { type = "slider", key = "height", db = db.BuffIcon, min = 10, max = 100, step = 1, text = L["Height"] or "高度" },
                { type = "slider", key = "iconGap", db = db.BuffIcon, min = 0, max = 30, step = 1, text = L["Icon Gap"] or "图标间距" },
                WF.UI:GetTextOptions(db.BuffIcon, "stack", L["Stack Text"] or "层数文本", "icon_stack"),
                WF.UI:GetTextOptions(db.BuffIcon, "cd", L["CD Text"] or "冷却文本", "icon_cd"),
            }}
        }
        return WF.UI:RenderOptionsGroup(scrollChild, 15, -10, ColW * 1.5, opts, HandleCDChange)
    end)

    WF.UI:RegisterPanel("cooldownCustom_BuffBar", function(scrollChild, ColW)
        local db = WF.db.cooldownCustom or {}; if not db.BuffBar then db.BuffBar = {} end
        local opts = {
            { type = "group", key = "bar_base", text = L["Buff Bars"] or "增益条", childs = {
                { type = "slider", key = "width", db = db.BuffBar, min = 50, max = 400, step = 1, text = L["Width"] or "宽度" },
                { type = "slider", key = "height", db = db.BuffBar, min = 10, max = 100, step = 1, text = L["Height"] or "高度" },
                { type = "slider", key = "iconGap", db = db.BuffBar, min = 0, max = 30, step = 1, text = L["Icon Gap"] or "条间距" },
                WF.UI:GetTextOptions(db.BuffBar, "stack", L["Stack Text"] or "层数文本", "bar_stack"),
                WF.UI:GetTextOptions(db.BuffBar, "cd", L["CD Text"] or "冷却文本", "bar_cd"),
            }}
        }
        return WF.UI:RenderOptionsGroup(scrollChild, 15, -10, ColW * 1.5, opts, HandleCDChange)
    end)
end