_      = require 'lodash'
Server = require './src/server'
UUID   = require 'uuid'

class Command
  constructor: ->
    @serverOptions =
      port                 : process.env.PORT ? 80
      namespace            : process.env.NAMESPACE ? 'meshblu'
      jobTimeoutSeconds    : parseInt(process.env.JOB_TIMEOUT_SECONDS ? 30)
      jobLogRedisUri       : process.env.JOB_LOG_REDIS_URI ? process.env.REDIS_URI
      jobLogSampleRate     : parseFloat(process.env.JOB_LOG_SAMPLE_RATE ? 0)
      jobLogQueue          : process.env.JOB_LOG_QUEUE ? 'sample-rate:1.00'
      redisUri             : process.env.REDIS_URI
      firehoseRedisUri     : process.env.FIREHOSE_REDIS_URI ? process.env.REDIS_URI
      cacheRedisUri        : process.env.CACHE_REDIS_URI ? process.env.REDIS_URI
      aliasServerUri       : process.env.ALIAS_SERVER_URI ? ''
      maxConnections       : parseInt(process.env.REDIS_MAX_CONNECTIONS ? 100)
      requestQueueName     : process.env.REQUEST_QUEUE_NAME ? 'v2:request:queue'
      responseQueueBaseName: process.env.RESPONSE_QUEUE_BASE_NAME ? 'v2:response:queue'

  run: =>
    @panic new Error('Missing required environment variable: REDIS_URI') if _.isEmpty @serverOptions.redisUri
    @panic new Error('Missing required environment variable: FIREHOSE_REDIS_URI') if _.isEmpty @serverOptions.firehoseRedisUri
    @panic new Error('Missing required environment variable: CACHE_REDIS_URI') if _.isEmpty @serverOptions.cacheRedisUri
    @panic new Error('Missing required environment variable: JOB_LOG_REDIS_URI') if _.isEmpty @serverOptions.jobLogRedisUri
    @panic new Error('Missing required environment variable: JOB_LOG_QUEUE') if _.isEmpty @serverOptions.jobLogQueue
    @panic new Error('Missing required environment variable: JOB_LOG_SAMPLE_RATE') unless @serverOptions.jobLogSampleRate?
    @panic new Error('Missing environment variable: REQUEST_QUEUE_NAME') if _.isEmpty @serverOptions.requestQueueName
    @panic new Error('Missing environment variable: RESPONSE_QUEUE_BASE_NAME') if _.isEmpty @serverOptions.responseQueueBaseName

    responseQueueId = UUID.v4()
    @serverOptions.responseQueueName = "#{@serverOptions.responseQueueBaseName}:#{responseQueueId}"

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
