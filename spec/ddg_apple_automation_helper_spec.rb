describe Fastlane::Helper::DdgAppleAutomationHelper do
  let(:other_action) { double("other_action") }
  let(:platform) { "ios" }
  let(:version) { "1.0.0" }
  let(:asana_access_token) { "secret-token" }
  let(:options) { { username: "user" } }

  describe "#process_erb_template" do
    it "processes ERB template" do
      template = "<h1>Hello, <%= x %>!</h1>"
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:load_file).and_return(template)
      expect(process_erb_template("template.erb", { 'x' => "World" })).to eq("<h1>Hello, World!</h1>")
    end

    it "shows error if provided template file does not exist" do
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:load_file).and_return(nil)
      allow(Fastlane::UI).to receive(:user_error!)
      expect(ERB).not_to receive(:new)
      process_erb_template("file.erb", {})
      expect(Fastlane::UI).to have_received(:user_error!).with("Template file not found: file.erb")
    end

    def process_erb_template(erb_file_path, args)
      Fastlane::Helper::DdgAppleAutomationHelper.process_erb_template(erb_file_path, args)
    end
  end

  describe "#compute_tag" do
    describe "when is prerelease" do
      let(:is_prerelease) { true }

      it "computes tag and returns nil promoted tag" do
        allow(File).to receive(:read).with("Configuration/Version.xcconfig").and_return("MARKETING_VERSION = 1.0.0")
        allow(File).to receive(:read).with("Configuration/BuildNumber.xcconfig").and_return("CURRENT_PROJECT_VERSION = 123")
        expect(compute_tag(is_prerelease)).to eq(["1.0.0-123", nil])
      end
    end

    describe "when is public release" do
      let(:is_prerelease) { false }

      it "computes tag and promoted tag" do
        allow(File).to receive(:read).with("Configuration/Version.xcconfig").and_return("MARKETING_VERSION = 1.0.0")
        allow(File).to receive(:read).with("Configuration/BuildNumber.xcconfig").and_return("CURRENT_PROJECT_VERSION = 123")
        expect(compute_tag(is_prerelease)).to eq(["1.0.0", "1.0.0-123"])
      end
    end

    def compute_tag(is_prerelease)
      Fastlane::Helper::DdgAppleAutomationHelper.compute_tag(is_prerelease)
    end
  end

  describe "#load_file" do
    it "shows error if provided file does not exist" do
      allow(Fastlane::UI).to receive(:user_error!)
      allow(File).to receive(:read).and_raise(Errno::ENOENT)
      load_file("file")
      expect(Fastlane::UI).to have_received(:user_error!).with("Error: The file 'file' does not exist.")
    end

    def load_file(file)
      Fastlane::Helper::DdgAppleAutomationHelper.load_file(file)
    end
  end

  describe "#code_freeze_prechecks" do
    it "performs git and submodule checks" do
      expect(other_action).to receive(:ensure_git_status_clean).twice
      expect(other_action).to receive(:ensure_git_branch).with(branch: Fastlane::Helper::DdgAppleAutomationHelper::DEFAULT_BRANCH)
      expect(other_action).to receive(:git_pull)
      expect(other_action).to receive(:git_submodule_update).with(recursive: true, init: true)
      Fastlane::Helper::DdgAppleAutomationHelper.code_freeze_prechecks(other_action)
    end
  end

  describe "#validate_new_version" do
    it "validates and returns the new version" do
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:current_version).and_return(version)
      expect(Fastlane::UI).to receive(:important).with("Current version in project settings is #{version}.")
      expect(Fastlane::UI).to receive(:important).with("New version is #{version}.")
      allow(Fastlane::UI).to receive(:interactive?).and_return(true)
      allow(Fastlane::UI).to receive(:confirm).and_return(true)
      expect(Fastlane::Helper::DdgAppleAutomationHelper.validate_new_version(version)).to eq(version)
    end
  end

  describe "#format_version" do
    it "formats a version string" do
      expect(Fastlane::Helper::DdgAppleAutomationHelper.format_version("1.2.3.4")).to eq("1.2.3")
    end
  end

  describe "#bump_minor_version" do
    it "increments the minor version" do
      expect(Fastlane::Helper::DdgAppleAutomationHelper.bump_minor_version("1.2.0")).to eq("1.3.0")
    end
  end

  describe "#bump_patch_version" do
    it "increments the patch version" do
      expect(Fastlane::Helper::DdgAppleAutomationHelper.bump_patch_version("1.2.3")).to eq("1.2.4")
    end
  end

  describe "#current_build_number" do
    it "reads the current build number from config" do
      allow(File).to receive(:read).and_return("CURRENT_PROJECT_VERSION = 123")
      expect(Fastlane::Helper::DdgAppleAutomationHelper.current_build_number).to eq(123)
    end
  end

  describe "#current_version" do
    it "reads the current version from config" do
      allow(File).to receive(:read).and_return("MARKETING_VERSION = 1.2.3")
      expect(Fastlane::Helper::DdgAppleAutomationHelper.current_version).to eq("1.2.3")
    end
  end

  describe "#prepare_release_branch" do
    it "prepares the release branch with version updates" do
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:code_freeze_prechecks)
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:validate_new_version).and_return(version)
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:create_release_branch)
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:update_embedded_files)
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:update_version_config)
      expect(other_action).to receive(:push_to_git_remote)
      release_branch, new_version = Fastlane::Helper::DdgAppleAutomationHelper.prepare_release_branch(platform, version, other_action)
      expect(release_branch).to eq("#{Fastlane::Helper::DdgAppleAutomationHelper::RELEASE_BRANCH}/#{version}")
      expect(new_version).to eq(version)
    end
  end

  describe "#create_hotfix_branch" do
    it "creates a new hotfix branch and checks out the branch" do
      branch_name = "hotfix/1.0.1"
      source_version = "1.0.0"
      new_version = "1.0.1"
      platform = "macos"
      allow(Fastlane::Helper).to receive(:is_ci?).and_return(false)
      allow(Fastlane::Actions).to receive(:sh).with("git", "branch", "--list", branch_name).and_return("")
      allow(Fastlane::Actions).to receive(:sh).with("git", "fetch", "--tags")
      allow(Fastlane::Actions).to receive(:sh).with("git", "checkout", "-b", branch_name, source_version)
      allow(Fastlane::Actions).to receive(:sh).with("git", "push", "-u", "origin", branch_name)
      allow(Fastlane::Actions).to receive(:sh).with("git", "checkout", branch_name)

      result = Fastlane::Helper::DdgAppleAutomationHelper.create_hotfix_branch(platform, source_version, new_version)
      expect(result).to eq(branch_name)
    end

    it "raises an error when the branch already exists" do
      allow(Fastlane::Actions).to receive(:sh).with("git", "branch", "--list", "hotfix/1.0.1").and_return("hotfix/1.0.1")
      source_version = "1.0.0"
      new_version = "1.0.1"
      platform = "macos"
      expect do
        Fastlane::Helper::DdgAppleAutomationHelper.create_hotfix_branch(platform, source_version, new_version)
      end.to raise_error(FastlaneCore::Interface::FastlaneCommonException, "Branch hotfix/1.0.1 already exists in this repository. Aborting.")
    end
  end

  describe "#validate_hotfix_version" do
    it "validates and bumps the patch version" do
      source_version = "1.0.0"
      new_version = "1.0.1"
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:bump_patch_version).with(source_version).and_return(new_version)
      allow(Fastlane::UI).to receive(:interactive?).and_return(false)
      allow(Fastlane::UI).to receive(:important)

      result = Fastlane::Helper::DdgAppleAutomationHelper.validate_hotfix_version(source_version)
      expect(result).to eq(new_version)
    end
  end

  describe "#validate_version_exists" do
    it "validates that the provided version exists as a git tag" do
      version = "1.0.0"
      formatted_version = "1.0.0"
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:format_version).with(version).and_return(formatted_version)
      allow(Fastlane::Actions).to receive(:sh).with("git", "fetch", "--tags")
      allow(Fastlane::Actions).to receive(:sh).with("git", "tag", "--list", formatted_version).and_return(formatted_version)

      result = Fastlane::Helper::DdgAppleAutomationHelper.validate_version_exists(version)
      expect(result).to eq(formatted_version)
    end
  end

  describe "#prepare_hotfix_branch" do
    it "prepares the hotfix branch" do
      platform = "macos"
      version = "1.0.0"
      source_version = "1.0.0"
      new_version = "1.0.1"
      release_branch_name = "hotfix/1.0.1"
      other_action = double("other_action")
      options = { some_option: "value" }
      github_token = "github-token"

      @client = double("Octokit::Client")
      allow(Octokit::Client).to receive(:new).and_return(@client)
      allow(@client).to receive(:latest_release).and_return(double(tag_name: source_version))
      allow(Fastlane::Helper::GitHelper).to receive(:repo_name).and_return("macOS")

      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:validate_version_exists)
        .with(version).and_return(source_version)

      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:validate_hotfix_version)
        .with(source_version).and_return(new_version)

      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:create_hotfix_branch)
        .with(platform, source_version, new_version).and_return(release_branch_name)

      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:increment_build_number)
        .with(platform, options, other_action)

      allow(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output)

      result_branch, result_version = Fastlane::Helper::DdgAppleAutomationHelper.prepare_hotfix_branch(
        github_token, platform, other_action, options
      )

      expect(result_branch).to eq(release_branch_name)
      expect(result_version).to eq(new_version)

      expect(Fastlane::Helper::DdgAppleAutomationHelper).to have_received(:validate_version_exists).with(version)
      expect(Fastlane::Helper::DdgAppleAutomationHelper).to have_received(:validate_hotfix_version).with(source_version)
      expect(Fastlane::Helper::DdgAppleAutomationHelper).to have_received(:create_hotfix_branch).with(platform, source_version, new_version)
      expect(Fastlane::Helper::DdgAppleAutomationHelper).to have_received(:increment_build_number).with(platform, options, other_action)
      expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("last_release", source_version)
      expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("release_branch_name", release_branch_name)
    end
  end

  describe "#create_release_branch" do
    it "creates a new release branch" do
      allow(Fastlane::Actions).to receive(:sh).and_return("")
      Fastlane::Helper::DdgAppleAutomationHelper.create_release_branch(version)
      expect(Fastlane::Actions).to have_received(:sh).with("git", "branch", "--list", "release/#{version}")
      expect(Fastlane::Actions).to have_received(:sh).with("git", "checkout", "-b", "release/#{version}")
      expect(Fastlane::Actions).to have_received(:sh).with("git", "push", "-u", "origin", "release/#{version}")
    end
  end

  describe "#update_embedded_files" do
    it "updates embedded files and commits them" do
      allow(Fastlane::Actions).to receive(:sh).with("./scripts/update_embedded.sh").and_return("")
      git_status_output = "On branch main\nmodified: Core/trackerData.json\n"
      allow(Fastlane::Actions).to receive(:sh).with("git", "status").and_return(git_status_output)
      allow(Fastlane::Actions).to receive(:sh).with("git", "add", "Core/trackerData.json").and_return("")
      allow(Fastlane::Actions).to receive(:sh).with("git", "commit", "-m", "Update embedded files").and_return("")
      expect(other_action).to receive(:ensure_git_status_clean)
      described_class.update_embedded_files(platform, other_action)
      expect(Fastlane::Actions).to have_received(:sh).with("git", "status")
      expect(Fastlane::Actions).to have_received(:sh).with("git", "add", "Core/trackerData.json")
      expect(Fastlane::Actions).to have_received(:sh).with("git", "commit", "-m", "Update embedded files")
    end
  end

  describe "#increment_build_number" do
    it "increments the build number" do
      allow(File).to receive(:read).with("Configuration/Version.xcconfig").and_return("MARKETING_VERSION = 1.0.0\n")
      allow(File).to receive(:read).with("Configuration/BuildNumber.xcconfig").and_return("CURRENT_PROJECT_VERSION = 123\n")
      allow(File).to receive(:write)
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:calculate_next_build_number).and_return(124)
      allow(Fastlane::UI).to receive(:interactive?).and_return(false)
      allow(Fastlane::UI).to receive(:confirm).and_return(true)
      allow(Fastlane::UI).to receive(:select).and_return("Current release (123)")
      expect(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:update_version_and_build_number_config)
      expect(other_action).to receive(:push_to_git_remote)
      Fastlane::Helper::DdgAppleAutomationHelper.increment_build_number(platform, options, other_action)
    end
  end

  describe "#calculate_next_build_number" do
    it "calculates the next build number" do
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:fetch_testflight_build_number).and_return(123)
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:current_build_number).and_return(124)
      allow(Fastlane::UI).to receive(:interactive?).and_return(false)
      expect(Fastlane::Helper::DdgAppleAutomationHelper.calculate_next_build_number(platform, options, other_action)).to eq(125)
    end
  end

  describe "#fetch_appcast_build_number" do
    it "fetches the highest appcast build number for macOS" do
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:`).with("plutil -extract SUFeedURL raw #{Fastlane::Helper::DdgAppleAutomationHelper::INFO_PLIST}").and_return("https://dummy-url.com/feed.xml\n")
      allow(HTTParty).to receive(:get).with("https://dummy-url.com/feed.xml").and_return(
        double(body: <<-XML
          <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
            <channel>
              <item>
                <sparkle:version>100</sparkle:version>
              </item>
            </channel>
          </rss>
        XML
              )
      )

      expect(Fastlane::Helper::DdgAppleAutomationHelper.fetch_appcast_build_number("macos")).to eq(100)
    end
  end

  describe "#fetch_testflight_build_number" do
    it "fetches the latest testflight build number" do
      expect(other_action).to receive(:latest_testflight_build_number).and_return(125)
      expect(Fastlane::Helper::DdgAppleAutomationHelper.fetch_testflight_build_number(platform, options, other_action)).to eq(125)
    end
  end

  describe "#get_api_key" do
    it "returns the API key if available in environment" do
      ENV["APPLE_API_KEY_ID"] = "key_id"
      ENV["APPLE_API_KEY_ISSUER"] = "issuer_id"
      ENV["APPLE_API_KEY_BASE64"] = "key_base64"
      expect(other_action).to receive(:app_store_connect_api_key).with(
        key_id: "key_id", issuer_id: "issuer_id", key_content: "key_base64", is_key_content_base64: true
      )
      Fastlane::Helper::DdgAppleAutomationHelper.get_api_key(other_action)
    end
  end

  describe "#get_username" do
    before do
      @original_ci_value = Fastlane::Helper.is_ci?
      allow(Fastlane::Helper).to receive(:is_ci?).and_return(false)
    end

    after do
      allow(Fastlane::Helper).to receive(:is_ci?).and_return(@original_ci_value)
    end

    it "fetches the username from options or git config" do
      expect(Fastlane::Helper::DdgAppleAutomationHelper.get_username(username: "username")).to eq("username")
    end
  end

  describe "#update_version_config" do
    it "updates the version in the config file" do
      expect(File).to receive(:write).with(
        Fastlane::Helper::DdgAppleAutomationHelper::VERSION_CONFIG_PATH,
        "#{Fastlane::Helper::DdgAppleAutomationHelper::VERSION_CONFIG_DEFINITION} = #{version}\n"
      )

      expect(other_action).to receive(:git_commit).with(
        path: Fastlane::Helper::DdgAppleAutomationHelper::VERSION_CONFIG_PATH,
        message: "Set marketing version to #{version}"
      )

      Fastlane::Helper::DdgAppleAutomationHelper.update_version_config(version, other_action)
    end
  end

  describe "#update_version_and_build_number_config" do
    it "updates both version and build number in config files" do
      expect(File).to receive(:write).with(Fastlane::Helper::DdgAppleAutomationHelper::VERSION_CONFIG_PATH, "#{Fastlane::Helper::DdgAppleAutomationHelper::VERSION_CONFIG_DEFINITION} = #{version}\n")
      expect(File).to receive(:write).with(Fastlane::Helper::DdgAppleAutomationHelper::BUILD_NUMBER_CONFIG_PATH, "#{Fastlane::Helper::DdgAppleAutomationHelper::BUILD_NUMBER_CONFIG_DEFINITION} = 123\n")
      expect(other_action).to receive(:git_commit)
      Fastlane::Helper::DdgAppleAutomationHelper.update_version_and_build_number_config(version, 123, other_action)
    end
  end
end
