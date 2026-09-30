class_name BattleManager
extends RefCounted
## 스텝 모드 전투 상태 머신. Node/UI를 모르며 signal로만 결과를 알린다.

signal sentence_loaded(side: String, sentence: Sentence)
signal eojeol_revealed(side: String, index: int, eojeol: Eojeol)
signal log_added(text: String)
signal turn_resolved(turn_no: int)
signal battle_finished(player_won: bool)

enum Phase { BATTLE_START, WAIT_INPUT, BATTLE_END }

const MAX_CONNECTIVE_CHAIN := 5

var player: Combatant
var enemy: Combatant
var enemy_patterns: Array[PatternDataResource]
var enemy_pattern_weights: Array[int]
var enemy_verbs: Dictionary  ## verbID(String) -> VerbDataResource. 패턴마다 basicLineVerbID로 다른 서술어를 쓸 수 있다.
var enemy_weapon_id: String
var rng: RandomNumberGenerator

## 지금 진행 중인 문장(기본+이어진 문장)을 만들어낸 패턴/서술어 — 새 기본 문장을 시작할 때마다
## enemy_patterns 중에서 다시 뽑고, 그 패턴의 basicLineVerbID로 enemy_verbs에서 서술어를 찾는다.
## 이어진 문장도 같은 서술어를 그대로 쓴다.
var _active_pattern: PatternDataResource
var _active_verb: VerbDataResource

var phase: Phase = Phase.BATTLE_START
var turn_no: int = 0

var _enemy_sentence: Sentence
var _player_sentence: Sentence
var _player_action_id: String = ""
var _enemy_damage_accum: int = 0
var _player_damage_accum: int = 0
var _connective_chain: int = 0


## p_patterns/p_pattern_weights는 EnemyData의 possessedPatternID/possessedPatternWeight에 대응한다
## (최소 1개는 있어야 한다). p_verbs는 p_patterns가 쓰는 모든 basicLineVerbID를 커버해야 한다 —
## 커버하지 못하는 패턴이 뽑히면 그 시점에 KeyError로 바로 드러난다(조용히 틀린 서술어를 쓰지 않도록).
func _init(p_player: Combatant, p_enemy: Combatant, p_patterns: Array[PatternDataResource],
		p_pattern_weights: Array[int], p_verbs: Dictionary, p_weapon_id: String, p_seed: int = 0) -> void:
	player = p_player
	enemy = p_enemy
	enemy_patterns = p_patterns
	enemy_pattern_weights = p_pattern_weights
	enemy_verbs = p_verbs
	enemy_weapon_id = p_weapon_id
	rng = RandomNumberGenerator.new()
	rng.seed = p_seed


func start_battle() -> void:
	_load_enemy_sentence(false)
	phase = Phase.WAIT_INPUT


func _load_enemy_sentence(is_connective: bool) -> void:
	if is_connective:
		_enemy_sentence = PatternGenerator.generate_continuation(_active_verb)
	else:
		_connective_chain = 0
		var index := PatternGenerator.pick_weighted_index(enemy_pattern_weights, rng)
		_active_pattern = enemy_patterns[index]
		_active_verb = enemy_verbs[_active_pattern.basicLineVerbID]
		var manner_id := PatternGenerator.roll_manner_adverb(_active_pattern, rng)
		_enemy_sentence = PatternGenerator.generate_base(
			_active_pattern.basicLineSubject, _active_verb, enemy_weapon_id, manner_id)
	sentence_loaded.emit("enemy", _enemy_sentence)


## 플레이어의 진행 중인(선딜~서술어 사이) 문장이 아직 안 끝났으면 true.
## UI는 이 값이 true인 동안 새 행동 선택지를 다시 보여주면 안 된다 — 완료 전까지는
## 적 문장과 동일하게 기존 문장이 계속 진행되며, 새 제출은 무시된다.
func has_pending_player_action() -> bool:
	return _player_sentence != null and not _player_sentence.is_finished()


## 플레이어 행동을 예약한다. action_id가 빈 문자열이면 패스.
## 이미 진행 중인 문장이 있으면 새 제출은 거부(false)한다 — 그 문장은 advance_turn()으로
## 계속 진행시켜야 한다. 쿨타임 중이거나 WAIT_INPUT이 아니어도 false를 반환한다.
func submit_player_action(action_id: String) -> bool:
	if phase != Phase.WAIT_INPUT:
		return false
	if action_id.is_empty():
		if not has_pending_player_action():
			_player_action_id = ""
			_player_sentence = null
		return true
	if has_pending_player_action():
		return false
	if not player.is_action_ready(action_id):
		return false
	var sentence := PlayerAction.build(action_id)
	if sentence == null:
		return false
	_player_action_id = action_id
	_player_sentence = sentence
	sentence_loaded.emit("player", _player_sentence)
	return true


## 한 턴을 진행한다. WAIT_INPUT이 아니면 아무 것도 하지 않는다.
func advance_turn() -> void:
	if phase != Phase.WAIT_INPUT:
		return
	turn_no += 1
	# 이번 턴 시작 시점에 쿨타임을 감소시킨다 (같은 턴에 막 걸린 쿨타임이 바로 줄어드는 것을 방지하려고
	# start_cooldown보다 먼저 실행한다 — 자세한 이유는 Ruling 참고).
	player.tick_cooldowns()
	enemy.tick_cooldowns()

	var enemy_eojeol := _enemy_sentence.advance()
	if enemy_eojeol != null:
		eojeol_revealed.emit("enemy", _enemy_sentence.cursor, enemy_eojeol)

	var player_eojeol: Eojeol = null
	if _player_sentence != null:
		player_eojeol = _player_sentence.advance()
		if player_eojeol != null:
			eojeol_revealed.emit("player", _player_sentence.cursor, player_eojeol)

	_resolve_turn_effects(enemy_eojeol, player_eojeol)
	turn_resolved.emit(turn_no)

	if _check_battle_end():
		return

	if _enemy_sentence.is_finished():
		_finish_enemy_sentence()
	if _player_sentence != null and _player_sentence.is_finished():
		_finish_player_sentence()

	phase = Phase.WAIT_INPUT


func _resolve_turn_effects(enemy_eojeol: Eojeol, player_eojeol: Eojeol) -> void:
	var enemy_defense := 0
	var player_defense := 0
	if enemy_eojeol != null and enemy_eojeol.role == Eojeol.Role.VERB and enemy_eojeol.data.get("is_defense", false):
		enemy_defense = DamageCalc.raw_amount(enemy, enemy_eojeol.data)
	if player_eojeol != null and player_eojeol.role == Eojeol.Role.VERB and player_eojeol.data.get("is_defense", false):
		player_defense = DamageCalc.raw_amount(player, player_eojeol.data)

	if enemy_eojeol != null and enemy_eojeol.role == Eojeol.Role.VERB and not enemy_eojeol.data.get("is_defense", false):
		var raw := DamageCalc.raw_amount(enemy, enemy_eojeol.data)
		var dealt := DamageCalc.apply_defense(raw, player_defense)
		player.take_damage(dealt)
		player.reduce_poise(DamageCalc.poise_loss(dealt, player.max_hp, player.max_poise))
		_enemy_damage_accum += dealt
		var reduced := raw - dealt
		var suffix := (" (%d 데미지 감소)" % reduced) if reduced > 0 else ""
		log_added.emit("%s %d만큼의 피해를 받았다.%s" % [Josa.i_ga(player.display_name), dealt, suffix])

	if player_eojeol != null and player_eojeol.role == Eojeol.Role.VERB and not player_eojeol.data.get("is_defense", false):
		var raw2 := DamageCalc.raw_amount(player, player_eojeol.data)
		var dealt2 := DamageCalc.apply_defense(raw2, enemy_defense)
		enemy.take_damage(dealt2)
		enemy.reduce_poise(DamageCalc.poise_loss(dealt2, enemy.max_hp, enemy.max_poise))
		_player_damage_accum += dealt2
		var reduced2 := raw2 - dealt2
		var suffix2 := (" (%d 데미지 감소)" % reduced2) if reduced2 > 0 else ""
		log_added.emit("%s %d만큼의 피해를 받았다.%s" % [Josa.i_ga(enemy.display_name), dealt2, suffix2])


## 양쪽 다 HP 0이면(동시 사망) 패배로 간주한다 (스펙에 명시되지 않은 엣지케이스에 대한 임의 결정).
func _check_battle_end() -> bool:
	if player.is_alive() and enemy.is_alive():
		return false
	phase = Phase.BATTLE_END
	var player_won := enemy.hp <= 0 and player.hp > 0
	battle_finished.emit(player_won)
	return true


func _finish_enemy_sentence() -> void:
	if _enemy_damage_accum > 0:
		log_added.emit("%s 총 %d만큼의 피해를 줬다." % [Josa.i_ga(enemy.display_name), _enemy_damage_accum])
	_enemy_damage_accum = 0
	if _connective_chain < MAX_CONNECTIVE_CHAIN and PatternGenerator.roll_continuation(_active_pattern, rng):
		_connective_chain += 1
		_load_enemy_sentence(true)
	else:
		_load_enemy_sentence(false)


func _finish_player_sentence() -> void:
	if _player_damage_accum > 0:
		log_added.emit("%s 총 %d만큼의 피해를 받았다." % [Josa.i_ga(enemy.display_name), _player_damage_accum])
	_player_damage_accum = 0
	if not _player_action_id.is_empty():
		player.start_cooldown(_player_action_id, PlayerAction.cooldown_for(_player_action_id))
	_player_action_id = ""
	_player_sentence = null
