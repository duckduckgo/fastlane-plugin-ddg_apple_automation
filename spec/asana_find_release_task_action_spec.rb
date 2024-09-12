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

      expect(find_latest_marketing_version).to eq("1.0.0")
    end

    describe "when there is no latest release" do
      it "shows error" do
        allow(@client).to receive(:releases).and_return([])
        allow(Fastlane::UI).to receive(:user_error!)

        find_latest_marketing_version

        expect(Fastlane::UI).to have_received(:user_error!).with("Failed to find latest marketing version")
      end
    end

    describe "when latest release is not a valid semver" do
      it "shows error" do
        allow(@client).to receive(:releases).and_return([double(tag_name: '1.0')])
        allow(Fastlane::UI).to receive(:user_error!)

        find_latest_marketing_version

        expect(Fastlane::UI).to have_received(:user_error!).with("Invalid marketing version: 1.0, expected format: MAJOR.MINOR.PATCH")
      end
    end

    def find_latest_marketing_version
      Fastlane::Actions::AsanaFindReleaseTaskAction.find_latest_marketing_version("token")
    end
  end

  describe "#extract_version_from_tag_name" do
    it "returns the version" do
      expect(extract_version_from_tag_name("1.0.0")).to eq("1.0.0")
      expect(extract_version_from_tag_name("v1.0.0")).to eq("v1.0.0")
      expect(extract_version_from_tag_name("1.105.0-251")).to eq("1.105.0")
    end

    def extract_version_from_tag_name(tag_name)
      Fastlane::Actions::AsanaFindReleaseTaskAction.extract_version_from_tag_name(tag_name)
    end
  end

  describe "#validate_semver" do
    it "validates semantic version" do
      expect(validate_semver("1.0.0")).to be_truthy
      expect(validate_semver("0.0.0")).to be_truthy
      expect(validate_semver("7.136.1")).to be_truthy

      expect(validate_semver("v1.0.0")).to be_falsy
      expect(validate_semver("7.1")).to be_falsy
      expect(validate_semver("1.105.0-251")).to be_falsy
      expect(validate_semver("1005")).to be_falsy
    end

    def validate_semver(version)
      Fastlane::Actions::AsanaFindReleaseTaskAction.validate_semver(version)
    end
  end

  describe "#find_release_task" do
    before do
      Fastlane::Actions::AsanaFindReleaseTaskAction.setup_constants("ios")

      @tasks = double
      asana_client = double("Asana::Client", tasks: @tasks)
      allow(Asana::Client).to receive(:new).and_return(asana_client)
    end

    describe "when release task is found" do
      describe "on the first page" do
        before do
          expect(@tasks).to receive(:find_all).and_return(double(next_page: nil))
        end

        it "returns the release task ID" do
          expect(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:find_hotfix_task_in_response)
          expect(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:find_release_task_in_response).and_return("1234567890")

          expect(find_release_task("1.0.0")).to eq("1234567890")
        end
      end

      describe "on the next page" do
        before do
          non_nil_next_page = double(next_page: nil)
          expect(@tasks).to receive(:find_all).and_return(double(next_page: non_nil_next_page))
          expect(Fastlane::Actions::AsanaFindReleaseTaskAction)
            .to receive(:find_release_task_in_response).twice.and_return(nil, "1234567890")
        end

        it "returns the release task ID" do
          allow(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:find_hotfix_task_in_response)
          expect(find_release_task("1.0.0")).to eq("1234567890")
          expect(Fastlane::Actions::AsanaFindReleaseTaskAction).to have_received(:find_hotfix_task_in_response).twice
        end
      end
    end

    describe "when fetching tasks in section fails" do
      before do
        expect(@tasks).to receive(:find_all).and_raise(StandardError, "API error")
      end

      it "shows error" do
        allow(Fastlane::UI).to receive(:user_error!)
        expect(Fastlane::Actions::AsanaFindReleaseTaskAction).not_to receive(:find_hotfix_task_in_response)
        expect(Fastlane::Actions::AsanaFindReleaseTaskAction).not_to receive(:find_release_task_in_response)

        find_release_task("1.0.0")

        expect(Fastlane::UI).to have_received(:user_error!).with("Failed to fetch release task: API error")
      end
    end

    describe "when fetching next page fails" do
      before do
        next_page = double
        expect(@tasks).to receive(:find_all).and_return(double(next_page: next_page))
        expect(next_page).to receive(:next_page).and_raise(StandardError, "API error")
      end

      it "shows error" do
        allow(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:find_hotfix_task_in_response)
        allow(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:find_release_task_in_response).and_return(nil)
        allow(Fastlane::UI).to receive(:user_error!)

        find_release_task("1.0.0")

        expect(Fastlane::UI).to have_received(:user_error!).with("Failed to fetch release task: API error")
      end
    end

    def find_release_task(version)
      Fastlane::Actions::AsanaFindReleaseTaskAction.find_release_task(version, "token")
    end
  end

  describe "#find_release_task_in_response" do
    describe "when release task is found" do
      before do
        Fastlane::Actions::AsanaFindReleaseTaskAction.setup_constants("ios")
        @tasks = [double(
          name: 'iOS App Release 1.0.0',
          gid: '1234567890',
          created_at: '2024-01-01'
        )]
      end

      describe "and the task is not too old" do
        before do
          allow(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:ensure_task_not_too_old)
        end

        it "returns the release task ID" do
          expect(find_release_task_in_response(@tasks, "1.0.0")).to eq("1234567890")
        end
      end

      describe "and release task is too old" do
        before do
          expect(Time).to receive(:now).and_return(Time.new(2024, 1, 10)).at_least(:once)
        end

        it "shows error" do
          allow(Fastlane::UI).to receive(:user_error!)
          find_release_task_in_response(@tasks, "1.0.0")

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
          expect(find_release_task_in_response([double(name: 'iOS App Release 1.0.0')], "1.0.1")).to be_nil
          expect(find_release_task_in_response([double(name: 'iOS Release 1.0.1')], "1.0.1")).to be_nil
          expect(find_release_task_in_response([double(name: 'macOS App Release 1.0.1')], "1.0.1")).to be_nil
        end
      end

      describe "on macOS" do
        before do
          Fastlane::Actions::AsanaFindReleaseTaskAction.setup_constants("macos")
        end

        it "returns nil" do
          expect(find_release_task_in_response([double(name: 'macOS App Release 1.0.0')], "1.0.1")).to be_nil
          expect(find_release_task_in_response([double(name: 'macOS Release 1.0.1')], "1.0.1")).to be_nil
          expect(find_release_task_in_response([double(name: 'iOS App Release 1.0.1')], "1.0.1")).to be_nil
        end
      end
    end

    def find_release_task_in_response(response, version)
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
          @tasks = [double(name: 'iOS App Hotfix Release 1.0.0', gid: '1234567890')]
        end
        it "shows error" do
          allow(Fastlane::UI).to receive(:user_error!)
          find_hotfix_task_in_response(@tasks)
          expect(Fastlane::UI).to have_received(:user_error!).with("Found active hotfix task: https://app.asana.com/0/0/1234567890/f")
        end
      end

      describe "when hotfix task is not present" do
        before do
          @tasks_lists = [
            [double(name: 'iOS App Release 1.0.0', gid: '1234567890')],
            [double(name: 'iOS App Hotfix 1.0.0', gid: '123456789')],
            [double(name: 'macOS App Hotfix 1.0.0', gid: '12345678')]
          ]
        end
        it "does not show error" do
          allow(Fastlane::UI).to receive(:user_error!)

          @tasks_lists.each do |tasks|
            find_hotfix_task_in_response(tasks)
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
          @tasks = [double(name: 'macOS App Hotfix Release 1.0.0', gid: '1234567890')]
        end

        it "shows error" do
          allow(Fastlane::UI).to receive(:user_error!)
          find_hotfix_task_in_response(@tasks)
          expect(Fastlane::UI).to have_received(:user_error!).with("Found active hotfix task: https://app.asana.com/0/0/1234567890/f")
        end
      end

      describe "when hotfix task is not present" do
        before do
          @tasks_lists = [
            [double(name: 'macOS App Release 1.0.0', gid: '1234567890')],
            [double(name: 'macOS App Hotfix 1.0.0', gid: '123456789')],
            [double(name: 'iOS App Hotfix 1.0.0', gid: '12345678')]
          ]
        end
        it "does not show error" do
          allow(Fastlane::UI).to receive(:user_error!)

          @tasks_lists.each do |tasks|
            find_hotfix_task_in_response(tasks)
          end
          expect(Fastlane::UI).not_to have_received(:user_error!)
        end
      end
    end

    def find_hotfix_task_in_response(response)
      Fastlane::Actions::AsanaFindReleaseTaskAction.find_hotfix_task_in_response(response)
    end
  end
end
