_                = require 'lodash'
Connect          = require './connect'

describe 'sendFrame: message', ->
  beforeEach (done) ->
    @connect = new Connect
    @connect.connect (error, things) =>
      return done error if error?
      {@sut,@connection,@device,@jobManager} = things
      done()

  afterEach (done) ->
    @connect.shutItDown done

  beforeEach ->
    @connection.send 'message', {}

  it 'should create a request', (done) ->
    @jobManager.getRequest (error,request) =>
      return done error if error?
      return done new Error('Request timeout') unless request?
      expect(request.metadata.jobType).to.deep.equal 'SendMessage'
      done()

  describe 'when the dispatcher responds', ->
    beforeEach (done) ->
      @jobManager.do (request, callback) =>
        return done error if error?
        return done new Error('Request timeout') unless request?

        response =
          metadata:
            responseId: request.metadata.responseId
            code: 200
          data:
            uuid: 'OHM MY!! WATT HAPPENED?? VOLTS'
        callback null, response
      , done

    it 'should not have an error', ->
      expect(@error).to.not.exist
