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
MessengerFactory = require './messenger-factory'
UuidAliasResolver = require 'meshblu-uuid-alias-resolver'

class Server
  constructor: (options) ->
    {@disableLogging, @port, @meshbluConfig, @aliasServerUri} = options
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

    uuidAliasClient = _.bindAll new RedisNS 'uuid-alias', redis.createClient(@redisUri)
    uuidAliasResolver = new UuidAliasResolver
      cache: uuidAliasResolver
      aliasServerUri: @aliasServerUri

    @messengerFactory = new MessengerFactory {uuidAliasResolver, @redisUri, @namespace}

    @server.on 'request', @onRequest
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
    websocketHandler = new WebsocketHandler {websocket, @jobManager, @meshbluConfig, @messengerFactory}
    websocketHandler.initialize()

  onRequest: (request, response) =>
    if request.url == '/healthcheck'
      response.writeHead 200
      response.write JSON.stringify online: true
      response.end()
      return

    response.writeHead 404
    response.end()

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
