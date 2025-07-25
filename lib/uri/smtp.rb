# frozen_string_literal: true

require "uri"
require_relative "smtp/version"

# See https://docs.ruby-lang.org/en/master/URI.html
module URI
  # Class that adds smtp(s)-scheme to the standard URI-module.
  class SMTP < URI::Generic
    class Error < StandardError; end

    # @return [Integer]
    def port
      return @port if @port
      return 25 if host_local?
      return 465 if tls?

      587
    end

    # Return mechanism of authentication (default `"plain"`).
    #
    # Only returns value when {URI::SMTP#userinfo} is provided and authentication is not `"none"`.
    #
    # Authentication can be provided via scheme (e.g. `"smtp+login://..."`) or via
    # query-params (e.g. `"smtp://foo.org?auth=cram-md5"`). The latter takes precedence when both are provided.
    # A provided value of `"none"` results in `nil`. Other values are returned as is.
    # @example
    #   # no userinfo
    #   URI("smtp://foo.org").auth #=> nil
    #
    #   # "none"
    #   URI("smtp+none://user@foo.org").auth #=> nil
    #
    #   # default value
    #   URI("smtp://user@foo.org").auth #=> "plain"
    #
    #   # query takes precedence
    #   URI("smtp+login://user@foo.org?auth=cram-md5").auth #=> "cram-md5"
    # @return [String, nil] mechanism of authentication or `nil`:
    # @return [nil] when there's no `userinfo`.
    # @return [nil] if 'auth via query' is `"none"`, e.g. `"smtp://foo.org?auth=none"`.
    # @return [String] 'auth via query' when present.
    # @return [nil] if 'auth via scheme' is `"none"`, e.g. `"smtp+none://foo.org"`.
    # @return [String] 'auth via scheme' when present, e.g. `"smtp+login://foo.org"`.
    # @return [String] else `"plain"`
    def auth
      # net-smtp: passing authtype without user/pw raises error
      return nil unless userinfo
      return nil if parsed_query["auth"] == "none"
      return parsed_query["auth"] if parsed_query.has_key?("auth")
      return nil if scheme_auth == "none"
      return scheme_auth if scheme_auth

      "plain"
    end

    # Decoded userinfo formatted as String, Array or Hash.
    #
    # **NOTE** not provided user or password result in `nil` (format: :array) or absent keys (format: :hash).
    #
    # @example no userinfo => `nil`
    #   URI("smtp://foo.org").decoded_userinfo #=> nil
    #   URI("smtp://foo.org").decoded_userinfo(format: :array) #=> nil
    #   URI("smtp://foo.org").decoded_userinfo(format: :hash) #=> nil
    #
    # @example format `:array`
    #   # absent user/password is `nil`
    #   URI("smtp://user@foo.org").decoded_userinfo(format: :array) #=> ["user", nil]
    #   URI("smtp://:pw@foo.org").decoded_userinfo(format: :array) #=> [nil, "pw"]
    #   # decoded values
    #   URI("smtp://user%40gmail.com:p%40ss@foo.org").decoded_userinfo(format: :array) #=> ["user@gmail.com", "p@ss"]
    #
    # @example format `:hash`
    #   # absent user/password is left out
    #   URI("smtp://user%40gmail.com@foo.org").decoded_userinfo(format: :hash) #=> {user: "user@gmail.com"}
    #   URI("smtp://:p%40ss@foo.org").decoded_userinfo(format: :hash) #=> {password: "p@ss"}
    #
    # @param format [Symbol] the format type, `:string` (default), `:array` or `:hash`.
    # @return [String, Array, Hash] Decoded userinfo formatted as String, Array or Hash.
    def decoded_userinfo(format: :string)
      return if userinfo.nil?

      case format
      when :string
        [decoded_user, decoded_password].join(":")
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

    # The host to send mail from, i.e. the `HELO` domain.
    # @return [String] the query-key `domain` when present, e.g. `"smtp://foo.org?domain=sender.org"`.
    # @return [String] the `fragment` when present, e.g. `"smtp://foo.org#sender.org"`.
    # @return [nil] otherwise
    def domain
      parsed_query["domain"] || fragment
    end

    # @return [Integer]
    def read_timeout
      parsed_query["read_timeout"]
    end

    # @return [Integer]
    def open_timeout
      parsed_query["open_timeout"]
    end

    # Whether or not to use `STARTTLS`.
    #
    # The possible return values (i.e. `:always`, `:auto` and `false`) map to what {https://github.com/ruby/net-smtp net-smtp} uses:
    # - `:always` use `STARTTLS` or disconnect when server does not support it.
    # - `:auto` use `STARTTLS` when supported, otherwise continue unencrypted.
    # - `false` don't use `STARTTLS`.
    #
    # @return [false] when `tls?`.
    # @return [:always, :auto, false] when query-key `starttls` is present, e.g. `"smtp://foo.org?starttls=auto"`.
    # @return [false] when `host_local?` (the host is considered one for local development).
    # @return [false] when `insecure?` (i.e. `scheme` starts with `"smtp+insecure"`).
    # @return [:always] otherwise.
    def starttls
      return false if tls?
      return parsed_query["starttls"] if parsed_query.has_key?("starttls")
      return false if host_local?
      return false if insecure?

      :always
    end

    # @return [Boolean] whether or not `scheme` starts with `"smtps"`.
    def tls
      !!scheme[/^smtps/]
    end
    alias_method :tls?, :tls

    # Whether or not the scheme indicates to skip STARTTLS.
    #
    # @see #starttls
    #
    # @example
    #   URI("smtp+insecure://foo.org").insecure? #=> true
    #   # This is equivalent (though shorter and more descriptive) to
    #   URI("smtp://foo.org?starttls=false")
    #
    #   # combine with authentication
    #   URI("smtp+insecure+login://user:pw@foo.org").insecure? #=> true
    # @return [Boolean] whether `scheme` starts with `"smtp+insecure"`.
    def insecure?
      scheme.start_with?("smtp+insecure")
    end

    # Whether or not `host` is considered local.
    #
    # Hostnames that are considered local have certain defaults (i.e. port `25` and no `STARTTLS`).
    # @example
    #   # Point to mailcatcher (https://github.com/sj26/mailcatcher)
    #   URI("smtp://127.0.0.1:1025").host_local? #=> true
    #
    #   URI("smtp://localhost").host_local? #=> true
    # @return [Boolean] whether or not `host` is considered local.
    def host_local?
      %w[127.0.0.1 localhost].include?(host)
    end

    # `query` as Hash with values `starttls`, `read_timeout` and `open_timeout` coerced.
    # @return [Hash] `query` parsed.
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

    # Return {Hash} representing the URI.
    #
    # `format` should be one of: `nil` or `:action_mailer` (or `:am`).
    #
    # Format `:action_mailer` matches how {https://guides.rubyonrails.org/action_mailer_basics.html#action-mailer-configuration ActionMailer} should be configured and works around some quirks in Mail v2.8.1.
    #
    # **NOTE** keys with nil-values are stripped.
    # @example default format
    #   URI("smtps+login://user%40gmail.com:p%40ss@smtp.gmail.com#sender.org").to_h
    #   # =>
    #   # {auth: "login",
    #   #  domain: "sender.org",
    #   #  host: "smtp.gmail.com",
    #   #  port: 465,
    #   #  scheme: "smtps+login",
    #   #  starttls: false,
    #   #  tls: true,
    #   #  user: "user@gmail.com",
    #   #  password: "p@ss"}
    # @example format `:action_mailer`/`:am`, ActionMailer configuration
    #   URI("smtps+login://user%40gmail.com:p%40ss@smtp.gmail.com#sender.org").to_h(format: :am)
    #   # =>
    #   # {address: "smtp.gmail.com",
    #   #  authentication: "login",
    #   #  domain: "sender.org",
    #   #  port: 465,
    #   #  tls: true,
    #   #  user_name: "user@gmail.com",
    #   #  password: "p@ss"}
    # @example Rails configuration
    #   # file: config/environments/development.rb
    #   # Config via env-var SMTP_URL or fallback to mailcatcher.
    #   config.action_mailer.smtp_settings = URI(ENV.fetch("SMTP_URL", "http://127.0.0.1:1025")).to_h(format: :am)
    # @param format [Symbol] the format type, `nil` (default), `:action_mailer`/`:am`.
    # @return [Hash]
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

    # Parse `uri` and instantiate instance of URI::SMTP.
    # @example
    #   URI::SMTP.parse("smtps+plain://user:pw@foo.org#sender.org")
    #   #=> #<URI::SMTP smtps+plain://user:pw@foo.org#sender.org>
    # @return [URI::SMTP] URI::SMTP instance from `uri`.
    def self.parse(uri)
      new(*URI.split(uri))
    end

    private

    def scheme_auth
      string_absense_in(scheme.split("+").last, %w[smtp smtps insecure])
    end

    # string_presence("")   #=> nil
    # string_presence("  ") #=> nil
    # string_presence(" FOO ") #=> " FOO "
    def string_presence(s)
      s.to_s.strip.then { _1 unless _1.empty? }
    end

    # string_absense_in("foo", %w[bar baz]) #=> "foo"
    # string_absense_in("bar", %w[bar baz]) #=> nil
    def string_absense_in(s, array)
      s unless array.include?(s)
    end
  end

  register_scheme "SMTP", SMTP
  register_scheme "SMTPS", SMTP
end

module UriSmtpExtensions
  def parse(uri)
    # Ensure 'plus schemes' (e.g., `smtp+login://`, `smtp+oauth://`) are parsed as URI::SMTP
    # instead of URI::Generic objects.
    if uri.is_a?(String) && uri.start_with?("smtp")
      return URI::SMTP.parse(uri)
    end

    super
  end
end

URI.singleton_class.prepend(UriSmtpExtensions)
