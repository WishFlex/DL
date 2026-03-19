local AddonName, ns = ...

-- ==========================================
-- [1. 创建核心框架对象]
-- ==========================================
local WF = CreateFrame("Frame", "WishFlexCore")
_G.WishFlex = WF  -- 暴露为全局变量，方便外部调用或调试
ns.WF = WF        -- 绑定到局部命名空间内部

WF.Title = "|cff00ffccWishFlex|r"
WF.ModulesRegistry = {}
ns.L = ns.L or {}

-- ==========================================
-- [2. 注册材质和字体 (LibSharedMedia)]
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
        
        -- 注册字体
    LSM:Register("font", "Wish-AvantGarde", [[Interface\AddOns\WishFlex\Media\Fonts\avantgarde.ttf]], 255)
    LSM:Register("font", "Wish-Pannetje", [[Interface\AddOns\WishFlex\Media\Fonts\pannetje.ttf]], 255)
    LSM:Register("font", "Wish-SG09", [[Interface\AddOns\WishFlex\Media\Fonts\SG09.ttf]], 255)
    end
end

-- ==========================================
-- [3. 核心 API：注册子模块]
-- ==========================================
function WF:RegisterModule(moduleKey, moduleName, initFunc)
    self.ModulesRegistry[moduleKey] = {
        name = moduleName,
        Init = initFunc
    }
end

-- ==========================================
-- [4. 暴雪编辑模式支持 (Mover API)]
-- ==========================================
function WF:CreateMover(frame, moverName, defaultPoint, width, height, labelText)
    -- 确保数据库的 movers 表存在
    if not WF.db.movers then WF.db.movers = {} end
    
    local mover = CreateFrame("Frame", moverName, UIParent, "BackdropTemplate")
    mover:SetSize(width or 200, height or 20)
    mover:SetFrameStrata("HIGH")
    
    -- 读取保存的位置，如果没有则使用默认位置
    if WF.db.movers[moverName] then
        local p = WF.db.movers[moverName]
        mover:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
    else
        if type(defaultPoint) == "table" then
            mover:SetPoint(unpack(defaultPoint))
        else
            mover:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end
    
    -- 绿色半透明编辑模式背景
    mover:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
    mover:SetBackdropColor(0, 1, 0, 0.3)
    mover:SetBackdropBorderColor(0, 1, 0, 0.8)
    mover:Hide() -- 默认隐藏，只有进入编辑模式才显示
    
    -- 允许鼠标交互和拖拽
    mover:EnableMouse(true)
    mover:SetMovable(true)
    mover:RegisterForDrag("LeftButton")
    
    local text = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER")
    text:SetText(labelText or moverName)
    
    mover:SetScript("OnDragStart", mover.StartMoving)
    mover:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        -- 拖拽结束后，将新坐标保存到数据库
        WF.db.movers[moverName] = {point = point, relativePoint = relativePoint, x = x, y = y}
    end)
    
    -- 将目标框架吸附到这个 Mover 上
    if frame then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", mover, "CENTER")
        frame.mover = mover
    end
    
    -- 【核心】：无缝挂钩暴雪原生编辑模式
    if EventRegistry then
        EventRegistry:RegisterCallback("EditMode_Enter", function() mover:Show() end)
        EventRegistry:RegisterCallback("EditMode_Exit", function() mover:Hide() end)
    end
    
    return mover
end

-- ==========================================
-- [5. 注册小地图快捷按钮 (Minimap API)]
-- ==========================================
function WF:InitMinimapIcon()
    local LDB = LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    
    if LDB and LDBIcon then
        local minimapData = LDB:NewDataObject("WishFlex", {
            type = "data source",
            text = "WishFlex",
            icon = [[Interface\AddOns\WishFlex\Media\Textures\Logo2.tga]], 
            OnClick = function(_, button)
                if button == "LeftButton" then
                    if WF.ToggleUI then WF:ToggleUI() end
                elseif button == "RightButton" then
                    -- 右键呼出暴雪编辑模式
                    if EditModeManagerFrame then ShowUIPanel(EditModeManagerFrame) end
                end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine(WF.Title)
                tooltip:AddLine(ns.L["Minimap_LeftClick"] or "|cff00ffcc左键:|r 打开设置中心")
                tooltip:AddLine(ns.L["Minimap_RightClick"] or "|cff00ffcc右键:|r 开启 UI 编辑模式")
            end
        })
        
        if not WF.db.minimap then WF.db.minimap = { hide = false } end
        LDBIcon:Register("WishFlex", minimapData, WF.db.minimap)
    end
end

-- ==========================================
-- [6. 核心初始化流程]
-- ==========================================
local function InitializeAddon()
    -- 1. 初始化本地数据库 (SavedVariables)
    if not WishFlexDB then WishFlexDB = {} end
    WF.db = WishFlexDB

    -- 2. 注册视觉材质
    LoadSharedMedia()

    -- 3. 启动小地图按钮
    WF:InitMinimapIcon()

    -- 4. 遍历并启动所有已注册的模块
    for key, data in pairs(WF.ModulesRegistry) do
        -- 确保数据库里有这个模块的配置表，默认关闭
        if WF.db[key] == nil then WF.db[key] = { enable = false } end
        
        -- 如果玩家启用了该模块，则执行初始化
        if WF.db[key].enable then
            if type(data.Init) == "function" then
                data.Init()
                print("|cff00ffcc[WishFlex]|r " .. (ns.L["Module Loaded"] or "已加载模块:") .. " " .. data.name)
            end
        end
    end
    
    print("|cff00ffcc[WishFlex Core]|r " .. (ns.L["Core Engine Active"] or "独立核心引擎已启动！输入 /wf 打开面板。"))
end

-- ==========================================
-- [7. 插件启动事件监听]
-- ==========================================
WF:RegisterEvent("ADDON_LOADED")
WF:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == AddonName then
        -- 当游戏读取完 WishFlex.toc 并加载了 WishFlexDB 变量后触发
        InitializeAddon()
        -- 核心启动完毕，注销此事件以节省资源
        self:UnregisterEvent("ADDON_LOADED")
    end
end)