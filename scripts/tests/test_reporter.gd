class_name TestReporter
extends RefCounted
## 경량 테스트 리포터. Godot 에디터에서 EditorScript로 실행한 결과를 Output 패널에 출력한다.

var _name: String
var _pass := 0
var _fail := 0

func _init(test_name: String) -> void:
	_name = test_name
	print("=== %s 테스트 시작 ===" % _name)

func check(desc: String, actual, expected) -> void:
	if actual == expected:
		_pass += 1
		print("  PASS: %s" % desc)
	else:
		_fail += 1
		printerr("  FAIL: %s (실제: %s, 기대: %s)" % [desc, str(actual), str(expected)])

func report() -> void:
	print("=== %s 결과: %d/%d 통과 ===" % [_name, _pass, _pass + _fail])
	if _fail > 0:
		printerr("!!! %s: %d개 실패 !!!" % [_name, _fail])
