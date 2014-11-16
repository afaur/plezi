# Anorexic(framework-server) - a revelution in the making

People who are serious about their frameworks, should make their own servers...

(if to para-phrase "People who are serious about their software, should make their own hardware.")

## About Anorexic

This is an Asynchronous Web Server/Framework that is a Rack/Rails/Sintra alternative all in one.

Anorexic contains an object-oriented server, divided into parts that can be changed/updated and removed easily. The Anorexic framework runs HTTP and WeSockets, but could as easily be extended to run SMTP, SPDY or any other Protocol (including custom made protocols).

This will allow - much like Node.js, native WebSocket support (and, if you would like to write your own Protocol or Handler, native SMPT or any other custom protocol you might wish to implement).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'anorexic'
```
Or install it yourself as:

    $ gem install anorexic

## Creating an Anorexic Application

to create a new barebones app using the Anorexic framework, run from terminal:

    $ anorexic new appname

That's it, now you have a ready to use basic web server (with some demo code), just run it:

    $ cd appname
    $ ./appname.rb # ( or: anorexic s )

now go, in your browser, to: http://localhost:3000/

the default first port for the app is 3000. you can set the first port to listen to by using the `-p ` option (make sure you have permissions for the requested port):

    $ ./appname.rb -p 80

you now have a smart framework app that will happily eat any gem you feed it. it responds extra well to Haml, Sass and Coffee-Script, which you can enable in it's Gemfile.

## Barebones Web Service

this example is basic, useless, but required for every doc out there...

"Hello World!" in 3 lines - try it in irb (exit irb to start server):

		require 'anorexic'
		listen
		route(/.?/) { |req, res| res.body << "Hello World!" }

After you exited irb, the Anorexic server started up. go to http://localhost:3000/ and see it run :)

## Anorexic Routes

Anorexic supports magic routes, in similar formats found in other systems, such as: `route "/:required/(:optional)/(:optional_with_format){[\\d]*}", Controler`.

Anorexic assummes all simple string routes to be RESTful routes ( `"/user" == "/user/(:id)"` ).

    require 'anorexic'
    listen

    # this route demos a route for listing/showing posts,
    # with or without revision numbers or page-control....
    # notice the single quotes (otherwise the '\' would need to be escaped).
    route '/post/(:id)/(:revision){[\d]+\.[\d]+}/(:page_number)', Anorexic::StubRESTCtrl

now visit:

* http://localhost:3000/post/12/1.3/1
* http://localhost:3000/post/12/1

**please see the `route` documentation for more information on routes**.

## Anorexic Virtual Hosts

Anorexic can be used to create virtual hosts for the same service:

    require 'anorexic'
    listen
    host 'localhost', alias: 'localhost2'

    shared_route '/people' do |req, res|
        res << "we are people - shared by all routes."
    end

    host

    route('*') do |req, res|
        res << "this is a 'catch-all' host. you got here by putting in the IP adderess."
    end

    host 'localhost'

    route('*') do |req, res|
        res << "this is localhost or localhost 2"
    end

Now visit:

* [http://127.0.0.1:3000/]( http://127.0.0.1:3000/ )
* [http://localhost:3000/]( http://localhost:3000/ )
* [http://127.0.0.1:3000/people]( http://127.0.0.1:3000/people )
* [http://localhost:3000/people]( http://localhost:3000/people )

## Anorexic Controller classes

One of the best things about the Anorexic is it's ability to take in any class as a controller class and route to the classes methods with special support for RESTful methods (`index`, `show`, `new`, `save`, `update`, `delete`, `before` and `after`) and for WebSockets (`pre_connect`, `on_connect`, `on_message`, `on_disconnect`, `broadcast`):

		require 'anorexic'

		class Controller
			def index
				"Hello World!"
			end
		end

		listen
		route '*' , Controller

Except for WebSockets, returning a String will automatically add the string to the response before sending the response - which makes for cleaner code. It's also possible to send the response as it is (by returning true).

Controllers can even be nested (order matters) or have advanced uses that are definitly worth exploring.

**please read the demo code for Anorexic::StubRESTCtrl and Anorexic::StubWSCtrl to learn more.**

Here's some food for thought - code similar to something actually used in the framework app:

    require 'anorexic'

    # this controller will re-write the request to extract data,
    # and then it will fail, so that routing continues.
    #
    # this is here just for the demo.
    #
    class ReWriteController
        # using the before filter and regular expressions to make some changes.
        def before
            # extract the fr and en locales.
            result = request.path.match /^\/(en|fr)($|\/.*)/

            if result
                params[:locale] = result[1]
                request.path = result[2]
            end

            # let the routing continue.
            return false
        end
    end

    class Controller
        def index
            return "Bonjour le monde!" if params[:locale] == 'fr'
            "Hello World!\n #{params}"
        end
        def show
            return "Vous êtes à la recherche d' : #{params[:id]}" if params[:locale] == 'fr'
            "You're looking for: #{params[:id]}"
        end
        def debug
            # binding.pry
            # do you use pry for debuging?
            # no? oh well, let's ignore this.
            false
        end
        def delete
            return "Mon Dieu! Mon français est mauvais!" if params[:locale] == 'fr'
            "did you try /#{params["id"]}/?_method=delete or does your server support a native DELETE method?"
        end
    end

    listen

    # we run the ReWriteController first, to rewrite the path for all the remaining routes.
    #
    # this is here just for the demo...
    #
    # ...in this specific case, it is possible to dispense with the ReWriteController class
    # and write:
    #
    # route '/(:locale){fr|en}/*', false
    #
    # the false controller acts as a simple path re-write that
    # deletes everything before the '*' sign (the catch-all).
    #
    route '*' , ReWriteController

    # this route takes a regular expression that is a simple math calculation
    # (calculator)
    route /^\/[\d\+\-\*\/\(\)\.]+$/ do |request, response|
        message = (request.params[:locale] == 'fr') ? "La solution est" : "My Answer is"
        response.body << "#{message}: #{eval(request.path[1..-1])}"
    end

    route "/users" , Controller

    route "/" , Controller

try:

* http://localhost:3000/
* http://localhost:3000/fr
* http://localhost:3000/users/hello
* http://localhost:3000/(5+5*20-15)/9
* (http://localhost:3000/fr/(5+5*20-15)/9)
* (http://localhost:3000/users/hello?_method=delete)

## Anorexic Helpers and Logging

The Anorexic module (also `AN`) has methods to help with logging, asynchronous callbacks, dynamic routes, dynamic services and more.

Logging:

    require 'anorexic'

    # simple logging of strings
    AN.info 'log info'
    AN.warn 'log warning'
    AN.error 'log error'
    AN.fatal "log a fatal error (shuoldn't be needed)."
    AN.log_raw "Write raw strings to the logger."

    # the logger accepts exceptions as well.
    begin
        raise "hell"
    rescue Exception => e
        AN.error e
    end

Asynchronous callbacks (works only while services are active and running):

    require 'anorexic'

    def my_shutdown_proc time_start
        puts "Services were running for #{Time.now - time_start} seconds."
    end

    # shutdown callbacks
    AN.on_shutdown(Kernel, :my_shutdown_proc, Time.now) { puts "this will run after shutdown." }
    AN.on_shutdown() { puts "this will run too." }

    AN.callback(Kernel, :puts, "Please tell me your name?") do
        AN.callback(Kernel, :gets) {|name| puts "hello #{name}"}
    end

    puts "Anorexic will start eating our code once we exit terminal."

## Anorexic Settings

Anorexic is ment to be very flexible. please take a look at the Anorexic Module for settings you might want to play with (max_threads, thread_timeout, idle_sleep) or any monkey patching you might enjoy.

Feel free to fork or contribute. right now I am one person, but together we can make something exciting that will help us enjoy Ruby in this brave new world.

## Contributing

1. Fork it ( https://github.com/boazsegev/anorexic-server/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
