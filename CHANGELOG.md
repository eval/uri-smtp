Changes can be:

* ✨ Features
* ⚠️ Breaking
* 🐛 Bug Fixes
* 🛠️ Developer

## [Unreleased]

- ✨ `smtps+insecure://`  
  TLS, skipping certificate verification.
  Adds `#tls_verify`; `to_h` emits `tls_verify: false` (default format) / `openssl_verify_mode: "none"` (`:am` format).
- ✨ `to_h` accepts `user:`/`password:` overrides
  provide credentials separately (no uri-escaping) and `auth` still resolves from the scheme, e.g.
  ```ruby
  URI("smtps+login://smtp.gmail.com").to_h(format: :am, user: ENV["U"], password: ENV["P"])
  ```

## [v0.7.3](https://github.com/eval/uri-smtp/releases/tag/v0.7.3)

- 🛡️ MFA required to publish this gem

## [v0.7.2](https://github.com/eval/uri-smtp/releases/tag/v0.7.2)

- 🛡️ Push and sign gem via GH Actions (i.e. trusted publisher)  
  See "Provenance" at https://rubygems.org/gems/uri-smtp

## [v0.6.0](https://github.com/eval/uri-smtp/releases/tag/v0.6.0)

- ✨ API-docs at https://eval.github.io/uri-smtp/  
- 🐛 "smtp+insecure+foo://..." not considered `#insecure?`  
- 🐛 "smtp://foo.org?auth=none" being ignored  
- 🐛 "smtp+insecure://..." having auth "insecure"  
- ⚠️ remove `#starttls?`  

## [v0.5.0](https://github.com/eval/uri-smtp/releases/tag/v0.5.0)

- Add: `uri#read_timeout`, `uri#open_timeout`  
  Coerced integers from query:
  ```ruby
  URI("smtp://foo?read_timeout=1").read_timeout #=> 1
  ```
  Included in `to_h`.
- Add: `uri.decoded_userinfo(format: ...)`  
  `:format` can be one of `[:string :array :hash]`
- Add: domain can appear in fragment
  ```ruby
  URI("smtp://foo.org#sender.org").domain #=> "sender.org"
  ```
  NOTE Any domain from the query takes precedence.
- Fix: "smtps+foo://..." having no tls

## [v0.4.0](https://github.com/eval/uri-smtp/releases/tag/v0.4.0)

- FIX: correct settings for action_mailer using mail v2.8.1

## [v0.3.0](https://github.com/eval/uri-smtp/releases/tag/v0.3.0)

- FIX: Kernel.URI should accept URI's

## [v0.2.0](https://github.com/eval/uri-smtp/releases/tag/v0.2.0)

- Feature complete

