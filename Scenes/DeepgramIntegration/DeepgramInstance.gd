extends Node

# signals

signal message_received
signal call_id_received
signal binary_packet_received

# variables

# we will buffer audio from the mic and send it out to Deepgram in reasonably sized chunks
var audio_buffer: PoolRealArray

# the WebSocketClient which allows us to connect to Deepgram
var client = WebSocketClient.new()
var ws_connected = false

var STS_URL = "wss://sts.sandbox.deepgram.com"
var BEPIS_SERVER_URL = "https://wcdonaldsquest.deepgram.com"

# functions

# a helper function to convert f32 pcm samples to i16
func f32_to_i16(f: float):
	f = f * 32768
	if f > 32767:
		return 32767
	if f < -32768:
		return -32768
	return int(f)

# a convenience function to delete this node
func delete():
	print("Destroying DeepgramInstance")
	get_tree().queue_delete(self)

func _ready():
	print("DeepgramInstance ready!")


func initialize(api_key):
	# start recording from the mic (actually this only starts capture of the recording I think)
	$MicrophoneInstance.recording = true

	# connect base signals to get notified of connection open, close, and errors
	client.connect("connection_closed", self, "_closed")
	client.connect("connection_error", self, "_closed")
	client.connect("connection_established", self, "_connected")
	client.connect("data_received", self, "_on_data")

	if OS.get_name() == "HTML5":
		var protocols = PoolStringArray(["token", api_key])
		var err = client.connect_to_url(STS_URL + "/agent", protocols, false, PoolStringArray())
		if err != OK:
			print("Unable to connect")
			emit_signal("message_received", "unable to connect to deepgram;")
			set_process(false)
	else:
		var headers = PoolStringArray(["Authorization: Token " + api_key])
		var err = client.connect_to_url(STS_URL + "/agent", PoolStringArray(), false, headers)
		if err != OK:
			print("Unable to connect")
			emit_signal("message_received", "unable to connect to deepgram;")
			set_process(false)

func _closed(was_clean = false):
	print("Closed, clean: ", was_clean)
	emit_signal("message_received", "connection to deepgram closed;")
	set_process(false)

func _connected(_proto):
	print("Connected to Deepgram!")

	var url = BEPIS_SERVER_URL + "/calls"

	print("making request to the function hosting server")

	var headers = ["Content-Type: application/json"]
	var use_ssl = false
	var query = "{}"
	$HTTPRequest.request(url, headers, use_ssl, HTTPClient.METHOD_POST, query)

func _on_HTTPRequest_request_completed(_result, response_code, _headers, body):
	if response_code != 200:
		return
	
	var id = body.get_string_from_utf8()
	print(id)
	emit_signal("call_id_received", id)
	
	var mix_rate = AudioServer.get_mix_rate()
	
	#var config_message = '{"type": "SettingsConfiguration", "audio": {"input": {"encoding": "linear16", "sample_rate": 48000}}}'
	var config_message = {
				"type": "SettingsConfiguration",
				"audio": {
					"input": {
						"encoding": "linear16",
						"sample_rate": mix_rate,
					},
					"output": {
						"encoding": "linear16",
						"sample_rate": mix_rate,
						"container": "none",
						"buffer_size": 500,
					},
				},
				"agent": {
					"listen": {"model": "nova-2"},
					"think": {
						"provider": "anthropic",
						"model": "claude-3-haiku-20240307",
						"instructions": "You are a beverage seller. You only sell coke and pepsi.",
						# this function is what STS will call to submit orders
						# for this call (note the "id" portion of the path)
						"functions": [
							{
								"name": "submit_order",
								"description": "Submit an order for a beverage.",
								"url": BEPIS_SERVER_URL + "/calls/" + id + "/order",
								"input_schema": {
									"type": "object",
									"properties": {
										"item": {
											"type": "string",
											"description": "The drink the user would like to order. The only valid values are coke or pepsi.",
										}
									},
									"required": ["item"],
								},
							}
						],
					},
					"speak": {"model": "aura-asteria-en"},
				},
			}
		
	client.get_peer(1).set_write_mode(0)
	client.get_peer(1).put_packet(JSON.print(config_message).to_utf8())
	client.get_peer(1).set_write_mode(1)
	print("finished sending config message")
	ws_connected = true	
	
func _on_data():
	# receive a message from Deepgram!
	var packet = client.get_peer(1).get_packet()
	if client.get_peer(1).was_string_packet():
		var message = packet.get_string_from_utf8()
	
		# emit the message from Deepgram as a signal
		emit_signal("message_received", message)
	else:
		emit_signal("binary_packet_received", packet)

func _process(_delta):
	client.poll()

func _on_MicrophoneInstance_audio_captured(mono_data):
	if !ws_connected:
		return
		
	audio_buffer.append_array(mono_data)
	# TODO: consider using `set_encode_buffer_max_size(value)` to increase the packet size
	# this might allow us to stream slower and possibly improve performance
	if audio_buffer.size() >= 1024 * 40 * 0.5 and ws_connected == true:
		# convert the f32 pcm to linear16/i16 pcm
		# this is a bit hacky, but godot doesn't seem to offer too much flexibility with low-level types
		var linear16_audio: PoolByteArray = []
		for sample in audio_buffer:
			linear16_audio.append(f32_to_i16(sample))
			linear16_audio.append(f32_to_i16(sample) >> 8)
		# send the audio to Deepgram!
		client.get_peer(1).put_packet(linear16_audio)
		audio_buffer = PoolRealArray()
