_ = require 'lodash'
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
      devices = JSON.parse(response.rawData)
      _.each devices, (device) =>
        delete device.token
      callback null, 'devices', devices

module.exports = SearchDevicesHandler
