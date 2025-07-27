# URI::SMTP [![Gem Version](https://badge.fury.io/rb/uri-smtp.svg)](https://badge.fury.io/rb/uri-smtp) [![API Docs](https://img.shields.io/badge/API%20Docs-YARD-red?style=flat-square&logo=ruby)](https://eval.github.io/uri-smtp/)

Extends Ruby's `URI` with support for SMTP-uri's.  
This allows for more concise SMTP-config:
```diff
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
- config.action_mailer.smtp_settings = {
-   address:         "smtp.gmail.com",
-   port:            587,
-   domain:          "example.com",
-   user_name:       Rails.application.credentials.dig(:smtp, :user_name),
-   password:        Rails.application.credentials.dig(:smtp, :password),
-   authentication:  "plain",
-   enable_starttls: true,
-   open_timeout:    5,
-   read_timeout:    5
- }
# given ENV["SMPT_URL"]:
# "smtp://user_name:password@smtp.gmail.com?open_timeout=5&read_timeout=5#example.com"
+ config.action_mailer.smtp_settings = URI(ENV.fetch("SMTP_URL")).to_h(format: :am)
```

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add uri-smtp
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install uri-smtp
```

## Usage

### parse

```ruby
u = URI("smtps+login://user%40gmail.com:p%40ss@smtp.gmail.com#sender.org")

url.scheme           #=> "smtps+login"
url.auth             #=> "login"
url.starttls         #=> false
url.starttls?        #=> false
url.tls?             #=> true
url.userinfo         #=> "user%40gmail.com:p%40ss"
url.decoded_userinfo #=> "user@gmail.com:p@ss"
url.decoded_user     #=> "user@gmail.com"
url.user             #=> "user%40gmail.com"
url.decoded_password #=> "p@ss"
url.password         #=> "p%40ss"
url.host             #=> "smtp.gmail.com"
url.port             #=> 465
url.domain           #=> "sender.org"
```

### to_h

```ruby
URI("smtps+login://user%40gmail.com:p%40ss@smtp.gmail.com?domain=sender.org").to_h
#=>
{auth: "login",
 domain: "sender.org",
 host: "smtp.gmail.com",
 port: 587,
 scheme: "smtps+login",
 starttls: :always,
 tls: false,
 user: "user@gmail.com",
 password: "p@ss"}
```

For [ActionMailer configuration](https://guides.rubyonrails.org/action_mailer_basics.html#action-mailer-configuration), use `format: :action_mailer` (or `:am`):
```ruby
URI("smtps+login://user%40gmail.com:p%40ss@smtp.gmail.com?domain=sender.org").to_h(format: :am)
#=>
{address: "smtp.gmail.com",
 authentication: "login",
 domain: "sender.org",
 enable_starttls: :always,
 port: 587,
 user_name: "user@gmail.com",
 password: "p@ss"}
```

Besides renaming some keys, this also works around a quirk in `v2.8.1` of the mail-gem (e.g. `tls: false` [skips setting up STARTTLS](https://github.com/mikel/mail/blob/2.8.1/lib/mail/network/delivery_methods/smtp.rb#L115)).


Full Rails config:
```ruby
    config.action_mailer.delivery_method = :smtp
    # [mailcatcher](https://github.com/sj26/mailcatcher) fallback:
    config.action_mailer.smtp_settings = URI(ENV.fetch("SMTP_URL", "smtp://127.0.0.1:1025")).to_h(format: :am)
```

## SMTP-URI

There's no official specification for SMTP-URIs. There's some prior work though. This implementation is heavily inspired by [aerc](https://git.sr.ht/~rjarry/aerc/tree/master/item/doc/aerc-smtp.5.scd).  

`<scheme>[+<auth>]://[<user>[:<password>]@]<host>[:<port>][?<query>][#<fragment>]`

### scheme

- `smtp`  
  SMTP with STARTTLS (i.e. `url.starttls #=> :always`).
- `smtp+insecure`  
  SMTP without STARTTLS (i.e. `url.starttls #=> false`)..
- `smtps`  
  SMTP with TLS.

> [!NOTE]
> to get `url.starttls #=> :auto`, provide it in the query: `smtp://user:pw@foo?auth=auto`. In that case `net-smtp` uses STARTTLS when the server supports it (but won't halt like when using `:always`).


### auth

Any value for auth that passes the URI-parser is acceptable. Though the following values have special meaning:

- `none`  
  No authentication is required.
- `plain`  
  Authenticate with a username and password using AUTH PLAIN. This is the default behavior when no authentication is provided.

> [!NOTE]
> any query's value for `auth` takes precedence.

### Examples

| SMTP URI | TLS? | Port | STARTTLS | Auth Method | Notes |
|----------|---------|------|----------|-------------|-------|
| `smtp://smtp.example.com` | ❌ | 587 | ⚡ | none | Standard submission with STARTTLS `:always` |
| `smtp+insecure://smtp.example.com` | ❌ | 587 | ❌ | none | Standard submission without STARTTLS |
| `smtp+insecure+login://user:pass@smtp.example.com` | ❌ | 587 | ❌ | login | Authenticate insecurely using LOGIN auth |
| `smtp://smtp.example.com?starttls=auto` | ❌ | 587 | 🔄 | none | Standard submission with STARTTLS `:auto` |
| `smtp://smtp.example.com:1025` | ❌ | 1025 | ⚡ | none | Standard submission with STARTTLS `:always` on custom port |
| `smtp://user:pass@mail.example.com` | ❌ | 587 | ⚡ | plain | STARTTLS `:always` with (default) PLAIN auth |
| `smtp+login://user:pass@mail.example.com` | ❌ | 587 | ⚡ | login | STARTTLS `:always` with LOGIN auth |
| `smtp+none://mail.example.com` | ❌ | 587 | 🔄 | none | Explicit no authentication |
| `smtps://mail.example.com` | ✅ | 465 | ❌ | none | Direct TLS connection |
| `smtps://mail.example.com?domain=sender.org&read_timeout=5&open_timeout=5` | ✅ | 465 | ❌ | none | `domain`, `read_timeout` and `open_timeout` set |
| `smtps+login://user@imap.gmail.com` | ✅ | 465 | ❌ | login | Direct TLS with LOGIN auth |
| `smtps://user%40gmail.com:p%40ss@imap.gmail.com` | ✅ | 465 | ❌ | login | Direct TLS with encoded userinfo `user@gmail.com:p@ss` |
| `smtp://localhost` | ❌ | 25 | ❌ | none | Local delivery (no encryption) |
| `smtp://127.0.0.1` | ❌ | 25 | ❌ | none | Local delivery (no encryption) |

**Legend**

`STARTTLS`
- ⚡ = `:always`  
  Require STARTTLS (i.e. `net-smtp` aborts when server doesn't support STARTTLS).
- 🔄 = `:auto`  
  Use STARTTLS if supported by server.
- ❌ = `false`  
  No STARTTLS. This is always the case when using TLS.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.
Use `bin/yard server --reload` when working on documentation.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/eval/uri-smtp.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
