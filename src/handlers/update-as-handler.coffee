http = require 'http'

class UpdateAsHandler
  constructor: ({@jobManager,@auth,@requestQueue,@responseQueue}) ->

  do: (request, callback=->) =>
    updateDeviceRequest =
      metadata:
        jobType: 'UpdateDevice'
        toUuid: request.metadata.toUuid
        fromUuid: request.metadata.fromUuid
        auth: @auth
      data: request.data

    @jobManager.do @requestQueue, @responseQueue, updateDeviceRequest, (error, response) =>
      return callback error, 'updateas' if error?
      callback null, 'updateas', response

module.exports = UpdateAsHandler
