extends Node

@export var public_ipv4 : String
@export var public_ipv6 : String

const api_ipv4 = "https://api.ipify.org"
const api_ipv6 = "https://api64.ipify.org"

var http
var thread
var waiting = false
var ip_grabbed = false

func get_ip():
	if ip_grabbed:
		return
	ip_grabbed = true
	
	http = HTTPRequest.new()
	http.use_threads = true
	add_child(http)
	
	thread = Thread.new()
	thread.start(_request_ips)

func _request_ips():
	http.request_completed.connect(_on_result_ivp4)
	http.request(api_ipv4)
	waiting = true
	
	while waiting:
		continue
		
	http.request_completed.disconnect(_on_result_ivp4)
		
	http.request_completed.connect(_on_result_ivp6)
	http.request(api_ipv6)
	waiting = true
	
	while waiting:
		continue
	
	http.request_completed.disconnect(_on_result_ivp6)
	
	var err_bad_gateway = public_ipv4 == "Bad Gateway" or public_ipv6 == "Bad Gateway"
	var err_empty = public_ipv4 == "" or public_ipv6 == ""
	
	if err_bad_gateway or err_empty:
		if err_bad_gateway:
			printerr("Bad gateway!")
		_request_ips()
	print([public_ipv4, public_ipv6])

func _on_result_ivp4(_result, _response_code, _headers, body):
	public_ipv4 = get_ip_from_body(body)

func _on_result_ivp6(_result, _response_code, _headers, body):
	public_ipv6 = get_ip_from_body(body)

func get_ip_from_body(body):
	waiting = false
	return body.get_string_from_utf8()
