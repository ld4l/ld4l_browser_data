require 'fileutils'

require_relative 'main_class_helper/source_files'

module Ld4lBrowserData
  module Utilities
    module MainClassHelper
      def parse_arguments(*allowed)
        @args = {}
        ARGV.each do |arg|
          parts = arg.split('=', 2)
          if parts.size == 2
            @args[parts[0].to_sym] = parts[1]
          else
            @args[arg.to_sym] = true
          end
        end
        guard_against_surprise_arguments(allowed)
      end

      def guard_against_surprise_arguments(allowed)
        not_allowed = @args.keys - allowed
        unless not_allowed.empty?
          user_input_error("Unexpected parameters on the command line: #{not_allowed.join(', ')}")
        end
      end

      def validate_input_directory(key, label_text)
        input_dir = require_value(key)

        path = File.expand_path(input_dir)
        user_input_error("#{path} is not a directory.") unless File.directory?(path)

        path
      end

      def validate_input_directories(key, label_text)
        input_dirs = require_value(key)
        paths = input_dirs.split(',').map {|d| File.expand_path(d) }
        paths.each do |path|
          user_input_error("#{path} is not a directory.") unless File.directory?(path)
        end

        paths
      end

      def validate_output_directory(key, label_text)
        output_dir = require_value(key)
        replace, path = parse_output_path(output_dir)
        user_input_error("Can't create #{path}, parent directory doesn't exist.") unless File.directory?(File.dirname(path))

        if (File.directory?(path))
          replace ||= ok_to_replace?(path)
          user_input_error("Fine. forget it") unless replace
          clear_directory(path)
        else
          Dir.mkdir(path)
        end

        path
      end

      def validate_incremental_output_directory(key, label_text)
        output_dir = require_value(key)
        replace, path = parse_output_path(output_dir)
        user_input_error("Can't create #{path}, parent directory doesn't exist.") unless File.directory?(File.dirname(path))

        if (File.directory?(path))
          if replace
            clear_directory(path)
          else
            user_input_error("Fine. forget it") unless ok_to_reuse?(path)
          end
        else
          Dir.mkdir(path)
        end

        path
      end

      def validate_input_file(key, label_text)
        input_file = require_value(key)
        path = File.expand_path(input_file)
        user_input_error("#{path} does not exist.") unless File.exist?(path)

        path
      end

      def validate_input_source(key, label_text)
        input_source = require_value(key)
        path = File.expand_path(input_source)
        user_input_error("#{path} does not exist.") unless File.exist?(path)
        path
      end
      
      def validate_output_file(key, label_text)
        output_file = require_value(key)
        replace, path = parse_output_path(output_file)
        user_input_error("Can't create #{path}, parent directory doesn't exist.") unless File.directory?(File.dirname(path))

        if (File.exist?(path))
          replace ||= ok_to_replace?(path)
          user_input_error("Fine. forget it") unless replace
          File.delete(path)
        end

        path
      end

      def validate_file_system(key, label_text)
        fs_choice = require_value(key)
        fs_key, options = parse_options(fs_choice)
        connect_file_system(fs_key)
      end

      def validate_integer(props)
        key, label, min, max, default = props.values_at(:key, :label, :min, :max, :default)
        value = @args[key] || default
        user_input_error("A value for #{label} is required.") unless value
        user_input_error("'#{value}' is not a valid integer.") unless value =~ /^-?\d+$/
        integer = value.to_i
        user_input_error("'#{label}' must be at least #{min}") unless integer >= min if min
        user_input_error("'#{label}' must be no more than #{max}") unless integer <= max if max
        integer
      end

      def validate_site_name(props)
        key, label = props.values_at(:key, :label)
        value = @args[key]
        user_input_error("A value for #{label} is required.") unless value
        user_input_error("'#{label}' must be one of #{site_names.inspect}") unless site_names.include?(value)
        value
      end

      def require_value(key)
        value = @args[key]
        user_input_error("A value for #{key} is required.") unless value
        value
      end
      
      def site_names
        ['cornell', 'harvard', 'stanford']
      end

      def check_site_consistency(ignore_surprise, props)
        return if ignore_surprise

        props = props.select{|_, v| v }
        mentioned = props.values.map do |value|
          site_names.select {|s| value.to_s.include?(s)}
        end.flatten.uniq
        return if mentioned.size < 2

        raise UserInputError.new("Fine. forget it") unless ignore_surprises?(mentioned, props)
      end

      def ignore_surprises?(mentioned, props)
        surprises = props.map { |label, value| "#{label} is '#{value}'" }
        puts "  " + surprises.join("\n  ")
        puts "      Ignore this discrepancy: #{mentioned.sort.inspect} (yes/no)?"
        'yes' == STDIN.gets.chomp.downcase
      end

      def clear_directory(path)
        Dir.chdir(path) do |d|
          Dir.entries('.') do |fn|
            FileUtils.remove_entry(fn)
          end
        end
      end

      def parse_output_path(raw_path)
        parts = raw_path.split('~')
        path = File.expand_path(parts[0])
        if parts[1] == 'REPLACE'
          [true, path]
        elsif parts[1]
          user_input_error("Incorrect modifier on output path: #{parts[1]}")
        else
          [false, path]
        end
      end

      def parse_site_name(raw_name)
        parts = raw_name.split('~')
        [parts[1] == 'IGNORE_SURPRISE', parts[0].downcase]
      end

      def parse_options(input)
        parts = input.split('~')
        [parts.shift, parts]
      end
      
      def ok_to_replace?(path)
        puts "  REPLACE #{path} (yes/no)?"
        'yes' == STDIN.gets.chomp
      end

      def ok_to_reuse?(path)
        puts "  ADD TO #{path} (yes/no)?"
        'yes' == STDIN.gets.chomp
      end

      def user_input_error(message)
        raise UserInputError.new(message + "\n" + @usage_text.join("\n                   "))
      end

      def connect_triple_store
        selected = TripleStoreController::Selector.selected
        raise UserInputError.new("No triple store selected.") unless selected

        TripleStoreDrivers.select(selected)
        @ts = TripleStoreDrivers.selected

        raise IllegalStateError.new("#{@ts} is not running") unless @ts.running?
        @report.logit("Connected to triple-store: #{@ts}")
      end

      def trap_control_c
        @interrupted = false
        trap("SIGINT") do
          @interrupted = true
        end
      end
    end
  end
end
