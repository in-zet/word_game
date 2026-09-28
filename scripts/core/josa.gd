class_name Josa
extends RefCounted
## 받침 여부에 따라 조사를 선택하는 유틸리티.

## 문자열 마지막 글자에 받침이 있는지 판정한다. 한글 음절(가~힣)이 아니거나 빈 문자열이면 false.
static func has_batchim(word: String) -> bool:
	if word.is_empty():
		return false
	var last_char := word.substr(word.length() - 1, 1)
	var code := last_char.unicode_at(0)
	if code < 0xAC00 or code > 0xD7A3:
		return false
	return (code - 0xAC00) % 28 != 0


static func i_ga(word: String) -> String:
	return word + ("이" if has_batchim(word) else "가")


static func eun_neun(word: String) -> String:
	return word + ("은" if has_batchim(word) else "는")


## 받침이 있고 그 받침이 'ㄹ'이면 "로", 그 외 받침 있으면 "으로", 받침 없으면 "로".
static func euro_ro(word: String) -> String:
	if not has_batchim(word):
		return word + "로"
	var last_char := word.substr(word.length() - 1, 1)
	var code := last_char.unicode_at(0)
	var jong := (code - 0xAC00) % 28
	if jong == 8:  # 종성 'ㄹ'
		return word + "로"
	return word + "으로"


static func wa_gwa(word: String) -> String:
	return word + ("과" if has_batchim(word) else "와")
