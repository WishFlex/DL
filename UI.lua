local AddonName, ns = ...
local WF = _G.WishFlex or ns.WF
ns.L = ns.L or {}
local L = ns.L

-- =========================================
-- [全局 UI 引擎 API 暴露]
-- =========================================
WF.UI = WF.UI or {}
WF.UI.Menus = {}
WF.UI.Panels = {}
WF.UI.CurrentNodeKey = "WF_HOME"

-- [新增] 原生重载(RL)弹窗定义
StaticPopupDialogs["WISHFLEX_RELOAD_UI"] = {
    text = L["One or more settings require a UI reload to take effect."] or "部分设置需要重载界面(RL)才能生效。",
    button1 = ACCEPT or "接受",
    button2 = CANCEL or "取消",
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function WF.UI:ShowReloadPopup()
    StaticPopup_Show("WISHFLEX_RELOAD_UI")
end

function WF.UI:RegisterMenu(menuData)
    table.insert(self.Menus, menuData)
end

function WF.UI:RegisterPanel(key, renderFunc)
    self.Panels[key] = renderFunc
end

function WF.UI:RefreshCurrentPanel()
    if WF.ScrollChild and self.CurrentNodeKey then
        local children = {WF.ScrollChild:GetChildren()}; for _, child in ipairs(children) do if type(child) == "table" and child.Hide then child:Hide() end end
        local regions = {WF.ScrollChild:GetRegions()}; for _, region in ipairs(regions) do if type(region) == "table" and region.Hide then region:Hide() end end
        if self.Panels[self.CurrentNodeKey] then
            local y = self.Panels[self.CurrentNodeKey](WF.ScrollChild, 320)
            WF.ScrollChild:SetHeight(math.abs(y) + 50)
        end
    end
end

-- =========================================
-- [布局常量与资源预设] 
-- =========================================
local FRAME_WIDTH = 900
local FRAME_HEIGHT = 650
local TITLE_HEIGHT = 35
local SIDEBAR_WIDTH_COLLAPSED = 40
local SIDEBAR_WIDTH_EXPANDED = 200

local ICON_ARROW = "Interface\\AddOns\\WishFlex\\Media\\Icons\\menu"
local ICON_CLOSE = "Interface\\AddOns\\WishFlex\\Media\\Icons\\off"
local ICON_LOGO = "Interface\\AddOns\\WishFlex\\Media\\Icons\\Logo2"

local LSM = LibStub("LibSharedMedia-3.0", true)
local FontOptions = {}
if LSM then
    for name, _ in pairs(LSM:HashTable("font")) do table.insert(FontOptions, {text = name, value = name}) end
    table.sort(FontOptions, function(a, b) return a.text < b.text end)
else
    FontOptions = { {text = "Expressway", value = "Expressway"} }
end
WF.UI.FontOptions = FontOptions

local AnchorOptions = {
    { text = L["TOPLEFT"] or "左上", value = "TOPLEFT" }, { text = L["TOP"] or "上方", value = "TOP" }, { text = L["TOPRIGHT"] or "右上", value = "TOPRIGHT" },
    { text = L["LEFT"] or "左侧", value = "LEFT" }, { text = L["CENTER"] or "居中", value = "CENTER" }, { text = L["RIGHT"] or "右侧", value = "RIGHT" },
    { text = L["BOTTOMLEFT"] or "左下", value = "BOTTOMLEFT" }, { text = L["BOTTOM"] or "下方", value = "BOTTOM" }, { text = L["BOTTOMRIGHT"] or "右下", value = "BOTTOMRIGHT" },
}
WF.UI.AnchorOptions = AnchorOptions

-- =========================================
-- [主题与颜色引擎]
-- =========================================
local _, playerClass = UnitClass("player")
local ClassColor = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass] or {r=1, g=1, b=1}
local CR, CG, CB = ClassColor.r, ClassColor.g, ClassColor.b

local function ApplyFlatSkin(frame, r, g, b, a, br, bg, bb, ba)
    if not frame:GetWidth() or frame:GetWidth() == 0 then frame:SetSize(10, 10) end
    if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    frame:SetBackdropColor(r or 0.1, g or 0.1, b or 0.1, a or 0.95)
    frame:SetBackdropBorderColor(br or 0, bg or 0, bb or 0, ba or 1)
end

local function CreateUIFont(parent, size, justify, isBold)
    local text = parent:CreateFontString(nil, "OVERLAY")
    local font = isBold and "Fonts\\ARKai_T.ttf" or STANDARD_TEXT_FONT
    text:SetFont(font, size or 13, "OUTLINE")
    text:SetJustifyH(justify or "LEFT")
    return text
end

local function ShowTooltipTemp(owner, text, r, g, b)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(text, r or 1, g or 1, b or 1)
    GameTooltip:Show()
    C_Timer.After(2, function() if GameTooltip:IsOwned(owner) then GameTooltip:Hide() end end)
end

-- =========================================
-- [高科技简约组件工厂]
-- =========================================
WF.UI.Factory = {}
local Factory = WF.UI.Factory

function Factory:CreateScrollArea(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10); scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)
    return scrollFrame, scrollChild
end

function Factory:CreateFlatButton(parent, textStr, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(120, 26)
    ApplyFlatSkin(btn, 0.15, 0.15, 0.15, 1, 0, 0, 0, 1)
    local text = CreateUIFont(btn, 13, "CENTER")
    text:SetPoint("CENTER"); text:SetText(textStr); text:SetTextColor(0.8, 0.8, 0.8)
    btn:SetScript("OnEnter", function() ApplyFlatSkin(btn, 0.2, 0.2, 0.2, 1, 0, 0, 0, 1); text:SetTextColor(1, 1, 1) end)
    btn:SetScript("OnLeave", function() ApplyFlatSkin(btn, 0.15, 0.15, 0.15, 1, 0, 0, 0, 1); text:SetTextColor(0.8, 0.8, 0.8) end)
    btn:SetScript("OnClick", onClick)
    return btn
end

function Factory:CreateToggle(parent, x, y, width, titleText, db, key, callback)
    local btn = CreateFrame("CheckButton", nil, parent)
    btn:SetSize(16, 16); btn:SetPoint("TOPLEFT", x, y); btn:SetChecked(db[key])
    ApplyFlatSkin(btn, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1)
    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetColorTexture(CR, CG, CB, 1); tex:SetPoint("TOPLEFT", 2, -2); tex:SetPoint("BOTTOMRIGHT", -2, 2); btn:SetCheckedTexture(tex)
    local text = CreateUIFont(btn, 13, "LEFT")
    text:SetPoint("LEFT", btn, "RIGHT", 10, 0); text:SetText(titleText); text:SetTextColor(0.9, 0.9, 0.9)
    btn:SetScript("OnClick", function(self) db[key] = self:GetChecked(); if callback then callback(db[key]) end end)
    return btn, y - 26
end

local sliderCounter = 0
function Factory:CreateSlider(parent, x, y, width, titleText, minVal, maxVal, step, db, key, callback)
    sliderCounter = sliderCounter + 1
    local sliderName = "WishFlexSlider_" .. key .. "_" .. sliderCounter
    local sliderWidth = width - 10
    local slider = CreateFrame("Slider", sliderName, parent)
    slider:SetSize(sliderWidth, 10); slider:SetPoint("TOPLEFT", x, y - 20)
    slider:SetOrientation("HORIZONTAL"); slider:SetMinMaxValues(minVal, maxVal); slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true); slider:SetValue(db[key] or minVal)
    ApplyFlatSkin(slider, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1)
    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(CR, CG, CB, 1); thumb:SetSize(6, 16); slider:SetThumbTexture(thumb)
    
    local title = CreateUIFont(slider, 12, "LEFT")
    title:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4); title:SetText(titleText); title:SetTextColor(0.7, 0.7, 0.7)
    local valText = CreateUIFont(slider, 12, "RIGHT")
    valText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 4); valText:SetText(string.format("%.2f", db[key] or minVal):gsub("%.00", "")); valText:SetTextColor(CR, CG, CB)
    
    slider:SetScript("OnValueChanged", function(self, value) db[key] = value; valText:SetText(string.format("%.2f", value):gsub("%.00", "")); if callback then callback(value) end end)
    return slider, y - 42
end

function Factory:CreateColorPicker(parent, x, y, width, titleText, db, key, callback)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(16, 16); btn:SetPoint("TOPLEFT", x, y)
    ApplyFlatSkin(btn, 0, 0, 0, 1, 0, 0, 0, 1)
    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 1, -1); tex:SetPoint("BOTTOMRIGHT", -1, 1)
    local function UpdateColor() local c = db[key] or {r=1,g=1,b=1,a=1}; tex:SetColorTexture(c.r, c.g, c.b, c.a or 1) end
    UpdateColor()

    local text = CreateUIFont(btn, 13, "LEFT")
    text:SetPoint("LEFT", btn, "RIGHT", 10, 0); text:SetText(titleText); text:SetTextColor(0.9, 0.9, 0.9)

    btn:SetScript("OnClick", function()
        local c = db[key] or {r=1,g=1,b=1,a=1}
        local function OnColorSet()
            local r, g, b = ColorPickerFrame:GetColorRGB(); local a = 1
            if ColorPickerFrame.GetColorAlpha then a = ColorPickerFrame:GetColorAlpha() elseif OpacitySliderFrame then a = OpacitySliderFrame:GetValue() end
            db[key] = {r=r, g=g, b=b, a=a}; UpdateColor(); if callback then callback() end
        end
        local function OnColorCancel(prev)
            db[key] = {r=prev.r, g=prev.g, b=prev.b, a=prev.opacity}; UpdateColor(); if callback then callback() end
        end
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({ r=c.r, g=c.g, b=c.b, opacity=c.a or 1, hasOpacity=true, swatchFunc=OnColorSet, opacityFunc=OnColorSet, cancelFunc=OnColorCancel })
        else
            ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = OnColorSet, OnColorSet, OnColorCancel
            ColorPickerFrame:SetColorRGB(c.r, c.g, c.b); ColorPickerFrame.hasOpacity = true; ColorPickerFrame.opacity = c.a or 1; ColorPickerFrame:Show()
        end
    end)
    return btn, y - 26
end

function Factory:CreateDropdown(parent, x, y, width, titleText, db, key, options, callback)
    local boxWidth = width - 10
    local title = CreateUIFont(parent, 12, "LEFT")
    title:SetPoint("TOPLEFT", x, y); title:SetText(titleText); title:SetTextColor(0.7, 0.7, 0.7)

    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(boxWidth, 22); btn:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    ApplyFlatSkin(btn, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1)

    local valText = CreateUIFont(btn, 12, "CENTER")
    valText:SetPoint("CENTER", btn, "CENTER", 0, 0); valText:SetTextColor(CR, CG, CB)
    local function GetOptText(val) for _, v in ipairs(options) do if v.value == val then return v.text end end return tostring(val) end
    valText:SetText(GetOptText(db[key]))

    local menu = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    ApplyFlatSkin(menu, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1)
    menu:SetFrameStrata("TOOLTIP"); menu:Hide()

    local showScroll = #options > 8
    menu:SetSize(boxWidth, (showScroll and 8 or #options) * 22 + 4)
    local scrollFrame = CreateFrame("ScrollFrame", nil, menu, showScroll and "UIPanelScrollFrameTemplate" or nil)
    scrollFrame:SetPoint("TOPLEFT", 4, -2); scrollFrame:SetPoint("BOTTOMRIGHT", showScroll and -26 or -4, 2)
    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(boxWidth - 30, #options * 22)
    scrollFrame:SetScrollChild(scrollChild)

    for i, opt in ipairs(options) do
        local item = CreateFrame("Button", nil, scrollChild)
        item:SetSize(boxWidth - 10, 22); item:SetPoint("TOPLEFT", 0, -(i-1)*22)
        local itxt = CreateUIFont(item, 12, "LEFT"); itxt:SetPoint("LEFT", 10, 0); itxt:SetText(opt.text)
        item:SetScript("OnEnter", function() ApplyFlatSkin(item, 0.15, 0.15, 0.15, 1, 0,0,0,0) end)
        item:SetScript("OnLeave", function() ApplyFlatSkin(item, 0, 0, 0, 0, 0,0,0,0) end)
        item:SetScript("OnClick", function()
            db[key] = opt.value; valText:SetText(opt.text); menu:Hide()
            if callback then callback(opt.value) end
        end)
    end
    btn:SetScript("OnClick", function() if menu:IsShown() then menu:Hide() else menu:Show() end end)
    return btn, y - 44
end

function Factory:CreateGroupHeader(parent, x, y, width, titleText, isExpanded, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, 26); btn:SetPoint("TOPLEFT", x, y)
    ApplyFlatSkin(btn, 0.1, 0.1, 0.1, 0.8, 0, 0, 0, 0)

    local accent = btn:CreateTexture(nil, "OVERLAY")
    accent:SetPoint("TOPLEFT"); accent:SetPoint("BOTTOMLEFT"); accent:SetWidth(2)
    accent:SetColorTexture(isExpanded and CR or 0.25, isExpanded and CG or 0.25, isExpanded and CB or 0.25, 1)

    local text = CreateUIFont(btn, 13, "LEFT")
    text:SetPoint("LEFT", 15, 0); text:SetText(titleText)
    text:SetTextColor(isExpanded and 1 or 0.7, isExpanded and 1 or 0.7, isExpanded and 1 or 0.7)

    local icon = btn:CreateTexture(nil, "OVERLAY")
    icon:SetSize(14, 14); icon:SetPoint("RIGHT", -8, 0); icon:SetTexture(ICON_ARROW)
    icon:SetRotation(isExpanded and -math.pi/2 or 0)
    icon:SetVertexColor(isExpanded and CR or 0.5, isExpanded and CG or 0.5, isExpanded and CB or 0.5, 1)

    btn:SetScript("OnEnter", function() ApplyFlatSkin(btn, 0.15, 0.15, 0.15, 1, 0, 0, 0, 0); accent:SetColorTexture(CR, CG, CB, 1); icon:SetVertexColor(CR, CG, CB, 1); text:SetTextColor(1, 1, 1) end)
    btn:SetScript("OnLeave", function() ApplyFlatSkin(btn, 0.1, 0.1, 0.1, 0.8, 0, 0, 0, 0); accent:SetColorTexture(isExpanded and CR or 0.25, isExpanded and CG or 0.25, isExpanded and CB or 0.25, 1); icon:SetVertexColor(isExpanded and CR or 0.5, isExpanded and CG or 0.5, isExpanded and CB or 0.5, 1); text:SetTextColor(isExpanded and 1 or 0.7, isExpanded and 1 or 0.7, isExpanded and 1 or 0.7) end)
    btn:SetScript("OnClick", function() PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON); if onClick then onClick() end end)
    return btn, y - 30
end

-- =========================================
-- [递归渲染引擎 - 引入弹窗拦截与强制刷新] 
-- =========================================
local GroupState = {}
function WF.UI:RenderOptionsGroup(parent, startX, startY, colWidth, options, onChange, level)
    local y = startY; level = level or 0
    local indent = level * 12
    local cx = startX + indent; local itemWidth = colWidth - indent

    for _, opt in ipairs(options) do
        if opt.type == "group" then
            if GroupState[opt.key] == nil then GroupState[opt.key] = false end
            local btn
            btn, y = Factory:CreateGroupHeader(parent, cx, y, itemWidth, opt.text, GroupState[opt.key], function()
                GroupState[opt.key] = not GroupState[opt.key]
                -- 【核心修复】强制立即刷新UI面板，彻底解决必须点其他地方才能展开折叠组的 Bug！
                WF.UI:RefreshCurrentPanel() 
                if type(onChange) == "function" then onChange("UI_REFRESH") end
            end)
            if GroupState[opt.key] and opt.childs then
                y = self:RenderOptionsGroup(parent, startX, y - 4, colWidth, opt.childs, onChange, level + 1); y = y - 6
            end
        elseif opt.type == "toggle" then 
            _, y = Factory:CreateToggle(parent, cx + 8, y, itemWidth, opt.text, opt.db, opt.key, function(val)
                if opt.requireReload then WF.UI:ShowReloadPopup() else if onChange then onChange(val) end end
            end)
        elseif opt.type == "slider" then 
            _, y = Factory:CreateSlider(parent, cx + 8, y, itemWidth, opt.text, opt.min, opt.max, opt.step, opt.db, opt.key, function(val)
                if opt.requireReload then WF.UI:ShowReloadPopup() else if onChange then onChange(val) end end
            end)
        elseif opt.type == "color" then 
            _, y = Factory:CreateColorPicker(parent, cx + 8, y, itemWidth, opt.text, opt.db, opt.key, function()
                if opt.requireReload then WF.UI:ShowReloadPopup() else if onChange then onChange() end end
            end)
        elseif opt.type == "dropdown" then 
            _, y = Factory:CreateDropdown(parent, cx + 8, y, itemWidth, opt.text, opt.db, opt.key, opt.options, function(val)
                if opt.requireReload then WF.UI:ShowReloadPopup() else if onChange then onChange(val) end end
            end)
        end
    end
    return y
end

function WF.UI:GetTextOptions(dbRef, prefix, titleStr, groupKey)
    return {
        type = "group", key = groupKey, text = titleStr, childs = {
            { type = "slider", key = prefix.."FontSize", db = dbRef, min = 8, max = 64, step = 1, text = L["Font Size"] or "字体大小" },
            { type = "dropdown", key = prefix.."Position", db = dbRef, text = L["Anchor"] or "锚点", options = AnchorOptions },
            { type = "slider", key = prefix.."XOffset", db = dbRef, min = -50, max = 50, step = 1, text = L["X Offset"] or "X 偏移" },
            { type = "slider", key = prefix.."YOffset", db = dbRef, min = -50, max = 50, step = 1, text = L["Y Offset"] or "Y 偏移" },
            { type = "color", key = prefix.."FontColor", db = dbRef, text = L["Color"] or "颜色" },
        }
    }
end

-- =========================================
-- [动画引擎]
-- =========================================
local animFrame = CreateFrame("Frame")
local function WF_AnimateRotation(texture, targetRad, duration)
    local startRad = texture._wf_rot or 0
    local startTime = GetTime()
    animFrame:SetScript("OnUpdate", function(self)
        local elapsed = GetTime() - startTime
        local progress = math.min(1, elapsed / duration)
        local currentRad = startRad + (targetRad - startRad) * progress
        texture:SetRotation(currentRad)
        texture._wf_rot = currentRad
        if progress >= 1 then self:SetScript("OnUpdate", nil) end
    end)
end

-- =========================================
-- [动态菜单树状构造引擎]
-- =========================================
local menuExpanded = {}
local function BuildMenuTree()
    local tree = {}; local map = {}
    for _, item in ipairs(WF.UI.Menus) do item.childs = {}; map[item.id] = item end
    for _, item in ipairs(WF.UI.Menus) do
        if item.parent and map[item.parent] then table.insert(map[item.parent].childs, item) else table.insert(tree, item) end
    end
    
    local function sortTree(node)
        table.sort(node, function(a, b) return (a.order or 99) < (b.order or 99) end)
        for _, child in ipairs(node) do sortTree(child.childs) end
    end
    sortTree(tree)
    
    local flat = {}
    local function flatten(node, lvl)
        for _, item in ipairs(node) do item.level = lvl; table.insert(flat, item); flatten(item.childs, lvl + 1) end
    end
    flatten(tree, 0)
    return flat
end

local function RenderTreeMenu()
    local sidebar = WF.MainFrame.Sidebar; local isExpanded = sidebar.isExpanded
    if not sidebar.buttons then sidebar.buttons = {} end
    for _, b in ipairs(sidebar.buttons) do b:Hide() end; wipe(sidebar.buttons)
    
    local yOffset = -50
    local activeIndicator = sidebar.activeIndicator
    if not activeIndicator then
        activeIndicator = sidebar:CreateTexture(nil, "OVERLAY")
        activeIndicator:SetWidth(3); activeIndicator:SetColorTexture(CR, CG, CB, 1)
        sidebar.activeIndicator = activeIndicator
    end

    local currentMenu = BuildMenuTree()

    local function AddBtn(item)
        local btn = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
        btn:SetHeight(28); btn:SetPoint("LEFT", 0, 0); btn:SetPoint("RIGHT", 0, 0); btn:SetPoint("TOP", 0, yOffset)
        ApplyFlatSkin(btn, 0.1, 0.1, 0.1, 0, 0,0,0,0)
        
        local xIndent = (item.level * 18)
        
        if item.icon then
            local tIcon = btn:CreateTexture(nil, "OVERLAY")
            tIcon:SetSize(18, 18); tIcon:SetPoint("LEFT", 10, 0); tIcon:SetTexture(item.icon)
            tIcon:SetVertexColor(0.6, 0.6, 0.6, 1); btn.tIcon = tIcon
            if item.type == "root" and item.id == "HOME" then tIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9) end
        end

        if item.type == "root" or item.type == "group" then
            if not item.icon then
                local icon = btn:CreateTexture(nil, "OVERLAY")
                icon:SetSize(14, 14); icon:SetPoint("LEFT", xIndent + 10, 0)
                icon:SetTexture(ICON_ARROW)
                icon._wf_rot = menuExpanded[item.id] and -math.pi/2 or 0
                icon:SetRotation(icon._wf_rot)
                icon:SetVertexColor(CR, CG, CB, 1)
                btn.arrowIcon = icon
            end
        end

        local text = CreateUIFont(btn, 13, "LEFT")
        text:SetPoint("LEFT", xIndent + 35, 0); text:SetText(item.name)
        
        if item.type == "root" then text:SetTextColor(CR, CG, CB)
        elseif item.type == "group" then text:SetTextColor(0.9, 0.8, 0.2) 
        else text:SetTextColor(0.6, 0.6, 0.6) end
        
        if not isExpanded then text:Hide() else text:Show() end

        btn:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            if item.type == "root" or item.type == "group" then menuExpanded[item.id] = not menuExpanded[item.id] end

            if not sidebar.isExpanded then
                sidebar.isExpanded = true; sidebar:SetWidth(SIDEBAR_WIDTH_EXPANDED)
                if sidebar.mIcon then WF_AnimateRotation(sidebar.mIcon, -math.pi/2, 0.2) end
            end

            if item.key then
                for _, b in ipairs(sidebar.buttons) do 
                    if b.tIcon then b.tIcon:SetVertexColor(0.6, 0.6, 0.6, 1) end
                    if b.text and b.itemType ~= "root" and b.itemType ~= "group" then b.text:SetTextColor(0.6, 0.6, 0.6) end 
                end
                text:SetTextColor(1, 1, 1); if btn.tIcon then btn.tIcon:SetVertexColor(CR, CG, CB, 1) end
                activeIndicator:ClearAllPoints(); activeIndicator:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0); activeIndicator:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0); activeIndicator:Show()
                
                WF.UI.CurrentNodeKey = item.key
                WF.UI:RefreshCurrentPanel()
                WF.MainFrame.TitleBar.titleText:SetText("|cffffffffW|cff00ffccF|r // "..item.name)
            end
            
            RenderTreeMenu()
        end)
        
        btn:SetScript("OnEnter", function()
            ApplyFlatSkin(btn, 0.2, 0.2, 0.2, 1, 0,0,0,0)
            if not sidebar.isExpanded then ShowTooltipTemp(btn, item.name, CR, CG, CB) end
        end)
        btn:SetScript("OnLeave", function()
            ApplyFlatSkin(btn, 0.1, 0.1, 0.1, 0, 0,0,0,0)
            if not sidebar.isExpanded and GameTooltip:IsOwned(btn) then GameTooltip:Hide() end
        end)
        
        btn.text = text; btn.itemType = item.type
        table.insert(sidebar.buttons, btn)
        yOffset = yOffset - 30
    end

    for _, item in ipairs(currentMenu) do
        if item.type == "root" then AddBtn(item)
        elseif isExpanded and item.parent and menuExpanded[item.parent] then
            local pNode = nil; for _, n in ipairs(currentMenu) do if n.id == item.parent then pNode = n; break end end
            if pNode and (pNode.type == "root" or (pNode.parent and menuExpanded[pNode.parent])) then AddBtn(item) end
        end
    end
end

-- =========================================
-- [主框架控制]
-- =========================================
function WF:ToggleUI()
    if not WF.MainFrame then
        local frame = CreateFrame("Frame", "WishFlexMainUI", UIParent, "BackdropTemplate")
        WF.MainFrame = frame
        frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT); frame:SetPoint("CENTER"); frame:SetMovable(true); frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton"); frame:SetScript("OnDragStart", frame.StartMoving); frame:SetScript("OnDragStop", frame.StopMovingOrSizing); frame:SetFrameStrata("DIALOG")
        frame:SetResizable(true); frame:SetResizeBounds(700, 500, 1400, 1000)
        ApplyFlatSkin(frame, 0.08, 0.08, 0.08, 0.95, CR, CG, CB, 1)

        local resizeGrip = CreateFrame("Button", nil, frame)
        resizeGrip:SetSize(16, 16); resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
        resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"); resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight"); resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        resizeGrip:SetScript("OnMouseDown", function(self, button) if button == "LeftButton" then frame:StartSizing("BOTTOMRIGHT") end end); resizeGrip:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() end)

        local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        sidebar:SetPoint("TOPLEFT", 1, -1); sidebar:SetPoint("BOTTOMLEFT", 1, 1)
        ApplyFlatSkin(sidebar, 0.1, 0.1, 0.1, 1, 0, 0, 0, 1)
        frame.Sidebar = sidebar

        local menuBtn = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
        menuBtn:SetSize(40, 26); menuBtn:SetPoint("TOP", 0, -10)
        local mIcon = menuBtn:CreateTexture(nil, "ARTWORK")
        mIcon:SetSize(16, 16); mIcon:SetPoint("CENTER"); mIcon:SetTexture(ICON_ARROW); mIcon:SetVertexColor(CR, CG, CB, 1)
        sidebar.mIcon = mIcon
        
        menuBtn:SetScript("OnEnter", function() if not sidebar.isExpanded then ShowTooltipTemp(menuBtn, L["MENU"] or "菜单", CR, CG, CB) end end)
        menuBtn:SetScript("OnLeave", function() if GameTooltip:IsOwned(menuBtn) then GameTooltip:Hide() end end)
        menuBtn:SetScript("OnClick", function()
            sidebar.isExpanded = not sidebar.isExpanded
            sidebar:SetWidth(sidebar.isExpanded and SIDEBAR_WIDTH_EXPANDED or SIDEBAR_WIDTH_COLLAPSED)
            RenderTreeMenu()
            WF_AnimateRotation(mIcon, sidebar.isExpanded and -math.pi/2 or 0, 0.2)
        end)

        local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        titleBar:SetHeight(TITLE_HEIGHT); titleBar:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 1, 0); titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        ApplyFlatSkin(titleBar, 0.12, 0.12, 0.12, 1, 0, 0, 0, 1)
        frame.TitleBar = titleBar

        local titleText = CreateUIFont(titleBar, 14, "LEFT")
        titleText:SetPoint("LEFT", 15, 0); titleText:SetText("|cffffffffW|cff00ffccF|r // "..L["Home"]); titleBar.titleText = titleText

        local closeBtn = CreateFrame("Button", nil, titleBar)
        closeBtn:SetSize(20, 20); closeBtn:SetPoint("RIGHT", -8, 0)
        local cIcon = closeBtn:CreateTexture(nil, "ARTWORK"); cIcon:SetPoint("CENTER"); cIcon:SetSize(14, 14); cIcon:SetTexture(ICON_CLOSE); cIcon:SetVertexColor(0.6, 0.6, 0.6, 1)
        closeBtn:SetScript("OnEnter", function() cIcon:SetVertexColor(CR, CG, CB, 1) end); closeBtn:SetScript("OnLeave", function() cIcon:SetVertexColor(0.6, 0.6, 0.6, 1) end); closeBtn:SetScript("OnClick", function() frame:Hide() end)

        local content = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        content:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0); content:SetPoint("BOTTOMRIGHT", -1, 1); content:SetFrameLevel(frame:GetFrameLevel() + 1)
        local scrollFrame, scrollChild = Factory:CreateScrollArea(content)
        content.scrollFrame = scrollFrame; content.scrollChild = scrollChild
        frame.Content = content
        WF.ScrollChild = scrollChild
    end
    
    if not WF.MainFrame:IsShown() then
        wipe(GroupState); wipe(menuExpanded)
        local sidebar = WF.MainFrame.Sidebar
        sidebar.isExpanded = false; sidebar:SetWidth(SIDEBAR_WIDTH_COLLAPSED)
        if sidebar.mIcon then sidebar.mIcon:SetRotation(0) end

        RenderTreeMenu()
        
        local firstBtn = sidebar.buttons[1]
        if firstBtn then
            for _, b in ipairs(sidebar.buttons) do 
                if b.tIcon then b.tIcon:SetVertexColor(0.6, 0.6, 0.6, 1) end
                if b.text and b.itemType ~= "root" and b.itemType ~= "group" then b.text:SetTextColor(0.6, 0.6, 0.6) end 
            end
            firstBtn.text:SetTextColor(1, 1, 1)
            if firstBtn.tIcon then firstBtn.tIcon:SetVertexColor(CR, CG, CB, 1) end
            
            if sidebar.activeIndicator then
                sidebar.activeIndicator:ClearAllPoints()
                sidebar.activeIndicator:SetPoint("TOPLEFT", firstBtn, "TOPLEFT", 0, 0)
                sidebar.activeIndicator:SetPoint("BOTTOMLEFT", firstBtn, "BOTTOMLEFT", 0, 0)
                sidebar.activeIndicator:Show()
            end
            
            WF.UI.CurrentNodeKey = "WF_HOME"
            WF.UI:RefreshCurrentPanel()
            WF.MainFrame.TitleBar.titleText:SetText("|cffffffffW|cff00ffccF|r // "..(L["Home"] or "首页"))
        end
        WF.MainFrame:Show()
    else
        WF.MainFrame:Hide()
    end
end

SLASH_WISHFLEX1 = "/wf"
SLASH_WISHFLEX2 = "/wishflex"
SlashCmdList["WISHFLEX"] = function() WF:ToggleUI() end