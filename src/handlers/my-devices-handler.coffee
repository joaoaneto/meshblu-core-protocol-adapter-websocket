http = require 'http'

class MyDevicesHandler
  constructor: ({@jobManager,@auth,@requestQueue,@responseQueue}) ->

  do: (data={}, callback=->) =>
    data.owner = @auth.uuid
    request =
      metadata:
        jobType: 'SearchDevices'
        auth: @auth
      data: data

    @jobManager.do @requestQueue, @responseQueue, request, (error, response) =>
      return callback error, 'mydevices' if error?
      callback null, 'mydevices', JSON.parse(response.rawData)

module.exports = MyDevicesHandler
