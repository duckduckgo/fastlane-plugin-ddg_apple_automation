describe Fastlane::Actions::FreezeReleaseBranchAction do
  describe "#run" do
    subject do
      configuration = Fastlane::ConfigurationHelper.parse(Fastlane::Actions::FreezeReleaseBranchAction, params)
      Fastlane::Actions::FreezeReleaseBranchAction.run(configuration)
    end

    let(:params) do
      {
        platform: "ios",
        github_token: "github-token"
      }
    end

    before do
      allow(Fastlane::Helper::GitHelper).to receive(:freeze_release_branch)
      allow(Fastlane::UI).to receive(:important)
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:report_error)
    end

    it "calls helper" do
      subject
      expect(Fastlane::Helper::GitHelper).to have_received(:freeze_release_branch)
      expect(Fastlane::UI).not_to have_received(:important)
      expect(Fastlane::Helper::DdgAppleAutomationHelper).not_to have_received(:report_error)
    end

    context "when helper fails" do
      before do
        allow(Fastlane::Helper::GitHelper).to receive(:freeze_release_branch).and_raise("error")
      end

      it "reports error" do
        subject
        expect(Fastlane::UI).to have_received(:important)
        expect(Fastlane::Helper::DdgAppleAutomationHelper).to have_received(:report_error)
      end
    end
  end
end
