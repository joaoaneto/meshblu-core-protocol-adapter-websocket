_ = require 'lodash'
http = require 'http'

class UpdateHandler
  constructor: ({@jobManager,@auth,@requestQueue,@responseQueue}) ->

  do: ([query, params], callback) =>
    unless _.isPlainObject params
      return callback new Error('invalid update'), 'updated'

    _.each params, (value, key) =>
      params[key] = _.omit value, ['uuid', 'token']

    request =
      metadata:
        jobType: 'UpdateDevice'
        toUuid: query.uuid
        auth: @auth
      data: params

    @jobManager.do request, (error) =>
      return callback error, 'update' if error?
      callback null, 'updated'

module.exports = UpdateHandler
