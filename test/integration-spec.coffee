MeshbluWebsocket = require 'meshblu-websocket'
WebSocket        = require 'faye-websocket'
redis            = require 'fakeredis'
uuid             = require 'uuid'
async            = require 'async'
http             = require 'http'
_                = require 'lodash'
RedisNS          = require '@octoblu/redis-ns'
JobManager       = require 'meshblu-core-job-manager'
Server           = require '../src/server'
{Pool}           = require 'generic-pool'

describe 'Websocket', ->
  beforeEach (done) ->
    @upstreamMeshblu = new MeshbluServer port: 0xf00d
    @upstreamMeshblu.start done

  beforeEach (done) ->
    @redisId = uuid.v4()

    pool = new Pool
      max: 1
      min: 0
      create: (callback) =>
        client = new RedisNS 'ns', redis.createClient(@redisId)
        callback null, client
      destroy: (client) => client.end true

    @sut = new Server
      port: 0xd00d
      timeoutSeconds: 1
      pool: pool
      meshbluConfig:
        hostname: "localhost"
        port: 0xf00d
        protocol: 'http'

    @sut.start done

  afterEach (done) ->
    @upstreamMeshblu.stop done

  afterEach (done) ->
    @sut.stop done

  describe 'when a websocket connects with a uuid and token', ->
    beforeEach ->
      @meshblu = new MeshbluWebsocket
        hostname: 'localhost'
        port: 0xd00d
        protocol: 'ws'
        pathname: '/'
        uuid: 'laughter'
        token: 'ha-ha-ha-ha-ha-ha-halp'

      @onConnect = sinon.spy()
      @meshblu.connect @onConnect

    afterEach ->
      @meshblu.close()

    it 'should create a request in the request queue', (done) ->
      jobManager = new JobManager
        client: new RedisNS 'ns', redis.createClient(@redisId)
        timeoutSeconds: 1

      jobManager.getRequest ['request'], (error, request) =>
        return done error if error?
        expect(request.metadata.responseId).to.exist
        delete request.metadata.responseId # We don't know what its gonna be

        expect(request).to.deep.equal
          metadata:
            auth: {uuid: 'laughter', token: 'ha-ha-ha-ha-ha-ha-halp'}
            jobType: 'Authenticate'
          rawData: 'null'
        done()

    describe 'when the response is all good', ->
      beforeEach (done) ->
        jobManager = new JobManager
          client: new RedisNS 'ns', redis.createClient(@redisId)
          timeoutSeconds: 1

        jobManager.getRequest ['request'], (error, request) =>
          return done error if error?
          @responseId = request.metadata.responseId
          response =
            metadata:
              responseId: @responseId
              code: 204
              status: 'No Content'

          jobManager.createResponse 'response', response, done

      it 'should establish a connection with the upstream meshblu', (done) ->
        meshbluConnected = => @upstreamMeshblu.connected
        wait = (callback) => _.delay callback, 10

        async.until meshbluConnected, wait, =>
          expect(@upstreamMeshblu.connected).to.be.true
          done()

      describe 'when the upstream server emits ready', ->
        beforeEach (done) ->
          meshbluConnected = => @upstreamMeshblu.connected
          wait = (callback) => _.delay callback, 10
          async.until meshbluConnected, wait, =>
            @upstreamMeshblu.send 'ready'
            done()

        it 'should call the callback without error', (done) ->
          onConnectCalled = => @onConnect.called
          wait = (callback) => _.delay callback, 10

          async.until onConnectCalled, wait, =>
            [error] = @onConnect.firstCall.args
            expect(error).not.to.exist
            done()

        describe 'when device fallbacks to upstream', ->
          beforeEach (done) ->
            @upstreamMeshblu.websocket.on 'message', (event) =>
              [type, data] = JSON.parse event.data
              @upstreamMeshblu.send type, data

            @meshblu.device uuid: 'shopping-frenzy'
            @meshblu.once 'device', (@device) => done()

          it 'should have the correct uuid', ->
            expect(@device.uuid).to.equal 'shopping-frenzy'

        describe 'when devices fallbacks to upstream', ->
          beforeEach (done) ->
            @upstreamMeshblu.websocket.on 'message', (event) =>
              [type, data] = JSON.parse event.data
              @upstreamMeshblu.send type, [{uuid: 'museum-exhibit'}]

            @meshblu.devices uuid: 'shopping-frenzy'
            @meshblu.once 'devices', (@devices) => done()

          it 'should have the correct uuid', ->
            expect(_.first(@devices).uuid).to.equal 'museum-exhibit'

        describe 'when messages fallbacks to upstream', ->
          beforeEach (done) ->
            @upstreamMeshblu.websocket.on 'message', (event) =>
              [type, data] = JSON.parse event.data
              @upstreamMeshblu.send type, data

            @meshblu.message topic: 'rock-lobster'
            @meshblu.once 'message', (@message) => done()

          it 'should have the correct uuid', ->
            expect(@message.topic).to.equal 'rock-lobster'

        describe 'when mydevices fallbacks to upstream', ->
          beforeEach (done) ->
            @upstreamMeshblu.websocket.on 'message', (event) =>
              [type, data] = JSON.parse event.data
              @upstreamMeshblu.send type, [{uuid: 'egged'}]

            @meshblu.mydevices()
            @meshblu.once 'mydevices', (@devices) => done()

          it 'should have the correct uuid', ->
            expect(_.first(@devices).uuid).to.equal 'egged'

        describe 'subscriptionList', ->
          beforeEach ->
            @meshblu.send 'subscriptionlist'

          it 'should create a request', (done) ->
            jobManager = new JobManager
              client: new RedisNS 'ns', redis.createClient(@redisId)
              timeoutSeconds: 1

            jobManager.getRequest ['request'], (error,request) =>
              return done error if error?
              return done new Error('Request timeout') unless request?
              expect(request.metadata.jobType).to.deep.equal 'SubscriptionList'
              done()

          describe 'when the dispatcher responds', ->
            beforeEach (done) ->
              @meshblu.once 'subscriptionlist', (@response) => done()

              jobManager = new JobManager
                client: new RedisNS 'ns', redis.createClient(@redisId)
                timeoutSeconds: 1

              jobManager.getRequest ['request'], (error,request) =>
                return done error if error?
                return done new Error('Request timeout') unless request?

                response =
                  metadata:
                    responseId: request.metadata.responseId
                    code: 200
                  data:
                    zapped: 'OHM MY!! WATT HAPPENED?? VOLTS'
                jobManager.createResponse 'response', response, (error) =>
                  return done error if error?

            it 'should yield the response', ->
              expect(@response).to.deep.equal zapped: 'OHM MY!! WATT HAPPENED?? VOLTS'

      describe 'when the upstream server emits notReady', ->
        beforeEach (done) ->
          meshbluConnected = => @upstreamMeshblu.connected
          wait = (callback) => _.delay callback, 10
          async.until meshbluConnected, wait, =>
            @upstreamMeshblu.send 'notReady', message: 'not cool'
            done()

        it 'should call the callback with error', (done) ->
          onConnectCalled = => @onConnect.called
          wait = (callback) => _.delay callback, 10

          async.until onConnectCalled, wait, =>
            [error] = @onConnect.firstCall.args
            expect(error).to.exist
            done()

    describe 'when the response is all bad', ->
      beforeEach (done) ->
        jobManager = new JobManager
          client: new RedisNS 'ns', redis.createClient(@redisId)
          timeoutSeconds: 1

        jobManager.getRequest ['request'], (error, request) =>
          return done error if error?
          @responseId = request.metadata.responseId
          response =
            metadata:
              responseId: @responseId
              code: 403
              status: 'Forbidden'
          jobManager.createResponse 'response', response, done

      it 'should have an error', (done) ->
        onConnectCalled = => @onConnect.called
        wait = (callback) => _.delay callback, 10

        async.until onConnectCalled, wait, =>
          [error] = @onConnect.firstCall.args
          expect(=> throw error).to.throw 'Forbidden'
          done()

class MeshbluServer
  constructor: ({@port}) ->
    @connected = false
    @server = http.createServer()

  start: (callback) =>
    @server.on 'upgrade', @onUpgrade
    @server.listen @port, callback

  stop: (callback) =>
    @server.close callback

  send: (event,data) =>
    @websocket.send JSON.stringify [event,data]

  onUpgrade: (request, socket, body) =>
    return unless WebSocket.isWebSocket request
    @websocket = new WebSocket request, socket, body
    @connected = true
