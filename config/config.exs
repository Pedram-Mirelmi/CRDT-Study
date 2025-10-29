import Config

config :crdt_comparison,
  sync_interval: 2000000,
  jd_bp?: true,
  nd_bp?: true,
  sb_sync_method: :updates_only, # :all or :updates_only

  bd_sync_method: :all, # :all or :random
  bd_push_model1?: true,
  bd_push_model2?: false,
  bd_pull_model?: true,

  debugging: false

config :logger, :console,
  level: :debug,
  # backends: [:console],
  format: "[$level] $metadata $message\n",
  metadata: [:node, :module, :function, :line]
