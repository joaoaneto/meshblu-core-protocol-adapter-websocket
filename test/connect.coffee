_ = require 'lodash'
MeshbluWebsocket = require 'meshblu-websocket'
async = require 'async'
uuid    = require 'uuid'
redis = require 'ioredis'
RedisNS = require '@octoblu/redis-ns'
JobManager = require 'meshblu-core-job-manager'
Server = require '../src/server'
UpstreamMeshbluServer = require './upstream-meshblu-server'

class Connect
  constructor: ({@redisUri}={}) ->
    @jobManager = new JobManager
      client: _.bindAll new RedisNS 'ns', redis.createClient(@redisUri)
      timeoutSeconds: 1

  connect: (callback) =>
    async.series [
      @startServer
      @startUpstream
      @createConnection
      @authenticateConnection
      @authenticateUpstreamConnection
    ], (error) =>
      return callback error if error?
      callback null,
        sut: @sut
        connection: @connection
        upstreamSocket: @upstreamSocket
        device: {uuid: 'masseuse', token: 'assassin'}
        jobManager: new JobManager
          client: _.bindAll new RedisNS 'ns', redis.createClient(@redisId)
          timeoutSeconds: 1

  shutItDown: (callback) =>
    @connection.close()

    async.series [
      async.apply @upstream.stop
      async.apply @sut.stop
    ], callback

  startServer: (callback) =>
    @sut = new Server
      port: 0xcafe
      jobTimeoutSeconds: 1
      meshbluConfig:
        hostname: 'localhost'
        protocol: 'http'
        port:   0xbabe
      jobLogRedisUri: 'redis://localhost:6379'
      redisUri: 'redis://localhost:6379'
      namespace: 'ns'

    @sut.run callback

  startUpstream: (callback) =>
    @onUpstreamConnection = sinon.spy()
    @upstream = new UpstreamMeshbluServer onConnection: @onUpstreamConnection, port: 0xbabe
    @upstream.start callback

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

  authenticateUpstreamConnection: (callback) =>
    onUpstreamConnectionCalled = => @onUpstreamConnection.called
    wait = (callback) => _.delay callback, 10
    async.until onUpstreamConnectionCalled, wait, =>
      [@upstreamSocket] = @onUpstreamConnection.firstCall.args
      @upstreamSocket.send JSON.stringify(['ready'])
      callback()

module.exports = Connect
