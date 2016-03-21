_                                     = require 'lodash'
async                                 = require 'async'
debug                                 = require('debug')('meshblu-server-websocket:websocket-handler')
MeshbluWebsocket                      = require 'meshblu-websocket'
AuthenticateHandler                   = require './handlers/authenticate-handler'
UpdateAsHandler                       = require './handlers/update-as-handler'
UpdateHandler                         = require './handlers/update-handler'
WhoamiHandler                         = require './handlers/whoami-handler'
SendMessageHandler                    = require './handlers/send-message-handler'
GetAuthorizedSubscriptionTypesHandler = require './handlers/get-authorized-subscription-types-handler'

class WebsocketHandler
  constructor: ({@websocket, @jobManager, @meshbluConfig, @messengerFactory}) ->
    @EVENTS =
      authenticate: @handlerHandler AuthenticateHandler
      identity: @onIdentity
      message: @handlerHandler SendMessageHandler
      subscriptionlist: @subscriptionList
      update: @handlerHandler UpdateHandler
      updateas: @handlerHandler UpdateAsHandler
      whoami: @handlerHandler WhoamiHandler
      subscribe: @onSubscribe
      unsubscribe: @onUnsubscribe

  initialize: =>
    @websocket.on 'message', @onMessage
    @websocket.on 'close', @onClose
    @messenger = @messengerFactory.build()

    @messenger.on 'message', (channel, message) =>
      @sendFrame 'message', message

    @messenger.on 'config', (channel, message) =>
      @sendFrame 'config', message

    @messenger.on 'data', (channel, message) =>
      @sendFrame 'data', message

  handlerHandler: (handlerClass) =>
    (data) =>
      requestQueue = 'request'
      responseQueue = 'response'
      handler = new handlerClass {@jobManager, @auth, @sendFrame, requestQueue, responseQueue}
      handler.do data, (error, type, response) =>
        return @sendError error.message, [type, data], 500 if error?
        @sendFrame type, response

  # Event Listeners
  onClose: =>
    @messenger?.close()
    @upstream?.close()

  onMessage: (event) =>
    @parseFrame event.data, (error, type, data) =>
      return @sendError error.message, event.data, 500 if error?
      debug 'onMessage', error, type, data
      return @EVENTS[type] data if @EVENTS[type]?
      @upstream.send type, data if @upstream?

  onSubscribe: (data) =>
    data.types ?= ['broadcast', 'received', 'sent']
    data.types.push 'config'
    data.types.push 'data'
    requestQueue = 'request'
    responseQueue = 'response'
    handler = new GetAuthorizedSubscriptionTypesHandler {@jobManager, @auth, @sendFrame, requestQueue, responseQueue}
    handler.do data, (error, type, response) =>
      async.each response.types, (type, next) =>
        @messenger.subscribe {type, uuid: data.uuid}, next

  onUnsubscribe: (data) =>
    data.types ?= ['broadcast', 'received', 'sent']
    requestQueue = 'request'
    responseQueue = 'response'
    handler = new GetAuthorizedSubscriptionTypesHandler {@jobManager, @auth, @sendFrame, requestQueue, responseQueue}
    handler.do data, (error, type, response) =>
      async.each response.types, (type, next) =>
        @messenger.unsubscribe {type, uuid: data.uuid}, next


  # API endpoints
  onIdentity: (authData) =>
    @auth = _.pick authData, 'uuid', 'token'
    request =
      metadata:
        auth: @auth
        jobType: 'Authenticate'

    @jobManager.do 'request', 'response', request, (error, response) =>
      return @sendFrame 'error', status: 502, message: "Bad Gateway" if error?
      return @sendFrame 'error', status: 504, message: 'Gateway Timeout' unless response?
      {code,status} = response.metadata

      return @sendFrame 'notReady', message: status, status: code unless code == 204

      @connectUpstream @auth, (error) =>
        return @sendFrame 'notReady', status: 502, message: 'Bad Gateway' if error?
        @sendFrame 'ready', message: status, status: code
        async.each ['received', 'config', 'data'], (type, next) =>
          @messenger.subscribe {type, uuid: @auth.uuid}, next


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
    @upstream.on 'whoami', (data) => @sendFrame 'whoami', data
    @upstream.on 'device', (data) => @sendFrame 'device', data
    @upstream.on 'devices', (data) => @sendFrame 'devices', data
    @upstream.on 'mydevices', (data) => @sendFrame 'mydevices', data
    @upstream.on 'registered', (data) => @sendFrame 'registered', data
    @upstream.on 'updated', (data) => @sendFrame 'updated', data
    @upstream.on 'unregistered', (data) => @sendFrame 'unregistered', data
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
    debug 'sendFrame', type, data
    frame = [type, data]
    @websocket.send JSON.stringify(frame) if type?

  sendError: (message, frame, code) =>
    @sendFrame 'error', message: message, frame: frame, status: code

module.exports = WebsocketHandler
