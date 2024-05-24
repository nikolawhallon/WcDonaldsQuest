extends Node2D

var BEPIS_SERVER_URL = "https://wcdonaldsquest.deepgram.com"
var call_id = null

var playback: AudioStreamPlayback = null # Actual playback stream, assigned in _ready().
var tried_to_connect = false

func _process(_delta):
	if $Yugo.global_position.distance_to($WcDonalds.global_position) < 100:
		if !tried_to_connect:
			initialize_drive_through()
			tried_to_connect = true

func initialize_drive_through():
	$DeepgramInstance.initialize("INSERT_API_KEY")

	playback = $AudioStreamPlayer.get_stream_playback()
	print("got a playback object?")
	print(playback.get_frames_available())
	$AudioStreamPlayer.play()


func _on_DeepgramInstance_message_received(message):
	var message_json = JSON.parse(message)
	if message_json.error == OK:
		print(message)


func _on_DeepgramInstance_call_id_received(id):
	call_id = id


func _on_Timer_timeout():
	if call_id != null:
		print("checking call order")
		
		var url = BEPIS_SERVER_URL + "/calls/" + call_id
		$HTTPRequest.request(url)


func _on_HTTPRequest_request_completed(_result, response_code, _headers, body):
	if response_code != 200:
		print("failed to make request for call info")
		return
		
	var response_body = body.get_string_from_utf8()
	print(response_body)
	
	var response_dictionary = JSON.parse(response_body)
	if response_dictionary.error == OK:
		if typeof(response_dictionary.result) == TYPE_DICTIONARY:
			if response_dictionary.result.has("order"):
				if typeof(response_dictionary.result["order"]) == TYPE_DICTIONARY:
					if response_dictionary.result["order"]["item"] == "coke":
						print("asked for a coke!")
					if response_dictionary.result["order"]["item"] == "pepsi":
						print("asked for a pepsi!")

	
func _on_DeepgramInstance_binary_packet_received(packet):
	# we pretty much always have enough frames available
	#print(playback.get_frames_available())
	#print(len(packet) / 2)
	for x in len(packet) / 2:
		var sample = packet[x * 2] | (packet[x * 2 + 1] << 8)
		if sample >= 32768:
			sample -= 65536
		sample = float(sample) / 32768.0
		playback.push_frame(Vector2(sample, sample))
