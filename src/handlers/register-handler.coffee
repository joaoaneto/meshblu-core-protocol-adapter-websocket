http = require 'http'

class RegisterHandler
  constructor: ({@jobManager,@auth,@requestQueue,@responseQueue}) ->

  do: (data, callback=->) =>
    request =
      metadata:
        jobType: 'RegisterDevice'
        toUuid: data.uuid
        auth: @auth
      data: data

    @jobManager.do @requestQueue, @responseQueue, request, (error, response) =>
      return callback error, 'register' if error?
      console.log 'response.rawData', response
      callback null, 'registered', JSON.parse(response.rawData)

module.exports = RegisterHandler
