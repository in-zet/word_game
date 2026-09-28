@tool
extends EditorScript

const Combatant = preload("res://scripts/battle/combatant.gd")
const BattleManager = preload("res://scripts/battle/battle_manager.gd")
const PlayerAction = preload("res://scripts/battle/player_action.gd")
const TestReporter = preload("res://scripts/tests/test_reporter.gd")

var _log_lines: Array[String] = []
var _finished := false
var _player_won := false


func _on_log(text: String) -> void:
	_log_lines.append(text)


func _on_finished(player_won: bool) -> void:
	_finished = true
	_player_won = player_won


func _run() -> void:
	var t := TestReporter.new("BattleManager headless")

	var player := Combatant.new("플레이어", 100, 12, 10, 100)
	var enemy := Combatant.new("고블린", 100, 8, 6, 100)
	var pattern: PatternDataResource = load("res://resources/data/PatternData/GolbinPattern1.tres")
	var verb: VerbDataResource = load("res://resources/data/VerbData/hit.tres")

	var battle := BattleManager.new(player, enemy, pattern, verb, "dagger", 42)
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

	# 쿨타임 중인 행동은 거부되는지 별도로 확인
	var p2 := Combatant.new("플레이어2", 100, 12, 10, 100)
	var e2 := Combatant.new("고블린2", 100, 8, 6, 100)
	var battle2 := BattleManager.new(p2, e2, pattern, verb, "dagger", 1)
	battle2.start_battle()
	battle2.submit_player_action(PlayerAction.DEFENSE_ID)
	battle2.advance_turn()
	# 수비 쿨타임은 2턴 -> 아직 안 끝났으면 거부되어야 함
	if not p2.is_action_ready(PlayerAction.DEFENSE_ID):
		t.check("쿨타임 중 수비 재사용 거부", battle2.submit_player_action(PlayerAction.DEFENSE_ID), false)

	t.report()
