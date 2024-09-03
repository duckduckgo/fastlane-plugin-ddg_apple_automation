describe Fastlane::Actions::AsanaFindReleaseTaskAction do
  describe "#run" do
    describe "when it finds the release task" do
      before do
        expect(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:find_latest_marketing_version).and_return("1.0.0")
        expect(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:find_release_task).and_return("1234567890")
      end

      it "returns release task ID, URL and release branch" do
        allow(Fastlane::UI).to receive(:success)
        allow(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output)

        expect(test_action("ios")).to eq({
          release_task_id: "1234567890",
          release_task_url: "https://app.asana.com/0/0/1234567890/f",
          release_branch: "release/1.0.0"
        })

        expect(Fastlane::UI).to have_received(:success).with("Found 1.0.0 release task: https://app.asana.com/0/0/1234567890/f")
        expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("release_branch", "release/1.0.0")
        expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("release_task_id", "1234567890")
        expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("release_task_url", "https://app.asana.com/0/0/1234567890/f")
      end
    end

    def test_action(platform)
      Fastlane::Actions::AsanaFindReleaseTaskAction.run(platform: platform)
    end
  end

  describe "#find_latest_marketing_version" do
    before do
      @client = double
      allow(Octokit::Client).to receive(:new).and_return(@client)
    end

    it "returns the latest marketing version" do
      allow(@client).to receive(:releases).and_return([double(tag_name: '1.0.0')])

      expect(test_action).to eq("1.0.0")
    end

    describe "when there is no latest release" do
      it "shows error" do
        allow(@client).to receive(:releases).and_return([])
        allow(Fastlane::UI).to receive(:user_error!)

        test_action

        expect(Fastlane::UI).to have_received(:user_error!).with("Failed to find latest marketing version")
      end
    end

    describe "when latest release is not a valid semver" do
      it "shows error" do
        allow(@client).to receive(:releases).and_return([double(tag_name: '1.0')])
        allow(Fastlane::UI).to receive(:user_error!)

        test_action

        expect(Fastlane::UI).to have_received(:user_error!).with("Invalid marketing version: 1.0, expected format: MAJOR.MINOR.PATCH")
      end
    end

    def test_action
      Fastlane::Actions::AsanaFindReleaseTaskAction.find_latest_marketing_version("token")
    end
  end

  describe "#extract_version_from_tag_name" do
    it "returns the version" do
      expect(test_action("1.0.0")).to eq("1.0.0")
      expect(test_action("v1.0.0")).to eq("v1.0.0")
      expect(test_action("1.105.0-251")).to eq("1.105.0")
    end

    def test_action(tag_name)
      Fastlane::Actions::AsanaFindReleaseTaskAction.extract_version_from_tag_name(tag_name)
    end
  end

  describe "#validate_semver" do
    it "validates semantic version" do
      expect(test_action("1.0.0")).to be_truthy
      expect(test_action("0.0.0")).to be_truthy
      expect(test_action("7.136.1")).to be_truthy

      expect(test_action("v1.0.0")).to be_falsy
      expect(test_action("7.1")).to be_falsy
      expect(test_action("1.105.0-251")).to be_falsy
      expect(test_action("1005")).to be_falsy
    end

    def test_action(version)
      Fastlane::Actions::AsanaFindReleaseTaskAction.validate_semver(version)
    end
  end

  describe "#find_release_task" do
    before do
      Fastlane::Actions::AsanaFindReleaseTaskAction.setup_constants("ios")
    end

    describe "when release task is found" do
      describe "on the first page" do
        before do
          expect(HTTParty).to receive(:get).and_return(
            double(success?: true, parsed_response: { 'data' => {}, 'next_page' => nil })
          )
        end

        it "returns the release task ID" do
          expect(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:find_hotfix_task_in_response)
          expect(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:find_release_task_in_response).and_return("1234567890")

          expect(test_action("1.0.0")).to eq("1234567890")
        end
      end

      describe "on the next page" do
        before do
          url = "https://example.com"
          expect(HTTParty).to receive(:get).twice.and_return(
            double(success?: true, parsed_response: { 'data' => {}, 'next_page' => { 'uri' => url } }),
            double(success?: true, parsed_response: { 'data' => {}, 'next_page' => nil })
          )
          expect(Fastlane::Actions::AsanaFindReleaseTaskAction)
            .to receive(:find_release_task_in_response).twice.and_return(nil, "1234567890")
        end

        it "returns the release task ID" do
          allow(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:find_hotfix_task_in_response)
          expect(test_action("1.0.0")).to eq("1234567890")
          expect(Fastlane::Actions::AsanaFindReleaseTaskAction).to have_received(:find_hotfix_task_in_response).twice
        end
      end
    end

    describe "when fetching tasks in section fails" do
      before do
        expect(HTTParty).to receive(:get).and_return(
          double(success?: false, code: 401, message: "Unauthorized")
        )
      end

      it "shows error" do
        expect(Fastlane::Actions::AsanaFindReleaseTaskAction).not_to receive(:find_hotfix_task_in_response)
        expect(Fastlane::Actions::AsanaFindReleaseTaskAction).not_to receive(:find_release_task_in_response)
        allow(Fastlane::UI).to receive(:user_error!)

        test_action("1.0.0")

        expect(Fastlane::UI).to have_received(:user_error!).with("Failed to fetch release task: (401 Unauthorized)")
      end
    end

    def test_action(version)
      Fastlane::Actions::AsanaFindReleaseTaskAction.find_release_task(version, "token")
    end
  end

  describe "#find_release_task_in_response" do
    describe "when release task is found" do
      before do
        @response = { 'data' => [{
          'name' => 'iOS App Release 1.0.0',
          'gid' => '1234567890',
          'created_at' => '2024-01-01'
        }] }
      end

      describe "and the task is not too old" do
        before do
          allow(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:ensure_task_not_too_old)
        end

        it "returns the release task ID" do
          expect(test_action(@response, "1.0.0")).to eq("1234567890")
        end
      end

      describe "and release task is too old" do
        before do
          expect(Time).to receive(:now).and_return(Time.new(2024, 1, 10)).at_least(:once)
        end

        it "shows error" do
          allow(Fastlane::UI).to receive(:user_error!)
          test_action(@response, "1.0.0")

          expect(Fastlane::UI).to have_received(:user_error!).with("Found release task: 1234567890 but it's older than 5 days, skipping.")
        end
      end
    end

    describe "when release task is not found" do
      describe "on iOS" do
        before do
          Fastlane::Actions::AsanaFindReleaseTaskAction.setup_constants("ios")
        end

        it "returns nil" do
          expect(test_action({ 'data' => [{ 'name' => 'iOS App Release 1.0.0' }] }, "1.0.1")).to be_nil
          expect(test_action({ 'data' => [{ 'name' => 'iOS Release 1.0.1' }] }, "1.0.1")).to be_nil
          expect(test_action({ 'data' => [{ 'name' => 'macOS App Release 1.0.1' }] }, "1.0.1")).to be_nil
        end
      end

      describe "on macOS" do
        before do
          Fastlane::Actions::AsanaFindReleaseTaskAction.setup_constants("macOS")
        end

        it "returns nil" do
          expect(test_action({ 'data' => [{ 'name' => 'macOS App Release 1.0.0' }] }, "1.0.1")).to be_nil
          expect(test_action({ 'data' => [{ 'name' => 'macOS Release 1.0.1' }] }, "1.0.1")).to be_nil
          expect(test_action({ 'data' => [{ 'name' => 'iOS App Release 1.0.1' }] }, "1.0.1")).to be_nil
        end
      end
    end

    def test_action(response, version)
      Fastlane::Actions::AsanaFindReleaseTaskAction.find_release_task_in_response(response, version)
    end
  end

  describe "#find_hotfix_task_in_response" do
    describe "on iOS" do
      before do
        Fastlane::Actions::AsanaFindReleaseTaskAction.setup_constants("ios")
      end

      describe "when hotfix task is present" do
        before do
          @response = { 'data' => [{ 'name' => 'iOS App Hotfix Release 1.0.0', 'gid' => '1234567890' }] }
        end
        it "shows error" do
          allow(Fastlane::UI).to receive(:user_error!)
          test_action(@response)
          expect(Fastlane::UI).to have_received(:user_error!).with("Found active hotfix task: https://app.asana.com/0/0/1234567890/f")
        end
      end

      describe "when hotfix task is not present" do
        before do
          @responses = [
            { 'data' => [{ 'name' => 'iOS App Release 1.0.0', 'gid' => '1234567890' }] },
            { 'data' => [{ 'name' => 'iOS App Hotfix 1.0.0', 'gid' => '123456789' }] },
            { 'data' => [{ 'name' => 'macOS App Hotfix 1.0.0', 'gid' => '12345678' }] }
          ]
        end
        it "does not show error" do
          allow(Fastlane::UI).to receive(:user_error!)

          @responses.each do |response|
            test_action(response)
          end
          expect(Fastlane::UI).not_to have_received(:user_error!)
        end
      end
    end

    describe "on macOS" do
      before do
        Fastlane::Actions::AsanaFindReleaseTaskAction.setup_constants("macos")
      end

      describe "when hotfix task is present" do
        before do
          @response = { 'data' => [{ 'name' => 'macOS App Hotfix Release 1.0.0', 'gid' => '1234567890' }] }
        end

        it "shows error" do
          allow(Fastlane::UI).to receive(:user_error!)
          test_action(@response)
          expect(Fastlane::UI).to have_received(:user_error!).with("Found active hotfix task: https://app.asana.com/0/0/1234567890/f")
        end
      end

      describe "when hotfix task is not present" do
        before do
          @responses = [
            { 'data' => [{ 'name' => 'macOS App Release 1.0.0', 'gid' => '1234567890' }] },
            { 'data' => [{ 'name' => 'macOS App Hotfix 1.0.0', 'gid' => '123456789' }] },
            { 'data' => [{ 'name' => 'iOS App Hotfix 1.0.0', 'gid' => '12345678' }] }
          ]
        end
        it "does not show error" do
          allow(Fastlane::UI).to receive(:user_error!)

          @responses.each do |response|
            test_action(response)
          end
          expect(Fastlane::UI).not_to have_received(:user_error!)
        end
      end
    end

    def test_action(response)
      Fastlane::Actions::AsanaFindReleaseTaskAction.find_hotfix_task_in_response(response)
    end
  end
end
