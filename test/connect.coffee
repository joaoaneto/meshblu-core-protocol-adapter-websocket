_ = require 'lodash'
MeshbluWebsocket = require 'meshblu-websocket'
async = require 'async'
uuid    = require 'uuid'
redis = require 'ioredis'
RedisNS = require '@octoblu/redis-ns'
JobManager = require 'meshblu-core-job-manager'
Server = require '../src/server'

class Connect
  constructor: ({@redisUri}={}) ->
    @jobManager = new JobManager
      client: _.bindAll new RedisNS 'ns', redis.createClient(@redisUri, dropBufferSupport: true)
      timeoutSeconds: 1

  connect: (callback) =>
    async.series [
      @startServer
      @createConnection
      @authenticateConnection
    ], (error) =>
      return callback error if error?
      callback null,
        sut: @sut
        connection: @connection
        device: {uuid: 'masseuse', token: 'assassin'}
        jobManager: new JobManager
          client: _.bindAll new RedisNS 'ns', redis.createClient(@redisId, dropBufferSupport: true)
          timeoutSeconds: 1

  shutItDown: (callback) =>
    @connection.close()

    async.series [
      async.apply @sut.stop
    ], callback

  startServer: (callback) =>
    @sut = new Server
      port: 0xcafe
      jobTimeoutSeconds: 1
      jobLogRedisUri: 'redis://localhost:6379'
      jobLogQueue: 'sample-rate:0.00'
      jobLogSampleRate: 0
      maxConnections: 10
      redisUri: 'redis://localhost:6379'
      cacheRedisUri: 'redis://localhost:6379'
      firehoseRedisUri: 'redis://localhost:6379'
      namespace: 'ns'

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
    @jobManager.getRequest ['request'], (error, @request) =>
      return callback error if error?

      response =
        metadata:
          responseId: @request.metadata.responseId
          code: 204

      @jobManager.createResponse 'response', response, callback

module.exports = Connect
