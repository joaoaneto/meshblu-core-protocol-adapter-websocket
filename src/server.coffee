http             = require 'http'
WebSocket        = require 'faye-websocket'
JobManager       = require 'meshblu-core-job-manager'
WebsocketHandler = require './websocket-handler'

class Server
  constructor: ({@port,client,timeoutSeconds}={}) ->
    @server = http.createServer()
    @jobManager = new JobManager
      client: client
      timeoutSeconds: timeoutSeconds ? 30

  run: =>
    @server.on 'upgrade', @onUpgrade
    @server.listen @port

  stop: => @server.close()

  # Event Listeners
  onUpgrade: (request, socket, body) =>
    return unless WebSocket.isWebSocket request
    websocket = new WebSocket request, socket, body

    websocketHandler = new WebsocketHandler websocket: websocket, jobManager: @jobManager
    websocketHandler.initialize()

module.exports = Server
