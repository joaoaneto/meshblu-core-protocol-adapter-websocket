_          = require 'lodash'

class WebsocketHandler
  constructor: ({@websocket,@jobManager}) ->

  initialize: =>
    @websocket.on 'message', @onMessage

  # Event Listeners
  onMessage: (event) =>
    @parseFrame event.data, (error, type, data) =>
      return @identity data if type == 'identity'

  # API endpoints
  identity: (data) =>
    request =
      metadata:
        auth: data
        jobType: 'Authenticate'

    @jobManager.do 'request', 'response', request, (error, response) =>
      return @sendFrame 'error', status: 502, message: 'Bad Gateway' if error?
      return @sendFrame 'error', status: 504, message: 'Gateway Timeout' unless response?
      {code,status} = response.metadata

      type = 'notReady'
      type = 'ready' if code == 204

      @sendFrame type, message: status, status: code

  # Helpers
  parseFrame: (frame, callback) =>
    try frame = JSON.parse frame
    return callback null, frame... if _.isArray(frame) && frame.length
    callback new Error 'invalid frame, must be in the form of [type, data]'

  sendFrame: (type, data) =>
    frame = [type, data]
    @websocket.send JSON.stringify frame

module.exports = WebsocketHandler
