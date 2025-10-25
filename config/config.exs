import Config

config :crdt_comparison,
  init_wall_clock_time: nil


config :logger, :console,
  level: :debug,
  # backends: [:console],
  format: "[$level] $metadata $message\n",
  metadata: [:node, :module, :function, :line]
