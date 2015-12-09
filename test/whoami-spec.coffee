_                = require 'lodash'
Connect          = require './connect'

describe 'sendFrame: whoami', ->
  beforeEach (done) ->
    @connect = new Connect
    @connect.connect (error, things) =>
      return done error if error?
      {@sut,@connection,@device,@jobManager} = things
      done()

  afterEach (done) ->
    @connect.shutItDown done

  beforeEach ->
    @connection.whoami()

  it 'should create a request', (done) ->
    @jobManager.getRequest ['request'], (error,request) =>
      return done error if error?
      return done new Error('Request timeout') unless request?
      expect(request.metadata.jobType).to.deep.equal 'GetDevice'
      done()

  describe 'when the dispatcher responds', ->
    beforeEach (done) ->
      @connection.once 'whoami', (@response) => done()

      @jobManager.getRequest ['request'], (error,request) =>
        return done error if error?
        return done new Error('Request timeout') unless request?

        response =
          metadata:
            responseId: request.metadata.responseId
            code: 200
          data:
            uuid: 'OHM MY!! WATT HAPPENED?? VOLTS'
        @jobManager.createResponse 'response', response, (error) =>
          return done error if error?

    it 'should yield the response', ->
      expect(@response).to.deep.equal uuid: 'OHM MY!! WATT HAPPENED?? VOLTS'
