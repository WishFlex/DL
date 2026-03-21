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

-- Widget 内存池 (解决重绘性能问题)
WF.UI.WidgetPools = { toggle = {}, slider = {}, color = {}, dropdown = {}, header = {}, container = {}, input = {} }
WF.UI.WidgetCounts = { toggle = 0, slider = 0, color = 0, dropdown = 0, header = 0, container = 0, input = 0 }

-- 高性能独立缓动动画引擎 (Smooth Lerp Engine)
local function Lerp(a, b, t) return a + (b - a) * t end
local AnimFrame = CreateFrame("Frame")
local activeAnims = {}
AnimFrame:SetScript("OnUpdate", function(_, elapsed)
    for frame, anims in pairs(activeAnims) do
        for key, data in pairs(anims) do
            data.timer = data.timer + elapsed
            local progress = math.min(1, data.timer / data.duration)
            local ease = 1 - (1 - progress) * (1 - progress)
            data.updateFunc(ease)
            if progress >= 1 then
                if data.onComplete then data.onComplete() end
                anims[key] = nil
            end
        end
        if next(anims) == nil then activeAnims[frame] = nil end
    end
end)

-- 原生重载(RL)弹窗定义
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

function WF.UI:Animate(frame, key, duration, updateFunc, onComplete)
    if not activeAnims[frame] then activeAnims[frame] = {} end
    activeAnims[frame][key] = { timer = 0, duration = duration, updateFunc = updateFunc, onComplete = onComplete }
end

function WF.UI:ShowReloadPopup() StaticPopup_Show("WISHFLEX_RELOAD_UI") end
function WF.UI:RegisterMenu(menuData) table.insert(self.Menus, menuData) end
function WF.UI:RegisterPanel(key, renderFunc) self.Panels[key] = renderFunc end

function WF.UI:UpdateTargetWidth(reqWidth, animated)
    if not WF.MainFrame then return end
    self.CurrentReqWidth = reqWidth or 800 
    local sidebarW = WF.MainFrame.Sidebar.isExpanded and 200 or 40
    local targetW = math.max(900, self.CurrentReqWidth + sidebarW + 70)
    
    if animated then
        local startW = WF.MainFrame:GetWidth()
        WF.UI:Animate(WF.MainFrame, "WindowResize", 0.3, function(ease)
            WF.MainFrame:SetWidth(Lerp(startW, targetW, ease))
        end)
    else
        WF.MainFrame:SetWidth(targetW)
    end
end

function WF.UI:RefreshCurrentPanel()
    if WF.ScrollChild and self.CurrentNodeKey then
        for k in pairs(self.WidgetCounts) do self.WidgetCounts[k] = 0 end
        for _, pool in pairs(self.WidgetPools) do for _, widget in ipairs(pool) do widget:Hide(); widget:ClearAllPoints() end end
        
        local children = {WF.ScrollChild:GetChildren()}; for _, child in ipairs(children) do if type(child) == "table" and child.Hide then child:Hide() end end
        local regions = {WF.ScrollChild:GetRegions()}; for _, region in ipairs(regions) do if type(region) == "table" and region.Hide then region:Hide() end end
        
        if self.Panels[self.CurrentNodeKey] then
            local availWidth = WF.ScrollChild:GetWidth(); if availWidth == 0 then availWidth = 800 end
            local y, reqWidth = self.Panels[self.CurrentNodeKey](WF.ScrollChild, availWidth / 2.2)
            WF.ScrollChild:SetHeight(math.abs(y) + 50)
            self:UpdateTargetWidth(reqWidth, false)
        end
    end
end

local FRAME_WIDTH = 900; local FRAME_HEIGHT = 650; local TITLE_HEIGHT = 35; local SIDEBAR_WIDTH_COLLAPSED = 40; local SIDEBAR_WIDTH_EXPANDED = 200
local ICON_ARROW = "Interface\\AddOns\\WishFlex\\Media\\Icons\\menu.tga"; local ICON_CLOSE = "Interface\\AddOns\\WishFlex\\Media\\Icons\\off.tga"; local ICON_GEAR = "Interface\\AddOns\\WishFlex\\Media\\Icons\\sett.tga"

local LSM = LibStub("LibSharedMedia-3.0", true)
local FontOptions = {}
if LSM then
    for name, _ in pairs(LSM:HashTable("font")) do table.insert(FontOptions, {text = name, value = name}) end
    table.sort(FontOptions, function(a, b) return a.text < b.text end)
else
    FontOptions = { {text = "Expressway", value = "Expressway"} }
end
WF.UI.FontOptions = FontOptions

-- 【新增】支持增益条材质下拉选项
local StatusBarOptions = {}
if LSM then
    for name, _ in pairs(LSM:HashTable("statusbar")) do table.insert(StatusBarOptions, {text = name, value = name}) end
    table.sort(StatusBarOptions, function(a, b) return a.text < b.text end)
else
    StatusBarOptions = { {text = "Blizzard", value = "Interface\\TargetingFrame\\UI-StatusBar"} }
end
WF.UI.StatusBarOptions = StatusBarOptions

local AnchorOptions = {
    { text = L["TOPLEFT"] or "左上", value = "TOPLEFT" }, { text = L["TOP"] or "上方", value = "TOP" }, { text = L["TOPRIGHT"] or "右上", value = "TOPRIGHT" },
    { text = L["LEFT"] or "左侧", value = "LEFT" }, { text = L["CENTER"] or "居中", value = "CENTER" }, { text = L["RIGHT"] or "右侧", value = "RIGHT" },
    { text = L["BOTTOMLEFT"] or "左下", value = "BOTTOMLEFT" }, { text = L["BOTTOM"] or "下方", value = "BOTTOM" }, { text = L["BOTTOMRIGHT"] or "右下", value = "BOTTOMRIGHT" },
}
WF.UI.AnchorOptions = AnchorOptions

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
    text:SetFont(font, size or 13, "OUTLINE"); text:SetJustifyH(justify or "LEFT")
    return text
end

local function ShowTooltipTemp(owner, text, r, g, b)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT"); GameTooltip:ClearLines(); GameTooltip:AddLine(text, r or 1, g or 1, b or 1); GameTooltip:Show()
    C_Timer.After(2, function() if GameTooltip:IsOwned(owner) then GameTooltip:Hide() end end)
end

WF.UI.Factory = {}
WF.UI.Factory.ApplyFlatSkin = ApplyFlatSkin
local Factory = WF.UI.Factory

function Factory:CreateScrollArea(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10); scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    local scrollChild = CreateFrame("Frame")
    scrollFrame:SetScript("OnSizeChanged", function(self, width, height) if self:GetScrollChild() then self:GetScrollChild():SetWidth(width) end end)
    scrollChild:SetSize(scrollFrame:GetWidth() or 800, 1); scrollFrame:SetScrollChild(scrollChild)
    return scrollFrame, scrollChild
end

function Factory:CreateFlatButton(parent, textStr, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(120, 26); ApplyFlatSkin(btn, 0.15, 0.15, 0.15, 1, 0, 0, 0, 1)
    local text = CreateUIFont(btn, 13, "CENTER"); text:SetPoint("CENTER"); text:SetText(textStr); text:SetTextColor(0.8, 0.8, 0.8)
    btn:SetScript("OnMouseDown", function() text:SetPoint("CENTER", 1, -1) end); btn:SetScript("OnMouseUp", function() text:SetPoint("CENTER", 0, 0) end)
    btn:SetScript("OnEnter", function() ApplyFlatSkin(btn, 0.2, 0.2, 0.2, 1, 0, 0, 0, 1); text:SetTextColor(1, 1, 1) end); btn:SetScript("OnLeave", function() ApplyFlatSkin(btn, 0.15, 0.15, 0.15, 1, 0, 0, 0, 1); text:SetTextColor(0.8, 0.8, 0.8) end)
    btn:SetScript("OnClick", function() if onClick then onClick() end end)
    return btn
end

function Factory:CreateInput(parent, x, y, width, titleText, db, key, callback)
    WF.UI.WidgetCounts.input = WF.UI.WidgetCounts.input + 1
    local c = WF.UI.WidgetPools.input[WF.UI.WidgetCounts.input]
    if not c then
        c = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        ApplyFlatSkin(c, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1)
        c.title = CreateUIFont(c, 12, "LEFT"); c.title:SetPoint("BOTTOMLEFT", c, "TOPLEFT", 0, 4)
        c.box = CreateFrame("EditBox", nil, c); c.box:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); c.box:SetPoint("TOPLEFT", 5, 0); c.box:SetPoint("BOTTOMRIGHT", -5, 0); c.box:SetAutoFocus(false)
        c.box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end); c.box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        c:SetScript("OnMouseDown", function() c.box:SetFocus() end)
        c:SetScript("OnEnter", function() ApplyFlatSkin(c, 0.1, 0.1, 0.1, 1, 0, 0, 0, 1); c.title:SetTextColor(1, 1, 1) end); c:SetScript("OnLeave", function() ApplyFlatSkin(c, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1); c.title:SetTextColor(0.7, 0.7, 0.7) end)
        WF.UI.WidgetPools.input[WF.UI.WidgetCounts.input] = c
    end
    c:SetParent(parent); c:SetSize(width - 10, 24); c:ClearAllPoints(); c:SetPoint("TOPLEFT", x, y - 20)
    c.title:SetText(titleText); c.title:SetTextColor(0.7, 0.7, 0.7); c.box:SetText(db[key] or "")
    c.box:SetScript("OnTextChanged", function(self, userInput) if not userInput then return end; db[key] = self:GetText(); if callback then callback(self:GetText()) end end)
    c:Show()
    return c, y - 48
end

function Factory:CreateToggle(parent, x, y, width, titleText, db, key, callback)
    WF.UI.WidgetCounts.toggle = WF.UI.WidgetCounts.toggle + 1
    local c = WF.UI.WidgetPools.toggle[WF.UI.WidgetCounts.toggle]
    if not c then
        c = CreateFrame("Button", nil, UIParent)
        c.track = CreateFrame("Frame", nil, c, "BackdropTemplate"); c.track:SetSize(36, 16); c.track:SetPoint("LEFT", 0, 0); ApplyFlatSkin(c.track, 0.15, 0.15, 0.15, 1, 0, 0, 0, 1)
        c.thumb = CreateFrame("Frame", nil, c.track, "BackdropTemplate"); c.thumb:SetSize(12, 12); ApplyFlatSkin(c.thumb, 0.6, 0.6, 0.6, 1, 0, 0, 0, 0)
        c.text = CreateUIFont(c, 13, "LEFT"); c.text:SetPoint("LEFT", c.track, "RIGHT", 10, 0)
        c.UpdateState = function(animated, isOn)
            local targetX = isOn and 22 or 2
            local targetR, targetG, targetB = 0.15, 0.15, 0.15
            if isOn then targetR, targetG, targetB = CR, CG, CB end
            local startR, startG, startB = c.track:GetBackdropColor(); local startX = select(4, c.thumb:GetPoint()) or 2
            if animated then
                WF.UI:Animate(c, "toggle", 0.2, function(ease)
                    c.thumb:ClearAllPoints(); c.thumb:SetPoint("LEFT", c.track, "LEFT", Lerp(startX, targetX, ease), 0)
                    c.track:SetBackdropColor(Lerp(startR, targetR, ease), Lerp(startG, targetG, ease), Lerp(startB, targetB, ease), 1)
                    local tc = Lerp(0.6, 1, ease); c.thumb:SetBackdropColor(tc, tc, tc, 1)
                end)
            else
                c.thumb:ClearAllPoints(); c.thumb:SetPoint("LEFT", c.track, "LEFT", targetX, 0); c.track:SetBackdropColor(targetR, targetG, targetB, 1)
                local tc = isOn and 1 or 0.6; c.thumb:SetBackdropColor(tc, tc, tc, 1)
            end
        end
        c:SetScript("OnEnter", function() c.text:SetTextColor(1, 1, 1) end); c:SetScript("OnLeave", function() c.text:SetTextColor(0.9, 0.9, 0.9) end)
        WF.UI.WidgetPools.toggle[WF.UI.WidgetCounts.toggle] = c
    end
    c:SetParent(parent); c:SetSize(width, 24); c:ClearAllPoints(); c:SetPoint("TOPLEFT", x, y); c.text:SetText(titleText); c.text:SetTextColor(0.9, 0.9, 0.9)
    c:SetScript("OnClick", function() local isOn = not db[key]; db[key] = isOn; c.UpdateState(true, isOn); if callback then callback(isOn) end end)
    c.UpdateState(false, db[key]); c:Show()
    return c, y - 28
end

function Factory:CreateSlider(parent, x, y, width, titleText, minVal, maxVal, step, db, key, callback)
    WF.UI.WidgetCounts.slider = WF.UI.WidgetCounts.slider + 1
    local c = WF.UI.WidgetPools.slider[WF.UI.WidgetCounts.slider]
    if not c then
        c = CreateFrame("Slider", nil, UIParent); c:SetOrientation("HORIZONTAL"); c:SetObeyStepOnDrag(true); ApplyFlatSkin(c, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1)
        c.thumb = c:CreateTexture(nil, "ARTWORK"); c.thumb:SetColorTexture(CR, CG, CB, 1); c.thumb:SetSize(8, 16); c:SetThumbTexture(c.thumb)
        c.title = CreateUIFont(c, 12, "LEFT"); c.title:SetPoint("BOTTOMLEFT", c, "TOPLEFT", 0, 4)
        c.valText = CreateUIFont(c, 12, "RIGHT"); c.valText:SetPoint("BOTTOMRIGHT", c, "TOPRIGHT", 0, 4); c.valText:SetTextColor(CR, CG, CB)
        c:SetScript("OnEnter", function() c.title:SetTextColor(1, 1, 1) end); c:SetScript("OnLeave", function() c.title:SetTextColor(0.7, 0.7, 0.7) end)
        WF.UI.WidgetPools.slider[WF.UI.WidgetCounts.slider] = c
    end
    c:SetParent(parent); c:SetSize(width - 10, 10); c:ClearAllPoints(); c:SetPoint("TOPLEFT", x, y - 20)
    c.isSystemUpdating = true; c:SetMinMaxValues(minVal, maxVal); c:SetValueStep(step)
    local targetVal = db[key] or minVal; if targetVal < minVal then targetVal = minVal end; if targetVal > maxVal then targetVal = maxVal end; c:SetValue(targetVal)
    c.title:SetText(titleText); c.title:SetTextColor(0.7, 0.7, 0.7); c.valText:SetText(string.format("%.2f", targetVal):gsub("%.00", ""))
    c:SetScript("OnValueChanged", function(self, value) if self.isSystemUpdating then return end; if db[key] == value then return end; db[key] = value; c.valText:SetText(string.format("%.2f", value):gsub("%.00", "")); if callback then callback(value) end end)
    c.isSystemUpdating = false; c:Show()
    return c, y - 42
end

function Factory:CreateColorPicker(parent, x, y, width, titleText, db, key, callback)
    WF.UI.WidgetCounts.color = WF.UI.WidgetCounts.color + 1
    local c = WF.UI.WidgetPools.color[WF.UI.WidgetCounts.color]
    if not c then
        c = CreateFrame("Button", nil, UIParent); c:SetSize(16, 16); ApplyFlatSkin(c, 0, 0, 0, 1, 0, 0, 0, 1)
        c.tex = c:CreateTexture(nil, "ARTWORK"); c.tex:SetPoint("TOPLEFT", 1, -1); c.tex:SetPoint("BOTTOMRIGHT", -1, 1)
        c.text = CreateUIFont(c, 13, "LEFT"); c.text:SetPoint("LEFT", c, "RIGHT", 10, 0)
        c.classBtn = CreateFrame("Button", nil, c, "BackdropTemplate"); c.classBtn:SetSize(12, 12); ApplyFlatSkin(c.classBtn, CR, CG, CB, 1, 0, 0, 0, 1)
        c.classBtn:SetScript("OnEnter", function() c.classBtn:SetBackdropBorderColor(1, 1, 1, 1); ShowTooltipTemp(c.classBtn, L["Apply Class Color"] or "一键应用职业色", CR, CG, CB) end)
        c.classBtn:SetScript("OnLeave", function() c.classBtn:SetBackdropBorderColor(0, 0, 0, 1); GameTooltip:Hide() end)
        c:SetScript("OnEnter", function() c.text:SetTextColor(1, 1, 1) end); c:SetScript("OnLeave", function() c.text:SetTextColor(0.9, 0.9, 0.9) end)
        c:SetScript("OnMouseDown", function() c.text:SetPoint("LEFT", c, "RIGHT", 11, -1) end); c:SetScript("OnMouseUp", function() c.text:SetPoint("LEFT", c, "RIGHT", 10, 0) end)
        WF.UI.WidgetPools.color[WF.UI.WidgetCounts.color] = c
    end
    c:SetParent(parent); c:ClearAllPoints(); c:SetPoint("TOPLEFT", x, y); c.text:SetText(titleText); c.text:SetTextColor(0.9, 0.9, 0.9)
    c.classBtn:ClearAllPoints(); c.classBtn:SetPoint("LEFT", c.text, "RIGHT", 8, 0)
    local function UpdateColor() local col = db[key] or {r=1,g=1,b=1,a=1}; c.tex:SetColorTexture(col.r, col.g, col.b, col.a or 1) end
    UpdateColor()
    c.classBtn:SetScript("OnClick", function() db[key] = {r = CR, g = CG, b = CB, a = 1}; UpdateColor(); if callback then callback() end end)
    c:SetScript("OnClick", function()
        local col = db[key] or {r=1,g=1,b=1,a=1}
        local function OnColorSet() local r, g, b = ColorPickerFrame:GetColorRGB(); local a = 1; if ColorPickerFrame.GetColorAlpha then a = ColorPickerFrame:GetColorAlpha() elseif OpacitySliderFrame then a = OpacitySliderFrame:GetValue() end; db[key] = {r=r, g=g, b=b, a=a}; UpdateColor(); if callback then callback() end end
        local function OnColorCancel(prev) db[key] = {r=prev.r, g=prev.g, b=prev.b, a=prev.opacity}; UpdateColor(); if callback then callback() end end
        if ColorPickerFrame.SetupColorPickerAndShow then ColorPickerFrame:SetupColorPickerAndShow({ r=col.r, g=col.g, b=col.b, opacity=col.a or 1, hasOpacity=true, swatchFunc=OnColorSet, opacityFunc=OnColorSet, cancelFunc=OnColorCancel }) else ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = OnColorSet, OnColorSet, OnColorCancel; ColorPickerFrame:SetColorRGB(col.r, col.g, col.b); ColorPickerFrame.hasOpacity = true; ColorPickerFrame.opacity = col.a or 1; ColorPickerFrame:Show() end
    end)
    c:Show()
    return c, y - 26
end

function Factory:CreateDropdown(parent, x, y, width, titleText, db, key, options, callback)
    WF.UI.WidgetCounts.dropdown = WF.UI.WidgetCounts.dropdown + 1
    local c = WF.UI.WidgetPools.dropdown[WF.UI.WidgetCounts.dropdown]
    if not c then
        c = CreateFrame("Button", nil, UIParent); ApplyFlatSkin(c, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1)
        c.title = CreateUIFont(c, 12, "LEFT"); c.title:SetPoint("BOTTOMLEFT", c, "TOPLEFT", 0, 4)
        c.valText = CreateUIFont(c, 12, "CENTER"); c.valText:SetPoint("CENTER", c, "CENTER", 0, 0); c.valText:SetTextColor(CR, CG, CB)
        c.menu = CreateFrame("Frame", nil, c, "BackdropTemplate"); c.menu:SetPoint("TOPLEFT", c, "BOTTOMLEFT", 0, -2); ApplyFlatSkin(c.menu, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1); c.menu:SetFrameStrata("TOOLTIP"); c.menu:Hide()
        c.scrollFrame = CreateFrame("ScrollFrame", nil, c.menu); c.scrollChild = CreateFrame("Frame"); c.scrollFrame:SetScrollChild(c.scrollChild)
        c.items = {}
        c:SetScript("OnEnter", function() ApplyFlatSkin(c, 0.1, 0.1, 0.1, 1, 0, 0, 0, 1); c.title:SetTextColor(1,1,1) end); c:SetScript("OnLeave", function() ApplyFlatSkin(c, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1); c.title:SetTextColor(0.7,0.7,0.7) end)
        c:SetScript("OnClick", function() if c.menu:IsShown() then c.menu:Hide() else c.menu:Show() end end)
        WF.UI.WidgetPools.dropdown[WF.UI.WidgetCounts.dropdown] = c
    end
    c:SetParent(parent); local boxWidth = width - 10; c:SetSize(boxWidth, 22); c:ClearAllPoints(); c:SetPoint("TOPLEFT", x, y - 18)
    c.title:SetText(titleText); c.title:SetTextColor(0.7, 0.7, 0.7)
    local function GetOptText(val) for _, v in ipairs(options) do if v.value == val then return v.text end end return tostring(val) end
    c.valText:SetText(GetOptText(db[key]))
    
    local showScroll = #options > 8
    c.menu:SetSize(boxWidth, (showScroll and 8 or #options) * 22 + 4); c.scrollFrame:SetPoint("TOPLEFT", 4, -2); c.scrollFrame:SetPoint("BOTTOMRIGHT", showScroll and -26 or -4, 2)
    if showScroll and not c.scrollFrame.ScrollBar then c.scrollFrame.ScrollBar = CreateFrame("EventFrame", nil, c.scrollFrame, "MinimalScrollBar"); c.scrollFrame.ScrollBar:SetPoint("TOPLEFT", c.scrollFrame, "TOPRIGHT", 6, 0); c.scrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", c.scrollFrame, "BOTTOMRIGHT", 6, 0); ScrollUtil.InitScrollFrameWithScrollBar(c.scrollFrame, c.scrollFrame.ScrollBar) end
    if c.scrollFrame.ScrollBar then if showScroll then c.scrollFrame.ScrollBar:Show() else c.scrollFrame.ScrollBar:Hide() end end

    c.scrollChild:SetSize(boxWidth - (showScroll and 30 or 10), #options * 22)
    for i, item in ipairs(c.items) do item:Hide() end

    for i, opt in ipairs(options) do
        local item = c.items[i]
        if not item then
            item = CreateFrame("Button", nil, c.scrollChild)
            item.itxt = CreateUIFont(item, 12, "LEFT"); item.itxt:SetPoint("LEFT", 10, 0)
            item:SetScript("OnEnter", function() ApplyFlatSkin(item, 0.15, 0.15, 0.15, 1, 0,0,0,0) end); item:SetScript("OnLeave", function() ApplyFlatSkin(item, 0, 0, 0, 0, 0,0,0,0) end)
            c.items[i] = item
        end
        item:SetSize(boxWidth - (showScroll and 30 or 10), 22); item:ClearAllPoints(); item:SetPoint("TOPLEFT", 0, -(i-1)*22); item.itxt:SetText(opt.text)
        item:SetScript("OnClick", function() db[key] = opt.value; c.valText:SetText(opt.text); c.menu:Hide(); if callback then callback(opt.value) end end); item:Show()
    end
    c:Show()
    return c, y - 44
end

function Factory:CreateGroupHeader(parent, x, y, width, titleText, isExpanded, onClick)
    WF.UI.WidgetCounts.header = WF.UI.WidgetCounts.header + 1
    local btn = WF.UI.WidgetPools.header[WF.UI.WidgetCounts.header]
    if not btn then
        btn = CreateFrame("Button", nil, UIParent, "BackdropTemplate"); ApplyFlatSkin(btn, 0.1, 0.1, 0.1, 0.8, 0, 0, 0, 0)
        btn.accent = btn:CreateTexture(nil, "OVERLAY"); btn.accent:SetPoint("TOPLEFT"); btn.accent:SetPoint("BOTTOMLEFT"); btn.accent:SetWidth(2)
        btn.text = CreateUIFont(btn, 13, "LEFT"); btn.icon = btn:CreateTexture(nil, "OVERLAY"); btn.icon:SetSize(14, 14); btn.icon:SetTexture(ICON_ARROW)
        btn:SetScript("OnMouseDown", function() btn.text:SetPoint("LEFT", 16, -1); btn.icon:SetPoint("RIGHT", -7, -1) end); btn:SetScript("OnMouseUp", function() btn.text:SetPoint("LEFT", 15, 0); btn.icon:SetPoint("RIGHT", -8, 0) end)
        WF.UI.WidgetPools.header[WF.UI.WidgetCounts.header] = btn
    end
    
    btn:SetParent(parent); btn:SetSize(width, 26); btn:ClearAllPoints(); btn:SetPoint("TOPLEFT", x, y)
    btn.text:SetPoint("LEFT", 15, 0); btn.text:SetText(titleText); btn.icon:SetPoint("RIGHT", -8, 0)
    
    btn.accent:SetColorTexture(isExpanded and CR or 0.25, isExpanded and CG or 0.25, isExpanded and CB or 0.25, 1)
    btn.text:SetTextColor(isExpanded and 1 or 0.7, isExpanded and 1 or 0.7, isExpanded and 1 or 0.7)
    btn.icon:SetRotation(isExpanded and -math.pi/2 or 0); btn.icon:SetVertexColor(isExpanded and CR or 0.5, isExpanded and CG or 0.5, isExpanded and CB or 0.5, 1)
    
    btn:SetScript("OnEnter", function() ApplyFlatSkin(btn, 0.15, 0.15, 0.15, 1, 0, 0, 0, 0); btn.accent:SetColorTexture(CR, CG, CB, 1); btn.icon:SetVertexColor(CR, CG, CB, 1); btn.text:SetTextColor(1, 1, 1) end)
    btn:SetScript("OnLeave", function() ApplyFlatSkin(btn, 0.1, 0.1, 0.1, 0.8, 0, 0, 0, 0); btn.accent:SetColorTexture(isExpanded and CR or 0.25, isExpanded and CG or 0.25, isExpanded and CB or 0.25, 1); btn.icon:SetVertexColor(isExpanded and CR or 0.5, isExpanded and CG or 0.5, isExpanded and CB or 0.5, 1); btn.text:SetTextColor(isExpanded and 1 or 0.7, isExpanded and 1 or 0.7, isExpanded and 1 or 0.7) end)
    btn:SetScript("OnClick", function() if onClick then onClick() end end); btn:Show()
    return btn, y - 30
end

local GroupState = {}
function WF.UI:RenderOptionsGroup(parent, startX, startY, colWidth, options, onChange, level)
    local y = startY; level = level or 0
    local indent = level * 12; local cx = startX + indent; local itemWidth = colWidth - indent

    for _, opt in ipairs(options) do
        if opt.type == "group" then
            if GroupState[opt.key] == nil then GroupState[opt.key] = false end
            local btn
            btn, y = Factory:CreateGroupHeader(parent, cx, y, itemWidth, opt.text, GroupState[opt.key], function()
                GroupState[opt.key] = not GroupState[opt.key]; WF.UI:RefreshCurrentPanel(); if type(onChange) == "function" then onChange("UI_REFRESH") end
            end)
            if GroupState[opt.key] and opt.childs then y = self:RenderOptionsGroup(parent, cx, y - 4, itemWidth, opt.childs, onChange, level + 1); y = y - 6 end
        elseif opt.type == "toggle" then 
            _, y = Factory:CreateToggle(parent, cx + 8, y, itemWidth, opt.text, opt.db, opt.key, function(val) if opt.requireReload then WF.UI:ShowReloadPopup() else if onChange then onChange(val) end end end)
        elseif opt.type == "slider" then 
            _, y = Factory:CreateSlider(parent, cx + 8, y, itemWidth, opt.text, opt.min, opt.max, opt.step, opt.db, opt.key, function(val) if opt.requireReload then WF.UI:ShowReloadPopup() else if onChange then onChange(val) end end end)
        elseif opt.type == "color" then 
            _, y = Factory:CreateColorPicker(parent, cx + 8, y, itemWidth, opt.text, opt.db, opt.key, function() if opt.requireReload then WF.UI:ShowReloadPopup() else if onChange then onChange() end end end)
        elseif opt.type == "dropdown" then 
            _, y = Factory:CreateDropdown(parent, cx + 8, y, itemWidth, opt.text, opt.db, opt.key, opt.options, function(val) if opt.requireReload then WF.UI:ShowReloadPopup() else if onChange then onChange(val) end end end)
        elseif opt.type == "input" then 
            _, y = Factory:CreateInput(parent, cx + 8, y, itemWidth, opt.text, opt.db, opt.key, function(val) if opt.requireReload then WF.UI:ShowReloadPopup() else if onChange then onChange(val) end end end)
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

local menuExpanded = {}
local function BuildMenuTree()
    local tree = {}; local map = {}
    for _, item in ipairs(WF.UI.Menus) do item.childs = {}; map[item.id] = item end
    for _, item in ipairs(WF.UI.Menus) do if item.parent and map[item.parent] then table.insert(map[item.parent].childs, item) else table.insert(tree, item) end end
    local function sortTree(node) table.sort(node, function(a, b) return (a.order or 99) < (b.order or 99) end); for _, child in ipairs(node) do sortTree(child.childs) end end
    sortTree(tree)
    local flat = {}; local function flatten(node, lvl) for _, item in ipairs(node) do item.level = lvl; table.insert(flat, item); flatten(item.childs, lvl + 1) end end
    flatten(tree, 0); return flat
end

local function RenderTreeMenu()
    local sidebar = WF.MainFrame.Sidebar; local isExpanded = sidebar.isExpanded
    if not sidebar.buttons then sidebar.buttons = {} end
    for _, b in ipairs(sidebar.buttons) do b:Hide() end
    local yOffset = -50
    local activeIndicator = sidebar.activeIndicator
    if not activeIndicator then activeIndicator = sidebar:CreateTexture(nil, "OVERLAY"); activeIndicator:SetWidth(3); activeIndicator:SetColorTexture(CR, CG, CB, 1); sidebar.activeIndicator = activeIndicator end

    local currentMenu = BuildMenuTree()
    local btnIndex = 1

    local function AddBtn(item)
        local btn = sidebar.buttons[btnIndex]
        if not btn then
            btn = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
            local hoverGlow = btn:CreateTexture(nil, "BACKGROUND"); hoverGlow:SetAllPoints(); hoverGlow:SetColorTexture(CR, CG, CB, 0); btn.hoverGlow = hoverGlow
            local tIcon = btn:CreateTexture(nil, "OVERLAY"); tIcon:SetSize(18, 18); tIcon:SetPoint("LEFT", 10, 0); btn.tIcon = tIcon
            local icon = btn:CreateTexture(nil, "OVERLAY"); icon:SetSize(14, 14); btn.arrowIcon = icon
            local text = CreateUIFont(btn, 13, "LEFT"); btn.text = text
            sidebar.buttons[btnIndex] = btn
        end
        btnIndex = btnIndex + 1

        btn:SetHeight(28); btn:SetPoint("LEFT", 0, 0); btn:SetPoint("RIGHT", 0, 0); btn:SetPoint("TOP", 0, yOffset)
        ApplyFlatSkin(btn, 0.1, 0.1, 0.1, 0, 0,0,0,0)
        local xIndent = (item.level * 18)
        
        if item.icon then btn.tIcon:SetTexture(item.icon); btn.tIcon:SetVertexColor(0.6, 0.6, 0.6, 1); if item.type == "root" and item.id == "HOME" then btn.tIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9) else btn.tIcon:SetTexCoord(0, 1, 0, 1) end; btn.tIcon:Show() else btn.tIcon:Hide() end
        if item.type == "root" or item.type == "group" then if not item.icon then btn.arrowIcon:SetPoint("LEFT", xIndent + 10, 0); btn.arrowIcon:SetTexture(ICON_ARROW); btn.arrowIcon._wf_rot = menuExpanded[item.id] and -math.pi/2 or 0; btn.arrowIcon:SetRotation(btn.arrowIcon._wf_rot); btn.arrowIcon:SetVertexColor(CR, CG, CB, 1); btn.arrowIcon:Show() else btn.arrowIcon:Hide() end else btn.arrowIcon:Hide() end
        btn.text:SetPoint("LEFT", xIndent + 35, 0); btn.text:SetText(item.name)
        
        if item.type == "root" then btn.text:SetTextColor(CR, CG, CB) else btn.text:SetTextColor(0.6, 0.6, 0.6) end
        if not isExpanded then btn.text:Hide() else btn.text:Show() end

        btn:SetScript("OnMouseDown", function() if item.icon then btn.tIcon:SetPoint("LEFT", 11, -1) end; if btn.arrowIcon:IsShown() then btn.arrowIcon:SetPoint("LEFT", xIndent + 11, -1) end; btn.text:SetPoint("LEFT", xIndent + 36, -1) end)
        btn:SetScript("OnMouseUp", function() if item.icon then btn.tIcon:SetPoint("LEFT", 10, 0) end; if btn.arrowIcon:IsShown() then btn.arrowIcon:SetPoint("LEFT", xIndent + 10, 0) end; btn.text:SetPoint("LEFT", xIndent + 35, 0) end)
        btn:SetScript("OnClick", function()
            if item.type == "root" or item.type == "group" then menuExpanded[item.id] = not menuExpanded[item.id] end
            if not sidebar.isExpanded then
                sidebar.isExpanded = true; sidebar:SetWidth(SIDEBAR_WIDTH_EXPANDED)
                if sidebar.mIcon then local startRad = sidebar.mIcon._wf_rot or 0; WF.UI:Animate(sidebar.mIcon, "rotation", 0.2, function(ease) local currentRad = Lerp(startRad, -math.pi/2, ease); sidebar.mIcon:SetRotation(currentRad); sidebar.mIcon._wf_rot = currentRad end) end
            end
            if item.key then
                for _, b in ipairs(sidebar.buttons) do if b.tIcon then b.tIcon:SetVertexColor(0.6, 0.6, 0.6, 1) end; if b.text and b.itemType ~= "root" then b.text:SetTextColor(0.6, 0.6, 0.6) end end
                btn.text:SetTextColor(1, 1, 1); if btn.tIcon then btn.tIcon:SetVertexColor(CR, CG, CB, 1) end
                activeIndicator:ClearAllPoints(); activeIndicator:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0); activeIndicator:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0); activeIndicator:Show()
                WF.UI.CurrentNodeKey = item.key; WF.UI:RefreshCurrentPanel(); WF.MainFrame.TitleBar.titleText:SetText("|cffffffffW|cff00ffccF|r // "..item.name)
            end
            RenderTreeMenu()
        end)
        btn:SetScript("OnEnter", function() if not sidebar.isExpanded then ShowTooltipTemp(btn, item.name, CR, CG, CB) end; WF.UI:Animate(btn, "hover", 0.15, function(ease) btn.hoverGlow:SetColorTexture(CR, CG, CB, Lerp(0, 0.15, ease)) end) end)
        btn:SetScript("OnLeave", function() if not sidebar.isExpanded and GameTooltip:IsOwned(btn) then GameTooltip:Hide() end; WF.UI:Animate(btn, "hover", 0.15, function(ease) btn.hoverGlow:SetColorTexture(CR, CG, CB, Lerp(0.15, 0, ease)) end) end)
        
        btn.itemType = item.type; btn:Show(); yOffset = yOffset - 30
    end

    for _, item in ipairs(currentMenu) do
        if item.type == "root" then AddBtn(item) elseif isExpanded and item.parent and menuExpanded[item.parent] then
            local pNode = nil; for _, n in ipairs(currentMenu) do if n.id == item.parent then pNode = n; break end end
            if pNode and (pNode.type == "root" or (pNode.parent and menuExpanded[pNode.parent])) then AddBtn(item) end
        end
    end
end

function WF:ToggleUI()
    if not WF.MainFrame then
        local frame = CreateFrame("Frame", "WishFlexMainUI", UIParent, "BackdropTemplate")
        WF.MainFrame = frame; frame:Hide(); WF.db = WF.db or {}; local initialScale = WF.db.uiScale or 1
        frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT); frame:SetPoint("CENTER"); frame:SetMovable(true); frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton"); frame:SetScript("OnDragStart", frame.StartMoving); frame:SetScript("OnDragStop", frame.StopMovingOrSizing); frame:SetFrameStrata("DIALOG")
        frame:SetResizable(true); frame:SetResizeBounds(700, 500, 1400, 1000)
        ApplyFlatSkin(frame, 0.08, 0.08, 0.08, 0.95, CR, CG, CB, 1); frame:SetScale(initialScale)

        local resizeGrip = CreateFrame("Button", nil, frame)
        resizeGrip:SetSize(16, 16); resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
        resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"); resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight"); resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        resizeGrip:SetScript("OnMouseDown", function(self, button) if button == "LeftButton" then frame:StartSizing("BOTTOMRIGHT") end end); resizeGrip:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() end)

        local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        sidebar:SetPoint("TOPLEFT", 1, -1); sidebar:SetPoint("BOTTOMLEFT", 1, 1); ApplyFlatSkin(sidebar, 0.1, 0.1, 0.1, 1, 0, 0, 0, 1); frame.Sidebar = sidebar

        local menuBtn = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
        menuBtn:SetSize(40, 26); menuBtn:SetPoint("TOP", 0, -10)
        local mIcon = menuBtn:CreateTexture(nil, "ARTWORK")
        mIcon:SetSize(16, 16); mIcon:SetPoint("CENTER"); mIcon:SetTexture(ICON_ARROW); mIcon:SetVertexColor(CR, CG, CB, 1); sidebar.mIcon = mIcon
        
        menuBtn:SetScript("OnEnter", function() if not sidebar.isExpanded then ShowTooltipTemp(menuBtn, L["MENU"] or "菜单", CR, CG, CB) end end)
        menuBtn:SetScript("OnLeave", function() if GameTooltip:IsOwned(menuBtn) then GameTooltip:Hide() end end)
        menuBtn:SetScript("OnMouseDown", function() mIcon:SetPoint("CENTER", 1, -1) end); menuBtn:SetScript("OnMouseUp", function() mIcon:SetPoint("CENTER", 0, 0) end)
        menuBtn:SetScript("OnClick", function()
            sidebar.isExpanded = not sidebar.isExpanded; sidebar:SetWidth(sidebar.isExpanded and SIDEBAR_WIDTH_EXPANDED or SIDEBAR_WIDTH_COLLAPSED); RenderTreeMenu()
            local startRad = mIcon._wf_rot or 0
            WF.UI:Animate(mIcon, "rotation", 0.2, function(ease) local currentRad = Lerp(startRad, sidebar.isExpanded and -math.pi/2 or 0, ease); mIcon:SetRotation(currentRad); mIcon._wf_rot = currentRad end)
            WF.UI:UpdateTargetWidth(WF.UI.CurrentReqWidth, true)
        end)

        local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        titleBar:SetHeight(TITLE_HEIGHT); titleBar:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 1, 0); titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        ApplyFlatSkin(titleBar, 0.12, 0.12, 0.12, 1, 0, 0, 0, 1); frame.TitleBar = titleBar

        local titleText = CreateUIFont(titleBar, 14, "LEFT")
        titleText:SetPoint("LEFT", 15, 0); titleText:SetText("|cffffffffW|cff00ffccF|r // "..L["Home"]); titleBar.titleText = titleText

        local closeBtn = CreateFrame("Button", nil, titleBar)
        closeBtn:SetSize(20, 20); closeBtn:SetPoint("RIGHT", -8, 0)
        local cIcon = closeBtn:CreateTexture(nil, "ARTWORK"); cIcon:SetPoint("CENTER"); cIcon:SetSize(14, 14); cIcon:SetTexture(ICON_CLOSE); cIcon:SetVertexColor(0.6, 0.6, 0.6, 1)
        closeBtn:SetScript("OnEnter", function() cIcon:SetVertexColor(CR, CG, CB, 1) end); closeBtn:SetScript("OnLeave", function() cIcon:SetVertexColor(0.6, 0.6, 0.6, 1) end)
        closeBtn:SetScript("OnMouseDown", function() cIcon:SetPoint("CENTER", 1, -1) end); closeBtn:SetScript("OnMouseUp", function() cIcon:SetPoint("CENTER", 0, 0) end)
        closeBtn:SetScript("OnClick", function() frame:Hide() end)

        local gearBtn = CreateFrame("Button", nil, titleBar)
        gearBtn:SetSize(20, 20); gearBtn:SetPoint("RIGHT", closeBtn, "LEFT", -10, 0)
        local gIcon = gearBtn:CreateTexture(nil, "ARTWORK"); gIcon:SetPoint("CENTER"); gIcon:SetSize(14, 14); gIcon:SetTexture(ICON_GEAR); gIcon:SetVertexColor(0.6, 0.6, 0.6, 1)
        gearBtn:SetScript("OnEnter", function() gIcon:SetVertexColor(CR, CG, CB, 1); ShowTooltipTemp(gearBtn, L["Open Blizzard CD Settings"] or "打开高级冷却设置 (/cds)", CR, CG, CB) end)
        gearBtn:SetScript("OnLeave", function() gIcon:SetVertexColor(0.6, 0.6, 0.6, 1); GameTooltip:Hide() end)
        gearBtn:SetScript("OnMouseDown", function() gIcon:SetPoint("CENTER", 1, -1) end); gearBtn:SetScript("OnMouseUp", function() gIcon:SetPoint("CENTER", 0, 0) end)
        gearBtn:SetScript("OnClick", function() 
            if _G.CooldownViewerSettings then if _G.CooldownViewerSettings:IsShown() then _G.CooldownViewerSettings:Hide() else _G.CooldownViewerSettings:Show() end; return end
            for name, func in pairs(SlashCmdList) do local i = 1; while _G["SLASH_"..name..i] do if string.lower(_G["SLASH_"..name..i]) == "/cds" then func(""); return end; i = i + 1 end end
        end)
        
        local scalePlusBtn = CreateFrame("Button", nil, titleBar)
        scalePlusBtn:SetSize(20, 20); scalePlusBtn:SetPoint("RIGHT", gearBtn, "LEFT", -15, 0)
        scalePlusBtn.text = CreateUIFont(scalePlusBtn, 16, "CENTER"); scalePlusBtn.text:SetPoint("CENTER"); scalePlusBtn.text:SetText("+"); scalePlusBtn.text:SetTextColor(0.6, 0.6, 0.6)
        scalePlusBtn:SetScript("OnEnter", function() scalePlusBtn.text:SetTextColor(CR, CG, CB) end); scalePlusBtn:SetScript("OnLeave", function() scalePlusBtn.text:SetTextColor(0.6, 0.6, 0.6) end)
        scalePlusBtn:SetScript("OnMouseDown", function() scalePlusBtn.text:SetPoint("CENTER", 1, -1) end); scalePlusBtn:SetScript("OnMouseUp", function() scalePlusBtn.text:SetPoint("CENTER", 0, 0) end)
        
        local scaleTxt = CreateUIFont(titleBar, 12, "CENTER")
        scaleTxt:SetPoint("RIGHT", scalePlusBtn, "LEFT", -5, 0)
        
        local scaleMinusBtn = CreateFrame("Button", nil, titleBar)
        scaleMinusBtn:SetSize(20, 20); scaleMinusBtn:SetPoint("RIGHT", scaleTxt, "LEFT", -5, 0)
        scaleMinusBtn.text = CreateUIFont(scaleMinusBtn, 16, "CENTER"); scaleMinusBtn.text:SetPoint("CENTER"); scaleMinusBtn.text:SetText("-"); scaleMinusBtn.text:SetTextColor(0.6, 0.6, 0.6)
        scaleMinusBtn:SetScript("OnEnter", function() scaleMinusBtn.text:SetTextColor(CR, CG, CB) end); scaleMinusBtn:SetScript("OnLeave", function() scaleMinusBtn.text:SetTextColor(0.6, 0.6, 0.6) end)
        scaleMinusBtn:SetScript("OnMouseDown", function() scaleMinusBtn.text:SetPoint("CENTER", 1, -1) end); scaleMinusBtn:SetScript("OnMouseUp", function() scaleMinusBtn.text:SetPoint("CENTER", 0, 0) end)

        local function UpdateScaleDisplay() WF.db = WF.db or {}; local s = WF.db.uiScale or 1; scaleTxt:SetText(math.floor(s * 100) .. "%"); frame:SetScale(s) end
        scalePlusBtn:SetScript("OnClick", function() WF.db = WF.db or {}; WF.db.uiScale = math.min(2.0, (WF.db.uiScale or 1) + 0.05); UpdateScaleDisplay() end)
        scaleMinusBtn:SetScript("OnClick", function() WF.db = WF.db or {}; WF.db.uiScale = math.max(0.5, (WF.db.uiScale or 1) - 0.05); UpdateScaleDisplay() end)
        UpdateScaleDisplay()

        local content = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        content:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0); content:SetPoint("BOTTOMRIGHT", -1, 1); content:SetFrameLevel(frame:GetFrameLevel() + 1)
        local scrollFrame, scrollChild = Factory:CreateScrollArea(content)
        content.scrollFrame = scrollFrame; content.scrollChild = scrollChild; frame.Content = content; WF.ScrollChild = scrollChild
    end
    
    if not WF.MainFrame:IsShown() then
        wipe(GroupState); wipe(menuExpanded)
        local sidebar = WF.MainFrame.Sidebar
        sidebar.isExpanded = false; sidebar:SetWidth(SIDEBAR_WIDTH_COLLAPSED)
        if sidebar.mIcon then sidebar.mIcon:SetRotation(0) end

        RenderTreeMenu()
        local firstBtn = sidebar.buttons[1]
        if firstBtn then
            for _, b in ipairs(sidebar.buttons) do if b.tIcon then b.tIcon:SetVertexColor(0.6, 0.6, 0.6, 1) end; if b.text and b.itemType ~= "root" then b.text:SetTextColor(0.6, 0.6, 0.6) end end
            firstBtn.text:SetTextColor(1, 1, 1); if firstBtn.tIcon then firstBtn.tIcon:SetVertexColor(CR, CG, CB, 1) end
            if sidebar.activeIndicator then sidebar.activeIndicator:ClearAllPoints(); sidebar.activeIndicator:SetPoint("TOPLEFT", firstBtn, "TOPLEFT", 0, 0); sidebar.activeIndicator:SetPoint("BOTTOMLEFT", firstBtn, "BOTTOMLEFT", 0, 0); sidebar.activeIndicator:Show() end
            WF.UI.CurrentNodeKey = "WF_HOME"; WF.UI:RefreshCurrentPanel(); WF.MainFrame.TitleBar.titleText:SetText("|cffffffffW|cff00ffccF|r // "..(L["Home"] or "首页"))
        end
        WF.MainFrame:Show()
    else WF.MainFrame:Hide() end
end

SLASH_WISHFLEX1 = "/wf"; SLASH_WISHFLEX2 = "/wishflex"
SlashCmdList["WISHFLEX"] = function() WF:ToggleUI() end