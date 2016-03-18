_       = require 'lodash'
Server  = require './src/server'
MeshbluConfig = require 'meshblu-config'

class Command
  constructor: ->
    port = process.env.PORT ? 80
    namespace = process.env.NAMESPACE ? 'meshblu'
    redisUri  = process.env.REDIS_URI
    jobLogRedisUri  = process.env.JOB_LOG_REDIS_URI
    jobLogQueue  = process.env.JOB_LOG_QUEUE
    connectionPoolMaxConnections = parseInt(process.env.REDIS_MAX_CONNECTIONS ? 100)
    timeoutSeconds = parseInt(process.env.JOB_TIMEOUT_SECONDS ? 30)
    aliasServerUri = process.env.ALIAS_SERVER_URI
    meshbluConfig = new MeshbluConfig().toJSON()

    @serverOptions = {
      port
      namespace
      meshbluConfig
      jobTimeoutSeconds: timeoutSeconds
      jobLogRedisUri
      jobLogQueue
      redisUri
      connectionPoolMaxConnections
      aliasServerUri
    }

  run: =>
    @panic new Error('Missing required environment variable: REDIS_URI') if _.isEmpty @serverOptions.redisUri
    @panic new Error('Missing required environment variable: JOB_LOG_REDIS_URI') if _.isEmpty @serverOptions.jobLogRedisUri
    @panic new Error('Missing required environment variable: JOB_LOG_QUEUE') if _.isEmpty @serverOptions.jobLogQueue

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
