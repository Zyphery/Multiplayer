extends Node

# v0.1 7/2/2023

signal new_connection(type, data)

enum CONNECTION_TYPE {
	CONNECTED,
	DISCONNECTED,
	KICK,
	BAN,
}

const api_ipv4 = "https://api.ipify.org"
const api_ipv6 = "https://api64.ipify.org"

var public_ipv4
var public_ipv6

var pending_clients
var connecting_clients
var connected_client_data
var ban_list

var server_information

var private = {}

func default_server_information() -> Dictionary:
	return {
		"server-name": "My Server",
		"public-server": true,
		"port": 21222,
		"password-protected": true,
		"password": "password123",
		"max-clients": 32,
	}

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
	private["username"] = info["username"]
	
	if not Network.join(ip, port):
		return false

func host(info : Dictionary):
	if info.is_empty():
		error("Server info is invalid")
		return false
	var port = info["port"] as int
	var upnp = info["public-server"] as bool
	var max_clients = info["max-clients"] as int
	
	server_information = info
	if not Network.host(port, true, max_clients, upnp):
		return false
	
	server_information["local-ip"] = IP.get_local_addresses()
	
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

func ban_ip(ip, reason = ""):
	pass

func ban_username(username, reason = ""):
	pass



func networkclient_connection(type, data):
	match type:
		CONNECTION_TYPE.CONNECTED:
			pass
		CONNECTION_TYPE.DISCONNECTED:
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
			if not multiplayer.is_server():
				return
			var peer_id = data["peer_id"]
			var packet = Network.default_packet("server_login_request")
			packet.merge({
				"password-request": server_information["password-protected"]
			})
			Network.send_packet.rpc_id(peer_id, packet)
		Network.CONNECTION_TYPE.PEER_DISCONNECTED:
			pass
		Network.CONNECTION_TYPE.VALID_CONNECTION:
			pass
		Network.CONNECTION_TYPE.SERVER_CLOSED:
			pass
		Network.CONNECTION_TYPE.FAILED_CONNECTION:
			pass

func network_message(data):
	if not data.has("packet_name"):
		error("Packet recieved without packet_name")
		return
	
	match data["packet_name"]:
		Network.PING_PACKET_NAME:
			var ping = ping_packet(data["timestamp_recieved"], data["timestamp_sent"], data["timestamp_mode"], data["to"])
		Network.KICK_PACKET_NAME:
			if data["peer_id"] == Network.get_id():
				new_connection.emit(CONNECTION_TYPE.KICK, {"from": data["from"], "reason": data["reason"]})
		"server_login_request":
			login_request(data)
		"server_login_request/reply":
			login_reply(data)

func login_reply(data):
	if not multiplayer.is_server():
		return
	if server_information["password-protected"]:
		var attempt = data["password-attempt"]
		var server_password = server_information["password"].hash()
		if not attempt == server_password:
			Network.kick(data["from"], "Invalid password")
		else:
			new_connection.emit(CONNECTION_TYPE.CONNECTED, data)

func login_request(server_packet : Dictionary):
	var reply_packet = Network.default_packet("server_login_request/reply")
	var password = private["password-attempt"]
	if server_packet["password-request"]:
		reply_packet.merge({"password-attempt": password.hash()})
	
	Network.send_packet.rpc_id(Network.SERVER_ID, reply_packet)

func ping_packet(time_recieved, time_sent, time_mode, peer_to) -> float:
	var ping_time = time_recieved - time_sent
	if time_mode == "usec":
		ping_time /= 1e+3
	var new_packet = Network.default_packet("update_ping")
	new_packet["ping_time"] = ping_time
	new_packet["peer_id"] = peer_to
	Network.send_packet.rpc(new_packet)
	
	return ping_time

func error(message):
	print(str(message))















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
