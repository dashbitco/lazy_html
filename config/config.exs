import Config

# We disable the extra newline in test env, because it breaks doctests.
if config_env() == :test,
  do: config(:lazy_html, :inspect_extra_newline, false)
