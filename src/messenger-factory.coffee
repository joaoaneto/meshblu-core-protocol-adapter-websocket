_ = require 'lodash'
redis   = require 'ioredis'
RedisNS = require '@octoblu/redis-ns'
MessengerManager = require 'meshblu-core-manager-messenger'

class MessengerFactory
  constructor: ({@uuidAliasResolver, @namespace, @redisUri}) ->

  build: =>
    client = _.bindAll new RedisNS @namespace, redis.createClient(@redisUri, dropBufferSupport: true)
    new MessengerManager {client, @uuidAliasResolver}

module.exports = MessengerFactory
