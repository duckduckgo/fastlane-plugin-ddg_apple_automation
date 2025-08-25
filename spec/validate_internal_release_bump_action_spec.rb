describe Fastlane::Actions::ValidateInternalReleaseBumpAction do
  shared_context "common setup" do
    before do
      @params = {
        asana_access_token: "secret-token",
        github_token: "github_token",
        platform: "ios",
        release_task_url: nil
      }

      allow(Fastlane::Helper::GitHelper).to receive(:setup_git_user)
      allow(Fastlane::Helper::GitHelper).to receive(:assert_release_branch_is_not_frozen)
      allow(Fastlane::Helper::GitHelper).to receive(:assert_branch_has_changes).and_return(true)
      allow(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output)
      allow(Fastlane::Helper::AsanaHelper).to receive(:fetch_release_notes).and_return("Valid release notes")
      allow(Fastlane::Helper::AsanaHelper).to receive(:extract_asana_task_id).and_return("987654321")
      allow(Fastlane::Actions).to receive(:lane_context).and_return({ Fastlane::Actions::SharedValues::PLATFORM_NAME => "ios" })

      @other_action = double(ensure_git_branch: nil, git_branch: "release_branch_name")
      allow(Fastlane::Action).to receive(:other_action).and_return(@other_action)
      allow(Fastlane::Actions).to receive(:other_action).and_return(@other_action)
      allow(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:find_latest_marketing_version)
        .and_return("1.0.0")

      allow(Fastlane::Actions::ValidateInternalReleaseBumpAction).to receive(:find_release_task_if_needed) do |params|
        params[:release_branch] = "release_branch_name"
        params[:release_task_id] = "mock_task_id"
      end
    end
  end

  shared_context "on ios" do
    before do
      @params[:platform] = "ios"
    end
  end

  shared_context "on macos" do
    before do
      @params[:platform] = "macos"
    end
  end

  describe "#run" do
    subject do
      configuration = FastlaneCore::Configuration.create(Fastlane::Actions::ValidateInternalReleaseBumpAction.available_options, @params)
      Fastlane::Actions::ValidateInternalReleaseBumpAction.run(configuration)
    end
    include_context "common setup"

    context "when there are changes in the release branch" do
      it "proceeds with release bump if release notes are valid" do
        expect(Fastlane::UI).to receive(:message).with("Validating release notes")
        expect(Fastlane::UI).to receive(:message).with("Release notes are valid: Valid release notes")
        subject
      end

      it "raises an error if release notes contain placeholder text" do
        allow(Fastlane::Helper::AsanaHelper).to receive(:fetch_release_notes).and_return("<-- Add release notes here -->")
        expect(Fastlane::UI).to receive(:message).with("Validating release notes")
        expect(Fastlane::UI).to receive(:user_error!).with("Release notes are empty or contain a placeholder. Please add release notes to the Asana task and restart the workflow.")
        subject
      end
    end

    context "when there are no changes in the release branch" do
      before do
        allow(Fastlane::Helper::GitHelper).to receive(:assert_branch_has_changes).and_return(false)
      end

      context "when it's a scheduled release" do
        before do
          @params[:is_scheduled_release] = true
        end

        it "skips the release" do
          allow(Fastlane::Helper::GitHelper).to receive(:assert_branch_has_changes).and_return(false)
          expect(Fastlane::UI).to receive(:important).with("No changes to the release branch (or only changes to scripts and workflows). Skipping automatic release.")
          expect(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output).with("skip_release", true)
          subject
        end
      end

      context "when it's not a scheduled release" do
        it "proceeds with release bump if release notes are valid" do
          expect(Fastlane::UI).to receive(:message).with("Validating release notes")
          expect(Fastlane::UI).to receive(:message).with("Release notes are valid: Valid release notes")
          subject
        end
      end
    end
  end

  describe "#find_release_task_if_needed" do
    include_context "common setup"

    context "when release_task_url is provided" do
      it "sets release_task_id and release_branch from release_task_url" do
        allow(Fastlane::Actions::ValidateInternalReleaseBumpAction).to receive(:find_release_task_if_needed).and_call_original
        @params[:release_task_url] = "https://app.asana.com/0/1234567890/987654321"
        Fastlane::Actions::ValidateInternalReleaseBumpAction.find_release_task_if_needed(@params)

        expect(Fastlane::Helper::AsanaHelper).to have_received(:extract_asana_task_id).with(@params[:release_task_url], set_gha_output: false)
        expect(Fastlane::Actions.other_action).to have_received(:ensure_git_branch).with(branch: "^release/.+$")
        expect(@params[:release_branch]).to eq("release_branch_name")
        expect(@params[:release_task_id]).to eq("987654321")
      end
    end

    context "when release_task_url is not provided" do
      it "runs AsanaFindReleaseTaskAction to find the release task" do
        allow(Fastlane::Actions::ValidateInternalReleaseBumpAction).to receive(:find_release_task_if_needed).and_call_original
        allow(Fastlane::Actions::AsanaFindReleaseTaskAction).to receive(:run).and_return({ release_task_id: "1234567890", release_branch: "release_branch_name" })
        Fastlane::Actions::ValidateInternalReleaseBumpAction.find_release_task_if_needed(@params)

        expect(Fastlane::Actions::AsanaFindReleaseTaskAction).to have_received(:run).with(
          asana_access_token: "secret-token",
          github_token: "github_token",
          platform: "ios"
        )
        expect(@params[:release_task_id]).to eq("1234567890")
        expect(@params[:release_branch]).to eq("release_branch_name")
      end
    end
  end

  # Constants and Configuration
  describe "constants and configuration" do
    it "returns the description" do
      expect(Fastlane::Actions::ValidateInternalReleaseBumpAction.description).to eq("Performs checks to decide if a subsequent internal release should be made")
    end

    it "returns the authors" do
      expect(Fastlane::Actions::ValidateInternalReleaseBumpAction.authors).to eq(["DuckDuckGo"])
    end

    it "returns the correct details" do
      expected_details = <<-DETAILS
This action performs the following tasks:
* finds the git branch and Asana task for the current internal release,
* checks for changes to the release branch,
* ensures that release notes aren't empty or placeholder.
      DETAILS
      expect(Fastlane::Actions::ValidateInternalReleaseBumpAction.details.strip).to eq(expected_details.strip)
    end

    it "includes the necessary configuration items" do
      options = Fastlane::Actions::ValidateInternalReleaseBumpAction.available_options.map(&:key)
      expect(options).to include(:asana_access_token, :github_token, :platform, :release_task_url)
    end

    it "supports macos and ios platforms" do
      expect(Fastlane::Actions::ValidateInternalReleaseBumpAction.is_supported?(:macos)).to be true
      expect(Fastlane::Actions::ValidateInternalReleaseBumpAction.is_supported?(:ios)).to be true
    end
  end
end
