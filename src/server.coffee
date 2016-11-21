_                       = require 'lodash'
http                    = require 'http'
WebSocket               = require 'faye-websocket'
WebsocketHandler        = require './websocket-handler'
debug                   = require('debug')('meshblu-core-protocol-adapter-websocket:server')
Redis                   = require 'ioredis'
RedisNS                 = require '@octoblu/redis-ns'
MessengerManagerFactory = require 'meshblu-core-manager-messenger/factory'
UuidAliasResolver       = require 'meshblu-uuid-alias-resolver'
RateLimitChecker        = require 'meshblu-core-rate-limit-checker'
{ JobManagerRequester } = require 'meshblu-core-job-manager'
JobLogger               = require 'job-logger'

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
      @requestQueueName
      @responseQueueName
    } = options
    throw new Error 'Server constructor is missing "@namespace"' unless @namespace?
    throw new Error 'Server constructor is missing "@jobTimeoutSeconds"' unless @jobTimeoutSeconds?
    throw new Error 'Server constructor is missing "@redisUri"' unless @redisUri?
    throw new Error 'Server constructor is missing "@cacheRedisUri"' unless @cacheRedisUri?
    throw new Error 'Server constructor is missing "@firehoseRedisUri"' unless @firehoseRedisUri?
    throw new Error 'Server constructor is missing "@jobLogRedisUri"' unless @jobLogRedisUri?
    throw new Error 'Server constructor is missing "@jobLogQueue"' unless @jobLogQueue?
    throw new Error 'Server constructor is missing "@jobLogSampleRate"' unless @jobLogSampleRate?
    throw new Error 'Server constructor is missing "@requestQueueName"' unless @requestQueueName?
    throw new Error 'Server constructor is missing "@responseQueueName"' unless @responseQueueName?

  run: (callback) =>
    @server = http.createServer()

    jobLogger = new JobLogger
      client: new Redis @jobLogRedisUri, dropBufferSupport: true
      indexPrefix: 'metric:meshblu-core-protocol-adapter-websocket'
      type: 'meshblu-core-protocol-adapter-websocket:request'
      jobLogQueue: @jobLogQueue

    @jobManager = new JobManagerRequester {
      @namespace
      @redisUri
      maxConnections: 1
      @jobTimeoutSeconds
      @jobLogSampleRate
      @requestQueueName
      @responseQueueName
      queueTimeoutSeconds: @jobTimeoutSeconds
    }

    @jobManager.once 'error', (error) =>
      @panic 'fatal job manager error', 1, error

    @jobManager._do = @jobManager.do
    @jobManager.do = (request, callback) =>
      @jobManager._do request, (error, response) =>
        jobLogger.log { error, request, response }, (jobLoggerError) =>
          return callback jobLoggerError if jobLoggerError?
          callback error, response


    @jobManager.start (error) =>
      return callback error if error?
      cacheClient = new Redis @cacheRedisUri, dropBufferSupport: true

      uuidAliasClient = new RedisNS 'uuid-alias', cacheClient
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

  panic: (message, exitCode, error) =>
    error ?= new Error('generic error')
    console.error message
    console.error error?.stack
    process.exit exitCode

  stop: (callback) =>
    @jobManager.stop =>
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
