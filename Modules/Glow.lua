local AddonName, ns = ...
local WF = ns.WF
local L = ns.L

-- =========================================
-- [加载外部库]
-- =========================================
local LCG = LibStub("LibCustomGlow-1.0", true)

-- 创建本模块 API (暴露给核心和其他模块)
local Glow = {}
WF.GlowAPI = Glow 

local GLOW_KEY = "WishFlex_PIXEL_GLOW"

-- =========================================
-- [默认配置]
-- =========================================
local DefaultConfig = {
    enable = true, 
    lines = 8, 
    frequency = 0.2, 
    thickness = 2, 
    color = { r = 0, g = 1, b = 0.5, a = 1 } 
}

-- =========================================
-- [核心发光控制功能]
-- =========================================
function Glow:Show(button)
    if not LCG or not button then return end
    
    local db = WF.db.glow
    if not db or not db.enable then return end

    -- 隐藏暴雪原生的发光材质
    if button.SpellActivationAlert then 
        button.SpellActivationAlert:Hide() 
        button.SpellActivationAlert:SetAlpha(0)
    end
    if button.overlay then
        button.overlay:Hide()
    end

    -- 启动 LibCustomGlow 的像素发光
    local color = { db.color.r, db.color.g, db.color.b, db.color.a }
    LCG.PixelGlow_Start(button, color, db.lines or 8, db.frequency or 0.2, nil, db.thickness or 2, 0, 0, false, GLOW_KEY)
end

function Glow:Hide(button)
    if not LCG or not button then return end
    LCG.PixelGlow_Stop(button, GLOW_KEY)
end

-- =========================================
-- [模块初始化与挂钩]
-- =========================================
local function InitGlow()
    -- 1. 初始化数据库与默认值
    if not WF.db.glow then WF.db.glow = {} end
    local db = WF.db.glow
    for k, v in pairs(DefaultConfig) do
        if db[k] == nil then db[k] = v end
    end

    if not db.enable then return end

    -- 2. 挂钩暴雪原生的动作条发光事件
    -- 这样当游戏触发技能可用(Proc)时，就会自动使用我们的发光替换
    if ActionButton_ShowOverlayGlow then
        hooksecurefunc("ActionButton_ShowOverlayGlow", function(button)
            Glow:Show(button)
        end)
    end

    if ActionButton_HideOverlayGlow then
        hooksecurefunc("ActionButton_HideOverlayGlow", function(button)
            Glow:Hide(button)
        end)
    end
end

-- 注册到 WishFlex 核心引擎
WF:RegisterModule("glow", L["Action Button Glow"] or "动作条按钮发光", InitGlow)