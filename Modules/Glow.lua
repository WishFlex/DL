local AddonName, ns = ...
local WF = ns.WF
local L = ns.L or {}

local LCG = LibStub("LibCustomGlow-1.0", true)
local Glow = {}
WF.GlowAPI = Glow 

local GLOW_KEY = "WishFlex_CD_GLOW"

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