local AddonName, ns = ...
local locale = GetLocale()
if locale ~= "zhCN" and locale ~= "zhTW" then return end

local L = ns.L

-- 菜单
L["WishFlex Settings"] = "WishFlex 设置"
L["Settings Console"] = "设置中心"
L["Combat"] = "战斗"
L["Cooldown Manager"] = "冷却管理器"
L["Class Resource"] = "资源条"
L["Action Button Glow"] = "发光"

-- 侧边栏
L["Global Settings"] = "全局"
L["Core Glow"] = "发光"
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
L["Feature 3"] = "- 高级冷却管理器"
L["Feature 4"] = "- 轻量化玩家资源条轨道"
L["Feature 5"] = "- 内置智能锚点编辑器"
L["Quick Actions"] = "快捷操作"
L["Reload UI"] = "重载界面"
L["Toggle Anchors"] = "解锁/锁定锚点"
L["Addon Info"] = "插件信息"
L["Version"] = "版本"
L["Author"] = "作者"

-- 通用设置
L["Enable Module"] = "启用"
L["Enable"] = "启用"
L["Width"] = "宽度"
L["Height"] = "高度"
L["Icon Gap"] = "间距"
L["Max Per Row"] = "换行图标数量"
L["Attach To Player"] = "玩家框体"
L["Total Width"] = "整体宽度"

-- 冷却全局
L["Global Font"] = "全局"
L["Default Swipe Color"] = "冷却遮罩"
L["Active Swipe Color"] = "触发遮罩"
L["Reverse Swipe"] = "冷却反向"
L["Enable Split Layout"] = "启用双行布局"
L["Row Y Gap"] = "行间距"

-- 文本专用
L["Row 1 Settings"] = "第一行设置"
L["Row 2 Settings"] = "第二行设置"
L["Stack Text"] = "层数文本"
L["CD Text"] = "倒计时文本"
L["Font Size"] = "字体大小"
L["Color"] = "文本颜色"
L["X Offset"] = "X轴"
L["Y Offset"] = "Y轴"
L["Anchor"] = "位置"

-- 九宫格锚点
L["TOPLEFT"] = "左上"
L["TOP"] = "顶部"
L["TOPRIGHT"] = "右上"
L["LEFT"] = "左侧"
L["CENTER"] = "居中"
L["RIGHT"] = "右侧"
L["BOTTOMLEFT"] = "左下"
L["BOTTOM"] = "底部"
L["BOTTOMRIGHT"] = "右下"

-- 发光设置
L["Glow Settings"] = "设置"
L["Glow Style"] = "发光样式"
L["Pixel"] = "像素发光"
L["Autocast"] = "触发发光"
L["Button"] = "按键高亮"
L["Proc"] = "触发频闪"
L["Enable Custom Color"] = "启用独立染色"
L["Lines"] = "线条数"
L["Frequency"] = "频率"
L["Length"] = "长度"
L["Thickness"] = "粗细"
L["Particles"] = "数量"
L["Scale"] = "大小"
L["Duration"] = "频闪持续时间"