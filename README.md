# 暗夜求生

> 2D 轻度 Roguelike 动作游戏 · Godot 4 开发

## 游戏类型

- **轻度肉鸽（Roguelike）** — 类 Vampire Survivors / Brotato
- 操控角色对抗源源不断的怪物潮，通过击杀敌人获取经验值升级，选择随机强化构建独特流派

## 操作说明

| 操作 | 按键 |
|---|---|
| 移动 | W / A / S / D |
| 瞄准 | 鼠标 |
| 冲刺 | 空格 |
| 切换武器 | 1 / 2 / 3 |
| 获得散弹枪 | Q（测试） |
| 获得激光枪 | E（测试） |
| 暂停 | ESC |
| 调试面板 | F1 |

## 已完成功能

### 核心系统
- 玩家移动（WASD + 鼠标朝向 + 冲刺）
- 鼠标瞄准射击（武器朝向跟随鼠标）
- 自动连射 + 弹幕散布

### 武器系统
- 数据驱动武器配置（weapon_data.json）
- 3 种武器：手枪 / 散弹枪 / 激光枪
- 武器槽位切换（1/2/3）
- 武器基类（WeaponBase），支持扩展新武器

### 敌人系统
- 多种敌人类型（基础兵 / 史莱姆 / 蝙蝠 / 石像 / 章鱼 / 恶魔）
- 精英怪（头顶血条 + 属性强化）
- Boss（冲撞 AI + 屏幕警报 + 血条 + 死亡掉落）

### 战斗系统
- 子弹碰撞 + 穿透 + 伤害数字
- 相机震动 / 受击闪白 / 死亡粒子
- 音效系统（可选，有音频文件时自动启用）

### 成长系统
- 经验掉落 → 自动吸收 → 升级
- 三选一升级面板（普通 / 稀有 / 史诗 / 传说 稀有度）
- 8 种升级类型：伤害 / 攻速 / 弹数 / 移速 / 生命 / 穿透 / 弹速 / 治疗

### 游戏流程
- 主菜单 → 开始游戏 / 设置（音量+全屏） / 退出
- 暂停菜单 → 继续 / 重新开始 / 返回主菜单
- 游戏结束 → 结算统计 / 重新开始 / 返回主菜单

### 系统架构
- 数据驱动：所有敌人/升级/武器数据通过 JSON 配置
- 对象池：子弹 / 敌人 / 经验球统一管理，减少 GC
- 信号驱动：UI 与逻辑解耦，通过信号同步状态
- Autoload 单例：GameManager / DataManager / ObjectPoolManager / AudioManager

### UI
- TextureProgressBar 血条 + 经验条（动态渐变）
- 暗黑风格主题（半透明面板 + 金色高亮）
- Boss 警报动画 / Boss 血条
- FPS 调试面板（F1）

### 数值平衡
- 波次递增（间隔缩减 + 数量增长 + 属性缩放）
- game_balance.json 集中配置缩放参数

## 计划开发

- [ ] 更多武器（火焰喷射器 / 火箭筒 / 冰冻 / 雷电）
- [ ] 角色选择系统
- [ ] 地图场景（基础地形 / 障碍物）
- [ ] 被动技能系统
- [ ] 成就系统
- [ ] 存档系统
- [ ] 音效素材完善
- [ ] 角色动画

## 使用引擎

- **Godot 4.6**
- **GDScript**（100%）
- 遵循项目编码规范：snake_case / 中文注释 / 信号驱动 / 数据驱动

## 运行方式

1. 安装 [Godot Engine 4.6+](https://godotengine.org/)
2. 用 Godot 打开项目根目录（包含 `project.godot` 的文件夹）
3. 等待资源导入完成
4. 点击右上角 **运行项目**（F5）

```
git clone <仓库地址>
# 用 Godot 打开 project.godot
```

## 项目结构

```
Game1/
├── assets/              # 美术/音频资源
│   ├── player/          # 玩家素材
│   ├── enemy/           # 敌人素材
│   ├── bullet/          # 子弹素材
│   ├── effects/         # 特效素材
│   └── audio/           # 音效文件
├── data/                # JSON 数据配置
│   ├── enemy_data.json
│   ├── upgrade_data.json
│   ├── weapon_data.json
│   ├── wave_data.json
│   └── game_balance.json
├── scenes/              # 场景文件
│   ├── main/            # 主菜单 + 游戏场景
│   ├── player/          # 玩家
│   ├── enemy/           # 敌人
│   ├── bullet/          # 子弹
│   ├── pickup/          # 拾取物
│   ├── ui/              # UI 界面
│   ├── effects/         # 特效
│   └── manager/         # 管理器
├── scripts/             # GDScript 脚本
│   ├── player/          # 玩家脚本
│   ├── enemy/           # 敌人脚本
│   ├── weapon/          # 武器系统
│   ├── bullet/          # 子弹脚本
│   ├── systems/         # 通用系统
│   ├── manager/         # 管理器
│   └── ui/              # UI 脚本
├── docs/                # 文档
└── project.godot        # 引擎配置
```
