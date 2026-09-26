@tool
extends EditorScript
## 게임을 실행(F5)하지 않고, 에디터에서 이 스크립트를 직접 실행해서
## API로부터 JSON을 받아와 res://cache/sheet_data_cache.json 에 저장합니다.
##
## 사용법:
## 1. 이 파일을 프로젝트 아무 곳에나 둡니다 (예: scripts/tools/editor_fetch_sheet_data.gd).
## 2. 스크립트 편집기에서 이 파일을 엽니다.
## 3. 상단 메뉴 파일(File) > 실행(Run) 또는 단축키 Ctrl+Shift+X 를 누릅니다.
## 4. 출력(Output) 창에서 결과를 확인합니다. 게임을 Play 할 필요가 없습니다.

const CONFIG_PATH := "res://local_config.cfg"
const CONFIG_SECTION := "DBapi"
const CONFIG_KEY := "url"

const CACHE_PATH := "res://scripts/DB/sheet_data_cache.json"
const MAX_REDIRECTS := 5
const POLL_DELAY_MSEC := 50


func _run() -> void:
	print("=== SheetData 에디터 저장 시작 ===")

	var url := _load_api_url()
	if url.is_empty():
		printerr("SheetData(Editor): API URL을 읽지 못해 중단합니다.")
		return

	var json_string := _fetch_url_blocking(url)
	if json_string.is_empty():
		printerr("SheetData(Editor): 응답을 받지 못해 중단합니다.")
		return

	var json := JSON.new()
	if json.parse(json_string) != OK:
		printerr("SheetData(Editor): JSON 파싱 실패 - %s" % json.get_error_message())
		printerr("SheetData(Editor): 응답 본문 (앞 300자): %s" % json_string.substr(0, 300))
		return

	if not _save_to_file(json_string):
		return

	var parsed: Variant = json.get_data()
	if typeof(parsed) == TYPE_DICTIONARY:
		print("SheetData(Editor): 시트 목록: ", (parsed as Dictionary).keys())

	print("=== 저장 완료: %s ===" % ProjectSettings.globalize_path(CACHE_PATH))


func _load_api_url() -> String:
	if not FileAccess.file_exists(CONFIG_PATH):
		printerr("SheetData(Editor): 설정 파일이 없습니다 (%s)" % CONFIG_PATH)
		return ""

	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		printerr("SheetData(Editor): 설정 파일 로드 실패")
		return ""

	var url: String = config.get_value(CONFIG_SECTION, CONFIG_KEY, "")
	if url.is_empty():
		printerr("SheetData(Editor): local_config.cfg 의 [%s] %s 값이 비어있습니다." % [CONFIG_SECTION, CONFIG_KEY])
	return url


func _parse_url(url: String) -> Dictionary:
	var use_ssl := url.begins_with("https://")
	var without_scheme := url.trim_prefix("https://").trim_prefix("http://")
	var slash_index := without_scheme.find("/")
	var host_port := without_scheme if slash_index == -1 else without_scheme.substr(0, slash_index)
	var path := "/" if slash_index == -1 else without_scheme.substr(slash_index)

	var host := host_port
	var port := 443 if use_ssl else 80
	if host_port.find(":") != -1:
		var parts := host_port.split(":")
		host = parts[0]
		port = int(parts[1])

	return {"use_ssl": use_ssl, "host": host, "port": port, "path": path}


## HTTPClient로 동기 방식 GET 요청을 보내고, 리다이렉트를 직접 따라가며 최종 본문을 반환합니다.
## 실패 시 빈 문자열을 반환합니다.
func _fetch_url_blocking(start_url: String) -> String:
	var url := start_url
	var redirects_left := MAX_REDIRECTS

	while redirects_left > 0:
		redirects_left -= 1
		var parts := _parse_url(url)

		var http := HTTPClient.new()
		var tls_options: TLSOptions = TLSOptions.client() if parts.use_ssl else null
		var err := http.connect_to_host(parts.host, parts.port, tls_options)
		if err != OK:
			printerr("SheetData(Editor): 연결 시작 실패 (error: %d)" % err)
			return ""

		while http.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
			http.poll()
			OS.delay_msec(POLL_DELAY_MSEC)

		if http.get_status() != HTTPClient.STATUS_CONNECTED:
			printerr("SheetData(Editor): 연결 실패 (status: %d)" % http.get_status())
			return ""

		err = http.request(HTTPClient.METHOD_GET, parts.path, ["User-Agent: GodotEditorScript"])
		if err != OK:
			printerr("SheetData(Editor): 요청 전송 실패 (error: %d)" % err)
			return ""

		while http.get_status() == HTTPClient.STATUS_REQUESTING:
			http.poll()
			OS.delay_msec(POLL_DELAY_MSEC)

		if not (http.get_status() == HTTPClient.STATUS_BODY or http.get_status() == HTTPClient.STATUS_CONNECTED):
			printerr("SheetData(Editor): 응답 상태 이상 (status: %d)" % http.get_status())
			return ""

		var response_code := http.get_response_code()
		var response_headers := http.get_response_headers_as_dictionary()

		# 3xx 리다이렉트면 Location을 따라 다시 시도
		if response_code in [301, 302, 303, 307, 308]:
			var location: String = response_headers.get("Location", response_headers.get("location", ""))
			if location.is_empty():
				printerr("SheetData(Editor): 리다이렉트 응답(%d)인데 Location 헤더가 없습니다." % response_code)
				return ""
			url = location
			continue

		if response_code != 200:
			printerr("SheetData(Editor): HTTP 에러 (status: %d)" % response_code)
			return ""

		var body := PackedByteArray()
		while http.get_status() == HTTPClient.STATUS_BODY:
			http.poll()
			var chunk := http.read_response_body_chunk()
			if chunk.size() == 0:
				OS.delay_msec(POLL_DELAY_MSEC)
			else:
				body += chunk

		return body.get_string_from_utf8()

	printerr("SheetData(Editor): 리다이렉트 한도(%d) 초과" % MAX_REDIRECTS)
	return ""


func _save_to_file(json_string: String) -> bool:
	var dir_path := CACHE_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var make_dir_error := DirAccess.make_dir_recursive_absolute(dir_path)
		if make_dir_error != OK:
			printerr("SheetData(Editor): 폴더 생성 실패 (%s, error: %d)" % [dir_path, make_dir_error])
			return false

	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file == null:
		printerr("SheetData(Editor): 파일 저장 실패 (error: %d)" % FileAccess.get_open_error())
		return false

	file.store_string(json_string)
	file.close()
	return true
