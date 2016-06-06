_                       = require 'lodash'
http                    = require 'http'
WebSocket               = require 'faye-websocket'
WebsocketHandler        = require './websocket-handler'
debug                   = require('debug')('meshblu-core-protocol-adapter-websocket:server')
RedisPooledJobManager   = require 'meshblu-core-redis-pooled-job-manager'
redis                   = require 'ioredis'
RedisNS                 = require '@octoblu/redis-ns'
MessengerManagerFactory = require 'meshblu-core-manager-messenger/factory'
UuidAliasResolver       = require 'meshblu-uuid-alias-resolver'

class Server
  constructor: (options) ->
    {
      @disableLogging
      @port
      @aliasServerUri
      @maxConnections
      @redisUri
      @firehoseRedisUri
      @namespace
      @jobTimeoutSeconds
      @jobLogRedisUri
      @jobLogQueue
      @jobLogSampleRate
    } = options

  run: (callback) =>
    @server = http.createServer()

    @jobManager = new RedisPooledJobManager {
      jobLogIndexPrefix: 'metric:meshblu-core-protocol-adapter-websocket'
      jobLogType: 'meshblu-core-protocol-adapter-websocket:request'
      @jobTimeoutSeconds
      @jobLogQueue
      @jobLogRedisUri
      @jobLogSampleRate
      @maxConnections
      @redisUri
      @namespace
    }

    uuidAliasClient = _.bindAll new RedisNS 'uuid-alias', redis.createClient(@redisUri, dropBufferSupport: true)
    uuidAliasResolver = new UuidAliasResolver
      cache: uuidAliasResolver
      aliasServerUri: @aliasServerUri

    @messengerManagerFactory = new MessengerManagerFactory {uuidAliasResolver, @namespace, redisUri: @firehoseRedisUri}

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
    websocketHandler = new WebsocketHandler {websocket, @jobManager, @messengerManagerFactory}
    websocketHandler.initialize()

  onRequest: (request, response) =>
    if request.url == '/healthcheck'
      response.writeHead 200
      response.write JSON.stringify online: true
      response.end()
      return

    response.writeHead 404
    response.end()

module.exports = Server
