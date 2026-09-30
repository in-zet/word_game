extends Control
## 프로토타입 전투 화면. UI 노드를 전부 코드로 생성하고 BattleManager의 signal만 구독한다.
## 로직(피해 계산, 턴 진행)은 이 파일에 두지 않는다 — 전부 BattleManager에 있다.
##
## 턴은 Timer로 1초마다 자동 진행된다(어절 하나 = 턴 하나 = 1초, 보드 설계 메모
## "어절은 다음 턴까지의 대기시간(유저가 동작을 입력할 수 있는 시간)"을 그대로 구현).
##
## 문장은 턴마다 한 어절씩 "그려서 쌓는" 방식으로 표시한다(사전 공개 없음):
## - 적 문장은 기본 문장이 새로 시작될 때만 줄을 비우고, 이어진 문장("또 ...")이 오면
##   지우지 않고 뒤에 계속 이어 붙인다.
## - 유저 줄은 적의 기본 문장이 새로 시작될 때 같이 비워지고, 그 뒤로는 매 턴 유저가
##   낸 어절(없으면 빈 칸)을 적 줄과 같은 턴 수만큼 쌓아서 적 줄 바로 밑에 위치가
##   맞도록 한다 (예: 1턴엔 대기, 2턴에 수비를 누르면 "(빈칸) 방패로 막았다."로 보임).
## - 방금(이번 턴) 나온 어절은 글자를 더 크게 표시한다.

const Combatant = preload("res://scripts/battle/combatant.gd")
const BattleManager = preload("res://scripts/battle/battle_manager.gd")
const PlayerAction = preload("res://scripts/battle/player_action.gd")

const TURN_INTERVAL_SEC := 1.0
const CURRENT_WORD_FONT_SIZE := 28
const BLANK_TURN_PLACEHOLDER := "    "  ## 그 턴에 유저가 아무 것도 안 했을 때의 자리 표시(칸 맞춤용)

var _battle: BattleManager
var _turn_timer: Timer
var _enemy_sentence_label: RichTextLabel
var _player_sentence_label: RichTextLabel
var _log_label: RichTextLabel
var _player_hp_bar: ProgressBar
var _enemy_hp_bar: ProgressBar
var _player_poise_bar: ProgressBar
var _enemy_poise_bar: ProgressBar
var _attack_button: Button
var _defense_button: Button
var _pass_button: Button

## 지금 라운드(적 기본 문장 시작 ~ 다음 기본 문장 시작 전)의 턴별 단어 기록.
## 두 배열은 항상 같은 길이(턴 수)를 유지한다 — 유저 쪽은 그 턴에 낼 말이 없으면 "".
var _round_enemy_words: Array[String] = []
var _round_player_words: Array[String] = []
var _this_turn_enemy_word: String = ""
var _this_turn_player_word: String = ""


func _ready() -> void:
	_build_ui()
	_start_battle()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var enemy_row := HBoxContainer.new()
	root.add_child(enemy_row)
	enemy_row.add_child(_labelled("적:"))
	_enemy_hp_bar = ProgressBar.new()
	_enemy_hp_bar.custom_minimum_size = Vector2(200, 20)
	enemy_row.add_child(_enemy_hp_bar)
	_enemy_poise_bar = ProgressBar.new()
	_enemy_poise_bar.custom_minimum_size = Vector2(200, 10)
	enemy_row.add_child(_enemy_poise_bar)

	_enemy_sentence_label = RichTextLabel.new()
	_enemy_sentence_label.bbcode_enabled = true
	_enemy_sentence_label.custom_minimum_size = Vector2(600, 50)
	_enemy_sentence_label.fit_content = true
	root.add_child(_enemy_sentence_label)

	# 유저 줄은 적 문장 라벨 바로 밑에 둔다(레이아웃 순서 = 화면 세로 위치) — HP/강인도 바는
	# 별도 줄이라 문장 두 줄이 곧바로 위아래로 붙어 보이게 한다.
	_player_sentence_label = RichTextLabel.new()
	_player_sentence_label.bbcode_enabled = true
	_player_sentence_label.custom_minimum_size = Vector2(600, 50)
	_player_sentence_label.fit_content = true
	root.add_child(_player_sentence_label)

	var player_row := HBoxContainer.new()
	root.add_child(player_row)
	player_row.add_child(_labelled("플레이어:"))
	_player_hp_bar = ProgressBar.new()
	_player_hp_bar.custom_minimum_size = Vector2(200, 20)
	player_row.add_child(_player_hp_bar)
	_player_poise_bar = ProgressBar.new()
	_player_poise_bar.custom_minimum_size = Vector2(200, 10)
	player_row.add_child(_player_poise_bar)

	var button_row := HBoxContainer.new()
	root.add_child(button_row)
	_attack_button = Button.new()
	_attack_button.text = "타격"
	_attack_button.pressed.connect(_on_action_pressed.bind(PlayerAction.ATTACK_ID))
	button_row.add_child(_attack_button)
	_defense_button = Button.new()
	_defense_button.text = "수비"
	_defense_button.pressed.connect(_on_action_pressed.bind(PlayerAction.DEFENSE_ID))
	button_row.add_child(_defense_button)
	_pass_button = Button.new()
	_pass_button.text = "패스"
	_pass_button.pressed.connect(_on_action_pressed.bind(""))
	button_row.add_child(_pass_button)

	_log_label = RichTextLabel.new()
	_log_label.custom_minimum_size = Vector2(600, 200)
	_log_label.scroll_following = true
	root.add_child(_log_label)

	_turn_timer = Timer.new()
	_turn_timer.wait_time = TURN_INTERVAL_SEC
	_turn_timer.one_shot = false
	_turn_timer.timeout.connect(_on_turn_timer_timeout)
	add_child(_turn_timer)


func _labelled(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _start_battle() -> void:
	var player := Combatant.new("플레이어", 100, 12, 10, 100)
	var enemy_data: EnemyDataResource = load("res://resources/data/EnemyData/Goblin.tres")
	var enemy := Combatant.new("고블린", enemy_data.healthPoint, enemy_data.strength,
		enemy_data.dexterity, enemy_data.poise)

	# 고블린이 보유한 패턴들(possessedPatternID)을 전부 불러온다 — 문장을 새로 시작할 때마다
	# possessedPatternWeight 가중치로 이 중 하나를 뽑아 쓴다(BattleManager._load_enemy_sentence).
	var patterns: Array[PatternDataResource] = []
	for pattern_id in enemy_data.possessedPatternID:
		patterns.append(load("res://resources/data/PatternData/%s.tres" % pattern_id))
	var pattern_weights: Array[int] = enemy_data.possessedPatternWeight

	var verb: VerbDataResource = load("res://resources/data/VerbData/" + patterns[0].basicLineVerbID + ".tres")
	var weapon_id: String = enemy_data.possessedWeaponID[0]

	_battle = BattleManager.new(player, enemy, patterns, pattern_weights, verb, weapon_id, randi())
	_battle.sentence_loaded.connect(_on_sentence_loaded)
	_battle.eojeol_revealed.connect(_on_eojeol_revealed)
	_battle.log_added.connect(_on_log_added)
	_battle.turn_resolved.connect(_on_turn_resolved)
	_battle.battle_finished.connect(_on_battle_finished)
	_battle.start_battle()
	_refresh_action_buttons()
	_refresh_bars()
	_turn_timer.start()


func _on_action_pressed(action_id: String) -> void:
	_battle.submit_player_action(action_id)
	_refresh_action_buttons()


## 1초마다 자동으로 한 턴(어절 하나)씩 진행한다. 그 사이가 유저가 행동을 입력할 수 있는 시간이다.
func _on_turn_timer_timeout() -> void:
	_battle.advance_turn()
	_refresh_action_buttons()
	_refresh_bars()


## 적의 새 기본 문장(연결 아님)이 시작되면 라운드가 새로 시작된 것으로 보고 두 줄을 비운다.
## 이어진 문장("또 ...")은 여기서 아무 것도 하지 않는다 — 이미 쌓인 줄에 계속 이어 붙게 둔다.
func _on_sentence_loaded(side: String, sentence: Sentence) -> void:
	if side != "enemy":
		return
	var is_new_base := sentence.eojeols.size() > 0 and sentence.eojeols[0].role == Eojeol.Role.SUBJECT
	if is_new_base:
		_round_enemy_words.clear()
		_round_player_words.clear()


## 이번 턴에 어느 쪽에 어떤 어절이 나왔는지만 잠깐 기억해둔다 — 실제로 줄에 쌓는 건
## 한 턴의 양쪽 처리가 다 끝난 뒤(turn_resolved)에 한다.
func _on_eojeol_revealed(side: String, _index: int, eojeol: Eojeol) -> void:
	if side == "enemy":
		_this_turn_enemy_word = eojeol.text
	else:
		_this_turn_player_word = eojeol.text


func _on_log_added(text: String) -> void:
	_log_label.append_text(text + "\n")


func _on_turn_resolved(_turn_no: int) -> void:
	_round_enemy_words.append(_this_turn_enemy_word)
	_round_player_words.append(_this_turn_player_word)
	_this_turn_enemy_word = ""
	_this_turn_player_word = ""
	_render_sentences()


func _on_battle_finished(player_won: bool) -> void:
	_turn_timer.stop()
	_log_label.append_text(("승리!" if player_won else "패배...") + "\n")
	_attack_button.disabled = true
	_defense_button.disabled = true
	_pass_button.disabled = true


## 진행 중인(선딜~서술어 사이) 플레이어 문장이 있거나 쿨타임 중이면 해당 버튼을 비활성화한다.
func _refresh_action_buttons() -> void:
	if _battle.phase != BattleManager.Phase.WAIT_INPUT or _battle.has_pending_player_action():
		_attack_button.disabled = true
		_defense_button.disabled = true
		_pass_button.disabled = true
		return
	_attack_button.disabled = not _battle.player.is_action_ready(PlayerAction.ATTACK_ID)
	_defense_button.disabled = not _battle.player.is_action_ready(PlayerAction.DEFENSE_ID)
	_pass_button.disabled = false


func _render_sentences() -> void:
	_enemy_sentence_label.text = _render_round_words(_round_enemy_words)
	_player_sentence_label.text = _render_round_words(_round_player_words)


## 턴별 단어 목록을 한 줄로 그린다. 빈 칸("")은 자리표시 공백으로, 방금(마지막) 나온
## 실제 단어는 더 큰 글자로 표시한다.
func _render_round_words(words: Array[String]) -> String:
	if words.is_empty():
		return ""
	var parts: Array[String] = []
	for i in words.size():
		var word := words[i]
		if word.is_empty():
			parts.append(BLANK_TURN_PLACEHOLDER)
		elif i == words.size() - 1:
			parts.append("[font_size=%d]%s[/font_size]" % [CURRENT_WORD_FONT_SIZE, word])
		else:
			parts.append(word)
	return " ".join(parts)


func _refresh_bars() -> void:
	_player_hp_bar.max_value = _battle.player.max_hp
	_player_hp_bar.value = _battle.player.hp
	_player_poise_bar.max_value = _battle.player.max_poise
	_player_poise_bar.value = _battle.player.poise
	_enemy_hp_bar.max_value = _battle.enemy.max_hp
	_enemy_hp_bar.value = _battle.enemy.hp
	_enemy_poise_bar.max_value = _battle.enemy.max_poise
	_enemy_poise_bar.value = _battle.enemy.poise
