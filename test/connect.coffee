_                       = require 'lodash'
{EventEmitter}          = require 'events'
MeshbluWebsocket        = require 'meshblu-websocket'
async                   = require 'async'
UUID                    = require 'uuid'
Redis                   = require 'ioredis'
RedisNS                 = require '@octoblu/redis-ns'
Server                  = require '../src/server'
getPort                 = require 'get-port'

{ JobManagerResponder, JobManagerRequester } = require 'meshblu-core-job-manager'

class Connect extends EventEmitter
  constructor: ({@redisUri}={}) ->
    queueId = UUID.v4()
    @namespace = 'ns'
    @requestQueueName = "test:request:queue:#{queueId}"
    @responseQueueName = "test:response:queue:#{queueId}"
    @redisUri = 'redis://localhost'
    @workerFunc = sinon.stub()

    @jobManager = new JobManagerResponder {
      @namespace
      @redisUri
      maxConnections: 1
      jobTimeoutSeconds: 1
      queueTimeoutSeconds: 1
      jobLogSampleRate: 0
      @requestQueueName
      workerFunc: (request, callback) =>
        @emit 'request', request
        @workerFunc request, callback
    }

  connect: (callback) =>
    async.series [
      @startJobManager
      @startServer
      @createConnection
    ], (error) =>
      return callback error if error?
      callback null, {
        sut: @sut
        connection: @connection
        device: {uuid: 'masseuse', token: 'assassin'}
        @jobManager
        @workerFunc
      }

  shutItDown: (callback=_.noop) =>
    @connection.close()
    @jobManager.stop()
    @sut.stop()
    callback()

  startJobManager: (callback) =>
    @jobManager.start callback

  startServer: (callback) =>
    getPort().then (@port) =>
      @sut = new Server
        port: @port
        jobTimeoutSeconds: 1
        jobLogRedisUri: @redisUri
        jobLogQueue: 'sample-rate:0.00'
        jobLogSampleRate: 0
        maxConnections: 10
        redisUri: @redisUri
        cacheRedisUri: @redisUri
        firehoseRedisUri: @redisUri
        namespace: @namespace
        requestQueueName: @requestQueueName
        responseQueueName: @responseQueueName

      @sut.run callback
    .catch callback
    return # nothing

  createConnection: (callback) =>
    @connection = new MeshbluWebsocket
      hostname: 'localhost'
      port: @port
      uuid: 'masseuse'
      token: 'assassin'
      protocol: 'http'

    @connection.on 'notReady', (error) => throw error
    @connection.on 'error', (error) => throw error
    callback()

  authenticateConnection: (callback) =>
    @jobManager.do (@request, next) =>
      response =
        metadata:
          responseId: @request.metadata.responseId
          code: 204
      next null, response
    , callback

module.exports = Connect
