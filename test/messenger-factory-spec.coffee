_                = require 'lodash'
async            = require 'async'
MessengerFactory = require '../src/messenger-factory'

describe 'When constructed', ->
  beforeEach ->
    @namespace = 'blowing-things-up'
    @redisUri = 'redis://localhost:6379'
    @uuidAliasResolver =
      resolve: (uuid, callback) =>
        callback null, uuid

    @sut = new MessengerFactory {@uuidAliasResolver, @namespace, @redisUri}

  describe 'a messenger is built', ->
    beforeEach ->
      @messenger = @sut.build()

    # afterEach (done) ->
    #   @messenger.close done

    describe 'when unsubscribe is called on that messenger', ->
      beforeEach (done) ->
        async.each ['hallo', 'poppet', 'asdwgwe'], (type, next) =>
          try
            @messenger.unsubscribe {type, uuid: 'some-random-uuid'}, next
          catch error
            @error = error

        _.delay done, 100

      it 'should not blow up', ->
        expect(@error).not.to.exist
