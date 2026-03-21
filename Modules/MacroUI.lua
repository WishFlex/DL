local AddonName, ns = ...
local WF = _G.WishFlex or ns.WF
local L = ns.L or {}
local LCG = LibStub("LibCustomGlow-1.0", true)

local MFE = CreateFrame("Frame")
WF.MacroUIAPI = MFE

MFE.knownMacros = {}
MFE.newMacros = {}

local DefaultConfig = {
    enable = true,
    width = 680,
    height = 750,
    glowType = "pixel",
}

local function GetDB()
    if not WF.db.macroUI then WF.db.macroUI = {} end
    for k, v in pairs(DefaultConfig) do
        if WF.db.macroUI[k] == nil then WF.db.macroUI[k] = v end
    end
    return WF.db.macroUI
end

-- ========================================================
-- [数据监听与核心功能]
-- ========================================================
function MFE:UpdateKnownMacros(checkNew)
    local currentList = {}
    
    -- 仅对通用宏 (1-120) 进行新建高亮判定
    for i = 1, 120 do
        local name = GetMacroInfo(i)
        if name then 
            currentList[name] = true 
            if checkNew and not self.knownMacros[name] then
                self.newMacros[name] = true
            end
        end
    end
    
    -- 专用宏 (121-138) 依然扫描用于列表追踪和过滤，但不触发新建发光
    for i = 121, 138 do
        local name = GetMacroInfo(i)
        if name then currentList[name] = true end
    end

    self.knownMacros = currentList
end

function MFE:UpdateMacroVisuals()
    if not MacroFrame or not MacroFrame.MacroSelector or not MacroFrame.MacroSelector.ScrollBox then return end
    if not MacroFrame.MacroSelector.ScrollBox:GetView() then return end
    
    local searchText = self.SearchBox and self.SearchBox:GetText():lower() or ""
    local db = GetDB()
    local glowType = db.glowType
    
    MacroFrame.MacroSelector.ScrollBox:ForEachFrame(function(button)
        local elementData = button:GetElementData()
        if not elementData then return end
        
        local macroIndex = type(elementData) == "table" and (elementData.macroIndex or elementData.id) or elementData
        local name, _, _ = GetMacroInfo(macroIndex)
        
        if not name then return end

        if searchText ~= "" and not name:lower():find(searchText, 1, true) then
            button:SetAlpha(0.2)
        else
            button:SetAlpha(1.0)
        end

        if LCG then
            LCG.PixelGlow_Stop(button)
            LCG.AutoCastGlow_Stop(button)
            LCG.ButtonGlow_Stop(button)
            
            if MFE.newMacros[name] then
                if glowType == "pixel" then
                    LCG.PixelGlow_Start(button)
                elseif glowType == "autocast" then
                    LCG.AutoCastGlow_Start(button)
                elseif glowType == "button" then
                    LCG.ButtonGlow_Start(button)
                end
            end
        end
    end)
end

function MFE:CreateSearchBox()
    if self.SearchBox then return end

    local searchBox = CreateFrame("EditBox", "MacroFrameEnhancerSearchBox", MacroFrame, "SearchBoxTemplate")
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(50)
    
    -- 【智能兼容】：如果有 ElvUI 则应用其原生皮肤风格，否则保留暴雪原生
    if _G.ElvUI then
        local E = _G.ElvUI[1]
        if E then
            local S = E:GetModule('Skins', true)
            if S and S.HandleEditBox then
                S:HandleEditBox(searchBox)
            end
        end
    end

    searchBox:SetScript("OnTextChanged", function(self)
        SearchBoxTemplate_OnTextChanged(self)
        MFE:UpdateMacroVisuals()
    end)

    self.SearchBox = searchBox
end

function MFE:UpdateLayout()
    if not MacroFrame then return end
    local db = GetDB()
    local safeWidth = math.max(600, db.width)
    local safeHeight = math.max(500, db.height)

    MacroFrame:SetWidth(safeWidth)
    MacroFrame:SetHeight(safeHeight)

    local insetX = 20
    local visualFixX = 4 

    if self.SearchBox then
        self.SearchBox:ClearAllPoints()
        self.SearchBox:SetPoint("TOPLEFT", MacroFrame, "TOPLEFT", insetX + visualFixX, -35)
        self.SearchBox:SetPoint("TOPRIGHT", MacroFrame, "TOPRIGHT", -(insetX + visualFixX), -35)
        self.SearchBox:SetHeight(25)
    end
    if MacroFrameTab1 and MacroFrameTab2 then
        MacroFrameTab1:ClearAllPoints()
        MacroFrameTab1:SetPoint("TOPLEFT", MacroFrame, "TOPLEFT", insetX, -70)
    end
    if MacroFrame.MacroSelector then
        MacroFrame.MacroSelector:ClearAllPoints()
        MacroFrame.MacroSelector:SetPoint("TOPLEFT", MacroFrameTab1, "BOTTOMLEFT", 0, -5)
        MacroFrame.MacroSelector:SetPoint("RIGHT", MacroFrame, "RIGHT", -insetX, 0)
        MacroFrame.MacroSelector:SetHeight(280)
        if MacroFrame.MacroSelector.ScrollBox then
            local view = MacroFrame.MacroSelector.ScrollBox:GetView()
            if view and view.SetStride then
                local availableWidth = safeWidth - (insetX * 2)
                local columns = math.max(6, math.floor(availableWidth / 44))
                view:SetStride(columns)
                if MacroFrame:IsShown() then
                    MacroFrame.MacroSelector.ScrollBox:FullUpdate(true)
                end
            end
        end
    end

    if MacroFrameSelectedMacroButton then
        MacroFrameSelectedMacroButton:ClearAllPoints()
        MacroFrameSelectedMacroButton:SetPoint("TOPLEFT", MacroFrame.MacroSelector, "BOTTOMLEFT", 0, -15)
    end

    if MacroFrameSelectedMacroName then
        MacroFrameSelectedMacroName:ClearAllPoints()
        MacroFrameSelectedMacroName:SetPoint("LEFT", MacroFrameSelectedMacroButton, "RIGHT", 10, 0)
        MacroFrameSelectedMacroName:SetWidth(120)
        MacroFrameSelectedMacroName:SetJustifyH("LEFT")
    end

    if MacroEditButton and MacroFrameSelectedMacroName then
        MacroEditButton:ClearAllPoints()
        MacroEditButton:SetPoint("LEFT", MacroFrameSelectedMacroName, "RIGHT", 10, 0)
    end

    if MacroSaveButton and MacroEditButton then
        MacroSaveButton:ClearAllPoints()
        MacroSaveButton:SetPoint("LEFT", MacroEditButton, "RIGHT", 10, 0)
    end

    if MacroCancelButton and MacroSaveButton then
        MacroCancelButton:ClearAllPoints()
        MacroCancelButton:SetPoint("LEFT", MacroSaveButton, "RIGHT", 10, 0)
    end

    if MacroFrameTextBackground then
        MacroFrameTextBackground:ClearAllPoints()
        MacroFrameTextBackground:SetPoint("TOPLEFT", MacroFrameSelectedMacroButton, "BOTTOMLEFT", 0, -15)
        MacroFrameTextBackground:SetPoint("BOTTOMRIGHT", MacroFrame, "BOTTOMRIGHT", -insetX, 45) 
    end
    
    if MacroFrameSelectedMacroBackground then
        MacroFrameSelectedMacroBackground:SetAlpha(0)
    end
    if MacroFrameEnterMacroText then
        MacroFrameEnterMacroText:SetText("")
        MacroFrameEnterMacroText:SetAlpha(0)
    end
    
    if MacroFrameScrollFrame then
        MacroFrameScrollFrame:ClearAllPoints()
        MacroFrameScrollFrame:SetPoint("TOPLEFT", MacroFrameTextBackground, "TOPLEFT", 10, -10)
        MacroFrameScrollFrame:SetPoint("BOTTOMRIGHT", MacroFrameTextBackground, "BOTTOMRIGHT", -30, 10)
    end

    if MacroFrameCharLimitText then
        MacroFrameCharLimitText:ClearAllPoints()
        MacroFrameCharLimitText:SetPoint("BOTTOM", MacroFrameTextBackground, "BOTTOM", 0, -15)
    end
    if MacroDeleteButton then
        MacroDeleteButton:ClearAllPoints()
        MacroDeleteButton:SetPoint("BOTTOMLEFT", MacroFrame, "BOTTOMLEFT", insetX, 15)
    end

    if MacroExitButton then
        MacroExitButton:ClearAllPoints()
        MacroExitButton:SetPoint("BOTTOMRIGHT", MacroFrame, "BOTTOMRIGHT", -insetX, 15)
    end

    if MacroNewButton and MacroExitButton then
        MacroNewButton:ClearAllPoints()
        MacroNewButton:SetPoint("RIGHT", MacroExitButton, "LEFT", -10, 0)
    end
end

-- ========================================================
-- [框架随意拖动支持]
-- ========================================================
function MFE:EnableDragging()
    if not MacroFrame then return end
    MacroFrame:SetMovable(true)
    MacroFrame:SetClampedToScreen(true)
    
    local dragTarget = MacroFrame.TitleContainer or MacroFrame
    dragTarget:EnableMouse(true)
    dragTarget:RegisterForDrag("LeftButton")
    dragTarget:SetScript("OnDragStart", function() MacroFrame:StartMoving() end)
    dragTarget:SetScript("OnDragStop", function() MacroFrame:StopMovingOrSizing() end)
end

function MFE:InitializeUI()
    if self.initialized then return end
    self.initialized = true

    self:CreateSearchBox()
    self:UpdateLayout()
    self:EnableDragging()
    self:HookScrollPosition()
end

function MFE:HookScrollPosition()
    if not MacroFrame or not MacroFrame.MacroSelector then return end
    local scrollData = {}
    local isRestoring = false
    
    hooksecurefunc(MacroFrame, "SelectMacro", function(self, index)
        if not isRestoring and scrollData.scrollPercentage then
            isRestoring = true
            C_Timer.After(0.01, function()
                if MacroFrame and MacroFrame.MacroSelector and MacroFrame.MacroSelector.ScrollBox and MacroFrame.MacroSelector.ScrollBox:GetView() then 
                    MacroFrame.MacroSelector.ScrollBox:SetScrollPercentage(scrollData.scrollPercentage) 
                end
                isRestoring = false
            end)
        end
    end)

    if MacroFrame.MacroSelector.ScrollBox then
        hooksecurefunc(MacroFrame.MacroSelector.ScrollBox, "Update", function()
            MFE:UpdateMacroVisuals()
        end)
    end

    self:RegisterEvent("UPDATE_MACROS")
    self:SetScript("OnEvent", function(self, event, ...)
        if event == "UPDATE_MACROS" then
            if MacroFrame and MacroFrame.MacroSelector and MacroFrame.MacroSelector.ScrollBox and MacroFrame.MacroSelector.ScrollBox:GetView() then 
                scrollData.scrollPercentage = MacroFrame.MacroSelector.ScrollBox:GetScrollPercentage() 
            end
            
            MFE:UpdateKnownMacros(true)
            MFE:UpdateMacroVisuals()
        elseif event == "ADDON_LOADED" then
            local loadedName = ...
            if loadedName == "Blizzard_MacroUI" then 
                self:InitializeUI()
                self:UnregisterEvent("ADDON_LOADED") 
            end
        end
    end)

    MacroFrame:HookScript("OnShow", function()
        MFE:UpdateLayout()
        MFE:UpdateKnownMacros(false)
        MFE.newMacros = {}
        if MFE.SearchBox then MFE.SearchBox:SetText("") end
        
        if scrollData.scrollPercentage then
            C_Timer.After(0.05, function() 
                if MacroFrame and MacroFrame.MacroSelector and MacroFrame.MacroSelector.ScrollBox and MacroFrame.MacroSelector.ScrollBox:GetView() then 
                    MacroFrame.MacroSelector.ScrollBox:SetScrollPercentage(scrollData.scrollPercentage) 
                end 
            end)
        end
    end)
    
    MacroFrame:HookScript("OnHide", function()
        MFE.newMacros = {}
        if MacroFrame and MacroFrame.MacroSelector and MacroFrame.MacroSelector.ScrollBox and MacroFrame.MacroSelector.ScrollBox:GetView() then
            MacroFrame.MacroSelector.ScrollBox:ForEachFrame(function(button)
                if LCG then 
                    LCG.PixelGlow_Stop(button)
                    LCG.AutoCastGlow_Stop(button)
                    LCG.ButtonGlow_Stop(button)
                end
            end)
        end
    end)
end

local function InitMacroUI()
    local db = GetDB()
    if not db.enable then return end

    if MacroFrame then 
        MFE:InitializeUI() 
    else
        MFE:RegisterEvent("ADDON_LOADED")
        MFE:SetScript("OnEvent", function(self, event, loadedName)
            if event == "ADDON_LOADED" and loadedName == "Blizzard_MacroUI" then 
                self:InitializeUI()
                self:UnregisterEvent("ADDON_LOADED") 
            end
        end)
    end
end

WF:RegisterModule("macroUI", L["Macro Enhancement"] or "宏界面增强", InitMacroUI)

-- =========================================================================
-- [面板注册系统]
-- =========================================================================
if WF.UI then
    WF.UI:RegisterMenu({ id = "UTILITIES", name = L["Utilities"] or "小工具", type = "root", key = "WF_UTILITIES", icon = "Interface\\AddOns\\WishFlex\\Media\\Icons\\menu.tga", order = 80 })
    WF.UI:RegisterMenu({ id = "MacroUI", parent = "UTILITIES", name = L["Macro Enhancement"] or "宏界面增强", key = "utilities_MacroUI", order = 1 })

    WF.UI:RegisterPanel("utilities_MacroUI", function(scrollChild, ColW)
        local db = GetDB()
        local y = -10

        local opts = {
            { type = "group", key = "macro_base", text = L["Macro Settings"] or "宏界面设置", childs = {
                { type = "toggle", key = "enable", db = db, text = L["Enable Module"] or "启用 宏界面增强", requireReload = true },
                { type = "slider", key = "width", db = db, min = 600, max = 1200, step = 10, text = L["Macro Frame Width"] or "界面宽度" },
                { type = "slider", key = "height", db = db, min = 500, max = 1200, step = 10, text = L["Macro Frame Height"] or "界面高度" },
                { type = "dropdown", key = "glowType", db = db, text = L["New Macro Glow"] or "新建宏高亮样式", options = {
                    { text = L["Pixel Glow"] or "像素边框 (Pixel)", value = "pixel" },
                    { text = L["Autocast Glow"] or "闪烁发光 (AutoCast)", value = "autocast" },
                    { text = L["Button Glow"] or "默认高亮 (Button)", value = "button" },
                }},
            }}
        }

        local function HandleMacroChange(val)
            if MFE.UpdateLayout then MFE:UpdateLayout() end
            if MFE.UpdateMacroVisuals then MFE:UpdateMacroVisuals() end
            if val == "UI_REFRESH" then WF.UI:RefreshCurrentPanel() end
        end

        return WF.UI:RenderOptionsGroup(scrollChild, 15, y, ColW * 1.5, opts, HandleMacroChange)
    end)
end