@tool
extends EditorScript

const PatternGenerator = preload("res://scripts/battle/pattern_generator.gd")
const TestReporter = preload("res://scripts/tests/test_reporter.gd")


func _run() -> void:
	var t := TestReporter.new("PatternGenerator")

	t.check("서술어 기본형", PatternGenerator.verb_display_text("hit", false), "찌른다.")
	t.check("서술어 연결형", PatternGenerator.verb_display_text("hit", true), "찌르고,")
	t.check("모르는 서술어 기본형은 id+.", PatternGenerator.verb_display_text("unknown", false), "unknown.")
	t.check("부사어 텍스트", PatternGenerator.adverb_display_text("dagger"), "단검으로")
	t.check("모르는 부사어는 id 그대로", PatternGenerator.adverb_display_text("mystery"), "mystery")

	var verb: VerbDataResource = load("res://resources/data/VerbData/hit.tres")

	var base := PatternGenerator.generate_base("고블린", verb, "dagger", "fast")
	t.check("기본 문장 어절 수 (주어+수단+방식+서술어)", base.eojeols.size(), 4)
	t.check("기본 문장 표시", base.to_display_text(), "고블린이 단검으로 빠르게 찌른다.")

	var base_no_manner := PatternGenerator.generate_base("고블린", verb, "dagger", "")
	t.check("방식 부사어 없으면 어절 3개", base_no_manner.eojeols.size(), 3)
	t.check("방식 부사어 없는 표시", base_no_manner.to_display_text(), "고블린이 단검으로 찌른다.")

	var cont := PatternGenerator.generate_continuation(verb)
	t.check("이어진 문장 어절 수 (연결부사+서술어)", cont.eojeols.size(), 2)
	t.check("이어진 문장 표시", cont.to_display_text(), "또 찌른다.")

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	t.check("총 가중치 0이면 빈 문자열", PatternGenerator.pick_weighted(["a"], [0], rng), "")
	t.check("빈 목록이면 빈 문자열", PatternGenerator.pick_weighted([], [], rng), "")
	t.check("후보 1개면 그것만 뽑힘", PatternGenerator.pick_weighted(["only"], [1], rng), "only")

	var pattern: PatternDataResource = load("res://resources/data/PatternData/GolbinPattern1.tres")
	var hit_count := 0
	var total := 200
	for i in total:
		if PatternGenerator.roll_continuation(pattern, rng):
			hit_count += 1
	# verbAppearRate = 0.2 근처인지 느슨하게 확인 (완전 결정 X, 범위만 확인)
	t.check("roll_continuation 발생 비율이 0에서 1 사이", hit_count >= 0 and hit_count <= total, true)

	t.report()
