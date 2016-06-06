_       = require 'lodash'
Server  = require './src/server'

class Command
  constructor: ->
    @serverOptions =
      port             : process.env.PORT ? 80
      namespace        : process.env.NAMESPACE ? 'meshblu'
      jobTimeoutSeconds: parseInt(process.env.JOB_TIMEOUT_SECONDS ? 30)
      jobLogRedisUri   : process.env.JOB_LOG_REDIS_URI
      jobLogSampleRate : parseFloat(process.env.JOB_LOG_SAMPLE_RATE)
      jobLogQueue      : process.env.JOB_LOG_QUEUE
      redisUri         : process.env.REDIS_URI
      firehoseRedisUri : process.env.FIREHOSE_REDIS_URI
      aliasServerUri   : process.env.ALIAS_SERVER_URI
      maxConnections   : parseInt(process.env.REDIS_MAX_CONNECTIONS ? 100)

  run: =>
    @panic new Error('Missing required environment variable: REDIS_URI') if _.isEmpty @serverOptions.redisUri
    @panic new Error('Missing required environment variable: FIREHOSE_REDIS_URI') if _.isEmpty @serverOptions.firehoseRedisUri
    @panic new Error('Missing required environment variable: JOB_LOG_REDIS_URI') if _.isEmpty @serverOptions.jobLogRedisUri
    @panic new Error('Missing required environment variable: JOB_LOG_QUEUE') if _.isEmpty @serverOptions.jobLogQueue
    @panic new Error('Missing required environment variable: JOB_LOG_SAMPLE_RATE') unless @serverOptions.jobLogSampleRate?

    server = new Server @serverOptions
    server.run (error) =>
      return @panic error if error?
      {address,port} = server.address()
      console.log "listening on #{address}:#{port}"

    process.on 'SIGTERM', =>
      console.log 'SIGTERM received, shutting down'
      server.stop =>
        process.exit 0

  panic: (error) =>
    console.error error.stack
    process.exit 1

command = new Command
command.run()
