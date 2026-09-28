class_name Eojeol
extends RefCounted
## 문장을 이루는 어절 하나. VERB 역할만 data에 피해/방어 계산용 정보를 담는다.
## data 형식 (VERB일 때): {"stat_type": int, "coefficient": float, "is_defense": bool}

enum Role { SUBJECT, ADVERB, VERB, SYSTEM }

var role: Role
var text: String
var data: Dictionary

func _init(p_role: Role, p_text: String, p_data: Dictionary = {}) -> void:
	role = p_role
	text = p_text
	data = p_data
