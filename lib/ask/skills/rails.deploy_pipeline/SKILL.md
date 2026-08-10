---
name: rails.deploy_pipeline
description: Pre-deployment checklist for Rails applications — migrations, assets, credentials, jobs, and logs
---

Use this skill before or during a Rails deployment to ensure nothing is missed.
Follow the steps in order — each builds on the previous.

## Step 1: Check Pending Migrations

Before deploying, always check for unapplied migrations:

```ruby
RunCommand.new.call(command: "bin/rails db:migrate:status | grep 'down'")
```

If there are pending migrations:
1. Review them with `Read.new.call(path: Rails.root.join("db/migrate/<TIMESTAMP>_migration_name.rb").to_s)`
2. Verify they're reversible: check `change`, `up`/`down`, or `reversible` blocks
3. Check for data migrations (e.g., backfills) that should run separately
4. Estimate execution time — large tables may need locking strategy

## Step 2: Verify Assets Pipeline

For Rails with assets (Sprockets or Propshaft):

```ruby
# Precompile locally to catch errors early
RunCommand.new.call(command: "bin/rails assets:precompile 2>&1")
```

Check for:
- Missing asset references (SCSS variables, image references)
- JavaScript compilation errors
- Asset fingerprint changes (manifold fingerprints if CSS changed)

For importmap or esbuild/vite setups:

```ruby
# Check build config
Read.new.call(path: Rails.root.join("package.json").to_s)
Read.new.call(path: Rails.root.join("vite.config.ts").to_s) if Rails.root.join("vite.config.ts").exist?
```

## Step 3: Review Credentials and Secrets

Verify that all required credentials exist in the target environment:

```ruby
# For production credentials
RunCommand.new.call(command: "bin/rails credentials:show --environment production 2>&1")
```

Check for common secrets that may need updating:
- `secret_key_base`
- `database_password`
- Third-party API keys (AWS, Stripe, SendGrid, etc.)
- JWT signing keys
- Any env vars referenced in `config/` files that aren't in credentials

## Step 4: Check Background Jobs

Review sidekiq/active job configuration before deploy:

```ruby
# Check job files for any that need queue configuration
Glob.new.call(pattern: "app/jobs/**/*.rb")
```

For any new or modified jobs:
1. Verify the queue adapter is configured in `production.rb`
2. Check for job retry logic that might affect rollback
3. Review `Read.new.call(path: Rails.root.join("config/sidekiq.yml").to_s)` if using Sidekiq
4. Verify scheduled/cron jobs if using `sidekiq-cron` or `whenever`

## Step 5: Review Production Log for Pre-deploy Issues

Check that the current production environment is healthy before deploying:

```ruby
ReadLog.new.call(lines: 100, level: "ERROR")
```

If there are recent errors, investigate before deploying more changes.

## Step 6: Verify Dependencies and Gem Versions

Check for critical gem updates or changes:

```ruby
# Review Gemfile for new/modified gems
RunCommand.new.call(command: "git diff HEAD -- Gemfile")
```

If adding a gem that needs system dependencies or native extensions:
```ruby
RunCommand.new.call(command: "bundle platform")
```

## Step 7: Config File Checklist

Verify configuration files for the target environment:

```ruby
Read.new.call(path: Rails.root.join("config/environments/production.rb").to_s)
Read.new.call(path: Rails.root.join("config/database.yml").to_s)
Read.new.call(path: Rails.root.join("config/cable.yml").to_s) if Rails.root.join("config/cable.yml").exist?
Read.new.call(path: Rails.root.join("config/storage.yml").to_s) if Rails.root.join("config/storage.yml").exist?
```

Key production checks:
- `config.force_ssl = true`
- `config.consider_all_requests_local = false`
- Proper cache store configured (`:mem_cache_store`, `:redis_cache_store`)
- Active Storage service configured for production

## Step 8: Quick Rollback Checklist

Before deploying, know how to roll back:

1. **Database**: `RunCommand.new.call(command: "bin/rails db:migrate:down VERSION=<previous>")`
2. **Code**: Git revert the deploy commit
3. **Assets**: Previous version's assets should still be cached
4. **Jobs**: Check if backward-incompatible changes won't replay failed jobs
5. **Feature flags**: If using flipper or similar, toggle off new features first
