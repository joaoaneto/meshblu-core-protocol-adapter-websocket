http = require 'http'

class UpdateAsHandler
  constructor: ({@jobManager,@auth,@requestQueue,@responseQueue}) ->

  do: ({metadata, data}, callback=->) =>
    updateDeviceRequest =
      metadata:
        jobType: 'UpdateDevice'
        toUuid: metadata.toUuid
        fromUuid: metadata.fromUuid
        auth: @auth
      data: data

    @jobManager.do @requestQueue, @responseQueue, updateDeviceRequest, (error, response) =>
      return callback error, 'updateas' if error?
      callback null, 'updateas', response

module.exports = UpdateAsHandler
