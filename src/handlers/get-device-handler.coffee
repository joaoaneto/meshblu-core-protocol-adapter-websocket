_ = require 'lodash'
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

    @jobManager.do request, (error, response) =>
      return callback error, 'device' if error?
      device = JSON.parse(response.rawData)
      delete device.token
      callback null, 'device', device

module.exports = GetDeviceHandler
