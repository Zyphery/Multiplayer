extends Node

# v0.0.1 - 6/25/2023
# v0.0.2 - 6/27/2023
# v0.0.3 - 7/2/2023
# v0.0.4 - 7/5/2023

signal new_connection(type, data)
signal message_recieved(data)

enum CONNECTION_TYPE {
	HOST = 0,
	
	CONNECTED,
	DISCONNECTED,
	
	VALID_CONNECTION,
	FAILED_CONNECTION,
	
	PEER_CONNECTED,
	PEER_DISCONNECTED,

	SERVER_CLOSED
}

const VERSION = "0.0.4"

const PING_MICROSECOND = true
const PING_CHANNEL = 1
const PING_PACKET_NAME = "ping"

const KICK_PACKET_NAME = "kick"

const SERVER_ID = 1

var enet_peer = ENetMultiplayerPeer.new()
var upnp : UPNP = null
var port_mapped : int

func _ready():
	multiplayer.connected_to_server.connect(on_connection_success)
	multiplayer.connection_failed.connect(on_connection_fail)
	multiplayer.server_disconnected.connect(on_server_disconnect)

func host(server_port = 21222, create_client = true, max_clients = 32, enable_upnp = true) -> bool:
	port_mapped = 0
	
	var err = enet_peer.create_server(server_port, max_clients)
	if err or enet_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		printerr("Unable to create server: ", error_string(err))
		disconnect_self()
		return false
	
	multiplayer.multiplayer_peer = enet_peer
	
	if not multiplayer.peer_connected.is_connected(on_new_client): multiplayer.peer_connected.connect(on_new_client)
	if not multiplayer.peer_disconnected.is_connected(on_remove_client): multiplayer.peer_disconnected.connect(on_remove_client)
	
	if enable_upnp:
		if !upnp_setup(server_port):
			printerr("Unable to setup UPNP")
			close_upnp(server_port)
			disconnect_self()
			return false
	
	if create_client:
		add_client(enet_peer.get_unique_id(), false)
	port_mapped = server_port
	
	new_connection.emit(CONNECTION_TYPE.HOST, { "ip": upnp.query_external_address() if enable_upnp else "localhost" })
	return true

func join(ip : String, port : int) -> bool:
	var err = enet_peer.create_client(ip, port)
	if err or enet_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		printerr("Unable to create client: ", error_string(err))
		disconnect_self()
		return false
	
	multiplayer.multiplayer_peer = enet_peer
	return true

@rpc("authority")
func kick(peer_id : int, reason = "") -> bool:
	if peer_id == 0 or peer_id == get_id() or enet_peer.get_peer(peer_id).get_state() != ENetPacketPeer.STATE_CONNECTED:
		return false
	
	var kick_packet = default_packet(KICK_PACKET_NAME)
	kick_packet["from"] = get_id()
	kick_packet["peer_id"] = peer_id
	kick_packet["reason"] = reason
	
	send_packet.rpc(kick_packet)
	send_packet.call_deferred(kick_packet)
	
	var message = {}
	while not (message.has("packet_name") and message["packet_name"] == KICK_PACKET_NAME):
		message = await message_recieved
	
	disconnect_self.rpc_id(peer_id)
	return true

@rpc("authority")
func disconnect_self():
	await on_remove_client(get_id())
	enet_peer.close()


@rpc("authority")
func add_client(peer_id, emit = true):
	if emit:
		new_connection.emit(CONNECTION_TYPE.PEER_CONNECTED if peer_id != get_id() else CONNECTION_TYPE.CONNECTED, { "peer_id": peer_id })

@rpc("authority")
func remove_client(peer_id):
	if peer_id != 0:
		new_connection.emit(CONNECTION_TYPE.PEER_DISCONNECTED if peer_id != get_id() else CONNECTION_TYPE.DISCONNECTED, { "peer_id": peer_id })



func on_new_client(peer_id):
	add_client.rpc(peer_id)
	add_client(peer_id)

func on_remove_client(peer_id):
	remove_client.rpc(peer_id)
	remove_client(peer_id)

func on_server_disconnect():
	disconnect_self()
	new_connection.emit(CONNECTION_TYPE.SERVER_CLOSED, {})

func on_connection_fail():
	disconnect_self()
	new_connection.emit(CONNECTION_TYPE.FAILED_CONNECTION, {})

func on_connection_success():
	new_connection.emit(CONNECTION_TYPE.VALID_CONNECTION, {})




func default_packet(packet_name : String):
	return { 
		"packet_name": packet_name,
		"from": get_id(),
		"timestamp_unix" : Time.get_unix_time_from_system()
	}

@rpc("any_peer")
func send_packet(packet : Dictionary):
	message_recieved.emit(packet)



# Ping using usec (microseconds)

@rpc("any_peer", "call_local", "reliable", PING_CHANNEL)
func rpc_pong_usec(packet, send_reply): # recieve packet
	packet["timestamp_recieved"] = Time.get_ticks_usec()
	message_recieved.emit(packet)
	if send_reply:
		rpc_ping_reply.rpc_id(packet["to"], packet)

@rpc("any_peer", "call_local", "reliable", PING_CHANNEL)
func rpc_ping_usec(packet, send_reply): # send packet
	rpc_pong_usec.rpc_id(packet["from"], packet, send_reply)

func ping_usec(peer_id, send_reply):
	var packet = default_packet(PING_PACKET_NAME)
	packet.merge({
		"from": get_id(),
		"to": peer_id,
		"timestamp_mode": "usec",
		"timestamp_sent": Time.get_ticks_usec()
		})
	rpc_ping_usec.rpc_id(peer_id, packet, send_reply)

# Ping using msec (milliseconds)

@rpc("any_peer", "call_local", "reliable", PING_CHANNEL)
func rpc_pong_msec(packet, send_reply): # recieve packet
	packet["timestamp_recieved"] = Time.get_ticks_msec()
	message_recieved.emit(packet)
	if send_reply:
		rpc_ping_reply.rpc_id(packet["to"], packet)

@rpc("any_peer", "call_local", "reliable", PING_CHANNEL)
func rpc_ping_msec(packet, send_reply): # send packet
	rpc_pong_msec.rpc_id(packet["from"], packet, send_reply)

func ping_msec(peer_id, send_reply):
	var packet = default_packet(PING_PACKET_NAME)
	packet.merge({
		"from": get_id(),
		"to": peer_id,
		"timestamp_mode": "msec",
		"timestamp_sent": Time.get_ticks_usec()
		})
	rpc_ping_msec.rpc_id(peer_id, packet, send_reply)

@rpc("any_peer", "call_remote", "reliable", PING_CHANNEL)
func rpc_ping_reply(packet):
	message_recieved.emit(packet)

func ping(peer_id, send_reply = true):
	if peer_id == get_id():
		printerr("Cannot ping yourself")
		return
	ping_usec(peer_id, send_reply) if PING_MICROSECOND else ping_msec(peer_id, send_reply)




func get_id() -> int:
	return multiplayer.get_unique_id()

func upnp_setup(server_port : int) -> bool:
	var upnpresult_to_str = func(error : int) -> String:
		const errors = ["Sucess", "Not authorized", "Port mapping not found", "Inconsistent parameters", "No such entry in array",
			"Action failed", "SRC IP wildcard not permitted", "Ext port wildcard not permitted", "Int port wildcard not permitted",
			"Remote host must be wildcard", "Ext port must be wildcard", "No port maps available", "Conflict with other mechanism",
			"Conflict with other mapping", "Same port values required", "Only permanent lease supported", "Invalid gateway",
			"Invalid port", "Invalid protocol", "Invalid duration", "Invalid args", "Invalid response", "Invalid parameter",
			"HTTP error", "Socket error", "Memory allocation error", "No gateway", "No devices", "Unknown error"]
		return errors[error]
	
	upnp = UPNP.new()
	
	var discover_result = upnp.discover()
	if discover_result != UPNP.UPNP_RESULT_SUCCESS:
		printerr("UPNP Discover Failed! %s" % upnpresult_to_str.call(discover_result))
		return false
	
	if !(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway()):
		printerr("UPNP Invalid Gateway!")
		return false
	
	var map_result_tcp = upnp.add_port_mapping(server_port, 0, "Godot_UDP", "TCP", 0)
	var map_result_udp = upnp.add_port_mapping(server_port, 0, "Godot_UDP", "UDP", 0)
	
	if map_result_udp != UPNP.UPNP_RESULT_SUCCESS:
		printerr("UPNP UDP Port Mapping Failed! %s" % upnpresult_to_str.call(map_result_udp))
		return false
	if map_result_tcp != UPNP.UPNP_RESULT_SUCCESS:
		printerr("UPNP TCP Port Mapping Failed! %s" % upnpresult_to_str.call(map_result_tcp))
		return false
	return true

func close_upnp(server_port):
	upnp.delete_port_mapping(server_port, "TCP")
	upnp.delete_port_mapping(server_port, "UDP")
	upnp = null
