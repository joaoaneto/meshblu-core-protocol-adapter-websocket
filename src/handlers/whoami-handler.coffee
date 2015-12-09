class WhoamiHandler
  constructor: ({@jobManager,@auth,@requestQueue,@responseQueue}) ->

  do: (data, callback=->) =>
    request =
      metadata:
        jobType: 'GetDevice'
        toUuid: @auth.uuid
        fromUuid: @auth.uuid
        auth: @auth

    @jobManager.do @requestQueue, @responseQueue, request, (error, response) =>
      return callback error  if error?
      device = JSON.parse response.rawData if response.rawData?
      callback null, 'whoami', device

module.exports = WhoamiHandler
