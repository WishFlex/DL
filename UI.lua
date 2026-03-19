local AddonName, ns = ...
local WF = _G.WishFlex or ns.WF
ns.L = ns.L or {}
local L = ns.L

-- =========================================
-- [布局常量与资源预设] 
-- =========================================
local FRAME_WIDTH = 900
local FRAME_HEIGHT = 650
local TITLE_HEIGHT = 35
local SIDEBAR_WIDTH_COLLAPSED = 40
local SIDEBAR_WIDTH_EXPANDED = 200

local ICON_ARROW = "Interface\\ChatFrame\\ChatFrameExpandArrow"
local ICON_CLOSE = "Interface\\FriendsFrame\\ClearBroadcastIcon"
local ICON_LOGO = "Interface\\AddOns\\WishFlex\\Media\\Icons\\Logo2"

local LSM = LibStub("LibSharedMedia-3.0", true)
local FontOptions = {}
if LSM then
    for name, _ in pairs(LSM:HashTable("font")) do table.insert(FontOptions, {text = name, value = name}) end
    table.sort(FontOptions, function(a, b) return a.text < b.text end)
else
    FontOptions = { {text = "Expressway", value = "Expressway"} }
end

local AnchorOptions = {
    { text = L["TOPLEFT"], value = "TOPLEFT" }, { text = L["TOP"], value = "TOP" }, { text = L["TOPRIGHT"], value = "TOPRIGHT" },
    { text = L["LEFT"], value = "LEFT" }, { text = L["CENTER"], value = "CENTER" }, { text = L["RIGHT"], value = "RIGHT" },
    { text = L["BOTTOMLEFT"], value = "BOTTOMLEFT" }, { text = L["BOTTOM"], value = "BOTTOM" }, { text = L["BOTTOMRIGHT"], value = "BOTTOMRIGHT" },
}

-- =========================================
-- [1. 主题与颜色引擎]
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

-- =========================================
-- [2. 高科技智能提示 (2秒自动消失)]
-- =========================================
local function ShowTooltipTemp(owner, text, r, g, b)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(text, r or 1, g or 1, b or 1)
    GameTooltip:Show()
    C_Timer.After(2, function()
        if GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
    end)
end

-- =========================================
-- [3. 高科技简约组件工厂]
-- =========================================
local UI_Factory = {}

function UI_Factory:CreateScrollArea(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10); scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)
    return scrollFrame, scrollChild
end

function UI_Factory:CreateFlatButton(parent, textStr, onClick)
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

function UI_Factory:CreateToggle(parent, x, y, width, titleText, db, key, callback)
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
function UI_Factory:CreateSlider(parent, x, y, width, titleText, minVal, maxVal, step, db, key, callback)
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

function UI_Factory:CreateColorPicker(parent, x, y, width, titleText, db, key, callback)
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

function UI_Factory:CreateDropdown(parent, x, y, width, titleText, db, key, options, callback)
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

function UI_Factory:CreateGroupHeader(parent, x, y, width, titleText, isExpanded, onClick)
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
-- [递归渲染引擎] 动态计算宽度、强制对齐缩进
-- =========================================
local GroupState = {}
local function ResetGroupState()
    wipe(GroupState)
end

local function RenderOptionsGroup(parent, startX, startY, colWidth, options, onChange, level)
    local y = startY; level = level or 0
    local indent = level * 12
    local cx = startX + indent; local itemWidth = colWidth - indent

    for _, opt in ipairs(options) do
        if opt.type == "group" then
            if GroupState[opt.key] == nil then GroupState[opt.key] = false end
            local btn
            btn, y = UI_Factory:CreateGroupHeader(parent, cx, y, itemWidth, opt.text, GroupState[opt.key], function()
                GroupState[opt.key] = not GroupState[opt.key]; onChange("UI_REFRESH")
            end)
            if GroupState[opt.key] and opt.childs then
                y = RenderOptionsGroup(parent, startX, y - 4, colWidth, opt.childs, onChange, level + 1); y = y - 6
            end
        elseif opt.type == "toggle" then _, y = UI_Factory:CreateToggle(parent, cx + 8, y, itemWidth, opt.text, opt.db, opt.key, onChange)
        elseif opt.type == "slider" then _, y = UI_Factory:CreateSlider(parent, cx + 8, y, itemWidth, opt.text, opt.min, opt.max, opt.step, opt.db, opt.key, onChange)
        elseif opt.type == "color" then _, y = UI_Factory:CreateColorPicker(parent, cx + 8, y, itemWidth, opt.text, opt.db, opt.key, onChange)
        elseif opt.type == "dropdown" then _, y = UI_Factory:CreateDropdown(parent, cx + 8, y, itemWidth, opt.text, opt.db, opt.key, opt.options, onChange)
        end
    end
    return y
end

local function GetTextOptions(dbRef, prefix, titleStr, groupKey)
    return {
        type = "group", key = groupKey, text = titleStr, childs = {
            { type = "slider", key = prefix.."FontSize", db = dbRef, min = 8, max = 64, step = 1, text = L["Font Size"] },
            { type = "dropdown", key = prefix.."Position", db = dbRef, text = L["Anchor"], options = AnchorOptions },
            { type = "slider", key = prefix.."XOffset", db = dbRef, min = -50, max = 50, step = 1, text = L["X Offset"] },
            { type = "slider", key = prefix.."YOffset", db = dbRef, min = -50, max = 50, step = 1, text = L["Y Offset"] },
            { type = "color", key = prefix.."FontColor", db = dbRef, text = L["Color"] },
        }
    }
end

-- =========================================
-- [各大板块参数派发引擎]
-- =========================================
local function RenderHomeContent(scrollChild)
    local y = -20
    local logo = scrollChild:CreateTexture(nil, "ARTWORK")
    logo:SetSize(48, 48); logo:SetPoint("TOPLEFT", 20, y); logo:SetTexture(ICON_LOGO)
    
    local title = CreateUIFont(scrollChild, 28, "LEFT", true)
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 15, -5); title:SetText("|cff00ffccWishFlex|r GeniSys"); title:SetTextColor(1, 1, 1)
    
    local sub = CreateUIFont(scrollChild, 14, "LEFT")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5); sub:SetText(L["Welcome to WishFlex"]); sub:SetTextColor(0.6, 0.6, 0.6)
    y = y - 90
    
    local desc = CreateUIFont(scrollChild, 14, "LEFT")
    desc:SetPoint("TOPLEFT", 20, y); desc:SetWidth(450)
    desc:SetSpacing(5); desc:SetText(L["Addon Description"]); desc:SetTextColor(0.8, 0.8, 0.8)
    y = y - 70
    
    local featureHead = CreateUIFont(scrollChild, 16, "LEFT", true)
    featureHead:SetPoint("TOPLEFT", 20, y); featureHead:SetText(L["Core Features"]); featureHead:SetTextColor(CR, CG, CB)
    y = y - 30
    
    local features = { L["Feature 1"], L["Feature 2"], L["Feature 3"], L["Feature 4"], L["Feature 5"] }
    for _, fText in ipairs(features) do
        local f = CreateUIFont(scrollChild, 13, "LEFT")
        f:SetPoint("TOPLEFT", 30, y); f:SetText(fText); f:SetTextColor(0.7, 0.7, 0.7)
        y = y - 22
    end
    y = y - 20
    
    local qaHead = CreateUIFont(scrollChild, 16, "LEFT", true)
    qaHead:SetPoint("TOPLEFT", 20, y); qaHead:SetText(L["Quick Actions"]); qaHead:SetTextColor(CR, CG, CB)
    y = y - 30
    
    local reloadBtn = UI_Factory:CreateFlatButton(scrollChild, L["Reload UI"], function() ReloadUI() end)
    reloadBtn:SetPoint("TOPLEFT", 20, y)
    local anchorBtn = UI_Factory:CreateFlatButton(scrollChild, L["Toggle Anchors"], function() if WF.ToggleMovers then WF:ToggleMovers() end end)
    anchorBtn:SetPoint("TOPLEFT", reloadBtn, "TOPRIGHT", 15, 0)
    y = y - 60
    
    local infoHead = CreateUIFont(scrollChild, 16, "LEFT", true)
    infoHead:SetPoint("TOPLEFT", 20, y); infoHead:SetText(L["Addon Info"]); infoHead:SetTextColor(CR, CG, CB)
    y = y - 30
    
    local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local version = getMeta and getMeta(AddonName, "Version") or "v1.0"
    local author = getMeta and getMeta(AddonName, "Author") or "WishFlex Team"

    local info1 = CreateUIFont(scrollChild, 13, "LEFT")
    info1:SetPoint("TOPLEFT", 30, y); info1:SetText(L["Version"]..": |cffffffff"..version.."|r"); info1:SetTextColor(0.7, 0.7, 0.7)
    y = y - 22
    local info2 = CreateUIFont(scrollChild, 13, "LEFT")
    info2:SetPoint("TOPLEFT", 30, y); info2:SetText(L["Author"]..": |cffffffff"..author.."|r"); info2:SetTextColor(0.7, 0.7, 0.7)
    
    y = y - 30
    scrollChild:SetHeight(math.abs(y))
end

local RenderContentSettings
RenderContentSettings = function(nodeKey, scrollChild)
    local children = {scrollChild:GetChildren()}; for _, child in ipairs(children) do if type(child) == "table" and child.Hide then child:Hide() end end
    local regions = {scrollChild:GetRegions()}; for _, region in ipairs(regions) do if type(region) == "table" and region.Hide then region:Hide() end end

    if nodeKey == "WF_HOME" then RenderHomeContent(scrollChild); return end

    local y = -10
    local db = WF.db.cooldownCustom or {}
    if not db.Essential then db.Essential = {} end
    if not db.Utility then db.Utility = {} end
    if not db.BuffIcon then db.BuffIcon = {} end
    if not db.BuffBar then db.BuffBar = {} end

    local function HandleCDChange(val)
        if WF.TriggerCooldownLayout then WF.TriggerCooldownLayout() end
        if val == "UI_REFRESH" then RenderContentSettings(nodeKey, scrollChild) end
    end
    local function HandleGlowChange(val)
        if WF.GlowAPI and WF.GlowAPI.UpdateAllGlows then WF.GlowAPI:UpdateAllGlows() end
        if val == "UI_REFRESH" then RenderContentSettings(nodeKey, scrollChild) end
    end

    local ColW = 320 

    if nodeKey == "cooldownCustom_Global" then
        local opts = {
            { type = "group", key = "cd_global_base", text = L["Global Settings"], childs = {
                { type = "toggle", key = "enable", db = db, text = L["Enable Module"] },
                { type = "dropdown", key = "countFont", db = db, text = L["Global Font"], options = FontOptions },
                { type = "color", key = "swipeColor", db = db, text = L["Default Swipe Color"] },
                { type = "color", key = "activeAuraColor", db = db, text = L["Active Swipe Color"] },
                { type = "toggle", key = "reverseSwipe", db = db, text = L["Reverse Swipe"] },
                { type = "toggle", key = "enableCustomLayout", db = db.Essential, text = L["Enable Split Layout"] },
                { type = "slider", key = "rowYGap", db = db.Essential, min = 0, max = 50, step = 1, text = L["Row Y Gap"] },
            }}
        }
        y = RenderOptionsGroup(scrollChild, 15, y, ColW * 2, opts, HandleCDChange)

    elseif nodeKey == "cooldownCustom_Glow" then
        local glowDB = WF.db.glow or {}
        local glowOpts = {
            { type = "group", key = "cd_glow", text = L["Glow Settings"], childs = {
                { type = "toggle", key = "enable", db = glowDB, text = L["Enable"] },
                { type = "dropdown", key = "glowType", db = glowDB, text = L["Glow Style"], options = {
                    {text = L["Pixel"], value="pixel"}, {text = L["Autocast"], value="autocast"}, {text = L["Button"], value="button"}, {text = L["Proc"], value="proc"}
                }},
                { type = "toggle", key = "useCustomColor", db = glowDB, text = L["Enable Custom Color"] },
                { type = "color", key = "color", db = glowDB, text = L["Color"] },
            }}
        }
        local childs = glowOpts[1].childs
        if glowDB.glowType == "pixel" then
            table.insert(childs, { type = "slider", key = "pixelLines", db = glowDB, min = 1, max = 20, step = 1, text = L["Lines"] })
            table.insert(childs, { type = "slider", key = "pixelFrequency", db = glowDB, min = -2, max = 2, step = 0.05, text = L["Frequency"] })
            table.insert(childs, { type = "slider", key = "pixelLength", db = glowDB, min = 0, max = 50, step = 1, text = L["Length"] })
            table.insert(childs, { type = "slider", key = "pixelThickness", db = glowDB, min = 1, max = 10, step = 1, text = L["Thickness"] })
            table.insert(childs, { type = "slider", key = "pixelXOffset", db = glowDB, min = -30, max = 30, step = 1, text = L["X Offset"] })
            table.insert(childs, { type = "slider", key = "pixelYOffset", db = glowDB, min = -30, max = 30, step = 1, text = L["Y Offset"] })
        elseif glowDB.glowType == "autocast" then
            table.insert(childs, { type = "slider", key = "autocastParticles", db = glowDB, min = 1, max = 20, step = 1, text = L["Particles"] })
            table.insert(childs, { type = "slider", key = "autocastFrequency", db = glowDB, min = -2, max = 2, step = 0.05, text = L["Frequency"] })
            table.insert(childs, { type = "slider", key = "autocastScale", db = glowDB, min = 0.5, max = 3, step = 0.1, text = L["Scale"] })
            table.insert(childs, { type = "slider", key = "autocastXOffset", db = glowDB, min = -30, max = 30, step = 1, text = L["X Offset"] })
            table.insert(childs, { type = "slider", key = "autocastYOffset", db = glowDB, min = -30, max = 30, step = 1, text = L["Y Offset"] })
        elseif glowDB.glowType == "button" then
            table.insert(childs, { type = "slider", key = "buttonFrequency", db = glowDB, min = 0, max = 2, step = 0.05, text = L["Frequency"] })
        elseif glowDB.glowType == "proc" then
            table.insert(childs, { type = "slider", key = "procDuration", db = glowDB, min = 0.1, max = 5, step = 0.1, text = L["Duration"] })
            table.insert(childs, { type = "slider", key = "procXOffset", db = glowDB, min = -30, max = 30, step = 1, text = L["X Offset"] })
            table.insert(childs, { type = "slider", key = "procYOffset", db = glowDB, min = -30, max = 30, step = 1, text = L["Y Offset"] })
        end
        y = RenderOptionsGroup(scrollChild, 15, y, ColW * 2, glowOpts, HandleGlowChange)

    elseif nodeKey == "cooldownCustom_Essential" then
        local leftOpts = {
            { type = "group", key = "ess_row1", text = L["Row 1 Settings"], childs = {
                { type = "slider", key = "maxPerRow", db = db.Essential, min = 1, max = 20, step = 1, text = L["Max Per Row"] },
                { type = "slider", key = "iconGap", db = db.Essential, min = 0, max = 50, step = 1, text = L["Icon Gap"] },
                { type = "slider", key = "row1Width", db = db.Essential, min = 10, max = 100, step = 1, text = L["Width"] },
                { type = "slider", key = "row1Height", db = db.Essential, min = 10, max = 100, step = 1, text = L["Height"] },
                GetTextOptions(db.Essential, "row1Stack", L["Stack Text"], "ess_row1_stack"),
                GetTextOptions(db.Essential, "row1Cd", L["CD Text"], "ess_row1_cd"),
            }}
        }
        local rightOpts = {
            { type = "group", key = "ess_row2", text = L["Row 2 Settings"], childs = {
                { type = "slider", key = "row2IconGap", db = db.Essential, min = 0, max = 50, step = 1, text = L["Icon Gap"] },
                { type = "slider", key = "row2Width", db = db.Essential, min = 10, max = 100, step = 1, text = L["Width"] },
                { type = "slider", key = "row2Height", db = db.Essential, min = 10, max = 100, step = 1, text = L["Height"] },
                GetTextOptions(db.Essential, "row2Stack", L["Stack Text"], "ess_row2_stack"),
                GetTextOptions(db.Essential, "row2Cd", L["CD Text"], "ess_row2_cd"),
            }}
        }
        local ly = RenderOptionsGroup(scrollChild, 15, y, ColW, leftOpts, HandleCDChange)
        local ry = RenderOptionsGroup(scrollChild, 335, y, ColW, rightOpts, HandleCDChange)
        y = math.min(ly, ry)

    elseif nodeKey == "cooldownCustom_Utility" then
        local opts = {
            { type = "group", key = "util_base", text = L["Utility Skills"], childs = {
                { type = "toggle", key = "attachToPlayer", db = db.Utility, text = L["Attach To Player"] },
                { type = "slider", key = "iconGap", db = db.Utility, min = 0, max = 50, step = 1, text = L["Icon Gap"] },
                { type = "slider", key = "width", db = db.Utility, min = 10, max = 100, step = 1, text = L["Width"] },
                { type = "slider", key = "height", db = db.Utility, min = 10, max = 100, step = 1, text = L["Height"] },
                GetTextOptions(db.Utility, "stack", L["Stack Text"], "util_stack"),
                GetTextOptions(db.Utility, "cd", L["CD Text"], "util_cd"),
            }}
        }
        y = RenderOptionsGroup(scrollChild, 15, y, ColW * 1.5, opts, HandleCDChange)

    elseif nodeKey == "cooldownCustom_BuffIcon" then
        local opts = {
            { type = "group", key = "icon_base", text = L["Buff Icons"], childs = {
                { type = "slider", key = "width", db = db.BuffIcon, min = 10, max = 100, step = 1, text = L["Width"] },
                { type = "slider", key = "height", db = db.BuffIcon, min = 10, max = 100, step = 1, text = L["Height"] },
                { type = "slider", key = "iconGap", db = db.BuffIcon, min = 0, max = 30, step = 1, text = L["Icon Gap"] },
                GetTextOptions(db.BuffIcon, "stack", L["Stack Text"], "icon_stack"),
                GetTextOptions(db.BuffIcon, "cd", L["CD Text"], "icon_cd"),
            }}
        }
        y = RenderOptionsGroup(scrollChild, 15, y, ColW * 1.5, opts, HandleCDChange)

    elseif nodeKey == "cooldownCustom_BuffBar" then
        local opts = {
            { type = "group", key = "bar_base", text = L["Buff Bars"], childs = {
                { type = "slider", key = "width", db = db.BuffBar, min = 50, max = 400, step = 1, text = L["Width"] },
                { type = "slider", key = "height", db = db.BuffBar, min = 10, max = 100, step = 1, text = L["Height"] },
                { type = "slider", key = "iconGap", db = db.BuffBar, min = 0, max = 30, step = 1, text = L["Icon Gap"] },
                GetTextOptions(db.BuffBar, "stack", L["Stack Text"], "bar_stack"),
                GetTextOptions(db.BuffBar, "cd", L["CD Text"], "bar_cd"),
            }}
        }
        y = RenderOptionsGroup(scrollChild, 15, y, ColW * 1.5, opts, HandleCDChange)
        
    elseif nodeKey == "classResource" then
        local rcDB = WF.db.classResource or {}
        local opts = {
            { type = "group", key = "classResource", text = L["Class Resource"], childs = {
                { type = "toggle", key = "enable", db = rcDB, text = L["Enable Module"] },
                { type = "slider", key = "width", db = rcDB, min = 100, max = 500, step = 1, text = L["Width"] },
            }}
        }
        y = RenderOptionsGroup(scrollChild, 15, y, ColW * 1.5, opts, function() if WF.ClassResourceAPI then WF.ClassResourceAPI:UpdateLayout() end end)
    end
    scrollChild:SetHeight(math.abs(y) + 50)
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
-- [树状展开菜单引擎] (无记忆，每次重置)
-- =========================================
local menuExpanded = {}
local function ResetMenuState()
    wipe(menuExpanded)
end

local menuStructure = {
{ id = "HOME", level = 0, name = L["Home"], type = "root", key = "WF_HOME", icon = "Interface\\AddOns\\WishFlex\\Media\\Icons\\home" },
{ id = "Combat", level = 0, name = L["Combat"], type = "root", icon = "Interface\\AddOns\\WishFlex\\Media\\Icons\\zd" },
    { id = "Resource", parent = "Combat", level = 1, name = L["Class Resource"], key = "classResource" },
    { id = "CDManager", parent = "Combat", level = 1, name = L["Cooldown Manager"], type = "group" },
    { id = "CD_Global", parent = "CDManager", level = 2, name = L["Global Settings"], key = "cooldownCustom_Global" },
    { id = "CD_Glow", parent = "CDManager", level = 2, name = L["Core Glow"], key = "cooldownCustom_Glow" },
    { id = "CD_Essential", parent = "CDManager", level = 2, name = L["Essential Skills"], key = "cooldownCustom_Essential" },
    { id = "CD_Utility", parent = "CDManager", level = 2, name = L["Utility Skills"], key = "cooldownCustom_Utility" },
    { id = "CD_BuffIcon", parent = "CDManager", level = 2, name = L["Buff Icons"], key = "cooldownCustom_BuffIcon" },
    { id = "CD_BuffBar", parent = "CDManager", level = 2, name = L["Buff Bars"], key = "cooldownCustom_BuffBar" },
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
            
            -- 如果点击的是文件夹，切换它的展开状态
            if item.type == "root" or item.type == "group" then
                menuExpanded[item.id] = not menuExpanded[item.id]
            end

            -- 点击图标不仅能打开页面，还要强制展开侧边栏
            if not sidebar.isExpanded then
                sidebar.isExpanded = true; sidebar:SetWidth(SIDEBAR_WIDTH_EXPANDED)
                if sidebar.mIcon then WF_AnimateRotation(sidebar.mIcon, -math.pi/2, 0.2) end
            end

            -- 渲染对应的设置内容
            if item.key then
                for _, b in ipairs(sidebar.buttons) do 
                    if b.tIcon then b.tIcon:SetVertexColor(0.6, 0.6, 0.6, 1) end
                    if b.text and b.itemType ~= "root" and b.itemType ~= "group" then b.text:SetTextColor(0.6, 0.6, 0.6) end 
                end
                text:SetTextColor(1, 1, 1); if btn.tIcon then btn.tIcon:SetVertexColor(CR, CG, CB, 1) end
                activeIndicator:ClearAllPoints(); activeIndicator:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0); activeIndicator:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0); activeIndicator:Show()
                RenderContentSettings(item.key, WF.ScrollChild)
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

    for _, item in ipairs(menuStructure) do
        if item.type == "root" then AddBtn(item)
        elseif isExpanded and item.parent and menuExpanded[item.parent] then
            local pNode = nil; for _, n in ipairs(menuStructure) do if n.id == item.parent then pNode = n; break end end
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
        
        menuBtn:SetScript("OnEnter", function() if not sidebar.isExpanded then ShowTooltipTemp(menuBtn, L["MENU"], CR, CG, CB) end end)
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
        local scrollFrame, scrollChild = UI_Factory:CreateScrollArea(content)
        content.scrollFrame = scrollFrame; content.scrollChild = scrollChild
        frame.Content = content
        WF.ScrollChild = scrollChild
    end
    
    if not WF.MainFrame:IsShown() then
        -- [强迫症福音]：每次打开界面，强制重置所有状态并全折叠
        ResetGroupState()
        ResetMenuState()
        
        local sidebar = WF.MainFrame.Sidebar
        sidebar.isExpanded = false
        if WF.db.global and WF.db.global.ui then WF.db.global.ui.sidebarExpanded = false end
        
        sidebar:SetWidth(SIDEBAR_WIDTH_COLLAPSED)
        if sidebar.mIcon then sidebar.mIcon:SetRotation(0) end

        RenderTreeMenu()
        
        -- 静默渲染主页 (避免调用 :Click() 触发自动展开逻辑)
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
            
            RenderContentSettings("WF_HOME", WF.ScrollChild)
            WF.MainFrame.TitleBar.titleText:SetText("|cffffffffW|cff00ffccF|r // "..L["Home"])
        end
        
        WF.MainFrame:Show()
    else
        WF.MainFrame:Hide()
    end
end

SLASH_WISHFLEX1 = "/wf"
SLASH_WISHFLEX2 = "/wishflex"
SlashCmdList["WISHFLEX"] = function() WF:ToggleUI() end