extends Node

# v0.0.1 7/2/2023
# v0.0.2 7/5/2023
# v0.0.3 7/7/2023

signal new_connection(type, data)

enum CONNECTION_TYPE {
	CONNECTED,
	DISCONNECTED,
	VALIDATION_SUCCESS,
	VALIDATION_FAILED,
	LOGIN_SUCCESS,
	LOGIN_FAILED,
	KICK,
	BAN,
}

enum VALIDATION_LEVEL {
	NONE = 0,
	
	PROJECT_NAME = 1,
	NET_VERSION_MAJOR = 2,
	NET_VERSION_MINOR = 4,
	NET_VERSION_PATCH = 8,
	CLIENT_VERSION_MAJOR = 16,
	CLIENT_VERSION_MINOR = 32,
	CLIENT_VERSION_PATCH = 64,
	
	CLIENT_VERSION_ONLY = 112,
	VERSION_ONLY = 126,
	EVERYTHING = 127
}

const VERSION = "0.0.3"

const VALIDATION_PACKET = "validation-packet"

const api_ipv4 = "https://api.ipify.org"
const api_ipv6 = "https://api64.ipify.org"

var public_ipv4
var public_ipv6

var pending_clients = {}
var connected_clients = {}
#var connected_client_data
var ban_list

var server_information

var private = {}

func validation_data() -> Dictionary:
	return {
		"net-version": Network.VERSION,
		"client-version": VERSION,
		"project-name": ProjectSettings.get_setting("application/config/name")
	}

func default_server_information() -> Dictionary:
	var info = {
		"server-name": "My Server",
		"version-validation": true,
		"public-server": true,
		"port": 21222,
		"password-protected": false,
		"password": "",
		"max-clients": 32,
		"validation-level": VALIDATION_LEVEL.EVERYTHING
	}
	info.merge(validation_data())
	return info

func _init():
	Network.message_recieved.connect(network_message)
	Network.new_connection.connect(network_connection)
	new_connection.connect(networkclient_connection)

func join(info : Dictionary):
	if info.is_empty():
		error("Join info is invalid")
		return false
	var ip = info["ip"] as String
	var port = info["port"] as int
	private["password-attempt"] = info["password"]
	
	return Network.join(ip, port)

func is_peer_connected(peer_id : int) -> bool:
	return multiplayer.get_peers().find(peer_id)

func get_client_data(peer_id : int) -> Dictionary:
	return connected_clients[peer_id]


func host(info : Array):
	if info.is_empty():
		error("Server info is invalid")
		return false
	var port = info[0]["port"] as int
	var upnp = info[0]["public-server"] as bool
	var max_clients = info[0]["max-clients"] as int
	var local_client = info[1]
	server_information = info[0]
	
	if not Network.host(port, local_client, max_clients, upnp):
		return false
	
	server_information["local-ip"] = IP.get_local_addresses()
	if local_client:
		connected_clients[Network.get_id()] = info[1]
	
	if upnp:
		await grab_public_ip()
		server_information["public-ipv4"] = public_ipv4
		server_information["public-ipv6"] = public_ipv6



func grab_public_ip():
	var http = HTTPRequest.new()
	http.use_threads = true
	add_child(http)
	
	var request = func():
		var result
		http.request(api_ipv4)
		result = await http.request_completed
		public_ipv4 = result[3].get_string_from_utf8()
		http.request(api_ipv6)
		result = await http.request_completed
		public_ipv6 = result[3].get_string_from_utf8()
	
	var valid_ips = false
	while not valid_ips:
		await request.call()
		valid_ips = not (public_ipv4 == "Bad Gateway" or public_ipv6 == "Bad Gateway" or public_ipv4 == "" or public_ipv6 == "")
	
	http.queue_free()

#func ban_ip(ip, reason = ""):
#	pass
#
#func ban_username(username, reason = ""):
#	pass



func verify_validation_data(data : Array) -> bool:
	var v_level = server_information["validation-level"]
	var verification = 0
	
	if v_level == VALIDATION_LEVEL.NONE:
		return true
	
	if v_level & VALIDATION_LEVEL.NET_VERSION_MAJOR:
		verification |= data[0][0]
	if v_level & VALIDATION_LEVEL.NET_VERSION_MINOR:
		verification |= data[0][1]
	if v_level & VALIDATION_LEVEL.NET_VERSION_PATCH:
		verification |= data[0][2]
	if v_level & VALIDATION_LEVEL.CLIENT_VERSION_MAJOR:
		verification |= data[1][0]
	if v_level & VALIDATION_LEVEL.CLIENT_VERSION_MINOR:
		verification |= data[1][1]
	if v_level & VALIDATION_LEVEL.CLIENT_VERSION_PATCH:
		verification |= data[1][2]
	if v_level & VALIDATION_LEVEL.PROJECT_NAME:
		verification |= not data[2] as int
	
	return not bool(verification)

func validation_request(data):
	var packet = Network.default_packet(VALIDATION_PACKET + "/reply")
	packet.merge(validation_data())
	Network.send_packet(Network.SERVER_ID, packet)

func validation_reply(data):
	const nv = "net-version"
	const cv = "client-version"
	const pn = "project-name"
	
	var comp_version = func(verA : String, verB : String) -> Array:
		var splitA = verA.split('.')
		var splitB = verB.split('.')
		
		var arr = []
		for i in range(3):
			arr.append(splitA[i].to_int() - splitB[i].to_int())
		return arr
	
	return [
		comp_version.call(server_information[nv], data[nv]),
		comp_version.call(server_information[cv], data[cv]),
		server_information[pn] == data[pn]
	]

func ping_packet(time_recieved, time_sent, time_mode, peer_to) -> float:
	var ping_time = time_recieved - time_sent
	if time_mode == "usec":
		ping_time /= 1e+3
	var new_packet = Network.default_packet("update-ping")
	new_packet["ping-time"] = ping_time
	new_packet["peer-id"] = peer_to
	Network.send_packet(0, new_packet)
	
	return ping_time

func error(message):
	print(str(message))



func networkclient_connection(type, data):
	match type:
		CONNECTION_TYPE.CONNECTED:
			pass
		CONNECTION_TYPE.DISCONNECTED:
			pass
		CONNECTION_TYPE.VALIDATION_SUCCESS:
			pass
		CONNECTION_TYPE.VALIDATION_FAILED:
			pass
		CONNECTION_TYPE.KICK:
			pass
		CONNECTION_TYPE.BAN:
			pass

func network_connection(type, data):
	match type:
		Network.CONNECTION_TYPE.HOST:
			pass
		Network.CONNECTION_TYPE.CONNECTED:
			pass
		Network.CONNECTION_TYPE.DISCONNECTED:
			pass
		Network.CONNECTION_TYPE.PEER_CONNECTED:
			var peer_id = data["peer-id"]
			if multiplayer.is_server():
				pending_clients[peer_id] = {
					"time-connected": Time.get_unix_time_from_system()
				}
				if server_information["version-validation"]:
					var validation_packet = Network.default_packet(VALIDATION_PACKET)
					Network.send_packet(peer_id, validation_packet)
				
				var login_packet = Network.default_packet("server-login-request")
				login_packet["password-required"] = server_information["password-protected"]
				Network.send_packet(peer_id, login_packet)
				
				var user_data_packet = Network.default_packet("user-data-request")
				Network.send_packet(peer_id, user_data_packet)
				return
			
		Network.CONNECTION_TYPE.PEER_DISCONNECTED:
			pass
		Network.CONNECTION_TYPE.VALID_CONNECTION:
			pass
		Network.CONNECTION_TYPE.SERVER_CLOSED:
			pass
		Network.CONNECTION_TYPE.FAILED_CONNECTION:
			pass

func network_message(data):
	match data[Network.PACKET_NAME]:
		Network.PING_PACKET_NAME:
			var ping = ping_packet(data["timestamp-recieved"], data["timestamp-sent"], data["timestamp-mode"], data["to"])
		Network.KICK_PACKET_NAME:
			if data["peer-id"] == Network.get_id():
				new_connection.emit(CONNECTION_TYPE.KICK, { "from": data["from"], "reason": data["reason"] })
		VALIDATION_PACKET:
			validation_request(data)
		VALIDATION_PACKET + "/reply":
			if not multiplayer.is_server():
				error("\'%s\' packet recieved but was not the server. " % data[Network.PACKET_NAME])
				return
			
			var peer_id = data["from"]
			var reply = validation_reply(data)
			if not verify_validation_data(reply):
				new_connection.emit(CONNECTION_TYPE.VALIDATION_FAILED, {})
				Network.kick(peer_id, "Validation failed")
				return
			new_connection.emit(CONNECTION_TYPE.VALIDATION_SUCCESS, {})
			
		"server-login-request":
			var reply_packet = Network.default_packet("server-login-request/reply")
			var password = private["password-attempt"]
			if data["password-required"]:
				reply_packet.merge({"password-attempt": password.hash()})
			
			Network.send_packet(Network.SERVER_ID, reply_packet)
		"server-login-request/reply":
			if not multiplayer.is_server():
				return
			if server_information["password-protected"]:
				var attempt = data["password-attempt"]
				var server_password = server_information["password"].hash()
				if not attempt == server_password:
					Network.kick(data["from"], "Invalid password")
					return
		"user-data-request/reply":
			var peer_id = data["from"]
			var user_data = data.duplicate(true)
			
			var packet_keys = Network.default_packet("").keys()
			for key in packet_keys:
				user_data.erase(key)
			
			connected_clients[peer_id] = user_data
			connected_clients[peer_id].merge({
				"time-connected": pending_clients[peer_id]["time-connected"],
				"time-validated": Time.get_unix_time_from_system()
			}, true)
			pending_clients.erase(peer_id)
			new_connection.emit(CONNECTION_TYPE.CONNECTED, { "peer-id": peer_id })










## Server.gd
#var udp_server = UDPServer.new()
#var udp_port = 6969
#
#func _ready():
#    udp_server.listen(udp_port, "0.0.0.0")
#    # do enetmultiplayer setup for host
#
#func _process(delta):
#    udp_server.poll()
#    if udp_server.is_connection_available():
#        var udp_peer : PacketPeerUDP = udp_server.take_connection()
#        var packet = udp_peer.get_packet()
#        print("Recieved : %s from %s:%s" %
#                [
#                    packet.get_string_from_ascii(),
#                    udp_peer.get_packet_ip(),
#                    udp_peer.get_packet_port(),
#                ]
#        )
#        # Reply to valid udp_peer with server IP address example
#        udp_peer.put_packet(IP.get_local_addresses()[0])
#
##Client.gd
#var udp_client := PacketPeerUDP.new()
#var udp_server_found = false
#var udp_requests = 3
#var delta_time = 0.0
#var udp_port = 6969
#
#func _ready():
#    udp_client.set_broadcast_enabled(true)
#    udp_client.set_destination_address("255.255.255.255", udp_port)
#
#func _process(delta):
#    delta_time += delta
#    if delta_time >= 2.0: #every 2 seconds send request
#        delta_time = 0.0
#        if not udp_server_found: # Try to contact server
#            udp_client.put_packet("Valid_Request".to_ascii())
#            udp_requests -= 1
#            if udp_requests == 0:
#                #start as server or stop sending request
#                pass
#    if udp_client.get_available_packet_count() > 0:
#        udp_server_found = true
#        var server_address_to_connect_to = udp_client.get_packet()
#        #connect to enetmultiplayer server using address
