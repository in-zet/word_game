class_name Combatant
extends RefCounted
## 전투 참가자의 상태 (HP, 강인도, 스탯, 쿨타임). UI/Node를 모른다.

var display_name: String
var max_hp: int
var hp: int
var max_poise: int
var poise: int
var strength: int
var dexterity: int
var cooldowns: Dictionary = {}  ## action_id(String) -> 남은 턴 수(int)

func _init(p_name: String, p_max_hp: int, p_str: int, p_dex: int, p_max_poise: int) -> void:
	display_name = p_name
	max_hp = p_max_hp
	hp = p_max_hp
	max_poise = p_max_poise
	poise = p_max_poise
	strength = p_str
	dexterity = p_dex

func is_alive() -> bool:
	return hp > 0

func is_broken() -> bool:
	return poise <= 0

func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)

func reduce_poise(amount: int) -> void:
	poise = max(0, poise - amount)

func reset_poise() -> void:
	poise = max_poise

func stat_value(stat_type: int) -> int:
	match stat_type:
		StatType.Value.STR:
			return strength
		StatType.Value.DEX:
			return dexterity
		_:
			return 0

func is_action_ready(action_id: String) -> bool:
	return cooldowns.get(action_id, 0) <= 0

func start_cooldown(action_id: String, turns: int) -> void:
	cooldowns[action_id] = turns

func tick_cooldowns() -> void:
	for key in cooldowns.keys():
		if cooldowns[key] > 0:
			cooldowns[key] -= 1
