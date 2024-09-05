describe Fastlane::Helper::DdgAppleAutomationHelper do
  describe "#asana_task_url" do
    it "constructs Asana task URL" do
      expect(asana_task_url("1234567890")).to eq("https://app.asana.com/0/0/1234567890/f")
      expect(asana_task_url("0")).to eq("https://app.asana.com/0/0/0/f")
    end

    it "shows error when task_id is empty" do
      allow(Fastlane::UI).to receive(:user_error!)
      asana_task_url("")
      expect(Fastlane::UI).to have_received(:user_error!).with("Task ID cannot be empty")
    end

    def asana_task_url(task_id)
      Fastlane::Helper::DdgAppleAutomationHelper.asana_task_url(task_id)
    end
  end
end
