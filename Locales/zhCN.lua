local AddonName, ns = ...
local locale = GetLocale()

-- 如果不是中文客户端，就不加载这个文件
if locale ~= "zhCN" and locale ~= "zhTW" then return end

local L = ns.L

-- 中文翻译覆盖
L["WishFlex Settings"] = "WishFlex 设置"
L["General"] = "常规"
L["Enable"] = "启用模块"
L["Aura Glow"] = "技能状态高亮"
L["Settings Console"] = "设置中心"
L["Enable Module"] = "启用该模块"
L["Requires Reload"] = "模块开关状态已更改，需要重载界面 (/rl) 才能生效！"
L["WIP Note"] = "底层渲染引擎已激活。具体的详细参数调节UI即将实装..."
L["Cooldown Tracker"] = "技能可用性智能变灰"
L["Action Button Glow"] = "技能高亮"
L["Combat"] = "战斗"
L["Enable"] = "启用"
L["Requires Reload"] = "此选项更改后需要重载界面 (/rl) 才能完全生效。"
L["Width"] = "宽度"
L["Align With CD"] = "依附于冷却条排版"
L["Reverse Swipe"] = "反向转圈"