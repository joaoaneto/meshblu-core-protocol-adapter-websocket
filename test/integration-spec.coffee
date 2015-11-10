MeshbluWebsocket = require 'meshblu-websocket'
redis            = require 'fakeredis'
uuid             = require 'uuid'
async            = require 'async'
_                = require 'lodash'
RedisNS          = require '@octoblu/redis-ns'
JobManager       = require 'meshblu-core-job-manager'
Server           = require '../src/server'

describe 'Websocket', ->
  beforeEach (done) ->
    @redisId = uuid.v4()

    @sut = new Server
      port: 0xd00d
      timeoutSeconds: 1
      client: new RedisNS 'ns', redis.createClient(@redisId)

    @sut.run done

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
      @meshblu.on 'error', => # ignore connect error, it'll be a GATEWAY_TIMEOUT

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

      it 'should not have an error', (done) ->
        onConnectCalled = => @onConnect.called
        wait = (callback) => _.delay callback, 10

        async.until onConnectCalled, wait, =>
          [error] = @onConnect.firstCall.args
          expect(error).not.to.exist
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
