_ = require 'lodash'
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
      devices = JSON.parse(response.rawData)
      _.each devices, (device) =>
        delete device.token
      callback null, 'mydevices', devices

module.exports = MyDevicesHandler
