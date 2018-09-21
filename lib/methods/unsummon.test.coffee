'use strict'

# Will access contents via share
import '../model.coffee'
# Test only works on server side; move to /server if you add client tests.
import '../../server/000servercall.coffee'
import chai from 'chai'
import sinon from 'sinon'
import { resetDatabase } from 'meteor/xolvio:cleaner'

model = share.model

describe 'unsummon', ->
  clock = null

  beforeEach ->
    clock = sinon.useFakeTimers(7)

  afterEach ->
    clock.restore()

  beforeEach ->
    resetDatabase()
  
  ['roundgroups', 'rounds', 'puzzles'].forEach (type) =>
    describe "on #{model.pretty_collection(type)}", ->
      describe 'which is not stuck', ->
        id = null
        ret = null
        beforeEach ->
          id = model.collection(type).insert
            name: 'Foo'
            canon: 'foo'
            created: 1
            created_by: 'cscott'
            touched: 2
            touched_by: 'cjb'
            solved: null
            solved_by: null
            tags: status: {name: 'Status', value: 'precipitate', touched: 2, touched_by: 'cjb'}
          ret = Meteor.callAs 'unsummon', 'torgen',
            type: type
            object: id

        it 'returns an error', ->
          chai.assert.isString ret

        it 'doesn\'t touch', ->
          chai.assert.deepInclude model.collection(type).findOne(id),
            touched: 2
            touched_by: 'cjb'
            tags: status: {name: 'Status', value: 'precipitate', touched: 2, touched_by: 'cjb'}

        it 'doesn\'t chat', ->
          chai.assert.lengthOf model.Messages.find(room_name: $ne: 'oplog/0').fetch(), 0

        it 'doesn\'t oplog', ->
          chai.assert.lengthOf model.Messages.find(room_name: 'oplog/0').fetch(), 0

      describe 'which someone else made stuck', ->
        id = null
        ret = null
        beforeEach ->
          id = model.collection(type).insert
            name: 'Foo'
            canon: 'foo'
            created: 1
            created_by: 'cscott'
            touched: 2
            touched_by: 'cjb'
            solved: null
            solved_by: null
            tags: status: {name: 'Status', value: 'stuck', touched: 2, touched_by: 'cjb'}
        it 'fails without login', ->
          chai.assert.throws ->
            Meteor.call 'unsummon',
              type: type
              object: id
          , Match.error

        describe 'when logged in', ->
          ret = null
          beforeEach ->
            ret = Meteor.callAs 'unsummon', 'torgen',
              type: type
              object: id

          it 'returns nothing', ->
            chai.assert.isUndefined ret

          it 'updates document', ->
            chai.assert.deepInclude model.collection(type).findOne(id),
              touched: 7
              touched_by: 'torgen'
              tags: {}

          it 'oplogs', ->
            chai.assert.lengthOf model.Messages.find({room_name: 'oplog/0', type: type, id: id}).fetch(), 1

          it 'notifies main chat', ->
            msgs = model.Messages.find(room_name: 'general/0').fetch()
            chai.assert.lengthOf msgs, 1
            chai.assert.include msgs[0].body, 'has arrived'
            chai.assert.include msgs[0].body, "#{model.pretty_collection(type)} Foo"

          it "notifies #{model.pretty_collection(type)} chat", ->
            msgs = model.Messages.find(room_name: "#{type}/#{id}").fetch()
            chai.assert.lengthOf msgs, 1
            chai.assert.include msgs[0].body, 'has arrived'
            chai.assert.notInclude msgs[0].body, "#{model.pretty_collection(type)} Foo"

      describe 'which they made stuck', ->
        id = null
        ret = null
        beforeEach ->
          id = model.collection(type).insert
            name: 'Foo'
            canon: 'foo'
            created: 1
            created_by: 'cscott'
            touched: 2
            touched_by: 'cjb'
            solved: null
            solved_by: null
            tags: status: {name: 'Status', value: 'stuck', touched: 2, touched_by: 'cjb'}
          ret = Meteor.callAs 'unsummon', 'cjb',
            type: type
            object: id

        it 'returns nothing', ->
          chai.assert.isUndefined ret

        it 'updates document', ->
          chai.assert.deepInclude model.collection(type).findOne(id),
            touched: 7
            touched_by: 'cjb'
            tags: {}

        it 'oplogs', ->
          chai.assert.lengthOf model.Messages.find({room_name: 'oplog/0', type: type, id: id}).fetch(), 1

        it 'notifies main chat', ->
          msgs = model.Messages.find(room_name: 'general/0').fetch()
          chai.assert.lengthOf msgs, 1
          chai.assert.include msgs[0].body, 'no longer'
          chai.assert.include msgs[0].body, "#{model.pretty_collection(type)} Foo"

        it "notifies #{model.pretty_collection(type)} chat", ->
          msgs = model.Messages.find(room_name: "#{type}/#{id}").fetch()
          chai.assert.lengthOf msgs, 1
          chai.assert.include msgs[0].body, 'no longer'
          chai.assert.notInclude msgs[0].body, "#{model.pretty_collection(type)} Foo"
