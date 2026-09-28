class_name Sentence
extends RefCounted
## 어절 배열과 진행 커서. 한 번에 어절 하나씩 advance()로 공개(해소)한다.

var eojeols: Array[Eojeol] = []
var cursor: int = -1
var cancelled: bool = false

func _init(p_eojeols: Array[Eojeol]) -> void:
	eojeols = p_eojeols

## 다음 어절을 공개하고 반환한다. 더 없거나 취소됐으면 null.
func advance() -> Eojeol:
	if cancelled:
		return null
	if cursor + 1 >= eojeols.size():
		return null
	cursor += 1
	return eojeols[cursor]

## 지금까지 공개된 어절 목록.
func revealed() -> Array[Eojeol]:
	var out: Array[Eojeol] = []
	for i in range(min(cursor + 1, eojeols.size())):
		out.append(eojeols[i])
	return out

func is_finished() -> bool:
	return cancelled or cursor + 1 >= eojeols.size()

func cancel_rest() -> void:
	cancelled = true

## 공개 여부와 상관없이 전체 문장을 하나의 문자열로 합친다 (미리보기 표시용).
func to_display_text() -> String:
	var parts: Array[String] = []
	for e in eojeols:
		parts.append(e.text)
	return " ".join(parts)
