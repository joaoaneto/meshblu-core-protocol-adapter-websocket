http = require 'http'
WebSocket        = require 'faye-websocket'

class UpstreamMeshbluServer
  constructor: ({@port,@onConnection}) ->
    @connected = false
    @server = http.createServer()

  start: (callback) =>
    @server.on 'upgrade', @onUpgrade
    @server.listen @port, callback

  stop: (callback) =>
    @server.close callback

  send: (event,data) =>
    @websocket.send JSON.stringify [event,data]

  onUpgrade: (request, socket, body) =>
    return unless WebSocket.isWebSocket request
    @websocket = new WebSocket request, socket, body
    @connected = true
    @onConnection @websocket

module.exports = UpstreamMeshbluServer
