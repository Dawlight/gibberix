import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :gibberix, GibberixWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "jwR8yVlvzeybMH5b/n81g5Z/eKCn7cGc2tr+fqsBYmpF1HBjKrO78rNWpROXzNCK",
  server: false

# In test we don't send emails.
config :gibberix, Gibberix.Mailer,
  adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
