local AddonName, ns = ...
local WF = _G.WishFlex or ns.WF
local L = ns.L or {}

-- 获取当前职业颜色
local _, playerClass = UnitClass("player")
local ClassColor = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass] or {r=1, g=1, b=1}
local CR, CG, CB = ClassColor.r, ClassColor.g, ClassColor.b

-- 1. 注册主页左侧菜单 (锚点)
WF.UI:RegisterMenu({ 
    id = "HOME", 
    name = L["Home"] or "首 页", 
    type = "root", 
    key = "WF_HOME", 
    icon = "Interface\\AddOns\\WishFlex\\Media\\Icons\\home", 
    order = 1 
})

-- 2. 注册主页具体内容渲染逻辑
WF.UI:RegisterPanel("WF_HOME", function(scrollChild, ColW)
    local y = -20
    local logo = scrollChild:CreateTexture(nil, "ARTWORK")
    logo:SetSize(48, 48); logo:SetPoint("TOPLEFT", 20, y); logo:SetTexture("Interface\\AddOns\\WishFlex\\Media\\Icons\\Logo2")
    
    local title = scrollChild:CreateFontString(nil, "OVERLAY")
    title:SetFont(STANDARD_TEXT_FONT, 28, "OUTLINE")
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 15, -5)
    title:SetText("|cff00ffccWishFlex|r GeniSys")
    title:SetTextColor(1, 1, 1)
    
    local sub = scrollChild:CreateFontString(nil, "OVERLAY")
    sub:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    sub:SetText(L["Welcome to WishFlex"] or "欢迎使用 WishFlex GeniSys")
    sub:SetTextColor(0.6, 0.6, 0.6)
    y = y - 90
    
    local desc = scrollChild:CreateFontString(nil, "OVERLAY")
    desc:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    desc:SetPoint("TOPLEFT", 20, y); desc:SetWidth(450)
    desc:SetSpacing(5)
    desc:SetText(L["Addon Description"] or "WishFlex 是一款轻量化、模块化、高性能的优化套装。专为追求极致排版、强迫症、高科技感和简约主义的玩家打造。")
    desc:SetTextColor(0.8, 0.8, 0.8)
    y = y - 70
    
    local featureHead = scrollChild:CreateFontString(nil, "OVERLAY")
    featureHead:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
    featureHead:SetPoint("TOPLEFT", 20, y)
    featureHead:SetText(L["Core Features"] or "核心功能:")
    featureHead:SetTextColor(CR, CG, CB)
    y = y - 30
    
    local features = { 
        L["Feature 1"] or "- 模块化按需加载 (低内存占用)", 
        L["Feature 2"] or "- 极致简约的扁平化 UI 与职业色主题", 
        L["Feature 3"] or "- 高级冷却管理器", 
        L["Feature 4"] or "- 轻量化玩家资源条轨道", 
        L["Feature 5"] or "- 内置智能锚点编辑器" 
    }
    
    for _, fText in ipairs(features) do
        local f = scrollChild:CreateFontString(nil, "OVERLAY")
        f:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
        f:SetPoint("TOPLEFT", 30, y); f:SetText(fText); f:SetTextColor(0.7, 0.7, 0.7)
        y = y - 22
    end
    y = y - 20
    
    local qaHead = scrollChild:CreateFontString(nil, "OVERLAY")
    qaHead:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
    qaHead:SetPoint("TOPLEFT", 20, y)
    qaHead:SetText(L["Quick Actions"] or "快捷操作")
    qaHead:SetTextColor(CR, CG, CB)
    y = y - 30
    
    local reloadBtn = WF.UI.Factory:CreateFlatButton(scrollChild, L["Reload UI"] or "重载界面", function() ReloadUI() end)
    reloadBtn:SetPoint("TOPLEFT", 20, y)
    
    local anchorBtn = WF.UI.Factory:CreateFlatButton(scrollChild, L["Toggle Anchors"] or "解锁/锁定锚点", function() if WF.ToggleMovers then WF:ToggleMovers() end end)
    anchorBtn:SetPoint("TOPLEFT", reloadBtn, "TOPRIGHT", 15, 0)
    y = y - 60
    
    local infoHead = scrollChild:CreateFontString(nil, "OVERLAY")
    infoHead:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
    infoHead:SetPoint("TOPLEFT", 20, y)
    infoHead:SetText(L["Addon Info"] or "插件信息")
    infoHead:SetTextColor(CR, CG, CB)
    y = y - 30
    
    local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local version = getMeta and getMeta(AddonName, "Version") or "v1.0"
    local author = getMeta and getMeta(AddonName, "Author") or "WishFlex Team"

    local info1 = scrollChild:CreateFontString(nil, "OVERLAY")
    info1:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    info1:SetPoint("TOPLEFT", 30, y)
    info1:SetText((L["Version"] or "版本")..": |cffffffff"..version.."|r")
    info1:SetTextColor(0.7, 0.7, 0.7)
    y = y - 22
    
    local info2 = scrollChild:CreateFontString(nil, "OVERLAY")
    info2:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    info2:SetPoint("TOPLEFT", 30, y)
    info2:SetText((L["Author"] or "作者")..": |cffffffff"..author.."|r")
    info2:SetTextColor(0.7, 0.7, 0.7)

    return y - 30
end)