http = require 'http'

class SearchDevicesHandler
  constructor: ({@jobManager,@auth,@requestQueue,@responseQueue}) ->

  do: (data, callback=->) =>
    request =
      metadata:
        jobType: 'SearchDevices'
        auth: @auth
      data: data

    @jobManager.do @requestQueue, @responseQueue, request, (error, response) =>
      return callback error, 'devices' if error?
      callback null, 'devices', JSON.parse(response.rawData)

module.exports = SearchDevicesHandler
