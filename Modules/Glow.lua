local AddonName, ns = ...
local WF = ns.WF
local L = ns.L or {}

local LCG = LibStub("LibCustomGlow-1.0", true)
local Glow = {}
WF.GlowAPI = Glow 

local GLOW_KEY = "WishFlex_CD_GLOW"

-- 创建一个弱引用表，用来记录当前所有正在发光的 Frame，防止内存泄漏
local activeGlowFrames = setmetatable({}, { __mode = "k" })

local DefaultConfig = {
    enable = true, 
    glowType = "pixel",
    useCustomColor = false,
    color = { r = 0.95, g = 0.95, b = 0.32, a = 1 },
    
    pixelLines = 8, pixelFrequency = 0.25, pixelLength = 0, pixelThickness = 2, pixelXOffset = 0, pixelYOffset = 0,
    autocastParticles = 4, autocastFrequency = 0.2, autocastScale = 1, autocastXOffset = 0, autocastYOffset = 0,
    buttonFrequency = 0,
    procDuration = 1, procXOffset = 0, procYOffset = 0
}

function Glow:Show(frame)
    if not LCG or not frame then return end
    local db = WF.db.glow

    -- 【核心优化】：无论是否启用，先强制清除旧的发光
    -- 这样当你在设置面板把“启用”关闭时，它也能立刻把正在亮的图标熄灭，不需要 RL！
    Glow:Hide(frame)
    
    if not db or not db.enable then return end

    local c = db.color or { r = 0.95, g = 0.95, b = 0.32, a = 1 }
    local colorArr = db.useCustomColor and {c.r, c.g, c.b, c.a} or nil
    
    if db.glowType == "pixel" then
        local len = db.pixelLength; if len == 0 then len = nil end
        LCG.PixelGlow_Start(frame, colorArr, db.pixelLines, db.pixelFrequency, len, db.pixelThickness, db.pixelXOffset, db.pixelYOffset, false, GLOW_KEY)
    elseif db.glowType == "autocast" then
        LCG.AutoCastGlow_Start(frame, colorArr, db.autocastParticles, db.autocastFrequency, db.autocastScale, db.autocastXOffset, db.autocastYOffset, GLOW_KEY)
    elseif db.glowType == "button" then
        local freq = db.buttonFrequency; if freq == 0 then freq = nil end
        LCG.ButtonGlow_Start(frame, colorArr, freq)
    elseif db.glowType == "proc" then
        LCG.ProcGlow_Start(frame, {color = colorArr, duration = db.procDuration, xOffset = db.procXOffset, yOffset = db.procYOffset, key = GLOW_KEY})
    end

    activeGlowFrames[frame] = true
end

function Glow:Hide(frame)
    if not LCG or not frame then return end
    LCG.PixelGlow_Stop(frame, GLOW_KEY)
    LCG.AutoCastGlow_Stop(frame, GLOW_KEY)
    LCG.ButtonGlow_Stop(frame)
    LCG.ProcGlow_Stop(frame, GLOW_KEY)
    
    activeGlowFrames[frame] = nil
end

function Glow:RefreshAll()
    for frame in pairs(activeGlowFrames) do
        self:Show(frame)
    end
    if WF.UpdateCooldownGlows then
        WF.UpdateCooldownGlows()
    end
end

local function InitGlow()
    if not WF.db.glow then WF.db.glow = {} end
    local db = WF.db.glow
    for k, v in pairs(DefaultConfig) do
        if db[k] == nil then db[k] = v end
    end
end

WF:RegisterModule("Glow", L["Core Glow"] or "发光引擎", InitGlow)


-- =========================================================================
-- [发光引擎 - UI 面板动态注入]
-- =========================================================================
if WF.UI then
    -- 设置 order = 2，刚好插入在 Global Settings(1) 和 Essential Skills(3) 的中间
    WF.UI:RegisterMenu({ id = "CD_Glow", parent = "CDManager", name = L["Core Glow"] or "核心发光", key = "cooldownCustom_Glow", order = 2 })

    local function HandleGlowChange(val)
        if WF.GlowAPI and WF.GlowAPI.RefreshAll then WF.GlowAPI:RefreshAll() end
        if val == "UI_REFRESH" then WF.UI:RefreshCurrentPanel() end
    end

    WF.UI:RegisterPanel("cooldownCustom_Glow", function(scrollChild, ColW)
        local glowDB = WF.db.glow or {}
        local glowOpts = {
            { type = "group", key = "cd_glow", text = L["Glow Settings"] or "发光设置", childs = {
                -- 发光支持实时刷新熄灭，所以不需要 requireReload = true
                { type = "toggle", key = "enable", db = glowDB, text = L["Enable"] or "启用" },
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
        
        local childs = glowOpts[1].childs
        if glowDB.glowType == "pixel" then
            table.insert(childs, { type = "slider", key = "pixelLines", db = glowDB, min = 1, max = 20, step = 1, text = L["Lines"] or "线条数量" })
            table.insert(childs, { type = "slider", key = "pixelFrequency", db = glowDB, min = -2, max = 2, step = 0.05, text = L["Frequency"] or "运动频率" })
            table.insert(childs, { type = "slider", key = "pixelLength", db = glowDB, min = 0, max = 50, step = 1, text = L["Length"] or "线条长度" })
            table.insert(childs, { type = "slider", key = "pixelThickness", db = glowDB, min = 1, max = 10, step = 1, text = L["Thickness"] or "线条粗细" })
            table.insert(childs, { type = "slider", key = "pixelXOffset", db = glowDB, min = -30, max = 30, step = 1, text = L["X Offset"] or "X 轴偏移" })
            table.insert(childs, { type = "slider", key = "pixelYOffset", db = glowDB, min = -30, max = 30, step = 1, text = L["Y Offset"] or "Y 轴偏移" })
        elseif glowDB.glowType == "autocast" then
            table.insert(childs, { type = "slider", key = "autocastParticles", db = glowDB, min = 1, max = 20, step = 1, text = L["Particles"] or "粒子数量" })
            table.insert(childs, { type = "slider", key = "autocastFrequency", db = glowDB, min = -2, max = 2, step = 0.05, text = L["Frequency"] or "运动频率" })
            table.insert(childs, { type = "slider", key = "autocastScale", db = glowDB, min = 0.5, max = 3, step = 0.1, text = L["Scale"] or "整体缩放" })
            table.insert(childs, { type = "slider", key = "autocastXOffset", db = glowDB, min = -30, max = 30, step = 1, text = L["X Offset"] or "X 轴偏移" })
            table.insert(childs, { type = "slider", key = "autocastYOffset", db = glowDB, min = -30, max = 30, step = 1, text = L["Y Offset"] or "Y 轴偏移" })
        elseif glowDB.glowType == "button" then
            table.insert(childs, { type = "slider", key = "buttonFrequency", db = glowDB, min = 0, max = 2, step = 0.05, text = L["Frequency"] or "闪烁频率" })
        elseif glowDB.glowType == "proc" then
            table.insert(childs, { type = "slider", key = "procDuration", db = glowDB, min = 0.1, max = 5, step = 0.1, text = L["Duration"] or "动画持续时间" })
            table.insert(childs, { type = "slider", key = "procXOffset", db = glowDB, min = -30, max = 30, step = 1, text = L["X Offset"] or "X 轴偏移" })
            table.insert(childs, { type = "slider", key = "procYOffset", db = glowDB, min = -30, max = 30, step = 1, text = L["Y Offset"] or "Y 轴偏移" })
        end
        
        return WF.UI:RenderOptionsGroup(scrollChild, 15, -10, ColW * 2, glowOpts, HandleGlowChange)
    end)
end