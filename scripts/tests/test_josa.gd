@tool
extends EditorScript

const Josa = preload("res://scripts/core/josa.gd")
const TestReporter = preload("res://scripts/tests/test_reporter.gd")


func _run() -> void:
	var t := TestReporter.new("Josa")
	t.check("받침 있음: 고블린", Josa.has_batchim("고블린"), true)
	t.check("받침 없음: 고블", Josa.has_batchim("고블"), false)
	t.check("빈 문자열", Josa.has_batchim(""), false)
	t.check("이/가 받침 있음", Josa.i_ga("고블린"), "고블린이")
	t.check("이/가 받침 없음", Josa.i_ga("고블"), "고블가")
	t.check("은/는 받침 있음", Josa.eun_neun("고블린"), "고블린은")
	t.check("은/는 받침 없음", Josa.eun_neun("고블"), "고블는")
	t.check("으로/로 받침 없음", Josa.euro_ro("칼"), "칼로")
	t.check("으로/로 받침 있음(ㄹ 아님)", Josa.euro_ro("단검"), "단검으로")
	t.check("으로/로 받침 있음(ㄹ)", Josa.euro_ro("칼날"), "칼날로")
	t.check("와/과 받침 있음", Josa.wa_gwa("독"), "독과")
	t.check("와/과 받침 없음", Josa.wa_gwa("화염"), "화염와")
	t.report()
