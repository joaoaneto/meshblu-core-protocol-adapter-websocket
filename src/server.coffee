_                = require 'lodash'
http             = require 'http'
WebSocket        = require 'faye-websocket'
WebsocketHandler = require './websocket-handler'
JobLogger        = require 'job-logger'
debug = require('debug')('meshblu-server-websocket:server')
PooledJobManager = require 'meshblu-core-pooled-job-manager'
{Pool} = require 'generic-pool'
redis   = require 'redis'
RedisNS = require '@octoblu/redis-ns'

class Server
  constructor: (options) ->
    {@disableLogging, @port, @meshbluConfig} = options
    {@connectionPoolMaxConnections, @redisUri, @namespace, @jobTimeoutSeconds} = options
    {@jobLogRedisUri, @jobLogQueue} = options

  run: (callback) =>
    @server = http.createServer()
    connectionPool = @_createConnectionPool()

    jobLogger = new JobLogger
      indexPrefix: 'metric:meshblu-server-websocket'
      type: 'meshblu-server-websocket:request'
      client: redis.createClient(@jobLogRedisUri)
      jobLogQueue: @jobLogQueue

    @jobManager = new PooledJobManager
      timeoutSeconds: @jobTimeoutSeconds
      pool: connectionPool
      jobLogger: jobLogger

    @server.on 'upgrade', @onUpgrade
    @server.listen @port, callback

  address: =>
    @server.address()

  stop: (callback) =>
    @server.close callback

  # Event Listeners
  onUpgrade: (request, socket, body) =>
    return unless WebSocket.isWebSocket request
    debug 'onUpgrade'
    websocket = new WebSocket request, socket, body
    websocketHandler = new WebsocketHandler {websocket, @jobManager, @meshbluConfig}
    websocketHandler.initialize()

  _createConnectionPool: =>
    connectionPool = new Pool
      max: @connectionPoolMaxConnections
      min: 0
      returnToHead: true # sets connection pool to stack instead of queue behavior
      create: (callback) =>
        client = _.bindAll new RedisNS @namespace, redis.createClient(@redisUri)

        client.on 'end', ->
          client.hasError = new Error 'ended'

        client.on 'error', (error) ->
          client.hasError = error
          callback error if callback?

        client.once 'ready', ->
          callback null, client
          callback = null

      destroy: (client) => client.end true
      validate: (client) => !client.hasError?

    return connectionPool

module.exports = Server
