# -*- coding: utf-8 -*-
require 'shellwords'
require 'open3'

Plugin.create(:pulseaudio) do
  defsound :pulseaudio, "PulseAudio" do |filename|
    SerialThread.new do
      if FileTest.exist?(filename)
        begin
          pacmd.puts "play-file #{Shellwords.escape(filename)} #{default_sink}"
        rescue => err
          error "Error occured. Force close connection.".freeze
          error err
          pacmd.close
          notice "Retry to play sound.".freeze
          pacmd.puts "play-file #{filename} #{default_sink}" end end end end

  # pacmd コマンドを実行して、書き込み用IOを返す。既に書き込み用IOが開いているならそちらを返す。
  # 既にcloseされているなら新しく接続しなおして返す。
  # ==== Return
  # IO 書き込み用のIO
  def pacmd
    if defined?(@pacmd) and not @pacmd.closed?
      @pacmd
    else
      notice "connection refused or not connected. reconnecting...".freeze
      @default_sink = nil
      @pacmd = IO.popen("pacmd".freeze, File::Constants::WRONLY).tap{ |pacmd|
        notice "connected.".freeze
        pacmd.close_on_exec = true
        pacmd.autoclose = true
        pacmd.sync = true } end end

  # PulseAudioに設定されている Default Sinkの名前を返す
  # ==== Return
  # String デフォルトシンクの名前
  def default_sink
    @default_sink ||= Open3.popen2({"LC_ALL" => "C".freeze} ,"pactl info".freeze){ |input, output, _|
      input.close
      target_line = output.find{ |line| line.start_with?("Default Sink".freeze) }
      if target_line
        result = target_line.match(/^Default Sink\s*:\s*(.+)$/)[1]
        notice "detected default sink: #{result}"
        result end } end

end
