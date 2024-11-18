describe Fastlane::Actions::AsanaGetTasksInLastInternalReleaseAction do
  describe "#run" do
    it "calls helper with the correct parameters" do
      params = { platform: "macos", github_token: "github-token" }
      tasks_list = "<ul><li><a data-asana-gid='123456'/></li></ul>"

      expect(Fastlane::Helper::AsanaHelper).to receive(:get_tasks_in_last_internal_release)
        .with(params[:platform], params[:github_token])
        .and_return(tasks_list)

      expect(Fastlane::Actions::AsanaGetTasksInLastInternalReleaseAction.run(params)).to eq(tasks_list)
    end
  end
end
