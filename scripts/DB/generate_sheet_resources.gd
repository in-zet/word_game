@tool
extends EditorScript
## CACHE_PATH (editor_fetch_sheet_data.gd로 미리 받아둔 캐시)을 읽어서,
## 시트마다 타입 지정된 Resource 클래스(.gd) 하나와, 행(row)마다 개별 .tres 파일을 생성합니다.
## 파일명은 각 행의 "id" 필드 값 (없으면 첫 번째 컬럼 값)을 사용합니다.
##
## 사용법:
## 1. 먼저 editor_fetch_sheet_data.gd 를 실행해서 캐시(JSON)를 만들어 둡니다.
## 2. 이 스크립트를 열고 파일(File) > 실행(Run) (Ctrl+Shift+X) 을 누릅니다.
## 3. RESOURCE_CLASS_DIR 에 <시트명>Resource.gd 가 생성되고
##    DATA_DIR/<시트명>/<id>.tres 로 행마다 개별 파일이 생성됩니다.
##
## 생성된 클래스는 곧바로 다음처럼 사용할 수 있습니다:
##   var enemy: EnemyDataResource = load("res://resources/data/EnemyData/Goblin.tres")
##   print(enemy.enemyID, enemy.healthPoint)
##
## Enum 지원:
## - "Enum<값1,값2,값3>" (예: Enum<Fire,Water,Wind>) → 값 목록으로 새 enum 생성, 이름은 필드명 기반 자동 생성.
## - "Enum<이름:값1,값2,값3>" (예: Enum<AdverbType:Fire,Water,Wind>) → 이름을 직접 지정.
##   접미사가 붙지 않고 지정한 이름 그대로 파일명이 됩니다 (AdverbType.gd, AdverbTypeEnum.gd 아님).
## - "Enum<이름>" 처럼 쉼표 없이 이름만 있으면 → 값 목록이 아니라 "이름 참조"로 해석됩니다.
##   즉 res://scripts/enums/<이름>.gd 가 이미 있어야 하고, 그 파일의 enum Value 멤버를 그대로 씁니다.
##   (파일이 없으면 값 목록이 없어 생성할 수 없으므로 경고를 남기고 NONE 하나짜리로 대체합니다.)
##
## 이미 만들어둔(직접 작성했거나 이전에 생성된) enum 파일이
## res://scripts/enums/<이름>.gd 에 있으면, 어떤 표기를 쓰든 그 파일을 덮어쓰지 않고
## 그대로 읽어서 사용합니다.
## 시트의 실제 셀 값은 "Fire" 처럼 이름 그대로 적으면 됩니다 (대소문자 무관 매칭).

const CACHE_PATH := "res://scripts/DB/sheet_data_cache.json"
const RESOURCE_CLASS_DIR := "res://scripts/custom_resources/"
const ENUM_DIR := "res://scripts/enums/"
const DATA_DIR := "res://resources/data/"

## 이번 실행에서 생성/재사용한 enum들을 추적합니다. { enum_name: { "members": Array } }
var _enum_registry: Dictionary = {}

## GDScript 예약어와 충돌하지 않도록 걸러낼 목록 (필요한 만큼만).
const RESERVED_WORDS := [
	"if", "elif", "else", "for", "while", "match", "break", "continue", "pass",
	"return", "class", "class_name", "extends", "is", "in", "as", "self",
	"signal", "func", "static", "const", "enum", "var", "onready", "export",
	"tool", "preload", "yield", "assert", "void", "and", "or", "not",
	"true", "false", "null", "PI", "TAU", "INF", "NAN",
]


func _run() -> void:
	print("=== 커스텀 리소스 자동 생성 시작 ===")
	_enum_registry.clear()

	if not FileAccess.file_exists(CACHE_PATH):
		printerr("생성 실패: 캐시 파일이 없습니다 (%s). editor_fetch_sheet_data.gd 를 먼저 실행하세요." % CACHE_PATH)
		return

	var file := FileAccess.open(CACHE_PATH, FileAccess.READ)
	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_string) != OK:
		printerr("생성 실패: 캐시 JSON 파싱 오류 - %s" % json.get_error_message())
		return

	var parsed: Variant = json.get_data()
	if typeof(parsed) != TYPE_DICTIONARY:
		printerr("생성 실패: 최상위 JSON이 Dictionary가 아닙니다.")
		return

	_ensure_dir(RESOURCE_CLASS_DIR)
	_ensure_dir(ENUM_DIR)
	_ensure_dir(DATA_DIR)

	var sheets: Dictionary = parsed
	for sheet_name in sheets.keys():
		_process_sheet(String(sheet_name), sheets[sheet_name])

	print("=== 전체 완료 ===")
	print("생성된 클래스: %s" % RESOURCE_CLASS_DIR)
	print("생성된 데이터: %s" % DATA_DIR)
	print("에디터 상단 메뉴 '프로젝트 > 다시 불러오기' 또는 잠시 후에 새 클래스의 class_name 자동완성이 잡힙니다.")


func _process_sheet(sheet_name: String, sheet_obj: Variant) -> void:
	if typeof(sheet_obj) != TYPE_DICTIONARY:
		printerr("건너뜀: '%s' 시트 형식이 이상합니다." % sheet_name)
		return

	var type_dict: Dictionary = sheet_obj.get("type", {})
	var comment_dict: Dictionary = sheet_obj.get("comment", {})
	var data_rows: Array = sheet_obj.get("data", [])

	if type_dict.is_empty():
		printerr("건너뜀: '%s' 시트에 type 정보가 없습니다." % sheet_name)
		return

	var base_name := _sanitize_class_base(sheet_name)
	var resource_class_name := base_name + "Resource"
	var resource_path := RESOURCE_CLASS_DIR + resource_class_name + ".gd"
	var sheet_data_dir := DATA_DIR + base_name + "/"

	# --- 필드 목록 구성 (원본 헤더 -> {field_name, gd_type, default_literal, is_array, elem_kind}) ---
	var fields: Array = []
	var index := 0
	for header in type_dict.keys():
		var header_str := String(header)
		if header_str.is_empty():
			continue
		var field_name := _sanitize_identifier(header_str, "field", index)
		var type_str := String(type_dict[header])
		var field_info := _build_field_info(header_str, field_name, type_str)
		field_info["comment"] = String(comment_dict.get(header, ""))
		fields.append(field_info)
		index += 1

	if fields.is_empty():
		printerr("건너뜀: '%s' 시트에 유효한 컬럼이 없습니다." % sheet_name)
		return

	# --- 파일명으로 쓸 id 필드 결정: "id"(대소문자 무관) 우선, 없으면 첫 번째 컬럼 ---
	var id_field: Dictionary = fields[0]
	for field in fields:
		if String(field.original_header).to_lower() == "id":
			id_field = field
			break

	# --- Resource 클래스 파일 생성 ---
	var resource_script_text := _build_resource_script_text(resource_class_name, fields)
	_write_file(resource_path, resource_script_text)

	var resource_script: GDScript = load(resource_path)
	if resource_script == null:
		printerr("실패: '%s' 생성된 스크립트를 로드하지 못했습니다." % sheet_name)
		return

	_ensure_dir(sheet_data_dir)

	# --- 행마다 개별 .tres 저장 ---
	var saved_count := 0
	var used_filenames: Dictionary = {}

	for row in data_rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue

		var row_dict: Dictionary = row
		var row_instance: Resource = resource_script.new()
		for field in fields:
			var raw_value: Variant = row_dict.get(field.original_header, null)
			row_instance.set(field.field_name, _coerce_value(raw_value, field))

		var id_raw: Variant = row_dict.get(id_field.original_header, null)
		var id_value: Variant = _coerce_single_by_field(id_raw, id_field)
		var filename := _sanitize_filename(str(id_value))

		if filename.is_empty():
			printerr("경고: '%s' 시트에 id 값이 비어있는 행이 있어 건너뜁니다." % sheet_name)
			continue
		if used_filenames.has(filename):
			printerr("경고: '%s' 시트에 id '%s' 가 중복됩니다. 이전 파일을 덮어씁니다." % [sheet_name, filename])
		used_filenames[filename] = true

		var tres_path := sheet_data_dir + filename + ".tres"
		var save_err := ResourceSaver.save(row_instance, tres_path)
		if save_err != OK:
			printerr("실패: %s 저장 오류 (code: %d)" % [tres_path, save_err])
			continue
		saved_count += 1

	print("완료: %s -> %s (%d개 파일), 클래스: %s (id 필드: %s)" % [sheet_name, sheet_data_dir, saved_count, resource_class_name, id_field.original_header])


## ---------- 타입 매핑 ----------

func _build_field_info(original_header: String, field_name: String, type_str: String) -> Dictionary:
	var is_array := false
	var elem_type_str := type_str

	if original_header.begins_with("arr_"):
		# Apps Script 쪽에서 arrN_ 컬럼들을 arr_<name> 하나로 이미 묶어줬고,
		# 이때 type 값은 '요소 타입'이 저장되어 있습니다.
		is_array = true
	else:
		var list_match := RegEx.create_from_string("(?i)^List<\\s*(.+?)\\s*>$").search(type_str)
		if list_match:
			is_array = true
			elem_type_str = list_match.get_string(1)

	# --- enum 타입 감지: Enum<값1,값2,값3> / Enum<이름:값1,값2,값3> / Enum<이름>(참조 전용) ---
	var enum_match := RegEx.create_from_string("(?i)^Enum<\\s*(?:([A-Za-z_][A-Za-z0-9_]*)\\s*:)?\\s*(.+?)\\s*>$").search(elem_type_str)
	if enum_match:
		var explicit_name := enum_match.get_string(1)
		var content := enum_match.get_string(2)
		if explicit_name.is_empty() and content.find(",") == -1:
			# 콤마 없는 단일 토큰: 값 목록이 아니라 "이름"으로 해석합니다.
			# 예: Enum<StatType> -> StatType.gd 를 참조 (값 없이 이름만 지정한 경우)
			explicit_name = content
			content = ""
		return _build_enum_field_info(original_header, field_name, explicit_name, content, is_array)

	var elem_map := _map_scalar_type(elem_type_str)

	var gd_type: String
	var default_literal: String
	if is_array:
		gd_type = "Array[%s]" % elem_map.gd_type if elem_map.gd_type != "Variant" else "Array"
		default_literal = "[]"
	else:
		gd_type = elem_map.gd_type
		default_literal = elem_map.default_literal

	return {
		"original_header": original_header,
		"field_name": field_name,
		"gd_type": gd_type,
		"default_literal": default_literal,
		"is_array": is_array,
		"is_enum": false,
		"elem_kind": elem_map.kind,  # "int" | "float" | "bool" | "string" | "variant"
	}


## Enum<A,B,C> / Enum<이름:A,B,C> / Enum<이름>(참조 전용) 을 파싱해서 enum 정보를 구성합니다.
##
## 우선순위:
## 1. 이번 실행에서 이미 등록된 enum이면 그대로 재사용합니다.
## 2. ENUM_DIR/<이름>.gd 에 이미 파일이 있으면 (직접 만들었거나 이전에 생성된 것)
##    그 파일을 덮어쓰지 않고, 그 안의 enum Value 멤버를 그대로 읽어서 사용합니다.
## 3. 파일이 없고 시트에 값 목록이 있으면 그 값으로 새로 생성합니다.
## 4. 파일도 없고 값 목록도 없으면(Enum<이름>만 쓴 경우) 에러를 남기고 NONE 하나짜리로 대체합니다.
func _build_enum_field_info(original_header: String, field_name: String, explicit_name: String, raw_member_list: String, is_array: bool) -> Dictionary:
	var enum_name: String
	if not explicit_name.is_empty():
		# 이름을 직접 지정한 경우: 접미사를 붙이지 않고 그대로 사용합니다.
		# 예: Enum<AdverbType:...> -> AdverbType.gd 를 찾습니다 (AdverbTypeEnum.gd 아님).
		enum_name = _sanitize_class_base(explicit_name)
	else:
		# 이름을 생략한 경우: 필드명 기반으로 자동 생성하며 "Enum" 접미사를 붙입니다.
		enum_name = _build_enum_name(field_name)
	enum_name = _avoid_engine_class_collision(enum_name)
	var sheet_members := _parse_enum_members(raw_member_list)

	var members: Array
	if _enum_registry.has(enum_name):
		var entry: Dictionary = _enum_registry[enum_name]
		members = entry.members
		if entry.source == "generated" and not _members_match(members, sheet_members):
			printerr("경고: enum '%s' 이(가) 서로 다른 값 목록으로 여러 번 정의되었습니다. 처음 정의를 그대로 사용합니다." % enum_name)
	else:
		var existing_members := _try_load_existing_enum(enum_name)
		if not existing_members.is_empty():
			members = existing_members
			_enum_registry[enum_name] = {"members": members, "source": "existing"}
			print("enum '%s': 기존 파일을 그대로 사용합니다 (%s, 덮어쓰지 않음)" % [enum_name, _enum_file_path(enum_name)])
		elif raw_member_list.is_empty():
			# 이름만 참조했는데(Enum<이름>) 파일도 없고 값 목록도 없는 경우.
			# 값이 없으니 NONE 하나짜리 플레이스홀더 파일을 만들어서 최소한 preload가 깨지지 않게 합니다.
			printerr("실패: enum '%s' 참조를 찾을 수 없습니다 (%s 없음), 시트에도 값 목록이 없습니다. %s 를 열어 실제 값을 채워주세요 (지금은 NONE 하나짜리 플레이스홀더로 생성됩니다)." % [enum_name, _enum_file_path(enum_name), _enum_file_path(enum_name)])
			members = sheet_members  # ["NONE"] 플레이스홀더
			_write_enum_file(enum_name, members)
			_enum_registry[enum_name] = {"members": members, "source": "generated"}
		else:
			members = sheet_members
			_write_enum_file(enum_name, members)
			_enum_registry[enum_name] = {"members": members, "source": "generated"}

	var gd_type: String
	var default_literal: String
	if is_array:
		gd_type = "Array[%s.Value]" % enum_name
		default_literal = "[]"
	else:
		gd_type = "%s.Value" % enum_name
		default_literal = "%s.Value.%s" % [enum_name, members[0].symbol]

	return {
		"original_header": original_header,
		"field_name": field_name,
		"gd_type": gd_type,
		"default_literal": default_literal,
		"is_array": is_array,
		"is_enum": true,
		"enum_name": enum_name,
		"enum_members": members,
		"elem_kind": "enum",
	}


## 두 enum 값 목록이 (순서 포함) 동일한지 비교합니다.
func _members_match(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if String(a[i].original).strip_edges().to_lower() != String(b[i].original).strip_edges().to_lower():
			return false
	return true


## "Fire,Water,Wind" 같은 문자열을 {original, symbol} 배열로 파싱합니다.
func _parse_enum_members(raw_member_list: String) -> Array:
	var members: Array = []
	var m_index := 0
	for raw_member in raw_member_list.split(","):
		var original_member := String(raw_member).strip_edges()
		if original_member.is_empty():
			continue
		members.append({"original": original_member, "symbol": _sanitize_enum_member(original_member, m_index)})
		m_index += 1
	if members.is_empty():
		members.append({"original": "NONE", "symbol": "NONE"})
	return members


## ENUM_DIR/<enum_name>.gd 파일이 이미 있으면 그 안의 "enum Value { ... }"
## 멤버 목록을 읽어서 반환합니다. 파일이 없거나 enum Value 블록을 못 찾으면 빈 배열을 반환합니다.
## 시트에는 이 이름만 지정하면 되고(Enum<이름:...>), 파일 안의 실제 멤버가 우선 사용됩니다.
func _try_load_existing_enum(enum_name: String) -> Array:
	var path := _enum_file_path(enum_name)
	if not FileAccess.file_exists(path):
		return []

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var text := file.get_as_text()
	file.close()

	var re := RegEx.create_from_string("enum\\s+Value\\s*\\{([^}]*)\\}")
	var m := re.search(text)
	if not m:
		printerr("경고: %s 에 'enum Value {...}' 블록을 찾지 못해 새로 생성합니다." % path)
		return []

	var members: Array = []
	for raw in m.get_string(1).split(","):
		# 줄 주석(#...) 제거 후 다듬기
		var symbol := raw.split("#")[0].strip_edges()
		if symbol.is_empty():
			continue
		members.append({"original": symbol, "symbol": symbol})

	return members


## enum을 ENUM_DIR 아래에 snake_case 파일명(_enum_file_path 참고)으로 저장합니다.
## (이미 파일이 있는 enum은 _try_load_existing_enum 에서 걸러져서 이 함수까지 오지 않습니다.)
func _write_enum_file(enum_name: String, members: Array) -> void:
	var lines: Array[String] = []
	lines.append("class_name %s" % enum_name)
	lines.append("extends RefCounted")
	lines.append("## 자동 생성된 enum 파일입니다. 여러 시트/필드에서 공유해서 재사용할 수 있습니다.")
	lines.append("## Google Sheets 구조가 바뀌면 생성 스크립트를 다시 실행해서 갱신하세요.")
	lines.append("")
	lines.append("enum Value {")
	for member in members:
		lines.append("\t%s," % member.symbol)
	lines.append("}")

	_write_file(_enum_file_path(enum_name), "\n".join(lines))


## enum_name(PascalCase, 예: "AdverbType")에 대응하는 실제 파일 경로를 반환합니다.
## 파일명은 snake_case(예: "adverb_type.gd")를 사용합니다 - 기존에 직접 작성해둔
## enum 파일들이 snake_case 이름을 쓰고 있기 때문입니다. class_name 및 코드 내
## 타입 참조(AdverbType.Value 등)는 계속 PascalCase(enum_name)를 그대로 씁니다.
func _enum_file_path(enum_name: String) -> String:
	return ENUM_DIR + _pascal_to_snake_case(enum_name) + ".gd"


## "AdverbType" -> "adverb_type", "HP" -> "hp", "statBonusType" -> "stat_bonus_type"
## 처럼 PascalCase/camelCase 이름을 snake_case로 변환합니다.
func _pascal_to_snake_case(name: String) -> String:
	var out := ""
	for i in name.length():
		var c := name[i]
		var is_upper := c.to_upper() == c and c.to_lower() != c
		if is_upper:
			var prev_is_lower_or_digit := i > 0 and name[i - 1] != "_" and name[i - 1].to_upper() != name[i - 1]
			var next_is_lower := i + 1 < name.length() and name[i + 1].to_upper() != name[i + 1] and name[i + 1].to_lower() == name[i + 1]
			if i > 0 and (prev_is_lower_or_digit or (next_is_lower and name[i - 1] != "_")):
				out += "_"
			out += c.to_lower()
		else:
			out += c
	# 연속된 밑줄 정리 및 앞뒤 밑줄 제거는 하지 않음 (원래 이름에 이미 _ 가 있을 수 있으므로 중복만 방지)
	while out.find("__") != -1:
		out = out.replace("__", "_")
	return out


## enum_name이 Godot 엔진의 내장 클래스명(예: "Range", "Node", "Object" 등)과 겹치면
## "member shadows a native class" 오류가 나므로, 겹칠 경우 뒤에 "Type"을 붙여 회피합니다.
## 그래도 겹치면 겹치지 않을 때까지 계속 "Type"을 덧붙입니다.
func _avoid_engine_class_collision(enum_name: String) -> String:
	var result := enum_name
	while ClassDB.class_exists(result):
		printerr("경고: enum 이름 '%s' 이(가) Godot 내장 클래스명과 겹쳐서 '%sType' 으로 변경합니다." % [result, result])
		result += "Type"
	return result


func _map_scalar_type(type_str: String) -> Dictionary:
	var t := type_str.to_lower().strip_edges()
	match t:
		"int", "integer":
			return {"gd_type": "int", "default_literal": "0", "kind": "int"}
		"float", "double", "number":
			return {"gd_type": "float", "default_literal": "0.0", "kind": "float"}
		"bool", "boolean":
			return {"gd_type": "bool", "default_literal": "false", "kind": "bool"}
		"json":
			return {"gd_type": "Variant", "default_literal": "null", "kind": "variant"}
		_:
			return {"gd_type": "String", "default_literal": "\"\"", "kind": "string"}


## row dict에서 꺼낸 raw_value를 필드의 실제 타입/기본값에 맞춰 보정합니다.
## 배열 필드는 Array[String]처럼 타입이 지정되어 있어서, 일반(untyped) Array를 그대로
## set()하면 타입이 안 맞아 에러 없이 조용히 무시됩니다. 그래서 Array 생성자로
## 실제 요소 타입을 명시한 typed array를 만들어서 반환합니다.
func _coerce_value(raw_value: Variant, field: Dictionary) -> Variant:
	if field.is_array:
		var out: Array = []
		if typeof(raw_value) == TYPE_ARRAY:
			for v in (raw_value as Array):
				out.append(_coerce_single_by_field(v, field))
		return _make_typed_array(out, field.elem_kind)
	return _coerce_single_by_field(raw_value, field)


## values를 field의 elem_kind에 맞는 typed Array로 다시 만들어서 반환합니다.
## (json/variant 처럼 타입이 없는 경우는 그대로 반환합니다.)
func _make_typed_array(values: Array, elem_kind: String) -> Array:
	var builtin_type := _variant_type_for_kind(elem_kind)
	if builtin_type == TYPE_NIL:
		return values
	return Array(values, builtin_type, &"", null)


func _variant_type_for_kind(kind: String) -> int:
	match kind:
		"int": return TYPE_INT
		"float": return TYPE_FLOAT
		"bool": return TYPE_BOOL
		"string": return TYPE_STRING
		"enum": return TYPE_INT
		_: return TYPE_NIL


## 배열 여부와 무관하게, 값 하나를 필드 타입(enum 포함)에 맞춰 변환합니다.
func _coerce_single_by_field(value: Variant, field: Dictionary) -> Variant:
	if field.get("is_enum", false):
		return _coerce_enum_scalar(value, field)
	return _coerce_scalar(value, field.elem_kind)


## enum 필드의 원본 문자열 값을 해당 enum의 정수 값으로 변환합니다.
## 일치하는 이름이 없으면 0번째 값으로 대체하고 경고를 남깁니다.
func _coerce_enum_scalar(value: Variant, field: Dictionary) -> int:
	if value == null:
		return 0

	var value_str := str(value).strip_edges().to_lower()
	var members: Array = field.enum_members
	for i in members.size():
		if String(members[i].original).strip_edges().to_lower() == value_str:
			return i

	printerr("경고: enum 필드 '%s' 에 알 수 없는 값 '%s' (기본값 0 사용)" % [field.field_name, str(value)])
	return 0


func _coerce_scalar(value: Variant, kind: String) -> Variant:
	if value == null:
		match kind:
			"int": return 0
			"float": return 0.0
			"bool": return false
			"string": return ""
			_: return null
	match kind:
		"int": return int(value)
		"float": return float(value)
		"bool": return bool(value)
		"string": return str(value)
		_: return value


## ---------- 코드 생성 ----------

func _build_resource_script_text(class_name_str: String, fields: Array) -> String:
	var lines: Array[String] = []
	lines.append("class_name %s" % class_name_str)
	lines.append("extends Resource")
	lines.append("## 자동 생성된 파일입니다. Google Sheets 구조가 바뀌면 생성 스크립트를 다시 실행해서 갱신하세요.")
	lines.append("")

	# --- 사용하는 enum 파일들을 preload (같은 enum이 여러 필드에 쓰여도 한 번만) ---
	var seen_enums: Dictionary = {}
	for field in fields:
		if not field.get("is_enum", false):
			continue
		var enum_name: String = field.enum_name
		if seen_enums.has(enum_name):
			continue
		seen_enums[enum_name] = true
		lines.append("const %s = preload(\"%s\")" % [enum_name, _enum_file_path(enum_name)])
	if not seen_enums.is_empty():
		lines.append("")

	# --- @export 필드 ---
	for field in fields:
		if not String(field.comment).is_empty():
			lines.append("## %s (원본 컬럼: %s)" % [field.comment, field.original_header])
		elif field.field_name != field.original_header:
			lines.append("## 원본 컬럼: %s" % field.original_header)
		if field.get("is_enum", false):
			var symbol_list: Array = []
			for member in field.enum_members:
				symbol_list.append(String(member.symbol))
			lines.append("## 값 목록 (%s): %s" % [_enum_file_path(field.enum_name), ", ".join(symbol_list)])
		lines.append("@export var %s: %s = %s" % [field.field_name, field.gd_type, field.default_literal])
		lines.append("")

	return "\n".join(lines)


## ---------- 유틸 ----------

func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)


## id 값을 파일 시스템에서 안전하게 쓸 수 있는 파일명으로 변환합니다.
func _sanitize_filename(name: String) -> String:
	var out := ""
	for c in name:
		if c == "/" or c == "\\" or c == ":" or c == "*" or c == "?" or c == "\"" or c == "<" or c == ">" or c == "|":
			out += "_"
		else:
			out += c
	return out.strip_edges()


func _write_file(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("파일 쓰기 실패: %s (error: %d)" % [path, FileAccess.get_open_error()])
		return
	file.store_string(content)
	file.close()


## 시트 이름을 PascalCase 클래스 베이스 이름으로 정리합니다 (예: "EnemyData" -> "EnemyData").
func _sanitize_class_base(name: String) -> String:
	var cleaned := ""
	for c in name:
		if c.to_upper() != c.to_lower() or c.is_valid_int():
			cleaned += c
		else:
			cleaned += "_"
	if cleaned.is_empty():
		cleaned = "Sheet"
	if cleaned[0].is_valid_int():
		cleaned = "_" + cleaned
	return cleaned


## 필드명을 기반으로 고유한 enum 타입 이름을 만듭니다. (예: "effect_type" -> "EffectTypeEnum")
func _build_enum_name(field_name: String) -> String:
	var pascal := ""
	for part in field_name.split("_"):
		if part.is_empty():
			continue
		pascal += part.substr(0, 1).to_upper() + part.substr(1)
	if pascal.is_empty():
		pascal = "Value"
	return pascal + "Enum"


## enum 값 이름(예: "Fire")을 유효한 GDScript enum 멤버명(예: "FIRE")으로 정리합니다.
func _sanitize_enum_member(name: String, index: int) -> String:
	var out := ""
	for c in name.to_upper():
		var code := c.unicode_at(0)
		var is_ascii_letter := code >= 65 and code <= 90
		var is_digit := code >= 48 and code <= 57
		if is_ascii_letter or is_digit or c == "_":
			out += c
		else:
			out += "_"

	if out.is_empty() or out.replace("_", "").is_empty():
		out = "VALUE_%d" % index

	if out[0].is_valid_int():
		out = "_" + out

	if RESERVED_WORDS.has(out):
		out += "_VALUE"

	return out


## 컬럼 헤더를 유효한 GDScript 변수명으로 정리합니다. (한글/특수문자는 제거되고, 비면 field_N 으로 대체)
func _sanitize_identifier(header: String, fallback_prefix: String, index: int) -> String:
	var out := ""
	for c in header:
		var code := c.unicode_at(0)
		var is_ascii_letter := (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		var is_digit := code >= 48 and code <= 57
		if is_ascii_letter or is_digit or c == "_":
			out += c
		else:
			out += "_"

	if out.is_empty() or out.replace("_", "").is_empty():
		out = "%s_%d" % [fallback_prefix, index]

	if out[0].is_valid_int():
		out = "_" + out

	if RESERVED_WORDS.has(out):
		out += "_field"

	return out
