# frozen_string_literal: true

require "uri"
require_relative "smtp/version"

module URI
  class SMTP < URI::Generic
    class Error < StandardError; end

    def initialize(scheme,
      userinfo, host, port, registry,
      path, opaque,
      query,
      fragment,
      parser = DEFAULT_PARSER,
      arg_check = false)
      super
    end

    def port
      return @port if @port
      return 25 if host_local?
      return 465 if tls?

      587
    end

    def auth
      # net-smtp: passing authtype without user/pw raises error
      return nil unless userinfo
      return parsed_query["auth"] if parsed_query.has_key?("auth")
      return nil if scheme_auth == "none"
      return scheme_auth if scheme_auth

      "plain"
    end

    # all formats: return nil when userinfo == nil.
    #
    # format: :array
    # Never contains empty strings (as opposed to [#user, #password]).
    # Example:
    # Given #<URI::SMTP smtps://:token@smtp.gmail.com>
    # Then:
    # [uri.user, uri.password] #=> ["", "token"]
    # uri.decoded_userinfo     #=> [nil, "token"]
    #
    # format: :hash
    # Keys are absent when value would be `nil`.
    # Example:
    # Given #<URI::SMTP smtps://:token@smtp.gmail.com>
    # Then:
    # uri.decoded_userinfo(format: :array) #=> [nil, "token"]
    # uri.decoded_userinfo(format: :to_h) #=> {password: "token"}
    def decoded_userinfo(format: :string)
      return if userinfo.nil?

      case format
      when :string
        [decoded_user, decoded_password].compact.join(":")
      when :array
        [string_presence(decoded_user), string_presence(decoded_password)]
      when :hash
        {
          user: string_presence(decoded_user),
          password: string_presence(decoded_password)
        }.delete_if { |_k, v| v.nil? }
      else
        raise ArgumentError,
          "Unknown format #{format.inspect}. Should be one of #{%i[string array hash].inspect}."
      end
    end

    def domain
      parsed_query["domain"] || fragment
    end

    def read_timeout
      parsed_query["read_timeout"]
    end

    def open_timeout
      parsed_query["open_timeout"]
    end

    def starttls
      return false if tls?
      return parsed_query["starttls"] if parsed_query.has_key?("starttls")
      return false if host_local?
      return false if insecure?

      :always
    end
    alias_method :starttls?, :starttls

    def tls
      !!scheme[/^smtps/]
    end
    alias_method :tls?, :tls

    def insecure?
      scheme == "smtp+insecure"
    end

    def host_local?
      %w[127.0.0.1 localhost].include?(host)
    end

    def parsed_query
      @parsed_query ||= URI.decode_www_form(query.to_s).to_h
        .delete_if { |_k, v| !string_presence(v) }
        .tap do
          _1["read_timeout"] &&= _1["read_timeout"].to_i
          _1["open_timeout"] &&= _1["open_timeout"].to_i
          _1["starttls"] &&= case _1["starttls"]
          when "always", "auto" then _1["starttls"].to_sym
          when "false" then false
          else
            :always
          end
        end
    end

    def to_h(format: nil)
      case format
      when :am, :action_mailer
        {
          address: host,
          authentication: auth,
          domain:,
          enable_starttls: starttls == :always,
          enable_starttls_auto: starttls == :auto,
          open_timeout:,
          port:,
          read_timeout:,
          tls:
        }.tap do
          unless _1[:authentication].nil?
            _1[:user_name] = decoded_user
            _1[:password] = decoded_password
          end
          # mail 2.8.1 logic is faulty in that it shortcuts
          # (start)tls-settings when they are false.
          # So we delete these flags.
          _1.delete(:tls) unless _1[:tls]
          _1.delete(:enable_starttls) unless _1[:enable_starttls]
          _1.delete(:enable_starttls) if _1[:tls]
          _1.delete(:enable_starttls_auto) unless _1[:enable_starttls_auto]
          _1.delete(:enable_starttls_auto) if _1[:tls]
        end.delete_if { |_k, v| v.nil? }
      else
        {
          auth:,
          domain:,
          host:,
          open_timeout:,
          port:,
          read_timeout:,
          scheme:,
          starttls:,
          tls:
        }.tap do
          unless _1[:auth].nil?
            _1[:user] = decoded_user
            _1[:password] = decoded_password
          end
        end.delete_if { |_k, v| v.nil? }
      end
    end

    def self.parse(uri)
      new(*URI.split(uri))
    end

    private

    def scheme_auth
      scheme[/.*(?:\+(.+))/, 1]
    end

    def string_presence(s)
      s.to_s.strip.then { _1 unless _1.empty? }
    end
  end

  register_scheme "SMTP", SMTP
  register_scheme "SMTPS", SMTP
end

module UriSmtpExtensions
  def parse(uri)
    if uri.is_a?(String) && uri.start_with?("smtp")
      return URI::SMTP.parse(uri)
    end

    super
  end
end

URI.singleton_class.prepend(UriSmtpExtensions)
