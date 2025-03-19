shared_context "common setup" do
  before do
    @params = {
      asana_access_token: "secret-token",
      github_token: "github_token",
      github_handle: "user",
      target_section_id: "12345",
      version: "1.0.0"
    }

    allow(Fastlane::Helper::GitHelper).to receive(:setup_git_user)
    allow(Fastlane::Helper::AsanaHelper).to receive(:get_asana_user_id_for_github_handle).and_return("user")
    allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:prepare_release_branch).and_return(["release_branch_name", "1.1.0"])
    allow(Fastlane::Helper::AsanaHelper).to receive(:create_release_task).and_return("1234567890")
    allow(Fastlane::Helper::AsanaHelper).to receive(:update_asana_tasks_for_internal_release)
    allow(Fastlane::Actions).to receive(:lane_context).and_return({ Fastlane::Actions::SharedValues::PLATFORM_NAME => "ios" })

    other_action_double = double("other_action")
    allow(other_action_double).to receive(:setup_constants)
    allow(Fastlane::Actions).to receive(:other_action).and_return(other_action_double)
  end
end

shared_context "on ios" do
  before do
    @params[:platform] = "ios"
    allow(Fastlane::Actions.other_action).to receive(:setup_constants).with(@params[:platform])
  end
end

shared_context "on macos" do
  before do
    @params[:platform] = "macos"
    allow(Fastlane::Actions.other_action).to receive(:setup_constants).with(@params[:platform])
  end
end

describe Fastlane::Actions::StartNewReleaseAction do
  describe '#run' do
    subject do
      configuration = Fastlane::ConfigurationHelper.parse(Fastlane::Actions::StartNewReleaseAction, @params)
      Fastlane::Actions::StartNewReleaseAction.run(configuration)
    end

    include_context "common setup"

    context "on ios" do
      include_context "on ios"

      it 'sets up git user' do
        subject
        expect(Fastlane::Helper::GitHelper).to have_received(:setup_git_user)
      end

      it 'gets Asana user ID based on GitHub handle' do
        subject
        expect(Fastlane::Helper::AsanaHelper).to have_received(:get_asana_user_id_for_github_handle).with("user")
      end

      it 'prepares the release branch' do
        subject
        expect(Fastlane::Helper::DdgAppleAutomationHelper).to have_received(:prepare_release_branch).with("ios", "1.0.0", anything)
      end

      it 'creates a release task in Asana' do
        subject
        expect(Fastlane::Helper::AsanaHelper).to have_received(:create_release_task).with("ios", "1.1.0", "user", "secret-token", { is_hotfix: false })
      end

      it 'updates Asana tasks for internal release' do
        subject
        expect(Fastlane::Helper::AsanaHelper).to have_received(:update_asana_tasks_for_internal_release).with(
          hash_including(
            platform: "ios",
            version: "1.1.0",
            release_branch_name: "release_branch_name",
            release_task_id: "1234567890",
            asana_access_token: "secret-token"
          )
        )
      end

      it 'doesn\'t warn on TDS performance tests success' do
        subject
        expect(Fastlane::Actions::AsanaAddCommentAction).not_to receive(:run)
      end

      context "on TDS performance tests failure" do
        before do
          allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:prepare_release_branch).and_return(["release_branch_name", "1.1.0", true])
          allow(Fastlane::Actions::AsanaAddCommentAction).to receive(:run)
        end
        it 'warns about TDS performance tests failures' do
          subject
          expect(Fastlane::Actions::AsanaAddCommentAction).to have_received(:run).with(
            hash_including(
              task_id: "1234567890",
              comment: include("TDS performance tests failed")
            )
          )
        end
      end
    end

    context "on macos" do
      include_context "on macos"

      it 'sets up git user' do
        subject
        expect(Fastlane::Helper::GitHelper).to have_received(:setup_git_user)
      end

      it 'gets Asana user ID based on GitHub handle' do
        subject
        expect(Fastlane::Helper::AsanaHelper).to have_received(:get_asana_user_id_for_github_handle).with("user")
      end

      it 'prepares the release branch' do
        subject
        expect(Fastlane::Helper::DdgAppleAutomationHelper).to have_received(:prepare_release_branch).with("macos", "1.0.0", anything)
      end

      it 'creates a release task in Asana' do
        subject
        expect(Fastlane::Helper::AsanaHelper).to have_received(:create_release_task).with("macos", "1.1.0", "user", "secret-token", { is_hotfix: false })
      end

      it 'updates Asana tasks for internal release' do
        subject
        expect(Fastlane::Helper::AsanaHelper).to have_received(:update_asana_tasks_for_internal_release).with(
          hash_including(
            platform: "macos",
            version: "1.1.0",
            release_branch_name: "release_branch_name",
            release_task_id: "1234567890",
            asana_access_token: "secret-token"
          )
        )
      end

      context "with hotfix release" do
        before do
          @params[:is_hotfix] = true

          allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:prepare_hotfix_branch)
            .and_return(["hotfix_branch_name", "1.0.1"])
          allow(Fastlane::Helper::AsanaHelper).to receive(:create_release_task)
            .and_return("9876543210")
          allow(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output)
        end

        it "sets up git user" do
          subject
          expect(Fastlane::Helper::GitHelper).to have_received(:setup_git_user)
        end

        it "gets Asana user ID based on GitHub handle" do
          subject
          expect(Fastlane::Helper::AsanaHelper).to have_received(:get_asana_user_id_for_github_handle).with("user")
        end

        it "prepares the hotfix branch" do
          subject
          expect(Fastlane::Helper::DdgAppleAutomationHelper).to have_received(:prepare_hotfix_branch)
            .with("github_token", "macos", anything, hash_including(asana_user_id: "user"))
        end

        it "creates a hotfix release task in Asana" do
          subject
          expect(Fastlane::Helper::AsanaHelper).to have_received(:create_release_task)
            .with("macos", "1.0.1", "user", "secret-token", { is_hotfix: true })
        end

        it "does not update Asana tasks for internal release" do
          subject
          expect(Fastlane::Helper::AsanaHelper).not_to have_received(:update_asana_tasks_for_internal_release)
        end
      end
    end
  end

  # Constants
  describe '#available_options' do
    it 'includes the necessary configuration items' do
      options = Fastlane::Actions::StartNewReleaseAction.available_options.map(&:key)
      expect(options).to include(:asana_access_token, :github_token, :platform, :version, :github_handle, :target_section_id)
    end
  end

  describe '#is_supported?' do
    it 'supports macos and ios platforms' do
      expect(Fastlane::Actions::StartNewReleaseAction.is_supported?(:macos)).to be true
      expect(Fastlane::Actions::StartNewReleaseAction.is_supported?(:ios)).to be true
    end
  end

  describe '.description' do
    it 'returns the description' do
      expect(described_class.description).to eq("Starts a new release")
    end
  end

  describe '.authors' do
    it 'returns the authors' do
      expect(described_class.authors).to include("DuckDuckGo")
    end
  end

  describe '.return_value' do
    it 'returns the return value description' do
      expect(described_class.return_value).to eq("The newly created release task ID")
    end
  end
end
