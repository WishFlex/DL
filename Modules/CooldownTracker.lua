local AddonName, ns = ...
local WF = ns.WF
local L = ns.L

local Tracker = CreateFrame("Frame")
WF.CooldownTrackerAPI = Tracker

-- =========================================
-- [默认配置与状态]
-- =========================================
local DefaultConfig = {
    enable = true,
    isFirstInit = true, 
    enableDesat = true,
    desatSpells = {}, 
    enableResource = true,
    resourceSpells = {},
}

Tracker.desatSpellSet = {}
Tracker.resourceSpellSet = {}

-- 使用弱引用表来缓存 Frame 状态
local Wish_FrameData = setmetatable({}, { __mode = "k" })
local function GetFrameData(frame)
    local data = Wish_FrameData[frame]
    if not data then 
        data = {}
        Wish_FrameData[frame] = data 
    end
    return data
end

-- =========================================
-- [核心视觉处理引擎]
-- =========================================
local function SafeKillRedBorder(frame)
    local function killTex(tex)
        if tex and not tex._wishKilled then
            tex._wishKilled = true
            hooksecurefunc(tex, "SetAlpha", function(s, a) 
                if a > 0 and not s._wLock then 
                    s._wLock = true; s:SetAlpha(0); s._wLock = false 
                end 
            end)
            hooksecurefunc(tex, "Show", function(s) 
                if not s._wLock then 
                    s._wLock = true; s:Hide(); s._wLock = false 
                end 
            end)
            tex:SetAlpha(0)
            tex:Hide()
        end
    end
    killTex(frame.PandemicIcon)
    killTex(frame.CooldownFlash)
    killTex(frame.OutOfRange)
end

local function ApplyWishVisuals(frame)
    if not frame or not frame.Icon then return end
    local data = GetFrameData(frame)
    if data.isUpdating then return end 

    SafeKillRedBorder(frame)

    local info = frame.cooldownInfo or (frame.GetCooldownInfo and frame:GetCooldownInfo())
    local spellID = info and (info.overrideSpellID or info.spellID)
    if not spellID then return end

    local db = WF.db.cooldownTracker
    local inDesat = Tracker.desatSpellSet[spellID] and db.enableDesat
    local inRes = Tracker.resourceSpellSet[spellID] and db.enableResource

    if not inDesat and not inRes then
        if data.wishModified then
            data.isUpdating = true
            if frame.Cooldown then frame.Cooldown:SetDrawSwipe(true) end
            if frame.Icon.SetDesaturation then frame.Icon:SetDesaturation(0) else frame.Icon:SetDesaturated(false) end
            frame.Icon:SetVertexColor(1, 1, 1)
            data.wishModified = false
            data.isUpdating = false
        end
        return 
    end

    data.wishModified = true
    local isActive = true
    
    if inDesat then
        local swipe = frame.cooldownSwipeColor
        if swipe and type(swipe) == "table" and swipe.GetRGBA then
            local ok, r = pcall(swipe.GetRGBA, swipe)
            if ok and r and not (type(issecretvalue) == "function" and issecretvalue(r)) then 
                isActive = (r ~= 0) 
            else 
                isActive = true 
            end
        else
            isActive = true
        end
    end

    if isActive and inRes then
        local _, notEnoughPower = C_Spell.IsSpellUsable(spellID)
        if notEnoughPower then isActive = false end
    end

    data.isUpdating = true 
    if not isActive then
        if frame.Cooldown then frame.Cooldown:SetDrawSwipe(false) end
        if frame.Icon.SetDesaturation then frame.Icon:SetDesaturation(1) else frame.Icon:SetDesaturated(true) end
        frame.Icon:SetVertexColor(0.6, 0.6, 0.6)
    else
        if frame.Cooldown then frame.Cooldown:SetDrawSwipe(true) end
        if frame.Icon.SetDesaturation then frame.Icon:SetDesaturation(0) else frame.Icon:SetDesaturated(false) end
        frame.Icon:SetVertexColor(1, 1, 1)
    end
    data.isUpdating = false 
end

local function HookFrame(frame)
    local data = GetFrameData(frame)
    if not frame or data.wishHooked then return end
    data.wishHooked = true

    local function triggerUpdate() ApplyWishVisuals(frame) end
    
    if frame.Cooldown then
        hooksecurefunc(frame.Cooldown, "SetCooldown", triggerUpdate)
        hooksecurefunc(frame.Cooldown, "Clear", triggerUpdate)
        if frame.Cooldown.SetSwipeColor then hooksecurefunc(frame.Cooldown, "SetSwipeColor", triggerUpdate) end
    end
    if frame.Icon then
        if frame.Icon.SetDesaturated then hooksecurefunc(frame.Icon, "SetDesaturated", triggerUpdate) end
        if frame.Icon.SetDesaturation then hooksecurefunc(frame.Icon, "SetDesaturation", triggerUpdate) end
        if frame.Icon.SetVertexColor then hooksecurefunc(frame.Icon, "SetVertexColor", triggerUpdate) end
    end
    
    triggerUpdate()
end

function Tracker:RefreshAll()
    if not WF.db.cooldownTracker.enable then return end
    
    local viewers = { _G.EssentialCooldownViewer, _G.UtilityCooldownViewer }
    for _, viewer in ipairs(viewers) do
        if viewer and viewer.itemFramePool then
            for frame in viewer.itemFramePool:EnumerateActive() do
                HookFrame(frame)
                ApplyWishVisuals(frame)
            end
        end
    end
end

local function InitCooldownTracker()
    if not WF.db.cooldownTracker then WF.db.cooldownTracker = {} end
    local db = WF.db.cooldownTracker
    for k, v in pairs(DefaultConfig) do
        if db[k] == nil then db[k] = v end
    end

    if db.isFirstInit then
        db.desatSpells["980"] = true      
        db.desatSpells["589"] = true      
        db.resourceSpells["124467"] = true 
        db.isFirstInit = false
    end

    wipe(Tracker.desatSpellSet)
    wipe(Tracker.resourceSpellSet)
    
    -- [修复]：严格判断 v 的布尔值，忽略 false 的记录
    if db.desatSpells then for id, v in pairs(db.desatSpells) do if v then Tracker.desatSpellSet[tonumber(id)] = true end end end
    if db.resourceSpells then for id, v in pairs(db.resourceSpells) do if v then Tracker.resourceSpellSet[tonumber(id)] = true end end end

    if not db.enable then return end

    Tracker:RegisterEvent("PLAYER_TARGET_CHANGED")
    Tracker:RegisterEvent("UNIT_POWER_UPDATE")
    
    local powerUpdatePending = false
    Tracker:SetScript("OnEvent", function(self, event, unit)
        if event == "PLAYER_TARGET_CHANGED" then
            Tracker:RefreshAll()
        elseif event == "UNIT_POWER_UPDATE" then
            if unit == "player" and not powerUpdatePending then
                powerUpdatePending = true
                C_Timer.After(0.1, function() 
                    powerUpdatePending = false
                    Tracker:RefreshAll() 
                end)
            end
        end
    end)

    C_Timer.After(1, function() Tracker:RefreshAll() end)
end

WF:RegisterModule("cooldownTracker", L["Icon Desaturation"] or "自定义图标 (褪色)", InitCooldownTracker)