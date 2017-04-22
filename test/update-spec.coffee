_                = require 'lodash'
Connect          = require './connect'

describe 'sendFrame: update', ->
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
    @workerFunc.onSecondCall().yields null, {
      metadata:
        code: 200
      rawData: JSON.stringify uuid: 'OHM MY!! WATT HAPPENED?? VOLTS'
    }

    @connect.on 'request', (@request) =>
    @connection.once 'updated', (@response) => done()
    @connection.send 'update',[{uuid: 'to-uuid'}, { uuid: 'to-uuid', foo: 'bar' }]

  it 'should create a request', ->
    expect(@request.metadata.jobType).to.deep.equal 'UpdateDevice'
