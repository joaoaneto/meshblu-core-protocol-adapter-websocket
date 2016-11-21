_                       = require 'lodash'
MeshbluWebsocket        = require 'meshblu-websocket'
async                   = require 'async'
UUID                    = require 'uuid'
Redis                   = require 'ioredis'
RedisNS                 = require '@octoblu/redis-ns'
Server                  = require '../src/server'
{ JobManagerResponder, JobManagerRequester } = require 'meshblu-core-job-manager'

class Connect
  constructor: ({@redisUri}={}) ->
    queueId = UUID.v4()
    @requestQueueName = "test:request:queue:#{queueId}"
    @responseQueueName = "test:response:queue:#{queueId}"
    @redisUri = 'redis://localhost'
    @namespace = 'ns'
    @jobManager = new JobManagerResponder {
      @namespace
      @redisUri
      maxConnections: 1
      jobTimeoutSeconds: 1
      queueTimeoutSeconds: 1
      jobLogSampleRate: 0
      @requestQueueName
    }

  connect: (callback) =>
    async.series [
      @startJobManager
      @startServer
      @createConnection
      @authenticateConnection
    ], (error) =>
      return callback error if error?
      jobManager = new JobManagerResponder {
        @redisUri
        @namespace
        maxConnections: 1
        jobTimeoutSeconds: 1
        queueTimeoutSeconds: 1
        jobLogSampleRate: 0
        @requestQueueName
      }

      jobManager.start (error) =>
        return callback error if error?
        callback null, {
          sut: @sut
          connection: @connection
          device: {uuid: 'masseuse', token: 'assassin'}
          jobManager
        }

  shutItDown: (callback) =>
    @connection.close()

    async.series [
      async.apply @jobManager.stop
      async.apply @sut.stop
    ], callback

  startJobManager: (callback) =>
    @jobManager.start callback

  startServer: (callback) =>
    @sut = new Server
      port: 0xcafe
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

  createConnection: (callback) =>
    @connection = new MeshbluWebsocket
      hostname: 'localhost'
      port: 0xcafe
      uuid: 'masseuse'
      token: 'assassin'
      protocol: 'http'

    @connection.on 'notReady', (error) => throw error
    @connection.on 'error', (error) => throw error
    @connection.connect =>
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
