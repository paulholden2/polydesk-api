Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = true

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join('tmp', 'caching-dev.txt').exist?
    config.action_controller.perform_caching = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options)
  config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  config.x.mail_from = "Polydesk <donotreply@polydesk.io>"
  config.action_mailer.default_url_options = { host: "polydesk.io" }
  config.action_mailer.smtp_settings = {
    address: 'email-smtp.us-west-2.amazonaws.com',
    port: 587,
    domain: Rails.application.credentials[Rails.env.to_sym][:ses][:domain],
    user_name: Rails.application.credentials[Rails.env.to_sym][:ses][:username],
    password: Rails.application.credentials[Rails.env.to_sym][:ses][:password]
  }

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  # Hostname for frontend
  config.polydesk_www = 'localhost:4200'
  # When headless, Devise links will point directly to API server
  # using default URL options (see Rails.application.routes)
  config.polydesk_headless = !!ENV['POLYDESK_HEADLESS']
  # Select how background jobs will be dispatched
  config.polydesk_job_dispatcher = Polydesk::JobDispatcher::ActiveJob

  Rails.application.routes.default_url_options[:host] = 'localhost:3000'
  Rails.application.routes.default_url_options[:protocol] = 'http'
end
