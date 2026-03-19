local AddonName, ns = ...

-- ==========================================
-- [1. 创建核心框架对象]
-- ==========================================
local WF = CreateFrame("Frame", "WishFlexCore")
_G.WishFlex = WF
ns.WF = WF 

WF.Title = "|cff00ffccWishFlex|r"
WF.ModulesRegistry = {}
ns.L = ns.L or {}

-- ==========================================
-- [2. 完美接管并注册所有材质与字体 (LibSharedMedia)]
-- [核心修正]：在文件加载的最早期直接执行，不依赖任何登录事件！
-- 这样 Plater, WeakAuras, Details, ElvUI 等所有插件都能第一时间读取到。
-- ==========================================
local function LoadSharedMedia()
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        -- 注册状态条材质
        LSM:Register("statusbar", "WishMouseover", [[Interface\AddOns\WishFlex\Media\Textures\WishMouseover.tga]])
        LSM:Register("statusbar", "WishTarget", [[Interface\AddOns\WishFlex\Media\Textures\WishTarget.tga]])
        LSM:Register("statusbar", "Wishq1", [[Interface\AddOns\WishFlex\Media\Textures\Wishq1.tga]])
        LSM:Register("statusbar", "WishFlex-clean", [[Interface\AddOns\WishFlex\Media\Textures\WishUI-clean.tga]])
        LSM:Register("statusbar", "Wish2", [[Interface\AddOns\WishFlex\Media\Textures\Wish2.tga]])
        LSM:Register("statusbar", "Wish3", [[Interface\AddOns\WishFlex\Media\Textures\Wish3.tga]])
        LSM:Register("statusbar", "Melli", [[Interface\AddOns\WishFlex\Assets\Melli.tga]])

        -- 注册自定义字体
        LSM:Register("font", "Wish-Pannetje", [[Interface\AddOns\WishFlex\Media\Fonts\pannetje.ttf]], 255)
        LSM:Register("font", "Wish-AvantGarde", [[Interface\AddOns\WishFlex\Media\Fonts\avantgarde.ttf]], 255)
        LSM:Register("font", "Wish-SG09", [[Interface\AddOns\WishFlex\Media\Fonts\SG09.ttf]], 255)
    end
end
LoadSharedMedia() -- 立刻执行！

-- ==========================================
-- [3. 模块注册系统]
-- ==========================================
function WF:RegisterModule(key, name, initFunc)
    self.ModulesRegistry[key] = {
        name = name,
        Init = initFunc
    }
end

-- ==========================================
-- [4. 暴雪编辑模式/锚点系统引擎]
-- ==========================================
function WF:CreateMover(frame, moverName, defaultPoint, width, height, titleText)
    if not frame then return end
    
    local mover = _G[moverName]
    if not mover then
        mover = CreateFrame("Frame", moverName, UIParent, "BackdropTemplate")
        mover:SetSize(width or 100, height or 40)
        mover:SetPoint(unpack(defaultPoint))
        mover:SetFrameStrata("HIGH")
        mover:SetMovable(true)
        mover:EnableMouse(true)
        mover:RegisterForDrag("LeftButton")
        mover:SetScript("OnDragStart", mover.StartMoving)
        mover:SetScript("OnDragStop", mover.StopMovingOrSizing)
        
        mover:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
        mover:SetBackdropColor(0, 1, 0, 0.3)
        mover:SetBackdropBorderColor(0, 1, 0, 1)
        
        mover.text = mover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        mover.text:SetPoint("CENTER")
        mover.text:SetText(titleText or moverName)
        mover:Hide()
        
        table.insert(WF.Movers, mover)
    end
    
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", mover, "CENTER")
    frame.mover = mover
    
    return mover
end

WF.Movers = {}
function WF:ToggleMovers()
    WF.MoversUnlocked = not WF.MoversUnlocked
    for _, mover in ipairs(WF.Movers) do
        if WF.MoversUnlocked then
            mover:Show()
        else
            mover:Hide()
        end
    end
end
SLASH_WISHFLEXMOVER1 = "/wfmove"
SlashCmdList["WISHFLEXMOVER"] = function() WF:ToggleMovers() end

-- ==========================================
-- [5. 小地图按钮]
-- ==========================================
function WF:InitMinimapIcon()
    local LDB = LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    
    if LDB and LDBIcon then
        local minimapData = LDB:NewDataObject("WishFlex", {
            type = "launcher",
            text = "WishFlex",
            icon = "Interface\\AddOns\\WishFlex\\Media\\Icons\\Logo3.tga",
            OnClick = function(_, button)
                if button == "LeftButton" then
                    if WF.ToggleUI then WF:ToggleUI() end
                elseif button == "RightButton" then
                    WF:ToggleMovers()
                end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine("|cff00ffccWishFlex|r")
                tooltip:AddLine("左键: 打开设置面板")
                tooltip:AddLine("右键: 解锁/锁定 锚点")
            end,
        })
        if not WF.db.minimap then WF.db.minimap = { hide = false } end
        LDBIcon:Register("WishFlex", minimapData, WF.db.minimap)
    end
end

-- ==========================================
-- [6. 核心初始化流程]
-- ==========================================
local function InitializeAddon()
    if not WishFlexDB then WishFlexDB = {} end
    WF.db = WishFlexDB

    WF:InitMinimapIcon()

    for key, data in pairs(WF.ModulesRegistry) do
        if WF.db[key] == nil then WF.db[key] = { enable = false } end
        if WF.db[key].enable then
            if type(data.Init) == "function" then
                data.Init()
                print("|cff00ffcc[WishFlex]|r " .. (ns.L["Module Loaded"] or "已加载模块:") .. " " .. data.name)
            end
        end
    end
    print("|cff00ffcc[WishFlex Core]|r 独立核心引擎已启动！输入 /wf 打开设置，/wfmove 解锁锚点。")
end

WF:RegisterEvent("PLAYER_LOGIN")
WF:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        InitializeAddon()
    end
end)