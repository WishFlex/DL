local AddonName, ns = ...
local WF = _G.WishFlex or ns.WF
ns.L = ns.L or {}
local L = ns.L

local FRAME_WIDTH, FRAME_HEIGHT, TITLE_HEIGHT = 900, 650, 35
local SIDEBAR_WIDTH_COLLAPSED, SIDEBAR_WIDTH_EXPANDED = 40, 200

local ICON_ARROW = "Interface\\ChatFrame\\ChatFrameExpandArrow"
local ICON_CLOSE = "Interface\\FriendsFrame\\ClearBroadcastIcon"
local ICON_LOGO  = "Interface\\Icons\\inv_misc_enggizmos_19"

local LSM = LibStub("LibSharedMedia-3.0", true)
local FontOptions, StatusbarOptions = {}, {}
if LSM then
    for name, _ in pairs(LSM:HashTable("font")) do table.insert(FontOptions, {text = name, value = name}) end
    table.sort(FontOptions, function(a, b) return a.text < b.text end)
    for name, _ in pairs(LSM:HashTable("statusbar")) do table.insert(StatusbarOptions, {text = name, value = name}) end
    table.sort(StatusbarOptions, function(a, b) return a.text < b.text end)
else
    FontOptions = { {text = "Expressway", value = "Expressway"} }
    StatusbarOptions = { {text = "Blizzard", value = "Interface\\TargetingFrame\\UI-StatusBar"} }
end

local AnchorOptions = {
    { text = "左上 (TOPLEFT)", value = "TOPLEFT" }, { text = "中上 (TOP)", value = "TOP" }, { text = "右上 (TOPRIGHT)", value = "TOPRIGHT" },
    { text = "左侧 (LEFT)", value = "LEFT" }, { text = "中心 (CENTER)", value = "CENTER" }, { text = "右侧 (RIGHT)", value = "RIGHT" },
    { text = "左下 (BOTTOMLEFT)", value = "BOTTOMLEFT" }, { text = "中下 (BOTTOM)", value = "BOTTOM" }, { text = "右下 (BOTTOMRIGHT)", value = "BOTTOMRIGHT" },
}
local OutlineOptions = {
    { text = "无描边", value = "NONE" }, { text = "细描边", value = "OUTLINE" }, { text = "粗描边", value = "THICKOUTLINE" }
}

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
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT"); GameTooltip:ClearLines(); GameTooltip:AddLine(text, r or 1, g or 1, b or 1); GameTooltip:Show()
    C_Timer.After(2, function() if GameTooltip:IsOwned(owner) then GameTooltip:Hide() end end)
end

local UI_Factory = {}
function UI_Factory:CreateScrollArea(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10); scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    local scrollChild = CreateFrame("Frame"); scrollChild:SetSize(scrollFrame:GetWidth(), 1); scrollFrame:SetScrollChild(scrollChild)
    return scrollFrame, scrollChild
end
function UI_Factory:CreateFlatButton(parent, textStr, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate"); btn:SetSize(120, 26); ApplyFlatSkin(btn, 0.15, 0.15, 0.15, 1, 0, 0, 0, 1)
    local text = CreateUIFont(btn, 13, "CENTER"); text:SetPoint("CENTER"); text:SetText(textStr); text:SetTextColor(0.8, 0.8, 0.8)
    btn:SetScript("OnEnter", function() ApplyFlatSkin(btn, 0.2, 0.2, 0.2, 1, 0, 0, 0, 1); text:SetTextColor(1, 1, 1) end)
    btn:SetScript("OnLeave", function() ApplyFlatSkin(btn, 0.15, 0.15, 0.15, 1, 0, 0, 0, 1); text:SetTextColor(0.8, 0.8, 0.8) end)
    btn:SetScript("OnClick", onClick); return btn
end
function UI_Factory:CreateToggle(parent, x, y, width, titleText, db, key, callback)
    local btn = CreateFrame("CheckButton", nil, parent); btn:SetSize(16, 16); btn:SetPoint("TOPLEFT", x, y); btn:SetChecked(db[key])
    ApplyFlatSkin(btn, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1); local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetColorTexture(CR, CG, CB, 1); tex:SetPoint("TOPLEFT", 2, -2); tex:SetPoint("BOTTOMRIGHT", -2, 2); btn:SetCheckedTexture(tex)
    local text = CreateUIFont(btn, 13, "LEFT"); text:SetPoint("LEFT", btn, "RIGHT", 10, 0); text:SetText(titleText); text:SetTextColor(0.9, 0.9, 0.9)
    btn:SetScript("OnClick", function(self) db[key] = self:GetChecked(); if callback then callback(db[key]) end end); return btn, y - 26
end
local sliderCounter = 0
function UI_Factory:CreateSlider(parent, x, y, width, titleText, minVal, maxVal, step, db, key, callback)
    sliderCounter = sliderCounter + 1; local sliderName = "WishFlexSlider_" .. key .. "_" .. sliderCounter
    local sliderWidth = width - 10; local slider = CreateFrame("Slider", sliderName, parent)
    slider:SetSize(sliderWidth, 10); slider:SetPoint("TOPLEFT", x, y - 20); slider:SetOrientation("HORIZONTAL"); slider:SetMinMaxValues(minVal, maxVal); slider:SetValueStep(step); slider:SetObeyStepOnDrag(true); slider:SetValue(db[key] or minVal)
    ApplyFlatSkin(slider, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1); local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(CR, CG, CB, 1); thumb:SetSize(6, 16); slider:SetThumbTexture(thumb)
    local title = CreateUIFont(slider, 12, "LEFT"); title:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4); title:SetText(titleText); title:SetTextColor(0.7, 0.7, 0.7)
    local valText = CreateUIFont(slider, 12, "RIGHT"); valText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 4); valText:SetText(string.format("%.2f", db[key] or minVal):gsub("%.00", "")); valText:SetTextColor(CR, CG, CB)
    slider:SetScript("OnValueChanged", function(self, value) db[key] = value; valText:SetText(string.format("%.2f", value):gsub("%.00", "")); if callback then callback(value) end end); return slider, y - 42
end
function UI_Factory:CreateColorPicker(parent, x, y, width, titleText, db, key, callback)
    local btn = CreateFrame("Button", nil, parent); btn:SetSize(16, 16); btn:SetPoint("TOPLEFT", x, y)
    ApplyFlatSkin(btn, 0, 0, 0, 1, 0, 0, 0, 1); local tex = btn:CreateTexture(nil, "ARTWORK"); tex:SetPoint("TOPLEFT", 1, -1); tex:SetPoint("BOTTOMRIGHT", -1, 1)
    local function UpdateColor() local c = db[key] or {r=1,g=1,b=1,a=1}; tex:SetColorTexture(c.r, c.g, c.b, c.a or 1) end; UpdateColor()
    local text = CreateUIFont(btn, 13, "LEFT"); text:SetPoint("LEFT", btn, "RIGHT", 10, 0); text:SetText(titleText); text:SetTextColor(0.9, 0.9, 0.9)
    btn:SetScript("OnClick", function()
        local c = db[key] or {r=1,g=1,b=1,a=1}
        local function OnColorSet() local r, g, b = ColorPickerFrame:GetColorRGB(); local a = 1; if ColorPickerFrame.GetColorAlpha then a = ColorPickerFrame:GetColorAlpha() elseif OpacitySliderFrame then a = OpacitySliderFrame:GetValue() end; db[key] = {r=r, g=g, b=b, a=a}; UpdateColor(); if callback then callback() end end
        local function OnColorCancel(prev) db[key] = {r=prev.r, g=prev.g, b=prev.b, a=prev.opacity}; UpdateColor(); if callback then callback() end end
        if ColorPickerFrame.SetupColorPickerAndShow then ColorPickerFrame:SetupColorPickerAndShow({ r=c.r, g=c.g, b=c.b, opacity=c.a or 1, hasOpacity=true, swatchFunc=OnColorSet, opacityFunc=OnColorSet, cancelFunc=OnColorCancel })
        else ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = OnColorSet, OnColorSet, OnColorCancel; ColorPickerFrame:SetColorRGB(c.r, c.g, c.b); ColorPickerFrame.hasOpacity = true; ColorPickerFrame.opacity = c.a or 1; ColorPickerFrame:Show() end
    end); return btn, y - 26
end
function UI_Factory:CreateDropdown(parent, x, y, width, titleText, db, key, options, callback)
    local boxWidth = width - 10; local title = CreateUIFont(parent, 12, "LEFT"); title:SetPoint("TOPLEFT", x, y); title:SetText(titleText); title:SetTextColor(0.7, 0.7, 0.7)
    local btn = CreateFrame("Button", nil, parent); btn:SetSize(boxWidth, 22); btn:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4); ApplyFlatSkin(btn, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1)
    local valText = CreateUIFont(btn, 12, "CENTER"); valText:SetPoint("CENTER", btn, "CENTER", 0, 0); valText:SetTextColor(CR, CG, CB)
    local function GetOptText(val) for _, v in ipairs(options) do if v.value == val then return v.text end end return tostring(val) end; valText:SetText(GetOptText(db[key]))
    local menu = CreateFrame("Frame", nil, btn, "BackdropTemplate"); menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2); ApplyFlatSkin(menu, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1); menu:SetFrameStrata("TOOLTIP"); menu:Hide()
    local showScroll = #options > 8; menu:SetSize(boxWidth, (showScroll and 8 or #options) * 22 + 4)
    local scrollFrame = CreateFrame("ScrollFrame", nil, menu, showScroll and "UIPanelScrollFrameTemplate" or nil); scrollFrame:SetPoint("TOPLEFT", 4, -2); scrollFrame:SetPoint("BOTTOMRIGHT", showScroll and -26 or -4, 2)
    local scrollChild = CreateFrame("Frame"); scrollChild:SetSize(boxWidth - 30, #options * 22); scrollFrame:SetScrollChild(scrollChild)
    for i, opt in ipairs(options) do
        local item = CreateFrame("Button", nil, scrollChild); item:SetSize(boxWidth - 10, 22); item:SetPoint("TOPLEFT", 0, -(i-1)*22)
        local itxt = CreateUIFont(item, 12, "LEFT"); itxt:SetPoint("LEFT", 10, 0); itxt:SetText(opt.text)
        item:SetScript("OnEnter", function() ApplyFlatSkin(item, 0.15, 0.15, 0.15, 1, 0,0,0,0) end); item:SetScript("OnLeave", function() ApplyFlatSkin(item, 0, 0, 0, 0, 0,0,0,0) end)
        item:SetScript("OnClick", function() db[key] = opt.value; valText:SetText(opt.text); menu:Hide(); if callback then callback(opt.value) end end)
    end
    btn:SetScript("OnClick", function() if menu:IsShown() then menu:Hide() else menu:Show() end end); return btn, y - 44
end
function UI_Factory:CreateEditBox(parent, x, y, width, titleText, db, key, callback)
    local boxWidth = width - 10; local title = CreateUIFont(parent, 12, "LEFT"); title:SetPoint("TOPLEFT", x, y); title:SetText(titleText); title:SetTextColor(0.7, 0.7, 0.7)
    local box = CreateFrame("EditBox", nil, parent); box:SetSize(boxWidth, 20); box:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4); box:SetFontObject("ChatFontNormal"); box:SetAutoFocus(false)
    ApplyFlatSkin(box, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1); box:SetText(db[key] or "")
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) db[key] = self:GetText(); self:ClearFocus(); if callback then callback(db[key]) end end)
    return box, y - 44
end
function UI_Factory:CreateGroupHeader(parent, x, y, width, titleText, isExpanded, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate"); btn:SetSize(width, 26); btn:SetPoint("TOPLEFT", x, y); ApplyFlatSkin(btn, 0.1, 0.1, 0.1, 0.8, 0, 0, 0, 0)
    local accent = btn:CreateTexture(nil, "OVERLAY"); accent:SetPoint("TOPLEFT"); accent:SetPoint("BOTTOMLEFT"); accent:SetWidth(2); accent:SetColorTexture(isExpanded and CR or 0.25, isExpanded and CG or 0.25, isExpanded and CB or 0.25, 1)
    local text = CreateUIFont(btn, 13, "LEFT"); text:SetPoint("LEFT", 15, 0); text:SetText(titleText); text:SetTextColor(isExpanded and 1 or 0.7, isExpanded and 1 or 0.7, isExpanded and 1 or 0.7)
    local icon = btn:CreateTexture(nil, "OVERLAY"); icon:SetSize(14, 14); icon:SetPoint("RIGHT", -8, 0); icon:SetTexture(ICON_ARROW); icon:SetRotation(isExpanded and -math.pi/2 or 0); icon:SetVertexColor(isExpanded and CR or 0.5, isExpanded and CG or 0.5, isExpanded and CB or 0.5, 1)
    btn:SetScript("OnEnter", function() ApplyFlatSkin(btn, 0.15, 0.15, 0.15, 1, 0, 0, 0, 0); accent:SetColorTexture(CR, CG, CB, 1); icon:SetVertexColor(CR, CG, CB, 1); text:SetTextColor(1, 1, 1) end)
    btn:SetScript("OnLeave", function() ApplyFlatSkin(btn, 0.1, 0.1, 0.1, 0.8, 0, 0, 0, 0); accent:SetColorTexture(isExpanded and CR or 0.25, isExpanded and CG or 0.25, isExpanded and CB or 0.25, 1); icon:SetVertexColor(isExpanded and CR or 0.5, isExpanded and CG or 0.5, isExpanded and CB or 0.5, 1); text:SetTextColor(isExpanded and 1 or 0.7, isExpanded and 1 or 0.7, isExpanded and 1 or 0.7) end)
    btn:SetScript("OnClick", function() PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON); if onClick then onClick() end end); return btn, y - 30
end

-- =========================================
-- [递归渲染引擎] (无记忆，每次打开均清空)
-- =========================================
local GroupState = {}
local function ResetGroupState() wipe(GroupState) end

local function RenderOptionsGroup(parent, startX, startY, colWidth, options, onChange, level)
    local y = startY; level = level or 0
    local indent = level * 12; local cx = startX + indent; local itemWidth = colWidth - indent

    for _, opt in ipairs(options) do
        if opt.type == "group" then
            if GroupState[opt.key] == nil then GroupState[opt.key] = false end
            local btn
            btn, y = UI_Factory:CreateGroupHeader(parent, cx, y, itemWidth, opt.text, GroupState[opt.key], function()
                GroupState[opt.key] = not GroupState[opt.key]; onChange("UI_REFRESH")
            end)
            if GroupState[opt.key] and opt.childs then y = RenderOptionsGroup(parent, startX, y - 4, colWidth, opt.childs, onChange, level + 1); y = y - 6 end
        elseif opt.type == "header" then
            local title = CreateUIFont(parent, 14, "LEFT", true); title:SetPoint("TOPLEFT", cx, y - 5); title:SetText(opt.text); title:SetTextColor(CR, CG, CB); y = y - 30
        elseif opt.type == "toggle" then _, y = UI_Factory:CreateToggle(parent, cx + 8, y, itemWidth, opt.text, opt.db, opt.key, onChange)
        elseif opt.type == "slider" then _, y = UI_Factory:CreateSlider(parent, cx + 8, y, itemWidth, opt.text, opt.min, opt.max, opt.step, opt.db, opt.key, onChange)
        elseif opt.type == "color" then _, y = UI_Factory:CreateColorPicker(parent, cx + 8, y, itemWidth, opt.text, opt.db, opt.key, onChange)
        elseif opt.type == "dropdown" then _, y = UI_Factory:CreateDropdown(parent, cx + 8, y, itemWidth, opt.text, opt.db, opt.key, opt.options, onChange)
        elseif opt.type == "input" then _, y = UI_Factory:CreateEditBox(parent, cx + 8, y, itemWidth, opt.text, opt.db, opt.key, onChange)
        elseif opt.type == "button" then
            local btn = UI_Factory:CreateFlatButton(parent, opt.text, opt.onClick)
            btn:ClearAllPoints(); btn:SetPoint("TOPLEFT", cx + 8, y); btn:SetWidth(itemWidth - 16); y = y - 36
        end
    end
    return y
end

-- =========================================
-- [PRO 级 资源条配置生成器 - 平铺排列]
-- =========================================
local function GetBarLayoutOptions(dbRef, keyPrefix)
    return {
        type = "group", key = keyPrefix.."_layout", text = "排版与材质 (Layout & Media)", childs = {
            { type = "toggle", key = "independent", db = dbRef, text = "独立分离 (脱离主框架自由排版)" },
            { type = "slider", key = "barXOffset", db = dbRef, min = -1000, max = 1000, step = 1, text = "独立排版 X轴偏移" },
            { type = "slider", key = "barYOffset", db = dbRef, min = -1000, max = 1000, step = 1, text = "独立排版 Y轴偏移" },
            { type = "slider", key = "height", db = dbRef, min = 2, max = 100, step = 1, text = "进度条独立高度" },
            { type = "toggle", key = "useCustomTexture", db = dbRef, text = "启用独立进度条材质" },
            { type = "dropdown", key = "texture", db = dbRef, text = "进度条材质", options = StatusbarOptions },
            { type = "toggle", key = "useCustomColor", db = dbRef, text = "启用独立前景色" },
            { type = "color", key = "customColor", db = dbRef, text = "进度条前景色" },
            { type = "toggle", key = "useCustomBgTexture", db = dbRef, text = "启用独立背景" },
            { type = "dropdown", key = "bgTexture", db = dbRef, text = "背景材质", options = StatusbarOptions },
            { type = "color", key = "bgColor", db = dbRef, text = "背景底色" },
        }
    }
end

local function GetBarTextOptions(dbRef, keyPrefix)
    return {
        type = "group", key = keyPrefix.."_text", text = "数值与时间文本 (Texts)", childs = {
            { type = "toggle", key = "textEnable", db = dbRef, text = "显示数值文本" },
            { type = "dropdown", key = "textFormat", db = dbRef, text = "文本格式", options = { {text="自动", value="AUTO"}, {text="百分比", value="PERCENT"}, {text="具体数值", value="ABSOLUTE"}, {text="当前 / 最大", value="BOTH"}, {text="隐藏", value="NONE"} } },
            { type = "dropdown", key = "font", db = dbRef, text = "字体", options = FontOptions },
            { type = "slider", key = "fontSize", db = dbRef, min = 8, max = 64, step = 1, text = "字号" },
            { type = "dropdown", key = "outline", db = dbRef, text = "描边", options = OutlineOptions },
            { type = "color", key = "color", db = dbRef, text = "颜色" },
            { type = "dropdown", key = "textAnchor", db = dbRef, text = "主文本对齐点", options = AnchorOptions },
            { type = "slider", key = "xOffset", db = dbRef, min = -100, max = 100, step = 1, text = "主文本 X轴偏移" },
            { type = "slider", key = "yOffset", db = dbRef, min = -100, max = 100, step = 1, text = "主文本 Y轴偏移" },
        }
    }
end

local function GetAuraLayoutOptions(dbRef, keyPrefix)
    return {
        type = "group", key = keyPrefix.."_layout", text = "增益排版与材质 (Layout & Media)", childs = {
            { type = "toggle", key = "independent", db = dbRef, text = "独立分离 (全组自由排版)" },
            { type = "slider", key = "barXOffset", db = dbRef, min = -1000, max = 1000, step = 1, text = "排版组 X轴偏移" },
            { type = "slider", key = "barYOffset", db = dbRef, min = -1000, max = 1000, step = 1, text = "排版组 Y轴偏移" },
            { type = "slider", key = "height", db = dbRef, min = 2, max = 100, step = 1, text = "全局进度条高度" },
            { type = "slider", key = "spacing", db = dbRef, min = 0, max = 50, step = 1, text = "多条垂直堆叠间距" },
            { type = "dropdown", key = "growth", db = dbRef, text = "组增长方向", options = {{text="向上堆叠", value="UP"}, {text="向下堆叠", value="DOWN"}} },
            { type = "toggle", key = "useCustomTexture", db = dbRef, text = "自定义保底材质" },
            { type = "dropdown", key = "texture", db = dbRef, text = "条材质", options = StatusbarOptions },
            { type = "color", key = "bgColor", db = dbRef, text = "增益条统一背景色" },
        }
    }
end

local function GetAuraTextOptions(dbRef, keyPrefix)
    return {
        type = "group", key = keyPrefix.."_text", text = "倒数与层数文本 (Texts)", childs = {
            { type = "header", text = "【倒计时文本 (Timer Text)】" },
            { type = "dropdown", key = "font", db = dbRef, text = "字体", options = FontOptions },
            { type = "slider", key = "fontSize", db = dbRef, min = 8, max = 64, step = 1, text = "字号" },
            { type = "dropdown", key = "outline", db = dbRef, text = "描边", options = OutlineOptions },
            { type = "color", key = "color", db = dbRef, text = "颜色" },
            { type = "dropdown", key = "textPosition", db = dbRef, text = "对齐位置", options = AnchorOptions },
            { type = "slider", key = "xOffset", db = dbRef, min = -100, max = 100, step = 1, text = "X偏移" },
            { type = "slider", key = "yOffset", db = dbRef, min = -100, max = 100, step = 1, text = "Y偏移" },

            { type = "header", text = "【层数文本 (Stack Text)】" },
            { type = "dropdown", key = "stackFont", db = dbRef, text = "层数字体", options = FontOptions },
            { type = "slider", key = "stackFontSize", db = dbRef, min = 8, max = 64, step = 1, text = "字号" },
            { type = "dropdown", key = "stackOutline", db = dbRef, text = "描边", options = OutlineOptions },
            { type = "color", key = "stackColor", db = dbRef, text = "颜色" },
            { type = "dropdown", key = "stackPosition", db = dbRef, text = "对齐位置", options = AnchorOptions },
            { type = "slider", key = "stackXOffset", db = dbRef, min = -100, max = 100, step = 1, text = "X偏移" },
            { type = "slider", key = "stackYOffset", db = dbRef, min = -100, max = 100, step = 1, text = "Y偏移" },
        }
    }
end

-- =========================================
-- [智能扫描引擎 (VFlow同步)]
-- =========================================
local function ScanActiveViewers()
    local results = {}
    -- 扫描自身 BUFF
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if aura and aura.spellId then results[aura.spellId] = { name = aura.name or "Unknown", icon = aura.icon } end
    end
    -- 扫描目标 DEBUFF
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("target", i, "HARMFUL")
        if aura and aura.spellId then results[aura.spellId] = { name = aura.name or "Unknown", icon = aura.icon } end
    end
    return results
end

-- =========================================
-- [3. 模块渲染派发]
-- =========================================
local RenderContentSettings
RenderContentSettings = function(nodeKey, scrollChild)
    local children = {scrollChild:GetChildren()}; for _, child in ipairs(children) do if type(child) == "table" and child.Hide then child:Hide() end end
    local regions = {scrollChild:GetRegions()}; for _, region in ipairs(regions) do if type(region) == "table" and region.Hide then region:Hide() end end

    local y = -10; local ColW = 320 

    local function HandleCDChange(val) if WF.TriggerCooldownLayout then WF.TriggerCooldownLayout() end; if val == "UI_REFRESH" then RenderContentSettings(nodeKey, scrollChild) end end
    local function HandleRCChange(val) if WF.ClassResourceAPI and WF.ClassResourceAPI.UpdateLayout then WF.ClassResourceAPI:UpdateLayout() end; if val == "UI_REFRESH" then RenderContentSettings(nodeKey, scrollChild) end end

    if nodeKey == "WF_HOME" then
        local logo = scrollChild:CreateTexture(nil, "ARTWORK"); logo:SetSize(48, 48); logo:SetPoint("TOPLEFT", 20, y); logo:SetTexture(ICON_LOGO)
        local title = CreateUIFont(scrollChild, 28, "LEFT", true); title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 15, -5); title:SetText("|cff00ffccWishFlex|r GeniSys"); title:SetTextColor(1, 1, 1)
        local sub = CreateUIFont(scrollChild, 14, "LEFT"); sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5); sub:SetText("专业的界面引擎"); sub:SetTextColor(0.6, 0.6, 0.6)
        y = y - 90
        local desc = CreateUIFont(scrollChild, 14, "LEFT"); desc:SetPoint("TOPLEFT", 20, y); desc:SetWidth(450); desc:SetSpacing(5); desc:SetText("轻量化、模块化、高性能的优化套装。"); desc:SetTextColor(0.8, 0.8, 0.8)
        y = y - 70
        local featureHead = CreateUIFont(scrollChild, 16, "LEFT", true); featureHead:SetPoint("TOPLEFT", 20, y); featureHead:SetText("核心功能:"); featureHead:SetTextColor(CR, CG, CB)
        y = y - 30
        local features = { "- 极致简约扁平化 UI", "- 高级冷却管理器 (含独立动画)", "- 专业资源条引擎 (支持平滑解密过滤)" }
        for _, fText in ipairs(features) do local f = CreateUIFont(scrollChild, 13, "LEFT"); f:SetPoint("TOPLEFT", 30, y); f:SetText(fText); f:SetTextColor(0.7, 0.7, 0.7); y = y - 22 end
        y = y - 20
        local qaHead = CreateUIFont(scrollChild, 16, "LEFT", true); qaHead:SetPoint("TOPLEFT", 20, y); qaHead:SetText("快捷操作"); qaHead:SetTextColor(CR, CG, CB)
        y = y - 30
        local reloadBtn = UI_Factory:CreateFlatButton(scrollChild, "重载界面", function() ReloadUI() end); reloadBtn:SetPoint("TOPLEFT", 20, y)
        local anchorBtn = UI_Factory:CreateFlatButton(scrollChild, "解锁锚点", function() if WF.ToggleMovers then WF:ToggleMovers() end end); anchorBtn:SetPoint("TOPLEFT", reloadBtn, "TOPRIGHT", 15, 0)
        
    elseif nodeKey == "rc_global" then
        local rcDB = WF.db.classResource or {}
        local specCfg = (WF.ClassResourceAPI and WF.ClassResourceAPI.cachedSpecCfg) or rcDB
        local opts = {
            { type = "group", key = "rc_global_base", text = "系统主控 (Master System)", childs = {
                { type = "toggle", key = "enable", db = rcDB, text = "全面启用职业资源条模块 (需重载 /rl)" },
                { type = "toggle", key = "hideElvUIBars", db = rcDB, text = "自动隐藏 ElvUI 原生能量条" },
                { type = "toggle", key = "alignWithCD", db = rcDB, text = "排版底层跟随 [冷却管理器] 第一排 自动对齐" },
                { type = "slider", key = "alignYOffset", db = rcDB, min = -50, max = 50, step = 1, text = "自动对齐时的 Y 轴下沉间距" },
                { type = "slider", key = "widthOffset", db = rcDB, min = -50, max = 50, step = 1, text = "自动对齐时的左右宽度补偿" },
                { type = "dropdown", key = "texture", db = rcDB, text = "系统全局保底材质", options = StatusbarOptions },
            }},
            { type = "group", key = "rc_global_spec", text = "当前专精开关 (环境记忆)", childs = {
                { type = "slider", key = "width", db = specCfg, min = 50, max = 800, step = 1, text = "堆叠排版时的统一总宽度 (开启自动跟随CD则失效)" },
                { type = "slider", key = "yOffset", db = specCfg, min = 0, max = 50, step = 1, text = "堆叠排版时的垂直间隙" },
                { type = "toggle", key = "showPower", db = specCfg, text = "启用 能量条 (Power Bar)" },
                { type = "toggle", key = "showClass", db = specCfg, text = "启用 主资源条 (连击点/符文/碎冰等)" },
                { type = "toggle", key = "showMana", db = specCfg, text = "启用 额外法力条 (治疗专精专属)" },
                { type = "toggle", key = "showAuraBar", db = specCfg, text = "启用 增益条组 (Aura Bar)" },
            }}
        }
        y = RenderOptionsGroup(scrollChild, 15, y, ColW * 2, opts, HandleRCChange)

    elseif nodeKey == "rc_power" then
        local specCfg = (WF.ClassResourceAPI and WF.ClassResourceAPI.cachedSpecCfg) or WF.db.classResource or {}
        if not specCfg.power then specCfg.power = {} end
        local ly = RenderOptionsGroup(scrollChild, 15, y, ColW, {GetBarLayoutOptions(specCfg.power, "power")}, HandleRCChange)
        local ry = RenderOptionsGroup(scrollChild, 345, y, ColW, {GetBarTextOptions(specCfg.power, "power")}, HandleRCChange)
        y = math.min(ly, ry)

    elseif nodeKey == "rc_class" then
        local specCfg = (WF.ClassResourceAPI and WF.ClassResourceAPI.cachedSpecCfg) or WF.db.classResource or {}
        if not specCfg.class then specCfg.class = {} end
        local ly = RenderOptionsGroup(scrollChild, 15, y, ColW, {GetBarLayoutOptions(specCfg.class, "class")}, HandleRCChange)
        local ry = RenderOptionsGroup(scrollChild, 345, y, ColW, {GetBarTextOptions(specCfg.class, "class")}, HandleRCChange)
        y = math.min(ly, ry)

    elseif nodeKey == "rc_mana" then
        local specCfg = (WF.ClassResourceAPI and WF.ClassResourceAPI.cachedSpecCfg) or WF.db.classResource or {}
        if not specCfg.mana then specCfg.mana = {} end
        local ly = RenderOptionsGroup(scrollChild, 15, y, ColW, {GetBarLayoutOptions(specCfg.mana, "mana")}, HandleRCChange)
        local ry = RenderOptionsGroup(scrollChild, 345, y, ColW, {GetBarTextOptions(specCfg.mana, "mana")}, HandleRCChange)
        y = math.min(ly, ry)

    elseif nodeKey == "rc_aura" then
        local specCfg = (WF.ClassResourceAPI and WF.ClassResourceAPI.cachedSpecCfg) or WF.db.classResource or {}
        if not specCfg.auraBar then specCfg.auraBar = {} end
        local ly = RenderOptionsGroup(scrollChild, 15, y, ColW, {GetAuraLayoutOptions(specCfg.auraBar, "aura")}, HandleRCChange)
        local ry = RenderOptionsGroup(scrollChild, 345, y, ColW, {GetAuraTextOptions(specCfg.auraBar, "aura")}, HandleRCChange)
        y = math.min(ly, ry)

    -- 【极致交互：VFlow 级双列增益扫描器】
    elseif nodeKey == "rc_scanner" then
        if not WishFlexDB.global then WishFlexDB.global = {} end
        if not WishFlexDB.global.spellDB then WishFlexDB.global.spellDB = {} end
        local sDB = WishFlexDB.global.spellDB

        local function RefreshAuraDB()
            if WF.ClassResourceAPI and WF.ClassResourceAPI.BuildAuraCache then WF.ClassResourceAPI:BuildAuraCache(); WF.ClassResourceAPI:UpdateLayout() end
            RenderContentSettings("rc_scanner", scrollChild)
        end

        local leftPanel = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
        leftPanel:SetSize(250, 500); leftPanel:SetPoint("TOPLEFT", 15, y)
        ApplyFlatSkin(leftPanel, 0.08, 0.08, 0.08, 1, 0.2, 0.2, 0.2, 1)

        local title = CreateUIFont(leftPanel, 14, "LEFT", true)
        title:SetPoint("TOPLEFT", 10, -10); title:SetText("扫描与管理缓存库"); title:SetTextColor(CR, CG, CB)

        local manualInput = CreateFrame("EditBox", nil, leftPanel); manualInput:SetSize(140, 24); manualInput:SetPoint("TOPLEFT", 10, -35); manualInput:SetFontObject("ChatFontNormal"); manualInput:SetAutoFocus(false)
        ApplyFlatSkin(manualInput, 0.15, 0.15, 0.15, 1, 0, 0, 0, 1)
        
        local addBtn = UI_Factory:CreateFlatButton(leftPanel, "添加 ID", function() 
            local id = tonumber(manualInput:GetText())
            if id then 
                if not sDB[tostring(id)] then sDB[tostring(id)] = {} end
                local d = sDB[tostring(id)]; d.buffID = id; d.class = playerClass; d.spec = GetSpecializationInfo(GetSpecialization()) or 0; d.hideOriginal = true
                d.auraBar = { enable = true, visibility = 1, inactiveAlpha = 1, mode = "time", trackType = "aura", overrideMax = false, maxStacks = 5, color = {r=0,g=0.8,b=1,a=1}, useThresholdColor = false, thresholdStacks = 3, thresholdColor = {r=1,g=0,b=0,a=1} }
                WishFlexDB.global.selectedAuraBarSpell = tostring(id); manualInput:SetText(""); RefreshAuraDB()
            end
        end)
        addBtn:SetSize(70, 24); addBtn:SetPoint("LEFT", manualInput, "RIGHT", 5, 0)

        local listScroll, listChild = UI_Factory:CreateScrollArea(leftPanel)
        listScroll:SetPoint("TOPLEFT", 5, -70); listScroll:SetPoint("BOTTOMRIGHT", -5, 5)

        local activeSpells = ScanActiveViewers()
        local mergedSpells = {}
        for k, v in pairs(sDB) do 
            local nm = "未知法术"; pcall(function() nm = C_Spell.GetSpellName(tonumber(k)) or nm end)
            local ic = 134400; pcall(function() ic = C_Spell.GetSpellTexture(tonumber(k)) or ic end)
            mergedSpells[tonumber(k)] = { name = nm, icon = ic, saved = true } 
        end
        for k, v in pairs(activeSpells) do if not mergedSpells[k] then mergedSpells[k] = { name = v.name, icon = v.icon, saved = false } end end

        local sortedSpells = {}
        for k, v in pairs(mergedSpells) do table.insert(sortedSpells, {id = k, name = v.name, icon = v.icon, saved = v.saved}) end
        table.sort(sortedSpells, function(a, b) if a.saved ~= b.saved then return a.saved end return a.name < b.name end)

        local listY = 0
        local selID = WishFlexDB.global.selectedAuraBarSpell
        
        for i, data in ipairs(sortedSpells) do
            local btn = CreateFrame("Button", nil, listChild, "BackdropTemplate")
            btn:SetSize(220, 28); btn:SetPoint("TOPLEFT", 5, listY)
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            
            local isSel = (tostring(data.id) == selID)
            ApplyFlatSkin(btn, isSel and 0.2 or 0.1, isSel and 0.2 or 0.1, isSel and 0.2 or 0.1, 1, 0,0,0,0)
            
            local icon = btn:CreateTexture(nil, "OVERLAY")
            icon:SetSize(20, 20); icon:SetPoint("LEFT", 4, 0); icon:SetTexture(data.icon); icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            
            local t = CreateUIFont(btn, 12, "LEFT")
            t:SetPoint("LEFT", icon, "RIGHT", 8, 0); t:SetText(data.name); t:SetWidth(130); t:SetWordWrap(false)
            t:SetTextColor(isSel and CR or 0.8, isSel and CG or 0.8, isSel and CB or 0.8)

            local isEnabled = false
            if data.saved and sDB[tostring(data.id)] and sDB[tostring(data.id)].auraBar and sDB[tostring(data.id)].auraBar.enable then isEnabled = true end

            local sText = CreateUIFont(btn, 10, "RIGHT")
            sText:SetPoint("RIGHT", -5, 0)
            if isEnabled then sText:SetText("|cff00ff00[启用]|r") elseif data.saved then sText:SetText("|cffaaaaaa[已存]|r") else sText:SetText("|cff555555[活跃]|r") end

            btn:SetScript("OnEnter", function() 
                ApplyFlatSkin(btn, 0.25, 0.25, 0.25, 1, 0,0,0,0) 
                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(data.id); GameTooltip:AddLine(" ")
                GameTooltip:AddLine("左键：选择并配置法术", 0, 1, 0)
                if data.saved then GameTooltip:AddLine("右键：取消追踪并删除", 1, 0, 0) end
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() ApplyFlatSkin(btn, isSel and 0.2 or 0.1, isSel and 0.2 or 0.1, isSel and 0.2 or 0.1, 1, 0,0,0,0); GameTooltip:Hide() end)
            
            btn:SetScript("OnClick", function(self, button)
                local idStr = tostring(data.id)
                if button == "RightButton" then
                    if data.saved then sDB[idStr] = nil; if WishFlexDB.global.selectedAuraBarSpell == idStr then WishFlexDB.global.selectedAuraBarSpell = nil end; RefreshAuraDB() end
                else
                    if not data.saved then
                        sDB[idStr] = { buffID = data.id, class = playerClass, spec = GetSpecializationInfo(GetSpecialization()) or 0, hideOriginal = true }
                        sDB[idStr].auraBar = { enable = true, visibility = 1, inactiveAlpha = 1, mode = "time", trackType = "aura", overrideMax = false, maxStacks = 5, color = {r=0,g=0.8,b=1,a=1}, useThresholdColor = false, thresholdStacks = 3, thresholdColor = {r=1,g=0,b=0,a=1} }
                    end
                    WishFlexDB.global.selectedAuraBarSpell = idStr; RefreshAuraDB()
                end
            end)
            listY = listY - 30
        end
        listChild:SetHeight(math.abs(listY))

        local rightOpts = {}
        if selID and sDB[selID] then
            local selData = sDB[selID]; local selAura = selData.auraBar or {}
            local spellName = "未知法术"; pcall(function() spellName = C_Spell.GetSpellName(tonumber(selID)) or spellName end)
            
            rightOpts = {
                { type = "header", text = spellName .. " ("..selID..") 的专属配置" },
                { type = "group", key = "scan_rules", text = "机制与规则", childs = {
                    { type = "toggle", key = "enable", db = selAura, text = "启用此法术追踪 (自动变为[启用]状态)" },
                    { type = "dropdown", key = "trackType", db = selAura, text = "监控机制", options = {{text="常规增益 (随时间递减)", value="aura"}, {text="消耗型层数 (向下掉)", value="consume"}, {text="充能技能 (向上涨)", value="charge"}} },
                    { type = "dropdown", key = "mode", db = selAura, text = "表现形式", options = {{text="平滑条 (Time)", value="time"}, {text="网格线 (Stack)", value="stack"}} },
                    { type = "toggle", key = "overrideMax", db = selAura, text = "强制覆盖最大层数" },
                    { type = "slider", key = "maxStacks", db = selAura, min = 1, max = 20, step = 1, text = "最大层数 / 网格数" },
                    { type = "dropdown", key = "visibility", db = selAura, text = "常驻策略", options = {{text="拥有时才显示 (自动隐藏)", value=1}, {text="永久常驻底框", value=2}, {text="战斗中常驻底框", value=3}} },
                    { type = "toggle", key = "hideOriginal", db = selData, text = "屏蔽右上角原生图标" },
                }},
                { type = "group", key = "scan_visuals", text = "视觉与排版覆盖", childs = {
                    { type = "color", key = "color", db = selAura, text = "专属前景色" },
                    { type = "toggle", key = "useThresholdColor", db = selAura, text = "启用层数条件变色" },
                    { type = "slider", key = "thresholdStacks", db = selAura, min = 1, max = 20, step = 1, text = "触发变色层数 (>=)" },
                    { type = "color", key = "thresholdColor", db = selAura, text = "警告期颜色" },
                    { type = "toggle", key = "useHorizontalSplit", db = selAura, text = "加入水平裂变组 (同组平分宽度)" },
                    { type = "slider", key = "splitSpacing", db = selAura, min = 0, max = 200, step = 1, text = "裂变间距" },
                    { type = "toggle", key = "useCustomSize", db = selAura, text = "启用独立专属尺寸" },
                    { type = "slider", key = "customWidth", db = selAura, min = 20, max = 600, step = 1, text = "独立专属宽度" },
                    { type = "slider", key = "customHeight", db = selAura, min = 2, max = 100, step = 1, text = "独立专属高度" },
                    { type = "toggle", key = "useIndependentPosition", db = selAura, text = "脱离排列组 (绝对定位)" },
                    { type = "slider", key = "customXOffset", db = selAura, min = -800, max = 800, step = 1, text = "X轴绝对偏移" },
                    { type = "slider", key = "customYOffset", db = selAura, min = -800, max = 800, step = 1, text = "Y轴绝对偏移" },
                    { type = "toggle", key = "reverseFill", db = selAura, text = "反向消耗 (从右向左)" },
                }}
            }
        else
            rightOpts = { { type = "header", text = "← 请在左侧点击一个法术以查看详细配置" } }
        end
        
        local ry = RenderOptionsGroup(scrollChild, 280, y, 400, rightOpts, RefreshAuraDB)
        y = math.min(-500, ry)

    -- 【3. 冷却管理器相关】
    elseif nodeKey == "cooldownCustom_Global" then
        local db = WF.db.cooldownCustom or {}
        local opts = {
            { type = "group", key = "cd_global_base", text = L["Global Settings"] or "全局设置", childs = {
                { type = "toggle", key = "enable", db = db, text = "启用" },
                { type = "dropdown", key = "countFont", db = db, text = "字体", options = FontOptions },
            }}
        }
        y = RenderOptionsGroup(scrollChild, 15, y, ColW * 2, opts, HandleCDChange)
    end
    
    scrollChild:SetHeight(math.abs(y) + 50)
end

-- =========================================
-- [侧边栏树状引擎 (无记忆，点开即合上)]
-- =========================================
local animFrame = CreateFrame("Frame")
local function WF_AnimateRotation(texture, targetRad, duration)
    local startRad = texture._wf_rot or 0; local startTime = GetTime()
    animFrame:SetScript("OnUpdate", function(self)
        local elapsed = GetTime() - startTime; local progress = math.min(1, elapsed / duration)
        local currentRad = startRad + (targetRad - startRad) * progress
        texture:SetRotation(currentRad); texture._wf_rot = currentRad
        if progress >= 1 then self:SetScript("OnUpdate", nil) end
    end)
end

local menuExpanded = {}
local function ResetMenuState() wipe(menuExpanded) end

local menuStructure = {
    { id = "HOME", level = 0, name = "主页", type = "root", key = "WF_HOME", icon = ICON_LOGO },
    { id = "Combat", level = 0, name = "战斗", type = "root", icon = "Interface\\Icons\\INV_Sword_04" },
    
    { id = "Resource", parent = "Combat", level = 1, name = "资源条", type = "group" },
    { id = "RC_Global", parent = "Resource", level = 2, name = "主控", key = "rc_global" },
    { id = "RC_Power", parent = "Resource", level = 2, name = "能量条", key = "rc_power" },
    { id = "RC_Class", parent = "Resource", level = 2, name = "主资源条", key = "rc_class" },
    { id = "RC_Mana", parent = "Resource", level = 2, name = "额外法力", key = "rc_mana" },
    { id = "RC_Aura", parent = "Resource", level = 2, name = "增益条", key = "rc_aura" },
    { id = "RC_Scanner", parent = "Resource", level = 2, name = "增益扫描", key = "rc_scanner" },

    { id = "CDManager", parent = "Combat", level = 1, name = "冷却管理器", type = "group" },
    { id = "CD_Global", parent = "CDManager", level = 2, name = "全局与外观", key = "cooldownCustom_Global" },
}

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
                icon:SetSize(14, 14); icon:SetPoint("LEFT", xIndent + 10, 0); icon:SetTexture(ICON_ARROW)
                icon._wf_rot = menuExpanded[item.id] and -math.pi/2 or 0; icon:SetRotation(icon._wf_rot)
                icon:SetVertexColor(CR, CG, CB, 1); btn.arrowIcon = icon
            end
        end

        local text = CreateUIFont(btn, 13, "LEFT")
        text:SetPoint("LEFT", xIndent + 35, 0); text:SetText(item.name)
        text:SetTextColor(item.type == "root" and CR or (item.type == "group" and 0.9 or 0.6), item.type == "root" and CG or (item.type == "group" and 0.8 or 0.6), item.type == "root" and CB or (item.type == "group" and 0.2 or 0.6))
        if not isExpanded then text:Hide() else text:Show() end

        btn:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            local wasExpanded = sidebar.isExpanded
            
            if not wasExpanded then
                sidebar.isExpanded = true; sidebar:SetWidth(SIDEBAR_WIDTH_EXPANDED)
                if sidebar.mIcon then WF_AnimateRotation(sidebar.mIcon, -math.pi/2, 0.2) end
            end

            if item.type == "root" or item.type == "group" then
                if not wasExpanded then menuExpanded[item.id] = true else menuExpanded[item.id] = not menuExpanded[item.id] end
            end

            if item.key then
                for _, b in ipairs(sidebar.buttons) do if b.tIcon then b.tIcon:SetVertexColor(0.6, 0.6, 0.6, 1) end; if b.text and b.itemType ~= "root" and b.itemType ~= "group" then b.text:SetTextColor(0.6, 0.6, 0.6) end end
                text:SetTextColor(1, 1, 1); if btn.tIcon then btn.tIcon:SetVertexColor(CR, CG, CB, 1) end
                activeIndicator:ClearAllPoints(); activeIndicator:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0); activeIndicator:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0); activeIndicator:Show()
                ResetGroupState() 
                RenderContentSettings(item.key, WF.ScrollChild)
                WF.MainFrame.TitleBar.titleText:SetText("|cffffffffW|cff00ffccF|r // "..item.name)
            end
            RenderTreeMenu()
        end)
        
        btn:SetScript("OnEnter", function() ApplyFlatSkin(btn, 0.2, 0.2, 0.2, 1, 0,0,0,0); if not sidebar.isExpanded then ShowTooltipTemp(btn, item.name, CR, CG, CB) end end)
        btn:SetScript("OnLeave", function() ApplyFlatSkin(btn, 0.1, 0.1, 0.1, 0, 0,0,0,0); if not sidebar.isExpanded and GameTooltip:IsOwned(btn) then GameTooltip:Hide() end end)
        btn.text = text; btn.itemType = item.type; table.insert(sidebar.buttons, btn)
        yOffset = yOffset - 30
    end

    for _, item in ipairs(menuStructure) do
        if item.type == "root" then AddBtn(item)
        elseif isExpanded and item.parent and menuExpanded[item.parent] then
            local pNode = nil; for _, n in ipairs(menuStructure) do if n.id == item.parent then pNode = n; break end end
            if pNode and (pNode.type == "root" or (pNode.parent and menuExpanded[pNode.parent])) then AddBtn(item) end
        end
    end
end

-- =========================================
-- [主框架控制] (无记忆全折叠)
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
        
        menuBtn:SetScript("OnEnter", function() if not sidebar.isExpanded then ShowTooltipTemp(menuBtn, "菜单", CR, CG, CB) end end)
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
        titleText:SetPoint("LEFT", 15, 0); titleText:SetText("|cffffffffW|cff00ffccF|r // 主页"); titleBar.titleText = titleText

        local closeBtn = CreateFrame("Button", nil, titleBar)
        closeBtn:SetSize(20, 20); closeBtn:SetPoint("RIGHT", -8, 0)
        local cIcon = closeBtn:CreateTexture(nil, "ARTWORK"); cIcon:SetPoint("CENTER"); cIcon:SetSize(14, 14); cIcon:SetTexture(ICON_CLOSE); cIcon:SetVertexColor(0.6, 0.6, 0.6, 1)
        closeBtn:SetScript("OnEnter", function() cIcon:SetVertexColor(CR, CG, CB, 1) end); closeBtn:SetScript("OnLeave", function() cIcon:SetVertexColor(0.6, 0.6, 0.6, 1) end); closeBtn:SetScript("OnClick", function() frame:Hide() end)

        local content = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        content:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0); content:SetPoint("BOTTOMRIGHT", -1, 1); content:SetFrameLevel(frame:GetFrameLevel() + 1)
        local scrollFrame, scrollChild = UI_Factory:CreateScrollArea(content)
        content.scrollFrame = scrollFrame; content.scrollChild = scrollChild
        frame.Content = content
        WF.ScrollChild = scrollChild
    end
    
    if not WF.MainFrame:IsShown() then
        ResetGroupState(); ResetMenuState()
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
            firstBtn.text:SetTextColor(1, 1, 1); if firstBtn.tIcon then firstBtn.tIcon:SetVertexColor(CR, CG, CB, 1) end
            if sidebar.activeIndicator then
                sidebar.activeIndicator:ClearAllPoints(); sidebar.activeIndicator:SetPoint("TOPLEFT", firstBtn, "TOPLEFT", 0, 0); sidebar.activeIndicator:SetPoint("BOTTOMLEFT", firstBtn, "BOTTOMLEFT", 0, 0); sidebar.activeIndicator:Show()
            end
            RenderContentSettings("WF_HOME", WF.ScrollChild)
            WF.MainFrame.TitleBar.titleText:SetText("|cffffffffW|cff00ffccF|r // 主页")
        end
        WF.MainFrame:Show()
    else
        WF.MainFrame:Hide()
    end
end

SLASH_WISHFLEX1 = "/wf"
SLASH_WISHFLEX2 = "/wishflex"
SlashCmdList["WISHFLEX"] = function() WF:ToggleUI() end