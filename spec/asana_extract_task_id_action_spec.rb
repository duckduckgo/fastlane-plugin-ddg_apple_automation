describe Fastlane::Actions::AsanaExtractTaskIdAction do
  describe "#run" do
    it "extracts task ID" do
      expect(test_action("https://app.asana.com/0/0/0")).to eq("0")
    end

    it "extracts task ID when project ID is non-zero" do
      expect(test_action("https://app.asana.com/0/753241/9999")).to eq("9999")
    end

    it "extracts task ID when first digit is non-zero" do
      expect(test_action("https://app.asana.com/4/753241/9999")).to eq("9999")
    end

    it "extracts long task ID" do
      expect(test_action("https://app.asana.com/0/0/12837864576817392")).to eq("12837864576817392")
    end

    it "extracts task ID from a URL with a trailing /f" do
      expect(test_action("https://app.asana.com/0/0/1234/f")).to eq("1234")
    end

    it "does not set GHA output when not in CI" do
      allow(Fastlane::Helper).to receive(:is_ci?).and_return(false)
      allow(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output)

      expect(test_action("https://app.asana.com/0/12837864576817392/3465387322")).to eq("3465387322")
      expect(Fastlane::Helper::GitHubActionsHelper).not_to have_received(:set_output)
    end

    it "sets GHA output in CI" do
      allow(Fastlane::Helper).to receive(:is_ci?).and_return(true)
      allow(Fastlane::Helper::GitHubActionsHelper).to receive(:set_output)

      expect(test_action("https://app.asana.com/0/12837864576817392/3465387322")).to eq("3465387322")
      expect(Fastlane::Helper::GitHubActionsHelper).to have_received(:set_output).with("ASANA_TASK_ID", "3465387322")
    end

    it "fails when garbage is passed" do
      expect(Fastlane::UI).to receive(:user_error!).with(Fastlane::Actions::AsanaExtractTaskIdAction::ERROR_MESSAGE)

      test_action("not a URL")
    end
  end

  def test_action(task_url)
    Fastlane::Actions::AsanaExtractTaskIdAction.run(task_url: task_url)
  end
end
