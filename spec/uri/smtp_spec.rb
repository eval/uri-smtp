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

  describe "#to_h" do
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
      sample("smtps://foo", {
        port: 465,
        starttls: false,
        tls: true
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
end
