http             = require 'http'
WebSocket        = require 'faye-websocket'
JobManager       = require 'meshblu-core-job-manager'
WebsocketHandler = require './websocket-handler'
debug = require('debug')('meshblu-server-websocket:server')

class Server
  constructor: ({@port,@meshbluConfig,client,timeoutSeconds}={}) ->
    @server = http.createServer()
    @jobManager = new JobManager
      client: client
      timeoutSeconds: timeoutSeconds ? 30

  address: =>
    @server.address()

  run: (callback=->) =>
    @server.on 'upgrade', @onUpgrade
    @server.listen @port, callback

  stop: (callback=->) =>
    @server.close callback

  # Event Listeners
  onUpgrade: (request, socket, body) =>
    debug 'onUpgrade'
    return unless WebSocket.isWebSocket request
    websocket = new WebSocket request, socket, body

    websocketHandler = new WebsocketHandler
      websocket: websocket
      jobManager: @jobManager
      meshbluConfig: @meshbluConfig
    websocketHandler.initialize()

module.exports = Server
