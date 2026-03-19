local AddonName, ns = ...
local WF = ns.WF
local L = ns.L

local CS = {}

-- ==========================================
-- 将当前聊天框配置保存到全局模板
-- ==========================================
function CS:SaveChatToTemplate()
    if not WishFlexDB.global then WishFlexDB.global = {} end
    WishFlexDB.global.ChatTemplate = {}
    local template = WishFlexDB.global.ChatTemplate
    local count = 0

    for i = 1, NUM_CHAT_WINDOWS do
        local name, fontSize, _, _, _, _, shown, _, docked = GetChatWindowInfo(i)
        if name and name ~= "" and (shown or docked or i == 1 or i == 2) then
            template[i] = {
                name = name,
                fontSize = fontSize,
                channels = { GetChatWindowChannels(i) }, 
                messages = { GetChatWindowMessages(i) }  
            }
            count = count + 1
        end
    end
    print(string.format("|cff00ffcc[WishFlex]|r " .. (L["Chat Saved: %d"] or "聊天配置已记录！共抓取 %d 个有效窗口。"), count))
end

-- ==========================================
-- 将全局模板应用到当前角色
-- ==========================================
function CS:SetupChat()
    local template = WishFlexDB.global and WishFlexDB.global.ChatTemplate
    if type(template) ~= "table" or not next(template) then
        print("|cff00ffcc[WishFlex]|r |cffff0000" .. (L["Chat No Data"] or "数据库为空！请先去原角色记录。") .. "|r") 
        return
    end

    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame"..i]
        local data = template[i]

        if data then
            FCF_SetWindowName(frame, data.name)
            ChatFrame_RemoveAllMessageGroups(frame)
            ChatFrame_RemoveAllChannels(frame)
            
            for _, msgType in ipairs(data.messages) do 
                ChatFrame_AddMessageGroup(frame, msgType) 
            end
            
            if i == 1 then ChatFrame_ReceiveAllPrivateMessages(frame) end
            
            if i > 2 then
                frame:Show()
                FCF_DockFrame(frame) 
                local tab = _G["ChatFrame"..i.."Tab"]
                if tab then tab:Show() end
            end
            FCF_SetChatWindowFontSize(nil, frame, data.fontSize or 12)
        else
            if i > 2 then
                FCF_SetWindowName(frame, "")
                ChatFrame_RemoveAllMessageGroups(frame)
                ChatFrame_RemoveAllChannels(frame)
                FCF_Close(frame)
                FCF_UnDockFrame(frame)
                local tab = _G["ChatFrame"..i.."Tab"]
                if tab then tab:Hide() end
            end
        end
    end

    -- 原生定时器，延时 2 秒让暴雪频道系统反应过来
    C_Timer.After(2, function()
        for i = 1, NUM_CHAT_WINDOWS do
            local data = template[i]
            local frame = _G["ChatFrame"..i]
            if data and frame and data.channels and i ~= 2 then
                for c = 1, #data.channels, 2 do
                    local chanName = data.channels[c]
                    if chanName then
                        JoinChannelByName(chanName)
                        ChatFrame_AddChannel(frame, chanName)
                    end
                end
            end
        end
        
        -- 兼容：如果玩家仍在使用 ElvUI 的聊天模块，呼叫它重置位置
        if _G.ElvUI then
            local E = unpack(_G.ElvUI)
            local CH = E:GetModule('Chat')
            if CH then
                if CH.UpdateChatTabs then CH:UpdateChatTabs() end
                if CH.PositionChat then CH:PositionChat(true) end
            end
        end
        print("|cff00ffcc[WishFlex]|r " .. (L["Chat Applied"] or "聊天窗口已按模板绝对镜像还原！"))
    end)
end

local function InitChatSetup()
    -- 暴露接口给未来的 UI.lua 按钮调用
    WF.ChatSetupAPI = CS 
end

WF:RegisterModule("chatSetup", L["Chat Sync"] or "聊天框同步", InitChatSetup)