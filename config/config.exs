import Config




config :logger, :console,
  level: :debug,
  # backends: [:console],
  format: "[$level] $metadata $message\n",
  metadata: [:node, :module, :function, :line]
