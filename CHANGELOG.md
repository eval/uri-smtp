## [Unreleased]

## [0.5.0] - 2025-07-25

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

## [0.4.0] - 2025-07-23

- FIX: correct settings for action_mailer using mail v2.8.1

## [0.3.0] - 2025-07-23

- FIX: Kernel.URI should accept URI's

## [0.2.0] - 2025-07-18

- Feature complete

