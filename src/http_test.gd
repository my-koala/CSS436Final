@tool
extends Node

var _http_client: HTTPClient = HTTPClient.new()

func check_word(word: String) -> void:
	pass

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	if _http_client.connect_to_host("https://api.dictionaryapi.dev") != OK:
		push_error("Failed to connect to dictionary API!")
		return
	

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_http_client.poll()
	print(_http_client.get_status())

	## TODO: Implement word check algorithm.
	## 1. Get all words created by submission.
	#var words: Array[String] = ["test", "ah", "superfluous", "egg", "mykoala"]
	#var http_requests: Array[HTTPRequest] = []
	#for word: String in words:
		#var http_client: HTTPClient = HTTPClient.new()
		#var url: String = "https://api.dictionaryapi.dev/api/v2/entries/en/" + word
		#http_request.timeout = 3.0
		#http_request.max_redirects = 1
		#http_request.use_threads = true
		#if http_request.request(url) != OK:
			#push_error("Could not make request to API: %s" % [url])
			#return SubmissionResult.ERROR
		#http_requests.append(http_request)
		#
		#await http_request.request_completed
		#while http_request:
			#await get_tree().physics_frame
		## Now process http request and check if valid word.
	#
	#while !http_requests.is_empty():
		#for http_request: HTTPRequest in http_requests:
			#pass
			#if http_request.has_response():
				#pass
		#await get_tree().physics_frame
	#
	#var http_client: HTTPClient = HTTPClient.new()
	#http_client.connect_to_host()
