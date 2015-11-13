_          = require 'lodash'
MeshbluWebsocket = require 'meshblu-websocket'

class WebsocketHandler
  constructor: ({@jobManager,@meshbluConfig,@websocket}) ->
    @EVENTS =
      'identity': @identity
      'subscriptionlist': @subscriptionList

  initialize: =>
    @websocket.on 'message', @onMessage
    @websocket.on 'close', @onClose

  # Event Listeners
  onClose: =>
    @upstream?.close()

  onMessage: (event) =>
    @parseFrame event.data, (error, type, data) =>
      return @EVENTS[type] data if @EVENTS[type]?
      @upstream.send type, data if @upstream?

  # API endpoints
  identity: (authData) =>
    request =
      metadata:
        auth: authData
        jobType: 'Authenticate'

    @jobManager.do 'request', 'response', request, (error, response) =>
      return @sendFrame 'error', status: 502, message: 'Bad Gateway' if error?
      return @sendFrame 'error', status: 504, message: 'Gateway Timeout' unless response?
      {code,status} = response.metadata

      return @sendFrame 'notReady', message: status, status: code unless code == 204

      @connectUpstream authData, (error) =>
        return @sendFrame 'notReady', status: 502, message: 'Bad Gateway' if error?
        @sendFrame 'ready', message: status, status: code

  subscriptionList: =>
    request = metadata: {jobType: 'SubscriptionList'}
    @jobManager.do 'request', 'response', request, (error, jobResponse) =>
      return @sendFrame 'error', status: 502, message: 'Bad Gateway', frame: ['subscriptionlist'] if error?
      {metadata,rawData} = jobResponse
      return @sendFrame 'error', status: metadata.code, message: metadata.status if metadata.code != 200
      @sendFrame 'subscriptionlist', JSON.parse(rawData)

  # Helpers
  connectUpstream: (authData, callback) =>
    options = _.extend {}, authData, @meshbluConfig

    @upstream = new MeshbluWebsocket options
    @upstream.on 'whoami', (device) => @sendFrame 'whoami', device
    @upstream.on 'device', (device) => @sendFrame 'device', device
    @upstream.on 'devices', (devices) => @sendFrame 'devices', devices
    @upstream.on 'message', (message) => @sendFrame 'message', message
    @upstream.on 'mydevices', (devices) => @sendFrame 'mydevices', devices
    @upstream.on 'registered', (device) => @sendFrame 'registered', device
    @upstream.on 'updated', (device) => @sendFrame 'updated', device
    @upstream.on 'unregistered', (device) => @sendFrame 'unregistered', device
    @upstream.on 'subscribe', => @sendFrame 'subscribe'
    @upstream.on 'unsubscribe', => @sendFrame 'unsubscribe'
    @upstream.on 'error', (error) =>
      delete @upstream
      @sendFrame 'error', message: error.message, code: 502
      @websocket.close()
    @upstream.connect callback

  parseFrame: (frame, callback) =>
    try frame = JSON.parse frame
    return callback null, frame... if _.isArray(frame) && frame.length
    callback new Error 'invalid frame, must be in the form of [type, data]'

  sendFrame: (type, data) =>
    frame = [type, data]
    @websocket.send JSON.stringify frame

module.exports = WebsocketHandler
