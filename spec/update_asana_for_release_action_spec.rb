require "date"

describe Fastlane::Actions::UpdateAsanaForReleaseAction do
  describe ".run" do
    let(:tag) { nil }
    let(:params) do
      {
        asana_access_token: "secret-token",
        github_token: "github_token",
        is_scheduled_release: true,
        platform: "ios",
        github_handle: "github_user",
        release_task_id: "1234567890",
        release_type: release_type,
        target_section_id: "987654321",
        tag: tag
      }
    end

    subject do
      configuration = FastlaneCore::Configuration.create(Fastlane::Actions::UpdateAsanaForReleaseAction.available_options, params)
      Fastlane::Actions::UpdateAsanaForReleaseAction.run(configuration)
    end

    before do
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:current_version).and_return("1.1.0")
      allow(Fastlane::Helper::AsanaHelper).to receive(:asana_task_url).and_return("https://app.asana.com/0/1234567890/1234567890")
      allow(Fastlane::Actions::AsanaCreateActionItemAction).to receive(:run)
    end

    context "when release type is internal" do
      let(:release_type) { "internal" }

      it "updates Asana tasks for internal release" do
        expect(Fastlane::Helper::AsanaHelper).to receive(:update_asana_tasks_for_internal_release).with(
          hash_including(
            release_task_id: "1234567890",
            version: "1.1.0"
          )
        )
        subject
      end
    end

    context "when release type is public" do
      let(:release_type) { "public" }
      let(:tag) { "1.116.1-322" }

      before do
        allow(Fastlane::Helper::AsanaHelper).to receive(:update_asana_tasks_for_public_release).and_return("Announcement task notes")
      end

      it "updates Asana tasks for public release" do
        expect(Fastlane::Helper::AsanaHelper).to receive(:update_asana_tasks_for_public_release).with(hash_including(release_task_id: "1234567890", version: "1.116.1"))
        subject
      end

      it "creates an announcement task in Asana" do
        subject
        expect(Fastlane::Actions::AsanaCreateActionItemAction).to have_received(:run).with(
          asana_access_token: "secret-token",
          task_url: "https://app.asana.com/0/1234567890/1234567890",
          task_name: "Announce the release to the company",
          html_notes: "Announcement task notes",
          github_handle: "github_user",
          is_scheduled_release: true,
          due_date: Date.today.strftime('%Y-%m-%d')
        )
      end
    end
  end

  describe ".available_options" do
    it "includes the necessary configuration items" do
      options = Fastlane::Actions::UpdateAsanaForReleaseAction.available_options.map(&:key)
      expect(options).to include(:asana_access_token, :github_token, :platform, :github_handle, :release_task_id, :release_type, :target_section_id)
    end
  end

  describe ".description" do
    it "returns the description" do
      expect(Fastlane::Actions::UpdateAsanaForReleaseAction.description).to eq("Processes tasks included in the release and the Asana release task")
    end
  end

  describe ".authors" do
    it "returns the authors" do
      expect(Fastlane::Actions::UpdateAsanaForReleaseAction.authors).to eq(["DuckDuckGo"])
    end
  end
end
