---
name: rails.route_trouble
description: Step-by-step methodology for debugging routing issues in Rails
---

Use this skill when a route is returning 404, you're getting route matching errors,
or routes aren't behaving as expected in a Rails application.

## Step 1: Inspect the Route Table

Start by examining the parsed route table:

```ruby
RouteInspector.new.call
```

This returns every route with its verb, path, controller, action, and name —
covering routes split across `draw` files and engines that a raw read of
`config/routes.rb` would miss.

Look for:
- The overall structure (namespaced, nested, shallow routes?)
- Resources that might be missing
- Constraints or conditions that could block matching
- Route ordering (more specific routes should come before less specific)

## Step 2: Check the Compiled Routes

Rails routes have a specific matching order. Use `RunCommand` to inspect the live routes:

```ruby
RunCommand.new.call(command: "bin/rails routes")
```

If you know the path you're trying to match, grep for it:

```ruby
RunCommand.new.call(command: "bin/rails routes | grep users")
```

For a specific route name:

```ruby
RunCommand.new.call(command: "bin/rails routes --grep user_profile")
```

## Step 3: Check Route Parameters and Constraints

Routes often fail because of parameter mismatches or constraints. Check for:

**Required parameters:** Does the route define `:id` but the URL doesn't include it?

**Format constraints:** Routes with `:format` (like `.json`, `.html`) constraints
can fail silently. Check if there's a default format:

```ruby
# In routes.rb:
resources :posts, defaults: { format: :json }
```

**Constraint classes:** Custom route constraints like `subdomain` or request-based
constraints can prevent matching:

```ruby
# In routes.rb:
get "admin", to: "admin/dashboard#show", constraints: ->(req) { req.subdomain == "admin" }
```

Check the constraints against the actual request parameters.

## Step 4: Trace the Match

For a failing request, trace how Rails would match it:

```ruby
RunCommand.new.call(
  command: "bin/rails runner \"puts Rails.application.routes.recognize_path('/users/1/edit', method: :get)\""
)
```

This will raise `ActionController::RoutingError` if no route matches — the
error message tells you what routes were tried before failing.

If the route exists but the controller isn't found:

```ruby
Read.new.call(path: Rails.root.join("app/controllers/users_controller.rb").to_s)
```

## Step 5: Check Namespace and Module Nesting

Routes in namespaced controllers fail when the controller file is in the wrong
directory or the module is misnamed:

```ruby
# Route:
namespace :admin do
  resources :users
end

# Expects:
# app/controllers/admin/users_controller.rb
# class Admin::UsersController < ApplicationController
```

Use `Glob` to verify the controller exists:

```ruby
# Via RunCommand:
RunCommand.new.call(command: "ls app/controllers/admin/")
```

## Step 6: Verify Helper Paths and Named Routes

If you're debugging a `No route matches` error from a view (link_to, form_with):

1. Check the route name: `RunCommand.new.call(command: "bin/rails routes | grep user_path")`
2. Verify the route helper: `RunCommand.new.call(command: "bin/rails routes --grep user")`
3. Check for route helper overrides in custom constraints or defaults

## Failure Mode Guide

| Symptom | Likely Cause | Action |
|---------|-------------|--------|
| 404 for existing route | Route constraint blocking | Check `constraints:` block in routes.rb |
| `No route matches` | Missing resource definition | Add `resources :model_name` |
| Route works in dev, not prod | Different route ordering | Check routes file isn't conditionally loaded |
| `Missing controller` | Wrong namespace or filename | Verify file path matches module structure |
| Path helper not responding | Wrong route name or params mismatch | Check `bin/rails routes --grep helper_name` |
