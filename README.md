# Atlas Sheets

Create and edit Revit drawing views, sheets and layouts. Requires Atlas Core.

**Public beta 0.1.0-beta.3. Windows x64; Revit 2025 and 2026.** Free personal/commercial use; implementation source remains private. See [terms](FREE-USE-TERMS.txt).

Install Atlas Core plus the specialists you need from [Atlas Marketplace](https://github.com/mroshdy91/Atlas-Marketplace), using [your client's installation route](CLIENTS.md). Then ask: **Set up RevitAtlas and check its connection to Revit.** Core's pinned setup helper installs the shared runtime and provisions the connection; users do not paste tokens or need a development SDK. Licensed Revit is a separate prerequisite.

Includes Codex, Claude Code, ZCode and Cursor manifests, portable Agent Plugins 1.0 packaging, and Gemini/Qwen extension manifests. Packaging support is distinct from an independently tested client: [compatibility and evidence](CLIENTS.md). Provider account/plan, trust prompts and gallery approval remain under the client's control.

All four Revit plugins reuse Core runtime **0.1.0-beta.1**. Native engines and authoring tools are unchanged in this packaging release. Non-HTTP clients may run one lightweight stdio connection adapter per active plugin; these exit when their client connection closes. No extra engine, broker service, scheduled task, or server port is installed. HAPAtlas is separate.

This is scoped beta support, not universal family qualification or a completed 15-delivery benchmark. Review engineering outputs. Formal drawing revision/cloud authoring, schedule authoring and cloud/worksharing remain outside the released scope. See [Core runtime qualification](https://github.com/mroshdy91/RevitAtlas.Core-Plugin/blob/v0.1.0-beta.1/RELEASE-READINESS.md).
