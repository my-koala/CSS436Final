@tool
extends HTTPRequest
class_name WordCheck

# Processes words using dictionary API and word request queue.
# TODO: Processes and cache word definitions.

const URL: String = "https://api.dictionaryapi.dev/api/v2/entries/en/"

signal _word_processed(word: String)

var _word_valid_cache: Dictionary[String, bool] = {}

var _word_queue: Array[String] = []

var _retry_count: int = 0
var _request_processing: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	request_completed.connect(_on_request_completed)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	while !_word_queue.is_empty():
		var word: String = _word_queue[0]
		if _word_valid_cache.has(word):
			_word_queue.remove_at(0)
			_request_processing = false
		elif _request_processing:
			break
		elif _request_word(word) == OK:
			_request_processing = true
			break
		else:
			_word_queue.remove_at(0)
			_word_valid_cache[word] = false
			print("WordCheck | '%s' is not a word!" % [word])
			_word_processed.emit(word)

# problem: duplicate words emit more than once
# i need a new queue solution
# Coroutine
func get_word_valid(word: String) -> bool:
	if _word_valid_cache.has(word):
		return _word_valid_cache[word]
	_word_queue.append(word)
	while (await _word_processed) != word:
		pass
	return _word_valid_cache[word]

func _request_word(word: String) -> Error:
	if word.is_empty():
		push_error("WordCheck | Error requesting word '%s': invalid word." % [word])
		return ERR_INVALID_PARAMETER
	var url: String = URL + word
	
	var error: Error = request(url, PackedStringArray(), HTTPClient.METHOD_GET, "")
	match error:
		ERR_UNCONFIGURED:
			push_error("WordCheck | Error requesting word '%s': not in scene tree." % [word])
		ERR_BUSY:
			push_error("WordCheck | Error requesting word '%s': still processing a request." % [word])
		ERR_INVALID_PARAMETER:
			push_error("WordCheck | Error requesting word '%s': invalid url." % [word])
		ERR_CANT_CONNECT:
			push_error("WordCheck | Error requesting word '%s': failed to connect." % [word])
	
	return error

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var word: String = _word_queue[0]
	if result != Result.RESULT_SUCCESS:
		# Retry logic
		if _retry_count < 4:
			print("WordCheck | Error processing word '%s': no result, retrying..." % [word])
			await get_tree().create_timer(float(_retry_count) * 0.5).timeout
			_request_word(word)
			_retry_count += 1
		else:
			push_error("WordCheck | Error processing word '%s': no result, out of retries." % [word])
			_word_valid_cache[word] = false
			_word_processed.emit(word)
	else:
		_retry_count = 0
		if response_code == HTTPClient.ResponseCode.RESPONSE_OK:
			_word_valid_cache[word] = true
			_word_processed.emit(word)
			# TODO: Get definitions.
			# Parse JSON response body as word entries.
			#var json: JSON = JSON.new()
			#if json.parse(body.get_string_from_utf8()) != OK:
				#push_error("WordCheck | Error processing word '%s': could not read JSON (invalid body string)." % [word])
				#return
			#var json_data: Variant = json.data
			#var json_entries: Array[Dictionary] = json_data
			#if !is_instance_valid(json_entries):
				#push_error("WordCheck | Error processing word '%s': could not read JSON (expected body as array)." % [word])
				#return
			#var json_entry: Dictionary[String, Variant] = json_entries[0]
			#if !is_instance_valid(json_entry):
				#push_error("WordCheck | Error processing word '%s': could not read JSON (expected entry as dictionary)." % [word])
				#return
			#var json_definitions: Array = json_entry["meanings"]
		else:
			# Could not find word.
			# TODO: Match response codes, possible retry.
			_word_valid_cache[word] = false
			_word_processed.emit(word)
