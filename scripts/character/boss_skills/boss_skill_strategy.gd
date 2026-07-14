class_name BossSkillStrategy
extends Node

var _game: Node

func setup(game: Node) -> void:
	_game = game

func boss_id() -> String:
	return ""

func execute(_player_index: int, _state: CharacterState) -> void:
	push_error("BossSkillStrategy.execute() must be implemented")
