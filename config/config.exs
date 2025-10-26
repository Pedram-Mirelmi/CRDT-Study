import Config

config :crdt_comparison,
  sync_interval: 20000,
  bp?: true,
  bd_sync_method: :all, # :all or :random
  sb_sync_method: :updates_only, # :all or :updates_only
  bd_push_model1?: true,
  bd_push_model2?: false,
  bd_pull_model?: true



config :logger, :console,
  level: :debug,
  # backends: [:console],
  format: "[$level] $metadata $message\n",
  metadata: [:node, :module, :function, :line]
