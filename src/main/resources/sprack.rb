require 'java'
require 'bundler/setup'
require 'rack'
require 'rack/rewindable_input'

module Sprack
  module RackServer
    class Builder
      def build(filename)
        rack_app, options_ignored = Rack::Builder.parse_file filename
        return SprayAdapter.new(rack_app)
      end

      def test
        puts "hi?"
      end
    end

    class SprayAdapter
      def initialize(app)
        @app = app
        @errors = java::lang::System::err.to_io #
        @logger = java::lang::System::out.to_io #
      end

      def test
        puts "ohai app here"
        p  @app.call({})
      end

      def call(request)

        rack_env = {
            'rack.version' => Rack::VERSION,
            'rack.multithread' => true,
            'rack.multiprocess' => false,
            'rack.input' => Rack::RewindableInput.new(request.input_stream.to_io),
            'rack.errors' => @errors,
            'rack.logger' => @logger,
            'rack.url_scheme' => request.scheme,
            'REQUEST_METHOD' => request.method,
            'SCRIPT_NAME' => '',
            'PATH_INFO' => request.path,
            'QUERY_STRING' => (request.query || ""),
            'SERVER_NAME' => 'server',
            'SERVER_PORT' => 'port'
        }

        rack_env['CONTENT_TYPE'] = request.content_type unless request.content_type.nil?
        rack_env['CONTENT_LENGTH']  = request.content_length unless request.content_length.nil?

        request.headers.each do |name, value|
          rack_env["HTTP_#{name.upcase.gsub(/-/,'_')}"] = value
        end

        response_status, response_headers, response_body = @app.call(rack_env)

        spray_headers = []
        response_headers.each do |name, value|
          spray_headers << Java::spray::http::HttpHeaders::RawHeader.apply(name,value)
        end

        body = Java::java::util::Arrays.asList(response_body.map{|p| p.to_java_bytes }.to_java)
        headers = Java::java.util::Arrays.asList(spray_headers.to_java)

        [response_status.to_java, headers, body]

      end
    end


  end
end

