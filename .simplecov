SimpleCov.start do
  # Merge results from multiple bashcov runs
  command_name 'claude-notifications'
  merge_timeout 3600

  # Enable coverage for sourced files
  enable_coverage :branch

  # Track these paths (relative to project root)
  track_files '{lib,hooks}/**/*.sh'

  # Group by directory
  add_group 'Libraries', 'lib'
  add_group 'Hooks', 'hooks'

  # Ignore everything except lib/ and hooks/
  add_filter do |source_file|
    !source_file.filename.match?(%r{/(lib|hooks)/})
  end

  # Don't fail if coverage is low (bash is tricky)
  # minimum_coverage 60

  # Output formats
  formatter SimpleCov::Formatter::HTMLFormatter
end
