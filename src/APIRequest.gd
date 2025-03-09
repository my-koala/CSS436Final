#extends Node2D
extends Control
var http_request: HTTPRequest
var word: String = "Cat" 
var url: String

func _ready() -> void:
	sendRequest(word)

#word map
var wordMap : Dictionary={}
#API request
func sendRequest(word: String) ->void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	
	url = "https://api.dictionaryapi.dev/api/v2/entries/en/" + word
	
	http_request.request_completed.connect(_on_request_completed)

	var error : int = http_request.request(url)
	if error != OK:
		print("Failed to send request")
# Signal handler for the request completion
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) ->void:
	if response_code == 200:
		# Parse JSON response
		var json : JSON = JSON.new()
		var error : int = json.parse(body.get_string_from_utf8())
		
		if error == OK:
			var response : Variant = json.data
			var first_entry : Dictionary = response[0]
				
			if "word" in first_entry and "meanings" in first_entry:
				print("Word: " + first_entry["word"])
				var meanings : Array = first_entry["meanings"]
				var definitions : Array = []
				for meaning : Dictionary in meanings:
					if "definitions" in meaning and meaning["definitions"] is Array and (meaning["definitions"] as Array).size() > 0:
							#print("Definition: " + meaning["definitions"][0]["definition"])
						definitions.append(meaning["definitions"][0]["definition"])
					
				wordMap[first_entry["word"]] = definitions
					
				print(wordMap)
			else:
				print("Invalid response format")
		else:
			print("Error parsing response JSON.")
	else:
		print("word not found in dictionary")
