SandboxedModule = require('sandboxed-module')
sinon = require('sinon')
require('chai').should()
modulePath = require('path').join __dirname, '../../../../app/js/TrackChangesManager'

describe "TrackChangesManager", ->
	beforeEach ->
		@TrackChangesManager = SandboxedModule.require modulePath, requires:
			"request": @request = {}
			"settings-sharelatex": @Settings = {}
			"logger-sharelatex": @logger = { log: sinon.stub(), error: sinon.stub() }
			"./WebRedisManager": @WebRedisManager = {}
		@project_id = "mock-project-id"
		@doc_id = "mock-doc-id"
		@callback = sinon.stub()

	describe "flushDocChanges", ->
		beforeEach ->
			@Settings.apis =
				trackchanges: url: "http://trackchanges.example.com"

		describe "successfully", ->
			beforeEach ->
				@request.post = sinon.stub().callsArgWith(1, null, statusCode: 204)
				@TrackChangesManager.flushDocChanges @project_id, @doc_id, @callback

			it "should send a request to the track changes api", ->
				@request.post
					.calledWith("#{@Settings.apis.trackchanges.url}/project/#{@project_id}/doc/#{@doc_id}/flush")
					.should.equal true

			it "should return the callback", ->
				@callback.calledWith(null).should.equal true

		describe "when the track changes api returns an error", ->
			beforeEach ->
				@request.post = sinon.stub().callsArgWith(1, null, statusCode: 500)
				@TrackChangesManager.flushDocChanges @project_id, @doc_id, @callback

			it "should return the callback with an error", ->
				@callback.calledWith(new Error("track changes api return non-success code: 500")).should.equal true

	describe "pushUncompressedHistoryOps", ->
		beforeEach ->
			@ops = ["mock-ops"]
			@TrackChangesManager.flushDocChanges = sinon.stub().callsArg(2)

		describe "pushing the op", ->
			beforeEach ->
				@WebRedisManager.pushUncompressedHistoryOps = sinon.stub().callsArgWith(3, null, 1)
				@TrackChangesManager.pushUncompressedHistoryOps @project_id, @doc_id, @ops, @callback

			it "should push the ops into redis", ->
				@WebRedisManager.pushUncompressedHistoryOps
					.calledWith(@project_id, @doc_id, @ops)
					.should.equal true

			it "should call the callback", ->
				@callback.called.should.equal true

			it "should not try to flush the op", ->
				@TrackChangesManager.flushDocChanges.called.should.equal false

		describe "when we hit a multiple of FLUSH_EVERY_N_OPS ops", ->
			beforeEach ->
				@WebRedisManager.pushUncompressedHistoryOps =
					sinon.stub().callsArgWith(3, null, 2 * @TrackChangesManager.FLUSH_EVERY_N_OPS)
				@TrackChangesManager.pushUncompressedHistoryOps @project_id, @doc_id, @ops, @callback

			it "should tell the track changes api to flush", ->
				@TrackChangesManager.flushDocChanges
					.calledWith(@project_id, @doc_id)
					.should.equal true

		describe "when we go over a multiple of FLUSH_EVERY_N_OPS ops", ->
			beforeEach ->
				@ops = ["op1", "op2", "op3"]
				@WebRedisManager.pushUncompressedHistoryOps =
					sinon.stub().callsArgWith(3, null, 2 * @TrackChangesManager.FLUSH_EVERY_N_OPS + 1)
				@TrackChangesManager.pushUncompressedHistoryOps @project_id, @doc_id, @ops, @callback

			it "should tell the track changes api to flush", ->
				@TrackChangesManager.flushDocChanges
					.calledWith(@project_id, @doc_id)
					.should.equal true

		describe "when TrackChangesManager errors", ->
			beforeEach ->
				@WebRedisManager.pushUncompressedHistoryOps =
					sinon.stub().callsArgWith(3, null, 2 * @TrackChangesManager.FLUSH_EVERY_N_OPS)
				@TrackChangesManager.flushDocChanges = sinon.stub().callsArgWith(2, @error = new Error("oops"))
				@TrackChangesManager.pushUncompressedHistoryOps @project_id, @doc_id, @ops, @callback

			it "should log out the error", ->
				@logger.error
					.calledWith(
						err: @error
						doc_id: @doc_id
						project_id: @project_id
						"error flushing doc to track changes api"
					)
					.should.equal true
		
		describe "with no ops", ->
			beforeEach ->
				@WebRedisManager.pushUncompressedHistoryOps = sinon.stub().callsArgWith(3, null, 1)
				@TrackChangesManager.pushUncompressedHistoryOps @project_id, @doc_id, [], @callback
			
			it "should not call WebRedisManager.pushUncompressedHistoryOps", ->
				@WebRedisManager.pushUncompressedHistoryOps.called.should.equal false
			

