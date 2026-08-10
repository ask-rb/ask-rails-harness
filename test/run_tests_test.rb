# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"

class RunTestsTest < Minitest::Test
  FAKE_RAILS = <<~RUBY
    #!/usr/bin/env ruby
    # frozen_string_literal: true
    # Minimal stand-in for `bin/rails test` in run_tests integration tests:
    # mirrors Rails' runner — files are required directly, minitest options
    # (including the harness plugin's -r injection) stay in ARGV, and
    # minitest/autorun's at_exit drives the run.
    ROOT = File.expand_path("..", __dir__)
    $LOAD_PATH.unshift(#{File.expand_path("../../lib", __dir__).inspect})
    require "minitest"
    File.write(File.join(ROOT, "env-dump.txt"),
               ENV.select { |k, _| k == "RAILS_MAX_THREADS" }.to_h.to_s)

    files = ARGV.select { |arg| arg.end_with?(".rb") }
    ARGV.replace(ARGV - files)
    if files.empty?
      Dir[File.join(ROOT, "test", "**", "*_test.rb")].sort.each { |f| require f }
    else
      files.each { |f| require File.expand_path(f, ROOT) }
    end
    # No Minitest.run call — autorun's at_exit handles it (single run).
  RUBY

  SCRATCH_SUITE = <<~RUBY
    require "minitest/autorun"

    class ScratchTest < Minitest::Test
      def test_passes
        assert true
      end

      def test_fails
        assert_equal 1, 2
      end

      def test_skips
        skip "later"
      end
    end
  RUBY

  def setup
    @tool = Ask::Rails::Harness::Tools::RunTests.new
    root = Dir.mktmpdir("ask-run-tests")
    @root = root
    # Closure over locals, not ivars: blocks defined via define_singleton_method
    # run with self == Rails, so `@root` there would resolve to Rails' own ivar.
    orig_root = Rails.root
    @restore_root = lambda do
      Rails.define_singleton_method(:root) { Pathname.new(orig_root) }
    end
    Rails.define_singleton_method(:root) { Pathname.new(root) }

    FileUtils.mkdir_p(File.join(root, "bin"))
    FileUtils.mkdir_p(File.join(root, "test"))
    File.write(File.join(root, "bin", "rails"), FAKE_RAILS)
    File.chmod(0o755, File.join(root, "bin", "rails"))
    File.write(File.join(root, "test", "scratch_test.rb"), SCRATCH_SUITE)

    # The tool's RUBYOPT activates the bundle in the spawned child
    # (-rbundler/setup). Give the scratch app a minimal Gemfile so that
    # succeeds there; minitest itself resolves from the default gems.
    File.write(File.join(root, "Gemfile"), "source \"https://rubygems.org\"\n")
    Bundler.with_unbundled_env do
      system("bundle", "install", "--local", chdir: root, out: File::NULL, err: File::NULL) ||
        system("bundle", "install", chdir: root, out: File::NULL, err: File::NULL)
    end

    # The suite runs under bundle exec; children spawned from the scratch dir
    # get a fresh RUBYOPT from the tool anyway, but keep the test process's
    # own env predictable while spawning.
    @orig_rubyopt = ENV["RUBYOPT"]
    ENV["RUBYOPT"] = nil
    # Mirror production: the harness MCP server runs with a small pool cap.
    @orig_rails_max_threads = ENV["RAILS_MAX_THREADS"]
    ENV["RAILS_MAX_THREADS"] = "1"
  end

  def teardown
    @restore_root.call
    ENV["RUBYOPT"] = @orig_rubyopt
    ENV["RAILS_MAX_THREADS"] = @orig_rails_max_threads
    FileUtils.rm_rf(@root)
  end

  # --- command building ----------------------------------------------------

  def test_minitest_command_defaults
    command, env = @tool.send(:build_command, :minitest, [], nil, nil, Pathname.new("/tmp/r.json"))
    assert_equal ["bin/rails", "test"], command
    assert_equal "/tmp/r.json", env["ASK_TEST_JSON_PATH"]
    assert_includes env["RUBYOPT"], "-rbundler/setup -r"
    assert_includes env["RUBYOPT"], "ask_rails_harness_plugin.rb"
  end

  def test_minitest_command_with_files_and_name
    command, env = @tool.send(:build_command, :minitest, ["test/a_test.rb", "test/b_test.rb"],
                              "test_user", nil, Pathname.new("/tmp/r.json"))
    assert_equal ["bin/rails", "test", "test/a_test.rb", "test/b_test.rb", "-n", "test_user"], command
    assert_equal "/tmp/r.json", env["ASK_TEST_JSON_PATH"]
  end

  def test_minitest_command_failed_only_builds_alternation_pattern
    failed = [{ file: "test/a_test.rb", test_name: "test_one" },
              { file: "test/b_test.rb", test_name: "test_two(extra)" }]
    command, = @tool.send(:build_command, :minitest, [], nil, failed, Pathname.new("/tmp/r.json"))
    assert_includes command, "-n"
    assert_includes command, "/test_one|test_two\\(extra\\)/"
  end

  def test_rspec_command_with_files_name_and_json_out
    json = Pathname.new("/tmp/r.json")
    command, env = @tool.send(:build_command, :rspec, ["spec/models/user_spec.rb"], "full name",
                              nil, json)
    assert_equal ["bundle", "exec", "rspec", "spec/models/user_spec.rb", "-e", "full name",
                  "--format", "json", "--out", "/tmp/r.json"], command
    assert_empty env
  end

  def test_rspec_command_failed_only_uses_file_line_args
    failed = [{ file: "spec/a_spec.rb", test_name: "x", line: 12 }]
    command, = @tool.send(:build_command, :rspec, [], nil, failed, Pathname.new("/tmp/r.json"))
    assert_includes command, "spec/a_spec.rb:12"
    refute_includes command, "-n"
  end

  # --- framework detection -------------------------------------------------

  def test_detects_minitest_by_default
    File.write(File.join(@root, "Gemfile.lock"), "GEM\n  remote: https://rubygems.org/\n")
    assert_equal :minitest, @tool.send(:detect_framework)
  end

  def test_detects_rspec_when_rspec_rails_and_spec_dir
    File.write(File.join(@root, "Gemfile.lock"), "      rspec-rails (~> 7.0)\n")
    FileUtils.mkdir_p(File.join(@root, "spec"))
    assert_equal :rspec, @tool.send(:detect_framework)
  end

  def test_ignores_rspec_gem_without_spec_dir
    File.write(File.join(@root, "Gemfile.lock"), "      rspec-rails (~> 7.0)\n")
    assert_equal :minitest, @tool.send(:detect_framework)
  end

  # --- result parsing ------------------------------------------------------

  def test_parses_minitest_json
    payload = {
      "framework" => "minitest", "run" => 3, "failures" => 1, "errors" => 1, "skips" => 1,
      "tests" => [
        { "name" => "test_fails", "klass" => "ScratchTest", "file" => "test/scratch_test.rb",
          "line" => 8, "status" => "failed", "message" => "Expected 2 == 1" },
        { "name" => "test_passes", "klass" => "ScratchTest", "file" => "test/scratch_test.rb",
          "line" => 4, "status" => "passed", "message" => nil }
      ]
    }
    path = File.join(@root, "report.json")
    File.write(path, JSON.generate(payload))

    results = @tool.send(:parse_results, :minitest, Pathname.new(path))
    assert_equal({ run: 3, failures: 1, errors: 1, skips: 1 }, results[:summary])
    assert_equal 1, results[:failed_tests].size
    failed = results[:failed_tests].first
    assert_equal "test_fails", failed[:test_name]
    assert_equal "test/scratch_test.rb", failed[:file]
    assert_equal 8, failed[:line]
    assert_equal "Expected 2 == 1", failed[:message]
  end

  def test_parses_rspec_json
    payload = {
      "examples" => [
        { "status" => "failed", "full_description" => "User validates email",
          "file_path" => "spec/models/user_spec.rb", "line_number" => 5,
          "exception" => { "message" => "expected: 2, got: 1" } },
        { "status" => "passed", "full_description" => "User is valid",
          "file_path" => "spec/models/user_spec.rb", "line_number" => 2 },
        { "status" => "pending", "full_description" => "User does later",
          "file_path" => "spec/models/user_spec.rb", "line_number" => 9 }
      ],
      "summary" => { "example_count" => 3, "failure_count" => 1, "pending_count" => 1 }
    }
    path = File.join(@root, "report.json")
    File.write(path, JSON.generate(payload))

    results = @tool.send(:parse_results, :rspec, Pathname.new(path))
    assert_equal({ run: 3, failures: 1, errors: 0, skips: 1 }, results[:summary])
    failed = results[:failed_tests].first
    assert_equal "User validates email", failed[:test_name]
    assert_equal "spec/models/user_spec.rb:5", "#{failed[:file]}:#{failed[:line]}"
    assert_equal "expected: 2, got: 1", failed[:message]
  end

  def test_parse_returns_nil_for_missing_or_invalid_json
    assert_nil @tool.send(:parse_results, :minitest, Pathname.new(File.join(@root, "nope.json")))
    bad = File.join(@root, "bad.json")
    File.write(bad, "not json {")
    assert_nil @tool.send(:parse_results, :minitest, Pathname.new(bad))
  end

  # --- integration ---------------------------------------------------------

  def test_test_children_do_not_inherit_rails_max_threads
    # The harness server runs with RAILS_MAX_THREADS=1 (small pool); test runs
    # are a separate concern and must get the app's normal pool sizes back.
    result = @tool.call({ name: "test_passes" })

    assert result.ok?, "run should succeed: #{result.error_message}"
    dump = File.read(File.join(@root, "env-dump.txt"))
    assert_equal "{}", dump, "RAILS_MAX_THREADS must be stripped from test children"
  end

  def test_execute_runs_suite_and_reports_structured_results
    result = @tool.call({})
    assert result.ok?, "run should succeed: #{result.error_message}"
    report = result.output
    assert_equal "minitest", report[:framework]
    assert_includes report[:command], "bin/rails test"
    assert_equal 3, report[:summary][:run]
    assert_equal 1, report[:summary][:failures]
    assert_equal 0, report[:summary][:errors]
    assert_equal 1, report[:summary][:skips]
    assert_equal 1, report[:failed_tests].size
    failed = report[:failed_tests].first
    assert_equal "test_fails", failed[:test_name]
    assert failed[:file].end_with?("test/scratch_test.rb"), "expected scratch file path, got #{failed[:file]}"
    assert_includes failed[:message], "Expected"
    assert_equal "run_tests(failed_only: true)", report[:next]
    assert File.exist?(File.join(@root, report[:artifact])), "log artifact must exist"

    # Failure list persisted for failed_only reruns
    status = JSON.parse(File.read(File.join(@root, "tmp/test/.ask/last-failures.json")))
    assert_equal "minitest", status["framework"]
    assert_equal ["test_fails"], status["failed_tests"].map { |t| t["test_name"] }
  end

  def test_execute_honors_file_and_name_filters
    result = @tool.call({ file: "test/scratch_test.rb", name: "test_passes" })

    assert result.ok?, "run should succeed: #{result.error_message}"
    report = result.output
    assert_includes report[:command], "test/scratch_test.rb"
    assert_includes report[:command], "-n test_passes"
    assert_equal 1, report[:summary][:run]
    assert_equal 0, report[:summary][:failures]
    assert_nil report[:next]
  end

  def test_failed_only_reruns_just_the_failures
    @tool.call({})

    result = @tool.call({ failed_only: true })

    assert result.ok?, "rerun should succeed: #{result.error_message}"
    report = result.output
    assert_includes report[:command], "-n /test_fails/"
    assert_equal 1, report[:summary][:run]
    assert_equal 1, report[:summary][:failures]
  end

  def test_failed_only_with_no_previous_failures_reports_cleanly
    result = @tool.call({ failed_only: true })
    refute result.ok?
    assert_includes result.error_message, "No failed tests"
  end

  def test_failed_only_after_clean_run_finds_nothing_to_rerun
    @tool.call({ name: "test_passes" })
    result = @tool.call({ failed_only: true })
    refute result.ok?
    assert_includes result.error_message, "No failed tests"
  end

  def test_timeout_kills_the_run_and_reports_timed_out
    File.write(File.join(@root, "test", "slow_test.rb"), <<~RUBY)
      require "minitest/autorun"
      class SlowTest < Minitest::Test
        def test_never_finishes
          sleep 30
        end
      end
    RUBY

    result = @tool.call({ timeout: 1 })

    assert result.ok?, "timed-out run still returns a structured report: #{result.error_message}"
    assert_equal true, result.output[:timed_out]
    refute_nil result.output[:exit_status]
  end

  def test_missing_results_returns_failure_with_artifact_path
    # A bin/rails that never produces JSON (simulates an incompatible runner)
    File.write(File.join(@root, "bin", "rails"), "#!/usr/bin/env ruby\nputs 'no json here'\n")
    File.chmod(0o755, File.join(@root, "bin", "rails"))

    result = @tool.call({})
    refute result.ok?
    assert_includes result.error_message, "machine-readable results"
    assert_includes result.error_message, "tmp/test/.ask/last-test.log"
  end
end
