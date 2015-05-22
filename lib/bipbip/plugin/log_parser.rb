require 'inotify'

module Bipbip

  class Plugin::LogParser < Plugin

    def metrics_schema
      config['matchers'].map do |matcher|
        {:name => matcher['name'], :type => 'gauge', :unit => 'Boolean'}
      end
    end

    def monitor
      notifier

      lines = @lines.entries
      @lines.clear

      Hash[
        config['matchers'].map do |matcher|
          name = matcher['name']
          regexp = Regexp.new(matcher['regexp'])
          value = lines.reject { |line| line.match(regexp).nil? }.length
          [name, value]
        end
      ]
    end

    def cleanup
      reset_notifier
    end

    private

    def notifier
      if @notifier.nil?
        file_stat = File.stat(config['path'])
        raise "Cannot read file `#{config['path']}`" unless file_stat.readable?
        @lines = []
        @size = file_stat.size
        @notifier = create_notifier
      end
      @notifier
    end

    def create_notifier
      # Including the "attrib" event, because on some systems "unlink" triggers "attrib", but then the inode's deletion doesn't trigger "delete_self"
      events = Inotify::MODIFY | Inotify::DELETE_SELF | Inotify::MOVE_SELF | Inotify::UNMOUNT | Inotify::ATTRIB
      notifier = Inotify.new
      notifier.add_watch(config['path'], events)

      @notifier_thread = Thread.new do
        notifier.each_event do |event|
          if event.mask == Inotify::MODIFY
            roll_file
          else
            log(Logger::WARN, "File event `#{event.mask}` detected, resetting notifier")
            reset_notifier
          end
        end
      end

      notifier
    end

    def reset_notifier
      unless @notifier.nil?
        begin
          @notifier.close
        rescue SystemCallError => e
          log(Logger::WARN, "Cannot close notifier: `#{e.message}`")
        end
        @notifier = nil
      end

      unless @notifier_thread.nil?
        @notifier_thread.exit
      end
    end

    def roll_file
      file = File.new(config['path'], 'r')
      if file.size != @size
        file.seek(@size)
        @lines.push(*file.readlines)
        @size = file.size
      end
      file.close
    end

  end
end
