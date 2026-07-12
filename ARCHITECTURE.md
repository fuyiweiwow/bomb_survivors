# Bomb Survivors — 软件架构文档

## 一、设计原则

本架构严格遵循 SOLID 原则，并结合 Godot 引擎特性进行适配：

| 原则 | Godot 实践方式 |
|------|---------------|
| **S** 单一职责 | 每个脚本只负责一个功能域，God Class 拆分为子系统 |
| **O** 开闭原则 | 通过 Godot Resource 和信号系统扩展新道具/地形/Boss，不修改现有代码 |
| **L** 里氏替换 | 所有道具继承 `BaseItem`，所有地形继承 `BaseTerrain`，可安全替换 |
| **I** 接口隔离 | 使用小的信号接口和虚拟方法，不强迫实现类依赖不需要的接口 |
| **D** 依赖反转 | 高层模块通过 EventBus 和 Manager 接口通信，不直接依赖具体类 |

---

## 二、整体分层架构

```
┌─────────────────────────────────────────────────────────┐
│                     UI Layer                             │
│   HUD / GameOverUI / StatusIndicator / InventoryUI      │
├─────────────────────────────────────────────────────────┤
│                   Game Logic Layer                       │
│   GameManager (orchestrator)                            │
│   ├── CharacterSystem    ├── BombSystem                 │
│   ├── ItemSystem         ├── TerrainSystem              │
│   ├── WeatherSystem      ├── WaveSystem                 │
│   └── StatusEffectSystem                                │
├─────────────────────────────────────────────────────────┤
│                    Data Layer                            │
│   GridManager / MapData / CharacterStats / ItemConfig   │
├─────────────────────────────────────────────────────────┤
│                    Infrastructure                        │
│   EventBus (Autoload) / Constants / Helpers             │
└─────────────────────────────────────────────────────────┘
```

---

## 三、模块详解

### 3.1 基础设施 (Infrastructure)

```
scripts/
  core/
	EventBus.gd              # Autoload 单例，全局信号总线
	Constants.gd              # 所有常量（网格尺寸、时间、枚举）
	Helpers.gd                # 纯工具函数
```

#### EventBus (`scripts/core/EventBus.gd`)
```gdscript
# Godot 的 Autoload 单例，所有跨模块通信通过此总线
signal bomb_exploded(cell: Vector2i, range: int, player_index: int)
signal player_damaged(player_index: int, source: String)
signal player_dying(player_index: int)      # 濒死
signal player_died(player_index: int)
signal player_revived(player_index: int)
signal item_picked_up(player_index: int, item_type: String)
signal item_used(player_index: int, item_type: String)
signal wave_started(wave_number: int, enemy_count: int)
signal boss_spawned(boss_id: String)
signal weather_changed(weather_type: String)
signal wall_self_destruct_started(cell: Vector2i)   # 墙体开始闪烁
signal wall_self_destructed(cell: Vector2i)
signal wall_recovered(cell: Vector2i)
signal game_over(winner_id: int)
```

#### Constants (`scripts/core/Constants.gd`)
```gdscript
# 纯常量定义，无逻辑
enum CellType { EMPTY, WALL, CRATE, FOREST, LAVA, PORTAL_A, PORTAL_B, TURRET, SPRING, ICE, THORN }
enum ItemSlot { SPEED, BOMB, RANGE, SHIELD }  # 属性道具
enum ConsumableType { DETONATOR, GLUE, SHIELD_POTION, STAR, DOLL, BARREL, WINGS, SOCCER, TIANLAO }
enum Weather { CLEAR, RAIN, FOG, WIND, THUNDER, SNOW }
enum GamePhase { PLAYING, DYING, GAME_OVER }

const GRID_W := 15
const GRID_H := 11
const TILE_SIZE := 1.6
const BOMB_FUSE := 2.5
const DYING_TIMEOUT := 5.0         # 濒死倒计时
const WALL_STAY_WARN := 2.0        # 墙体停留闪烁预警
const WALL_STAY_DESTROY := 4.0     # 墙体自毁
const WALL_RECOVER_TIME := 8.0     # 墙体恢复
const MAX_CONSUMABLES := 3          # 背包上限
```

---

### 3.2 角色系统 (CharacterSystem)

```
scripts/character/
  CharacterController.gd       # 基础角色节点（场景树 Node）
  PlayerInputController.gd     # 键盘输入 → 发出移动/炸弹/道具指令信号
  PlayerController.gd          # 目标角色控制器 → 继承 CharacterController
  AIController.gd              # AI 决策 → 继承 CharacterController
  BossController.gd            # Boss 行为 → 继承 AIController
  CharacterStats.gd            # Resource — 纯数据结构，无逻辑
  StatusEffectManager.gd        # 状态效果管理
```

#### 继承体系
```
CharacterController (Node3D)
  ├── PlayerController     (处理 Input → move/bomb/use 指令)
  ├── AIController         (BFS 寻路/炸弹策略)
  │   └── BossController   (技能系统 + 阶段切换)
```

#### CharacterStats (`scripts/character/CharacterStats.gd`)
```gdscript
# Resource — 纯数据，被 CharacterController 组合
class_name CharacterStats extends Resource
@export var speed: int = 5
@export var bomb_max: int = 1
@export var bomb_range: int = 2
@export var bombs_placed: int = 0
@export var shield: int = 0
# 运行时状态（不持久化）
var is_alive: bool = true
var is_dying: bool = false
var dying_timer: float = 0.0
var wall_stay_timer: float = 0.0
var on_wall_cell: Vector2i = Vector2i(-1, -1)
# 属性叠加
var speed_bonus: int = 0
var bomb_bonus: int = 0
var range_bonus: int = 0
```

**SOLID 体现**:
- **S**: 只负责数据，不负责逻辑
- **O**: 新增属性只需加字段，不修改已有代码
- **D**: 被 Controller 组合使用，不是继承

#### StatusEffectManager (`scripts/character/StatusEffectManager.gd`)
```gdscript
# 管理角色身上的临时状态效果
# 使用策略模式：每个效果是一个 Effect 对象
class_name StatusEffectManager extends Node

var active_effects: Dictionary = {}

# 效果标识符
const EFFECT_WINGS := "wings"
const EFFECT_INVINCIBLE := "invincible"
const EFFECT_GLUED := "glued"
const EFFECT_SOCCER := "soccer"

func apply_effect(effect_id: String, duration: float, data: Dictionary = {}) -> void
func remove_effect(effect_id: String) -> void
func has_effect(effect_id: String) -> bool
func is_effect_active(effect_id: String) -> bool
```

**SOLID 体现**:
- **O**: 新增效果只需定义新的 effect_id + 对应逻辑判断，不修改管理器
- **I**: Effect 只通过 ID 字符串交互，不需要实现接口

---

### 3.3 炸弹系统 (BombSystem)

```
scripts/bomb/
  BombManager.gd           # 炸弹生命周期、爆炸协调
  Bomb.gd                  # 单个炸弹节点（fuse 动画 + 爆炸触发）
  Explosion.gd             # 爆炸效果节点
  BombEffect.gd            # 炸弹效果策略基类
  effects/                 # 具体炸弹效果
	NormalBombEffect.gd
	CrossBombEffect.gd     # 天牢
	KickedBombEffect.gd    # 被踢的炸弹
```

#### BombManager (`scripts/bomb/BombManager.gd`)
```gdscript
class_name BombManager extends Node

# 依赖注入: 通过 EventBus 通信，不直接引用 GameManager
var _bomb_map: Dictionary = {}  # cell → Bomb

func place_bomb(cell: Vector2i, owner_index: int, range: int, fuse: float = BOMB_FUSE) -> bool
func kick_bomb(from_cell: Vector2i, direction: Vector2i) -> void
func _explode_bomb(cell: Vector2i) -> void
func _get_explosion_cells(origin: Vector2i, range: int) -> Array[Vector2i]
func is_cell_occupied(cell: Vector2i) -> bool
```

**SOLID 体现**:
- **S**: 只管理炸弹
- **O**: 新增炸弹类型（如天牢炸弹）通过 BombEffect 策略扩展
- **L**: 所有 BombEffect 可互换使用

---

### 3.4 道具系统 (ItemSystem)

```
scripts/item/
  InventoryManager.gd       # 三格背包、选中槽、添加与消费
  ItemManager.gd            # 道具掉落、拾取、使用
  BaseItem.gd               # 道具 Resource 基类
  AttributeItem.gd          # 属性道具（speed/bomb/range/shield）
  ConsumableItem.gd         # 消耗道具基类
  consumables/              # 具体消耗道具
	DetonatorItem.gd
	GlueItem.gd
	ShieldPotionItem.gd
	StarItem.gd
	DollItem.gd
	BarrelItem.gd
	WingsItem.gd
	SoccerItem.gd
	TianlaoItem.gd
  ItemFactory.gd            # 工厂 — 根据权重创建道具
```

#### BaseItem (`scripts/item/BaseItem.gd`)
```gdscript
class_name BaseItem extends Resource

@export var item_name: String
@export var icon: Texture2D
@export var drop_weight: float = 1.0   # 掉落权重

func on_pickup(owner: CharacterController) -> void:
	pass  # 子类覆写

func on_use(owner: CharacterController) -> void:
	pass  # 子类覆写
```

#### ConsumableItem 示例 (`scripts/item/consumables/WingsItem.gd`)
```gdscript
class_name WingsItem extends ConsumableItem

@export var duration: float = 8.0

func on_use(owner: CharacterController) -> void:
	owner.status_effects.apply_effect("wings", duration)
	# 由 StatusEffectManager 在到期时自动清理
```

#### ItemFactory (`scripts/item/ItemFactory.gd`)
```gdscript
class_name ItemFactory

# 基于权重和随机数创建道具
static func roll_item() -> BaseItem:
	var r := randf()
	# ... 权重表
	# 新增道具只需在权重表中加一行
```

**SOLID 体现**:
- **S**: 每个道具一个文件
- **O**: 新增道具 = 新建文件 + 在工厂注册，不改现有代码
- **L**: 所有 ConsumableItem 可替换使用
- **D**: GameManager 通过 `ItemManager` 接口使用道具，不直接 new

---

### 3.5 地形系统 (TerrainSystem)

```
scripts/terrain/
  TerrainManager.gd         # 地形效果处理
  BaseTerrain.gd            # 地形行为基类
  terrains/                 # 具体地形
	PortalTerrain.gd
	TurretTerrain.gd
	SpringTerrain.gd
	IceTerrain.gd
	ThornTerrain.gd
```

#### TerrainManager (`scripts/terrain/TerrainManager.gd`)
```gdscript
class_name TerrainManager extends Node

# 注册所有特殊地形
var _terrain_handlers: Dictionary = {}  # CellType → BaseTerrain

func register_terrain(cell_type: CellType, handler: BaseTerrain) -> void
func on_player_enter(cell: Vector2i, player: CharacterController) -> void
func on_player_exit(cell: Vector2i, player: CharacterController) -> void
func process_terrain(delta: float) -> void  # 炮台等需要 tick 的地形
```

---

### 3.6 天气系统 (WeatherSystem)

```
scripts/weather/
  WeatherManager.gd         # 天气切换、效果应用
  BaseWeather.gd            # 天气效果基类
  weathers/                 # 具体天气
	ClearWeather.gd
	RainWeather.gd
	FogWeather.gd
	WindWeather.gd
	ThunderWeather.gd
	SnowWeather.gd
```

---

### 3.7 波次系统 (WaveSystem)

```
scripts/wave/
  WaveManager.gd            # 波次生成、Boss 触发
  WaveConfig.gd             # Resource — 每波配置
  BaseBossSkill.gd          # Boss 技能基类
  boss_skills/              # 具体 Boss 技能
```

---

### 3.8 网格系统 (GridSystem)

```
scripts/grid/
  GridManager.gd            # 网格数据、动态叠加层、遍历查询
  MapRenderer.gd            # 网格的可视化渲染（从 GridManager 读取）
```

#### GridManager (`scripts/grid/GridManager.gd`)
```gdscript
class_name GridManager extends Node

var _base_grid: Array  # 2D → CellType
var _dynamic_overlays: Dictionary  # cell → Array[Overlay] (胶水等)

func is_walkable(cell: Vector2i, character: CharacterController) -> bool
func get_cell_type(cell: Vector2i) -> int
func set_cell(cell: Vector2i, type: int) -> void
func add_overlay(cell: Vector2i, overlay: OverlayData) -> void
func remove_overlay(cell: Vector2i, overlay_id: String) -> void
```

**SOLID 体现**:
- **S**: 只负责网格数据和查询
- **O**: +Overlay 系统支持动态效果，不用改基础网格

---

### 3.9 UI 系统

```
scripts/ui/
  GameHUD.gd                # 当前 3D 游戏 HUD、状态卡与背包槽
  HUD.gd                    # 状态显示（速度/炸弹/范围/道具）
  GameOverUI.gd             # 结算界面
  StatusIndicator.gd        # 状态效果图标（翅膀/无敌等）
  InventoryUI.gd            # 背包选择条
  DyingTimerUI.gd           # 濒死倒计时
```

---

## 四、数据流架构

```
用户输入 (WASD/Space/E)
	│
	▼
PlayerInputController._unhandled_input()
	│  emit → EventBus.player_moved / EventBus.bomb_placed
	▼
GameManager._process(delta)   ← 协调器，delta 分发给各子系统
	├── WeatherManager.process_weather(delta)
	├── StatusEffectManager.tick_all(delta)
	├── TerrainManager.process_terrain(delta)
	├── BombManager.process_bombs(delta)
	├── WaveManager.check_spawn(delta)
	├── GridManager.check_wall_stay(delta)     ← 墙体停留计时
	└── GameManager.check_dying_state(delta)    ← 濒死倒计时
```

**响应式更新**:

```
BombManager._explode_bomb()
	emit → EventBus.bomb_exploded
		├── GridManager.on_bomb_exploded()     → 破坏箱子/更新网格
		├── TerrainManager.on_bomb_exploded()  → 触发桶爆炸连锁
		├── ItemManager.on_bomb_exploded()     → 掉落道具
		├── CharacterController.on_bomb_exploded() → 检测受击
		└── HUD.on_bomb_exploded()             → 更新 UI
```

---

## 五、节点结构（场景树）

```gdscript
# main_3d.tscn
GameManager (Node3D)
  ├── EnvironmentSetup
  ├── Camera3D
  ├── GridManager
  │   └── MapRenderer (所有地形 Mesh 实例)
  ├── BombManager
  ├── ItemManager
  ├── TerrainManager
  ├── WeatherManager
  ├── WaveManager
  ├── PlayerController
  │   ├── CharacterController (Node3D)
  │   ├── StatusEffectManager
  │   └── CharacterStats (Resource)
  ├── AIController[] (多个 AI)
  │   ├── CharacterController (Node3D)
  │   ├── StatusEffectManager
  │   └── CharacterStats (Resource)
  ├── CanvasLayer (UI)
  │   ├── HUD
  │   ├── InventoryUI
  │   ├── DyingTimerUI
  │   └── GameOverUI
  └── WorldEnvironment
```

---

## 六、依赖关系图

```
				 ┌─────────────┐
				 │  EventBus   │ ← Autoload 单例，全局可见
				 └─────────────┘
					   ▲
					   │ emits/receives
					   │
	┌──────────────────┼──────────────────┐
	│                  │                  │
┌───────┐      ┌──────────┐      ┌───────────┐
│  UI   │      │  Managers│      │Characters │
│ Layer │◄────►│ (Bomb/   │◄────►│(Player/   │
│       │      │  Item/   │      │ AI/Boss)  │
│(HUD)  │      │  Grid/   │      │           │
│(GO UI)│      │  Terrain/│      │ Stats     │
│       │      │  Weather)│      │ Effects   │
└───────┘      └──────────┘      └───────────┘
					  │
				┌─────┴─────┐
				│ Constants │ ← 纯静态数据
				└───────────┘
```

核心原则:
1. **同级 Manager 不直接互相调用** — 都通过 EventBus 通信
2. **Character 不直接访问 Manager** — 通过 EventBus emit 指令
3. **UI 只监听 EventBus** — 不主动调用逻辑
4. **Constants 无依赖** — 可以被任何模块引用

---

## 七、重构步骤（P0 具体计划）

### 当前落地状态

- `game_manager_3d.gd` 只保留场景编排、地图生成、玩家/AI/Boss 和伤害结算。
- `BombManager.gd` 负责炸弹放置、踢动、引爆、火焰表现和爆炸危险格计算。
- `WallMechanics.gd` 负责炸弹上墙、墙体预警、自毁和恢复。
- `ConsumableEffects.gd` 负责主动消耗品、胶水区域、油桶连锁和翅膀落点。
- `InventoryManager.gd`、`PlayerInputController.gd`、`GameHUD.gd` 分别负责背包、输入与 HUD。
- 当前子系统通过注入游戏场景引用共享运行时网格；后续可继续迁移 AI 与角色状态，并收窄为信号接口。

| 步骤 | 操作 | 涉及文件 |
|------|------|----------|
| 1 | 创建 `Constants.gd`，从 `game_manager_3d.gd` 提取所有常量 | 新建 |
| 2 | 创建 `EventBus.gd`，设为 Autoload | 新建 |
| 3 | 创建 `GridManager`，提取网格初始化和查询逻辑 | 新建 + 从 GM 提取 |
| 4 | 创建 `CharacterStats` Resource | 新建 |
| 5 | 创建 `StatusEffectManager` | 新建 |
| 6 | 创建 `CharacterController` + `PlayerController` | 新建 + 从 GM 提取 |
| 7 | 创建 `AIController` | 从 GM 提取 |
| 8 | 创建 `BombManager` + `Bomb` | 从 GM 提取 |
| 9 | 创建 `ItemManager` + `BaseItem` + 属性道具 | 新建 + 从 GM 提取 |
| 10 | 创建 `TerrainManager` + 基础地形 | 从 GM 提取 |
| 11 | 创建 `WeatherManager` | 新建 |
| 12 | 创建 `WaveManager` | 新建 |
| 13 | 提取 UI 到独立文件 | 从 GM 提取 |
| 14 | GameManager 降级为纯协调器 | 改写 |
