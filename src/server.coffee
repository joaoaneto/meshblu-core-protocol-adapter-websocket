http             = require 'http'
WebSocket        = require 'faye-websocket'
JobManager       = require 'meshblu-core-job-manager'
WebsocketHandler = require './websocket-handler'
debug = require('debug')('meshblu-server-websocket:server')

class Server
  constructor: ({@port,@meshbluConfig,@pool,@timeoutSeconds}={}) ->
    @server = http.createServer()

  address: =>
    @server.address()

  start: (callback) =>
    @server.on 'upgrade', @onUpgrade
    @server.listen @port, callback

  stop: (callback) =>
    @server.close callback

  # Event Listeners
  onUpgrade: (request, socket, body) =>
    return unless WebSocket.isWebSocket request
    debug 'onUpgrade'
    websocket = new WebSocket request, socket, body

    websocketHandler = new WebsocketHandler {websocket, @pool, @meshbluConfig, @timeoutSeconds}
    websocketHandler.initialize()

module.exports = Server
