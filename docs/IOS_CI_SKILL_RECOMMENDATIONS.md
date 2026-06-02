# iOS CI and debugging skill recommendations

I would install these **in this order** for an iOS CI/debugging workflow.
I ranked them by a mix of **direct relevance to failing CI**,
**iOS/Xcode usefulness**, **GitHub stars**, and whether the repo is actively
structured as a Codex/agent skill.

| Rank | Skill / repo                                                      | GitHub signal | Why it matters for your iOS CI problem |
| ---: | ----------------------------------------------------------------- | -----------------------------------------------------------------------: | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|    1 | **OpenAI `gh-fix-ci`**, inside `openai/skills`                    | `openai/skills` has about **21.1k stars** | This is the first one I would use. It is an official curated Codex skill for failing GitHub Actions PR checks. It uses `gh` to inspect PR checks, fetch logs, identify failing jobs, summarize the failure, and propose a fix plan. |
|    2 | **getsentry/XcodeBuildMCP**, especially its `xcodebuildmcp` skill | About **5.8k stars**, latest release shown as **v2.6.0 on June 1, 2026** | This is the best iOS-specific debugging companion. It gives the agent build, test, run, simulator, device, log capture, LLDB, screenshots, view hierarchy, UI automation, and SwiftPM workflows. |
|    3 | **twostraws/SwiftUI-Agent-Skill**                                 | About **4k stars** | Best high-rated SwiftUI correctness skill. It targets common LLM mistakes in SwiftUI, including deprecated API, accessibility mistakes, and performance problems. |
|    4 | **Dimillian/Skills**, especially `ios-debugger-agent`             | About **3.6k stars** | Strong iOS debugging skill. The `ios-debugger-agent` skill uses XcodeBuildMCP to build, launch, inspect, interact with the simulator, capture screenshots, and gather logs. |
|    5 | **AvdLee/SwiftUI-Agent-Skill**                                    | About **2.9k stars** | Another high-rated SwiftUI expert skill, focused on state management, view composition, performance, and iOS 26+ Liquid Glass adoption. I would use this as a review pass after Codex gets the build green. |

My practical recommendation is: **use `gh-fix-ci` plus XcodeBuildMCP as the core pair**, then add the SwiftUI/Swift skills for code quality and iOS-specific remediation.

For installation, start with:

```bash
# In Codex, install the official CI fixer:
$skill-installer gh-fix-ci
```

```bash
# Install XcodeBuildMCP:
brew tap getsentry/xcodebuildmcp
brew install xcodebuildmcp

# Or:
npm install -g xcodebuildmcp@latest

# Then initialize its agent skills:
xcodebuildmcp init
```

For broader Swift/iOS coverage, this one is also worth adding even though it is less directly CI-focused:

```bash
npx skills add dpearson2699/swift-ios-skills --all
```

That repo bundles **84 iOS/Swift skills**, including SwiftUI, Swift core, iOS frameworks, engineering skills, and Apple platform skills, and it explicitly documents Codex installation.

For your actual failing PR, prompt Codex like this:

```text
Use the gh-fix-ci skill first. Inspect the failing GitHub Actions checks for the current PR using gh, pull the failing job logs, identify the exact failing command and error, and produce a concise root-cause analysis.

Then use XcodeBuildMCP to reproduce the closest equivalent build/test locally for the relevant scheme, simulator, and test target. Do not guess. Compare the CI failure against the local XcodeBuildMCP result. Make the smallest production-quality fix that addresses the actual failure, then rerun the targeted build/test command and summarize the diff and remaining risks.
```

Also add this to your repo’s `AGENTS.md` so Codex stops flailing around with generic commands:

```md
## iOS CI Debugging Rules

When CI fails, first use `gh-fix-ci` to inspect the failing GitHub Actions run and retrieve the exact failing log section. Do not infer the failure from file names or recent edits alone.

For local iOS reproduction, use XcodeBuildMCP rather than hand-written `xcodebuild`, `xcrun`, or `simctl` commands unless XcodeBuildMCP cannot produce complete logs. Always identify the workspace/project, scheme, destination simulator, and failing test target before changing code.

After each fix, rerun the narrowest relevant build or test command first. Only run the full suite after the targeted failure is resolved.
```
