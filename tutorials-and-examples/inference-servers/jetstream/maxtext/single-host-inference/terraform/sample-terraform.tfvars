custom_metrics_enabled = true
metrics_port           = 9100

# How to (horizontally) scale the workload. Allowed values are:
# - null (no scaling),
# - Workload metrics (i.e. custom metrics):
#   - "jetstream_prefill_backlog_size"
#   - "jetstream_slots_used_percentage"
# - Workload resources
#   - accelerator/memory_used
# - Other possibilities coming soon...
#
# Demonstrating autoscaling with jetstream_prefill_backlog_size, change as desired.
# For jetstream_prefill_backlog_size. (experiment with this to determine optimal values).
hpa_type                = "jetstream_prefill_backlog_size"
hpa_averagevalue_target = 10

# Adjust these if you want different min/max values
hpa_min_replicas = 1
hpa_max_replicas = 2