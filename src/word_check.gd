@tool
extends HTTPRequest
class_name WordCheck

# Reads words from a text file.
# https://github.com/elasticdog/yawl/tree/master

const WORDS_PATH: String = "res://assets/words/words.txt"

var _words: Dictionary[String, bool] = {}

func _init() -> void:
	if Engine.is_editor_hint():
		return
	
	_words.clear()
	
	print("WordCheck | Reading words...")
	var words_file: FileAccess = FileAccess.open(WORDS_PATH, FileAccess.READ)
	if !is_instance_valid(words_file) || !words_file.is_open():
		push_error("WordCheck | Failed to read words.")
		return
	
	while !words_file.eof_reached():
		var word: String = words_file.get_line()
		if !word.is_empty():
			_words[word] = true
	
	words_file.close()
	print("WordCheck | Done reading words!")

func is_word(word: String) -> bool:
	return _words.has(word)
