# Bomb Survivors — 代码规范文档

## 一、GDScript 风格规范

### 1.1 命名约定

| 类别 | 约定 | 示例 |
|------|------|------|
| 文件/类名 | `PascalCase` | `GameManager.gd`, `PlayerController.gd` |
| 变量/函数 | `snake_case` | `player_speed`, `_process_input()` |
| 常量 | `UPPER_CASE` | `const MAX_BOMB_RANGE := 10` |
| 枚举 | `PascalCase` | `enum CellType { EMPTY, WALL }` |
| 信号 | `snake_case` | `signal bomb_exploded(cell)` |
| 节点名 | `PascalCase` | `$BombManager`, `$PlayerController` |
| 私有成员 | `_` 前缀 | `_bomb_map`, `_calculate_damage()` |
| 导出变量 | `snake_case` | `@export var start_speed := 5` |
| 类型别名 | `PascalCase` | `class_name BombController` |

### 1.2 文件结构（强制顺序）

每个 `.gd` 文件按以下顺序组织：

```gdscript
# 1. class_name（如果跨文件引用）
class_name CharacterController

# 2. extends
extends Node3D

# 3. 信号声明
signal health_changed(current_hp)
signal died()

# 4. 枚举
enum State { IDLE, MOVING, DYING }

# 5. 常量
const MOVE_SPEED := 5.0

# 6. @export 变量
@export var start_speed := 5

# 7. 公开变量
var current_hp: int = 3

# 8. 私有变量
var _state := State.IDLE
var _stats: CharacterStats = null

# 9. @onready 变量（按初始化顺序）
@onready var _bomb_manager := $BombManager

# 10. 内置回调（按 Godot 生命周期顺序）
func _init():
func _ready():
func _process(delta):
func _physics_process(delta):
func _input(event):
func _unhandled_input(event):

# 11. 公开方法
func take_damage(amount: int, source: String) -> void:
func heal(amount: int) -> void:

# 12. 私有方法
func _update_state() -> void:
func _check_status() -> bool:
```

### 1.3 类型注解

```gdscript
# ✅ 所有函数参数和返回值必须标注类型
func move_player(direction: Vector2i) -> bool

# ✅ 变量声明必须标注类型
var current_cell: Vector2i = Vector2i.ZERO
var players: Array[Dictionary] = []

# ✅ 使用强类型 Dictionary 声明
var stats: Dictionary = {
    "speed": 5,
    "bomb_max": 1
}

# ❌ 禁止无类型
var current_cell     # 禁止
func move_player(d)  # 禁止

# ⚠️ Dictionary 键用字符串，不要用整数
# ✅
stats["speed"] = 5
# ❌
stats[0] = 5
```

---

## 二、SOLID 编码守则

### 2.1 单一职责 — 文件大小限制

| 类别 | 最大行数 |
|------|----------|
| Manager 类 | 300 行 |
| Controller 类 | 250 行 |
| Effect/Item 类 | 100 行 |
| UI 类 | 200 行 |
| Resource 类 | 50 行 |

> 超过上限 = 必须拆分。当前 `game_manager_3d.gd`（1257 行）是反例。

### 2.2 开闭原则 — 如何扩展

```gdscript
# ✅ 新增消耗道具的流程（不改现有代码）：
# 1. 在 scripts/item/consumables/ 下新建 MyNewItem.gd
# 2. 继承 ConsumableItem，实现 on_use()
# 3. 在 ItemFactory 注册权重

# ❌ 禁止：
# 在 GameManager 里加一个巨大的 match/case 来放新道具逻辑
```

### 2.3 依赖反转 — 禁止跨模块直接引用

```gdscript
# ✅ 正确：通过 EventBus 通信
EventBus.bomb_placed.emit(cell, owner_index)
# 在 BombManager 中：
EventBus.bomb_exploded.connect(_on_bomb_exploded)

# ❌ 错误：直接引用其他 Manager
get_parent().get_node("BombManager")._explode_bomb(cell)
```

---

## 三、Godot 实践规范

### 3.1 节点路径

```gdscript
# ✅ 使用 @onready + 相对路径
@onready var _grid_manager := $GridManager
@onready var _bomb_manager := get_node("../BombManager")

# ❌ 禁止硬编码绝对路径
@onready var x = get_node("/root/Game/GridManager")
```

### 3.2 信号使用

```gdscript
# ✅ 信号名用过去式表示事件已完成
signal door_opened()
signal item_picked_up(item_id: String)

# ✅ 使用 Callable 连接，避免字符串
EventBus.item_used.connect(_on_item_used)

# ❌ 避免字符串连接
EventBus.connect("item_used", self, "_on_item_used")  # Godot 3 风格，禁止
```

### 3.3 资源管理

```gdscript
# ✅ 道具用 Resource 而非 Dictionary
var item: BaseItem = preload("res://scripts/item/consumables/wings.tres")

# ❌ 禁止在代码中使用硬编码大字典维护道具数据
var items_db = {
    "wings": {"name": "翅膀", "duration": 8},
    "star":  {"name": "无敌星", "duration": 5}
    # ... 随着道具增多，这个字典会无限膨胀
}
```

### 3.4 Timer 管理

```gdscript
# ✅ 使用 Godot 内置 Timer 节点
var _effect_timer := Timer.new()
_effect_timer.one_shot = true
_effect_timer.wait_time = duration
_effect_timer.timeout.connect(_on_effect_end)
add_child(_effect_timer)
_effect_timer.start()

# ❌ 禁止手动 delta 累加实现计时器（除非极端情况）
var _timer: float = 0.0
func _process(delta):
    _timer += delta
    if _timer >= duration:
        # ... 能加 Timer 节点就别用手动累加
```

### 3.5 内存与引用

```gdscript
# ✅ 使用 is_instance_valid() 检查释放后的节点
if is_instance_valid(bomb_node):
    bomb_node.queue_free()

# ✅ 断开不再需要的信号连接
if effect_timer.timeout.is_connected(_on_effect_end):
    effect_timer.timeout.disconnect(_on_effect_end)

# ❌ 不保留对 queue_free 节点的引用
var dead_node = some_node
dead_node.queue_free()
# 后续不再访问 dead_node
```

---

## 四、项目结构规范

### 4.1 目录结构

```
scripts/
  core/           # 框架级：EventBus, Constants, Helpers
  character/      # 角色系统
  bomb/           # 炸弹系统
  item/           # 道具系统
    consumables/  # 消耗道具（每个道具一个文件）
  terrain/        # 地形系统
  weather/        # 天气系统
  wave/           # 波次/Boss 系统
  grid/           # 网格系统
  ui/             # UI 组件
  editor/         # 编辑器
  menu/           # 主菜单

scenes/
  game/           # 游戏场景
  editor/         # 编辑器场景
  menu/           # 菜单场景

assets/
  art/            # 美术资源
  audio/          # 音效
```

### 4.2 文件命名规则

- 脚本文件 = 类名（PascalCase）→ `PlayerController.gd`
- 场景文件 = 场景名（snake_case）→ `main_3d.tscn`
- 贴图文件 = 描述名（snake_case）→ `floor_tile.png`
- Resource 文件 = 类名 + `.tres` → `character_stats.tres`

### 4.3 每个文件职责清单

```
每个 .gd 文件只能包含：
  1. 一个 class_name（可选）
  2. 一个 extends
  3. 与文件名对应的类的完整实现

禁止：
  1. 一个文件多个 class
  2. 文件内嵌不符合命名的工具类
  3. 超过行数限制的巨型文件
```

---

## 五、Git 与版本控制

### 5.1 提交规范

```
格式: [模块] 描述

示例:
  [core] 创建 EventBus 和 Constants 基础设施
  [item] 实现翅膀道具及其状态效果
  [bomb] 修复炸弹连锁爆炸缺失问题
  [terrain] 新增炮台方块及其AI检测逻辑
  [refactor] 拆分 GameManager 为 GridManager 和 BombManager
```

### 5.2 分支策略

```
main          — 稳定可玩版本
develop       — 开发主线
feature/*     — 功能分支
refactor/*    — 重构分支
fix/*         — Bug 修复
```

---

## 六、代码审查清单

提交 PR/合并前检查：

- [ ] 文件是否超过行数限制？
- [ ] 所有函数参数和返回是否有类型注解？
- [ ] 是否通过 EventBus 而不是直接调用其他 Manager？
- [ ] 是否有硬编码的 magic number 未提取为常量？
- [ ] Timer 是否使用 Timer 节点而非手动 delta 累加？
- [ ] 新增道具是否遵循"新建文件 → 注册 → 不改旧代码"流程？
- [ ] 是否存在 `is_instance_valid` 检查？
- [ ] Dictionary 键是否使用字符串而非整数？
- [ ] 命名是否符合 `snake_case`/`PascalCase`/`UPPER_CASE` 规范？

---

## 七、常见反例对照

| 反模式 | 问题 | 正确做法 |
|--------|------|----------|
| 1257 行单文件 | 违反 SRP，无法测试 | 拆分为 10+ 文件 |
| `match item_type: ...` 放 9 个分支 | 违反 OCP | 每个 Item 一个文件 + 多态 |
| `get_node("../../BombManager")` | 耦合，节点路径脆弱 | EventBus |
| `var t = 0; _process: t += delta` | Timer 不精确，代码冗余 | Timer 节点 |
| `if p["has_wings"] and ...` | 状态用成员变量散落 | StatusEffectManager |
