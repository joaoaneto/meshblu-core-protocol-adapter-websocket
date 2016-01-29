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
    meshbluConfig = new MeshbluConfig().toJSON()

    @server = new Server {
      port
      namespace
      meshbluConfig
      jobTimeoutSeconds: timeoutSeconds
      jobLogRedisUri
      jobLogQueue
      redisUri
      connectionPoolMaxConnections
    }

  run: =>
    @server.run (error) =>
      return @panic error if error?
      {address,port} = @server.address()
      console.log "listening on #{address}:#{port}"

    process.on 'SIGTERM', =>
      console.log 'SIGTERM received, shutting down'
      @server.stop =>
        process.exit 0

  panic: (error) =>
    console.error error.stack
    process.exit 1

command = new Command
command.run()
