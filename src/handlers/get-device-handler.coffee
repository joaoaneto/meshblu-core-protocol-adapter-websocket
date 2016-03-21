http = require 'http'

class GetDeviceHandler
  constructor: ({@jobManager,@auth,@requestQueue,@responseQueue}) ->

  do: (data, callback=->) =>
    request =
      metadata:
        jobType: 'GetDevice'
        toUuid: data.uuid
        auth: @auth
      data: data

    @jobManager.do @requestQueue, @responseQueue, request, (error, response) =>
      return callback error, 'device' if error?
      callback null, 'device', JSON.parse(response.rawData)

module.exports = GetDeviceHandler
