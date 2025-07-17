# frozen_string_literal: true

require "uri"
require_relative "smtp/version"

module URI
  class SMTP < URI::Generic
    class Error < StandardError; end
  end

  register_scheme "SMTP", SMTP
  register_scheme "SMTPS", SMTP
end
