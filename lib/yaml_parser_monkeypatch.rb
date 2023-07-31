# frozen_string_literal: true

require 'yaml'
require 'strscan'

# Monkey patching of Psych is necessary in this case because by default, its
# tokenizer interprets the YAML keys "on" and "off" as "true" and "false", respectively.

# This means it's impossible to generate and emit a valid Actions workflow with the
# standard library YAML parser, as the "on" key is used to specify a block of events which
# cause a workflow to run.

# Thus, the best option is to override the default tokenizer to patch this behavior out.

module Psych
  class ScalarScanner
    # Taken from http://yaml.org/type/int.html
    INTEGER = /^(?:[-+]?0b[0-1_]+          (?# base 2)
                    |[-+]?0[0-7_]+           (?# base 8)
                    |[-+]?(?:0|[1-9][0-9_]*) (?# base 10)
                    |[-+]?0x[0-9a-fA-F_]+    (?# base 16))$/x.freeze

    def initialize(*_args)
      super()
      @string_cache ||= {}
      @symbol_cache ||= {}
    end

    def tokenize(string)
      return nil if string.empty?
      return string if @string_cache.key?(string)
      return @symbol_cache[string] if @symbol_cache.key?(string)

      case string
      # Check for a String type, being careful not to get caught by hash keys, hex values, and
      # special floats (e.g., -.inf).
      when %r{^[^\d.:-]?[A-Za-z_\s!@#$%\^&*(){}<>|/\\~;=]+}, /\n/
        if string.length > 5
          @string_cache[string] = true
          return string
        end

        case string
        when /^[^ytonf~]/i
          @string_cache[string] = true
          string
        when '~', /^null$/i
          nil
        when /^(yes|true)$/i
          true
        when /^(no|false)$/i
          false
        else
          @string_cache[string] = true
          string
        end
      when TIME
        begin
          parse_time string
        rescue ArgumentError
          string
        end
      when /^\d{4}-(?:1[012]|0\d|\d)-(?:[12]\d|3[01]|0\d|\d)$/
        require 'date'
        begin
          class_loader.date.strptime(string, '%Y-%m-%d')
        rescue ArgumentError
          string
        end
      when /^\.inf$/i
        Float::INFINITY
      when /^-\.inf$/i
        -Float::INFINITY
      when /^\.nan$/i
        Float::NAN
      when /^:./
        @symbol_cache[string] = if string =~ /^:(["'])(.*)\1/
                                  class_loader.symbolize(::Regexp.last_match(2).sub(/^:/, ''))
                                else
                                  class_loader.symbolize(string.sub(/^:/, ''))
                                end
      when /^[-+]?[0-9][0-9_]*(:[0-5]?[0-9])+$/
        i = 0
        string.split(':').each_with_index do |n, e|
          i += (n.to_i * 60**(e - 2).abs)
        end
        i
      when /^[-+]?[0-9][0-9_]*(:[0-5]?[0-9])+\.[0-9_]*$/
        i = 0
        string.split(':').each_with_index do |n, e|
          i += (n.to_f * 60**(e - 2).abs)
        end
        i
      when FLOAT
        if string =~ /\A[-+]?\.\Z/
          @string_cache[string] = true
          string
        else
          Float(string.gsub(/[,_]|\.$/, ''))
        end
      else
        int = parse_int string.gsub(/[,_]/, '')
        return int if int

        @string_cache[string] = true
        string
      end
    end

    ###
    # Parse and return an int from +string+
    def parse_int(string)
      return unless INTEGER === string

      Integer(string)
    end
  end
end
