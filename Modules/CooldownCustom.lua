local AddonName, ns = ...
local WF = _G.WishFlex or ns.WF
local L = ns.L or {}
local LSM = LibStub("LibSharedMedia-3.0", true)
local LCG = LibStub("LibCustomGlow-1.0", true)
local CDMod = {}

CDMod.hiddenCDs = {}
CDMod.hiddenBuffs = {}
local BaseSpellCache = {}

local DEFAULT_SWIPE_COLOR = {r = 0, g = 0, b = 0, a = 0.8}
local DEFAULT_ACTIVE_AURA_COLOR = {r = 1, g = 0.95, b = 0.57, a = 0.69}
local DEFAULT_CD_COLOR = {r = 1, g = 0.82, b = 0}
local DEFAULT_STACK_COLOR = {r = 1, g = 1, b = 1}

local GrowthOptionsVertical = { {text="向下排列 (DOWN)", value="DOWN"}, {text="向上排列 (UP)", value="UP"} }
local BarAlignOptions = { {text="居中对齐", value="CENTER"}, {text="顶部对齐", value="TOP"}, {text="底部对齐", value="BOTTOM"} }
local IconPosOptions = { {text="左侧", value="LEFT"}, {text="右侧", value="RIGHT"} }

local DefaultConfig = {
    enable = true, countFont = "Expressway", countFontOutline = "OUTLINE", countFontColor = DEFAULT_STACK_COLOR,
    swipeColor = DEFAULT_SWIPE_COLOR, activeAuraColor = DEFAULT_ACTIVE_AURA_COLOR, reverseSwipe = true,
    Utility = { attachToPlayer = false, attachX = 0, attachY = 1, width = 45, height = 30, iconGap = 2, growth = "CENTER_HORIZONTAL", cdFontSize = 18, cdFontColor = DEFAULT_CD_COLOR, cdPosition = "CENTER", cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackPosition = "BOTTOMRIGHT", stackXOffset = 0, stackYOffset = 0 },
    BuffBar = { showIcon = true, iconPosition = "LEFT", width = 150, height = 24, barHeight = 24, barTexture = "Blizzard", barPosition = "CENTER", iconGap = 2, growth = "DOWN", cdFontSize = 18, cdFontColor = DEFAULT_CD_COLOR, cdPosition = "RIGHT", cdXOffset = -5, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackPosition = "LEFT", stackXOffset = 5, stackYOffset = 0 },
    BuffIcon = { width = 45, height = 45, iconGap = 2, growth = "CENTER_HORIZONTAL", cdFontSize = 18, cdFontColor = DEFAULT_CD_COLOR, cdPosition = "CENTER", cdXOffset = 0, cdYOffset = 0, stackFontSize = 14, stackFontColor = DEFAULT_STACK_COLOR, stackPosition = "BOTTOMRIGHT", stackXOffset = 0, stackYOffset = 0 }, 
    Essential = { enableCustomLayout = true, maxPerRow = 7, iconGap = 2, rowYGap = 2, row1Width = 45, row1Height = 45, row1CdFontSize = 18, row1CdFontColor = DEFAULT_CD_COLOR, row1CdPosition = "CENTER", row1CdXOffset = 0, row1CdYOffset = 0, row1StackFontSize = 14, row1StackFontColor = DEFAULT_STACK_COLOR, row1StackPosition = "BOTTOMRIGHT", row1StackXOffset = 0, row1StackYOffset = 0, row2Width = 40, row2Height = 40, row2IconGap = 2, row2CdFontSize = 18, row2CdFontColor = DEFAULT_CD_COLOR, row2CdPosition = "CENTER", row2CdXOffset = 0, row2CdYOffset = 0, row2StackFontSize = 14, row2StackFontColor = DEFAULT_STACK_COLOR, row2StackPosition = "BOTTOMRIGHT", row2StackXOffset = 0, row2StackYOffset = 0 }
}

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

-- 【终极修复：手绘物理 1 像素完美黑边与半透明底衬】
local function ApplyElvUISkin(targetObj, parentFrame)
    if not targetObj then return nil end
    if not targetObj.wishBd then
        local bd = CreateFrame("Frame", nil, parentFrame)
        
        local parentLvl = (parentFrame and parentFrame.GetFrameLevel and parentFrame:GetFrameLevel()) or 1
        if targetObj.GetFrameLevel then
            bd:SetFrameLevel(math.max(0, targetObj:GetFrameLevel() - 1))
        else
            bd:SetFrameLevel(math.max(0, parentLvl))
        end
        
        -- ELVUI 半透明暗色背景
        local bg = bd:CreateTexture(nil, "BACKGROUND", nil, -1)
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.05, 0.05, 0.6) 
        bd.bg = bg
        
        local m = GetOnePixelSize()
        local function DrawEdge(p1, p2, x, y, w, h)
            local t = bd:CreateTexture(nil, "BORDER", nil, 1)
            t:SetColorTexture(0, 0, 0, 1)
            t:SetPoint(p1, bd, p1, x, y)
            t:SetPoint(p2, bd, p2, x, y)
            if w then t:SetWidth(m) end
            if h then t:SetHeight(m) end
            if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
            if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
            return t
        end
        
        bd.top = DrawEdge("TOPLEFT", "TOPRIGHT", 0, 0, nil, 1)
        bd.bottom = DrawEdge("BOTTOMLEFT", "BOTTOMRIGHT", 0, 0, nil, 1)
        bd.left = DrawEdge("TOPLEFT", "BOTTOMLEFT", 0, 0, 1, nil)
        bd.right = DrawEdge("TOPRIGHT", "BOTTOMRIGHT", 0, 0, 1, nil)
        
        if targetObj.IsObjectType and targetObj:IsObjectType("Texture") then
            targetObj:SetDrawLayer("ARTWORK", 1)
        end
        
        targetObj.wishBd = bd
    end
    
    local m = GetOnePixelSize()
    targetObj:ClearAllPoints()
    targetObj:SetPoint("TOPLEFT", targetObj.wishBd, "TOPLEFT", m, -m)
    targetObj:SetPoint("BOTTOMRIGHT", targetObj.wishBd, "BOTTOMRIGHT", -m, m)
    
    return targetObj.wishBd
end

local function RemoveBarIconMask(parentFrame, iconTex)
    if not parentFrame or type(parentFrame.GetRegions) ~= "function" then return end
    if not iconTex or type(iconTex.RemoveMaskTexture) ~= "function" then return end
    if parentFrame._wfMaskRemoved then return end
    
    local regions = { parentFrame:GetRegions() }
    for i = 1, #regions do
        local region = regions[i]
        if region and region.IsObjectType and region:IsObjectType("MaskTexture") then
            if region:GetAtlas() == "UI-HUD-CoolDownManager-Mask" then
                pcall(function() iconTex:RemoveMaskTexture(region) end)
                parentFrame._wfMaskRemoved = true
                break
            end
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
    end
end

function CDMod:BuildHiddenCache()
    wipe(self.hiddenCDs)
    wipe(self.hiddenBuffs)
    if WF.db and WF.db.wishMonitor then
        if WF.db.wishMonitor.skills then for idStr, cfg in pairs(WF.db.wishMonitor.skills) do if cfg.enable and cfg.hideOriginal then self.hiddenCDs[tonumber(idStr)] = true end end end
        if WF.db.wishMonitor.buffs then for idStr, cfg in pairs(WF.db.wishMonitor.buffs) do if cfg.enable and cfg.hideOriginal then self.hiddenBuffs[tonumber(idStr)] = true end end end
    end
    if WF.db and WF.db.auraGlow and WF.db.auraGlow.spells then
        for idStr, cfg in pairs(WF.db.auraGlow.spells) do
            if cfg.hideOriginal then 
                local bID = tonumber(cfg.buffID) or tonumber(idStr)
                self.hiddenBuffs[bID] = true 
            end
        end
    end
end

local function ShouldHideCD(info)
    if not info then return false end
    if IsSafeValue(info.spellID) then 
        local overrideDb = WF.db.cooldownCustom and WF.db.cooldownCustom.spellOverrides and WF.db.cooldownCustom.spellOverrides[tostring(info.spellID)]
        if overrideDb and overrideDb.hide then return true end
        if CDMod.hiddenCDs[info.spellID] or CDMod.hiddenCDs[info.overrideSpellID] then return true end
        local baseID = GetBaseSpellFast(info.spellID); if baseID and CDMod.hiddenCDs[baseID] then return true end 
    end
    if info.linkedSpellIDs then for i = 1, #info.linkedSpellIDs do local lid = info.linkedSpellIDs[i]; if IsSafeValue(lid) and CDMod.hiddenCDs[lid] then return true end end end
    return false
end

local function ShouldHideBuff(info)
    if not info then return false end
    if IsSafeValue(info.spellID) then 
        local overrideDb = WF.db.cooldownCustom and WF.db.cooldownCustom.spellOverrides and WF.db.cooldownCustom.spellOverrides[tostring(info.spellID)]
        if overrideDb and overrideDb.hide then return true end
        if CDMod.hiddenBuffs[info.spellID] or CDMod.hiddenBuffs[info.overrideSpellID] then return true end
        local baseID = GetBaseSpellFast(info.spellID); if baseID and CDMod.hiddenBuffs[baseID] then return true end 
    end
    if info.linkedSpellIDs then for i = 1, #info.linkedSpellIDs do local lid = info.linkedSpellIDs[i]; if IsSafeValue(lid) and CDMod.hiddenBuffs[lid] then return true end end end
    return false
end

local function PhysicalHideFrame(frame) if not frame then return end; frame:SetAlpha(0); if frame.Icon then frame.Icon:SetAlpha(0) end; frame:EnableMouse(false); frame:ClearAllPoints(); frame:SetPoint("CENTER", UIParent, "CENTER", -5000, 0); frame._wishFlexHidden = true end

local function SetupFrameGlow(frame)
    if not frame then return end
    if frame.SpellActivationAlert and not frame._wf_glowHooked then
        frame._wf_glowHooked = true
        frame.SpellActivationAlert:SetAlpha(0) 
        hooksecurefunc(frame.SpellActivationAlert, "Show", function(self) 
            self:SetAlpha(0)
            if WF.GlowAPI then WF.GlowAPI:Show(frame) end 
        end)
        hooksecurefunc(frame.SpellActivationAlert, "Hide", function(self) 
            if WF.GlowAPI then WF.GlowAPI:Hide(frame) end 
        end)
        if frame.SpellActivationAlert:IsShown() then 
            if WF.GlowAPI then WF.GlowAPI:Show(frame) end 
        end
    end
end

local function SafeEquals(v, expected) return (type(v) ~= "number" or not (issecretvalue and issecretvalue(v))) and v == expected end
local function SafeHide(self) if self:IsShown() then self:Hide(); self:SetAlpha(0) end end

local function SuppressDebuffBorder(f)
    if not f or f._wishBorderSuppressed then return end; f._wishBorderSuppressed = true
    local borders = { f.DebuffBorder, f.Border, f.IconBorder, f.IconOverlay, f.overlay, f.ExpireBorder, f.Icon and f.Icon.Border, f.Icon and f.Icon.IconBorder, f.Icon and f.Icon.DebuffBorder, f.Bar and f.Bar.Border, f.Bar and f.Bar.BarBG, f.Bar and f.Bar.Pip }
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
    
    local iconTex = frame.Icon and (frame.Icon.Icon or frame.Icon) or frame
    local realAnchor = iconTex.wishBd or iconTex
    frame.Cooldown:ClearAllPoints(); frame.Cooldown:SetAllPoints(realAnchor); frame.Cooldown:SetFrameLevel(frame:GetFrameLevel() + 2)

    if not frame.Cooldown._wishSwipeHooked then 
        hooksecurefunc(frame.Cooldown, "SetCooldown", StaticUpdateSwipeColor)
        if frame.Cooldown.SetCooldownFromDurationObject then hooksecurefunc(frame.Cooldown, "SetCooldownFromDurationObject", StaticUpdateSwipeColor) end
        frame.Cooldown._wishSwipeHooked = true 
    end
    if frame.wasSetFromAura then local ac = db.activeAuraColor or DEFAULT_ACTIVE_AURA_COLOR; frame.Cooldown:SetSwipeColor(ac.r, ac.g, ac.b, ac.a) else local sc = db.swipeColor or DEFAULT_SWIPE_COLOR; frame.Cooldown:SetSwipeColor(sc.r, sc.g, sc.b, sc.a) end 
end

local function FormatText(t, isStack, cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY, fontPath, outline, targetRefStack, targetRefCD) 
    if not t or type(t) ~= "table" or not t.SetFont then return end
    local size = isStack and stackSize or cdSize; local color = isStack and stackColor or cdColor; local pos = isStack and stackPos or cdPos or "CENTER"; local ox = isStack and stackX or cdX or 0; local oy = isStack and stackY or cdY or 0
    local ref = isStack and targetRefStack or targetRefCD
    t:SetFont(fontPath, size, outline); t:SetTextColor(color.r, color.g, color.b); t:ClearAllPoints(); t:SetPoint(pos, ref, pos, ox, oy); t:SetDrawLayer("OVERLAY", 7) 
end

function CDMod:ApplyText(frame, category, rowIndex)
    local db = WF.db.cooldownCustom; local cfg = db[category]; if not cfg then return end
    local fontPath = (LSM and LSM:Fetch('font', db.countFont)) or STANDARD_TEXT_FONT; local outline = db.countFontOutline or "OUTLINE"
    local cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY
    if category == "Essential" then if rowIndex == 2 then cdSize, cdColor, cdPos, cdX, cdY = cfg.row2CdFontSize, cfg.row2CdFontColor, cfg.row2CdPosition or "CENTER", cfg.row2CdXOffset or 0, cfg.row2CdYOffset or 0; stackSize, stackColor, stackPos, stackX, stackY = cfg.row2StackFontSize, cfg.row2StackFontColor, cfg.row2StackPosition or "BOTTOMRIGHT", cfg.row2StackXOffset or 0, cfg.row2StackYOffset or 0 else cdSize, cdColor, cdPos, cdX, cdY = cfg.row1CdFontSize, cfg.row1CdFontColor, cfg.row1CdPosition or "CENTER", cfg.row1CdXOffset or 0, cfg.row1CdYOffset or 0; stackSize, stackColor, stackPos, stackX, stackY = cfg.row1StackFontSize, cfg.row1StackFontColor, cfg.row1StackPosition or "BOTTOMRIGHT", cfg.row1StackXOffset or 0, cfg.row1StackYOffset or 0 end
    else cdSize, cdColor, cdPos, cdX, cdY = cfg.cdFontSize, cfg.cdFontColor, cfg.cdPosition or "CENTER", cfg.cdXOffset or 0, cfg.cdYOffset or 0; stackSize, stackColor, stackPos, stackX, stackY = cfg.stackFontSize, cfg.stackFontColor, cfg.stackPosition or "BOTTOMRIGHT", cfg.stackXOffset or 0, cfg.stackYOffset or 0 end
    
    local targetRefStack = frame; local targetRefCD = frame
    if category == "BuffBar" then
        if cfg.showIcon ~= false then
            local iconObj = type(frame.Icon) == "table" and (frame.Icon.IsObjectType and frame.Icon:IsObjectType("Texture") and frame.Icon or frame.Icon.Icon) or frame.Icon
            targetRefStack = iconObj and iconObj.wishBd or iconObj or frame
            targetRefCD = frame.Bar and frame.Bar.wishBd or frame.Bar or frame
        else
            targetRefStack = frame.Bar and frame.Bar.wishBd or frame.Bar or frame; targetRefCD = targetRefStack
        end
    else
        local iconObj = type(frame.Icon) == "table" and (frame.Icon.IsObjectType and frame.Icon:IsObjectType("Texture") and frame.Icon or frame.Icon.Icon) or frame.Icon
        targetRefStack = iconObj and iconObj.wishBd or iconObj or frame; targetRefCD = targetRefStack
    end
    
    local stackText = (frame.Applications and frame.Applications.Applications) or (frame.ChargeCount and frame.ChargeCount.Current) or frame.Count
    if frame.Cooldown then if frame.Cooldown.timer and frame.Cooldown.timer.text then FormatText(frame.Cooldown.timer.text, false, cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY, fontPath, outline, targetRefStack, targetRefCD) end; for k = 1, select("#", frame.Cooldown:GetRegions()) do local region = select(k, frame.Cooldown:GetRegions()); if region and region.IsObjectType and region:IsObjectType("FontString") then FormatText(region, false, cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY, fontPath, outline, targetRefStack, targetRefCD) end end end
    FormatText(stackText, true, cdSize, cdColor, cdPos, cdX, cdY, stackSize, stackColor, stackPos, stackX, stackY, fontPath, outline, targetRefStack, targetRefCD)
end

-- 【核心渲染升级：统一的完美对齐与边框注入】
local function ApplyIconAlignment(f, w, h, isSandbox)
    local iconTex, iconParent
    if isSandbox then
        iconTex, iconParent = f.tex, f
    else
        if type(f.Icon) == "table" and f.Icon.IsObjectType and f.Icon:IsObjectType("Texture") then iconTex, iconParent = f.Icon, f
        else iconTex, iconParent = f.Icon.Icon or f.Icon, f.Icon or f end
    end
    
    if iconTex then
        local iconBd = ApplyElvUISkin(iconTex, iconParent)
        iconBd:ClearAllPoints(); iconBd:SetPoint("CENTER", f, "CENTER", 0, 0); iconBd:SetSize(w, h); iconBd:Show()
        iconTex:Show(); CDMod.ApplyTexCoord(iconTex, w, h)
    end
end

local function ApplyBarAlignment(f, cfg, w, h, barH, gap, isSandbox)
    local iconPos = cfg.iconPosition or "LEFT"
    local barPos = cfg.barPosition or "CENTER"
    local showIcon = (cfg.showIcon ~= false) 
    
    local iconTex, iconParent, barObj, barParent
    if isSandbox then
        iconTex, iconParent = f.tex, f; barObj, barParent = f.barTex, f
    else
        if type(f.Icon) == "table" and f.Icon.IsObjectType and f.Icon:IsObjectType("Texture") then iconTex, iconParent = f.Icon, f
        else iconTex, iconParent = f.Icon.Icon or f.Icon, f.Icon or f end
        barObj, barParent = f.Bar, f
    end
    
    local iconBd = ApplyElvUISkin(iconTex, iconParent)
    local barBd = ApplyElvUISkin(barObj, barParent)
    
    iconBd:ClearAllPoints(); barBd:ClearAllPoints()
    
    if showIcon then
        iconBd:SetSize(h, h); iconBd:Show(); iconTex:Show()
        CDMod.ApplyTexCoord(iconTex, h, h) 
        
        local actualBarW = math.max(1, w - h - gap)
        barBd:SetSize(actualBarW, barH) 
        
        if iconPos == "LEFT" then
            if barPos == "TOP" then iconBd:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0); barBd:SetPoint("TOPLEFT", iconBd, "TOPRIGHT", gap, 0)
            elseif barPos == "BOTTOM" then iconBd:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0); barBd:SetPoint("BOTTOMLEFT", iconBd, "BOTTOMRIGHT", gap, 0)
            else iconBd:SetPoint("LEFT", f, "LEFT", 0, 0); barBd:SetPoint("LEFT", iconBd, "RIGHT", gap, 0) end
        else
            if barPos == "TOP" then barBd:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0); iconBd:SetPoint("TOPLEFT", barBd, "TOPRIGHT", gap, 0)
            elseif barPos == "BOTTOM" then barBd:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0); iconBd:SetPoint("BOTTOMLEFT", barBd, "BOTTOMRIGHT", gap, 0)
            else barBd:SetPoint("LEFT", f, "LEFT", 0, 0); iconBd:SetPoint("LEFT", barBd, "RIGHT", gap, 0) end
        end
    else
        iconBd:Hide(); iconTex:Hide()
        barBd:SetSize(w, barH)
        if barPos == "TOP" then barBd:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        elseif barPos == "BOTTOM" then barBd:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        else barBd:SetPoint("CENTER", f, "CENTER", 0, 0) end
    end
    
    if not isSandbox and barObj.SetStatusBarTexture then
        local texPath = (LSM and LSM:Fetch("statusbar", cfg.barTexture)) or "Interface\\TargetingFrame\\UI-StatusBar"
        barObj:SetStatusBarTexture(texPath)
    end
end

local function StyleFrameCommon(f, cfg, w, h, catName, isSandbox)
    local isBar = (catName == "BuffBar")
    local barH = PixelSnap(cfg.barHeight or h)
    local gap = PixelSnap(cfg.iconGap or 2)
    f:SetSize(w, math.max(h, barH))
    
    if isBar then
        ApplyBarAlignment(f, cfg, w, h, barH, gap, isSandbox)
        if isSandbox then
            local texPath = (LSM and LSM:Fetch("statusbar", cfg.barTexture)) or "Interface\\TargetingFrame\\UI-StatusBar"
            f.barTex:SetTexture(texPath)
        end
    else
        ApplyIconAlignment(f, w, h, isSandbox)
    end
end

function CDMod:ImmediateStyleFrame(frame, category)
    if not frame then return end
    if category == "BuffIcon" or category == "BuffBar" then if ShouldHideBuff(frame.cooldownInfo) then PhysicalHideFrame(frame); return end
    else if ShouldHideCD(frame.cooldownInfo) then PhysicalHideFrame(frame); return end end
    
    if frame._wishFlexHidden then frame._wishFlexHidden = false; frame:SetAlpha(1); if frame.Icon then frame.Icon:SetAlpha(1) end; frame:EnableMouse(true) end
    SuppressDebuffBorder(frame)
    local db = WF.db.cooldownCustom; local cfg = db[category]
    if cfg then 
        local w = PixelSnap(cfg.width or cfg.row1Width or 45); local h = PixelSnap(cfg.height or cfg.row1Height or 45)
        if frame.Icon then 
            local iconParent = type(frame.Icon) == "table" and frame.Icon.IsObjectType and frame.Icon:IsObjectType("Texture") and frame or frame.Icon
            local iconTex = type(frame.Icon) == "table" and frame.Icon.IsObjectType and frame.Icon:IsObjectType("Texture") and frame.Icon or frame.Icon.Icon
            RemoveBarIconMask(iconParent, iconTex) 
        end
        StyleFrameCommon(frame, cfg, w, h, category, false)
    end
    self:ApplyText(frame, category, 1); self:ApplySwipeSettings(frame)
    SetupFrameGlow(frame); ApplySpellOverrides(frame)
end

local cachedIcons = {}; local cachedR1 = {}; local cachedR2 = {}
local function DoLayoutBuffs(viewerName, key, isVertical)
    local db = WF.db.cooldownCustom; local container = _G[viewerName]; if not container or not container:IsShown() then return end
    local targetAnchor = _G["WishFlex_Anchor_"..key]; if targetAnchor then WeldToMover(container, targetAnchor) end
    
    wipe(cachedIcons); local count = 0
    if container.itemFramePool then 
        for f in container.itemFramePool:EnumerateActive() do 
            if f:IsShown() then 
                if ShouldHideBuff(f.cooldownInfo) then 
                    PhysicalHideFrame(f) 
                else 
                    count = count + 1; cachedIcons[count] = f; CDMod:ImmediateStyleFrame(f, key)
                end 
            end 
        end 
    end 
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
            local f = cachedIcons[i]; f:ClearAllPoints()
            if growth == "UP" then f:SetPoint("CENTER", container, "CENTER", 0, -startY + (i - 1) * (itemH + gap)) else f:SetPoint("CENTER", container, "CENTER", 0, startY - (i - 1) * (itemH + gap)) end
        end
    else
        local startX = -(totalW / 2) + (w / 2)
        for i = 1, count do 
            local f = cachedIcons[i]; f:ClearAllPoints()
            if growth == "LEFT" then f:SetPoint("CENTER", container, "CENTER", -startX - (i - 1) * (w + gap), 0) elseif growth == "RIGHT" then f:SetPoint("CENTER", container, "CENTER", startX + (i - 1) * (w + gap), 0) else f:SetPoint("CENTER", container, "CENTER", startX + (i - 1) * (w + gap), 0) end
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
                    if (defCat == "Essential" or defCat == "Utility") and (oCat == "Essential" or oCat == "Utility") then tCat = oCat end
                end
                if ShouldHideCD(info) then PhysicalHideFrame(f) else CDMod:ImmediateStyleFrame(f, tCat); table.insert(catFrames[tCat], f) end
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
                for i = 1, count do local f = uFrames[i]; f:ClearAllPoints(); f:SetPoint("RIGHT", uViewer, "RIGHT", -((i - 1) * (w + gap)), 0) end
            else
                local startX = -(totalW / 2) + (w / 2)
                for i = 1, count do local f = uFrames[i]; f:ClearAllPoints(); if growth == "LEFT" then f:SetPoint("CENTER", uViewer, "CENTER", -startX - (i - 1) * (w + gap), 0) elseif growth == "RIGHT" then f:SetPoint("CENTER", uViewer, "CENTER", startX + (i - 1) * (w + gap), 0) else f:SetPoint("CENTER", uViewer, "CENTER", startX + (i - 1) * (w + gap), 0) end end
            end
            uViewer:Show(); uViewer:SetAlpha(1)
        else uViewer:Hide() end
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

                for i = 1, r1c do local f = cachedR1[i]; f:ClearAllPoints(); local xOff = startX1 + (i - 1) * (w1 + gap); if targetAnchor then f:SetPoint("CENTER", targetAnchor, "CENTER", xOff, 0) else f:SetPoint("CENTER", eViewer, "CENTER", xOff, 0) end end
                
                local r2Anchor = _G["WishFlex_Anchor_EssentialR2"]
                if r2Anchor then
                    WeldToMover(r2Anchor, r2Anchor.mover)
                    local w2 = PixelSnap(cfgE.row2Width or 40); local h2 = PixelSnap(cfgE.row2Height or 40); local gap2 = PixelSnap(cfgE.row2IconGap or 2)
                    local totalW2 = (r2c * w2) + math.max(0, (r2c - 1) * gap2); local startX2 = -(totalW2 / 2) + (w2 / 2)
                    r2Anchor:SetSize(math.max(1, totalW2), math.max(1, h2)); if r2Anchor.mover then r2Anchor.mover:SetSize(r2Anchor:GetSize()) end
                    for i = 1, r2c do local f = cachedR2[i]; f:ClearAllPoints(); f:SetPoint("CENTER", r2Anchor, "CENTER", startX2 + (i - 1) * (w2 + gap2), 0) end
                end
            end
            eViewer:Show(); eViewer:SetAlpha(1)
        else eViewer:Hide() end
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

if WF.UI then
    CDMod.Sandbox = CDMod.Sandbox or {
        selectedRow = nil,
        selectedSpellForTracker = nil,
        scannedEssential = {}, scannedUtility = {}, scannedBuffIcon = {}, scannedBuffBar = {},
        RenderedLists = {},
        GlowPreviewBtns = {} 
    }

    local function GetSpecOptions()
        local playerClass = select(2, UnitClass("player"))
        local opts = {}
        if playerClass == "DRUID" then opts = { {text = L["Humanoid / None"] or "人形态 / 无形态", value = 1000}, {text = L["Cat Form"] or "猎豹形态", value = 1001}, {text = L["Bear Form"] or "熊形态", value = 1002}, {text = L["Moonkin Form"] or "枭兽形态", value = 1003}, {text = L["Travel Form"] or "旅行形态", value = 1004} }
        else local classID = select(3, UnitClass("player")); for i = 1, GetNumSpecializationsForClassID(classID) do local id, name = GetSpecializationInfoForClassID(classID, i); if id and name then table.insert(opts, {text = name, value = id}) end end; table.insert(opts, {text = L["No Spec / General"] or "无专精 / 通用", value = 0}) end
        return opts
    end

    function CDMod:UpdateSandboxGlows()
        if WF.GlowAPI and WF.db.glow and WF.db.glow.enable then
            if WF.UI.MainScrollChild and WF.UI.MainScrollChild.SandboxIconsPool then
                for _, btn in ipairs(WF.UI.MainScrollChild.SandboxIconsPool) do
                    WF.GlowAPI:Hide(btn.tex.wishBd or btn)
                end
            end
            for _, btn in ipairs(CDMod.Sandbox.GlowPreviewBtns or {}) do
                WF.GlowAPI:Show(btn)
            end
        end
    end

    function CDMod:ScanForSandbox()
        if not CDMod.Sandbox.scannedEssential then CDMod.Sandbox.scannedEssential = {} end
        if not CDMod.Sandbox.scannedUtility then CDMod.Sandbox.scannedUtility = {} end
        if not CDMod.Sandbox.scannedBuffIcon then CDMod.Sandbox.scannedBuffIcon = {} end
        if not CDMod.Sandbox.scannedBuffBar then CDMod.Sandbox.scannedBuffBar = {} end
        
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

        local showIcon = true
        if isBar and catCfg.showIcon == false then showIcon = false end

        local targetStack = btn
        local targetCD = btn
        
        if isBar then
            if showIcon then targetStack = btn.tex.wishBd or btn.tex or btn; targetCD = btn.barTex.wishBd or btn.barTex or btn
            else targetStack = btn.barTex.wishBd or btn.barTex or btn; targetCD = targetStack end
        else
            targetStack = btn.tex.wishBd or btn.tex or btn; targetCD = targetStack
        end

        if not btn.mockCd then btn.mockCd = btn:CreateFontString(nil, "OVERLAY", nil, 7) end
        btn.mockCd:SetFont(fontPath, cdSize or 18, outline)
        btn.mockCd:SetTextColor((cdColor and cdColor.r) or 1, (cdColor and cdColor.g) or 0.82, (cdColor and cdColor.b) or 0)
        btn.mockCd:ClearAllPoints(); btn.mockCd:SetPoint(cdPos or "CENTER", targetCD, cdPos or "CENTER", cdX or 0, cdY or 0); btn.mockCd:SetText("12")

        if not btn.mockStack then btn.mockStack = btn:CreateFontString(nil, "OVERLAY", nil, 7) end
        btn.mockStack:SetFont(fontPath, stackSize or 14, outline)
        btn.mockStack:SetTextColor((stackColor and stackColor.r) or 1, (stackColor and stackColor.g) or 1, (stackColor and stackColor.b) or 1)
        btn.mockStack:ClearAllPoints(); btn.mockStack:SetPoint(stackPos or "BOTTOMRIGHT", targetStack, stackPos or "BOTTOMRIGHT", stackX or 0, stackY or 0); btn.mockStack:SetText("3")
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
        
        if not CDMod.Sandbox.GlowPreviewBtns then CDMod.Sandbox.GlowPreviewBtns = {} end
        wipe(CDMod.Sandbox.GlowPreviewBtns)

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
            local barH = PixelSnap(catCfg.barHeight or h)
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
            bg.catName = catName; bg.rowID = rowID
            
            local bgTopY = startY + bgPadding
            bg:ClearAllPoints(); bg:SetSize(bgW, bgH); bg:SetPoint("TOP", canvas, "TOP", 0, bgTopY); bg:Show()

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
                
                if isVertical then
                    local curY = startY - (i - 1) * (itemH + gap)
                    if catCfg.growth == "UP" then curY = startY - contentH + itemH + (i - 1) * (itemH + gap) end
                    btn:ClearAllPoints(); btn:SetPoint("CENTER", canvas, "TOP", 0, curY - itemH/2)
                else
                    btn:ClearAllPoints(); btn:SetPoint("CENTER", canvas, "TOP", startX + (i - 1) * (w + gap), startY - itemH/2)
                end
                
                btn.tex:SetVertexColor(1, 1, 1, 1)
                btn.tex:SetTexture(item.icon)
                
                if catName == "BuffBar" then
                    if not btn.barTex then 
                        btn.barTex = btn:CreateTexture(nil, "ARTWORK")
                        btn.barTex:SetVertexColor(0.2, 0.6, 1, 1) 
                    end
                end
                
                StyleFrameCommon(btn, catCfg, w, h, catName, true)

                local bColor = {r=0, g=0, b=0, a=1}
                if CDMod.Sandbox.selectedSpellForTracker == btn.spellID then bColor = {r=1, g=0.6, b=0, a=1}
                elseif CDMod.Sandbox.selectedRow == rowID then bColor = {r=0, g=1, b=0, a=1} end
                
                local function SetBdColor(bd, c) 
                    if bd and bd.top then 
                        bd.top:SetColorTexture(c.r, c.g, c.b, c.a)
                        bd.bottom:SetColorTexture(c.r, c.g, c.b, c.a)
                        bd.left:SetColorTexture(c.r, c.g, c.b, c.a)
                        bd.right:SetColorTexture(c.r, c.g, c.b, c.a)
                    end 
                end
                SetBdColor(btn.tex.wishBd, bColor)
                if btn.barTex then SetBdColor(btn.barTex.wishBd, bColor) end
                btn:SetBackdropBorderColor(0,0,0,0) 
                
                if i == 1 then table.insert(CDMod.Sandbox.GlowPreviewBtns, btn.tex.wishBd or btn) end
                
                btn:SetScript("OnClick", function(self, button)
                    if self.isDragging then return end
                    if button == "RightButton" then
                        if CDMod.Sandbox.selectedSpellForTracker == self.spellID then CDMod.Sandbox.selectedSpellForTracker = nil 
                        else CDMod.Sandbox.selectedSpellForTracker = self.spellID end
                        CDMod.Sandbox.selectedRow = nil
                    else
                        if CDMod.Sandbox.selectedRow == self.rowID then CDMod.Sandbox.selectedRow = nil 
                        else CDMod.Sandbox.selectedRow = self.rowID end
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
                        local sID = tonumber(item.idStr); local success = false
                        if sID then success = pcall(function() GameTooltip:SetSpellByID(sID) end) end
                        if not success then GameTooltip:SetText(item.name) end
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine(L["Left Click: Select Row Layout"] or "|cff00ff00[左键]|r 选中整行进行排版设置", 1,1,1)
                        GameTooltip:AddLine(L["Right Click: Tracker"] or "|cffffaa00[右键]|r 设置此技能专属的褪色与发光效果", 1,1,1)
                        GameTooltip:Show() 
                    end 
                end)
                btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                
                btn:RegisterForDrag("LeftButton")
                btn:SetScript("OnDragStart", function(self)
                    self.isDragging = true; local currentLevel = self:GetFrameLevel() or 1
                    self.origFrameLevel = currentLevel; self:SetFrameLevel(math.min(65535, currentLevel + 50)) 
                    local cx, cy = GetCursorPosition(); local uiScale = self:GetEffectiveScale() 
                    self.cursorStartX = cx / uiScale; self.cursorStartY = cy / uiScale
                    local p, rt, rp, x, y = self:GetPoint(); self.origP, self.origRT, self.origRP = p, rt, rp; self.startX, self.startY = x, y
                    
                    self:SetScript("OnUpdate", function(s)
                        local ncx, ncy = GetCursorPosition(); ncx, ncy = ncx / uiScale, ncy / uiScale
                        s:ClearAllPoints(); s:SetPoint(s.origP, s.origRT, s.origRP, s.startX + (ncx - s.cursorStartX), s.startY + (ncy - s.cursorStartY))
                        local ind = scrollChild.Sandbox_DropIndicator; local scx, scy = s:GetCenter()
                        if not scx or not scy then return end
                        
                        local minDist = 9999; local closestBtn = nil; local targetBg = nil
                        
                        for j = 1, #scrollChild.SandboxIconsPool do
                            local other = scrollChild.SandboxIconsPool[j]
                            if other:IsShown() and other ~= s then
                                local isCombatSrc = (s.catName == "Essential" or s.catName == "Utility")
                                local isCombatTgt = (other.catName == "Essential" or other.catName == "Utility")
                                local canDrop = false
                                if isCombatSrc and isCombatTgt then canDrop = true elseif s.catName == other.catName then canDrop = true end
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
                                if (isCombatSrc and isCombatTgt) or (s.catName == cBg.catName) then targetBg = cBg; break end
                            end
                        end

                        if closestBtn and minDist < 40 then
                            local ox, oy = closestBtn:GetCenter(); s.dropTarget = closestBtn; s.dropMode = "btn"
                            if s.catName == "BuffBar" then
                                local isUpGrowth = (WF.db.cooldownCustom.BuffBar.growth == "UP")
                                if isUpGrowth then s.dropModeDir = (scy > oy) and "after" or "before" else s.dropModeDir = (scy > oy) and "before" or "after" end
                            else s.dropModeDir = (scx < ox) and "before" or "after" end
                            
                            ind:ClearAllPoints(); ind:SetParent(closestBtn:GetParent()); ind:SetFrameLevel(math.min(65535, closestBtn:GetFrameLevel() + 5))
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
                            s.dropTarget = targetBg; s.dropMode = "bg"
                            ind:ClearAllPoints(); ind:SetParent(targetBg); ind:SetFrameLevel(math.min(65535, targetBg:GetFrameLevel() + 2)); ind:SetAllPoints(targetBg)
                            ind.tex:SetColorTexture(0, 1, 0, 0.2); ind:Show()
                        else ind:Hide(); s.dropTarget = nil end
                    end)
                end)
                
                btn:SetScript("OnDragStop", function(self)
                    self.isDragging = false; self:SetScript("OnUpdate", nil)
                    self:SetFrameLevel(math.max(1, math.min(65535, self.origFrameLevel or 1)))
                    if scrollChild.Sandbox_DropIndicator then scrollChild.Sandbox_DropIndicator:Hide() end
                    
                    if self.dropTarget then
                        local srcCat = self.catName; local tgtCat = self.dropTarget.catName
                        local srcList = CDMod.Sandbox.RenderedLists[srcCat]; local tgtList = CDMod.Sandbox.RenderedLists[tgtCat]
                        if srcList and tgtList then
                            local myIdx
                            for idx, v in ipairs(srcList) do if v.idStr == self.spellID then myIdx = idx; break end end
                            if myIdx then
                                local myItem = table.remove(srcList, myIdx)
                                if self.dropMode == "bg" then
                                    if tgtCat == "Essential" and self.dropTarget.rowID == "Row1" then
                                        local maxR1 = WF.db.cooldownCustom.Essential.maxPerRow or 7; local eR1Count = math.min(#tgtList, maxR1)
                                        table.insert(tgtList, eR1Count + 1, myItem)
                                    else table.insert(tgtList, #tgtList + 1, myItem) end
                                else
                                    local targetIdx = 0
                                    for idx, v in ipairs(tgtList) do if v.idStr == self.dropTarget.spellID then targetIdx = idx; break end end
                                    if self.dropModeDir == "after" then table.insert(tgtList, targetIdx + 1, myItem) else table.insert(tgtList, targetIdx > 0 and targetIdx or 1, myItem) end
                                end
                                
                                local dbO = WF.db.cooldownCustom.spellOverrides; if not dbO then dbO = {}; WF.db.cooldownCustom.spellOverrides = dbO end
                                if not dbO[self.spellID] then dbO[self.spellID] = {} end
                                if srcCat ~= tgtCat then dbO[self.spellID].category = tgtCat end
                                
                                for idx, v in ipairs(tgtList) do if not dbO[v.idStr] then dbO[v.idStr] = {} end; dbO[v.idStr].sortIndex = idx end
                                if srcCat ~= tgtCat then for idx, v in ipairs(srcList) do if not dbO[v.idStr] then dbO[v.idStr] = {} end; dbO[v.idStr].sortIndex = idx end end
                            end
                        end
                    end
                    
                    self:ClearAllPoints(); if WF.UI.RefreshCurrentPanel then WF.UI:RefreshCurrentPanel() end; if WF.TriggerCooldownLayout then WF.TriggerCooldownLayout() end
                end)
                
                ApplyMockText(btn, db, catCfg, isRow2, catName == "BuffBar")
                if WF.AuraGlowAPI and WF.AuraGlowAPI.ApplyPreview then WF.AuraGlowAPI:ApplyPreview(btn.tex.wishBd or btn, btn.spellID, false) end
                
                btn:Show(); poolIdx = poolIdx + 1
            end
            
            return isVertical and contentH or itemH
        end

        local currentY = -15
        local cH = RenderGroup(bbList, db.BuffBar, "BuffBar", "BuffBar", currentY, false); currentY = currentY - cH - 12
        cH = RenderGroup(biList, db.BuffIcon, "BuffIcon", "BuffIcon", currentY, false); currentY = currentY - cH - 12
        cH = RenderGroup(eR1, db.Essential, "Essential", "Row1", currentY, false); currentY = currentY - cH - 12
        cH = RenderGroup(eR2, db.Essential, "Essential", "Row2", currentY, true); currentY = currentY - cH - 12
        cH = RenderGroup(uList, db.Utility, "Utility", "Utility", currentY, false); currentY = currentY - cH - 12

        if WF.db.auraGlow and WF.AuraGlowAPI then
            local agDB = WF.db.auraGlow
            local activeInds = {}
            local currentSpecID = 0
            pcall(function() currentSpecID = GetSpecializationInfo(GetSpecialization()) or 0 end)
            
            for sIDStr, cfg in pairs(agDB.spells) do
                if cfg.iconEnable and (not cfg.class or cfg.class == "ALL" or cfg.class == playerClass) then
                    local sSpec = tonumber(cfg.spec) or 0
                    if sSpec == 0 or sSpec == currentSpecID then table.insert(activeInds, tonumber(sIDStr)) end
                end
            end
            
            local previewInds = {}
            local maxPreviewCols = 6
            for i = 1, math.min(#activeInds, maxPreviewCols) do table.insert(previewInds, activeInds[i]) end
            
            if #previewInds > 0 then
                local indAnchor = scrollChild.Sandbox_IndAnchor
                if not indAnchor then
                    indAnchor = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
                    WF.UI.Factory.ApplyFlatSkin(indAnchor, 0.1, 0.1, 0.1, 0.3, 0.2, 0.2, 0.2, 0.6)
                    indAnchor.title = indAnchor:CreateFontString(nil, "OVERLAY")
                    indAnchor.title:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); indAnchor.title:SetPoint("BOTTOM", indAnchor, "TOP", 0, 4)
                    indAnchor.title:SetText(L["Independent Aura Glow"] or "触发时屏幕中央弹出的独立高亮图标组 (预览受限)")
                    scrollChild.Sandbox_IndAnchor = indAnchor
                end
                
                local cfg = agDB.independent
                local w = tonumber(cfg.size) or 45; local gap = tonumber(cfg.gap) or 2; local growth = cfg.growth or "LEFT"
                local numIcons = #previewInds
                local totalW = (numIcons * w) + math.max(0, (numIcons - 1) * gap)
                local bgW, bgH = totalW + 4, w + 4
                
                currentY = currentY - 20
                indAnchor:ClearAllPoints(); indAnchor:SetSize(bgW, bgH); indAnchor:SetPoint("TOP", canvas, "TOP", 0, currentY); indAnchor:Show()
                
                if not scrollChild.SandboxIndIconsPool then scrollChild.SandboxIndIconsPool = {} end
                for _, b in ipairs(scrollChild.SandboxIndIconsPool) do b:Hide() end
                
                local startX = -(totalW / 2) + (w / 2)
                for i, sID in ipairs(previewInds) do
                    local btn = scrollChild.SandboxIndIconsPool[i]
                    if not btn then
                        btn = CreateFrame("Button", nil, canvas, "BackdropTemplate")
                        btn:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
                        local tex = btn:CreateTexture(nil, "BACKGROUND")
                        tex:SetPoint("TOPLEFT", 1, -1); tex:SetPoint("BOTTOMRIGHT", -1, 1); tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
                        btn.tex = tex; scrollChild.SandboxIndIconsPool[i] = btn
                    end
                    
                    btn:SetParent(indAnchor); btn:SetSize(w, w); btn:ClearAllPoints()
                    
                    if growth == "CENTER_HORIZONTAL" then btn:SetPoint("CENTER", indAnchor, "CENTER", startX + (i - 1) * (w + gap), 0)
                    elseif growth == "LEFT" then if i == 1 then btn:SetPoint("RIGHT", indAnchor, "RIGHT", -2, 0) else btn:SetPoint("RIGHT", scrollChild.SandboxIndIconsPool[i-1], "LEFT", -gap, 0) end
                    elseif growth == "RIGHT" then if i == 1 then btn:SetPoint("LEFT", indAnchor, "LEFT", 2, 0) else btn:SetPoint("LEFT", scrollChild.SandboxIndIconsPool[i-1], "RIGHT", gap, 0) end
                    elseif growth == "UP" then if i == 1 then btn:SetPoint("BOTTOM", indAnchor, "BOTTOM", 0, 2) else btn:SetPoint("BOTTOM", scrollChild.SandboxIndIconsPool[i-1], "TOP", 0, gap) end
                    elseif growth == "DOWN" then if i == 1 then btn:SetPoint("TOP", indAnchor, "TOP", 0, -2) else btn:SetPoint("TOP", scrollChild.SandboxIndIconsPool[i-1], "BOTTOM", 0, -gap) end end
                    
                    local sInfo = nil; pcall(function() sInfo = C_Spell.GetSpellInfo(tonumber(sID)) end)
                    btn.tex:SetTexture(sInfo and sInfo.iconID or 134400)
                    
                    if CDMod.Sandbox.selectedSpellForTracker == tostring(sID) then btn:SetBackdropBorderColor(1, 0.6, 0, 1) else btn:SetBackdropBorderColor(0, 0, 0, 1) end
                    
                    btn:SetScript("OnClick", function(self, button)
                        if button == "RightButton" then
                            local strID = tostring(sID)
                            if CDMod.Sandbox.selectedSpellForTracker == strID then CDMod.Sandbox.selectedSpellForTracker = nil else CDMod.Sandbox.selectedSpellForTracker = strID end
                            CDMod.Sandbox.selectedRow = nil
                            if WF.UI.UpdateTargetWidth then local startW = WF.MainFrame:GetWidth(); WF.UI:RefreshCurrentPanel(); WF.MainFrame:SetWidth(startW); local targetReq = (CDMod.Sandbox.selectedRow or CDMod.Sandbox.selectedSpellForTracker) and 1050 or 950; WF.UI:UpdateTargetWidth(targetReq, true) else WF.UI:RefreshCurrentPanel() end
                        end
                    end)
                    btn:SetScript("OnEnter", function() GameTooltip:SetOwner(btn, "ANCHOR_RIGHT"); GameTooltip:SetSpellByID(tonumber(sID)); GameTooltip:AddLine(" "); GameTooltip:AddLine(L["Right Click: Tracker"] or "|cffffaa00[右键]|r 设置此技能专属的褪色与发光效果", 1,1,1); GameTooltip:Show() end)
                    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    
                    WF.AuraGlowAPI:ApplyPreview(btn, sID, true)
                    btn:Show()
                end
                currentY = currentY - bgH - 12
            else
                if scrollChild.Sandbox_IndAnchor then scrollChild.Sandbox_IndAnchor:Hide() end
                if scrollChild.SandboxIndIconsPool then for _, b in ipairs(scrollChild.SandboxIndIconsPool) do b:Hide() end end
            end
        end

        local boxWidth = math.max(10, (forcedWidth or 400) - 20)
        if currentMaxWidth > boxWidth and currentMaxWidth > 0 then
            local computedScale = math.max(0.1, boxWidth / currentMaxWidth)
            canvas:SetScale(computedScale)
        else
            canvas:SetScale(1)
        end
        
        if CDMod.UpdateSandboxGlows then CDMod:UpdateSandboxGlows() end
        
        return math.abs(currentY)
    end

    WF.UI:RegisterPanel("cooldownCustom_Global", function(scrollChild, ColW)
        local db = WF.db.cooldownCustom or {}; if not db.Essential then db.Essential = {} end; if not db.Utility then db.Utility = {} end
        WF.UI.MainScrollChild = scrollChild
        
        local targetWidth = (CDMod.Sandbox.selectedRow or CDMod.Sandbox.selectedSpellForTracker) and 1050 or 950
        ColW = targetWidth / 2.2
        
        local leftColW = 475
        local rightColW = targetWidth - leftColW - 35
        local leftX = 15
        local rightX = 15 + leftColW + 20

        local leftY = -10
        
        local help = scrollChild.Sandbox_Help or scrollChild:CreateFontString(nil, "OVERLAY")
        help:SetParent(scrollChild); help:ClearAllPoints(); help:SetPoint("TOPLEFT", leftX, leftY); help:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); help:SetWidth(leftColW); help:SetJustifyH("LEFT")
        help:SetText("|cff00ccff[排版引擎]|r |cff00ff00[左键]|r单击选中排版；|cffffaa00[右键]|r单击设置专属特效；拖拽图标跨组换绑；点击空白返回全局设置。")
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
            
            local agDB = WF.db.auraGlow or { spells = {} }
            if not agDB.spells then agDB.spells = {} end
            local spellAG = agDB.spells[spellIDStr]
            if not spellAG then
                spellAG = { glowEnable = true, iconEnable = false, iconGlowEnable = true, hideOriginal = false, duration = 0, spec = 0 }
                agDB.spells[spellIDStr] = spellAG
            end
            
            local specOpts = { {text="全部通用", value=0} }; for i = 1, 4 do local id, name = GetSpecializationInfo(i); if id and name then table.insert(specOpts, {text=name, value=id}) end end
            
            local trackerOpts = {
                { type = "group", key = "sb_trigger", text = "|cff00ffcc[1] 触发规则与参数 (技能: " .. sName .. ")|r", childs = {
                    { type = "dropdown", key = "spec", db = spellAG, text = "触发专精限制", options = specOpts },
                    { type = "slider", key = "duration", db = spellAG, text = "强制固定持续时间 (0为智能自动读取)", min=0, max=120, step=1 },
                }},
            }
            
            local visualOpts = {
                { type = "group", key = "sb_visual", text = "|cffffaa00[2] 视觉表现: 变灰、高亮与弹窗|r", childs = {
                    { type = "toggle", key = spellIDStr, db = trackerDB.desatSpells, text = "状态/距离异常变灰 (如：目标缺少痛楚)" },
                    { type = "toggle", key = spellIDStr, db = trackerDB.resourceSpells, text = "能量/资源不足变灰 (如：缺少星界能量)" },
                    { type = "toggle", key = "glowEnable", db = spellAG, text = "触发时: 原排版内图标产生覆盖发光" },
                    { type = "toggle", key = "iconEnable", db = spellAG, text = "触发时: 屏幕中央弹出独立的实体大图标" },
                    { type = "toggle", key = "iconGlowEnable", db = spellAG, text = "该独立大图标自身是否附带发光效果" },
                    { type = "toggle", key = "hideOriginal", db = spellAG, text = "触发时: 隐藏在增益排版里的原图标" },
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
                if WF.AuraGlowAPI and WF.AuraGlowAPI.UpdateGlows then WF.AuraGlowAPI:UpdateGlows(true) end
                if WF.TriggerCooldownLayout then WF.TriggerCooldownLayout() end
                if CDMod.DrawSandboxToUI then CDMod:DrawSandboxToUI() end
                if val == "UI_REFRESH" or type(val) == "string" then WF.UI:RefreshCurrentPanel() end
            end
            
            rightY = WF.UI:RenderOptionsGroup(scrollChild, rightX, rightY, rightColW, trackerOpts, HandleTrackerChange)
            
            local boxBg = scrollChild.AG_BuffIDBox_BG
            if not boxBg then
                boxBg = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
                WF.UI.Factory.ApplyFlatSkin(boxBg, 0.1, 0.1, 0.1, 0.5, 0, 0, 0, 1)
                
                local label = boxBg:CreateFontString(nil, "OVERLAY")
                label:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
                label:SetPoint("LEFT", boxBg, "LEFT", 10, 0)
                label:SetText("专属触发 Buff ID (空=默认跟随技能):")
                
                local box = CreateFrame("EditBox", nil, boxBg, "BackdropTemplate")
                box:SetSize(80, 20)
                box:SetPoint("RIGHT", boxBg, "RIGHT", -10, 0)
                box:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
                box:SetAutoFocus(false)
                box:SetTextInsets(5, 5, 0, 0)
                box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
                box:SetBackdropColor(0, 0, 0, 0.8)
                box:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
                
                box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
                boxBg.box = box
                scrollChild.AG_BuffIDBox_BG = boxBg
            end
            
            scrollChild.AG_BuffIDBox_BG.box:SetScript("OnEnterPressed", function(self)
                self:ClearFocus()
                local v = tonumber(self:GetText())
                if v then spellAG.buffID = v else spellAG.buffID = nil end
                HandleTrackerChange("UI_REFRESH")
            end)
            
            boxBg:SetParent(scrollChild)
            boxBg:SetSize(rightColW, 36)
            boxBg:ClearAllPoints()
            boxBg:SetPoint("TOPLEFT", rightX, rightY)
            if spellAG.buffID then boxBg.box:SetText(tostring(spellAG.buffID)) else boxBg.box:SetText("") end
            boxBg:Show()
            rightY = rightY - 45
            
            rightY = WF.UI:RenderOptionsGroup(scrollChild, rightX, rightY, rightColW, visualOpts, HandleTrackerChange)
            
        elseif CDMod.Sandbox.selectedRow then
            if scrollChild.AG_BuffIDBox_BG then scrollChild.AG_BuffIDBox_BG:Hide() end
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
                    { type = "toggle", key = "showIcon", db = db.BuffBar, text = "显示技能图标" },
                    { type = "dropdown", key = "iconPosition", db = db.BuffBar, text = "图标位置", options = IconPosOptions },
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
            if scrollChild.AG_BuffIDBox_BG then scrollChild.AG_BuffIDBox_BG:Hide() end
            local agDB = WF.db.auraGlow or {}
            local glowDB = WF.db.glow or {}
            
            local globalBaseOpts = {
                { type = "group", key = "cd_global_base", text = "【通用】排版与动画设定", childs = {
                    { type = "toggle", key = "enable", db = db, text = "启用排版管理模块", requireReload = true },
                    { type = "dropdown", key = "countFont", db = db, text = "全局数字字体", options = WF.UI.FontOptions },
                    { type = "color", key = "swipeColor", db = db, text = "默认冷却遮罩颜色" },
                    { type = "color", key = "activeAuraColor", db = db, text = "激活时冷却遮罩颜色" },
                    { type = "toggle", key = "reverseSwipe", db = db, text = "反转冷却转圈方向" },
                    { type = "toggle", key = "enableCustomLayout", db = db.Essential, text = "启用核心爆发分排布局" },
                    { type = "slider", key = "rowYGap", db = db.Essential, min = 0, max = 50, step = 1, text = "第二排Y轴间距" },
                }}
            }
            
            local nativeGlowOpts = {
                { type = "group", key = "native_glow_visuals", text = "【原生高亮】暴雪自带发光替换", childs = {
                    { type = "toggle", key = "enable", db = glowDB, text = "启用并接管暴雪原生发光", requireReload = true },
                    { type = "dropdown", key = "glowType", db = glowDB, text = "发光样式", options = {
                        {text = "像素边框 (Pixel)", value="pixel"}, 
                        {text = "自动施法 (Autocast)", value="autocast"}, 
                        {text = "暴雪默认 (Button)", value="button"}, 
                        {text = "高亮闪烁 (Proc)", value="proc"}
                    }},
                    { type = "toggle", key = "useCustomColor", db = glowDB, text = "使用自定义发光颜色" },
                    { type = "color", key = "color", db = glowDB, text = "自定义发光颜色" },
                }}
            }
            
            local nChilds = nativeGlowOpts[1].childs
            if glowDB.glowType == "pixel" then
                table.insert(nChilds, { type = "slider", key = "pixelLines", db = glowDB, min = 1, max = 20, step = 1, text = "发光线条数量" })
                table.insert(nChilds, { type = "slider", key = "pixelFrequency", db = glowDB, min = -2, max = 2, step = 0.05, text = "运动频率" })
                table.insert(nChilds, { type = "slider", key = "pixelLength", db = glowDB, min = 0, max = 50, step = 1, text = "线条长度" })
                table.insert(nChilds, { type = "slider", key = "pixelThickness", db = glowDB, min = 1, max = 10, step = 1, text = "线条粗细" })
                table.insert(nChilds, { type = "slider", key = "pixelXOffset", db = glowDB, min = -30, max = 30, step = 1, text = "X轴偏移" })
                table.insert(nChilds, { type = "slider", key = "pixelYOffset", db = glowDB, min = -30, max = 30, step = 1, text = "Y轴偏移" })
            elseif glowDB.glowType == "autocast" then
                table.insert(nChilds, { type = "slider", key = "autocastParticles", db = glowDB, min = 1, max = 20, step = 1, text = "粒子数" })
                table.insert(nChilds, { type = "slider", key = "autocastFrequency", db = glowDB, min = -2, max = 2, step = 0.05, text = "运动频率" })
                table.insert(nChilds, { type = "slider", key = "autocastScale", db = glowDB, min = 0.5, max = 3, step = 0.1, text = "整体缩放" })
                table.insert(nChilds, { type = "slider", key = "autocastXOffset", db = glowDB, min = -30, max = 30, step = 1, text = "X轴偏移" })
                table.insert(nChilds, { type = "slider", key = "autocastYOffset", db = glowDB, min = -30, max = 30, step = 1, text = "Y轴偏移" })
            elseif glowDB.glowType == "button" then
                table.insert(nChilds, { type = "slider", key = "buttonFrequency", db = glowDB, min = 0, max = 2, step = 0.05, text = "闪烁频率" })
            elseif glowDB.glowType == "proc" then
                table.insert(nChilds, { type = "slider", key = "procDuration", db = glowDB, min = 0.1, max = 5, step = 0.1, text = "动画持续时间" })
                table.insert(nChilds, { type = "slider", key = "procXOffset", db = glowDB, min = -30, max = 30, step = 1, text = "X轴偏移" })
                table.insert(nChilds, { type = "slider", key = "procYOffset", db = glowDB, min = -30, max = 30, step = 1, text = "Y轴偏移" })
            end
            
            local auraGlowOpts = {
                { type = "group", key = "ag_global_visuals", text = "【自定义高亮】BUFF触发高亮引擎", childs = {
                    { type = "toggle", key = "enable", db = agDB, text = "全面启用自定义高亮组件", requireReload = true },
                    { type = "dropdown", key = "glowType", db = agDB, text = "全局覆盖发光动画样式", options = {
                        {text = "像素边框 (Pixel)", value="pixel"}, 
                        {text = "自动施法 (Autocast)", value="autocast"}, 
                        {text = "暴雪默认 (Button)", value="button"}, 
                        {text = "高亮闪烁 (Proc)", value="proc"}
                    }},
                    { type = "toggle", key = "glowUseCustomColor", db = agDB, text = "使用自定义发光颜色" },
                    { type = "color", key = "glowColor", db = agDB, text = "自定义发光颜色" },
                }}
            }
            
            local agChilds = auraGlowOpts[1].childs
            if agDB.glowType == "pixel" then
                table.insert(agChilds, { type = "slider", key = "glowPixelLines", db = agDB, min = 1, max = 20, step = 1, text = "发光线条数量" })
                table.insert(agChilds, { type = "slider", key = "glowPixelFrequency", db = agDB, min = -2, max = 2, step = 0.05, text = "运动频率" })
                table.insert(agChilds, { type = "slider", key = "glowPixelLength", db = agDB, min = 0, max = 50, step = 1, text = "线条长度" })
                table.insert(agChilds, { type = "slider", key = "glowPixelThickness", db = agDB, min = 1, max = 10, step = 1, text = "线条粗细" })
                table.insert(agChilds, { type = "slider", key = "glowPixelXOffset", db = agDB, min = -30, max = 30, step = 1, text = "X轴偏移" })
                table.insert(agChilds, { type = "slider", key = "glowPixelYOffset", db = agDB, min = -30, max = 30, step = 1, text = "Y轴偏移" })
            elseif agDB.glowType == "autocast" then
                table.insert(agChilds, { type = "slider", key = "glowAutocastParticles", db = agDB, min = 1, max = 20, step = 1, text = "粒子数" })
                table.insert(agChilds, { type = "slider", key = "glowAutocastFrequency", db = agDB, min = -2, max = 2, step = 0.05, text = "运动频率" })
                table.insert(agChilds, { type = "slider", key = "glowAutocastScale", db = agDB, min = 0.5, max = 3, step = 0.1, text = "整体缩放" })
                table.insert(agChilds, { type = "slider", key = "glowAutocastXOffset", db = agDB, min = -30, max = 30, step = 1, text = "X轴偏移" })
                table.insert(agChilds, { type = "slider", key = "glowAutocastYOffset", db = agDB, min = -30, max = 30, step = 1, text = "Y轴偏移" })
            elseif agDB.glowType == "button" then
                table.insert(agChilds, { type = "slider", key = "glowButtonFrequency", db = agDB, min = 0, max = 2, step = 0.05, text = "闪烁频率" })
            elseif agDB.glowType == "proc" then
                table.insert(agChilds, { type = "slider", key = "glowProcDuration", db = agDB, min = 0.1, max = 5, step = 0.1, text = "动画持续时间" })
                table.insert(agChilds, { type = "slider", key = "glowProcXOffset", db = agDB, min = -30, max = 30, step = 1, text = "X轴偏移" })
                table.insert(agChilds, { type = "slider", key = "glowProcYOffset", db = agDB, min = -30, max = 30, step = 1, text = "Y轴偏移" })
            end
            
            table.insert(agChilds, { type = "slider", key = "size", db = agDB.independent, text = "独立弹窗图标尺寸", min = 10, max = 100, step = 1 })
            table.insert(agChilds, { type = "slider", key = "gap", db = agDB.independent, text = "独立弹窗图标间距", min = 0, max = 50, step = 1 })
            table.insert(agChilds, { type = "dropdown", key = "growth", db = agDB.independent, text = "独立弹窗排列方向", options = { {text="向左延伸",value="LEFT"}, {text="向右延伸",value="RIGHT"}, {text="向上延伸",value="UP"}, {text="向下延伸",value="DOWN"}, {text="中心对称展开",value="CENTER_HORIZONTAL"} } })

            local textOpts = {
                { type = "group", key = "ag_text_global", text = "【自定义高亮】倒数细节设置 (覆盖/独立)", childs = {
                    { type = "dropdown", key = "font", db = agDB.text, text = "共用文本字体", options = WF.UI.FontOptions },
                    { type = "slider", key = "fontSize", db = agDB.text, text = "共用文本大小", min = 8, max = 60, step = 1 },
                    { type = "dropdown", key = "fontOutline", db = agDB.text, text = "共用文本描边", options = { {text="无",value="NONE"}, {text="普通描边",value="OUTLINE"}, {text="粗描边",value="THICKOUTLINE"} } },
                    { type = "color", key = "color", db = agDB.text, text = "共用文本颜色" },
                    { type = "dropdown", key = "textAnchor", db = agDB.text, text = "共用文字锚点位置", options = WF.UI.AnchorOptions },
                    { type = "slider", key = "offsetX", db = agDB.text, text = "微调 X 轴偏移", min = -50, max = 50, step = 1 },
                    { type = "slider", key = "offsetY", db = agDB.text, text = "微调 Y 轴偏移", min = -50, max = 50, step = 1 },
                    
                    { type = "toggle", key = "enable", db = agDB.independentText, text = "★ 给独立图标单独设置字体 (不与覆盖层共用)" },
                }}
            }
            
            if agDB.independentText.enable then
                local indT = textOpts[1].childs
                table.insert(indT, { type = "slider", key = "fontSize", db = agDB.independentText, text = "独立文本大小", min = 8, max = 60, step = 1 })
                table.insert(indT, { type = "color", key = "color", db = agDB.independentText, text = "独立文本颜色" })
                table.insert(indT, { type = "dropdown", key = "textAnchor", db = agDB.independentText, text = "独立文字锚点位置", options = WF.UI.AnchorOptions })
                table.insert(indT, { type = "slider", key = "offsetX", db = agDB.independentText, text = "微调 X 轴偏移", min = -50, max = 50, step = 1 })
                table.insert(indT, { type = "slider", key = "offsetY", db = agDB.independentText, text = "微调 Y 轴偏移", min = -50, max = 50, step = 1 })
            end
            
            local function HandleNativeGlowChange(val)
                if WF.GlowAPI and WF.GlowAPI.RefreshAll then WF.GlowAPI:RefreshAll() end
                if CDMod.UpdateSandboxGlows then CDMod:UpdateSandboxGlows() end
                if val == "UI_REFRESH" or type(val) == "string" then WF.UI:RefreshCurrentPanel() end
            end
            
            local function HandleAuraGlowChange(val)
                if WF.AuraGlowAPI and WF.AuraGlowAPI.UpdateGlows then WF.AuraGlowAPI:UpdateGlows(true) end
                if CDMod.DrawSandboxToUI then CDMod:DrawSandboxToUI() end 
                if val == "UI_REFRESH" or type(val) == "string" then WF.UI:RefreshCurrentPanel() end
            end
            
            rightY = WF.UI:RenderOptionsGroup(scrollChild, rightX, rightY, rightColW, globalBaseOpts, HandleCDChange)
            rightY = WF.UI:RenderOptionsGroup(scrollChild, rightX, rightY, rightColW, nativeGlowOpts, HandleNativeGlowChange)
            rightY = WF.UI:RenderOptionsGroup(scrollChild, rightX, rightY, rightColW, auraGlowOpts, HandleAuraGlowChange)
            rightY = WF.UI:RenderOptionsGroup(scrollChild, rightX, rightY, rightColW, textOpts, HandleAuraGlowChange)
        end

        return math.min(leftY, rightY), targetWidth
    end)
end