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

    it 'creates the temporary directory' do
      allow(Dir).to receive(:tmpdir).and_return('/tmp/')
      allow(FileUtils).to receive(:mkdir_p).and_return(true)
      expect(FileUtils).to receive(:mkdir_p).with('/tmp/tds-perf-testing')

      Fastlane::Actions::TdsPerfTestAction.run(test_params)
    end

    it 'clones the repository' do
      allow(Fastlane::Actions).to receive(:sh).and_return(true)
      expect(Fastlane::Actions).to receive(:sh).with('git clone --depth=1 https://github.com/duckduckgo/TrackerRadarKit.git')

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
      allow(Dir).to receive(:tmpdir).and_return('/tmp/')
      allow(FileUtils).to receive(:mkdir_p).and_return(true)
      expect(FileUtils).to receive(:mkdir_p).with('/tmp/tds-perf-testing')
      allow(FileUtils).to receive(:rm_rf).and_return(true)
      expect(FileUtils).to receive(:rm_rf).with(tmp_dir)

      Fastlane::Actions::TdsPerfTestAction.run(test_params)
    end

    it 'cleans up the temporary directory when tests fail' do
      # Set up default success for all commands
      allow(Fastlane::Actions).to receive(:sh).and_return(true)
      allow(FileUtils).to receive(:rm_rf).and_return(true)
      allow(Dir).to receive(:tmpdir).and_return('/tmp/')
      allow(FileUtils).to receive(:mkdir_p).and_return(true)
      expect(FileUtils).to receive(:mkdir_p).with('/tmp/tds-perf-testing')

      # Make only the test command fail
      allow(Fastlane::Actions).to receive(:sh).with(test_command_pattern).and_raise("Test failed")

      # Ensure cleanup is still called and succeeds
      expect(FileUtils).to receive(:rm_rf).with(tmp_dir).and_return(true)

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

  describe 'default parameters' do
    let(:ios_ref_url) { 'https://raw.githubusercontent.com/duckduckgo/apple-browsers/refs/heads/main/iOS/Core/ContentBlocker/Domain/' }

    before do
      allow(Dir).to receive(:chdir).and_yield
      allow(FileUtils).to receive(:mkdir_p)
      allow(FileUtils).to receive(:rm_rf)
      allow(Fastlane::UI).to receive(:message)
      allow(Fastlane::UI).to receive(:error)
    end

    def test_command_for(params, lane_platform: nil)
      commands = []
      allow(Fastlane::Actions).to receive(:sh) { |command| commands << command }
      allow(Fastlane::Actions).to receive(:lane_context).and_return({ Fastlane::Actions::SharedValues::PLATFORM_NAME => lane_platform })

      Fastlane::Actions::TdsPerfTestAction.run(params)

      commands.find { |command| command.include?('xcodebuild test-without-building') }
    end

    it 'downloads the iOS reference file from its current location' do
      command = test_command_for({}, lane_platform: :ios)

      expect(command).to include('TEST_RUNNER_TDS_UT_FILE_NAME=ios-tds.json')
      expect(command).to include("TEST_RUNNER_TDS_REF_URL=#{ios_ref_url}")
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
