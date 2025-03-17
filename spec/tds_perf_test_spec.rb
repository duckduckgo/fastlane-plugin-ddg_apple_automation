describe Fastlane::Actions::TdsPerfTestAction do
  describe '#run' do
    before do
      # Mock environment and filesystem operations
      allow(ENV).to receive(:fetch).and_call_original
      # This is the key change - mock the TMPDIR fetch specifically
      allow(ENV).to receive(:fetch).with('TMPDIR', nil).and_return('/tmp')
      allow(Dir).to receive(:chdir).and_yield
      allow(Fastlane::UI).to receive(:message)
      allow(Fastlane::UI).to receive(:error)
    end

    let(:test_params) do
      {
        ut_file_name: 'test_tds.json',
        ut_url: 'https://example.com/test_tds.json',
        ref_file_name: 'reference_tds.json',
        ref_url: 'https://example.com/reference_tds.json'
      }
    end

    let(:tmp_dir) { '/tmp/tds-perf-testing' }
    let(:test_command_pattern) { /xcodebuild test-without-building/ }
    let(:cleanup_command) { "rm -rf \"#{tmp_dir}\"" }

    it 'creates the temporary directory' do
      allow(Fastlane::Actions).to receive(:sh).and_return(true)
      expect(Fastlane::Actions).to receive(:sh).with('mkdir -p "/tmp/tds-perf-testing"')

      Fastlane::Actions::TdsPerfTestAction.run(test_params)
    end

    it 'clones the repository' do
      allow(Fastlane::Actions).to receive(:sh).and_return(true)
      expect(Fastlane::Actions).to receive(:sh).with('git clone --depth=1 git@github.com:duckduckgo/TrackerRadarKit.git')

      Fastlane::Actions::TdsPerfTestAction.run(test_params)
    end

    it 'runs the performance tests with correct parameters' do
      allow(Fastlane::Actions).to receive(:sh).and_return(true)

      expected_command = [
        "env",
        "TEST_RUNNER_TDS_UT_FILE_NAME=test_tds.json",
        "TEST_RUNNER_TDS_UT_URL=https://example.com/test_tds.json",
        "TEST_RUNNER_TDS_REF_FILE_NAME=reference_tds.json",
        "TEST_RUNNER_TDS_REF_URL=https://example.com/reference_tds.json",
        "xcodebuild test-without-building",
        "-scheme TrackerRadarKit",
        "-destination 'platform=macOS'",
        "-only-testing:TrackerRadarKitPerformanceTests/NextTrackerDataSetPerformanceTests"
      ].join(" ")

      expect(Fastlane::Actions).to receive(:sh).with(expected_command)

      Fastlane::Actions::TdsPerfTestAction.run(test_params)
    end

    it 'cleans up the temporary directory when tests pass' do
      allow(Fastlane::Actions).to receive(:sh).and_return(true)
      expect(Fastlane::Actions).to receive(:sh).with(cleanup_command)

      Fastlane::Actions::TdsPerfTestAction.run(test_params)
    end

    it 'cleans up the temporary directory when tests fail' do
      # Set up default success for all commands
      allow(Fastlane::Actions).to receive(:sh).and_return(true)

      # Make only the test command fail
      allow(Fastlane::Actions).to receive(:sh).with(test_command_pattern).and_raise("Test failed")

      # Ensure cleanup is still called and succeeds
      expect(Fastlane::Actions).to receive(:sh).with(cleanup_command).and_return(true)

      Fastlane::Actions::TdsPerfTestAction.run(test_params)
    end

    it 'returns true when tests pass' do
      allow(Fastlane::Actions).to receive(:sh).and_return(true)

      result = Fastlane::Actions::TdsPerfTestAction.run(test_params)
      expect(result).to be true
    end

    it 'returns false when tests fail' do
      # Set up default success for all commands
      allow(Fastlane::Actions).to receive(:sh).and_return(true)

      # Make only the test command fail
      allow(Fastlane::Actions).to receive(:sh).with(test_command_pattern).and_raise("Test failed")

      result = Fastlane::Actions::TdsPerfTestAction.run(test_params)
      expect(result).to be false
    end
  end

  # Rest of the tests remain the same
  describe '#available_options' do
    it 'includes all required parameters' do
      options = Fastlane::Actions::TdsPerfTestAction.available_options

      expect(options.map(&:key)).to include(
        :ut_file_name,
        :ut_url,
        :ref_file_name,
        :ref_url
      )
    end

    it 'marks all parameters as required' do
      options = Fastlane::Actions::TdsPerfTestAction.available_options

      options.each do |option|
        expect(option.optional).to be false
      end
    end
  end

  describe '#is_supported?' do
    it 'supports iOS platform' do
      expect(Fastlane::Actions::TdsPerfTestAction.is_supported?(:ios)).to be true
    end

    it 'supports macOS platform' do
      expect(Fastlane::Actions::TdsPerfTestAction.is_supported?(:mac)).to be true
    end

    it 'does not support Android platform' do
      expect(Fastlane::Actions::TdsPerfTestAction.is_supported?(:android)).to be false
    end
  end

  describe '#description and metadata' do
    it 'has a description' do
      expect(Fastlane::Actions::TdsPerfTestAction.description).not_to be_empty
    end

    it 'has return value documentation' do
      expect(Fastlane::Actions::TdsPerfTestAction.return_value).not_to be_empty
    end
  end
end
