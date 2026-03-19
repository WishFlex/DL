local AddonName, ns = ...
local WF = ns.WF
local L = ns.L

-- =========================================
-- [1. 主题与颜色引擎]
-- =========================================
local _, playerClass = UnitClass("player")
local ClassColor = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass] or {r=1, g=1, b=1}
local CR, CG, CB = ClassColor.r, ClassColor.g, ClassColor.b

local function ApplyFlatSkin(frame, r, g, b, a, br, bg, bb, ba)
    if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(r or 0.1, g or 0.1, b or 0.1, a or 0.95)
    frame:SetBackdropBorderColor(br or 0, bg or 0, bb or 0, ba or 1)
end

local function CreateUIFont(parent, size, justify, isBold)
    local text = parent:CreateFontString(nil, "OVERLAY")
    local font = isBold and "Fonts\\ARKai_T.ttf" or STANDARD_TEXT_FONT
    text:SetFont(font, size or 14, "OUTLINE")
    text:SetJustifyH(justify or "CENTER")
    return text
end

-- =========================================
-- [2. 原生 UI 组件库]
-- =========================================
local UI_Factory = {}

function UI_Factory:CreateScrollArea(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)
    
    return scrollFrame, scrollChild
end

function UI_Factory:CreateToggle(parent, yOffset, titleText, db, key, callback)
    local btn = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
    btn:SetPoint("TOPLEFT", 20, yOffset)
    btn:SetChecked(db[key])
    
    btn:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    local ct = btn:GetCheckedTexture()
    if ct then ct:SetVertexColor(CR, CG, CB) end
    
    local text = CreateUIFont(btn, 14, "LEFT")
    text:SetPoint("LEFT", btn, "RIGHT", 5, 0)
    text:SetText(titleText)
    
    btn:SetScript("OnClick", function(self)
        db[key] = self:GetChecked()
        if callback then callback(db[key]) end
    end)
    return btn, yOffset - 30
end

local sliderCounter = 0
function UI_Factory:CreateSlider(parent, yOffset, titleText, minVal, maxVal, step, db, key, callback)
    sliderCounter = sliderCounter + 1
    local sliderName = "WishFlexSlider_" .. key .. "_" .. sliderCounter
    
    local slider = CreateFrame("Slider", sliderName, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 25, yOffset - 15)
    slider:SetWidth(200)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(db[key] or minVal)
    
    if _G[sliderName .. "Low"] then _G[sliderName .. "Low"]:SetText(minVal) end
    if _G[sliderName .. "High"] then _G[sliderName .. "High"]:SetText(maxVal) end
    
    local text = _G[sliderName .. "Text"]
    if text then
        text:SetText(titleText .. ": " .. (db[key] or minVal))
        text:SetTextColor(CR, CG, CB)
    end

    slider:SetScript("OnValueChanged", function(self, value)
        db[key] = value
        if text then text:SetText(titleText .. ": " .. string.format("%.2f", value):gsub("%.00", "")) end
        if callback then callback(value) end
    end)
    return slider, yOffset - 50
end

function UI_Factory:CreateHeader(parent, yOffset, titleText)
    local title = CreateUIFont(parent, 16, "LEFT", true)
    title:SetPoint("TOPLEFT", 15, yOffset)
    title:SetText(titleText)
    title:SetTextColor(CR, CG, CB)
    
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(CR, CG, CB, 0.3)
    line:SetSize(400, 1)
    line:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    
    return title, yOffset - 35
end

-- =========================================
-- [3. 渲染具体的模块设置]
-- =========================================
local function RenderCombatSettings(tabName, scrollChild)
    -- 安全清理旧内容 (防弹版)
    local children = {scrollChild:GetChildren()}
    for _, child in ipairs(children) do 
        if type(child) == "table" and child.Hide then child:Hide() end 
    end
    local regions = {scrollChild:GetRegions()}
    for _, region in ipairs(regions) do 
        if type(region) == "table" and region.Hide then region:Hide() end 
    end

    local y = -10

    if tabName == "classResource" then
        local db = WF.db.classResource or {}
        _, y = UI_Factory:CreateHeader(scrollChild, y, L["Class Resource"] or "资源条设置")
        local t1; t1, y = UI_Factory:CreateToggle(scrollChild, y, L["Enable"] or "启用", db, "enable", function() print(L["Requires Reload"]) end)
        local t2; t2, y = UI_Factory:CreateToggle(scrollChild, y, L["Align With CD"] or "依附于冷却条排版", db, "alignWithCD", function() if WF.ClassResourceAPI then WF.ClassResourceAPI:UpdateLayout() end end)
        local s1; s1, y = UI_Factory:CreateSlider(scrollChild, y, L["Width"] or "宽度", 100, 500, 1, db, "width", function() if WF.ClassResourceAPI then WF.ClassResourceAPI:UpdateLayout() end end)

    elseif tabName == "cooldownCustom" then
        local db = WF.db.cooldownCustom or {}
        local yBackup = y
        
        -- 左侧列：通用与尺寸设置
        _, y = UI_Factory:CreateHeader(scrollChild, y, L["Cooldown Custom"] or "冷却管理器通用")
        local t1; t1, y = UI_Factory:CreateToggle(scrollChild, y, L["Enable"] or "启用模块", db, "enable", function() print(L["Requires Reload"]) end)
        local t2; t2, y = UI_Factory:CreateToggle(scrollChild, y, "转圈动画反向", db, "reverseSwipe", function() if WF.ClassResourceAPI then WF.ClassResourceAPI:UpdateLayout() end end)
        
        _, y = UI_Factory:CreateHeader(scrollChild, y - 10, "核心爆发区 (Essential)")
        if not db.Essential then db.Essential = {} end
        local t3; t3, y = UI_Factory:CreateToggle(scrollChild, y, "启用双排布局", db.Essential, "enableCustomLayout", function() print(L["Requires Reload"]) end)
        local s1; s1, y = UI_Factory:CreateSlider(scrollChild, y, "第一排图标上限", 1, 15, 1, db.Essential, "maxPerRow", function() end)
        local s2; s2, y = UI_Factory:CreateSlider(scrollChild, y, "列间距", 0, 20, 1, db.Essential, "iconGap", function() end)
        local s3; s3, y = UI_Factory:CreateSlider(scrollChild, y, "第一排图标宽度", 20, 80, 1, db.Essential, "row1Width", function() end)
        local s4; s4, y = UI_Factory:CreateSlider(scrollChild, y, "第二排图标宽度", 20, 80, 1, db.Essential, "row2Width", function() end)

        _, y = UI_Factory:CreateHeader(scrollChild, y - 10, "功能技能区 (Utility)")
        if not db.Utility then db.Utility = {} end
        local t4; t4, y = UI_Factory:CreateToggle(scrollChild, y, "吸附到玩家头像边", db.Utility, "attachToPlayer", function() print(L["Requires Reload"]) end)
        local s5; s5, y = UI_Factory:CreateSlider(scrollChild, y, "图标宽度", 20, 80, 1, db.Utility, "width", function() end)

        -- 右侧列：特效与发光设置
        local yRight = yBackup
        local rightX = 350 

        local rTitle = CreateUIFont(scrollChild, 16, "LEFT", true)
        rTitle:SetPoint("TOPLEFT", rightX + 15, yRight)
        rTitle:SetText("动作条发光特效")
        rTitle:SetTextColor(CR, CG, CB)
        
        local rLine = scrollChild:CreateTexture(nil, "ARTWORK")
        rLine:SetColorTexture(CR, CG, CB, 0.3)
        rLine:SetSize(400, 1)
        rLine:SetPoint("TOPLEFT", rTitle, "BOTTOMLEFT", 0, -5)
        yRight = yRight - 35

        local function RightToggle(yPos, text, dbTarget, key)
            local btn = CreateFrame("CheckButton", nil, scrollChild, "ChatConfigCheckButtonTemplate")
            btn:SetPoint("TOPLEFT", rightX + 20, yPos)
            btn:SetChecked(dbTarget[key])
            btn:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
            local ct = btn:GetCheckedTexture(); if ct then ct:SetVertexColor(CR, CG, CB) end
            local font = CreateUIFont(btn, 14, "LEFT"); font:SetPoint("LEFT", btn, "RIGHT", 5, 0); font:SetText(text)
            btn:SetScript("OnClick", function(self) dbTarget[key] = self:GetChecked(); print(L["Requires Reload"]) end)
            return yPos - 30
        end

        local function RightSlider(yPos, text, minV, maxV, step, dbTarget, key)
            sliderCounter = sliderCounter + 1
            local sliderName = "WishFlexSlider_Right_" .. key .. "_" .. sliderCounter
            local slider = CreateFrame("Slider", sliderName, scrollChild, "OptionsSliderTemplate")
            slider:SetPoint("TOPLEFT", rightX + 25, yPos - 15)
            slider:SetWidth(180)
            slider:SetMinMaxValues(minV, maxV)
            slider:SetValueStep(step)
            slider:SetObeyStepOnDrag(true)
            slider:SetValue(dbTarget[key] or minV)
            if _G[sliderName.."Low"] then _G[sliderName.."Low"]:SetText(minV) end
            if _G[sliderName.."High"] then _G[sliderName.."High"]:SetText(maxV) end
            local txt = _G[sliderName.."Text"]; if txt then txt:SetText(text .. ": " .. (dbTarget[key] or minV)); txt:SetTextColor(CR, CG, CB) end
            slider:SetScript("OnValueChanged", function(self, val) dbTarget[key] = val; if txt then txt:SetText(text .. ": " .. string.format("%.2f", val):gsub("%.00", "")) end end)
            return yPos - 50
        end

        yRight = RightToggle(yRight, "开启爆发技能发光", db, "glowEnable")
        yRight = RightSlider(yRight, "像素线条数", 1, 20, 1, db, "glowPixelLines")
        yRight = RightSlider(yRight, "旋转频率", -2, 2, 0.05, db, "glowPixelFrequency")
        yRight = RightSlider(yRight, "线条粗细", 1, 10, 1, db, "glowPixelThickness")
        
        y = math.min(y, yRight)

    elseif tabName == "glow" then
        local db = WF.db.glow or {}
        _, y = UI_Factory:CreateHeader(scrollChild, y, L["Action Button Glow"] or "动作条发光")
        local t1; t1, y = UI_Factory:CreateToggle(scrollChild, y, L["Enable"] or "启用", db, "enable", function() print(L["Requires Reload"]) end)
        local s1; s1, y = UI_Factory:CreateSlider(scrollChild, y, "像素线条数", 1, 20, 1, db, "lines")
        local s2; s2, y = UI_Factory:CreateSlider(scrollChild, y, "旋转频率", -2, 2, 0.05, db, "frequency")
        local s3; s3, y = UI_Factory:CreateSlider(scrollChild, y, "线条粗细", 1, 10, 1, db, "thickness")

    elseif tabName == "auraGlow" then
        local db = WF.db.auraGlow or {}
        if not db.independent then db.independent = {} end
        _, y = UI_Factory:CreateHeader(scrollChild, y, L["Aura Glow"] or "技能状态高亮")
        local t1; t1, y = UI_Factory:CreateToggle(scrollChild, y, L["Enable"] or "启用", db, "enable", function() print(L["Requires Reload"]) end)
        local t2; t2, y = UI_Factory:CreateToggle(scrollChild, y, "全局发光特效", db, "glowEnable")
        _, y = UI_Factory:CreateHeader(scrollChild, y, "独立图标设置")
        local s1; s1, y = UI_Factory:CreateSlider(scrollChild, y, "图标尺寸", 10, 100, 1, db.independent, "size")
        local s2; s2, y = UI_Factory:CreateSlider(scrollChild, y, "图标间距", 0, 30, 1, db.independent, "gap")

    elseif tabName == "cooldownTracker" then
        local db = WF.db.cooldownTracker or {}
        _, y = UI_Factory:CreateHeader(scrollChild, y, L["Cooldown Tracker"] or "技能智能变灰")
        local t1; t1, y = UI_Factory:CreateToggle(scrollChild, y, L["Enable"] or "启用", db, "enable", function() print(L["Requires Reload"]) end)
        local t2; t2, y = UI_Factory:CreateToggle(scrollChild, y, "目标无DoT时变灰", db, "enableDesat", function() if WF.CooldownTrackerAPI then WF.CooldownTrackerAPI:RefreshAll() end end)
        local t3; t3, y = UI_Factory:CreateToggle(scrollChild, y, "资源不足时变灰", db, "enableResource", function() if WF.CooldownTrackerAPI then WF.CooldownTrackerAPI:RefreshAll() end end)
    end
    
    scrollChild:SetHeight(math.abs(y) + 50)
end

-- =========================================
-- [4. 构建主界面框架]
-- =========================================
local function CreateMainUI()
    if WF.MainFrame then return end

    local frame = CreateFrame("Frame", "WishFlexMainUI", UIParent, "BackdropTemplate")
    frame:SetSize(850, 600)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    
    ApplyFlatSkin(frame, 0.08, 0.08, 0.08, 0.95, CR, CG, CB, 1)

    local titleBG = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBG:SetPoint("TOPLEFT", 1, -1)
    titleBG:SetPoint("TOPRIGHT", -1, -1)
    titleBG:SetHeight(35)
    ApplyFlatSkin(titleBG, 0.12, 0.12, 0.12, 1, 0, 0, 0, 0) 

    local titleText = CreateUIFont(titleBG, 16, "LEFT", true)
    titleText:SetPoint("LEFT", 15, 0)
    titleText:SetText("|cff00ffccW|cff00f8cci|cff00f1ccs|cff00ebcch|cff00e4ccF|cff00ddaal|cff00d6aae|cff00cfaax|r |cff555555//|r " .. (L["Settings Console"] or "设置中心"))

    local closeBtn = CreateFrame("Button", nil, titleBG)
    closeBtn:SetSize(30, 30)
    closeBtn:SetPoint("RIGHT", -5, 0)
    local closeText = CreateUIFont(closeBtn, 16)
    closeText:SetPoint("CENTER")
    closeText:SetText("X")
    closeText:SetTextColor(0.5, 0.5, 0.5)
    closeBtn:SetScript("OnEnter", function() closeText:SetTextColor(CR, CG, CB) end)
    closeBtn:SetScript("OnLeave", function() closeText:SetTextColor(0.5, 0.5, 0.5) end)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", titleBG, "BOTTOMLEFT", 0, -5)
    sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    sidebar:SetWidth(150)
    ApplyFlatSkin(sidebar, 0.1, 0.1, 0.1, 1, 0, 0, 0, 0)

    local content = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 5, 0)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
    ApplyFlatSkin(content, 0.12, 0.12, 0.12, 1, 0, 0, 0, 0)

    local subTabBar = CreateFrame("Frame", nil, content, "BackdropTemplate")
    subTabBar:SetPoint("TOPLEFT", 0, 0)
    subTabBar:SetPoint("TOPRIGHT", 0, 0)
    subTabBar:SetHeight(30)
    ApplyFlatSkin(subTabBar, 0.09, 0.09, 0.09, 1, 0, 0, 0, 0)

    local scrollFrame, scrollChild = UI_Factory:CreateScrollArea(content)
    scrollFrame:SetPoint("TOPLEFT", 10, -40)

    WF.MainFrame = frame
    WF.Sidebar = sidebar
    WF.Content = content
    WF.SubTabBar = subTabBar
    WF.ScrollChild = scrollChild
    
    frame:Hide()
end

-- =========================================
-- [5. 渲染导航与标签页]
-- =========================================
local function RenderSubTabs(category)
    if category ~= "Combat" then return end

    if WF.SubTabBar.tabs then
        for _, tab in ipairs(WF.SubTabBar.tabs) do 
            if type(tab) == "table" then
                if tab.Hide then 
                    tab:Hide() 
                elseif tab.frame and tab.frame.Hide then
                    tab.frame:Hide()
                end
            end
        end
    end
    WF.SubTabBar.tabs = {}

    local tabsConfig = {
        { key = "classResource", name = L["Class Resource"] or "资源条" },
        { key = "cooldownCustom", name = L["Cooldown Custom"] or "冷却管理器" },
        { key = "glow", name = L["Action Button Glow"] or "技能高亮" },
        { key = "auraGlow", name = L["Aura Glow"] or "技能状态高亮" },
        { key = "cooldownTracker", name = L["Cooldown Tracker"] or "技能变灰" },
    }

    local xOffset = 10
    for _, tabData in ipairs(tabsConfig) do
        local btn = CreateFrame("Button", nil, WF.SubTabBar)
        local text = CreateUIFont(btn, 13)
        text:SetPoint("CENTER")
        text:SetText(tabData.name)
        text:SetTextColor(0.6, 0.6, 0.6)
        
        local textWidth = text:GetStringWidth()
        btn:SetSize(textWidth + 20, 30)
        btn:SetPoint("LEFT", xOffset, 0)
        
        local highlight = btn:CreateTexture(nil, "OVERLAY")
        highlight:SetColorTexture(CR, CG, CB, 1)
        highlight:SetPoint("BOTTOMLEFT", 0, 0)
        highlight:SetPoint("BOTTOMRIGHT", 0, 0)
        highlight:SetHeight(2)
        highlight:Hide()

        btn.Highlight = highlight
        btn.Text = text

        btn:SetScript("OnClick", function()
            for _, t in ipairs(WF.SubTabBar.tabs) do
                if type(t) == "table" and t.Highlight and t.Highlight.Hide then t.Highlight:Hide() end
                if type(t) == "table" and t.Text and t.Text.SetTextColor then t.Text:SetTextColor(0.6, 0.6, 0.6) end
            end
            if highlight and highlight.Show then highlight:Show() end
            if text and text.SetTextColor then text:SetTextColor(CR, CG, CB) end
            
            RenderCombatSettings(tabData.key, WF.ScrollChild)
        end)

        table.insert(WF.SubTabBar.tabs, btn)
        xOffset = xOffset + textWidth + 25
    end

    if #WF.SubTabBar.tabs > 0 then
        WF.SubTabBar.tabs[1]:GetScript("OnClick")()
    end
end

local function RenderSidebar()
    if WF.Sidebar.buttonsRendered then return end
    
    local categories = {
        { key = "Combat", name = L["Combat"] or "战斗" }
    }
    
    local yOffset = -20
    local buttons = {}
    
    for _, cat in ipairs(categories) do
        local btn = CreateFrame("Button", nil, WF.Sidebar, "BackdropTemplate")
        btn:SetSize(150, 40)
        btn:SetPoint("TOP", 0, yOffset)
        ApplyFlatSkin(btn, 0.1, 0.1, 0.1, 1, 0,0,0,0)
        
        local text = CreateUIFont(btn, 15, "LEFT", true)
        text:SetPoint("LEFT", 20, 0)
        text:SetText(cat.name)
        text:SetTextColor(0.6, 0.6, 0.6)
        
        btn:SetScript("OnClick", function()
            for _, b in ipairs(buttons) do
                if b.frame then ApplyFlatSkin(b.frame, 0.1, 0.1, 0.1, 1, 0,0,0,0) end
                if b.text then b.text:SetTextColor(0.6, 0.6, 0.6) end
            end
            ApplyFlatSkin(btn, 0.15, 0.15, 0.15, 1, 0,0,0,0) 
            text:SetTextColor(CR, CG, CB)
            
            RenderSubTabs(cat.key)
        end)

        table.insert(buttons, { frame = btn, text = text })
        yOffset = yOffset - 40
    end
    
    WF.Sidebar.buttonsRendered = true
    
    if #buttons > 0 then
        buttons[1].frame:GetScript("OnClick")()
    end
end

-- =========================================
-- [呼出界面API]
-- =========================================
function WF:ToggleUI()
    if not WF.MainFrame then
        CreateMainUI()
        RenderSidebar()
    end
    WF.MainFrame:SetShown(not WF.MainFrame:IsShown())
end

SLASH_WISHFLEX1 = "/wf"
SLASH_WISHFLEX2 = "/wishflex"
SlashCmdList["WISHFLEX"] = function()
    WF:ToggleUI()
end