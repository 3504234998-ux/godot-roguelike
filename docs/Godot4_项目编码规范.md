# Godot4 项目编码规范

---

# 一、文档目标

本规范用于统一：

- 项目结构
- 命名方式
- 节点规则
- GDScript风格
- AI生成代码格式

目的：

```text
保证多人开发与AI生成代码时，
项目不会混乱。
```

---

# 二、开发环境统一

| 项目 | 环境 |
|---|---|
| 引擎 | Godot 4.6.2 |
| 编辑器 | VSCode |
| 语言 | GDScript |
| Python | 3.10.19 |
| 虚拟环境 | Conda（AN） |

---

# 三、项目目录规范

---

# 根目录结构

```text
Game1/
│
├── assets/            # 美术资源
├── scenes/            # 场景
├── scripts/           # 脚本
├── data/              # 配置数据
├── docs/              # 文档
├── saves/             # 存档
└── addons/            # Godot插件
```

---

# 四、资源目录规范

---

# 1. 美术资源

```text
assets/
│
├── player/
├── enemy/
├── bullet/
├── effects/
├── ui/
└── audio/
```

---

# 2. 场景目录

```text
scenes/
│
├── player/
├── enemy/
├── bullet/
├── ui/
├── map/
└── manager/
```

---

# 3. 脚本目录

```text
scripts/
│
├── player/
├── enemy/
├── systems/
├── manager/
├── ui/
└── utils/
```

---

# 五、命名规范（非常重要）

---

# 1. 文件命名

统一：

```text
snake_case
```

例如：

```text
player_controller.gd
enemy_spawner.gd
game_manager.gd
```

---

# 2. 场景命名

统一：

```text
PascalCase
```

例如：

```text
Player.tscn
Enemy.tscn
MainScene.tscn
```

---

# 3. 节点命名

统一：

```text
PascalCase
```

例如：

```text
Player
Camera2D
AnimationPlayer
```

---

# 4. 变量命名

统一：

```gdscript
snake_case
```

例如：

```gdscript
var move_speed = 200
var max_health = 100
```

---

# 5. 常量命名

统一：

```gdscript
UPPER_CASE
```

例如：

```gdscript
const MAX_ENEMY_COUNT = 100
```

---

# 6. 函数命名

统一：

```gdscript
snake_case
```

例如：

```gdscript
func move_player():
func take_damage():
```

---

# 六、脚本规范

---

# 1. 一个脚本只负责一个功能

错误：

```text
Player.gd
同时负责：
移动
攻击
UI
存档
网络
```

正确：

```text
player_move.gd
player_attack.gd
player_health.gd
```

---

# 2. 必须添加中文注释

例如：

```gdscript
# 玩家移动速度
var move_speed = 200

# 玩家受到伤害
func take_damage():
```

---

# 3. 生命周期函数顺序统一

统一：

```gdscript
extends CharacterBody2D

# 常量
const SPEED = 200

# 导出变量
@export var health = 100

# 普通变量
var move_direction = Vector2.ZERO

# 生命周期函数
func _ready():
    pass

func _process(delta):
    pass

func _physics_process(delta):
    pass

# 自定义函数
func move_player():
    pass
```

---

# 七、节点结构规范

---

# Player节点结构

```text
Player
├── Sprite2D
├── CollisionShape2D
├── AnimationPlayer
├── Camera2D
└── AttackPoint
```

---

# Enemy节点结构

```text
Enemy
├── Sprite2D
├── CollisionShape2D
├── AnimationPlayer
└── HurtBox
```

---

# Bullet节点结构

```text
Bullet
├── Sprite2D
├── CollisionShape2D
└── Area2D
```

---

# 八、AI生成代码规范（重点）

---

# AI生成代码必须满足：

## 1. Godot4版本

禁止：

```text
Godot3 API
```

---

# 2. 必须说明：

- 节点结构
- 脚本挂载位置
- 输入映射
- 使用方法

---

# 3. 必须可直接运行

禁止：

```text
省略代码
```

例如：

```text
# 剩余部分自行实现
```

不允许。

---

# 4. 必须增加中文注释

---

# 5. 禁止硬编码路径

错误：

```gdscript
load("res://123.png")
```

正确：

```gdscript
@export var bullet_scene
```

---

# 九、输入系统规范

统一输入名称：

| 功能 | 输入 |
|---|---|
| 上移 | move_up |
| 下移 | move_down |
| 左移 | move_left |
| 右移 | move_right |
| 攻击 | attack |
| 冲刺 | dash |
| 暂停 | pause |

---

# 十、UI规范

---

# UI命名

例如：

```text
HealthBar
ExpBar
PauseMenu
```

---

# UI更新规则

禁止：

```text
每帧更新全部UI
```

正确：

```text
仅数据变化时更新
```

---

# 十一、数据驱动规范

推荐：

```json
{
  "enemy_name": "slime",
  "hp": 100,
  "speed": 80,
  "damage": 10
}
```

禁止：

```gdscript
var slime_hp = 100
```

写死数据。

---

# 十二、Manager管理器规范

---

# 必须存在：

## GameManager

负责：

- 游戏状态
- 时间
- 波次

---

## EnemyManager

负责：

- 刷怪
- 怪物管理

---

## UIManager

负责：

- UI更新

---

# 十三、性能规范

---

# 1. 禁止频繁实例化

错误：

```gdscript
每帧创建子弹
```

正确：

```text
对象池（Object Pool）
```

---

# 2. 禁止_process大量遍历

优先：

```gdscript
Timer
Signal
```

---

# 3. 优先使用信号

例如：

```gdscript
health_changed.emit()
```

---

# 十四、Git规范（非常重要）

---

# 提交规范

格式：

```text
[功能] 添加玩家移动系统
[修复] 修复敌人碰撞问题
[优化] 优化刷怪性能
```

---

# 分支规范

```text
main
develop
feature/player
feature/enemy
```

---

# 十五、AI协作规范（重点）

---

# AI开发流程

## Step1

阅读：

```text
docs/
```

---

## Step2

只开发：

```text
一个模块
```

---

## Step3

输出：

- 节点结构
- GDScript代码
- 配置步骤
- 测试方法

---

# 十六、推荐开发顺序

```text
玩家移动
↓
敌人系统
↓
自动攻击
↓
经验系统
↓
升级系统
↓
UI
↓
Boss
```

---

# 十七、禁止事项（重点）

---

# 禁止：

## 1. 单文件超过1000行

---

## 2. 一个节点挂多个无关功能

---

## 3. AI一次生成整个游戏

---

## 4. 不测试直接合并代码

---

## 5. 不写注释

---

# 十八、项目核心原则

---

# 原则1

先：

```text
能运行
```

再：

```text
优化
```

---

# 原则2

先：

```text
最小可玩版本（MVP）
```

再：

```text
扩展玩法
```

---

# 原则3

AI负责：

```text
代码生成
```

人负责：

```text
架构与调试
```

---

# 十九、最终目标

建立：

```text
可长期维护、
可AI协作、
可多人开发
```

的 Godot4 肉鸽项目。

---