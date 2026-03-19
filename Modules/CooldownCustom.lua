local AddonName, ns = ...
local WF = ns.WF
local L = ns.L
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
    glowEnable = true, glowType = "pixel", glowUseCustomColor = false, glowColor = {r = 1, g = 1, b = 1, a = 1},
    glowPixelLines = 8, glowPixelFrequency = 0.25, glowPixelLength = 0, glowPixelThickness = 2, glowPixelXOffset = 0, glowPixelYOffset = 0,
    glowAutocastParticles = 4, glowAutocastFrequency = 0.2, glowAutocastScale = 1, glowAutocastXOffset = 0, glowAutocastYOffset = 0,
    glowButtonFrequency = 0, glowProcDuration = 1, glowProcXOffset = 0, glowProcYOffset = 0,
    Utility = { attachToPlayer = false, attachX = 0, attachY = 1, width = 45, height = 30, iconGap = 2, growth = "CENTER_HORIZONTAL", cdFontSize = 18, cdFontColor = DEFAULT_CD_COLOR, cdPosition = "CENTER", cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackPosition = "BOTTOMRIGHT", stackXOffset = 0, stackYOffset = 0 },
    BuffBar = { width = 120, height = 30, iconGap = 2, growth = "DOWN", cdFontSize = 18, cdFontColor = DEFAULT_CD_COLOR, cdPosition = "CENTER", cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackPosition = "BOTTOMRIGHT", stackXOffset = 0, stackYOffset = 0 },
    BuffIcon = { width = 45, height = 45, iconGap = 2, growth = "CENTER_HORIZONTAL", cdFontSize = 18, cdFontColor = DEFAULT_CD_COLOR, cdPosition = "CENTER", cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackPosition = "BOTTOMRIGHT", stackXOffset = 0, stackYOffset = 0 }, 
    Essential = { enableCustomLayout = true, maxPerRow = 7, iconGap = 2, row1Width = 45, row1Height = 45, row1CdFontSize = 18, row1CdFontColor = DEFAULT_CD_COLOR, row1CdPosition = "CENTER", row1CdXOffset = 0, row1CdYOffset = 0, row1StackFontSize = 14, row1StackFontColor = DEFAULT_STACK_COLOR, row1StackPosition = "BOTTOMRIGHT", row1StackXOffset = 0, row1StackYOffset = 0, row2Width = 40, row2Height = 40, row2IconGap = 2, row2CdFontSize = 18, row2CdFontColor = DEFAULT_CD_COLOR, row2CdPosition = "CENTER", row2CdXOffset = 0, row2CdYOffset = 0, row2StackFontSize = 14, row2StackFontColor = DEFAULT_STACK_COLOR, row2StackPosition = "BOTTOMRIGHT", row2StackXOffset = 0, row2StackYOffset = 0 }
}

-- =========================================
-- [最强原生锚点系统]
-- =========================================
local function WeldToMover(frame, anchorFrame)
    if frame and anchorFrame then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", anchorFrame, "CENTER")
    end
end

-- =========================================
-- [核心缓存和排版函数]
-- =========================================
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
function CDMod.OnUpdateEngine()
    local now = GetTime(); local throttle = (layoutDirty or burstTicksRemaining > 0) and BURST_THROTTLE or WATCHDOG_THROTTLE
    if now < nextUpdateTime then return end; nextUpdateTime = now + throttle
    if layoutDirty or burstTicksRemaining > 0 then
        CDMod:BuildHiddenCache()
        local currentHash = GetLayoutStateHash()
        if currentHash ~= lastLayoutHash or layoutDirty then
            lastLayoutHash = currentHash; CDMod:UpdateAllLayouts(); CDMod:ForceBuffsLayout()
        end
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
local function GetKeyFromFrame(frame)
    local parent = frame:GetParent()
    while parent do local name = parent:GetName() or ""; if name:find("UtilityCooldownViewer") then return "Utility" end; if name:find("BuffBarCooldownViewer") then return "BuffBar" end; if name:find("BuffIconCooldownViewer") then return "BuffIcon" end; if name:find("EssentialCooldownViewer") then return "Essential" end; parent = parent:GetParent() end; return nil
end
function CDMod.ApplyTexCoord(texture, width, height) if not texture or not texture.SetTexCoord then return end; local ratio = width / height; local offset = 0.08; local left, right, top, bottom = offset, 1-offset, offset, 1-offset; if ratio > 1 then local vH = (1 - 2*offset) / ratio; top, bottom = 0.5 - (vH/2), 0.5 + (vH/2) elseif ratio < 1 then local vW = (1 - 2*offset) * ratio; left, right = 0.5 - (vW/2), 0.5 + (vW/2) end; texture:SetTexCoord(left, right, top, bottom) end
local function SafeEquals(v, expected) return (type(v) ~= "number" or not (issecretvalue and issecretvalue(v))) and v == expected end
local function SafeHide(self) if self:IsShown() then self:Hide(); self:SetAlpha(0) end end
local function SuppressDebuffBorder(f)
    if not f or f._wishBorderSuppressed then return end; f._wishBorderSuppressed = true
    local borders = { f.DebuffBorder, f.Border, f.IconBorder, f.IconOverlay, f.overlay, f.ExpireBorder, f.Icon and f.Icon.Border, f.Icon and f.Icon.IconBorder, f.Icon and f.Icon.DebuffBorder }
    for i = 1, #borders do local border = borders[i]; if border then border:Hide(); border:SetAlpha(0); hooksecurefunc(border, "Show", SafeHide) end end
    if f.DebuffBorder and f.DebuffBorder.UpdateFromAuraData then hooksecurefunc(f.DebuffBorder, "UpdateFromAuraData", SafeHide) end
    for i = 1, select("#", f:GetRegions()) do local region = select(i, f:GetRegions()); if region and region.IsObjectType and region:IsObjectType("Texture") then if SafeEquals(region:GetAtlas(), "UI-HUD-CoolDownManager-IconOverlay") or SafeEquals(region:GetTexture(), 6707800) then region:SetAlpha(0); region:Hide(); hooksecurefunc(region, "Show", SafeHide) end end end
    if f.PandemicIcon then f.PandemicIcon:SetAlpha(0); f.PandemicIcon:Hide(); hooksecurefunc(f.PandemicIcon, "Show", SafeHide) end
    if type(f.ShowPandemicStateFrame) == "function" then hooksecurefunc(f, "ShowPandemicStateFrame", function(self) if self.PandemicIcon then self.PandemicIcon:Hide(); self.PandemicIcon:SetAlpha(0) end end) end
    if f.CooldownFlash then f.CooldownFlash:SetAlpha(0); f.CooldownFlash:Hide(); hooksecurefunc(f.CooldownFlash, "Show", SafeHide); if f.CooldownFlash.FlashAnim and f.CooldownFlash.FlashAnim.Play then hooksecurefunc(f.CooldownFlash.FlashAnim, "Play", function(self) self:Stop(); f.CooldownFlash:Hide() end) end end
    if f.SpellActivationAlert then f.SpellActivationAlert:SetAlpha(0); f.SpellActivationAlert:Hide(); hooksecurefunc(f.SpellActivationAlert, "Show", SafeHide) end
    local bg = f.backdrop or f
    if bg then if not bg.SetBackdrop then Mixin(bg, BackdropTemplateMixin) end; bg:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1}); bg:SetBackdropBorderColor(0, 0, 0, 1) end
end
local function SortByLayoutIndex(a, b) return (a.layoutIndex or 999) < (b.layoutIndex or 999) end
local function StaticUpdateSwipeColor(self) local b = self:GetParent(); local cddb = WF.db.cooldownCustom; if b and b.wasSetFromAura then local ac = cddb.activeAuraColor or DEFAULT_ACTIVE_AURA_COLOR; self:SetSwipeColor(ac.r, ac.g, ac.b, ac.a) else local sc = cddb.swipeColor or DEFAULT_SWIPE_COLOR; self:SetSwipeColor(sc.r, sc.g, sc.b, sc.a) end end
function CDMod:ApplySwipeSettings(frame) if not frame or not frame.Cooldown then return end; local db = WF.db.cooldownCustom; local rev = db.reverseSwipe; if rev == nil then rev = true end; frame.Cooldown:SetReverse(rev); if not frame.Cooldown._wishSwipeHooked then hooksecurefunc(frame.Cooldown, "SetCooldown", StaticUpdateSwipeColor); if frame.Cooldown.SetCooldownFromDurationObject then hooksecurefunc(frame.Cooldown, "SetCooldownFromDurationObject", StaticUpdateSwipeColor) end; frame.Cooldown._wishSwipeHooked = true end; if frame.wasSetFromAura then local ac = db.activeAuraColor or DEFAULT_ACTIVE_AURA_COLOR; frame.Cooldown:SetSwipeColor(ac.r, ac.g, ac.b, ac.a) else local sc = db.swipeColor or DEFAULT_SWIPE_COLOR; frame.Cooldown:SetSwipeColor(sc.r, sc.g, sc.b, sc.a) end end
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
    if cfg then local w = cfg.width or cfg.row1Width or 45; local h = cfg.height or cfg.row1Height or 45; frame:SetSize(w, h); if frame.Icon then local iconObj = frame.Icon.Icon or frame.Icon; CDMod.ApplyTexCoord(iconObj, w, h); if frame.Bar then frame.Icon:SetSize(h, h); local gap = cfg.iconGap or 2; frame.Bar:SetSize(w - h - gap, h); frame.Bar:ClearAllPoints(); frame.Bar:SetPoint("LEFT", frame.Icon, "RIGHT", gap, 0) end end end
end

local cachedIcons = {}; local cachedFrames = {}; local cachedR1 = {}; local cachedR2 = {}
local function DoLayoutBuffs(viewerName, key, isVertical)
    local db = WF.db.cooldownCustom; local container = _G[viewerName]; if not container or not container:IsShown() then return end
    local targetAnchor = _G["WishFlex_Anchor_"..key]
    WeldToMover(container, targetAnchor) 
    wipe(cachedIcons); local count = 0
    if container.itemFramePool then for f in container.itemFramePool:EnumerateActive() do if f:IsShown() then if ShouldHideFrame(f.cooldownInfo) then PhysicalHideFrame(f) else if f._wishFlexHidden then f._wishFlexHidden = false; f:SetAlpha(1); if f.Icon then f.Icon:SetAlpha(1) end; f:EnableMouse(true) end; count = count + 1; cachedIcons[count] = f; SuppressDebuffBorder(f); CDMod:ApplyText(f, key); CDMod:ApplySwipeSettings(f) end end end end 
    if count == 0 then return end; table.sort(cachedIcons, SortByLayoutIndex)
    local cfg = db[key]; local w, h, gap = cfg.width or 45, cfg.height or 45, cfg.iconGap or 2; local growth = cfg.growth or (isVertical and "DOWN" or "CENTER_HORIZONTAL")
    local totalW = (count * w) + math.max(0, (count - 1) * gap); local totalH = (count * h) + math.max(0, (count - 1) * gap)
    container:SetSize(math.max(1, isVertical and w or totalW), math.max(1, isVertical and totalH or h)); if targetAnchor and targetAnchor.mover then targetAnchor.mover:SetSize(container:GetSize()) end
    if isVertical then
        local startY = (totalH / 2) - (h / 2)
        for i = 1, count do local f = cachedIcons[i]; f:ClearAllPoints(); f:SetSize(w, h); if growth == "UP" then f:SetPoint("CENTER", container, "CENTER", 0, -startY + (i - 1) * (h + gap)) else f:SetPoint("CENTER", container, "CENTER", 0, startY - (i - 1) * (h + gap)) end; if f.Icon then local iconObj = f.Icon.Icon or f.Icon; if not f.Bar then f.Icon:SetSize(w, h); CDMod.ApplyTexCoord(iconObj, w, h) else f.Icon:SetSize(h, h); f.Bar:SetSize(w - h - gap, h); f.Bar:ClearAllPoints(); f.Bar:SetPoint("LEFT", f.Icon, "RIGHT", gap, 0); if iconObj then CDMod.ApplyTexCoord(iconObj, h, h) end end end end
    else
        local startX = -(totalW / 2) + (w / 2)
        for i = 1, count do local f = cachedIcons[i]; f:ClearAllPoints(); f:SetSize(w, h); if growth == "LEFT" then f:SetPoint("CENTER", container, "CENTER", -startX - (i - 1) * (w + gap), 0) elseif growth == "RIGHT" then f:SetPoint("CENTER", container, "CENTER", startX + (i - 1) * (w + gap), 0) else f:SetPoint("CENTER", container, "CENTER", startX + (i - 1) * (w + gap), 0) end; if f.Icon then local iconObj = f.Icon.Icon or f.Icon; if not f.Bar then f.Icon:SetSize(w, h); CDMod.ApplyTexCoord(iconObj, w, h) else f.Icon:SetSize(h, h); f.Bar:SetSize(w - h - gap, h); f.Bar:ClearAllPoints(); f.Bar:SetPoint("LEFT", f.Icon, "RIGHT", gap, 0); if iconObj then CDMod.ApplyTexCoord(iconObj, h, h) end end end end
    end
end

function CDMod:ForceBuffsLayout() DoLayoutBuffs("BuffIconCooldownViewer", "BuffIcon", false); DoLayoutBuffs("BuffBarCooldownViewer", "BuffBar", true) end

function CDMod:UpdateAllLayouts()
    local db = WF.db.cooldownCustom
    local function LayoutViewer(viewer, cfg, cat)
        if not viewer or not viewer.itemFramePool then return end
        local targetAnchor = _G["WishFlex_Anchor_"..cat]
        local attachToPlayer = (cat == "Utility" and cfg.attachToPlayer)
        if not attachToPlayer then WeldToMover(viewer, targetAnchor) end
        
        wipe(cachedFrames); local count = 0
        for f in viewer.itemFramePool:EnumerateActive() do if f:IsShown() then if f._wishFlexHidden then f._wishFlexHidden = false; f:SetAlpha(1); if f.Icon then f.Icon:SetAlpha(1) end; f:EnableMouse(true) end; count = count + 1; cachedFrames[count] = f; SuppressDebuffBorder(f); self:ApplyText(f, cat, 1); self:ApplySwipeSettings(f) end end
        if count == 0 then return end; table.sort(cachedFrames, SortByLayoutIndex)
        local w, h, gap = cfg.width or 45, cfg.height or 30, cfg.iconGap or 2; local growth = attachToPlayer and "LEFT" or (cfg.growth or "CENTER_HORIZONTAL"); local totalW = (count * w) + math.max(0, (count - 1) * gap)
        viewer:SetSize(math.max(1, totalW), math.max(1, h)); if not attachToPlayer and targetAnchor and targetAnchor.mover then targetAnchor.mover:SetSize(viewer:GetSize()) end

        local anchorFrame = nil
        if attachToPlayer then if _G.ElvUF_Player then anchorFrame = _G.ElvUF_Player.backdrop or _G.ElvUF_Player elseif _G.PlayerFrame then anchorFrame = _G.PlayerFrame end end

        if attachToPlayer and anchorFrame then
            viewer:ClearAllPoints()
            viewer:SetPoint("BOTTOMRIGHT", anchorFrame, "TOPRIGHT", cfg.attachX or 0, cfg.attachY or 1)
            for i = 1, count do local f = cachedFrames[i]; f:ClearAllPoints(); f:SetSize(w, h); f:SetPoint("RIGHT", viewer, "RIGHT", -((i - 1) * (w + gap)), 0); if f.Icon then CDMod.ApplyTexCoord(f.Icon.Icon or f.Icon, w, h) end end
        else
            local startX = -(totalW / 2) + (w / 2)
            for i = 1, count do local f = cachedFrames[i]; f:ClearAllPoints(); f:SetSize(w, h); if growth == "LEFT" then f:SetPoint("CENTER", viewer, "CENTER", -startX - (i - 1) * (w + gap), 0) elseif growth == "RIGHT" then f:SetPoint("CENTER", viewer, "CENTER", startX + (i - 1) * (w + gap), 0) else f:SetPoint("CENTER", viewer, "CENTER", startX + (i - 1) * (w + gap), 0) end; if f.Icon then CDMod.ApplyTexCoord(f.Icon.Icon or f.Icon, w, h) end end
        end
    end
    
    LayoutViewer(_G.UtilityCooldownViewer, db.Utility, "Utility")

    local eViewer = _G.EssentialCooldownViewer
    if eViewer and eViewer.itemFramePool then
        local targetAnchor = _G["WishFlex_Anchor_Essential"]
        WeldToMover(eViewer, targetAnchor)
        wipe(cachedFrames); local count = 0
        for f in eViewer.itemFramePool:EnumerateActive() do if f:IsShown() then if f._wishFlexHidden then f._wishFlexHidden = false; f:SetAlpha(1); if f.Icon then f.Icon:SetAlpha(1) end; f:EnableMouse(true) end; count = count + 1; cachedFrames[count] = f end end
        
        if count > 0 then
            table.sort(cachedFrames, SortByLayoutIndex); local cfgE = db.Essential
            if cfgE.enableCustomLayout then
                wipe(cachedR1); wipe(cachedR2); local r1c, r2c = 0, 0
                for i = 1, count do local f = cachedFrames[i]; if i <= cfgE.maxPerRow then r1c = r1c + 1; cachedR1[r1c] = f else r2c = r2c + 1; cachedR2[r2c] = f end end
                local w1, h1, gap = cfgE.row1Width, cfgE.row1Height, cfgE.iconGap; local totalW1 = (r1c * w1) + math.max(0, (r1c - 1) * gap); local startX1 = -(totalW1 / 2) + (w1 / 2)
                eViewer:SetSize(math.max(1, totalW1), math.max(1, h1)); if targetAnchor and targetAnchor.mover then targetAnchor.mover:SetSize(eViewer:GetSize()) end
                for i = 1, r1c do local f = cachedR1[i]; f:ClearAllPoints(); f:SetPoint("CENTER", eViewer, "CENTER", startX1 + (i - 1) * (w1 + gap), 0); f:SetSize(w1, h1); if f.Icon then CDMod.ApplyTexCoord(f.Icon.Icon or f.Icon, w1, h1) end; SuppressDebuffBorder(f); self:ApplyText(f, "Essential", 1); self:ApplySwipeSettings(f) end
                
                -- 【修复笔误】：这里将 r2Anchor 吸附到它的移动把手(mover)上，而不是吸附自己！
                local r2Anchor = _G["WishFlex_Anchor_EssentialR2"]
                WeldToMover(r2Anchor, r2Anchor.mover)
                
                local w2, h2, gap2 = cfgE.row2Width, cfgE.row2Height, cfgE.row2IconGap or 2; local totalW2 = (r2c * w2) + math.max(0, (r2c - 1) * gap2); local startX2 = -(totalW2 / 2) + (w2 / 2)
                r2Anchor:SetSize(math.max(1, totalW2), math.max(1, h2)); if r2Anchor.mover then r2Anchor.mover:SetSize(r2Anchor:GetSize()) end
                for i = 1, r2c do local f = cachedR2[i]; f:ClearAllPoints(); f:SetPoint("CENTER", r2Anchor, "CENTER", startX2 + (i - 1) * (w2 + gap2), 0); f:SetSize(w2, h2); if f.Icon then CDMod.ApplyTexCoord(f.Icon.Icon or f.Icon, w2, h2) end; SuppressDebuffBorder(f); self:ApplyText(f, "Essential", 2); self:ApplySwipeSettings(f) end
            end
        end
    end
end

local function InitCooldownCustom()
    if not WF.db.cooldownCustom then WF.db.cooldownCustom = {} end
    for k, v in pairs(DefaultConfig) do if WF.db.cooldownCustom[k] == nil then WF.db.cooldownCustom[k] = v end end
    for _, k in ipairs({"Essential", "Utility", "BuffBar", "BuffIcon"}) do for subK, subV in pairs(DefaultConfig[k]) do if WF.db.cooldownCustom[k][subK] == nil then WF.db.cooldownCustom[k][subK] = subV end end end
    if not WF.db.cooldownCustom.enable then return end
    
    -- 【原生EditMode 独立锚点系统创建】
    local anchors = {
        { name = "WishFlex_Anchor_Utility", title = "冷却：功能型法术", point = {"CENTER", UIParent, "CENTER", 0, -100} },
        { name = "WishFlex_Anchor_Essential", title = "冷却：核心/爆发", point = {"CENTER", UIParent, "CENTER", 0, 50} },
        { name = "WishFlex_Anchor_EssentialR2", title = "冷却：核心第2排", point = {"TOP", UIParent, "CENTER", 0, 0} },
        { name = "WishFlex_Anchor_BuffIcon", title = "冷却：增益图标", point = {"BOTTOM", UIParent, "CENTER", 0, 100} },
        { name = "WishFlex_Anchor_BuffBar", title = "冷却：增益条", point = {"CENTER", UIParent, "CENTER", 0, 150} }
    }
    for _, a in ipairs(anchors) do
        local frame = CreateFrame("Frame", a.name, UIParent)
        WF:CreateMover(frame, a.name.."Mover", a.point, 45, 45, a.title)
    end

    -- 强制将核心冷却第2排的把手停靠在第一排的把手下方
    _G["WishFlex_Anchor_EssentialR2Mover"]:ClearAllPoints()
    _G["WishFlex_Anchor_EssentialR2Mover"]:SetPoint("TOP", _G["WishFlex_Anchor_EssentialMover"], "BOTTOM", 0, -2)

    -- 发光挂钩
    local isHookingGlow = false
    if LCG then
        local function ApplyCustomGlow(frame, drawLayer)
            local cfg = WF.db.cooldownCustom; if not cfg.glowEnable then return end
            local c = cfg.glowColor or {r=1, g=1, b=1, a=1}; local colorArr = cfg.glowUseCustomColor and {c.r, c.g, c.b, c.a} or nil; local t = cfg.glowType or "pixel"
            if t == "pixel" then local len = cfg.glowPixelLength; if len == 0 then len = nil end; LCG.PixelGlow_Start(frame, colorArr, cfg.glowPixelLines, cfg.glowPixelFrequency, len, cfg.glowPixelThickness, cfg.glowPixelXOffset, cfg.glowPixelYOffset, false, "WishEssentialGlow", drawLayer)
            elseif t == "autocast" then LCG.AutoCastGlow_Start(frame, colorArr, cfg.glowAutocastParticles, cfg.glowAutocastFrequency, cfg.glowAutocastScale, cfg.glowAutocastXOffset, cfg.glowAutocastYOffset, "WishEssentialGlow", drawLayer)
            elseif t == "button" then local freq = cfg.glowButtonFrequency; if freq == 0 then freq = nil end; LCG.ButtonGlow_Start(frame, colorArr, freq)
            elseif t == "proc" then LCG.ProcGlow_Start(frame, {color = colorArr, duration = cfg.glowProcDuration, xOffset = cfg.glowProcXOffset, yOffset = cfg.glowProcYOffset, key = "WishEssentialGlow", frameLevel = drawLayer}) end
        end
        hooksecurefunc(LCG, "PixelGlow_Start", function(frame, color, lines, frequency, length, thickness, xOffset, yOffset, drawLayer, key)
            if isHookingGlow or not frame or key == "WishEssentialGlow" then return end
            if GetKeyFromFrame(frame) == "Essential" then isHookingGlow = true; LCG.PixelGlow_Stop(frame, key); ApplyCustomGlow(frame, drawLayer); isHookingGlow = false end
        end)
        hooksecurefunc(LCG, "PixelGlow_Stop", function(frame, key)
            if isHookingGlow or key == "WishEssentialGlow" or not frame then return end
            if GetKeyFromFrame(frame) == "Essential" then isHookingGlow = true; LCG.PixelGlow_Stop(frame, "WishEssentialGlow"); LCG.AutoCastGlow_Stop(frame, "WishEssentialGlow"); LCG.ButtonGlow_Stop(frame); LCG.ProcGlow_Stop(frame, "WishEssentialGlow"); isHookingGlow = false end
        end)
    end

    local function EventTrigger() CDMod:MarkLayoutDirty() end
    local mixins = { {"BuffIcon", _G.CooldownViewerBuffIconItemMixin}, {"Essential", _G.CooldownViewerEssentialItemMixin}, {"Utility", _G.CooldownViewerUtilityItemMixin}, {"BuffBar", _G.CooldownViewerBuffBarItemMixin} }
    for _, data in ipairs(mixins) do local cat, mixin = data[1], data[2]; if mixin then if mixin.OnCooldownIDSet then hooksecurefunc(mixin, "OnCooldownIDSet", function(frame) CDMod:ImmediateStyleFrame(frame, cat); EventTrigger() end) end; if mixin.OnActiveStateChanged then hooksecurefunc(mixin, "OnActiveStateChanged", function(frame) CDMod:ImmediateStyleFrame(frame, cat); EventTrigger() end) end end end
    local viewers = { EssentialCooldownViewer = "Essential", UtilityCooldownViewer = "Utility", BuffIconCooldownViewer = "BuffIcon", BuffBarCooldownViewer = "BuffBar" }
    for vName, cat in pairs(viewers) do local v = _G[vName]; if v then if v.OnAcquireItemFrame then hooksecurefunc(v, "OnAcquireItemFrame", function(_, frame) CDMod:ImmediateStyleFrame(frame, cat); EventTrigger() end) end; if v.Layout then hooksecurefunc(v, "Layout", EventTrigger) end; if v.UpdateLayout then hooksecurefunc(v, "UpdateLayout", EventTrigger) end end end
    CDMod:MarkLayoutDirty()
end
WF:RegisterModule("cooldownCustom", L["Cooldown Custom"] or "冷却管理器", InitCooldownCustom)