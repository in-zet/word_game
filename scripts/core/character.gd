class_name Character
extends Node

var _generated_lines: Array = []
@export var stat: CharacterDataResource

func character_start() -> void:
	# intro mesg print
	pass


func character_dead() -> void:
	# die mesg print
	pass


func _generate_line() -> Array:
	# generate pattern line
	return []


## 패턴 라인 1개를 pop
func pop_line() -> Array:
	if _generated_lines.size() == 0:
		_generated_lines.append(_generate_line())
	return _generated_lines.pop_front()


## 특정 인덱스의 패턴 라인을 탐색
func seek_line(index: int) -> Array:
	while _generated_lines.size() < index:
		_generated_lines.append(_generate_line())
	return _generated_lines[index]


func execute_word():
	pass
