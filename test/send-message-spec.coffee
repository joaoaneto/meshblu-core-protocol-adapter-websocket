_                = require 'lodash'
Connect          = require './connect'

describe 'sendFrame: message', ->
  beforeEach 'connect', (done) ->
    @connect = new Connect()
    @connect.connect (error, {@sut, @workerFunc, @connection}) => done(error)

  beforeEach 'connect', (done) ->
    @workerFunc.onFirstCall().yields null, {
      metadata:
        code: 204
    }

    @connection.connect (error) =>
      done error

  afterEach 'shutItDown', (done) ->
    @connect.shutItDown done

  beforeEach (done) ->
    @connection.send 'message', {}
    @connect.on 'request', (@request) => done()

  it 'should create a request', ->
    expect(@request).to.containSubset
      metadata:
        jobType: 'SendMessage'
