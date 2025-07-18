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

    def scheme_auth
      scheme[/.*(?:\+(.+))/, 1]
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
      scheme == "smtps"
    end
    alias_method :tls?, :tls

    def insecure?
      scheme == "smtp+insecure"
    end

    def host_local?
      %w[127.0.0.1 localhost].include?(host)
    end

    def parsed_query
      @parsed_query ||= URI.decode_www_form(query.to_s).to_h.tap do
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
          enable_starttls: starttls,
          password: decoded_password,
          port:,
          user_name: decoded_user
        }
      else
        {
          auth:,
          host:,
          password: decoded_password,
          port:,
          scheme:,
          starttls:,
          tls:,
          user: decoded_user
        }
      end
    end

    def self.parse(uri)
      new(*URI.split(uri))
    end
  end

  register_scheme "SMTP", SMTP
  register_scheme "SMTPS", SMTP
end

module UriSmtpExtensions
  def parse(uri)
    if uri.start_with?("smtp")
      return URI::SMTP.parse(uri)
    end

    super
  end
end

URI.singleton_class.prepend(UriSmtpExtensions)
