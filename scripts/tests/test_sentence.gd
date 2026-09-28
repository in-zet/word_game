@tool
extends EditorScript

const Eojeol = preload("res://scripts/battle/eojeol.gd")
const Sentence = preload("res://scripts/battle/sentence.gd")
const TestReporter = preload("res://scripts/tests/test_reporter.gd")


func _make_sentence() -> Sentence:
	var eojeols: Array[Eojeol] = [
		Eojeol.new(Eojeol.Role.SUBJECT, "고블린이"),
		Eojeol.new(Eojeol.Role.ADVERB, "단검으로"),
		Eojeol.new(Eojeol.Role.VERB, "찌른다."),
	]
	return Sentence.new(eojeols)


func _run() -> void:
	var t := TestReporter.new("Sentence")

	var s := _make_sentence()
	t.check("초기 cursor", s.cursor, -1)
	t.check("초기 is_finished", s.is_finished(), false)
	t.check("revealed 비어있음", s.revealed().size(), 0)

	var e1 := s.advance()
	t.check("첫 advance는 SUBJECT", e1.role, Eojeol.Role.SUBJECT)
	t.check("advance 후 cursor", s.cursor, 0)
	t.check("revealed 1개", s.revealed().size(), 1)

	s.advance()
	var e3 := s.advance()
	t.check("세번째 advance는 VERB", e3.role, Eojeol.Role.VERB)
	t.check("모두 소진 후 is_finished", s.is_finished(), true)
	t.check("더 advance하면 null", s.advance(), null)

	var s2 := _make_sentence()
	s2.advance()
	s2.cancel_rest()
	t.check("cancel 후 is_finished", s2.is_finished(), true)
	t.check("cancel 후 advance는 null", s2.advance(), null)
	t.check("cancel 후 revealed는 취소 전까지만", s2.revealed().size(), 1)

	var s3 := _make_sentence()
	t.check("to_display_text", s3.to_display_text(), "고블린이 단검으로 찌른다.")

	t.report()
