_ = require 'lodash'
http = require 'http'

class UpdateHandler
  constructor: ({@jobManager,@auth,@requestQueue,@responseQueue}) ->

  do: (request, callback=->) =>
    unless _.isPlainObject request.data
      return callback new Error error: 'invalid update'

    request.data = _.omit request.data, ['uuid', 'token']

    updateDeviceRequest =
      metadata:
        jobType: 'UpdateDevice'
        toUuid: @auth.uuid
        fromUuid: @auth.uuid
        auth: @auth
      data: request.data

    @jobManager.do @requestQueue, @responseQueue, updateDeviceRequest, (error) =>
      return callback error, 'update' if error?
      callback null, 'updated'

module.exports = UpdateHandler
