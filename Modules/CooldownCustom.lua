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

local GrowthOptionsVertical = { {text="向下排列 (DOWN)", value="DOWN"}, {text="向上排列 (UP)", value="UP"} }
local BarAlignOptions = { {text="居中对齐", value="CENTER"}, {text="顶部对齐", value="TOP"}, {text="底部对齐", value="BOTTOM"} }

local DefaultConfig = {
    enable = true, countFont = "Expressway", countFontOutline = "OUTLINE", countFontColor = DEFAULT_STACK_COLOR,
    swipeColor = DEFAULT_SWIPE_COLOR, activeAuraColor = DEFAULT_ACTIVE_AURA_COLOR, reverseSwipe = true,
    Utility = { attachToPlayer = false, attachX = 0, attachY = 1, width = 45, height = 30, iconGap = 2, growth = "CENTER_HORIZONTAL", cdFontSize = 18, cdFontColor = DEFAULT_CD_COLOR, cdPosition = "CENTER", cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackPosition = "BOTTOMRIGHT", stackXOffset = 0, stackYOffset = 0 },
    BuffBar = { width = 150, height = 24, barHeight = 24, barTexture = "Blizzard", barPosition = "CENTER", iconGap = 2, growth = "DOWN", cdFontSize = 18, cdFontColor = DEFAULT_CD_COLOR, cdPosition = "RIGHT", cdXOffset = -5, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackPosition = "LEFT", stackXOffset = 5, stackYOffset = 0 },
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
        local top = CreateBorderTex(border, "OVERLAY", 7); top:SetColorTexture(0, 0, 0, 1); top:SetPoint("TOPLEFT", border, "TOPLEFT", 0, 0); top:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, 0); top:SetHeight(m)
        local bottom = CreateBorderTex(border, "OVERLAY", 7); bottom:SetColorTexture(0, 0, 0, 1); bottom:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, 0); bottom:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, 0); bottom:SetHeight(m)
        local left = CreateBorderTex(border, "OVERLAY", 7); left:SetColorTexture(0, 0, 0, 1); left:SetPoint("TOPLEFT", border, "TOPLEFT", 0, -m); left:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, m); left:SetWidth(m)
        local right = CreateBorderTex(border, "OVERLAY", 7); right:SetColorTexture(0, 0, 0, 1); right:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, -m); right:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, m); right:SetWidth(m)
        frame.wishBorder = border
    end
    if frame.Icon then
        local tex = frame.Icon.Icon or frame.Icon
        if type(tex) == "table" and tex.SetDrawLayer then tex:SetDrawLayer("ARTWORK", 1) end
    end
end

local function WeldToMover(frame, anchorFrame)
    if frame and anchorFrame then frame:ClearAllPoints(); frame:SetPoint("CENTER", anchorFrame, "CENTER") end
end

local BURST_THROTTLE = 0.033; local WATCHDOG_THROTTLE = 0.25; local BURST_TICKS = 5; local IDLE_DISABLE_SEC = 2.0
local layoutEngine = CreateFrame("Frame"); local engineEnabled = false; local layoutDirty = true
local burstTicksRemaining = 0; local lastActivityTime = 0; local nextUpdateTime = 0; local lastLayoutHash = ""

function CDMod:MarkLayoutDirty()
    layoutDirty = true; burstTicksRemaining = BURST_TICKS; lastActivityTime = GetTime(); nextUpdateTime = 0
    if not engineEnabled then layoutEngine:SetScript("OnUpdate", self.OnUpdateEngine); engineEnabled = true end
end
WF.TriggerCooldownLayout = function() CDMod:MarkLayoutDirty() end

local function GetLayoutStateHash()
    local hash = ""; local viewers = { _G.UtilityCooldownViewer, _G.EssentialCooldownViewer, _G.BuffIconCooldownViewer, _G.BuffBarCooldownViewer }
    for _, viewer in ipairs(viewers) do if viewer and viewer.itemFramePool then local c = 0; for f in viewer.itemFramePool:EnumerateActive() do if f:IsShown() then local sid = (f.cooldownInfo and f.cooldownInfo.spellID) or 0; local idx = f.layoutIndex or 0; local hidden = f._wishFlexHidden and 1 or 0; hash = hash .. sid .. ":" .. idx .. ":" .. hidden .. "|"; c = c + 1 end end; hash = hash .. "C:" .. c .. "|" end end
    return hash
end

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

local function ApplySpellOverrides(frame)
    if not frame then return end
    local info = frame.cooldownInfo or (frame.GetCooldownInfo and frame:GetCooldownInfo())
    local sid = info and (info.overrideSpellID or info.spellID)
    if not sid then return end
    
    local spellDb = WF.db.cooldownCustom and WF.db.cooldownCustom.spellOverrides and WF.db.cooldownCustom.spellOverrides[tostring(sid)]
    local iconObj = frame.Icon and (frame.Icon.Icon or frame.Icon)
    
    if spellDb then
        if spellDb.customIcon and spellDb.customIcon ~= "" and iconObj and iconObj.SetTexture then iconObj:SetTexture(tonumber(spellDb.customIcon) or spellDb.customIcon) end
        if spellDb.glow then
            local r, g, b, a = 1, 0.95, 0.57, 1
            if spellDb.glowColor then r, g, b, a = spellDb.glowColor.r, spellDb.glowColor.g, spellDb.glowColor.b, 1 end
            if LCG then LCG.PixelGlow_Start(iconObj, {r, g, b, a}, 8, 0.25, 8, 2) end
        else
            if LCG then LCG.PixelGlow_Stop(iconObj) end
        end
    else
        if LCG then LCG.PixelGlow_Stop(iconObj) end
    end
end

function CDMod:BuildHiddenCache()
    wipe(self.hiddenAuras)
    local playerClass = select(2, UnitClass("player"))
    if _G.WishFlexDB and _G.WishFlexDB.global and _G.WishFlexDB.global.spellDB then 
        local spellDB = _G.WishFlexDB.global.spellDB
        for k, v in pairs(spellDB) do 
            if type(v) == "table" and v.hideOriginal ~= false then 
                if not v.class or v.class == "ALL" or v.class == playerClass then 
                    local sid = tonumber(k); local bid = v.buffID or sid; 
                    if sid then self.hiddenAuras[sid] = true end; if bid then self.hiddenAuras[bid] = true end 
                end 
            end 
        end 
    end
    if WF.db and WF.db.wishMonitor then
        if WF.db.wishMonitor.skills then for idStr, cfg in pairs(WF.db.wishMonitor.skills) do if cfg.enable and cfg.hideOriginal then self.hiddenAuras[tonumber(idStr)] = true end end end
        if WF.db.wishMonitor.buffs then for idStr, cfg in pairs(WF.db.wishMonitor.buffs) do if cfg.enable and cfg.hideOriginal then self.hiddenAuras[tonumber(idStr)] = true end end end
    end
end

local function ShouldHideFrame(info)
    if not info then return false end
    if IsSafeValue(info.spellID) then 
        local overrideDb = WF.db.cooldownCustom and WF.db.cooldownCustom.spellOverrides and WF.db.cooldownCustom.spellOverrides[tostring(info.spellID)]
        if overrideDb and overrideDb.hide then return true end
        if CDMod.hiddenAuras[info.spellID] or CDMod.hiddenAuras[info.overrideSpellID] then return true end
        local baseID = GetBaseSpellFast(info.spellID); if baseID and CDMod.hiddenAuras[baseID] then return true end 
    end
    if info.linkedSpellIDs then for i = 1, #info.linkedSpellIDs do local lid = info.linkedSpellIDs[i]; if IsSafeValue(lid) and CDMod.hiddenAuras[lid] then return true end end end
    return false
end

local function PhysicalHideFrame(frame) if not frame then return end; frame:SetAlpha(0); if frame.Icon then frame.Icon:SetAlpha(0) end; frame:EnableMouse(false); frame:ClearAllPoints(); frame:SetPoint("CENTER", UIParent, "CENTER", -5000, 0); frame._wishFlexHidden = true end

local function SetupFrameGlow(frame)
    if not frame then return end
    if frame.SpellActivationAlert and not frame._wf_glowHooked then
        frame._wf_glowHooked = true
        frame.SpellActivationAlert:SetAlpha(0) 
        hooksecurefunc(frame.SpellActivationAlert, "Show", function(self) self:SetAlpha(0); if WF.GlowAPI then WF.GlowAPI:Show(frame) end end)
        hooksecurefunc(frame.SpellActivationAlert, "Hide", function(self) if WF.GlowAPI then WF.GlowAPI:Hide(frame) end end)
        if frame.SpellActivationAlert:IsShown() then if WF.GlowAPI then WF.GlowAPI:Show(frame) end end
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

local function GetSortVal(f)
    local info = f.cooldownInfo or (f.GetCooldownInfo and f:GetCooldownInfo())
    local sid = info and (info.overrideSpellID or info.spellID)
    if sid then
        local db = WF.db.cooldownCustom
        if db and db.spellOverrides and db.spellOverrides[tostring(sid)] and db.spellOverrides[tostring(sid)].sortIndex then
            return db.spellOverrides[tostring(sid)].sortIndex
        end
    end
    return f.layoutIndex or 999
end
local function SortByLayoutIndex(a, b) return GetSortVal(a) < GetSortVal(b) end

local function StaticUpdateSwipeColor(self) 
    local b = self:GetParent(); local cddb = WF.db.cooldownCustom; 
    if b and b.wasSetFromAura then local ac = cddb.activeAuraColor or DEFAULT_ACTIVE_AURA_COLOR; self:SetSwipeColor(ac.r, ac.g, ac.b, ac.a) else local sc = cddb.swipeColor or DEFAULT_SWIPE_COLOR; self:SetSwipeColor(sc.r, sc.g, sc.b, sc.a) end 
end

function CDMod:ApplySwipeSettings(frame) 
    if not frame or not frame.Cooldown then return end
    local db = WF.db.cooldownCustom; local rev = db.reverseSwipe; if rev == nil then rev = true end
    frame.Cooldown:SetReverse(rev); frame.Cooldown:SetDrawEdge(false); frame.Cooldown:SetDrawBling(false); frame.Cooldown:SetUseCircularEdge(false); frame.Cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8x8")
    local anchor = (frame.Icon and (frame.Icon.Icon or frame.Icon)) or frame
    frame.Cooldown:ClearAllPoints(); frame.Cooldown:SetAllPoints(anchor); frame.Cooldown:SetFrameLevel(frame:GetFrameLevel() + 2)

    if not frame.Cooldown._wishSwipeHooked then 
        hooksecurefunc(frame.Cooldown, "SetCooldown", StaticUpdateSwipeColor)
        if frame.Cooldown.SetCooldownFromDurationObject then hooksecurefunc(frame.Cooldown, "SetCooldownFromDurationObject", StaticUpdateSwipeColor) end
        frame.Cooldown._wishSwipeHooked = true 
    end
    if frame.wasSetFromAura then local ac = db.activeAuraColor or DEFAULT_ACTIVE_AURA_COLOR; frame.Cooldown:SetSwipeColor(ac.r, ac.g, ac.b, ac.a) else local sc = db.swipeColor or DEFAULT_SWIPE_COLOR; frame.Cooldown:SetSwipeColor(sc.r, sc.g, sc.b, sc.a) end 
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

local function ApplyBarAlignment(f, cfg, w, h, barH, gap)
    local barPos = cfg.barPosition or "CENTER"
    f.Icon:ClearAllPoints(); f.Bar:ClearAllPoints()
    f.Icon:SetSize(h, h); f.Bar:SetSize(math.max(1, w - h - gap), barH)
    
    if barPos == "TOP" then
        f.Icon:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        f.Bar:SetPoint("TOPLEFT", f.Icon, "TOPRIGHT", gap, 0)
    elseif barPos == "BOTTOM" then
        f.Icon:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        f.Bar:SetPoint("BOTTOMLEFT", f.Icon, "BOTTOMRIGHT", gap, 0)
    else
        f.Icon:SetPoint("LEFT", f, "LEFT", 0, 0)
        f.Bar:SetPoint("LEFT", f.Icon, "RIGHT", gap, 0)
    end
end

function CDMod:ImmediateStyleFrame(frame, category)
    if not frame then return end
    if (category == "BuffIcon" or category == "BuffBar") and ShouldHideFrame(frame.cooldownInfo) then PhysicalHideFrame(frame); return end
    if frame._wishFlexHidden then frame._wishFlexHidden = false; frame:SetAlpha(1); if frame.Icon then frame.Icon:SetAlpha(1) end; frame:EnableMouse(true) end
    SuppressDebuffBorder(frame); self:ApplyText(frame, category, 1); self:ApplySwipeSettings(frame)
    local db = WF.db.cooldownCustom; local cfg = db[category]
    if cfg then 
        local w = PixelSnap(cfg.width or cfg.row1Width or 45); local h = PixelSnap(cfg.height or cfg.row1Height or 45)
        local barH = PixelSnap(cfg.barHeight or h)
        frame:SetSize(w, math.max(h, barH)); 
        if frame.Icon then 
            local iconObj = frame.Icon.Icon or frame.Icon; CDMod.ApplyTexCoord(iconObj, w, h); 
            if frame.Bar then 
                local gap = PixelSnap(cfg.iconGap or 2)
                ApplyBarAlignment(frame, cfg, w, h, barH, gap)
                local texPath = nil
                if cfg.barTexture and LSM then texPath = LSM:Fetch("statusbar", cfg.barTexture) end
                if not texPath then texPath = "Interface\\TargetingFrame\\UI-StatusBar" end
                if frame.Bar.SetStatusBarTexture then frame.Bar:SetStatusBarTexture(texPath) elseif frame.Bar.SetTexture then frame.Bar:SetTexture(texPath) end
            else
                frame.Icon:ClearAllPoints(); frame.Icon:SetAllPoints() 
            end 
        end 
    end
    AddElvUIBorder(frame); SetupFrameGlow(frame); ApplySpellOverrides(frame)
end

local cachedIcons = {}; local cachedR1 = {}; local cachedR2 = {}
local function DoLayoutBuffs(viewerName, key, isVertical)
    local db = WF.db.cooldownCustom; local container = _G[viewerName]; if not container or not container:IsShown() then return end
    local targetAnchor = _G["WishFlex_Anchor_"..key]; if targetAnchor then WeldToMover(container, targetAnchor) end
    
    wipe(cachedIcons); local count = 0
    if container.itemFramePool then for f in container.itemFramePool:EnumerateActive() do if f:IsShown() then if ShouldHideFrame(f.cooldownInfo) then PhysicalHideFrame(f) else if f._wishFlexHidden then f._wishFlexHidden = false; f:SetAlpha(1); if f.Icon then f.Icon:SetAlpha(1) end; f:EnableMouse(true) end; count = count + 1; cachedIcons[count] = f; SuppressDebuffBorder(f); CDMod:ApplyText(f, key); CDMod:ApplySwipeSettings(f); ApplySpellOverrides(f) end end end end 
    if count == 0 then return end; table.sort(cachedIcons, SortByLayoutIndex)
    
    local cfg = db[key]; local w = PixelSnap(cfg.width or 45); local h = PixelSnap(cfg.height or 45); local gap = PixelSnap(cfg.iconGap or 2); local growth = cfg.growth or (isVertical and "DOWN" or "CENTER_HORIZONTAL")
    local barH = PixelSnap(cfg.barHeight or h)
    local itemH = math.max(h, barH)
    
    local totalW = (count * w) + math.max(0, (count - 1) * gap); local totalH = (count * itemH) + math.max(0, (count - 1) * gap)
    container:SetSize(math.max(1, isVertical and w or totalW), math.max(1, isVertical and totalH or itemH))
    if targetAnchor then targetAnchor:SetSize(container:GetSize()); if targetAnchor.mover then targetAnchor.mover:SetSize(targetAnchor:GetSize()) end end

    if isVertical then
        local startY = (totalH / 2) - (itemH / 2)
        for i = 1, count do 
            local f = cachedIcons[i]; f:ClearAllPoints(); f:SetSize(w, itemH); 
            if growth == "UP" then f:SetPoint("CENTER", container, "CENTER", 0, -startY + (i - 1) * (itemH + gap)) else f:SetPoint("CENTER", container, "CENTER", 0, startY - (i - 1) * (itemH + gap)) end
            if f.Icon then 
                local iconObj = f.Icon.Icon or f.Icon
                if not f.Bar then 
                    f.Icon:ClearAllPoints(); f.Icon:SetAllPoints(); CDMod.ApplyTexCoord(iconObj, w, h) 
                else 
                    ApplyBarAlignment(f, cfg, w, h, barH, gap); if iconObj then CDMod.ApplyTexCoord(iconObj, h, h) end
                    local texPath = nil; if cfg.barTexture and LSM then texPath = LSM:Fetch("statusbar", cfg.barTexture) end; if not texPath then texPath = "Interface\\TargetingFrame\\UI-StatusBar" end
                    if f.Bar.SetStatusBarTexture then f.Bar:SetStatusBarTexture(texPath) elseif f.Bar.SetTexture then f.Bar:SetTexture(texPath) end 
                end 
            end
            AddElvUIBorder(f) 
        end
    else
        local startX = -(totalW / 2) + (w / 2)
        for i = 1, count do 
            local f = cachedIcons[i]; f:ClearAllPoints(); f:SetSize(w, itemH); 
            if growth == "LEFT" then f:SetPoint("CENTER", container, "CENTER", -startX - (i - 1) * (w + gap), 0) elseif growth == "RIGHT" then f:SetPoint("CENTER", container, "CENTER", startX + (i - 1) * (w + gap), 0) else f:SetPoint("CENTER", container, "CENTER", startX + (i - 1) * (w + gap), 0) end; 
            if f.Icon then 
                local iconObj = f.Icon.Icon or f.Icon
                if not f.Bar then 
                    f.Icon:ClearAllPoints(); f.Icon:SetAllPoints(); CDMod.ApplyTexCoord(iconObj, w, h) 
                else 
                    ApplyBarAlignment(f, cfg, w, h, barH, gap); if iconObj then CDMod.ApplyTexCoord(iconObj, h, h) end
                    local texPath = nil; if cfg.barTexture and LSM then texPath = LSM:Fetch("statusbar", cfg.barTexture) end; if not texPath then texPath = "Interface\\TargetingFrame\\UI-StatusBar" end
                    if f.Bar.SetStatusBarTexture then f.Bar:SetStatusBarTexture(texPath) elseif f.Bar.SetTexture then f.Bar:SetTexture(texPath) end 
                end 
            end
            AddElvUIBorder(f) 
        end
    end
    container:Show(); container:SetAlpha(1)
end

function CDMod:ForceBuffsLayout() DoLayoutBuffs("BuffIconCooldownViewer", "BuffIcon", false); DoLayoutBuffs("BuffBarCooldownViewer", "BuffBar", true) end

function CDMod:UpdateAllLayouts()
    local db = WF.db.cooldownCustom
    local r1Mover = _G["WishFlex_Anchor_EssentialMover"]; local r2Mover = _G["WishFlex_Anchor_EssentialR2Mover"]
    if r1Mover and r2Mover then r2Mover:ClearAllPoints(); r2Mover:SetPoint("TOP", r1Mover, "BOTTOM", 0, -(db.Essential.rowYGap or 2)) end

    local catFrames = { Essential = {}, Utility = {} }
    
    local function GatherFrames(viewer, defCat)
        if not viewer or not viewer.itemFramePool then return end
        for f in viewer.itemFramePool:EnumerateActive() do 
            if f:IsShown() then 
                local info = f.cooldownInfo or (f.GetCooldownInfo and f:GetCooldownInfo())
                local sid = info and (info.overrideSpellID or info.spellID)
                local tCat = defCat
                if sid and db.spellOverrides and db.spellOverrides[tostring(sid)] and db.spellOverrides[tostring(sid)].category then
                    local oCat = db.spellOverrides[tostring(sid)].category
                    if (defCat == "Essential" or defCat == "Utility") and (oCat == "Essential" or oCat == "Utility") then 
                        tCat = oCat 
                    end
                end
                
                if ShouldHideFrame(info) then 
                    PhysicalHideFrame(f) 
                else 
                    f:Show(); f:SetAlpha(1); 
                    if f._wishFlexHidden then f._wishFlexHidden = false; if f.Icon then f.Icon:SetAlpha(1) end; f:EnableMouse(true) end
                    SuppressDebuffBorder(f); self:ApplyText(f, tCat, 1); self:ApplySwipeSettings(f); SetupFrameGlow(f); ApplySpellOverrides(f)
                    table.insert(catFrames[tCat], f) 
                end
            end 
        end
    end
    GatherFrames(_G.UtilityCooldownViewer, "Utility")
    GatherFrames(_G.EssentialCooldownViewer, "Essential")

    local uViewer = _G.UtilityCooldownViewer
    if uViewer then
        local uFrames = catFrames.Utility
        local count = #uFrames
        local cfg = db.Utility
        local targetAnchor = _G["WishFlex_Anchor_Utility"]; local attachToPlayer = cfg.attachToPlayer
        if not attachToPlayer and targetAnchor then WeldToMover(uViewer, targetAnchor) end
        
        if count > 0 then
            table.sort(uFrames, SortByLayoutIndex)
            local w = PixelSnap(cfg.width or 45); local h = PixelSnap(cfg.height or 30); local gap = PixelSnap(cfg.iconGap or 2)
            local growth = attachToPlayer and "LEFT" or (cfg.growth or "CENTER_HORIZONTAL"); local totalW = (count * w) + math.max(0, (count - 1) * gap)
            uViewer:SetSize(math.max(1, totalW), math.max(1, h))
            if not attachToPlayer and targetAnchor then targetAnchor:SetSize(uViewer:GetSize()); if targetAnchor.mover then targetAnchor.mover:SetSize(targetAnchor:GetSize()) end end

            local anchorFrame = nil
            if attachToPlayer then if _G.ElvUF_Player then anchorFrame = _G.ElvUF_Player.backdrop or _G.ElvUF_Player elseif _G.PlayerFrame then anchorFrame = _G.PlayerFrame end end

            if attachToPlayer and anchorFrame then
                uViewer:ClearAllPoints(); uViewer:SetPoint("BOTTOMRIGHT", anchorFrame, "TOPRIGHT", cfg.attachX or 0, cfg.attachY or 1)
                for i = 1, count do local f = uFrames[i]; f:ClearAllPoints(); f:SetParent(uViewer); f:SetSize(w, h); f:SetPoint("RIGHT", uViewer, "RIGHT", -((i - 1) * (w + gap)), 0); if f.Icon then f.Icon:ClearAllPoints(); f.Icon:SetAllPoints(); CDMod.ApplyTexCoord(f.Icon.Icon or f.Icon, w, h) end; AddElvUIBorder(f) end
            else
                local startX = -(totalW / 2) + (w / 2)
                for i = 1, count do local f = uFrames[i]; f:ClearAllPoints(); f:SetParent(uViewer); f:SetSize(w, h); if growth == "LEFT" then f:SetPoint("CENTER", uViewer, "CENTER", -startX - (i - 1) * (w + gap), 0) elseif growth == "RIGHT" then f:SetPoint("CENTER", uViewer, "CENTER", startX + (i - 1) * (w + gap), 0) else f:SetPoint("CENTER", uViewer, "CENTER", startX + (i - 1) * (w + gap), 0) end; if f.Icon then f.Icon:ClearAllPoints(); f.Icon:SetAllPoints(); CDMod.ApplyTexCoord(f.Icon.Icon or f.Icon, w, h) end; AddElvUIBorder(f) end
            end
            uViewer:Show(); uViewer:SetAlpha(1)
        else
            uViewer:Hide()
        end
    end

    local eViewer = _G.EssentialCooldownViewer
    if eViewer then
        local eFrames = catFrames.Essential
        local count = #eFrames
        local targetAnchor = _G["WishFlex_Anchor_Essential"]; if targetAnchor then WeldToMover(eViewer, targetAnchor) end
        
        if count > 0 then
            table.sort(eFrames, SortByLayoutIndex); local cfgE = db.Essential
            if cfgE.enableCustomLayout then
                wipe(cachedR1); wipe(cachedR2); local r1c, r2c = 0, 0
                for i = 1, count do local f = eFrames[i]; if i <= cfgE.maxPerRow then r1c = r1c + 1; cachedR1[r1c] = f else r2c = r2c + 1; cachedR2[r2c] = f end end
                local w1 = PixelSnap(cfgE.row1Width or 45); local h1 = PixelSnap(cfgE.row1Height or 45); local gap = PixelSnap(cfgE.iconGap or 2)
                local totalW1 = (r1c * w1) + math.max(0, (r1c - 1) * gap); local startX1 = -(totalW1 / 2) + (w1 / 2)
                eViewer:SetSize(math.max(1, totalW1), math.max(1, h1)); if targetAnchor then targetAnchor:SetSize(math.max(1, totalW1), math.max(1, h1)); if targetAnchor.mover then targetAnchor.mover:SetSize(targetAnchor:GetSize()) end end

                for i = 1, r1c do 
                    local f = cachedR1[i]; f:ClearAllPoints(); f:SetParent(eViewer)
                    local xOff = startX1 + (i - 1) * (w1 + gap); if targetAnchor then f:SetPoint("CENTER", targetAnchor, "CENTER", xOff, 0) else f:SetPoint("CENTER", eViewer, "CENTER", xOff, 0) end
                    f:SetSize(w1, h1); if f.Icon then f.Icon:ClearAllPoints(); f.Icon:SetAllPoints(); CDMod.ApplyTexCoord(f.Icon.Icon or f.Icon, w1, h1) end; SuppressDebuffBorder(f); self:ApplyText(f, "Essential", 1); self:ApplySwipeSettings(f); AddElvUIBorder(f); SetupFrameGlow(f)
                end
                
                local r2Anchor = _G["WishFlex_Anchor_EssentialR2"]
                if r2Anchor then
                    WeldToMover(r2Anchor, r2Anchor.mover)
                    local w2 = PixelSnap(cfgE.row2Width or 40); local h2 = PixelSnap(cfgE.row2Height or 40); local gap2 = PixelSnap(cfgE.row2IconGap or 2)
                    local totalW2 = (r2c * w2) + math.max(0, (r2c - 1) * gap2); local startX2 = -(totalW2 / 2) + (w2 / 2)
                    r2Anchor:SetSize(math.max(1, totalW2), math.max(1, h2)); if r2Anchor.mover then r2Anchor.mover:SetSize(r2Anchor:GetSize()) end
                    for i = 1, r2c do 
                        local f = cachedR2[i]; f:ClearAllPoints(); f:SetParent(r2Anchor); f:SetPoint("CENTER", r2Anchor, "CENTER", startX2 + (i - 1) * (w2 + gap2), 0); f:SetSize(w2, h2); 
                        if f.Icon then f.Icon:ClearAllPoints(); f.Icon:SetAllPoints(); CDMod.ApplyTexCoord(f.Icon.Icon or f.Icon, w2, h2) end; SuppressDebuffBorder(f); self:ApplyText(f, "Essential", 2); self:ApplySwipeSettings(f); AddElvUIBorder(f); SetupFrameGlow(f)
                    end
                end
            end
            eViewer:Show(); eViewer:SetAlpha(1)
        else
            eViewer:Hide()
        end
    end
end

local function InitCooldownCustom()
    if not WF.db.cooldownCustom then WF.db.cooldownCustom = {} end
    for k, v in pairs(DefaultConfig) do if WF.db.cooldownCustom[k] == nil then WF.db.cooldownCustom[k] = v end end
    for _, k in ipairs({"Essential", "Utility", "BuffBar", "BuffIcon"}) do for subK, subV in pairs(DefaultConfig[k]) do if WF.db.cooldownCustom[k][subK] == nil then WF.db.cooldownCustom[k][subK] = subV end end end
    if not WF.db.cooldownCustom.enable then return end
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
        local mover = _G[a.name.."Mover"]
        if mover then
            if WF.db.movers[a.name.."Mover"] then local p = WF.db.movers[a.name.."Mover"]; mover:ClearAllPoints(); mover:SetPoint(p.point, UIParent, p.relativePoint, p.xOfs, p.yOfs) end
            if not mover._wishSaveHooked then
                mover:HookScript("OnDragStop", function(self) local point, _, relativePoint, xOfs, yOfs = self:GetPoint(); WF.db.movers[self:GetName()] = { point = point, relativePoint = relativePoint, xOfs = xOfs, yOfs = yOfs } end)
                mover._wishSaveHooked = true
            end
        end
    end

    _G["WishFlex_Anchor_EssentialR2Mover"]:ClearAllPoints()
    _G["WishFlex_Anchor_EssentialR2Mover"]:SetPoint("TOP", _G["WishFlex_Anchor_EssentialMover"], "BOTTOM", 0, -(WF.db.cooldownCustom.Essential.rowYGap or 2))

    local viewers = { EssentialCooldownViewer = "Essential", UtilityCooldownViewer = "Utility", BuffIconCooldownViewer = "BuffIcon", BuffBarCooldownViewer = "BuffBar" }
    for vName, cat in pairs(viewers) do local v = _G[vName]; if v then if v.OnAcquireItemFrame then hooksecurefunc(v, "OnAcquireItemFrame", function(_, frame) CDMod:ImmediateStyleFrame(frame, cat); CDMod:MarkLayoutDirty() end) end; v.UpdateLayout = function() CDMod:MarkLayoutDirty() end; v.Layout = function() CDMod:MarkLayoutDirty() end end end

    local mixins = { {"BuffIcon", _G.CooldownViewerBuffIconItemMixin}, {"Essential", _G.CooldownViewerEssentialItemMixin}, {"Utility", _G.CooldownViewerUtilityItemMixin}, {"BuffBar", _G.CooldownViewerBuffBarItemMixin} }
    for _, data in ipairs(mixins) do local cat, mixin = data[1], data[2]; if mixin then if mixin.OnCooldownIDSet then hooksecurefunc(mixin, "OnCooldownIDSet", function(frame) CDMod:ImmediateStyleFrame(frame, cat); CDMod:MarkLayoutDirty() end) end; if mixin.OnActiveStateChanged then hooksecurefunc(mixin, "OnActiveStateChanged", function(frame) CDMod:ImmediateStyleFrame(frame, cat); CDMod:MarkLayoutDirty() end) end end end
    CDMod:MarkLayoutDirty()
end
WF:RegisterModule("cooldownCustom", L["Cooldown Custom"] or "冷却管理器", InitCooldownCustom)

-- ========================================================
-- [全新沙盒：极限紧凑排版 + 半透明组落区 + 拖拽全域秒刷 + 发光/褪色整合]
-- ========================================================
if WF.UI then
    CDMod.Sandbox = CDMod.Sandbox or {
        selectedRow = nil,
        selectedSpellForTracker = nil,
        scannedEssential = {}, scannedUtility = {}, scannedBuffIcon = {}, scannedBuffBar = {},
        RenderedLists = {},
        GlowPreviewBtns = {} -- [新增] 用于记录沙盒中用来演示发光的图标
    }

    function CDMod:UpdateSandboxGlows()
        if not WF.GlowAPI then return end
        -- 清理旧发光防止重叠
        if WF.UI.MainScrollChild and WF.UI.MainScrollChild.SandboxIconsPool then
            for _, btn in ipairs(WF.UI.MainScrollChild.SandboxIconsPool) do
                WF.GlowAPI:Hide(btn)
            end
        end
        -- 为每个排版组的第一个代表性图标挂载发光
        if WF.db.glow and WF.db.glow.enable then
            for _, btn in ipairs(CDMod.Sandbox.GlowPreviewBtns or {}) do
                WF.GlowAPI:Show(btn)
            end
        end
    end

    function CDMod:ScanForSandbox()
        wipe(CDMod.Sandbox.scannedEssential)
        wipe(CDMod.Sandbox.scannedUtility)
        wipe(CDMod.Sandbox.scannedBuffIcon)
        wipe(CDMod.Sandbox.scannedBuffBar)
        
        local dbO = WF.db.cooldownCustom and WF.db.cooldownCustom.spellOverrides or {}
        local seen = {}

        local function DoScan(viewer, defCat)
            if not viewer or not viewer.itemFramePool then return end
            for f in viewer.itemFramePool:EnumerateActive() do
                local info = f.cooldownInfo or (f.GetCooldownInfo and f:GetCooldownInfo())
                local spellID = info and (info.overrideSpellID or info.spellID)
                if spellID then
                    local sidStr = tostring(spellID)
                    local tCat = defCat
                    
                    if dbO[sidStr] and dbO[sidStr].category then
                        local oCat = dbO[sidStr].category
                        if (defCat == "Essential" or defCat == "Utility") and (oCat == "Essential" or oCat == "Utility") then 
                            tCat = oCat 
                        end
                    end
                    
                    local domain = (defCat == "Essential" or defCat == "Utility") and "CD" or "BUFF"
                    local uniqueKey = domain .. "_" .. sidStr
                    
                    if not seen[uniqueKey] then
                        seen[uniqueKey] = true
                        
                        local sInfo = nil; pcall(function() sInfo = C_Spell.GetSpellInfo(spellID) end)
                        if sInfo and sInfo.name then 
                            local item = { idStr = sidStr, name = sInfo.name, icon = sInfo.iconID, defaultIdx = f.layoutIndex or 999 }
                            if tCat == "Essential" then table.insert(CDMod.Sandbox.scannedEssential, item)
                            elseif tCat == "Utility" then table.insert(CDMod.Sandbox.scannedUtility, item)
                            elseif tCat == "BuffIcon" then table.insert(CDMod.Sandbox.scannedBuffIcon, item)
                            elseif tCat == "BuffBar" then table.insert(CDMod.Sandbox.scannedBuffBar, item)
                            end
                        end
                    end
                end
            end
        end
        DoScan(_G.EssentialCooldownViewer, "Essential")
        DoScan(_G.UtilityCooldownViewer, "Utility")
        DoScan(_G.BuffIconCooldownViewer, "BuffIcon")
        DoScan(_G.BuffBarCooldownViewer, "BuffBar")
    end

    -- [修改]：彻底移除多余的二级菜单，直接点击“冷却管理器”即可进入可视化沙盒
    WF.UI:RegisterMenu({ id = "Combat", name = L["Combat"] or "战斗组件", type = "root", icon = "Interface\\AddOns\\WishFlex\\Media\\Icons\\zd", order = 10 })
    WF.UI:RegisterMenu({ id = "CDManager", parent = "Combat", name = L["Cooldown Manager"] or "冷却管理器", key = "cooldownCustom_Global", order = 20 })

    local function HandleCDChange(val)
        if WF.TriggerCooldownLayout then WF.TriggerCooldownLayout() end
        if CDMod.DrawSandboxToUI then CDMod:DrawSandboxToUI() end
        if val == "UI_REFRESH" or type(val) == "string" then WF.UI:RefreshCurrentPanel() end
    end

    local function ApplyMockText(btn, dbRef, catCfg, isRow2, isBar)
        local fontPath = (LSM and LSM:Fetch('font', dbRef.countFont)) or STANDARD_TEXT_FONT
        local outline = dbRef.countFontOutline or "OUTLINE"
        local cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY

        if catCfg == dbRef.Essential then
            if isRow2 then 
                cdSize, cdColor, cdPos, cdX, cdY = catCfg.row2CdFontSize, catCfg.row2CdFontColor, catCfg.row2CdPosition, catCfg.row2CdXOffset, catCfg.row2CdYOffset
                stackSize, stackColor, stackPos, stackX, stackY = catCfg.row2StackFontSize, catCfg.row2StackFontColor, catCfg.row2StackPosition, catCfg.row2StackXOffset, catCfg.row2StackYOffset
            else
                cdSize, cdColor, cdPos, cdX, cdY = catCfg.row1CdFontSize, catCfg.row1CdFontColor, catCfg.row1CdPosition, catCfg.row1CdXOffset, catCfg.row1CdYOffset
                stackSize, stackColor, stackPos, stackX, stackY = catCfg.row1StackFontSize, catCfg.row1StackFontColor, catCfg.row1StackPosition, catCfg.row1StackXOffset, catCfg.row1StackYOffset
            end
        else
            cdSize, cdColor, cdPos, cdX, cdY = catCfg.cdFontSize, catCfg.cdFontColor, catCfg.cdPosition, catCfg.cdXOffset, catCfg.cdYOffset
            stackSize, stackColor, stackPos, stackX, stackY = catCfg.stackFontSize, catCfg.stackFontColor, catCfg.stackPosition, catCfg.stackXOffset, catCfg.stackYOffset
        end

        if not btn.mockCd then btn.mockCd = btn:CreateFontString(nil, "OVERLAY", nil, 7) end
        btn.mockCd:SetFont(fontPath, cdSize or 18, outline)
        btn.mockCd:SetTextColor((cdColor and cdColor.r) or 1, (cdColor and cdColor.g) or 0.82, (cdColor and cdColor.b) or 0)
        btn.mockCd:ClearAllPoints()
        if isBar then btn.mockCd:SetPoint(cdPos or "RIGHT", btn, cdPos or "RIGHT", cdX or -5, cdY or 0) else btn.mockCd:SetPoint(cdPos or "CENTER", btn, cdPos or "CENTER", cdX or 0, cdY or 0) end
        btn.mockCd:SetText("12")

        if not btn.mockStack then btn.mockStack = btn:CreateFontString(nil, "OVERLAY", nil, 7) end
        btn.mockStack:SetFont(fontPath, stackSize or 14, outline)
        btn.mockStack:SetTextColor((stackColor and stackColor.r) or 1, (stackColor and stackColor.g) or 1, (stackColor and stackColor.b) or 1)
        btn.mockStack:ClearAllPoints()
        if isBar then btn.mockStack:SetPoint(stackPos or "LEFT", btn.tex, stackPos or "LEFT", stackX or 5, stackY or 0) else btn.mockStack:SetPoint(stackPos or "BOTTOMRIGHT", btn, stackPos or "BOTTOMRIGHT", stackX or 0, stackY or 0) end
        btn.mockStack:SetText("3")
    end

    function CDMod:DrawSandboxToUI(forcedWidth)
        local db = WF.db.cooldownCustom
        local scrollChild = WF.UI.MainScrollChild
        if not scrollChild or not scrollChild.SandboxIconsPool then return end
        
        local canvas = scrollChild.Sandbox_Canvas
        if not canvas then return end
        
        for _, btn in ipairs(scrollChild.SandboxIconsPool) do 
            btn:Hide(); btn:ClearAllPoints(); btn:SetParent(canvas)
        end
        
        if not scrollChild.Sandbox_DropIndicator then
            local ind = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
            ind:SetSize(4, 45)
            local tex = ind:CreateTexture(nil, "OVERLAY")
            tex:SetAllPoints(); tex:SetColorTexture(0, 1, 0, 1)
            ind.tex = tex; ind:Hide()
            scrollChild.Sandbox_DropIndicator = ind
        else
            scrollChild.Sandbox_DropIndicator:SetParent(canvas)
        end
        
        local poolIdx = 1
        local currentMaxWidth = 0 
        wipe(CDMod.Sandbox.GlowPreviewBtns) -- 清空用于发光预览的按钮列表

        local function GetSortedList(catData, mockData)
            local source = (#catData > 0) and catData or mockData
            local sorted = {}; for _, v in ipairs(source) do table.insert(sorted, v) end
            table.sort(sorted, function(a, b)
                local idxA = db.spellOverrides and db.spellOverrides[a.idStr] and db.spellOverrides[a.idStr].sortIndex or a.defaultIdx
                local idxB = db.spellOverrides and db.spellOverrides[b.idStr] and db.spellOverrides[b.idStr].sortIndex or b.defaultIdx
                return idxA < idxB
            end)
            return sorted
        end

        local eList = GetSortedList(CDMod.Sandbox.scannedEssential, {})
        local uList = GetSortedList(CDMod.Sandbox.scannedUtility, {})
        local biList = GetSortedList(CDMod.Sandbox.scannedBuffIcon, {})
        local bbList = GetSortedList(CDMod.Sandbox.scannedBuffBar, {})
        
        CDMod.Sandbox.RenderedLists = { Essential = eList, Utility = uList, BuffIcon = biList, BuffBar = bbList }

        local eR1, eR2 = {}, {}
        local maxR1 = db.Essential.maxPerRow or 7
        for i, v in ipairs(eList) do if i <= maxR1 then table.insert(eR1, v) else table.insert(eR2, v) end end

        local function RenderGroup(list, catCfg, catName, rowID, startY, isRow2)
            local w = catCfg.row1Width or catCfg.width or 45; local h = catCfg.row1Height or catCfg.height or 45; local gap = catCfg.iconGap or 2
            if isRow2 then w = catCfg.row2Width or 40; h = catCfg.row2Height or 40; gap = catCfg.row2IconGap or 2 end
            
            local isVertical = (catName == "BuffBar")
            local barPos = catCfg.barPosition or "CENTER"
            local growth = catCfg.growth or "DOWN"
            local barH = catCfg.barHeight or h
            local itemH = math.max(h, barH)
            
            local count = #list

            local contentW = (count > 0) and (count * w + (count - 1) * gap) or w
            local contentH = (count > 0) and (count * itemH + (count - 1) * gap) or itemH
            
            local bgPadding = 2
            local bgW = isVertical and (w + bgPadding*2) or (contentW + bgPadding*2)
            local bgH = isVertical and (contentH + bgPadding*2) or (itemH + bgPadding*2)

            if not canvas.groupBgs then canvas.groupBgs = {} end
            local bg = canvas.groupBgs[rowID]
            if not bg then
                bg = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
                WF.UI.Factory.ApplyFlatSkin(bg, 0.1, 0.1, 0.1, 0.3, 0.2, 0.2, 0.2, 0.6)
                canvas.groupBgs[rowID] = bg
            end
            bg.catName = catName
            bg.rowID = rowID
            
            local bgTopY = startY + bgPadding
            
            bg:ClearAllPoints()
            bg:SetSize(bgW, bgH)
            bg:SetPoint("TOP", canvas, "TOP", 0, bgTopY)
            bg:Show()

            if bgW > currentMaxWidth then currentMaxWidth = bgW end

            if count == 0 then return isVertical and contentH or itemH end

            local startX = -contentW / 2 + w / 2

            for i = 1, count do
                local item = list[i]

                local btn = scrollChild.SandboxIconsPool[poolIdx]
                if not btn then
                    btn = CreateFrame("Button", nil, canvas, "BackdropTemplate")
                    btn:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
                    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                    
                    local tex = btn:CreateTexture(nil, "BACKGROUND")
                    tex:SetTexCoord(0.1, 0.9, 0.1, 0.9); btn.tex = tex
                    scrollChild.SandboxIconsPool[poolIdx] = btn
                end

                btn.spellID = item.idStr; btn.defaultIdx = item.defaultIdx; btn.catName = catName; btn.rowID = rowID
                btn:SetSize(w, itemH)
                
                if isVertical then
                    local curY = startY - (i - 1) * (itemH + gap)
                    if growth == "UP" then 
                        curY = startY - contentH + itemH + (i - 1) * (itemH + gap) 
                    end
                    btn:ClearAllPoints(); btn:SetPoint("CENTER", canvas, "TOP", 0, curY - itemH/2)
                else
                    btn:ClearAllPoints(); btn:SetPoint("CENTER", canvas, "TOP", startX + (i - 1) * (w + gap), startY - itemH/2)
                end
                
                btn.tex:SetVertexColor(1, 1, 1, 1)
                btn.tex:SetTexture(item.icon)
                
                if catName == "BuffBar" then
                    if not btn.barTex then btn.barTex = btn:CreateTexture(nil, "ARTWORK"); btn.barTex:SetVertexColor(0.2, 0.6, 1, 1) end
                    local texPath = nil
                    if catCfg.barTexture and LSM then texPath = LSM:Fetch("statusbar", catCfg.barTexture) end
                    if not texPath then texPath = "Interface\\TargetingFrame\\UI-StatusBar" end
                    btn.barTex:SetTexture(texPath)
                    
                    btn.tex:ClearAllPoints()
                    btn.barTex:ClearAllPoints()
                    if barPos == "TOP" then
                        btn.tex:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
                        btn.barTex:SetPoint("TOPLEFT", btn.tex, "TOPRIGHT", gap, 0)
                    elseif barPos == "BOTTOM" then
                        btn.tex:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
                        btn.barTex:SetPoint("BOTTOMLEFT", btn.tex, "BOTTOMRIGHT", gap, 0)
                    else
                        btn.tex:SetPoint("LEFT", btn, "LEFT", 0, 0)
                        btn.barTex:SetPoint("LEFT", btn.tex, "RIGHT", gap, 0)
                    end
                    
                    btn.tex:SetSize(h, h)
                    btn.barTex:SetSize(math.max(1, w - h - gap), barH)
                    btn.barTex:Show()
                else
                    if btn.barTex then btn.barTex:Hide() end
                    btn.tex:ClearAllPoints(); btn.tex:SetPoint("TOPLEFT", 1, -1); btn.tex:SetPoint("BOTTOMRIGHT", -1, 1)
                end

                if CDMod.Sandbox.selectedSpellForTracker == btn.spellID then
                    btn:SetBackdropBorderColor(1, 0.6, 0, 1)
                elseif CDMod.Sandbox.selectedRow == rowID then 
                    btn:SetBackdropBorderColor(0, 1, 0, 1) 
                else 
                    btn:SetBackdropBorderColor(0, 0, 0, 1) 
                end
                
                -- [新增] 取每个渲染组的第一个技能作为发光效果的展示宿主
                if i == 1 then
                    table.insert(CDMod.Sandbox.GlowPreviewBtns, btn)
                end
                
                btn:SetScript("OnClick", function(self, button)
                    if self.isDragging then return end
                    
                    if button == "RightButton" then
                        if CDMod.Sandbox.selectedSpellForTracker == self.spellID then 
                            CDMod.Sandbox.selectedSpellForTracker = nil 
                        else 
                            CDMod.Sandbox.selectedSpellForTracker = self.spellID 
                        end
                        CDMod.Sandbox.selectedRow = nil
                    else
                        if CDMod.Sandbox.selectedRow == self.rowID then 
                            CDMod.Sandbox.selectedRow = nil 
                        else 
                            CDMod.Sandbox.selectedRow = self.rowID 
                        end
                        CDMod.Sandbox.selectedSpellForTracker = nil
                    end
                    
                    if WF.UI.UpdateTargetWidth then
                        local startW = WF.MainFrame:GetWidth(); WF.UI:RefreshCurrentPanel(); WF.MainFrame:SetWidth(startW) 
                        local targetReq = (CDMod.Sandbox.selectedRow or CDMod.Sandbox.selectedSpellForTracker) and 1050 or 950
                        WF.UI:UpdateTargetWidth(targetReq, true)
                    else WF.UI:RefreshCurrentPanel() end
                end)
                
                btn:SetScript("OnEnter", function(self) 
                    if not self.isDragging then 
                        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                        local sID = tonumber(item.idStr)
                        local success = false
                        if sID then success = pcall(function() GameTooltip:SetSpellByID(sID) end) end
                        if not success then GameTooltip:SetText(item.name) end
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine(L["Left Click: Select Row Layout"] or "|cff00ff00[左键]|r 选中整行进行排版设置", 1,1,1)
                        GameTooltip:AddLine(L["Right Click: Tracker"] or "|cffffaa00[右键]|r 设置此技能专属的变灰/褪色条件", 1,1,1)
                        GameTooltip:Show() 
                    end 
                end)
                btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                
                btn:RegisterForDrag("LeftButton")
                btn:SetScript("OnDragStart", function(self)
                    self.isDragging = true
                    local currentLevel = self:GetFrameLevel() or 1
                    self.origFrameLevel = currentLevel
                    self:SetFrameLevel(math.min(65535, currentLevel + 50)) 
                    
                    local cx, cy = GetCursorPosition()
                    local uiScale = self:GetEffectiveScale() 
                    self.cursorStartX = cx / uiScale
                    self.cursorStartY = cy / uiScale
                    local p, rt, rp, x, y = self:GetPoint()
                    self.origP, self.origRT, self.origRP = p, rt, rp
                    self.startX, self.startY = x, y
                    
                    self:SetScript("OnUpdate", function(s)
                        local ncx, ncy = GetCursorPosition()
                        ncx, ncy = ncx / uiScale, ncy / uiScale
                        s:ClearAllPoints(); s:SetPoint(s.origP, s.origRT, s.origRP, s.startX + (ncx - s.cursorStartX), s.startY + (ncy - s.cursorStartY))
                        
                        local ind = scrollChild.Sandbox_DropIndicator
                        local scx, scy = s:GetCenter()
                        if not scx or not scy then return end
                        
                        local minDist = 9999
                        local closestBtn = nil
                        local targetBg = nil
                        
                        for j = 1, #scrollChild.SandboxIconsPool do
                            local other = scrollChild.SandboxIconsPool[j]
                            if other:IsShown() and other ~= s then
                                local isCombatSrc = (s.catName == "Essential" or s.catName == "Utility")
                                local isCombatTgt = (other.catName == "Essential" or other.catName == "Utility")
                                local canDrop = false
                                
                                if isCombatSrc and isCombatTgt then canDrop = true
                                elseif s.catName == other.catName then canDrop = true end
                                
                                if canDrop then
                                    local ox, oy = other:GetCenter()
                                    if ox and oy then
                                        local dist = math.sqrt((scx - ox)^2 + (scy - oy)^2)
                                        if dist < minDist then minDist = dist; closestBtn = other end
                                    end
                                end
                            end
                        end
                        
                        for _, cBg in pairs(canvas.groupBgs) do
                            if cBg:IsShown() and cBg:IsMouseOver() then
                                local isCombatSrc = (s.catName == "Essential" or s.catName == "Utility")
                                local isCombatTgt = (cBg.catName == "Essential" or cBg.catName == "Utility")
                                if (isCombatSrc and isCombatTgt) or (s.catName == cBg.catName) then
                                    targetBg = cBg
                                    break
                                end
                            end
                        end

                        if closestBtn and minDist < 40 then
                            local ox, oy = closestBtn:GetCenter()
                            s.dropTarget = closestBtn
                            s.dropMode = "btn"
                            
                            if s.catName == "BuffBar" then
                                local isUpGrowth = (WF.db.cooldownCustom.BuffBar.growth == "UP")
                                if isUpGrowth then
                                    s.dropModeDir = (scy > oy) and "after" or "before"
                                else
                                    s.dropModeDir = (scy > oy) and "before" or "after"
                                end
                            else
                                s.dropModeDir = (scx < ox) and "before" or "after"
                            end
                            
                            ind:ClearAllPoints()
                            ind:SetParent(closestBtn:GetParent())
                            ind:SetFrameLevel(math.min(65535, closestBtn:GetFrameLevel() + 5))
                            ind.tex:SetColorTexture(0, 1, 0, 1)
                            
                            if s.catName == "BuffBar" then
                                ind:SetSize(closestBtn:GetWidth() + 10, 4)
                                if scy > oy then ind:SetPoint("BOTTOM", closestBtn, "TOP", 0, 2) else ind:SetPoint("TOP", closestBtn, "BOTTOM", 0, -2) end
                            else
                                ind:SetSize(4, closestBtn:GetHeight() + 10)
                                if s.dropModeDir == "before" then ind:SetPoint("RIGHT", closestBtn, "LEFT", -2, 0) else ind:SetPoint("LEFT", closestBtn, "RIGHT", 2, 0) end
                            end
                            ind:Show()
                            
                        elseif targetBg then
                            s.dropTarget = targetBg
                            s.dropMode = "bg"
                            
                            ind:ClearAllPoints()
                            ind:SetParent(targetBg)
                            ind:SetFrameLevel(math.min(65535, targetBg:GetFrameLevel() + 2))
                            ind:SetAllPoints(targetBg)
                            ind.tex:SetColorTexture(0, 1, 0, 0.2)
                            ind:Show()
                        else
                            ind:Hide()
                            s.dropTarget = nil
                        end
                    end)
                end)
                
                btn:SetScript("OnDragStop", function(self)
                    self.isDragging = false
                    self:SetScript("OnUpdate", nil)
                    
                    self:SetFrameLevel(math.max(1, math.min(65535, self.origFrameLevel or 1)))
                    if scrollChild.Sandbox_DropIndicator then scrollChild.Sandbox_DropIndicator:Hide() end
                    
                    if self.dropTarget then
                        local srcCat = self.catName
                        local tgtCat = self.dropTarget.catName
                        local srcList = CDMod.Sandbox.RenderedLists[srcCat]
                        local tgtList = CDMod.Sandbox.RenderedLists[tgtCat]
                        
                        if srcList and tgtList then
                            local myIdx
                            for idx, v in ipairs(srcList) do
                                if v.idStr == self.spellID then myIdx = idx; break end
                            end
                            
                            if myIdx then
                                local myItem = table.remove(srcList, myIdx)
                                
                                if self.dropMode == "bg" then
                                    if tgtCat == "Essential" and self.dropTarget.rowID == "Row1" then
                                        local maxR1 = WF.db.cooldownCustom.Essential.maxPerRow or 7
                                        local eR1Count = math.min(#tgtList, maxR1)
                                        table.insert(tgtList, eR1Count + 1, myItem)
                                    else
                                        table.insert(tgtList, #tgtList + 1, myItem)
                                    end
                                else
                                    local targetIdx = 0
                                    for idx, v in ipairs(tgtList) do if v.idStr == self.dropTarget.spellID then targetIdx = idx; break end end
                                    if self.dropModeDir == "after" then table.insert(tgtList, targetIdx + 1, myItem) else table.insert(tgtList, targetIdx > 0 and targetIdx or 1, myItem) end
                                end
                                
                                local dbO = WF.db.cooldownCustom.spellOverrides
                                if not dbO then dbO = {}; WF.db.cooldownCustom.spellOverrides = dbO end
                                if not dbO[self.spellID] then dbO[self.spellID] = {} end
                                
                                if srcCat ~= tgtCat then
                                    dbO[self.spellID].category = tgtCat
                                end
                                
                                for idx, v in ipairs(tgtList) do
                                    if not dbO[v.idStr] then dbO[v.idStr] = {} end
                                    dbO[v.idStr].sortIndex = idx
                                end
                                if srcCat ~= tgtCat then
                                    for idx, v in ipairs(srcList) do
                                        if not dbO[v.idStr] then dbO[v.idStr] = {} end
                                        dbO[v.idStr].sortIndex = idx
                                    end
                                end
                            end
                        end
                    end
                    
                    self:ClearAllPoints()
                    if WF.UI.RefreshCurrentPanel then WF.UI:RefreshCurrentPanel() end
                    if WF.TriggerCooldownLayout then WF.TriggerCooldownLayout() end
                end)
                
                ApplyMockText(btn, db, catCfg, isRow2, catName == "BuffBar")
                btn:Show(); poolIdx = poolIdx + 1
            end
            
            return isVertical and contentH or itemH
        end

        local currentY = -15
        
        local cH = RenderGroup(bbList, db.BuffBar, "BuffBar", "BuffBar", currentY, false)
        currentY = currentY - cH - 12

        cH = RenderGroup(biList, db.BuffIcon, "BuffIcon", "BuffIcon", currentY, false)
        currentY = currentY - cH - 12

        cH = RenderGroup(eR1, db.Essential, "Essential", "Row1", currentY, false)
        currentY = currentY - cH - 12

        cH = RenderGroup(eR2, db.Essential, "Essential", "Row2", currentY, true)
        currentY = currentY - cH - 12

        cH = RenderGroup(uList, db.Utility, "Utility", "Utility", currentY, false)
        currentY = currentY - cH - 12

        local boxWidth = math.max(10, (forcedWidth or 400) - 20)
        if currentMaxWidth > boxWidth and currentMaxWidth > 0 then
            local computedScale = math.max(0.1, boxWidth / currentMaxWidth)
            canvas:SetScale(computedScale)
        else
            canvas:SetScale(1)
        end
        
        -- [新增] 沙盒绘制完成后，统一刷新预览区里的发光效果
        if CDMod.UpdateSandboxGlows then CDMod:UpdateSandboxGlows() end
        
        return math.abs(currentY)
    end

    WF.UI:RegisterPanel("cooldownCustom_Global", function(scrollChild, ColW)
        local db = WF.db.cooldownCustom or {}; if not db.Essential then db.Essential = {} end; if not db.Utility then db.Utility = {} end
        WF.UI.MainScrollChild = scrollChild
        
        local targetWidth = (CDMod.Sandbox.selectedRow or CDMod.Sandbox.selectedSpellForTracker) and 1050 or 950
        ColW = targetWidth / 2.2
        
        local leftColW = ColW * 1.1
        local rightColW = ColW * 0.9 - 10
        local leftX = 15
        local rightX = 15 + leftColW + 20

        local leftY = -10
        
        local help = scrollChild.Sandbox_Help or scrollChild:CreateFontString(nil, "OVERLAY")
        help:SetParent(scrollChild); help:ClearAllPoints(); help:SetPoint("TOPLEFT", leftX, leftY); help:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); help:SetWidth(leftColW); help:SetJustifyH("LEFT")
        help:SetText("|cff00ccff[排版引擎]|r |cff00ff00[左键]|r单击选中排版；|cffffaa00[右键]|r单击设置褪色；拖拽图标可跨组换绑；点击空白处返回全局设置。")
        help:Show(); scrollChild.Sandbox_Help = help
        leftY = leftY - 35

        local btnScan = scrollChild.Sandbox_ScanBtn or WF.UI.Factory:CreateFlatButton(scrollChild, "▶ 扫描/抓取当前原版高级冷却的法术", function() CDMod:ScanForSandbox(); WF.UI:RefreshCurrentPanel() end)
        btnScan:SetParent(scrollChild); btnScan:ClearAllPoints(); btnScan:SetPoint("TOPLEFT", leftX, leftY); btnScan:SetWidth(leftColW); btnScan:Show(); scrollChild.Sandbox_ScanBtn = btnScan
        leftY = leftY - 35

        local previewBox = scrollChild.Sandbox_Box or CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
        previewBox:SetPoint("TOPLEFT", leftX, leftY)
        WF.UI.Factory.ApplyFlatSkin(previewBox, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1); previewBox:Show(); scrollChild.Sandbox_Box = previewBox

        local bgClick = scrollChild.Sandbox_BgClick
        if not bgClick then
            bgClick = CreateFrame("Button", nil, previewBox)
            bgClick:SetAllPoints()
            bgClick:SetFrameLevel(previewBox:GetFrameLevel())
            bgClick:SetScript("OnClick", function()
                if CDMod.Sandbox.selectedRow or CDMod.Sandbox.selectedSpellForTracker then
                    CDMod.Sandbox.selectedRow = nil
                    CDMod.Sandbox.selectedSpellForTracker = nil
                    if WF.UI.UpdateTargetWidth then
                        local startW = WF.MainFrame:GetWidth()
                        WF.UI:RefreshCurrentPanel()
                        WF.MainFrame:SetWidth(startW)
                        WF.UI:UpdateTargetWidth(950, true)
                    else
                        WF.UI:RefreshCurrentPanel()
                    end
                end
            end)
            scrollChild.Sandbox_BgClick = bgClick
        end

        local canvas = scrollChild.Sandbox_Canvas or CreateFrame("Frame", nil, previewBox)
        canvas:SetPoint("TOP", previewBox, "TOP", 0, 0)
        scrollChild.Sandbox_Canvas = canvas

        if not scrollChild.SandboxIconsPool then scrollChild.SandboxIconsPool = {} end
        CDMod:ScanForSandbox()
        
        local unscaledHeight = CDMod:DrawSandboxToUI(leftColW) or 350
        local finalScale = canvas:GetScale() or 1
        local previewHeight = math.max(350, (unscaledHeight * finalScale) + 20)
        
        previewBox:SetSize(leftColW, previewHeight)
        canvas:SetSize(leftColW, previewHeight)
        
        leftY = leftY - previewHeight - 15

        local rightY = -45
        
        if CDMod.Sandbox.selectedSpellForTracker then
            local spellIDStr = CDMod.Sandbox.selectedSpellForTracker
            local sID = tonumber(spellIDStr)
            local sInfo = nil; pcall(function() sInfo = C_Spell.GetSpellInfo(sID) end)
            local sName = sInfo and sInfo.name or spellIDStr
            
            local trackerDB = WF.db.cooldownTracker or { desatSpells = {}, resourceSpells = {} }
            if not trackerDB.desatSpells then trackerDB.desatSpells = {} end
            if not trackerDB.resourceSpells then trackerDB.resourceSpells = {} end
            
            local trackerOpts = {
                { type = "group", key = "sb_tracker_global", text = "褪色引擎全局控制", childs = {
                    { type = "toggle", key = "enable", db = trackerDB, text = "完全启用褪色/变灰功能", requireReload = true },
                    { type = "toggle", key = "enableDesat", db = trackerDB, text = "全局允许：状态/距离异常判断" },
                    { type = "toggle", key = "enableResource", db = trackerDB, text = "全局允许：能量/资源不足判断" },
                }},
                { type = "group", key = "sb_tracker", text = "|cffffaa00自定义褪色配置|r: " .. sName, childs = {
                    { type = "toggle", key = spellIDStr, db = trackerDB.desatSpells, text = "状态/距离异常变灰 (如：目标缺少痛楚)" },
                    { type = "toggle", key = spellIDStr, db = trackerDB.resourceSpells, text = "能量/资源不足变灰 (如：缺少星界能量)" },
                }}
            }
            
            local function HandleTrackerChange(val)
                if WF.CooldownTrackerAPI then
                    wipe(WF.CooldownTrackerAPI.desatSpellSet)
                    wipe(WF.CooldownTrackerAPI.resourceSpellSet)
                    for k, v in pairs(trackerDB.desatSpells) do if v then WF.CooldownTrackerAPI.desatSpellSet[tonumber(k)] = true end end
                    for k, v in pairs(trackerDB.resourceSpells) do if v then WF.CooldownTrackerAPI.resourceSpellSet[tonumber(k)] = true end end
                    WF.CooldownTrackerAPI:RefreshAll()
                end
                if WF.TriggerCooldownLayout then WF.TriggerCooldownLayout() end
            end
            
            rightY = WF.UI:RenderOptionsGroup(scrollChild, rightX, rightY, rightColW, trackerOpts, HandleTrackerChange)
            
        elseif CDMod.Sandbox.selectedRow then
            local rowOpts = {}
            if CDMod.Sandbox.selectedRow == "Row1" then
                rowOpts = {{ type = "group", key = "sb_r1", text = "|cff00ff00该行排版调整|r: 第一排核心", childs = { { type = "slider", key = "maxPerRow", db = db.Essential, min = 1, max = 20, step = 1, text = L["Max Per Row"] or "每排最大数量" }, { type = "slider", key = "iconGap", db = db.Essential, min = 0, max = 50, step = 1, text = L["Icon Gap"] or "间距" }, { type = "slider", key = "row1Width", db = db.Essential, min = 10, max = 100, step = 1, text = L["Width"] or "宽度" }, { type = "slider", key = "row1Height", db = db.Essential, min = 10, max = 100, step = 1, text = L["Height"] or "高度" }, WF.UI:GetTextOptions(db.Essential, "row1Stack", L["Stack Text"] or "层数", "r1_st"), WF.UI:GetTextOptions(db.Essential, "row1Cd", L["CD Text"] or "冷却文本", "r1_cd") } }}
            elseif CDMod.Sandbox.selectedRow == "Row2" then
                rowOpts = {{ type = "group", key = "sb_r2", text = "|cff00ff00该行排版调整|r: 第二排核心", childs = { { type = "slider", key = "row2IconGap", db = db.Essential, min = 0, max = 50, step = 1, text = L["Icon Gap"] or "间距" }, { type = "slider", key = "row2Width", db = db.Essential, min = 10, max = 100, step = 1, text = L["Width"] or "宽度" }, { type = "slider", key = "row2Height", db = db.Essential, min = 10, max = 100, step = 1, text = L["Height"] or "高度" }, WF.UI:GetTextOptions(db.Essential, "row2Stack", L["Stack Text"] or "层数", "r2_st"), WF.UI:GetTextOptions(db.Essential, "row2Cd", L["CD Text"] or "冷却文本", "r2_cd") } }}
            elseif CDMod.Sandbox.selectedRow == "Utility" then
                rowOpts = {{ type = "group", key = "sb_u", text = "|cff00ff00该行排版调整|r: 效能组技能", childs = { { type = "slider", key = "iconGap", db = db.Utility, min = 0, max = 50, step = 1, text = L["Icon Gap"] or "间距" }, { type = "slider", key = "width", db = db.Utility, min = 10, max = 100, step = 1, text = L["Width"] or "宽度" }, { type = "slider", key = "height", db = db.Utility, min = 10, max = 100, step = 1, text = L["Height"] or "高度" }, WF.UI:GetTextOptions(db.Utility, "stack", L["Stack Text"] or "层数", "u_st"), WF.UI:GetTextOptions(db.Utility, "cd", L["CD Text"] or "冷却文本", "u_cd") } }}
            elseif CDMod.Sandbox.selectedRow == "BuffIcon" then
                rowOpts = {{ type = "group", key = "sb_bi", text = "|cff00ff00该行排版调整|r: 增益图标", childs = { { type = "slider", key = "iconGap", db = db.BuffIcon, min = 0, max = 50, step = 1, text = L["Icon Gap"] or "间距" }, { type = "slider", key = "width", db = db.BuffIcon, min = 10, max = 100, step = 1, text = L["Width"] or "宽度" }, { type = "slider", key = "height", db = db.BuffIcon, min = 10, max = 100, step = 1, text = L["Height"] or "高度" }, WF.UI:GetTextOptions(db.BuffIcon, "stack", L["Stack Text"] or "层数", "bi_st"), WF.UI:GetTextOptions(db.BuffIcon, "cd", L["CD Text"] or "倒计时", "bi_cd") } }}
            elseif CDMod.Sandbox.selectedRow == "BuffBar" then
                rowOpts = {{ type = "group", key = "sb_bb", text = "|cff00ff00该行排版调整|r: 增益条", childs = { 
                    { type = "dropdown", key = "barTexture", db = db.BuffBar, text = "增益条材质", options = WF.UI.StatusBarOptions },
                    { type = "dropdown", key = "growth", db = db.BuffBar, text = "垂直排列方向", options = GrowthOptionsVertical },
                    { type = "dropdown", key = "barPosition", db = db.BuffBar, text = "条与图标的对齐基准", options = BarAlignOptions },
                    { type = "slider", key = "iconGap", db = db.BuffBar, min = 0, max = 50, step = 1, text = L["Icon Gap"] or "间距" }, 
                    { type = "slider", key = "width", db = db.BuffBar, min = 50, max = 400, step = 1, text = "总宽度" }, 
                    { type = "slider", key = "height", db = db.BuffBar, min = 10, max = 100, step = 1, text = "图标大小" }, 
                    { type = "slider", key = "barHeight", db = db.BuffBar, min = 2, max = 100, step = 1, text = "增益条独立高度" },
                    WF.UI:GetTextOptions(db.BuffBar, "stack", L["Stack Text"] or "层数", "bb_st"), 
                    WF.UI:GetTextOptions(db.BuffBar, "cd", L["CD Text"] or "倒计时", "bb_cd") 
                } }}
            end
            rightY = WF.UI:RenderOptionsGroup(scrollChild, rightX, rightY, rightColW, rowOpts, HandleCDChange)
        else
            -- [修改] 分离发光与基础排版的渲染组，阻止互相引发的不必要重绘
            local glowDB = WF.db.glow or {}
            
            local globalBaseOpts = {
                { type = "group", key = "cd_global_base", text = L["Global Settings"] or "全局通用设定", childs = {
                    { type = "toggle", key = "enable", db = db, text = L["Enable Module"] or "启用模块", requireReload = true },
                    { type = "dropdown", key = "countFont", db = db, text = L["Global Font"] or "全局字体", options = WF.UI.FontOptions },
                    { type = "color", key = "swipeColor", db = db, text = L["Default Swipe Color"] or "默认冷却遮罩颜色" },
                    { type = "color", key = "activeAuraColor", db = db, text = L["Active Swipe Color"] or "激活时冷却遮罩颜色" },
                    { type = "toggle", key = "reverseSwipe", db = db, text = L["Reverse Swipe"] or "反转冷却转圈方向" },
                    { type = "toggle", key = "enableCustomLayout", db = db.Essential, text = L["Enable Split Layout"] or "启用核心爆发分排布局" },
                    { type = "slider", key = "rowYGap", db = db.Essential, min = 0, max = 50, step = 1, text = L["Row Y Gap"] or "第二排Y轴间距" },
                }}
            }
            
            local globalGlowOpts = {
                { type = "group", key = "cd_global_glow", text = L["Global Glow"] or "全局发光替换设置", childs = {
                    { type = "toggle", key = "enable", db = glowDB, text = L["Enable Glow"] or "全面接管并启用发光引擎" },
                    { type = "dropdown", key = "glowType", db = glowDB, text = L["Glow Style"] or "发光样式", options = {
                        {text = L["Pixel"] or "像素边框", value="pixel"}, 
                        {text = L["Autocast"] or "自动施法", value="autocast"}, 
                        {text = L["Button"] or "暴雪默认", value="button"}, 
                        {text = L["Proc"] or "高亮闪烁", value="proc"}
                    }},
                    { type = "toggle", key = "useCustomColor", db = glowDB, text = L["Enable Custom Color"] or "启用自定义颜色" },
                    { type = "color", key = "color", db = glowDB, text = L["Color"] or "颜色" },
                }}
            }
            
            local glowChilds = globalGlowOpts[1].childs
            if glowDB.glowType == "pixel" then
                table.insert(glowChilds, { type = "slider", key = "pixelLines", db = glowDB, min = 1, max = 20, step = 1, text = L["Lines"] or "线条数量" })
                table.insert(glowChilds, { type = "slider", key = "pixelFrequency", db = glowDB, min = -2, max = 2, step = 0.05, text = L["Frequency"] or "运动频率" })
                table.insert(glowChilds, { type = "slider", key = "pixelLength", db = glowDB, min = 0, max = 50, step = 1, text = L["Length"] or "线条长度" })
                table.insert(glowChilds, { type = "slider", key = "pixelThickness", db = glowDB, min = 1, max = 10, step = 1, text = L["Thickness"] or "线条粗细" })
                table.insert(glowChilds, { type = "slider", key = "pixelXOffset", db = glowDB, min = -30, max = 30, step = 1, text = L["X Offset"] or "X 轴偏移" })
                table.insert(glowChilds, { type = "slider", key = "pixelYOffset", db = glowDB, min = -30, max = 30, step = 1, text = L["Y Offset"] or "Y 轴偏移" })
            elseif glowDB.glowType == "autocast" then
                table.insert(glowChilds, { type = "slider", key = "autocastParticles", db = glowDB, min = 1, max = 20, step = 1, text = L["Particles"] or "粒子数量" })
                table.insert(glowChilds, { type = "slider", key = "autocastFrequency", db = glowDB, min = -2, max = 2, step = 0.05, text = L["Frequency"] or "运动频率" })
                table.insert(glowChilds, { type = "slider", key = "autocastScale", db = glowDB, min = 0.5, max = 3, step = 0.1, text = L["Scale"] or "整体缩放" })
                table.insert(glowChilds, { type = "slider", key = "autocastXOffset", db = glowDB, min = -30, max = 30, step = 1, text = L["X Offset"] or "X 轴偏移" })
                table.insert(glowChilds, { type = "slider", key = "autocastYOffset", db = glowDB, min = -30, max = 30, step = 1, text = L["Y Offset"] or "Y 轴偏移" })
            elseif glowDB.glowType == "button" then
                table.insert(glowChilds, { type = "slider", key = "buttonFrequency", db = glowDB, min = 0, max = 2, step = 0.05, text = L["Frequency"] or "闪烁频率" })
            elseif glowDB.glowType == "proc" then
                table.insert(glowChilds, { type = "slider", key = "procDuration", db = glowDB, min = 0.1, max = 5, step = 0.1, text = L["Duration"] or "动画持续时间" })
                table.insert(glowChilds, { type = "slider", key = "procXOffset", db = glowDB, min = -30, max = 30, step = 1, text = L["X Offset"] or "X 轴偏移" })
                table.insert(glowChilds, { type = "slider", key = "procYOffset", db = glowDB, min = -30, max = 30, step = 1, text = L["Y Offset"] or "Y 轴偏移" })
            end
            
            -- [新增] 发光专用的刷新回调，不再触发任何重绘排版的逻辑
            local function HandleGlowChange(val)
                if WF.GlowAPI and WF.GlowAPI.RefreshAll then WF.GlowAPI:RefreshAll() end
                if CDMod.UpdateSandboxGlows then CDMod:UpdateSandboxGlows() end
                
                -- 当改变下拉菜单时仍需要重绘面板（因为需要增减不同选项的滑块）
                if val == "UI_REFRESH" or type(val) == "string" then WF.UI:RefreshCurrentPanel() end
            end
            
            rightY = WF.UI:RenderOptionsGroup(scrollChild, rightX, rightY, rightColW, globalBaseOpts, HandleCDChange)
            rightY = WF.UI:RenderOptionsGroup(scrollChild, rightX, rightY, rightColW, globalGlowOpts, HandleGlowChange)
        end

        return math.min(leftY, rightY), targetWidth
    end)
end