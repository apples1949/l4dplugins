# l4dplugins
个人服务器插件备忘录  
仅供参考  
也是白嫖别人的备忘录整理的  

6882(1.11)linux  
2022-5-4豆瓣酱な (v1.1.0.6528-974)战役整合包（中国插件qq群豆瓣酱最新整理 需要加群 别问群号）   
可选-修复类(v1.0.2)(修复玩家正在连接时不出特感)    
必选-修复类(v1.0.4)(幸存者闲置修复)  
必选-修复类(v1.1.1)(修复女巫丢失目标)//witch_prevent_target_loss.smx-4人关  
必选-修复类(v1.2.2-git135)(linux版本)(修复c6m1实体过多任务失败炸服)  
必选-修复类(v1.4)(修复女巫攻击错误的惊扰者)//Witch_Target_patch.smx-4人关  
必选-修复类(v1.7)(幸存者身份修复)//l4d_survivor_identity_fix.smx-4人关  
必选-修复类(v2.0.1)(修复电击器救起存活的幸存者)  
必选-修复类(v2.8)(解决linux系统CFG不加载)  
必选-内存补丁类扩展sourcescramble.ext(v0.7.0)  
必选-功能类扩展dhooks.ext(v2.2.0-detours17)  
必选-功能类插件left4dhooks(v1.100)(2022年4月28日)  
自选-8角色共存(v1.6.8)//survivor_chat_select.smx-4人关  
自选-8角色共存(修复c6m1和c6m3地图中的传送bug)  
自选-MOD(8人大厅)  
自选-tick解锁扩展(启动项加 -tickrate 100)(需要配合tick设置插件使用)  
自选-tick设置插件(启动项加 -tickrate 100)(需要配合tick解锁扩展使用)  
自选-保存玩家的STEAM用户名,数字ID跟聊天记录到logs  
自选-修复玩家过关后装备和属性混乱(v1.2.0)(作者sorallll)//transition_restore_fix.smx-4人关  
自选-修改近战对坦克和女巫的比例伤害或固定伤害//l4d2_antimelee.smx-4人关  
自选-倒地即死时阻止不正常的心跳声  
自选-击杀或爆头和黑枪提示和关闭队伤  
自选-击杀特感坦克女巫奖励血量和前置弹药(可关闭击杀特感提示)  
自选-后备弹药插件  
自选-坦克出现时根据幸存者人数增加血量和女巫随机或固定血量//l4d2_tank_announce.smx-4人关  
自选-坦克特感女巫血量显示和坦克死亡提示  
自选-多人插件//l4d2_multislots.smx-4人关  
自选-幸存者死亡和被制服提示  
自选-幸存者自杀指令  
自选-幸存者触发警报车提示  
自选-幸存者闲置状态使用自由视角  
自选-幸存者黑白发光(请看CFG里的说明)  
自选-扔投掷物提示(v1.0.8)(注意-本地服务器请勿使用)  
自选-服务器中文名(指令!host立即刷新服名)  
自选-服务器里没人后自动炸服(建议linux系统使用)  
自选-点燃或打爆物品提示(v1.0.7)(注意-本地服务器请勿使用)  
自选-特感主动攻击幸存者(v1.1.1)(作者sorallll)//aggresive_specials_patch.smx-4人关  
自选-管理员娱乐菜单  
自选-管理员暂停游戏(精简版)  
自选-管理员更改游戏模式  
自选-管理员菜单更改难度  
自选-设置医疗物品倍数(根据人数或固定倍数)  
自选-防止服务器人数不足而关闭  

[addons]l4d_dissolve_infected.smx 击杀溶解效果1.15 https://forums.alliedmods.net/showthread.php?t=306789   
[addons]mvpnowy.smx 去除望夜广告的排行榜插件 https://github.com/apples1949/l4dplugins/blob/main/mvpnowy.sp  
[addons]l4d2_item_hint.smx [addons]l4d_use_priority.smx 标记物品特感和位置插件和修复插件 https://github.com/fbef0102/L4D2-Plugins/tree/master/l4d2_item_hint   
[addons]l4d_bunnyhop.smx 连跳插件 https://forums.alliedmods.net/showthread.php?t=298555  
[addons]l4d2_tda.sp 支持多人坦克伤害统计 https://github.com/apples1949/l4dplugins/blob/main/l4d2_tda.sp （某群友给的不方便透露）//测试  
[addons]l4d_witch_damage_announce.smx 女巫伤害统计 https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/addons/sourcemod/scripting/l4d_witch_damage_announce.sp （zm版本不支持多人 用的是之前smside论坛找的支持多人的插件 忘了存源码）  
[addons]l4d_ffannounce.smx 友伤显示 https://github.com/Target5150/MoYu_Server_Stupid_Plugins/tree/master/The%20Last%20Stand/l4d_ffannounce  
[addons]l4d2_sgfix.smx 修复sg552换弹问题 https://forums.alliedmods.net/showthread.php?p=1551119  
[addons]lfd_both_fixSG552.smx 修复sg552高tick下换弹问题 https://forums.alliedmods.net/showthread.php?t=322141  
[addons]l4d2_msg_system_zh.smx 各种消息提示 https://github.com/9-BAKA/sourcemod/blob/master/l4d2_msg_system_zh.sp (其实才发现不需要）  
[addons]l4d_coop_markers.smx 路程提示 https://forums.alliedmods.net/showthread.php?t=321288  
[addons]l4d_headshot_buff 爆头提示音 https://forums.alliedmods.net/showthread.php?t=336523  
[addons]l4d_gear_transfer.smx 按键给物品 https://forums.alliedmods.net/showthread.php?t=137616  
[addons]l4d2_sb_fix.smx bot加强 https://forums.alliedmods.net/showthread.php?p=2774567#post2774567  
[addons]l4d2_server_update_checker.smx 服务器自动更新后重启 https://github.com/fdxx/l4d2_plugins/blob/main/l4d2_server_update_checker.sp  
[addons]anti-friendly_fire.smx 反伤插件 https://github.com/fbef0102/Rotoblin-AZMod/blob/master/SourceCode/scripting-az/anti-friendly_fire.sp  
[addons]l4d2_incap_magnum.smx 倒地马格南 https://forums.alliedmods.net/showthread.php?t=120575  
[addons]NekoAdminMenu.smx/[addons]NekoSpecials.smx Neko多特 https://github.com/himenekocn/NekoSpecials-L4D2  
[addons]show_mic.smx/[addons]ThirdPersonShoulder_Detect.smx 显示谁在说话 https://github.com/fbef0102/L4D2-Plugins/tree/master/show_mic  
[addons]l4d2_skill_detect.smx/[addons]l4d2_stats.smx 特殊操作提示 https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/addons/sourcemod/scripting/l4d2_skill_detect.sp/https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/addons/sourcemod/scripting/l4d2_stats.sp  
[addons]l4d2_ellis_hunter_bandaid_fix.smx ellis起身修复 https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/addons/sourcemod/scripting/l4d2_ellis_hunter_bandaid_fix.sp  
meleedrop.vpk 死亡掉落副武器 https://steamcommunity.com/sharedfiles/filedetails/?id=2608563050  
[addons]l4d_nightvision.smx 夜视仪 https://github.com/Dragoon666/l4d2_supercoop_standard/blob/win/left4dead2/addons/sourcemod/scripting/_sc_l4d_nightvision.sp  
[addons]l4d_automatic_weapons.smx 部分单发武器连射   https://github.com/AldoDiaz01/Left4Dead2_Sourcemod_Plugins/blob/master/left4dead2/addons/sourcemod/scripting/l4d_automatic_weapons.sp  
[addons]anti_bot_medkit.smx 阻止ai打包 https://github.com/SamuelXXX/l4d2_supercoop_for2/blob/master/left4dead2/addons/sourcemod/scripting/_sc_anti_bot_medkit.sp  
[addons]all4dead2.smx 另外个游戏控制插件 https://github.com/apples1949/l4dplugins/blob/main/all4dead2.sp  
