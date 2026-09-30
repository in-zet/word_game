@tool
extends EditorScript

const Combatant = preload("res://scripts/battle/combatant.gd")
const BattleManager = preload("res://scripts/battle/battle_manager.gd")
const PlayerAction = preload("res://scripts/battle/player_action.gd")
const TestReporter = preload("res://scripts/tests/test_reporter.gd")

var _log_lines: Array[String] = []
var _finished := false
var _player_won := false

# 이어진 문장 체인 카운트용 (GDScript 람다는 지역변수를 "값으로" 캡처해서 람다 안에서
# 바꿔도 바깥에 반영되지 않으므로, 위 _log_lines처럼 멤버 변수 + named 메서드로 추적한다).
var _chain_run := 0
var _max_chain_run := 0
var _enemy_sentence_count := 0


func _on_log(text: String) -> void:
	_log_lines.append(text)


func _on_finished(player_won: bool) -> void:
	_finished = true
	_player_won = player_won


func _on_chain_sentence_loaded(side: String, sentence: Sentence) -> void:
	if side != "enemy":
		return
	_enemy_sentence_count += 1
	var starts_with_connective := sentence.eojeols.size() > 0 \
		and sentence.eojeols[0].role == Eojeol.Role.ADVERB \
		and sentence.eojeols[0].text == PatternGenerator.CONNECTIVE_ADVERB_TEXT
	if starts_with_connective:
		_chain_run += 1
		_max_chain_run = max(_max_chain_run, _chain_run)
	else:
		_chain_run = 0


func _run() -> void:
	var t := TestReporter.new("BattleManager headless")

	var player := Combatant.new("플레이어", 100, 12, 10, 100)
	var enemy := Combatant.new("고블린", 100, 8, 6, 100)
	var pattern: PatternDataResource = load("res://resources/data/PatternData/GolbinPattern1.tres")
	var verb: VerbDataResource = load("res://resources/data/VerbData/hit.tres")
	var patterns: Array[PatternDataResource] = [pattern]
	var pattern_weights: Array[int] = [1]
	var verbs: Dictionary = {"hit": verb}

	var battle := BattleManager.new(player, enemy, patterns, pattern_weights, verbs, "dagger", 42)
	battle.log_added.connect(_on_log)
	battle.battle_finished.connect(_on_finished)
	battle.start_battle()

	t.check("시작 직후 phase는 WAIT_INPUT", battle.phase, BattleManager.Phase.WAIT_INPUT)

	# 항상 타격만 선택하며 최대 500턴까지 진행 (무한루프 방지 안전장치)
	var guard := 0
	while not _finished and guard < 500:
		guard += 1
		if player.is_action_ready(PlayerAction.ATTACK_ID):
			battle.submit_player_action(PlayerAction.ATTACK_ID)
		else:
			battle.submit_player_action("")
		battle.advance_turn()

	t.check("500턴 안에 전투 종료", _finished, true)
	t.check("종료 후 phase는 BATTLE_END", battle.phase, BattleManager.Phase.BATTLE_END)
	t.check("승패 중 하나는 HP 0", player.hp <= 0 or enemy.hp <= 0, true)
	t.check("플레이어 hp 음수 아님", player.hp >= 0, true)
	t.check("적 hp 음수 아님", enemy.hp >= 0, true)
	t.check("로그가 최소 1줄 이상 쌓임", _log_lines.size() > 0, true)

	print("--- 전투 로그 (형식 눈으로 확인용) ---")
	for line in _log_lines:
		print(line)
	print("--- 결과: %s ---" % ("플레이어 승리" if _player_won else "플레이어 패배"))

	# 진행 중인(선딜~서술어 사이) 행동에 새로 제출하면 거부되는지 확인
	var p2 := Combatant.new("플레이어2", 100, 12, 10, 100)
	var e2 := Combatant.new("고블린2", 100, 8, 6, 100)
	var battle2 := BattleManager.new(p2, e2, patterns, pattern_weights, verbs, "dagger", 1)
	battle2.start_battle()
	t.check("수비 제출 성공", battle2.submit_player_action(PlayerAction.DEFENSE_ID), true)
	t.check("제출 직후 진행 중 상태", battle2.has_pending_player_action(), true)
	t.check("진행 중에 재제출하면 거부", battle2.submit_player_action(PlayerAction.ATTACK_ID), false)

	# 수비(2어절)는 advance_turn을 두 번 해야 서술어에 도달해 쿨타임(2턴)이 걸린다.
	battle2.advance_turn()
	battle2.advance_turn()
	t.check("서술어까지 진행한 뒤 진행 중 상태 아님", battle2.has_pending_player_action(), false)
	t.check("수비 2어절 진행 후 쿨타임 걸림", p2.is_action_ready(PlayerAction.DEFENSE_ID), false)
	t.check("쿨타임 중 수비 재사용 거부", battle2.submit_player_action(PlayerAction.DEFENSE_ID), false)

	# 이어진 문장 체인 상한(MAX_CONNECTIVE_CHAIN=5) 확인: verbAppearRate=1.0으로 항상 이어지게
	# 만들어서 연속 "또 ..." 문장 개수가 5를 넘지 않는지 센다.
	var always_chain_pattern: PatternDataResource = pattern.duplicate()
	always_chain_pattern.verbAppearRate = 1.0
	var always_chain_patterns: Array[PatternDataResource] = [always_chain_pattern]
	var p3 := Combatant.new("플레이어3", 100000, 1, 1, 100000)
	var e3 := Combatant.new("고블린3", 100000, 8, 6, 100000)
	var battle3 := BattleManager.new(p3, e3, always_chain_patterns, pattern_weights, verbs, "dagger", 7)
	battle3.sentence_loaded.connect(_on_chain_sentence_loaded)
	battle3.start_battle()
	var guard3 := 0
	while _enemy_sentence_count < 60 and guard3 < 2000:
		guard3 += 1
		battle3.submit_player_action("")
		battle3.advance_turn()
	t.check("이어진 문장 체인이 MAX_CONNECTIVE_CHAIN(5)을 넘지 않음", _max_chain_run <= 5, true)
	t.check("이어진 문장이 실제로 여러 번 발생함(체인 상한 테스트가 유의미함)", _max_chain_run > 0, true)

	t.report()
