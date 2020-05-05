# frozen_string_literal: true

require 'shellwords'
require 'open3'

Plugin.create(:pulseaudio) do
  defsound :pulseaudio, 'PulseAudio' do |filename|
    SerialThread.new do
      if FileTest.exist?(filename)
        pacmd.puts "play-file #{Shellwords.escape(filename)} #{default_sink}"
      end
    rescue => err
      error 'Error occured. Force close connection.'
      error err
      pacmd.close
      pacmd.puts "play-file #{filename} #{default_sink}"
    end
  end

  # pacmd コマンドを実行して、書き込み用IOを返す。既に書き込み用IOが開いているならそちらを返す。
  # 既にcloseされているなら新しく接続しなおして返す。
  # ==== Return
  # IO 書き込み用のIO
  def pacmd
    if defined?(@pacmd) && !@pacmd.closed?
      @pacmd
    else
      @default_sink = nil
      @pacmd = IO.popen('pacmd', File::Constants::WRONLY).tap do |pacmd|
        pacmd.close_on_exec = true
        pacmd.autoclose = true
        pacmd.sync = true
      end
    end
  end

  # PulseAudioに設定されている Default Sinkの名前を返す
  # ==== Return
  # String デフォルトシンクの名前
  def default_sink
    @default_sink ||= Open3.popen2({'LC_ALL' => 'C'} ,'pactl info') do |input, output, _|
      input.close
      output
        .find{ |line| line.start_with?('Default Sink') }
        &.match(/^Default Sink\s*:\s*(.+)$/)&.captures&.first
    end
  end
end
