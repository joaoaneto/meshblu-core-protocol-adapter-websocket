_                = require 'lodash'
UUID             = require 'uuid'
Connect          = require './connect'
Server           = require '../src/server'
MeshbluWebsocket = require 'meshblu-websocket'
{JobManagerResponder} = require 'meshblu-core-job-manager'

describe 'sendFrame: authenticate', ->
  beforeEach 'connect', (done) ->
    @connect = new Connect()
    @connect.connect (error, {@sut, @workerFunc, @connection}) => done(error)

  beforeEach 'send authenticate request', (done) ->
    @workerFunc.yields null, {
      metadata:
        code: 204
    }

    @connection.connect (error) =>
      console.log 'connected'
      done error

  afterEach 'shutItDown', (done) ->
    @connect.shutItDown done
    
  it 'should create a request', ->
    expect(@workerFunc.firstCall.args[0]).to.containSubset
      metadata:
        jobType: 'Authenticate'
        auth:
          uuid: 'masseuse'
          token: 'assassin'
