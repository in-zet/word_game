@tool
extends EditorScript

const PlayerAction = preload("res://scripts/battle/player_action.gd")
const TestReporter = preload("res://scripts/tests/test_reporter.gd")


func _run() -> void:
	var t := TestReporter.new("PlayerAction")

	var attack := PlayerAction.build(PlayerAction.ATTACK_ID)
	t.check("타격 문장 어절 수", attack.eojeols.size(), 2)
	t.check("타격 문장 표시", attack.to_display_text(), "주먹으로 때렸다.")
	t.check("타격 서술어는 STR 기반", attack.eojeols[1].data.get("stat_type"), StatType.Value.STR)
	t.check("타격은 공격(방어 아님)", attack.eojeols[1].data.get("is_defense"), false)

	var defense := PlayerAction.build(PlayerAction.DEFENSE_ID)
	t.check("수비 문장 어절 수", defense.eojeols.size(), 2)
	t.check("수비 문장 표시", defense.to_display_text(), "방패로 막았다.")
	t.check("수비 서술어는 DEX 기반", defense.eojeols[1].data.get("stat_type"), StatType.Value.DEX)
	t.check("수비는 방어", defense.eojeols[1].data.get("is_defense"), true)

	t.check("모르는 id는 null", PlayerAction.build("unknown"), null)

	t.check("타격 쿨타임", PlayerAction.cooldown_for(PlayerAction.ATTACK_ID), 1)
	t.check("수비 쿨타임", PlayerAction.cooldown_for(PlayerAction.DEFENSE_ID), 2)
	t.check("모르는 id 쿨타임 0", PlayerAction.cooldown_for("unknown"), 0)

	t.report()
