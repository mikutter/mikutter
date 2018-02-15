require 'websocket'
require 'websocket-client-simple'

class WebSocket::Client::Simple::Client
  def prepare_socket(host, port, **options)
    return if @socket
    @socket = TCPSocket.new(host, port)
    if port == 443
      context = OpenSSL::SSL::SSLContext.new.tap do |ctx|
        ctx.ssl_version = options[:ssl_version] || 'TLSv1_2'
        ctx.verify_mode = options[:verify_mode] || OpenSSL::SSL::VERIFY_PEER
        ctx.cert_store = OpenSSL::X509::Store.new.tap do |store|
          store.set_default_paths
        end
      end
      @socket = ::OpenSSL::SSL::SSLSocket.new(@socket, context)
      @socket.hostname = host
      @socket.connect
    end
    @socket
  end

  def connect(url, **options)
    return if @socket
    @url = url
    uri = URI.parse url
    prepare_socket(uri.host, uri.port || (uri.scheme == 'wss' ? 443 : 80), options)

    @handshake = ::WebSocket::Handshake::Client.new :url => url, :headers => options[:headers]
    @handshaked = false
    @pipe_broken = false
    @closed = false
    once :__close do |err|
      close
      emit :close, err
    end

    @thread = Thread.new do
      while !@closed do
        begin
          unless recv_data = @socket.getc
            close
            emit :close, "timeout 5sec"
            return
          end
          unless @handshaked
            @handshake << recv_data
            if @handshake.finished?
              if !@handshake.valid?
                close
                emit :close, "handshake was not valid"
                return
              end
              @handshaked = true
              frame = ::WebSocket::Frame::Incoming::Client.new(version: @handshake.version)
              emit :open
            end
          else
            frame << recv_data
            while msg = frame.next
              if msg.type == :ping
                send(msg.data, type: :pong)
                #puts "ping-pong: #{msg.data}\n"
              else
                emit :message, msg
              end
            end
          end
        rescue => e
          emit :error, e
        end
      end
    end

    @socket.write @handshake.to_s
  end
end

