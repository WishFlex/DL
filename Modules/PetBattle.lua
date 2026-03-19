local ElvUI = _G.ElvUI
local E, L, V, P, G = unpack(ElvUI)
local WUI = E:GetModule('WishFlex') 
local PB = WUI:NewModule('WishFlex_PetBattle', 'AceEvent-3.0', 'AceHook-3.0')

-- 1. 注册极简默认设置
P["WishFlex"] = P["WishFlex"] or { modules = {} }
P["WishFlex"].modules.petBattle = true
P["WishFlex"].petBattle = {
    targets = {},  
    thresholds = { [1] = 80, [2] = 80, [3] = 80 }, 
    autoSurrender = true,     
    surrenderTime = 180,  
    showXP = true, 
}

local CHEX = "|cff00ffcc"
PB.selectedBindTeamID = nil
PB.fallbackQueue = {}
PB.currentCheckTarget = nil
PB.lastTargetNPC = nil    
PB.lockedBattleNPC = nil  
PB.reviveWasOnCD = false  
PB.activeTeamID = nil          
PB.pendingReviveSwitch = false 
PB.TDHooked = false            
local targetChangeTimer = nil

-- 防卡死专用变量
PB.battleStartTime = 0
PB.battleTicker = nil
PB.lastBattleDuration = 0

-- 经验监控专用变量
PB.XPFrame = nil
PB.currentXP = 0
PB.maxXP = 1
PB.lastXPGain = 0

----------------------------------------------------
-- 基础工具函数
----------------------------------------------------
local function GetNPCID()
    -- 【核心修复】：使用 pcall 拦截副本内的“神秘字符串”报错
    local success, npcID = pcall(function()
        local guid = UnitGUID("target")
        if guid then
            local unitType, _, _, _, _, id = strsplit("-", guid)
            if unitType == "Creature" or unitType == "Vehicle" then 
                return tonumber(id) 
            end
        end
        return nil
    end)
    
    if success then return npcID end
    return nil
end

----------------------------------------------------
-- 【经验监控面板】：核心 UI 与逻辑
----------------------------------------------------
local function CreateXPFrame()
    if PB.XPFrame then return end
    
    local frame = CreateFrame("Frame", "WishFlexPetBattleXPFrame", UIParent)
    frame:SetSize(250, 95) 
    frame:SetFrameStrata("HIGH") 
    if E then frame:SetTemplate("Transparent") end

    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        E.db.WishFlex = E.db.WishFlex or {}
        E.db.WishFlex.XPFramePos = {point, relativePoint, xOfs, yOfs}
    end)
    
    if E.db.WishFlex and E.db.WishFlex.XPFramePos then
        local pos = E.db.WishFlex.XPFramePos
        frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -100) 
    end

    frame.text = frame:CreateFontString(nil, "OVERLAY")
    if E then frame.text:FontTemplate(nil, 13, "OUTLINE") end
    frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.text:SetJustifyH("CENTER")
    frame.text:SetSpacing(6)
    frame.text:SetText("等待经验数据...")

    frame:SetScript("OnUpdate", function(self, elapsed)
        self.timer = (self.timer or 0) + elapsed
        if self.timer > 0.5 then 
            PB:UpdateXPInfo()
            self.timer = 0
        end
    end)

    frame:Hide()
    PB.XPFrame = frame
    
    PB.currentXP = UnitXP("player") or 0
    PB.maxXP = UnitXPMax("player") or 1
end

function PB:UpdateXPInfo()
    if not self.XPFrame then return end
    
    local currentLevel = UnitLevel("player")
    local maxLevel = GetMaxPlayerLevel()
    
    if currentLevel >= maxLevel then
        self.XPFrame.text:SetText(CHEX.."[已满级]|r\n无法获取角色经验")
        return
    end
    
    local pct = (self.currentXP / self.maxXP) * 100
    local remaining = self.maxXP - self.currentXP
    local battlesLeft = self.lastXPGain > 0 and math.ceil(remaining / self.lastXPGain) or 0
    
    local function formatTime(secs)
        if secs < 60 then return string.format("%d秒", math.floor(secs)) end
        local m = math.floor(secs / 60)
        local s = math.floor(secs % 60)
        return string.format("%d分%d秒", m, s)
    end

    local currentDuration = 0
    if C_PetBattles.IsInBattle() and self.battleStartTime > 0 then
        currentDuration = GetTime() - self.battleStartTime
    else
        currentDuration = self.lastBattleDuration or 0
    end

    local estTimeText = "?"
    if battlesLeft > 0 and self.lastBattleDuration and self.lastBattleDuration > 0 then
        local avgCycleTime = self.lastBattleDuration + 5
        local totalSecs = battlesLeft * avgCycleTime
        if totalSecs > 3600 then
            local h = math.floor(totalSecs / 3600)
            local m = math.floor((totalSecs % 3600) / 60)
            estTimeText = string.format("%d小时%d分", h, m)
        else
            estTimeText = formatTime(totalSecs)
        end
    end

    local start, duration = 0, 0
    if C_Spell and C_Spell.GetSpellCooldown then
        local cdInfo = C_Spell.GetSpellCooldown(125439)
        if cdInfo then start, duration = cdInfo.startTime, cdInfo.duration end
    elseif GetSpellCooldown then
        start, duration = GetSpellCooldown(125439)
    end
    
    local cdText = "|cff00ff00已就绪|r"
    local success, isOnCD = pcall(function() return (start and start > 0 and duration and duration > 1.5) end)
    if success and isOnCD then
        local remainCD = (start + duration) - GetTime()
        if remainCD > 0 then
            cdText = string.format("|cffff0000%s|r", formatTime(remainCD))
        end
    end

    local battlesLeftText = battlesLeft > 0 and tostring(battlesLeft) or "?"
    local txt = string.format("当前等级: %s%d|r (%.1f%%)\n", CHEX, currentLevel, pct)
    txt = txt .. string.format("升级需刷: 约 %s%s|r 场 (预计 %s%s|r)\n", CHEX, battlesLeftText, CHEX, estTimeText)
    txt = txt .. string.format("对战耗时: %s%s|r | 经验: %s%d|r\n", CHEX, formatTime(currentDuration), CHEX, self.lastXPGain)
    txt = txt .. string.format("复活技能 CD: %s", cdText)
    
    self.XPFrame.text:SetText(txt)
end

function PB:PLAYER_XP_UPDATE()
    if not E.db.WishFlex.modules.petBattle or not E.db.WishFlex.petBattle.showXP then return end
    
    local newXP = UnitXP("player") or 0
    local newMax = UnitXPMax("player") or 1
    
    if self.currentXP and self.maxXP then
        if newXP > self.currentXP then
            self.lastXPGain = newXP - self.currentXP
        elseif newXP < self.currentXP then 
            self.lastXPGain = (self.maxXP - self.currentXP) + newXP
        end
    end
    
    self.currentXP = newXP
    self.maxXP = newMax
    
    self:UpdateXPInfo()
end

----------------------------------------------------
-- 【终极奥义】：永久接管 tdBattlePetScript 神经中枢
----------------------------------------------------
local function InjectHookToTD()
    if not _G.PetBattleScripts then return end
    
    local RematchPlugin = _G.PetBattleScripts:GetPlugin('Rematch')
    if RematchPlugin and not PB.TDHooked then
        local orig_GetCurrentKey = RematchPlugin.GetCurrentKey
        
        RematchPlugin.GetCurrentKey = function(self)
            local targetID = PB.lockedBattleNPC or GetNPCID() or PB.lastTargetNPC
            if targetID and E.db.WishFlex.petBattle.targets[targetID] and PB.activeTeamID then
                return PB.activeTeamID
            end
            return orig_GetCurrentKey(self)
        end
        
        PB.TDHooked = true
        print(CHEX.."[WishFlex]|r 已成功接管 tdBattlePetScript，彻底解决脚本与队伍错位问题！")
    end
end

----------------------------------------------------
-- 核心底层：重写的最强数据读取
----------------------------------------------------
local function GetRematchTeams()
    local list = {}
    if not C_AddOns.IsAddOnLoaded("Rematch") then return { ["none"] = "请先启用 Rematch 插件" } end
    
    local found = false
    if _G.Rematch5SavedTeams then
        for id, data in pairs(_G.Rematch5SavedTeams) do
            if type(data) == "table" then 
                list[id] = data.name or id 
                found = true
            end
        end
    end
    if _G.RematchSaved then
        for id, data in pairs(_G.RematchSaved) do
            if type(data) == "table" then 
                list[id] = data.name or id 
                found = true
            end
        end
    end
    
    if not found then return { ["none"] = "未能读取到队伍，请在Rematch保存至少一个队伍。" } end
    return list
end

local function GetRematchTeamName(teamID)
    if _G.Rematch5SavedTeams and _G.Rematch5SavedTeams[teamID] then return _G.Rematch5SavedTeams[teamID].name or teamID end
    if _G.RematchSaved and _G.RematchSaved[teamID] then return _G.RematchSaved[teamID].name or teamID end
    return "未知队伍"
end

local function GetRematchBlueprint(teamID)
    local team = nil
    if _G.Rematch5SavedTeams and _G.Rematch5SavedTeams[teamID] then team = _G.Rematch5SavedTeams[teamID]
    elseif _G.RematchSaved and _G.RematchSaved[teamID] then team = _G.RematchSaved[teamID] end
    
    if not team then return nil end
    
    local blueprint = {}
    for slot = 1, 3 do
        local petID, abilities
        if team.pets then 
            petID = team.pets[slot]
            abilities = team.abilities and team.abilities[slot] or {}
        elseif type(team[slot]) == "table" then 
            petID = team[slot][1]
            abilities = { team[slot][2], team[slot][3], team[slot][4] }
        else
            petID = team[slot]
            abilities = {}
        end
        
        local speciesID = nil
        if type(petID) == "string" and petID:match("^BattlePet%-") then
            speciesID = C_PetJournal.GetPetInfoByPetID(petID)
        elseif type(petID) == "number" and petID > 0 then
            speciesID = petID
        end
        
        blueprint[slot] = {
            originalPetID = petID,
            speciesID = speciesID,
            abilities = abilities
        }
    end
    return blueprint
end

local function SyncRematchUI(teamID)
    if Rematch and Rematch.settings then Rematch.settings.currentTeamID = teamID end
    if _G.RematchSettings then _G.RematchSettings.currentTeamID = teamID end
    if Rematch and Rematch.events then
        Rematch.events:Fire("REMATCH_TEAM_LOADED", teamID)
        if Rematch.Frame and Rematch.Frame:IsShown() then Rematch.events:Fire("REMATCH_UPDATE") end
    end
end

local function ApplyNativeLoadout(slot, petID, abilities)
    local currentPetID = C_PetJournal.GetPetLoadOutInfo(slot)
    if currentPetID ~= petID then
        C_PetJournal.SetPetLoadOutInfo(slot, petID)
    end
    
    if abilities then
        for i = 1, 3 do
            local abilityID = abilities[i]
            if abilityID and abilityID > 0 then
                C_PetJournal.SetAbility(slot, i, abilityID)
            end
        end
    end
end

local function ForceLoadTeamDirectly(teamID)
    local blueprint = GetRematchBlueprint(teamID)
    if not blueprint then return end

    for slot = 1, 3 do
        local petID = blueprint[slot].originalPetID
        if type(petID) == "string" and petID:match("^BattlePet%-") then
            ApplyNativeLoadout(slot, petID, blueprint[slot].abilities)
        end
    end
    
    PB.activeTeamID = teamID
    SyncRematchUI(teamID)
end

----------------------------------------------------
-- 核心引擎：血量检测与多队伍回退 (Fallback)
----------------------------------------------------
local function FindHealthyReplacement(targetSpeciesID, minHealthPct, excludePetIDs)
    C_PetJournal.ClearSearchFilter()
    local _, numOwned = C_PetJournal.GetNumPets()

    for i = 1, numOwned do
        local petID, speciesID, isOwned = C_PetJournal.GetPetInfoByIndex(i)
        if isOwned and speciesID == targetSpeciesID and not excludePetIDs[petID] then
            local health, maxHealth = C_PetJournal.GetPetStats(petID)
            if health and maxHealth and maxHealth > 0 then
                local hpPct = (health / maxHealth) * 100
                if hpPct >= minHealthPct then return petID end
            end
        end
    end
    return nil 
end

function PB:CheckNextTeamInQueue()
    if #self.fallbackQueue == 0 then
        print(CHEX.."[WishFlex] 警告：绑定的所有对战图纸均已严重残血，请使用复活或绷带！|r")
        return
    end

    local teamID = table.remove(self.fallbackQueue, 1)
    local teamName = GetRematchTeamName(teamID)
    local blueprint = GetRematchBlueprint(teamID)
    
    if not blueprint then PB:CheckNextTeamInQueue(); return end
    
    local allGood = true
    local plan = {}
    local excludePetIDs = {}
    
    for slot = 1, 3 do
        local speciesID = blueprint[slot].speciesID
        if speciesID and speciesID > 0 then
            local threshold = E.db.WishFlex.petBattle.thresholds[slot] or 80
            local healthyPetID = FindHealthyReplacement(speciesID, threshold, excludePetIDs)
            if healthyPetID then
                plan[slot] = healthyPetID
                excludePetIDs[healthyPetID] = true
            else
                allGood = false 
                break
            end
        end
    end

    if allGood then
        C_Timer.After(0.05, function()
            for slot = 1, 3 do
                if plan[slot] then
                    ApplyNativeLoadout(slot, plan[slot], blueprint[slot].abilities)
                end
            end
            
            PB.activeTeamID = teamID
            SyncRematchUI(teamID) 
        end)
    else
        PB:CheckNextTeamInQueue()
    end
end

function PB:StartTargetCheck(specificNPCID)
    if InCombatLockdown() or C_PetBattles.IsInBattle() or not C_PetJournal.IsJournalUnlocked() then return end
    
    local npcID = specificNPCID or GetNPCID() or PB.lastTargetNPC
    if not npcID then return end

    local bindList = E.db.WishFlex.petBattle.targets[npcID]
    if not bindList or #bindList == 0 then return end

    self.currentCheckTarget = npcID

    local start, duration = 0, 0
    if C_Spell and C_Spell.GetSpellCooldown then
        local cdInfo = C_Spell.GetSpellCooldown(125439)
        if cdInfo then start, duration = cdInfo.startTime, cdInfo.duration end
    elseif GetSpellCooldown then
        start, duration = GetSpellCooldown(125439)
    end
    
    local success, isOnCD = pcall(function() return (start and start > 0 and duration and duration > 1.5) end)
    
    if success and not isOnCD then
        local firstTeamID = bindList[1]
        if firstTeamID then
            ForceLoadTeamDirectly(firstTeamID)
            return 
        end
    end

    self.fallbackQueue = {}
    for _, tid in ipairs(bindList) do table.insert(self.fallbackQueue, tid) end
    
    self:CheckNextTeamInQueue()
end

----------------------------------------------------
-- 【心跳级防卡死机制】
----------------------------------------------------
function PB:StartBattleMonitor()
    if self.battleTicker then 
        self.battleTicker:Cancel() 
        self.battleTicker = nil 
    end
    
    if E.db.WishFlex.petBattle.autoSurrender == nil then 
        E.db.WishFlex.petBattle.autoSurrender = true 
    end
    if not E.db.WishFlex.petBattle.surrenderTime then 
        E.db.WishFlex.petBattle.surrenderTime = 180 
    end
    
    if not E.db.WishFlex.petBattle.autoSurrender then return end
    
    self.battleStartTime = GetTime()
    local surrenderSecs = E.db.WishFlex.petBattle.surrenderTime
    
    self.battleTicker = C_Timer.NewTicker(5, function()
        if not C_PetBattles.IsInBattle() then
            if PB.battleTicker then PB.battleTicker:Cancel(); PB.battleTicker = nil end
            return
        end
        
        local elapsed = GetTime() - PB.battleStartTime
        if elapsed >= surrenderSecs then
            print(string.format("%s[WishFlex]|r 战斗异常！已超过设定的 %d 秒，正在强制投降...", CHEX, surrenderSecs))
            C_PetBattles.ForfeitGame() 
            if PB.battleTicker then PB.battleTicker:Cancel(); PB.battleTicker = nil end
        end
    end)
end

----------------------------------------------------
-- 核心事件监控
----------------------------------------------------

function PB:PLAYER_TARGET_CHANGED()
    if not E.db.WishFlex.modules.petBattle then return end
    local npcID = GetNPCID()
    if npcID and E.db.WishFlex.petBattle.targets[npcID] then
        PB.lastTargetNPC = npcID
    end

    if targetChangeTimer then targetChangeTimer:Cancel() end
    targetChangeTimer = C_Timer.NewTimer(0.15, function() PB:StartTargetCheck() end)
end

function PB:PET_BATTLE_OPENING_START()
    if not E.db.WishFlex.modules.petBattle then return end
    PB.lockedBattleNPC = PB.lastTargetNPC or GetNPCID()
    PB.battleStartTime = GetTime() 
    PB:StartBattleMonitor()
    
    if E.db.WishFlex.petBattle.showXP and PB.XPFrame then
        PB.XPFrame:Show()
        PB:UpdateXPInfo()
    end
end

function PB:PET_BATTLE_CLOSE()
    if not E.db.WishFlex.modules.petBattle then return end
    
    if PB.battleStartTime > 0 then
        PB.lastBattleDuration = GetTime() - PB.battleStartTime
    end
    
    if PB.battleTicker then 
        PB.battleTicker:Cancel() 
        PB.battleTicker = nil 
    end
    
    if PB.XPFrame then
        C_Timer.After(4, function()
            if not C_PetBattles.IsInBattle() then
                PB.XPFrame:Hide()
            end
        end)
    end
    
    if targetChangeTimer then targetChangeTimer:Cancel() end
    
    local targetToPatch = PB.lockedBattleNPC or PB.lastTargetNPC
    targetChangeTimer = C_Timer.NewTimer(0.15, function() 
        if PB.pendingReviveSwitch then
            PB.pendingReviveSwitch = false
            if targetToPatch and E.db.WishFlex.petBattle.targets[targetToPatch] then
                local firstTeamID = E.db.WishFlex.petBattle.targets[targetToPatch][1]
                if firstTeamID then ForceLoadTeamDirectly(firstTeamID) end
                PB.lockedBattleNPC = nil
                return 
            end
        end

        if targetToPatch then PB:StartTargetCheck(targetToPatch) end
        PB.lockedBattleNPC = nil
    end)
end

function PB:SPELL_UPDATE_COOLDOWN()
    if not E.db.WishFlex.modules.petBattle then return end
    local start, duration = 0, 0
    
    if C_Spell and C_Spell.GetSpellCooldown then
        local cdInfo = C_Spell.GetSpellCooldown(125439)
        if cdInfo then start, duration = cdInfo.startTime, cdInfo.duration end
    elseif GetSpellCooldown then
        start, duration = GetSpellCooldown(125439)
    end
    
    local success, isOnCD = pcall(function() return (start and start > 0 and duration and duration > 1.5) end)
    if not success then return end 
    
    if isOnCD and not PB.reviveWasOnCD then
        PB.reviveWasOnCD = true
    elseif not isOnCD and PB.reviveWasOnCD then
        PB.reviveWasOnCD = false
        
        if InCombatLockdown() or C_PetBattles.IsInBattle() then 
            PB.pendingReviveSwitch = true
            return 
        end 
        
        if PB.lastTargetNPC and E.db.WishFlex.petBattle.targets[PB.lastTargetNPC] then
            local firstTeamID = E.db.WishFlex.petBattle.targets[PB.lastTargetNPC][1]
            if firstTeamID then ForceLoadTeamDirectly(firstTeamID) end
        end
    end
end

function PB:UNIT_SPELLCAST_SENT(event, unit, target, castGUID, spellID)
    if not E.db.WishFlex.modules.petBattle then return end
    if C_PetBattles.IsInBattle() then return end 

    if unit == "player" then
        if spellID == 125439 or spellID == 125801 then
            if PB.lastTargetNPC and E.db.WishFlex.petBattle.targets[PB.lastTargetNPC] then 
                local firstTeamID = E.db.WishFlex.petBattle.targets[PB.lastTargetNPC][1]
                if firstTeamID then ForceLoadTeamDirectly(firstTeamID) end
            end
        end
    end
end

function PB:UNIT_SPELLCAST_SUCCEEDED(event, unit, castGUID, spellID)
    if not E.db.WishFlex.modules.petBattle then return end
    if C_PetBattles.IsInBattle() then return end 

    if unit == "player" then
        if spellID == 125439 or spellID == 125801 then
            if PB.activeTeamID then 
                -- 静默处理
            end
        end
    end
end

function PB:UNIT_SPELLCAST_INTERRUPTED(event, unit, castGUID, spellID)
    if not E.db.WishFlex.modules.petBattle then return end
    if C_PetBattles.IsInBattle() then return end

    if unit == "player" and (spellID == 125439 or spellID == 125801) then
    end
end

----------------------------------------------------
-- 【全新功能】自动生成劳模无脑刷宏 
----------------------------------------------------
local function CreateFarmMacro()
    if InCombatLockdown() then return print(CHEX.."[WishFlex]|r 请在角色脱战状态下生成宏！") end
    
    local npcName = UnitName("target")
    if not npcName then return print(CHEX.."[WishFlex]|r 失败：请先在游戏中用鼠标选中你要刷的劳模 NPC！") end
    
    local macroName = "WF无脑刷"
    local macroBody = "#showtooltip\n/targetexact " .. npcName .. "\n/cast [nocombat] 复活战斗宠物\n/click tdBattlePetScriptAutoButton"
    
    local macroIndex = GetMacroIndexByName(macroName)
    if macroIndex > 0 then
        EditMacro(macroIndex, macroName, "INV_PET_BATTLEPETTRAINING", macroBody)
        print(CHEX.."[WishFlex]|r 宏 ["..macroName.."] 已更新！当前锁定劳模：["..npcName.."]")
    else
        local numGlobal = select(1, GetNumMacros())
        if numGlobal < 120 then
            CreateMacro(macroName, "INV_PET_BATTLEPETTRAINING", macroBody, false)
            print(CHEX.."[WishFlex]|r 成功生成宏 ["..macroName.."]！请打开宏面板(/m)拖至快捷键。")
        else
            print(CHEX.."[WishFlex]|r 你的通用宏数量已满，无法自动创建，请手动清理腾出位置！")
        end
    end
end

----------------------------------------------------
-- UI 交互面板
----------------------------------------------------
function PB:BindTeamToTarget()
    local npcID, targetName = GetNPCID(), UnitName("target")
    if not npcID or not targetName then return print(CHEX.."WishFlex:|r 请先在游戏中选中目标NPC！") end
    if not PB.selectedBindTeamID or PB.selectedBindTeamID == "none" then return print(CHEX.."WishFlex:|r 请先选择一个有效的 Rematch 队伍图纸！") end
    
    E.db.WishFlex.petBattle.targets[npcID] = E.db.WishFlex.petBattle.targets[npcID] or {}
    for _, tid in ipairs(E.db.WishFlex.petBattle.targets[npcID]) do 
        if tid == PB.selectedBindTeamID then return print(CHEX.."WishFlex:|r 该图纸已在后备列表中！") end 
    end
    table.insert(E.db.WishFlex.petBattle.targets[npcID], PB.selectedBindTeamID)
    print(string.format("%sWishFlex:|r 成功将图纸 [%s] 加入目标后备列表！", CHEX, GetRematchTeamName(PB.selectedBindTeamID)))
end

local function InjectOptions()
    WUI.OptionsArgs = WUI.OptionsArgs or {}
    WUI.OptionsArgs.widgets = WUI.OptionsArgs.widgets or { order = 21, type = "group", name = "|cff00e5cc小工具|r", childGroups = "tab", args = {} }
    WUI.OptionsArgs.widgets.args = WUI.OptionsArgs.widgets.args or {}
    
    WUI.OptionsArgs.widgets.args.petBattle = {
        order = 30, type = "group", name = "智能宠物管家", childGroups = "tab",
        args = {
            enable = { order = 1, type = "toggle", name = "启用队伍管家模块", get = function() return E.db.WishFlex.modules.petBattle end, set = function(_, v) E.db.WishFlex.modules.petBattle = v; E:StaticPopup_Show("CONFIG_RL") end }, 
            desc = { order = 2, type = "description", fontSize = "medium", name = "说明：采用原生底层装载机制，彻底架空 Rematch。Rematch 现仅作为【图纸库】供你保存队伍物种与技能搭配。" },
            
            targetTab = {
                order = 3, type = "group", name = "1. 绑定顺位打手队伍",
                args = {
                    info = { order = 1, type = "description", fontSize = "large", name = function() local n = GetNPCID(); return n and string.format("\n当前选中目标: |cff00ffcc%s|r (NPC ID: %d)\n", UnitName("target"), n) or "\n|cffff0000[请在游戏中鼠标选中要挑战的NPC]|r\n" end },
                    bindSel = { order = 2, type = "select", name = "读取你存好的 Rematch 图纸", width="double", values = GetRematchTeams, get = function() return PB.selectedBindTeamID end, set = function(_, v) PB.selectedBindTeamID = v end },
                    bindBtn = { order = 3, type = "execute", name = "添加至该目标的顺位列表", func = function() PB:BindTeamToTarget() end },
                    clearBtn = { order = 4, type = "execute", name = "清空该目标所有绑定", func = function() local n = GetNPCID(); if n then E.db.WishFlex.petBattle.targets[n] = nil; print("已清空！") end end },
                    
                    spacer = { order = 5, type = "description", name = "\n|cffaaaaaa——————————————————————————|r\n" },
                    
                    bindList = {
                        order = 6, type = "description", fontSize = "medium",
                        name = function()
                            local n = GetNPCID()
                            if not n or not E.db.WishFlex.petBattle.targets[n] or #E.db.WishFlex.petBattle.targets[n] == 0 then return "\n当前目标暂无绑定的顺位队伍。" end
                            local txt = "\n|cff00ffcc当前目标的加载顺位 (自上而下检测血量)：|r\n"
                            for i, tid in ipairs(E.db.WishFlex.petBattle.targets[n]) do
                                txt = txt .. string.format(" %d. %s\n", i, GetRematchTeamName(tid))
                            end
                            return txt
                        end
                    },
                    
                    spacer2 = { order = 7, type = "description", name = "\n|cffaaaaaa——————————————————————————|r\n" },
                    
                    macroBtn = { 
                        order = 8, type = "execute", name = "生成【一键无脑刷】宏", 
                        desc = "【注意】：暴雪已禁止宏直接与NPC对话。您需要配合原生的按键设置使用：\n\n1. 在此处点击生成宏。\n2. 将生成的宏拖到动作条，绑定为【鼠标滚轮上】。\n3. 打开魔兽自带的【按键设置】-【选中目标】，找到【与目标互动】功能，并绑定为【鼠标滚轮下】。\n\n设置好后，对战时只要来回疯狂搓动鼠标滚轮，即可实现“秒选目标-秒对话-秒复活-秒放技能”的全自动闭眼刷！",
                        func = function() CreateFarmMacro() end 
                    },
                }
            },
            
            thresholdTab = {
                order = 4, type = "group", name = "2. 全局替补血线要求",
                args = {
                    desc = { order = 1, type = "description", name = "如果队伍中该槽位的宠物血量低于以下设定值，系统将自动寻找包里健康的同名同类宠物顶替，并强制应用原图纸技能。\n" },
                    hp1 = { order = 2, type = "range", name = "一号位最低血量 (%)", min=1,max=100,step=1, get = function() return E.db.WishFlex.petBattle.thresholds[1] end, set = function(_,v) E.db.WishFlex.petBattle.thresholds[1] = v end },
                    hp2 = { order = 3, type = "range", name = "二号位最低血量 (%)", min=1,max=100,step=1, get = function() return E.db.WishFlex.petBattle.thresholds[2] end, set = function(_,v) E.db.WishFlex.petBattle.thresholds[2] = v end },
                    hp3 = { order = 4, type = "range", name = "三号位最低血量 (%)", min=1,max=100,step=1, get = function() return E.db.WishFlex.petBattle.thresholds[3] end, set = function(_,v) E.db.WishFlex.petBattle.thresholds[3] = v end },
                }
            },
            
            autoSurrenderTab = {
                order = 5, type = "group", name = "3. 防卡死保护",
                args = {
                    desc = { order = 1, type = "description", name = "防止脚本出现死循环一直卡在战斗中。如果战斗时间超过设定值，系统将自动发起投降。\n" },
                    enable = { order = 2, type = "toggle", name = "启用超时自动投降", get = function() return E.db.WishFlex.petBattle.autoSurrender end, set = function(_,v) E.db.WishFlex.petBattle.autoSurrender = v end },
                    time = { order = 3, type = "range", name = "超时阈值 (秒)", min=30, max=600, step=10, get = function() return E.db.WishFlex.petBattle.surrenderTime end, set = function(_,v) E.db.WishFlex.petBattle.surrenderTime = v end },
                }
            },
            
            xpTab = {
                order = 6, type = "group", name = "4. 经验监控面板",
                args = {
                    desc = { order = 1, type = "description", name = "在宠物对战期间显示一个信息面板，实时统计单局获取经验以及距离升级所需场次。\n鼠标悬停即可直接拖动位置，系统会自动永久保存。\n" },
                    enable = { order = 2, type = "toggle", name = "启用经验监控面板", get = function() return E.db.WishFlex.petBattle.showXP end, set = function(_,v) 
                        E.db.WishFlex.petBattle.showXP = v; 
                        if v and PB.XPFrame and C_PetBattles.IsInBattle() then PB.XPFrame:Show() 
                        elseif PB.XPFrame then PB.XPFrame:Hide() end 
                    end },
                }
            }
        }
    }
end

hooksecurefunc(WUI, "Initialize", function() if not PB.Initialized then PB:Initialize() end end)

function PB:Initialize()
    if self.Initialized then return end
    self.Initialized = true
    InjectOptions()
    if not E.db.WishFlex.modules.petBattle then return end
    
    if E.db.WishFlex.petBattle.showXP == nil then E.db.WishFlex.petBattle.showXP = true end
    
    CreateXPFrame()
    
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("PET_BATTLE_OPENING_START")
    self:RegisterEvent("PET_BATTLE_CLOSE")
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    self:RegisterEvent("UNIT_SPELLCAST_SENT")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    self:RegisterEvent("UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED")
    self:RegisterEvent("PLAYER_XP_UPDATE")
    
    if C_PetBattles.IsInBattle() then
        PB.battleStartTime = GetTime()
        PB:StartBattleMonitor()
        if E.db.WishFlex.petBattle.showXP and PB.XPFrame then
            PB.XPFrame:Show()
            PB:UpdateXPInfo()
        end
    end
    
    C_Timer.After(2, InjectHookToTD)
end