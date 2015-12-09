JobManager = require 'meshblu-core-job-manager'

class PooledJobManager
  constructor: ({@pool,@timeoutSeconds}) ->

  do: (requestQueue, responseQueue, request, callback) =>
    @pool.acquire (error, client) =>
      return callback error if error?
      jobManager = new JobManager client: client, timeoutSeconds: @timeoutSeconds
      jobManager.do requestQueue, responseQueue, request, (error, response) =>
        @pool.release client
        callback error, response

module.exports = PooledJobManager
