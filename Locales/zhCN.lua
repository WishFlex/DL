local AddonName, ns = ...
local locale = GetLocale()
if locale ~= "zhCN" and locale ~= "zhTW" then return end

local L = ns.L

-- 菜单
L["WishFlex Settings"] = "WishFlex 设置"
L["Settings Console"] = "设置中心"
L["Combat"] = "战斗"
L["Cooldown Manager"] = "冷却管理器"

-- 【核心新增：资源条侧边栏层级】
L["Class Resource"] = "资源条"
L["RC Global"] = "主控"
L["RC Power"] = "能量条"
L["RC Class"] = "主资源条"
L["RC Mana"] = "额外法力"
L["RC Aura"] = "增益条"
L["RC Scanner"] = "增益扫描"

-- 侧边栏
L["Global Settings"] = "全局与外观"
L["Core Glow"] = "核心发光特效"
L["Essential Skills"] = "重要技能"
L["Utility Skills"] = "效能技能"
L["Buff Icons"] = "增益图标"
L["Buff Bars"] = "增益条"

-- 主页 HOME
L["Home"] = "主页"
L["MENU"] = "菜单"
L["Welcome to WishFlex"] = "欢迎使用 WishFlex GeniSys"
L["Addon Description"] = "WishFlex 是一款轻量化、模块化、高性能的优化套装。专为追求极致排版、强迫症、高科技感和简约主义的玩家打造。"
L["Core Features"] = "核心功能:"
L["Feature 1"] = "- 模块化按需加载 (低内存占用)"
L["Feature 2"] = "- 极致简约的扁平化 UI 与职业色主题"
L["Feature 3"] = "- 高级冷却管理器 (含 VFlow 级像素发光)"
L["Feature 4"] = "- 轻量化玩家资源条轨道"
L["Feature 5"] = "- 内置智能锚点编辑器"
L["Quick Actions"] = "快捷操作"
L["Reload UI"] = "重载界面"
L["Toggle Anchors"] = "解锁/锁定锚点"
L["Addon Info"] = "插件信息"
L["Version"] = "版本"
L["Author"] = "作者"

-- 通用设置
L["Enable Module"] = "启用模块"
L["Enable"] = "启用"
L["Width"] = "图标宽度"
L["Height"] = "图标高度"
L["Icon Gap"] = "图标间距"
L["Max Per Row"] = "每排最大显示数量"
L["Attach To Player"] = "依附至玩家头像框边"
L["Total Width"] = "整体宽度"

-- 文本专用
L["Row 1 Settings"] = "第一排独立设置"
L["Row 2 Settings"] = "第二排独立设置"
L["Stack Text"] = "层数文本设置 (Stack)"
L["CD Text"] = "倒计时文本设置 (CD)"
L["Font Size"] = "字体大小"
L["Color"] = "文本颜色"
L["X Offset"] = "X轴偏移"
L["Y Offset"] = "Y轴偏移"
L["Anchor"] = "锚点位置 (九宫格)"

-- 九宫格锚点
L["TOPLEFT"] = "左上"
L["TOP"] = "中上"
L["TOPRIGHT"] = "右上"
L["LEFT"] = "左侧"
L["CENTER"] = "正中心"
L["RIGHT"] = "右侧"
L["BOTTOMLEFT"] = "左下"
L["BOTTOM"] = "中下"
L["BOTTOMRIGHT"] = "右下"