local AddonName, ns = ...
local WF = _G.WishFlex or ns.WF
local L = ns.L or {}

local _, playerClass = UnitClass("player")
local ClassColor = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[playerClass] or {r=1, g=1, b=1}
local CR, CG, CB = ClassColor.r, ClassColor.g, ClassColor.b

-- =========================================================================
-- [极致保护的数据序列化引擎]
-- =========================================================================
local function cleanData(src)
    if type(src) ~= "table" then return src end
    local res = {}
    for k, v in pairs(src) do
        local tk = type(k)
        if tk == "string" or tk == "number" then
            local tv = type(v)
            if tv == "table" then
                if type(v.GetObjectType) ~= "function" and not v[0] then
                    res[k] = cleanData(v)
                end
            elseif tv == "string" or tv == "number" or tv == "boolean" then
                res[k] = v
            end
        end
    end
    return res
end

local function DeepMerge(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then 
            if type(target[k]) ~= "table" then target[k] = {} end
            DeepMerge(target[k], v)
        else 
            target[k] = v 
        end
    end
end

local function SerializeTable(t)
    local function serialize(o)
        if type(o) == "number" then
            return tostring(o)
        elseif type(o) == "boolean" then
            return tostring(o)
        elseif type(o) == "string" then
            return string.format("%q", o)
        elseif type(o) == "table" then
            local s = "{"
            for k,v in pairs(o) do
                local tk = type(k)
                if tk == "number" or tk == "string" then
                    s = s .. "[" .. serialize(k) .. "]=" .. serialize(v) .. ","
                end
            end
            return s .. "}"
        else
            return "nil"
        end
    end
    return serialize(t)
end

local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function EncodeBase64(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

local function DecodeBase64(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

local function GenerateExportString(exportType)
    local dataToExport = {}
    if exportType == "ALL" then dataToExport = WF.db
    elseif exportType == "MONITOR" then dataToExport = WF.db.wishMonitor or {}
    elseif exportType == "CLASSRES" then dataToExport = WF.db.classResource or {}
    elseif exportType == "GLOW" then dataToExport = WF.db.glow or {}
    elseif exportType == "CDCUSTOM" then dataToExport = WF.db.cooldownCustom or {}
    end

    local payload = { type = exportType, data = cleanData(dataToExport), version = 1 }
    local serializedStr = SerializeTable(payload)
    local encoded = EncodeBase64(serializedStr)

    return "!WF!" .. encoded
end

local function ImportFromString(str)
    if not str or not str:match("^!WF!") then return false, L["Import Failed"] end
    local encoded = str:sub(5)
    
    local decoded = DecodeBase64(encoded)
    if not decoded or decoded == "" then return false, L["Import Failed"] .. " (Decode failed)" end

    local func, err = loadstring("return " .. decoded)
    if not func then return false, L["Import Failed"] .. " (Syntax)" end
    
    local success, payload = pcall(func)
    if not success or type(payload) ~= "table" then return false, L["Import Failed"] .. " (Execution)" end

    local exportType = payload.type
    local data = payload.data
    if not exportType or not data then return false, L["Import Failed"] .. " (Data Empty)" end

    if exportType == "ALL" then DeepMerge(WF.db, data)
    elseif exportType == "MONITOR" then DeepMerge(WF.db.wishMonitor, data)
    elseif exportType == "CLASSRES" then DeepMerge(WF.db.classResource, data)
    elseif exportType == "GLOW" then DeepMerge(WF.db.glow, data)
    elseif exportType == "CDCUSTOM" then DeepMerge(WF.db.cooldownCustom, data)
    end
    
    return true, L["Import Success"] or "Import Successful!"
end

local function InitHomeUI()
    if not WF.UI then return end
    if WF.HomeInitialized then return end
    WF.HomeInitialized = true
    
    WF.UI:RegisterMenu({ 
        id = "HOME", 
        name = L["Home"] or "首 页", 
        type = "root", 
        key = "WF_HOME", 
        icon = "Interface\\AddOns\\WishFlex\\Media\\Icons\\home.tga", 
        order = 1 
    })
    
    WF.UI:RegisterMenu({ 
        id = "CONFIG_ROOT", 
        name = L["Profile"] or "配 置", 
        type = "root", 
        key = "WF_HOME_CONFIG", 
        icon = "Interface\\AddOns\\WishFlex\\Media\\Icons\\op.tga", 
        order = 99 
    })

    WF.UI:RegisterPanel("WF_HOME", function(scrollChild, ColW)
        local y = -20
        
        local logo = scrollChild.logo or scrollChild:CreateTexture(nil, "ARTWORK")
        scrollChild.logo = logo
        logo:SetSize(48, 48); logo:SetPoint("TOPLEFT", 20, y); logo:SetTexture("Interface\\AddOns\\WishFlex\\Media\\Icons\\Logo2.tga")
        logo:Show()
        
        local title = scrollChild.title or scrollChild:CreateFontString(nil, "OVERLAY")
        scrollChild.title = title
        title:SetFont(STANDARD_TEXT_FONT, 28, "OUTLINE")
        title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 15, -5)
        title:SetText("|cff00ffccWishFlex|r QoL")
        title:SetTextColor(1, 1, 1)
        title:Show()
        
        local sub = scrollChild.sub or scrollChild:CreateFontString(nil, "OVERLAY")
        scrollChild.sub = sub
        sub:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
        sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
        sub:SetText(L["Welcome to WishFlex"] or "欢迎使用 WishFlex GeniSys")
        sub:SetTextColor(0.6, 0.6, 0.6)
        sub:Show()
        y = y - 90
        
        local desc = scrollChild.desc or scrollChild:CreateFontString(nil, "OVERLAY")
        scrollChild.desc = desc
        desc:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
        desc:SetPoint("TOPLEFT", 20, y); desc:SetWidth(450)
        desc:SetSpacing(5)
        desc:SetText(L["Addon Description"] or "WishFlex 是一款轻量化、模块化、高性能的优化套装。专为追求极致排版、强迫症、高科技感和简约主义的玩家打造。")
        desc:SetTextColor(0.8, 0.8, 0.8)
        desc:Show()
        y = y - 70
        
        local featureHead = scrollChild.featureHead or scrollChild:CreateFontString(nil, "OVERLAY")
        scrollChild.featureHead = featureHead
        featureHead:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
        featureHead:SetPoint("TOPLEFT", 20, y)
        featureHead:SetText(L["Core Features"] or "核心功能:")
        featureHead:SetTextColor(CR, CG, CB)
        featureHead:Show()
        y = y - 30
        
        local features = { 
            L["Feature 1"] or "- 模块化按需加载 (低内存占用)", 
            L["Feature 2"] or "- 极致简约的扁平化 UI 与职业色主题", 
            L["Feature 3"] or "- 高级冷却管理器", 
            L["Feature 4"] or "- 轻量化玩家资源条轨道", 
            L["Feature 5"] or "- 内置智能锚点编辑器" 
        }
        
        if not scrollChild.featureLines then scrollChild.featureLines = {} end
        for i, fText in ipairs(features) do
            local f = scrollChild.featureLines[i] or scrollChild:CreateFontString(nil, "OVERLAY")
            scrollChild.featureLines[i] = f
            f:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", 30, y); f:SetText(fText); f:SetTextColor(0.7, 0.7, 0.7)
            f:Show()
            y = y - 22
        end
        y = y - 20
        
        local qaHead = scrollChild.qaHead or scrollChild:CreateFontString(nil, "OVERLAY")
        scrollChild.qaHead = qaHead
        qaHead:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
        qaHead:SetPoint("TOPLEFT", 20, y)
        qaHead:SetText(L["Quick Actions"] or "快捷操作")
        qaHead:SetTextColor(CR, CG, CB)
        qaHead:Show()
        y = y - 30
        
        local reloadBtn = scrollChild.reloadBtn or WF.UI.Factory:CreateFlatButton(scrollChild, L["Reload UI"] or "重载界面", function() ReloadUI() end)
        scrollChild.reloadBtn = reloadBtn
        reloadBtn:ClearAllPoints(); reloadBtn:SetPoint("TOPLEFT", 20, y); reloadBtn:Show()
        
        local anchorBtn = scrollChild.anchorBtn or WF.UI.Factory:CreateFlatButton(scrollChild, L["Toggle Anchors"] or "解锁/锁定锚点", function() if WF.ToggleMovers then WF:ToggleMovers() end end)
        scrollChild.anchorBtn = anchorBtn
        anchorBtn:ClearAllPoints(); anchorBtn:SetPoint("TOPLEFT", reloadBtn, "TOPRIGHT", 15, 0); anchorBtn:Show()
        y = y - 60
        
        local infoHead = scrollChild.infoHead or scrollChild:CreateFontString(nil, "OVERLAY")
        scrollChild.infoHead = infoHead
        infoHead:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
        infoHead:SetPoint("TOPLEFT", 20, y)
        infoHead:SetText(L["Addon Info"] or "插件信息")
        infoHead:SetTextColor(CR, CG, CB)
        infoHead:Show()
        y = y - 30
        
        local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
        local version = getMeta and getMeta(AddonName, "Version") or "v1.0"
        local author = getMeta and getMeta(AddonName, "Author") or "WishFlex Team"

        local info1 = scrollChild.info1 or scrollChild:CreateFontString(nil, "OVERLAY")
        scrollChild.info1 = info1
        info1:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
        info1:SetPoint("TOPLEFT", 30, y)
        info1:SetText((L["Version"] or "版本")..": |cffffffff"..version.."|r")
        info1:SetTextColor(0.7, 0.7, 0.7)
        info1:Show()
        y = y - 22
        
        local info2 = scrollChild.info2 or scrollChild:CreateFontString(nil, "OVERLAY")
        scrollChild.info2 = info2
        info2:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
        info2:SetPoint("TOPLEFT", 30, y)
        info2:SetText((L["Author"] or "作者")..": |cffffffff"..author.."|r")
        info2:SetTextColor(0.7, 0.7, 0.7)
        info2:Show()

        return y - 40
    end)

    WF.UI:RegisterPanel("WF_HOME_CONFIG", function(scrollChild, ColW)
        local y = -20
        
        local profHead = scrollChild.profHead or scrollChild:CreateFontString(nil, "OVERLAY")
        scrollChild.profHead = profHead
        profHead:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
        profHead:SetPoint("TOPLEFT", 20, y)
        profHead:SetText(L["Profile Management"] or "配置文件管理 (导入/导出)")
        profHead:SetTextColor(CR, CG, CB)
        profHead:Show()
        y = y - 40
        
        local profDesc = scrollChild.profDesc or scrollChild:CreateFontString(nil, "OVERLAY")
        scrollChild.profDesc = profDesc
        profDesc:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
        profDesc:SetPoint("TOPLEFT", 20, y)
        profDesc:SetWidth(ColW * 1.5)
        profDesc:SetSpacing(5)
        profDesc:SetText(L["Profile Desc"] or "在此处备份或分享您的专属配置...")
        profDesc:SetTextColor(0.7, 0.7, 0.7)
        profDesc:SetJustifyH("LEFT")
        profDesc:Show()
        
        -- 【修复】大幅增加Y轴偏移，防止说明文字和下拉框重叠
        y = y - 100 

        scrollChild.exportTypeDB = scrollChild.exportTypeDB or { type = "ALL" }
        local typeOpts = {
            {text = L["Export ALL"] or "全部配置 (全局)", value = "ALL"},
            {text = L["Export Monitor"] or "自定义监控 (WishMonitor)", value = "MONITOR"},
            {text = L["Export ClassResource"] or "职业资源条 (ClassResource)", value = "CLASSRES"},
            {text = L["Export Glow"] or "核心发光 (Glow)", value = "GLOW"},
            {text = L["Export CDCustom"] or "冷却管理器 (CooldownCustom)", value = "CDCUSTOM"},
        }
        
        local ddBtn
        ddBtn, y = WF.UI.Factory:CreateDropdown(scrollChild, 20, y, 300, L["Export Module"] or "选择处理模块", scrollChild.exportTypeDB, "type", typeOpts, nil)
        y = y - 20 
        
        local expBtn = scrollChild.expBtn or WF.UI.Factory:CreateFlatButton(scrollChild, L["Generate Export"] or "生成导出代码", function()
            local str = GenerateExportString(scrollChild.exportTypeDB.type)
            scrollChild.exportBox.editBox:SetText(str)
            scrollChild.exportBox.editBox:HighlightText()
            scrollChild.exportBox.editBox:SetFocus()
        end)
        scrollChild.expBtn = expBtn
        expBtn:ClearAllPoints(); expBtn:SetPoint("TOPLEFT", 20, y); expBtn:Show()

        local impBtn = scrollChild.impBtn or WF.UI.Factory:CreateFlatButton(scrollChild, L["Import Current"] or "导入当前代码", function()
            local str = scrollChild.exportBox.editBox:GetText()
            local success, msg = ImportFromString(str)
            if success then
                print("|cff00ffccWishFlex:|r " .. msg)
                C_Timer.After(1.5, ReloadUI)
            else
                print("|cffff0000WishFlex Error:|r " .. msg)
            end
        end)
        scrollChild.impBtn = impBtn
        impBtn:ClearAllPoints(); impBtn:SetPoint("LEFT", expBtn, "RIGHT", 15, 0); impBtn:Show()
        
        local clearBtn = scrollChild.clearBtn or WF.UI.Factory:CreateFlatButton(scrollChild, L["Clear Input"] or "清空输入区", function()
            scrollChild.exportBox.editBox:SetText("")
            scrollChild.exportBox.editBox:ClearFocus()
        end)
        scrollChild.clearBtn = clearBtn
        clearBtn:ClearAllPoints(); clearBtn:SetPoint("LEFT", impBtn, "RIGHT", 15, 0); clearBtn:Show()
        
        y = y - 40

        if not scrollChild.exportBox then
            local backdrop = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
            if WF.UI.Factory.ApplyFlatSkin then WF.UI.Factory.ApplyFlatSkin(backdrop, 0.05, 0.05, 0.05, 1, 0, 0, 0, 1) end
            local scroll = CreateFrame("ScrollFrame", nil, backdrop, "UIPanelScrollFrameTemplate")
            scroll:SetPoint("TOPLEFT", 5, -5)
            scroll:SetPoint("BOTTOMRIGHT", -25, 5)
            local editBox = CreateFrame("EditBox", nil, scroll)
            editBox:SetWidth(ColW * 1.5 - 30)
            editBox:SetMultiLine(true)
            editBox:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
            editBox:SetAutoFocus(false)
            editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            scroll:SetScrollChild(editBox)
            backdrop.editBox = editBox
            scrollChild.exportBox = backdrop
        end
        scrollChild.exportBox:ClearAllPoints()
        scrollChild.exportBox:SetPoint("TOPLEFT", 20, y)
        scrollChild.exportBox:SetSize(ColW * 1.5, 200)
        scrollChild.exportBox:Show()

        return y - 220
    end)
end

if WF.UI then
    InitHomeUI()
else
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(self)
        InitHomeUI()
        self:UnregisterAllEvents()
    end)
end