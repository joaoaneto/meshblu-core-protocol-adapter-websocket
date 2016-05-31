_                     = require 'lodash'
http                  = require 'http'
WebSocket             = require 'faye-websocket'
WebsocketHandler      = require './websocket-handler'
debug                 = require('debug')('meshblu-core-protocol-adapter-websocket:server')
RedisPooledJobManager = require 'meshblu-core-redis-pooled-job-manager'
redis                 = require 'ioredis'
RedisNS               = require '@octoblu/redis-ns'
MessengerFactory      = require './messenger-factory'
UuidAliasResolver     = require 'meshblu-uuid-alias-resolver'

class Server
  constructor: (options) ->
    {@disableLogging, @port, @aliasServerUri} = options
    {@maxConnections, @redisUri, @namespace, @jobTimeoutSeconds} = options
    {@jobLogRedisUri, @jobLogQueue, @jobLogSampleRate} = options

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
    websocketHandler = new WebsocketHandler {websocket, @jobManager, @messengerFactory}
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
