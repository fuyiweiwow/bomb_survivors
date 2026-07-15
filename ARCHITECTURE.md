# Bomb Survivors 架构

本文档描述当前已经落地的架构，而不是未来设想。新增功能应优先遵守这里的依赖方向，再按实际需要演进。

## 一、设计目标

- `GameManager3D` 只负责组合系统、保存共享运行时状态和声明每帧执行顺序。
- 每个领域脚本负责一种变化原因，例如移动规则、玩家命令、Boss 技能或道具效果。
- 系统依赖在启动时显式注入，不使用隐藏的全局服务定位器。
- 游戏与编辑器共用网格常量、美术目录和地图编码，避免预览与实战不一致。
- 重构期间保留薄兼容代理，旧调用可逐步迁移到领域公开接口。

## 二、运行时结构

```text
GameManager3D                         共享运行时上下文与帧顺序
├── GameSystemInstaller              组合根，创建领域系统
├── PlayerCommandHandler             玩家命令与背包操作
│   └── PlayerInputController        物理输入采集和输入缓冲
├── ProgressionCoordinator           波次、天气和生成编排
│   ├── WaveManager
│   └── WeatherManager
├── MapState / GridManager           地图领域对象与地形实例
├── GridMovementController           通行、移动开始和连续推进
├── CharacterState                   角色聚合根
│   ├── CharacterEffectState         护盾、状态计时与熔岩暴露
│   ├── CharacterElevationState      浮空、落地、踩踏与承重状态
│   ├── CharacterBombState           炸弹容量、范围、计数与卡位窗口
│   └── CharacterQuery               HUD/AI/决斗使用的类型化只读查询
├── CharacterRegistry                角色集合、唯一 ID 与索引查询
├── GameConfigRepository             玩家配置与 AI 难度持久化、默认值和校验
├── PlayerManager                    角色生成与选点编排
│   ├── CharacterStateFactory        合法角色默认数据构建
│   ├── PlayerVisualFactory          碰撞根与角色 Mesh 构建
│   └── BossCatalog                  Boss 静态档案与共享材质绑定
├── CharacterPresentation            出生、受伤、倒地、复活与死亡表现
├── AIController                     通用 AI 决策和逃生
│   ├── AILavaFlightStrategy
│   └── BossBehaviorController       Boss 策略注册、冷却触发与分派
│       ├── BlastKingSkillStrategy   炸弹压制
│       ├── FrostGiantSkillStrategy  冻结与冲锋
│       └── CloneDemonSkillStrategy  分身生成与自爆
├── CombatRules / CombatManager      纯战斗判定与效果编排
│   └── TerrainEffectProcessor       状态计时与森林/岩浆效果
├── BombManager                      炸弹生命周期和爆炸范围
├── PowerupManager                   掉落物生成与拾取
│   └── PowerupDropTable             完整箱子权重表与可掉落集合
├── ConsumableEffects                主动道具分发与即时效果
│   ├── ItemAreaEffectController     胶水、油桶与持续火区生命周期
│   └── ConsumableActivationPresentation 施放范围与瞬时动画反馈
├── RockAttackController             Rock 地面射击、Rock+Wings 高空投放、命中与表现
├── GameAudioManager                 音效资源映射、并发播放器池与防重叠节流
├── DuelManager                      主地图决斗触发、暂停、恢复与胜负回传
│   ├── DuelArenaCatalog             随机竞技场注册入口
│   ├── LavaRiftArena                首个横版岩浆竞技场
│   └── DuelRoundController / HUD    独立飞行物理、AI、俯冲伤害与显示
│       ├── DuelActorState           决斗临时生命、飞行、道具增益与控制状态
│       └── DuelItemController        决斗背包输入、道具适配、Dummy 与使用反馈
├── WallMechanics                    墙顶/箱顶承重与破坏
├── AirborneController               垂直运动和落点
├── GameUI / GameHUD                 显示与天气可见性
└── MapEditor                        编辑器场景编排与地图预览渲染
	├── MapEditorDocument            编辑、保存与严格版本加载
	├── MapEditorPicker              屏幕射线到逻辑格子的换算
	└── MapEditorToolbar             工具选择、保存与退出信号
```

## 三、目录职责

| 目录 | 职责 |
|------|------|
| `scripts/game` | 组合根、玩家命令、进度编排，不实现具体战斗规则 |
| `scripts/character` | 玩家/AI 状态、移动、浮空、寻路和 Boss 行为 |
| `scripts/combat` | 伤害状态机、down/复活/死亡和胜负判断 |
| `scripts/bomb` | 炸弹与地图掉落物；`powerup_manager.gd` 是保留路径，语义属于道具域 |
| `scripts/item` | 三格背包、消耗品分发、区域效果和状态视觉 |
| `scripts/duel` | 决斗生命周期、竞技场目录、横版回合规则与决斗 HUD |
| `scripts/grid` | 网格数据、地图编解码和地形实例 |
| `scripts/terrain` | 地形美术工厂与动态地形机制 |
| `scripts/weather` | 天气状态和天气规则 |
| `scripts/wave` | 纯波次计时与波次配置 |
| `scripts/ui` | HUD、结果界面和视觉反馈 |
| `scripts/audio` | 全局音效事件映射、音量/音高设置和播放器复用 |
| `scripts/config` | 跨场景用户配置的默认值、校验与 JSON 持久化 |
| `scripts/editor` | 地图/角色编辑器，只调用共享数据与美术模块 |
| `scripts/core` | 无场景状态的常量、网格换算、Mesh 工具和美术目录 |

## 四、核心边界

### 4.1 GameManager3D

允许持有：

- 领域状态：`MapState`、`CharacterRegistry`、炸弹/掉落物/动态地形集合。
- 系统引用：`combat_manager`、`movement_controller` 等。
- 全局局内状态：`game_over`、`next_player_id`、难度。
- `_process()` 中明确可读的系统执行顺序。

不应加入：

- 新道具的具体效果。
- 新 AI/Boss 技能。
- 新移动或伤害判定。
- Mesh/材质创建细节。

文件末尾的 `_try_move_player()`、`is_cell_walkable()` 等是迁移期兼容代理。新代码应直接调用对应领域系统的公开方法。

### 4.2 显式组合根

`GameSystemInstaller` 是普通领域系统的唯一创建入口。系统只在 `setup(game)` 中接收运行时上下文，不在内部创建同级 manager。

具有生命周期编排含义的子系统由协调器创建：

- `PlayerCommandHandler` 创建并拥有 `PlayerInputController`。
- `ProgressionCoordinator` 创建并拥有 `WaveManager`、`WeatherManager`。
- `AIController` 创建并拥有通用 AI 策略和 `BossBehaviorController`；Boss 控制器再注册并拥有各 Boss 的 `BossSkillStrategy`。

### 4.3 领域状态对象

- `MapState` 是地图格子的唯一所有者，负责边界、读写、类型和通行查询；只有 `GridManager`、`MapEditorDocument` 与 `MapDataCodec` 可以访问底层 `cells`。
- `CharacterState` 是单个角色的聚合根，负责生命周期、生命值、移动事务和 AI 计时器，并协调三个内聚子状态。
- `CharacterEffectState` 负责护盾、翅膀、无敌、冰冻、减速和熔岩暴露计时。
- `CharacterElevationState` 负责浮空、垂直速度、单次飞行踩踏集合和墙/箱承重状态。
- `CharacterBombState` 负责炸弹容量、爆炸范围、在场计数和连续放置卡位窗口。
- `CharacterQuery` 包装实时角色数据，只提供类型化读取并对背包集合返回副本；HUD、静态 AI 策略和决斗初始化不得直接读角色字典。
- `CharacterState` 原子维护 Boss 技能间隔与倒计时；具体策略不得直接修改 `skill_timer`。
- `CharacterRegistry` 是局内角色集合的唯一所有者，原子维护顺序索引和唯一 ID 查询，并拒绝重复 ID。
- `CharacterStateFactory` 是默认角色数据结构的唯一构建入口；`PlayerManager` 不拼装领域字典。
- `GameConfigRepository` 是玩家初始属性与 AI 难度的唯一持久化入口；游戏、主菜单和玩家编辑器不得各自解析 JSON。
- `BossCatalog` 是 Boss 静态数值的唯一目录，返回模板副本并在运行时绑定 `GameArtCatalog` 材质。
- `CombatRules` 是无场景状态的纯判定对象，负责伤害路由、攻击高度/格内命中和角色重叠规则。
- `PlayerVisualFactory` 只构造碰撞根和 Mesh，不进入场景树；`PlayerManager` 只负责配置应用、选点和生成编排。
- `CharacterPresentation` 独占角色 Tween、临时战斗特效和死亡节点清理；领域数据不保存动画句柄。
- `GridManager`、`PlayerManager`、`CombatManager` 负责各自跨领域编排，不重复领域规则或角色表现实现。
- `TerrainEffectProcessor` 负责状态倒计时和森林/岩浆 tick；`CombatManager` 只保留兼容代理并接收最终伤害命令。

`grid` 与 `players` 目前只作为迁移期兼容视图。`players` 每次返回从 `CharacterRegistry` 派生的数组快照，修改数组不会改变注册表成员。新代码使用 `character_registry.states()` 取得领域对象，或使用 `queries()` 取得只读查询，不得直接读取或修改兼容视图；地图写入使用 `MapState.set_cell()`，角色写入使用 `CharacterState` 或其子状态方法。例外只有明确的数据所有者：`CharacterStateFactory` 创建初始数据，`InventoryManager` 修改背包槽位。表现 Tween 只能存放在 `CharacterPresentation` 内部，不能写入角色数据。

### 4.4 共享运行时上下文

当前项目使用注入的 `game` 引用访问局内共享状态。这是一个有意保留的显式依赖，而不是全局单例。

规则：

1. manager 可以读取共享集合，但写入应集中在拥有该状态的领域接口。
2. 新代码不要调用其他 manager 的下划线私有方法；先增加一个语义明确的公开方法。
3. manager 不得通过 `get_tree().get_first_node_in_group()` 查找业务依赖。
4. 纯算法保持为 `RefCounted` 或静态函数，避免无意义地进入场景树。

### 4.5 编辑器边界

- `MapEditor` 是场景协调器，只创建环境、渲染地图，并把输入分发给独立组件。
- `MapEditorDocument` 是编辑器地图数据入口，保护边界格，独占保存、加载和不兼容文件清理。
- `MapEditorPicker` 是无场景状态的投影算法，不读取地图内容或 UI。
- `MapEditorToolbar` 只构建工具界面并发出语义信号，不写地图文件或格子数据。
- 编辑器渲染读取 `MapState` 的公开查询；新交互不得绕过 `MapEditorDocument.paint()` 和 `erase()`。

## 五、主要数据流

### 玩家输入

```text
InputEvent
→ PlayerInputController（采集、排序、缓冲）
→ PlayerCommandHandler（解释 bomb/use/select/menu）
→ GridMovementController / BombManager / ConsumableEffects
```

### 连续移动

```text
PlayerCommandHandler 或 AIController
→ GridMovementController.try_move()
→ 通行与天气速度判定
→ GridMovementController._physics_process()
→ 到达子步、同步 grid_pos、拾取道具、决定是否续走
```

通行判断、移动启动和物理推进必须保留在同一控制器中，避免不同调用方出现两套速度或格子规则。
`GridMovementController` 只计算目标与位移，`CharacterState` 通过 begin/sync/complete/cancel 四个原子操作维护移动状态。浮空与墙顶承重通过 `CharacterElevationState` 提交，不能直接组合修改 `airborne`、`grid_pos` 与 `elevated_cell`。

### 波次

```text
WaveManager.wave_started
→ ProgressionCoordinator
→ WeatherManager.start_wave()
→ Boss 箱子刷新与 Boss 生成
→ 普通敌人生成
→ 按实际生成数量更新 next_player_id
```

### 伤害

```text
Bomb / Lava / Thunder / Stomp / Boss Skill
→ CombatManager.damage_player()
→ shield / invincible / boss HP / down / death
→ GameUI 读取状态更新 HUD
```

### 音效

```text
Bomb / Combat / Movement / UI 等领域事件
→ GameAudioManager.play(event_id)
→ 从 16 个 AudioStreamPlayer 中复用空闲播放器
→ 统一应用音量、随机音高和高频事件节流
```

业务系统只发送语义事件 ID，不应直接加载音频文件。素材来源和许可证记录在
`assets/audio/SOURCES.md`。

### 决斗

```text
Duel Token → DuelManager.arm() → 触碰敌人
→ 暂停原 SceneTree（炸弹、AI、天气与背包保持原状态）
→ DuelArenaCatalog 随机创建已注册竞技场
→ DuelRoundController + DuelActorState 独立运行横版移动、岩浆升空、翅膀与俯冲
→ 胜利：恢复原地图并 force_down 敌人
→ 失败：恢复原地图并进入原有失败结算
```

新增决斗地图时实现与 `LavaRiftArena` 相同的公开接口，并在
`DuelArenaCatalog.ARENA_BUILDERS` 注册；`DuelManager` 不应出现地图特例。

## 六、共享数据与美术

- `Constants`：网格尺寸、世界坐标换算、速度曲线、攻击高度。
- `MapState`：地图边界、Cell 数据和通行查询。
- `CharacterState`：角色聚合根；子状态分别维护持续效果、垂直空间和炸弹装备状态。
- `CharacterQuery`：角色聚合的实时只读投影，统一 HUD、AI 决策与决斗入口所需字段。
- `CombatRules`：可独立测试的命中和伤害路由规则。
- `MapDataCodec`：游戏和地图编辑器共用的当前格式编解码与严格版本校验；不迁移旧地图。
- `GameArtCatalog`：游戏和地图编辑器共用的纹理与材质实例定义。
- `GameConfigRepository`：主菜单、玩家编辑器和游戏启动共用的配置默认值、范围约束与文件读写。
- `BossCatalog`：Boss ID、显示名、战斗数值和材质选择目录；调用方只接收副本。
- `PowerupModelFactory`：游戏掉落物与菜单道具图标共用的程序化 3D 模型定义。
- `TerrainArtFactory`：只负责根据材质创建地形表现。
- `MeshHelpers`：基础 Mesh 与材质构造。

任何会影响游戏与编辑器一致性的参数都应进入共享模块，不要在两个场景脚本里复制。

## 七、扩展方式

### 新增消耗道具

1. 在 `Constants.CONSUMABLE_IDS` 注册 ID。
2. 在 `ConsumableEffects.use()` 增加效果实现；复杂效果拆为独立策略。
3. 在 `PowerupManager` 增加模型或显示名。
4. 增加背包拾取、使用和清理测试。

### 新增 Boss

1. 在 `BossCatalog` 注册静态档案与材质映射。
2. 新建继承 `BossSkillStrategy` 的技能策略，并实现稳定的 `boss_id()` 与 `execute()`。
3. 在 `BossBehaviorController.STRATEGY_SCRIPTS` 注册策略脚本。
4. 在 `WaveManager.BOSS_WAVES` 配置波次。

### 新增地形

1. 在 `Constants.Cell` 和地图编码中注册类型。
2. 在 `GridManager` 负责数据和实例创建。
3. 在独立地形机制脚本实现动态行为。
4. 地图编辑器使用同一 Cell ID 与 `GameArtCatalog`。

## 八、测试与约束

- `tests/domain_model_smoke.gd` 独立覆盖配置校验和持久化、Boss 档案隔离与技能计时、决斗临时状态、地图、编辑器文档边界、角色查询实时性与集合隔离、角色聚合、注册表唯一 ID、兼容视图隔离、移动事务、状态计时、浮空落地、炸弹卡位和战斗判定。
- `tests/modular_gameplay_smoke.gd` 覆盖系统组合、Boss 策略注册、输入、移动、AI、背包、天气、爆炸和高度规则。
- `tests/boss_strategy_smoke.gd` 实际触发爆破王炸弹、冰霜冻结、分身生成和分身自爆。
- `tests/boundary_rules_smoke.gd` 独立覆盖三格背包 FIFO/重复道具/选中槽修正、爆炸高度与格子边缘、浮空落点 BFS 和踩踏接触边界。
- `tests/consumable_effects_smoke.gd` 覆盖 3×3 Glue、分级 AI 认知、全图雷管、Wings 单独飞行、Rock 地面射击、Rock+Wings 高空投放、足球鞋踢弹、9×9 油火连锁/持续伤害、9×9 Prison 群控、可见动画节点和决斗进攻系数。
- `tests/scene_load_smoke.gd` 验证地图编辑器组件组合以及地图元素与游戏逻辑格尺寸一致。
- 架构重构必须先保持 smoke 行为不变，再增加边界初始化和唯一 ID 测试。
- 新增脚本必须能被 Godot editor 全量扫描，并提交对应 `.gd.uid`。
- `project.godot` 的用户本地窗口设置不应混入功能提交。

## 九、后续技术债

按收益优先级继续处理：

1. 将仍直接读写角色兼容字典的运行时调用迁移到 `CharacterState` 命令或 `CharacterQuery`，再逐步缩小 `players` 兼容视图。

不要一次性替换角色字典为 Resource；应先建立类型化适配器和当前格式编解码测试，再按领域逐步迁移。
