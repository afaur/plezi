# I started writing tests... but I haven't finished quite yet.
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'open-uri'
require 'plezi'
require 'objspace'

def report_before_filter(result= true)
	return true if $before_tested
	puts("    * Before filter test: #{PleziTestTasks::RESULTS[result]}")
	$before_tested = true
	true
end
def report_after_filter(result= true)
	return true if $after_tested
	puts("    * After filter test: #{PleziTestTasks::RESULTS[result]}")
	$after_tested = true
	true
end

class Nothing
end
class TestCtrl



	# this will be called before every request.
	def before
		report_before_filter
	end

	# this will be called after every request.
	def after
		report_after_filter
	end

	# shouldn't be available (return 404).
	def _hidden
		"do you see me?"
	end
	def index
		"test"
	end
	def headers
		"HTTP request: #{request[:method]} #{request[:query]} - version: #{request[:version]}\n" + (request.headers.map {|k, v| "#{k}: #{v}"} .join "\n")
	end

	# returns the url used to access this method
	def my_url
		dest = params.dup
		url_for dest
	end
	# should return a 500 internal server error message.
	def fail
		raise "Hell!"
	end

	# called when request is GET and params\[:id] == "new".
	def new
		"new"
	end
	# called when request is GET and params\[:id] exists (unless params\[:id] == "new").
	def show
		"show #{params[:id]}"
	end
	# called when request is POST / PUT and params\[:id] exists and isn't 'new'
	def update
		"update #{params[:id]}"
	end
	def delete
		"delete #{params[:id]}"
	end
	# called when request is POST / PUT and params\[:id] is 'new'
	def save
		params[:data].to_s
	end
	def sleeper
		sleep 1
		"slept"
	end
	# should return a 404 error.
	def get404
		false
	end
	# path to test for chuncked encoding and response streaming.
	def streamer
		response.stream_async &method(:_stream_out)
		true
	end
	def _stream_out
		response << "streamed"
		true
	end
	def file_test
		if params[:file]
			send_data params[:file][:data], type: params[:file][:type], inline: true, filename: params[:file][:filename]
			return true
		end
		false
	end


	############
	## WebSockets

	# called once the websocket was connected
	def on_open
		response << "connected"
	end

	# called when new Websocket data is recieved
	#
	# data is a string that contains binary or UTF8 (message dependent) data.
	def on_message data
		case data
		when 'get uuid'
			response << "uuid: #{uuid}"
		when /to: ([^\s]*)/
			# puts "cating target: #{data.match(/to: ([^\s]*)/)[1]}"
			unicast data.match(/to: ([^\s]*)/)[1], :_push, "unicast"
			# broadcast :_push, "unicast"
		else
			broadcast :_push, data
			_push data
		end
			return true
	end

	# called when a disconnect packet has been recieved or the connection has been cut
	# (ISN'T called after a disconnect message has been sent).
	def on_close
	end

	# a demo event method that recieves a broadcast from instance siblings.
	def _push data
		response << data.to_s
	end
end

class WSsizeTestCtrl
	# called when new Websocket data is recieved
	#
	# data is a string that contains binary or UTF8 (message dependent) data.
	def on_message data
		response << data
	end
end

module PleziTestTasks
	module_function


	RESULTS = {true => "\e[32mpassed\e[0m", :waiting => "\e[32mwaiting validation\e[0m", :failed => "\e[31mFAILED!\e[0m"}
	RESULTS.default = RESULTS[:failed]

	def run_tests
		(public_methods(false)).each {|m| method(m).call if m.to_s.match /^test_/}
		report_before_filter false
		report_after_filter false
		true
	end
	def test_sleep
		Plezi.run_async do
			begin
				puts "    * Sleeper test: #{RESULTS[URI.parse("http://localhost:3000/sleeper").read == 'slept']}"
				puts "    * ASync tasks test: #{RESULTS[true]}"
			rescue => e
				puts "    **** Sleeper test FAILED TO RUN!!!"
				puts e
			end
		end
	end

	def test_index
		begin
			puts "    * Index test: #{RESULTS[URI.parse("http://localhost:3000/").read == 'test']}"
		rescue => e
			puts "    **** Index test FAILED TO RUN!!!"
			puts e
		end
	end
	def test_ssl
		puts "    * Connection to non-ssl and unique route test: #{RESULTS[URI.parse("http://localhost:3000/ssl").read == 'false']}"
		uri = URI.parse("https://localhost:3030/ssl")
		Net::HTTP.start(uri.host, uri.port, use_ssl: (uri.scheme == "https"), verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
			puts "    * Connection to ssl and unique ssl route test: #{RESULTS[ http.request(Net::HTTP::Get.new(uri)).body == 'true' ]}"
		end
		rescue => e
		puts "    **** SSL Tests FAILED to complete!!!"
		puts e
	end
	def test_new
		puts "    * New RESTful path test: #{RESULTS[URI.parse("http://localhost:3000/new").read == 'new']}"

		rescue => e
		puts "    **** New RESTful path test FAILED TO RUN!!!"
		puts e
	end
	def test_show
		puts "    * Show RESTful path test: #{RESULTS[URI.parse("http://localhost:3000/3").read == 'show 3']}"

		rescue => e
		puts "    **** Show RESTful path test FAILED TO RUN!!!"
		puts e
	end
	def test_update
		puts "    * Update RESTful path test: #{RESULTS[Net::HTTP.post_form( URI.parse("http://localhost:3000/"), id: 3).body == 'update 3']}"

		rescue => e
		puts "    **** Update RESTful path test FAILED TO RUN!!!"
		puts e.message
	end
	def test_delete
		puts "    * Delete RESTful path test: #{RESULTS[Net::HTTP.post_form( URI.parse("http://localhost:3000/"), id: 3, _method: :delete).body == 'delete 3']}"

		rescue => e
		puts "    **** Delete RESTful path test FAILED TO RUN!!!"
		puts e
	end
	def test_save
		puts "    * Save RESTful path test: #{RESULTS[Net::HTTP.post_form( URI.parse("http://localhost:3000/new"), data: "passed").body == 'passed']}"

		rescue => e
		puts "    **** Save RESTful path test FAILED TO RUN!!!"
		puts e
	end
	def test_streamed
		begin
			puts "    * Streaming test: #{RESULTS[URI.parse("http://localhost:3000/streamer").read == 'streamed']}"
		rescue => e
			puts "    **** Streaming test FAILED TO RUN!!!"
			puts e
		end
	end
	def test_url_for
		test_url = "/some/path/test/my_url/ask/"
		puts "    * simple #url_for test: #{RESULTS[URI.parse("http://localhost:3000" + test_url).read == test_url]}"
		test_url = "/some/another_path/my_url/ask/"
		puts "    * missing arguments #url_for test: #{RESULTS[URI.parse("http://localhost:3000" + test_url).read == test_url]}"

		rescue => e
		puts "    **** #url_for test FAILED TO RUN!!!"
		puts e
	end
	def test_placebo
		puts "    * Starting placebo tests..."
		ws = GRHttp::WSClient.connect_to("ws://localhost:3000/ws/placebo") {|ws| 'ME?'}
		ws << "    * Placebo WS connected."
		sleep 2
		ws.close
		rescue => e
		puts "    **** Placebo test FAILED TO RUN!!!"
		puts e
	end
	def test_websocket
		connection_test = broadcast_test = echo_test = unicast_test = false
		begin
			ws4 = GRHttp::WSClient.connect_to("wss://localhost:3030") do |ws|
				if ws.data == "unicast"
					puts "    * Websocket unicast testing: #{RESULTS[false]}"
					unicast_test = :failed
				end
			end
			ws2 = GRHttp::WSClient.connect_to("wss://localhost:3030") do |ws|
				next unless @is_connected || !(@is_connected = true)
				if ws.data == "unicast"
					puts "    * Websocket unicast message test: #{RESULTS[false]}"
					unicast_test = :failed
					next
				else
					puts "    * Websocket broadcast message test: #{RESULTS[broadcast_test = (ws.data == 'echo test')]}"
					go_test = false
				end
			end
			ws3 = GRHttp::WSClient.connect_to("ws://localhost:3000") do |ws|
				if ws.data.match /uuid: ([^s]*)/
					ws2 << "to: #{ws.data.match(/^uuid: ([^s]*)/)[1]}"
					puts "    * Websocket UUID for unicast testing: #{ws.data.match(/^uuid: ([^s]*)/)[1]}"
				elsif ws.data == "unicast"
					puts "    * Websocket unicast testing: #{RESULTS[:waiting]}"
					unicast_test ||= true
				end
			end
			ws3 << 'get uuid'
			puts "    * Websocket SSL client test: #{RESULTS[ws2 && true]}"
			ws1 = GRHttp::WSClient.connect_to("ws://localhost:3000") do |ws|
				unless @connected
					puts "    * Websocket connection message test: #{RESULTS[connection_test = (ws.data == 'connected')]}"
					@connected = true
					response << "echo test"
					next
				end
				if ws.data == "unicast"
					puts "    * Websocket unicast testing: #{RESULTS[false]}"
					unicast_test = :failed
					next
				end
				puts "    * Websocket echo message test: #{RESULTS[echo_test = (ws.data == 'echo test')]}"
			end
			
		rescue => e
			puts "    **** Websocket tests FAILED TO RUN!!!"
			puts e.message
		end
		remote = GRHttp::WSClient.connect_to("wss://echo.websocket.org/") {|ws| puts "    * Extra Websocket Remote test (SSL: echo.websocket.org): #{RESULTS[ws.data == 'Hello websockets!']}"; response.close}
		if remote.closed?
			puts "    * Extra Websocket Remote test (SSL: echo.websocket.org): #{RESULTS[false]}"
		else
			remote << "Hello websockets!"
		end
		sleep 0.5
		[ws1, ws2, ws3, ws4, remote].each {|ws| ws.close}
		PL.on_shutdown {puts "    * Websocket connection message test: #{RESULTS[connection_test]}" unless connection_test}
		PL.on_shutdown {puts "    * Websocket echo message test: #{RESULTS[echo_test]}" unless echo_test}
		PL.on_shutdown {puts "    * Websocket broadcast message test: #{RESULTS[broadcast_test]}" unless broadcast_test}
		PL.on_shutdown {puts "    * Websocket unicast message test: #{RESULTS[unicast_test]}"}
	end
	def test_websocket_sizes
			should_disconnect = false
			ws = GRHttp::WSClient.connect_to("ws://localhost:3000/ws/size") do |ws|
				if should_disconnect
					puts "    * Websocket size disconnection test: #{RESULTS[false]}"
				else
					puts "    * Websocket message size test: got #{ws.data.bytesize} bytes"
				end

			end
			ws.on_close do
				puts "    * Websocket size disconnection test: #{RESULTS[should_disconnect]}"
			end
			str = 'a'
			time_now = Time.now
			7.times {|i| str = str * 2**i;puts "    * Websocket message size test: sending #{str.bytesize} bytes"; ws << str; }
			str.clear
			to_sleep = (Time.now - time_now)*2 + 1
			puts "will now sleep for #{to_sleep} seconds, waiting allowing the server to respond"
			sleep to_sleep rescue true
			should_disconnect = true
			Plezi::Settings.ws_message_size_limit = 1024
			ws << ('0123'*258)
	end
	def test_broadcast_stress
		PlaceboStressTestCtrl.create_listeners
		PlaceboStressTestCtrl.run_test
	end
	def test_404
		puts "    * 404 not found and router continuity tests: #{RESULTS[ Net::HTTP.get_response(URI.parse "http://localhost:3000/get404" ).code == '404' ]}"

		rescue => e
		puts "    **** 404 not found test FAILED TO RUN!!!"
		puts e
	end
	def test_500
		workers = GReactor.instance_exec {@threads.select {|t| t.alive?} .count}
		print "    * 500 internal error test: #{RESULTS[ Net::HTTP.get_response(URI.parse "http://localhost:3000/fail" ).code == '500' ]}"
		# cause 10 more exceptions to be raised... testing thread survival.
		10.times { putc "."; Net::HTTP.get_response(URI.parse "http://localhost:3000/fail" ).code }
		putc "\n"
		workers_after_test = GReactor.instance_exec {@threads.select {|t| t.alive?} .count}
		puts "    * Worker survival test: #{RESULTS[workers_after_test == workers]} (#{workers_after_test} out of #{workers})"

		rescue => e
		puts "    **** 500 internal error test FAILED TO RUN!!!"
		puts e
	end
end

class PlaceboTestCtrl
	# called when new Websocket data is recieved
	#
	# data is a string that contains binary or UTF8 (message dependent) data.
	def index
		false
	end
	def on_open
		puts "    * Placebo multicasting to placebo test: #{PleziTestTasks::RESULTS[ multicast :send_back, uuid: uuid, test: true, type: 'multicast' ] }"
	end
	def on_message data
		puts data
	end
	def _get_uuid data
		puts "    * Placebo send #{data[:type]} test: #{PleziTestTasks::RESULTS[data[:test]]}"
		unicast( data[:uuid], :send_back, {test: true, type: 'unicast'}) if data[:uuid]
	end
end

class PlaceboCtrl
	def send_back data
		puts "    * Placebo recieve test for #{data[:type]}: #{PleziTestTasks::RESULTS[data[:test]]}"
		if data[:uuid]
			unicast( data[:uuid], :_get_uuid, {test: true, uuid: uuid, type: 'unicast'})
		else
			broadcast WSsizeTestCtrl, :_get_uuid, test: true, type: 'broadcast'
			multicast :_get_uuid, test: true, type: 'multicast'
		end
	end
end


class PlaceboStressTestCtrl
	def review start_time, fin = false, uni = false
		if fin
			time_now = Time.now
			average = (((time_now - start_time)*1.0/(LISTENERS*REPEATS))*1000.0).round(4)
			total = (time_now - start_time).round(3)
			puts "    * Placebo stress test - Total of #{LISTENERS*REPEATS} events) finished in #{total} seconds"
			puts "    * Placebo stress test - average: (#{average} seconds per event."
			PlaceboStressTestCtrl.run_unicast_test unless uni
		end
	end
	def self.run_test
		puts "\n    * Placebo Broadcast stress test starting - (#{LISTENERS} listening objects with #{REPEATS} messages."
		start_time = Time.now
		(REPEATS - 1).times {|i| PlaceboStressTestCtrl.broadcast :review, start_time}
		PlaceboStressTestCtrl.unicast @uuid, :review, start_time, true
		puts "    * Placebo stress test - sending messages required: (#{Time.now - start_time} seconds."
	end
	def self.run_unicast_test
		puts "\n    * Placebo Unicast stress test starting - (#{LISTENERS} listening objects with #{REPEATS} messages."
		start_time = Time.now
		(REPEATS - 1).times {|i| PlaceboStressTestCtrl.unicast @uuid, :review, start_time, false, true}
		PlaceboStressTestCtrl.unicast @uuid, :review, start_time, true, true
		puts "    * Placebo stress test - sending messages required: (#{Time.now - start_time} seconds."
	end
	def self.create_listeners
		@uuid = nil
		LISTENERS.times {@uuid = Plezi::Placebo.new(PlaceboStressTestCtrl).uuid}
	end
	REPEATS = 1000
	LISTENERS = 600
end

PL.create_logger nil
# PL::Settings.max_threads = 4

listen port: 3000

route("/ssl") {|req, res| res << "false" }
listen port: 3030, ssl: true
route("/ssl") {|req, res| res << "true" }

shared_route 'ws/no', Nothing
shared_route 'ws/placebo', PlaceboTestCtrl
shared_route 'ws/size', WSsizeTestCtrl


# puts Nothing.ancestors.join "\n"

shared_route '/some/:multi{path|another_path}/(:option){route|test}/(:id)/(:optional)', TestCtrl
shared_route '/', TestCtrl


mem_print_proc = Proc.new do
	h = GC.stat.merge ObjectSpace.count_objects_size
	ObjectSpace.each_object {|o| h[o.class] = h[o.class].to_i + 1}
	puts (h.to_a.map {|i| i.join ': '} .join "\n")
	h.clear
	GC.start
end
# puts ("\n\n*** GC.stat:\n" + ((GC.stat.merge ObjectSpace.count_objects_size).to_a.map {|i| i.join ': '} .join "\n"))
# mem_print_proc.call
# GR.run_every 30, &mem_print_proc




puts "    --- Plezi will ran async, performing some tests that than hang"

puts "    --- Starting tests"
puts "    --- Failed tests should read: #{PleziTestTasks::RESULTS[false]}"

r = Plezi::Placebo.new PlaceboCtrl
puts "    * Create Placebo test: #{PleziTestTasks::RESULTS[r && true]}"
puts "    * Placebo admists to being placebo: #{PleziTestTasks::RESULTS[PlaceboCtrl.placebo?]}"
puts "    * Regular controller answers placebo: #{PleziTestTasks::RESULTS[!PlaceboTestCtrl.placebo?]}"


Plezi.start_async
PleziTestTasks.run_tests

# ENV['PL_REDIS_URL'] ||= ENV['REDIS_URL'] || ENV['REDISCLOUD_URL'] || ENV['REDISTOGO_URL'] || "redis://test:1234@pub-redis-11008.us-east-1-4.5.ec2.garantiadata.com:11008"
# GReactor.forking 4
# GR.run_async { PleziTestTasks.run_tests }
# start_services

shoutdown_test = false
Plezi.on_shutdown { shoutdown_test = true }

puts "\n    --- Press ^C to complete tests."
Plezi.start
# Plezi::EventMachine.clear_timers

# sleep PLEZI_TEST_TIME if defined? PLEZI_TEST_TIME


puts "    * Shutdown test: #{ PleziTestTasks::RESULTS[shoutdown_test] }"


