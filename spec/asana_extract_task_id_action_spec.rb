describe Fastlane::Actions::AsanaExtractTaskIdAction do
  describe "#run" do
    it "calls helper" do
      expect(Fastlane::Helper::AsanaHelper).to receive(:extract_asana_task_id)
        .with("https://app.asana.com/0/0/0").and_return("0")
      expect(test_action("https://app.asana.com/0/0/0")).to eq("0")
    end
  end

  def test_action(task_url)
    Fastlane::Actions::AsanaExtractTaskIdAction.run(task_url: task_url)
  end
end
