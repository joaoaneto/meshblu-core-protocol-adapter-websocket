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
RateLimitChecker        = require 'meshblu-core-rate-limit-checker'

class Server
  constructor: (options) ->
    {
      @disableLogging
      @port
      @aliasServerUri
      @maxConnections
      @redisUri
      @cacheRedisUri
      @firehoseRedisUri
      @namespace
      @jobTimeoutSeconds
      @jobLogRedisUri
      @jobLogQueue
      @jobLogSampleRate
    } = options
    throw new Error 'Server constructor is missing "@namespace"' unless @namespace?
    throw new Error 'Server constructor is missing "@jobTimeoutSeconds"' unless @jobTimeoutSeconds?
    throw new Error 'Server constructor is missing "@redisUri"' unless @redisUri?
    throw new Error 'Server constructor is missing "@cacheRedisUri"' unless @cacheRedisUri?
    throw new Error 'Server constructor is missing "@firehoseRedisUri"' unless @firehoseRedisUri?
    throw new Error 'Server constructor is missing "@jobLogRedisUri"' unless @jobLogRedisUri?
    throw new Error 'Server constructor is missing "@jobLogQueue"' unless @jobLogQueue?
    throw new Error 'Server constructor is missing "@jobLogSampleRate"' unless @jobLogSampleRate?

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

    cacheClient = redis.createClient @cacheRedisUri, dropBufferSupport: true

    uuidAliasClient = _.bindAll new RedisNS 'uuid-alias', cacheClient
    uuidAliasResolver = new UuidAliasResolver
      cache: uuidAliasResolver
      aliasServerUri: @aliasServerUri

    @messengerManagerFactory = new MessengerManagerFactory {uuidAliasResolver, @namespace, redisUri: @firehoseRedisUri}

    rateLimitCheckerClient = new RedisNS 'meshblu-count', cacheClient
    @rateLimitChecker = new RateLimitChecker client: rateLimitCheckerClient

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
    websocketHandler = new WebsocketHandler {
      websocket
      @jobManager
      @messengerManagerFactory
      @rateLimitChecker
    }
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
