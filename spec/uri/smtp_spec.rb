# frozen_string_literal: true

RSpec.describe URI::SMTP do
  it "has a version number" do
    expect(URI::SMTP::VERSION).not_to be nil
  end

  describe "initialize" do
    context "with Kernel.URI()" do
      specify do
        expect(URI("smtp+login://foo")).to be_a(URI::SMTP)
      end
    end

    context "with URI.parse()" do
      specify do
        expect(URI.parse("smtp+login://foo")).to be_a(URI::SMTP)
      end
    end
  end

  def parse(uri)
    URI(uri)
  end

  describe "#starttls" do
    shared_examples "starttls of uri" do |uri, expected, meta|
      describe uri.inspect, meta.inspect do
        specify do
          expect(parse(uri).starttls).to eql(expected)
        end
      end
    end

    [
      sample("smtp+insecure://foo", false),
      sample("smtp://localhost", false),
      sample("smtp://127.0.0.1", false),
      sample("smtp://foo", :always),

      # query takes precedence
      sample("smtp://foo?starttls=false", false),
      sample("smtp+insecure://localhost?starttls=true", :always),
      sample("smtp+insecure://localhost?starttls=always", :always),
      sample("smtp+insecure://localhost?starttls=auto", :auto),

      # smtps then always false
      sample("smtps://foo", false),
      sample("smtps://foo?starttls=true", false)
    ].each do |*args|
      include_examples "starttls of uri", *args
    end
  end

  describe "#auth" do
    shared_examples "auth of uri" do |uri, expected, meta|
      describe uri.inspect, meta.inspect do
        specify do
          expect(parse(uri).auth).to eq(expected)
        end
      end
    end

    [
      # no userinfo
      sample("smtp://foo", nil),

      # default
      sample("smtp://u:p@foo", "plain"),

      # via scheme
      sample("smtp+login://u:p@foo", "login"),

      # none nillifies auth
      sample("smtp+none://u:p@foo", nil),

      # query is leading
      sample("smtp+none://u:p@foo?auth=login", "login")
    ].each do |*args|
      include_examples "auth of uri", *args
    end
  end

  describe "#port" do
    shared_examples "port of uri" do |uri, expected, meta|
      describe uri.inspect, meta.inspect do
        specify do
          expect(parse(uri).port).to eq(expected)
        end
      end
    end

    [
      # local
      sample("smtp://localhost", 25),
      sample("smtp://127.0.0.1", 25),
      sample("smtp://127.0.0.1:1025", 1025),

      # (non-)smtps
      sample("smtp://foo", 587),
      sample("smtp://foo:123", 123),
      sample("smtps://foo", 465),
      sample("smtps://foo:123", 123)
    ].each do |*args|
      include_examples "port of uri", *args
    end
  end

  describe "#decoded_userinfo" do
    shared_examples "decoded_userinfo of uri" do |uri, format, expected, meta|
      describe uri.inspect, meta.inspect do
        specify do
          expect(parse(uri).decoded_userinfo(format:)).to eql(expected)
        end
      end
    end

    [
      # string
      sample("smtp://foo.org", :string, nil),
      sample("smtp://token@foo.org", :string, "token:"),
      sample("smtp://user:token@foo.org", :string, "user:token"),
      sample("smtp://user%40gmail.com:pass%2F@foo.org", :string, "user@gmail.com:pass/"),

      # array
      sample("smtp://foo.org", :array, nil),
      sample("smtp://token@foo.org", :array, ["token", nil]),
      sample("smtp://:token@foo.org", :array, [nil, "token"]),
      sample("smtp://user%40gmail.com:pass%2F@foo.org", :array, ["user@gmail.com", "pass/"]),

      # to_h
      sample("smtp://foo.org", :hash, nil),
      sample("smtp://token@foo.org", :hash, {user: "token"}),
      sample("smtp://:token@foo.org", :hash, {password: "token"}),
      sample("smtp://user%40gmail.com:pass%2F@foo.org", :hash, {user: "user@gmail.com", password: "pass/"})

    ].each do |*args|
      include_examples "decoded_userinfo of uri", *args
    end
  end

  describe "#to_h" do
    describe "format: default" do
      shared_examples "hash of uri" do |uri, includes, meta|
        describe uri.inspect, meta.inspect do
          specify do
            expect(parse(uri).to_h).to include(includes)
          end

          specify do
            expect(parse(uri).to_h.values).to_not include(nil)
          end
        end
      end

      [
        # decoded userinfo
        sample("smtps://user%40gmail.com:pass%2F@foo", {
          user: "user@gmail.com",
          password: "pass/"
        }),

        # local defaults
        sample("smtp://localhost", {
          port: 25,
          starttls: false,
          tls: false
        }),
        sample("smtps://foo#sender.org", {
          port: 465,
          starttls: false,
          tls: true,
          domain: "sender.org"
        }),
        sample("smtp://foo", {
          port: 587,
          starttls: :always,
          tls: false
        })
      ].each do |*args|
        include_examples "hash of uri", *args
      end

      it "doesn't include userinfo when no auth" do
        expect(parse("smtp+none://u:p@foo").to_h).to_not include(:user, :password)
      end
    end
    describe "format: :action_mailer" do
      shared_examples "hash of uri for action_mailer" do |uri, includes, meta|
        describe uri.inspect, meta.inspect do
          excluded_keys = includes.delete(:__excluding)
          specify do
            expect(parse(uri).to_h(format: :am)).to include(includes)
          end
          if excluded_keys&.any?
            specify do
              expect(parse(uri).to_h(format: :am).keys).to_not include(excluded_keys)
            end
          end

          specify do
            expect(parse(uri).to_h.values).to_not include(nil)
          end
        end
      end

      [
        # decoded userinfo with correct key
        sample("smtps+login://user%40gmail.com:pass%2F@foo", {
          user_name: "user@gmail.com",
          password: "pass/",
          tls: true,
          authentication: "login"
        }),

        # local defaults
        sample("smtp://localhost", {
          port: 25,
          __excluding: %i[tls enable_starttls enable_starttls_auto]
        }),
        sample("smtps://foo", {
          port: 465,
          tls: true,
          __excluding: %i[enable_starttls enable_starttls_auto]
        }),
        sample("smtps://foo", {
          port: 465,
          tls: true,
          __excluding: %i[enable_starttls enable_starttls_auto]
        }),
        sample("smtp://foo", {
          port: 587,
          enable_starttls: true,
          __excluding: %i[tls enable_starttls_auto]
        }),
        # timeout settings
        sample("smtp://foo?read_timeout=&open_timeout=", {
          __excluding: %i[read_timeout open_timeout]
        }),
        sample("smtp://foo?read_timeout=1&open_timeout=2", {
          read_timeout: 1,
          open_timeout: 2
        })
      ].each do |*args|
        include_examples "hash of uri for action_mailer", *args
      end
    end
  end
end
