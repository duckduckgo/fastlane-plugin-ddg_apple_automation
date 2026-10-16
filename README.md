# ddg_apple_automation plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-ddg_apple_automation)

## Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-ddg_apple_automation`, add it to your project by running:

```bash
fastlane add_plugin ddg_apple_automation
```

## About ddg_apple_automation

This plugin contains actions used by DuckDuckGo iOS and macOS release automation. It's meant for internal use only. We do not accept contributions to this repository at this time.

**Note to author:** Add a more detailed description about this plugin here. If your plugin contains multiple actions, make sure to mention them here.

## Example

Check out the [example `Fastfile`](fastlane/Fastfile) to see how to use this plugin. Try it by cloning the repo, running `fastlane install_plugins` and `bundle exec fastlane test`.

### Local release merges

`tag_release` merges locally with `git merge --strategy=ort`. No strategy option is required.

Internal releases merge the release tag; public releases with `ignore_untagged_commits` merge the release branch before deleting it. Local merges fetch full history into an isolated temporary repository, so shallow or detached checkouts and local changes are supported. `base_branch` still selects the destination (default `main`). Temporary repositories use Ruby's standard temporary directory (`TMPDIR` when set) and are removed on success or failure.

The runner needs Git with the `ort` strategy and Git's environment-based configuration support (Git 2.34 or newer). HTTPS fetch and push use `github_elevated_permissions_token` when supplied, otherwise `github_token`, without persisting credentials or putting them in command arguments. The token needs repository contents write access, and repository branch rules must permit the normal push. Protection rejections and concurrent base updates fail through the existing release and Asana error reporting; no force push or automatic retry is used. An already-merged ref succeeds without pushing.

For apple-browsers integration, once a plugin version containing this change is released, update both platforms' `Pluginfile` and `Gemfile.lock` to that released version. Existing tag-release invocations will use local `ort` merges automatically. No version is assigned by this change. Validate against a disposable repository/base branch before enabling release publication.

Focused checks (all publication and external services mocked):

```bash
bundle exec rspec spec/local_git_merge_helper_spec.rb spec/git_helper_spec.rb spec/tag_release_action_spec.rb
```

## Run tests for this plugin

To run both the tests, and code style validation, run

```
rake
```

To automatically fix many of the styling issues, use
```
rubocop -a
```

## Issues and Feedback

For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).
