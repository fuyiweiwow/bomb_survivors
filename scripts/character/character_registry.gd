class_name CharacterRegistry
extends RefCounted

var _states: Array[CharacterState] = []
var _ids: Dictionary = {}

func register(state: CharacterState) -> bool:
	if state == null or state.id() < 0 or _ids.has(state.id()):
		return false
	_ids[state.id()] = state
	_states.append(state)
	return true

func unregister_last() -> CharacterState:
	if _states.is_empty():
		return null
	var state := _states.pop_back() as CharacterState
	_ids.erase(state.id())
	return state

func unregister_by_id(character_id: int) -> CharacterState:
	var state := by_id(character_id)
	if state == null:
		return null
	_states.erase(state)
	_ids.erase(character_id)
	return state

func count() -> int:
	return _states.size()

func is_empty() -> bool:
	return _states.is_empty()

func state_at(index: int) -> CharacterState:
	if index < 0 or index >= _states.size():
		return null
	return _states[index]

func by_id(character_id: int) -> CharacterState:
	return _ids.get(character_id) as CharacterState

func states() -> Array[CharacterState]:
	return _states.duplicate()

func data_view() -> Array:
	var result: Array = []
	result.resize(_states.size())
	for index in range(_states.size()):
		result[index] = _states[index].data
	return result
