You are working in this repo. Think hard and carefully read SPECIFICATION.md for the functional requirements and AGENT_STEPS.md for the staged plan.

Your task: Resolve the outstanding test failures, and work to ensure you can cleanly build/test/lint/format WITHIN your sandbox to avoid privilege escalations.

Your First milestones:

- Ensure build/test works completely/safely within the sandbox.
- resolve tests so the suite is green
- Validate format/lint works completely within the sandbox.

Once complete, work towards the next milestone, as defined in our AGENT_STEPS.md guide.

**NOTES**:
 - You will not get permission to escalate or bypass sandbox permissions. You should not ask.
 - Building swift package code is tricky as it will attempt to access files external to your sandbox. Instead, you should look to utilize arguments and ENV variables that allow you to stage the build environment entirely within your sandbox. Look at bin/spm for a starting point on this.

As always, you must obey AGENTS.md as your overall source of truth.
