redis   = require 'redis'
RedisNS = require '@octoblu/redis-ns'
Server  = require './src/server'

class Command
  constructor: ->
    port = process.env.PORT ? 80
    namespace = process.env.NAMESPACE ? 'meshblu'
    redisUri  = process.env.REDIS_URI

    client = new RedisNS namespace, redis.createClient(redisUri)
    @server = new Server port: port, client: client

  run: =>
    @server.run (error) =>
      return @panic error if error?
      {address,port} = @server.address()
      console.log "listening on #{address}:#{port}"

  panic: (error) =>
    console.error error.stack
    process.exit 1

command = new Command
command.run()