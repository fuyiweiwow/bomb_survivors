class_name BossBehaviorController
extends Node

const STRATEGY_SCRIPTS := [
	preload("res://scripts/character/boss_skills/blast_king_skill_strategy.gd"),
	preload("res://scripts/character/boss_skills/frost_giant_skill_strategy.gd"),
	preload("res://scripts/character/boss_skills/clone_demon_skill_strategy.gd"),
]

var _game: Node
var _strategies: Dictionary = {}
var _clone_strategy: CloneDemonSkillStrategy

func setup(game: Node) -> void:
	_game = game
	for strategy_script in STRATEGY_SCRIPTS:
		register_strategy(strategy_script.new() as BossSkillStrategy)

func register_strategy(strategy: BossSkillStrategy) -> bool:
	if strategy == null or strategy.boss_id().is_empty() or _strategies.has(strategy.boss_id()):
		return false
	_strategies[strategy.boss_id()] = strategy
	add_child(strategy)
	strategy.setup(_game)
	if strategy is CloneDemonSkillStrategy:
		_clone_strategy = strategy as CloneDemonSkillStrategy
	return true

func strategy_for(boss_id: String) -> BossSkillStrategy:
	return _strategies.get(boss_id) as BossSkillStrategy

func strategy_ids() -> Array[String]:
	var result: Array[String] = []
	for strategy_id in _strategies.keys():
		result.append(str(strategy_id))
	return result

func process_skill(player_index: int, delta: float) -> void:
	var state := _game.character_registry.state_at(player_index) as CharacterState
	if state == null:
		return
	var strategy := strategy_for(state.boss_id())
	if strategy == null or not state.advance_boss_skill_timer(delta):
		return
	state.reset_boss_skill_timer()
	strategy.execute(player_index, state)

func explode_clone_minion(player_index: int) -> void:
	if _clone_strategy != null:
		_clone_strategy.explode_minion(player_index)
