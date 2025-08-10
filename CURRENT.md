You are working in this repo. Think hard and carefully read SPECIFICATION.md for the functional requirements and AGENT_STEPS.md for the staged plan.

Your task: Start implementing from the existing SwiftPM skeleton.

Your First milestone: complete the CLI argument parsing and legacy-flag compatibility layer (Sources/tn/main.swift), wiring both modern subcommands and the legacy flags into the same code paths.

Once complete, work towards the next milestone, as defined in our AGENT_STEPS.md guide.

You will not get permission to escalate or bypass sandbox permissions. You should not ask.

building swift package code is tricky as it will attempt to access files external to your sandbox. Instead, you should look to utilize arguments and ENV variables that allow you to stage the build environment entirely within your sandbox. Look at bin/spm for a starting point on this.

**ALWAYS**:

- Add validation, proper exit codes, and tests for both the modern and legacy interfaces as described in the spec.
- Follow Swift style conventions (argument-parser idioms, async/await, throwing errors), document public APIs, and ensure all new code is covered by Swift Testing unit tests.
- Commit changes in small, logical units.
- Do not forget to regularly commit your work; You are working autonomously so it's imperative that each step is recoverable.
- Avoid commands that utilize multiple steps (e.g with `&&` chaining). Prefer one step and cache results. You will not get permission to exit the sandbox for commands that are failing due to command errors. Think hard and carefully about the response from the shell command tool to identify why it failed.

As always, you must obey AGENTS.md as your overall source of truth.
