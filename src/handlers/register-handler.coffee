_ = require 'lodash'
http = require 'http'

class RegisterHandler
  constructor: ({@jobManager,@auth,@requestQueue,@responseQueue}) ->

  do: (data, callback=->) =>
    if data.owner?
      data.discoverWhitelist ?= []
      data.configureWhitelist ?= []
      data.discoverWhitelist.push(data.owner) unless _.includes(data.discoverWhitelist, '*')
      data.configureWhitelist.push(data.owner) unless _.includes(data.configureWhitelist, '*')

    data.discoverWhitelist ?= ['*']
    data.configureWhitelist ?= ['*']
    data.sendWhitelist ?= ['*']
    data.receiveWhitelist ?= ['*']

    request =
      metadata:
        jobType: 'RegisterDevice'
        toUuid: data.uuid
        auth: @auth
      data: data

    @jobManager.do @requestQueue, @responseQueue, request, (error, response) =>
      return callback error, 'register' if error?
      callback null, 'registered', JSON.parse(response.rawData)

module.exports = RegisterHandler
