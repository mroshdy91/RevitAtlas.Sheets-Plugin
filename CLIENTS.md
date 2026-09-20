# Client compatibility and installation

Atlas connects to **licensed Revit 2025/2026 on Windows**. Run the MCP connection on the same Windows PC and account. Your choice of model is separate from your client's plugin/MCP support.

This package targets current documented formats, not every historical client version. **Format-compatible does not mean independently live-tested.** See the evidence table below. No Claude/Cursor/Copilot/ZCode subscription is included. Enterprise policies and third-party gallery acceptance cannot be granted by Atlas.

## Choose your route

| Client | Installation route | Package |
|---|---|---|
| Codex desktop/CLI | Add `mroshdy91/Atlas-Marketplace`; install `atlas-core` and chosen specialists | Codex manifest and portable Agent Plugins |
| Claude Code (local Windows) | `/plugin marketplace add mroshdy91/Atlas-Marketplace`, then `/plugin install atlas-core@atlas-marketplace` and specialists | Claude plugin |
| ZCode | Open a workspace; Settings → Plugins → Add marketplace → `mroshdy91/Atlas-Marketplace`; install Core and specialists | ZCode manifest |
| Cursor | Add the Git marketplace where your plan permits; otherwise install the individual plugin through its supported local plugin route | Cursor/Agent Plugins |
| GitHub Copilot CLI | `copilot plugin marketplace add mroshdy91/Atlas-Marketplace`, then `copilot plugin install atlas-core@atlas-marketplace` and specialists | Agent Plugins |
| GitHub Copilot in VS Code | Add `mroshdy91/Atlas-Marketplace` to `chat.plugins.marketplaces`; browse Agent Plugins and install | Agent Plugins |
| GitHub Copilot app | Use the app's supported Agent Plugins install route, with a local Windows execution host | Agent Plugins; host must be verified |
| Factory Droid | `droid plugin marketplace add https://github.com/mroshdy91/Atlas-Marketplace`; read the registered name with `droid plugin marketplace list`, then install | Claude-compatible plugin translation |
| Qwen Code | `qwen extensions install mroshdy91/Atlas-Marketplace:atlas-core` and specialists, or install each public plugin repository | Qwen extension/Claude marketplace |
| Gemini CLI | `gemini extensions install https://github.com/mroshdy91/RevitAtlas.Core-Plugin --ref v0.1.0-beta.3`, then chosen plugin repositories | Gemini extension; gallery submission is separate |
| Kiro | Powers → Add Custom Power → import each public plugin repository; install Core first | Agent Plugins power |
| Hermes Agent | Install each public plugin repository with `hermes plugins install owner/repository --no-enable`, inspect, then enable | Agent Plugins; requires Windows-local MCP execution |
| OpenClaw | Install the public plugin repository through its documented bundle install route | Agent Plugins bundle; requires Windows-local MCP execution |
| Antigravity | Export the matching local plugin using the helper below, then `agy plugin install <export-folder>` or use its documented plugin directory | Antigravity manifest, skills and MCP config; format-tested only |
| Other Agent Plugins 1.0 clients | Import the individual public plugin repository using that client's supported route | Root `plugin.json`, `skills/`, `mcp.json`; requires stdio on Windows |

Specialist repositories: `mroshdy91/RevitAtlas.Family-Plugin`, `mroshdy91/RevitAtlas.Sheets-Plugin`, `mroshdy91/RevitAtlas.Annotations-Plugin`. Each remains independently selectable. Marketplace catalogs do not make every vendor's curated gallery list Atlas automatically.

## Setup without manual token handling

After installing Core and the desired specialists, ask the agent: **Set up RevitAtlas and check its connection to Revit.** The packaged Core skill works before MCP connects. It diagnoses prerequisites and installs the pinned shared runtime when authorized. Save/close Revit and restart/reconnect only when requested. No source access, SDK or token copying is required.

The portable stdio adapter runs `powershell.exe` with `-NoProfile -NonInteractive -File`; it never changes Windows execution policy. It uses the current process's explicitly supplied credential first, otherwise the credential already provisioned for the Windows user. It forwards only to the fixed authenticated loopback Atlas endpoint, rejects redirects, and preserves tool results, operation identities and image content. If a client disables local processes or Windows policy blocks scripts, report that condition rather than bypass it.

There is still one shared broker and one version-matched native engine per Revit process. A stdio client starts a small connection process for each enabled specialist; no duplicate engine or permanent background service. Codex's native HTTP configuration is retained in `mcp.codex.json`.

## Evidence levels

Checked 20 September 2026 on Windows. Native engine qualification remains the retained Revit 2025/2026 beta scope.

| Client/check | Actual evidence | Remaining limitation |
|---|---|---|
| Codex desktop/CLI | Retained published native authoring, inspection, images and drawing checks on 2025/2026; new packaging installed-client discovery checked separately | No claim that every family workflow passes |
| Claude Code 2.1.278 | All four plugins installed; all four MCP connections passed | No new Claude model authoring evaluation |
| Gemini CLI 0.60.0 | All four extensions and skills discovered; all four MCP connections passed | No new Gemini model authoring evaluation |
| Qwen Code 0.24.2 | All four extensions installed; all four MCP connections passed | No new Qwen model authoring evaluation |
| Copilot CLI 1.0.86 | Marketplace install, all four plugins and MCP configurations discovered | Full connection/model execution not qualified in this client |
| ZCode CLI 0.16.9 | Manifest validation, marketplace installation and skills discovery passed | Live app-server test blocked by missing local built-in provider configuration; no live execution claim |
| Portable adapter / independent MCP SDK | 27 typed tools; native geometry creation/measurement; operation recovery; actual image; save/close on Revit 2025; UTF-8, deep JSON, errors and protocol checks | Shared transport evidence, not a substitute for every client test |
| Cursor, VS Code, Factory, Kiro, Hermes, OpenClaw | Published formats/documentation researched; applicable manifests generated; standard schemas validated | Individual client execution unqualified |
| Antigravity and generic exports | Export structure, preserved skills/setup, absolute adapter paths and refusal to overwrite tested | Individual client execution unqualified |

Do not treat schema validation, a marketplace listing or provider documentation as a live acceptance test. Supported format routes are available for beta testing; client-specific limits remain visible. Native runtime files are unchanged.

## Export a connection or Antigravity plugin

The agent can run the helper from each installed plugin; no token is written into the exported file:

```powershell
powershell.exe -NoProfile -NonInteractive -File "<plugin-folder>/scripts/atlas-client-config.ps1" -Client vscode -Surface core -OutputPath "<new-config-file>.json"
```

Choose `generic` for the common `mcpServers` format, `vscode`, `opencode`, or `continue` for their documented config shapes. Continue accepts the generated JSON as YAML content. Merge only the named server through the client's supported settings flow, preserving other servers. Keep the package at its current path, and install/load its `skills/` through that client's supported skill mechanism. An MCP-only connection does not automatically install guidance.

For Antigravity, choose `-Client antigravity` and an **absent directory** as `-OutputPath`. Run the helper from the matching surface's package. It exports the required manifest, skills, setup helper and `mcp_config.json`; install that directory with `agy plugin install`. Keep the export directory because the connection uses its absolute script path. Alternatively export directly into its documented workspace plugin directory. Export afresh and update the client path when upgrading; existing directories are never overwritten.

## Other markets and execution boundaries

Cline, Windsurf/Devin, Roo Code, Continue and similar MCP catalogs are not necessarily compatible with Git plugin marketplaces. Use their documented custom MCP route plus the installed Atlas skill when available; do not claim that adding the Atlas repository installs a native extension into every such product. OpenCode's native JavaScript plugin ecosystem is a different contract. We provide an explicit connection-config export for these clients; their store approval remains separate.

Cloud-only Grok Bot, browser chat, remote Copilot tasks and containerized NanoClaw cannot automatically reach the Windows broker. Portable package recognition does not overcome that execution boundary. WSL/SSH/container execution needs a separately verified Windows-local MCP host; this release does not expose Revit over a public address or automatically build a tunnel. Claude web/Cowork and Claude Code are different client surfaces.

## Official format references

- [Agent Plugins clients and transport specification](https://agent-plugins.org/compatible-clients)
- [Claude Code plugins](https://code.claude.com/docs/en/plugins-reference)
- [ZCode plugins](https://zcode.z.ai/en/docs/plugin)
- [Cursor plugins](https://cursor.com/docs/reference/plugins)
- [Copilot CLI](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference)
- [VS Code Agent Plugins](https://code.visualstudio.com/docs/agent-customization/agent-plugins)
- [Factory plugins](https://docs.factory.ai/harness/plugins)
- [Gemini extensions](https://geminicli.com/docs/extensions/reference/)
- [Qwen extensions](https://github.com/QwenLM/qwen-code/blob/main/docs/users/extension/introduction.md)
- [Kiro powers](https://kiro.dev/docs/powers/create/)
- [Hermes plugins](https://hermes-agent.nousresearch.com/docs/developer-guide/plugins)
- [OpenClaw bundles](https://docs.openclaw.ai/plugins/bundles)

- [Antigravity plugins](https://antigravity.google/docs/plugins)
- [OpenCode configuration](https://opencode.ai/v2/docs/config)
- [Continue configuration](https://docs.continue.dev/reference)
