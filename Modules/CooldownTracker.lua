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

-- 使用弱引用表来缓存 Frame 状态，防止内存泄漏和无限递归更新
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
            -- 安全挂钩，拦截所有试图显示或设置透明度的行为
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
    -- 防止由于修改透明度或颜色触发的无限循环钩子
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
    
    -- 1. 目标 DoT 缺失判定 (Desat)
    if inDesat then
        local swipe = frame.cooldownSwipeColor
        if swipe and type(swipe) == "table" and swipe.GetRGBA then
            local ok, r = pcall(swipe.GetRGBA, swipe)
            -- 如果 r 颜色通道为 0 (或者某些特定系统下)，判定为无效
            if ok and r and not (type(issecretvalue) == "function" and issecretvalue(r)) then 
                isActive = (r ~= 0) 
            else 
                isActive = true 
            end
        else
            isActive = true
        end
    end

    -- 2. 资源不足判定 (Resource)
    if isActive and inRes then
        local _, notEnoughPower = C_Spell.IsSpellUsable(spellID)
        if notEnoughPower then isActive = false end
    end

    -- 应用最终视觉效果
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

-- =========================================
-- [全局遍历与事件注册]
-- =========================================
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
    -- 1. 初始化数据库与默认值
    if not WF.db.cooldownTracker then WF.db.cooldownTracker = {} end
    local db = WF.db.cooldownTracker
    for k, v in pairs(DefaultConfig) do
        if db[k] == nil then db[k] = v end
    end

    if not db.enable then return end

    -- 2. 首次加载预设法术 ID (痛楚、吸血鬼之触、星涌术等示例)
    if db.isFirstInit then
        db.desatSpells[980] = true      -- 痛苦术 痛楚
        db.desatSpells[589] = true      -- 暗牧 吸血鬼之触
        db.resourceSpells[124467] = true -- 示例资源追踪法术
        db.isFirstInit = false
    end

    -- 3. 建立内存高速缓存集 (Set)
    wipe(Tracker.desatSpellSet)
    wipe(Tracker.resourceSpellSet)
    if db.desatSpells then 
        for id in pairs(db.desatSpells) do Tracker.desatSpellSet[id] = true end 
    end
    if db.resourceSpells then 
        for id in pairs(db.resourceSpells) do Tracker.resourceSpellSet[id] = true end 
    end

    -- 4. 注册更新事件 (利用 C_Timer.After 做高频事件节流)
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

    -- 初始执行一次
    -- 延迟 1 秒执行以确保暴雪 UI 已经生成了技能图标
    C_Timer.After(1, function()
        Tracker:RefreshAll()
    end)
end

-- 注册到 WishFlex 核心引擎
WF:RegisterModule("cooldownTracker", L["Cooldown Tracker"] or "技能可用性变灰", InitCooldownTracker)