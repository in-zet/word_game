class_name Character
extends Node

@export var stat: CharacterDataResource

var _generated_lines: Array = []
var cur_line: Array = []

var line_count: int
var word_offset: int  ## when will the line starts at (index)
var behave_state: BehaveState

func character_start() -> void:
	# intro mesg print
	
	line_count = -1
	pass


func character_dead() -> void:
	# die mesg print
	pass


func _generate_line() -> Array:
	# generate pattern line
	return []


## 패턴 라인 1개를 pop
func next_line() -> void:
	if _generated_lines.size() == 0:
		_generated_lines.append(_generate_line())
	
	cur_line = _generated_lines.pop_front()
	line_count += 1


## 특정 인덱스의 패턴 라인을 탐색
func seek_line(index: int) -> Array:
	while _generated_lines.size() < index:
		_generated_lines.append(_generate_line())
	return _generated_lines[index]


func execute_word(index: int) -> bool:
	if not cur_line or index < word_offset \
	   or index >= cur_line.size() + word_offset:
		return false
	
	var cur_word = cur_line[index - word_offset]
	
	if cur_word is Adverb:
		var cur_adverb := cur_word as Adverb
		
