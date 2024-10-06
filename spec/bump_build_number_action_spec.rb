describe Fastlane::Actions::BumpBuildNumberAction do
  describe "#run" do
    let(:other_action) { double }

    before do
      expect(Fastlane::Helper::GitHelper).to receive(:setup_git_user)
      allow(Fastlane::Actions).to receive(:lane_context).and_return({ Fastlane::Actions::SharedValues::PLATFORM_NAME => "ios" })
      allow(Fastlane::Action).to receive(:other_action).and_return(other_action)
      allow(Fastlane::Helper::DdgAppleAutomationHelper).to receive(:increment_build_number)
    end

    it "calls helper" do
      test_action("macos")

      expect(Fastlane::Actions).not_to have_received(:lane_context)
      expect(Fastlane::Helper::DdgAppleAutomationHelper).to have_received(:increment_build_number)
        .with("macos", { platform: "macos" }, other_action)
    end

    it "calls helper taking platform from lane context if not provided" do
      test_action(nil)

      expect(Fastlane::Actions).to have_received(:lane_context)
      expect(Fastlane::Helper::DdgAppleAutomationHelper).to have_received(:increment_build_number)
        .with("ios", { platform: "ios" }, other_action)
    end
  end

  def test_action(platform)
    params = { platform: platform }
    allow(params).to receive(:values).and_return(params)

    Fastlane::Actions::BumpBuildNumberAction.run(params)
  end
end
