http = require 'http'

class UnregisterHandler
  constructor: ({@jobManager,@auth,@requestQueue,@responseQueue}) ->

  do: (data, callback=->) =>
    request =
      metadata:
        jobType: 'UnregisterDevice'
        toUuid: data.uuid
        auth: @auth
      data: data

    @jobManager.do request, (error, response) =>
      return callback error, 'unregister' if error?
      callback null, 'unregistered', JSON.parse(response.rawData)

module.exports = UnregisterHandler
