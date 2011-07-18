require 'wopen3'

# Maintains a status message, along with an optional progress amount
# (which is generically displayed as (x of y), for example (5 of 100).
# The progress amount gets reset when you set a new message. 

module Buffet
  class StatusMessage
    def initialize(should_display=false)
      @message = ""
      @show_progress = false
      @progress = 0
      @max_progress = 0
      @should_display = should_display
    end

    def set(message)
      @message = message
      @show_progress = false

      display
    end

    def get
      if @show_progress
        "#{@message} (#{@progress} of #{@max_progress})"
      else
        "#{@message}"
      end
    end

    # Run the command COMMAND, and every time an output line matches PROGRESS_REGEX,
    # add to self
    def increase_progress(progress_regex, expected, command)
      start_progress(expected)
      # It's necessary to split along && because passing in multiple commands to
      # popen3 does not appear to work.
      command.split('&&').map do |command|
        Wopen3.popen3(*command.split(" ")) do |stdin, stdout, stderr|
          Thread.new(stdout) do |out|
            out.each do |line|
              if progress_regex =~ line
                add_to_progress
              end
            end
          end

          Thread.new(stderr) do |out|
            out.each do |line|
              puts line
            end
          end
        end
      end

      if $?.exitstatus != 0
        @status.set "Command #{command} failed."
      end
    end

    private 

    def start_progress(max_progress)
      @show_progress = true
      @max_progress = max_progress
      @progress = 0
      display
    end

    def add_to_progress
      @progress += 1
      display
    end

    def display
      puts(get) if @should_display
    end
  end
end