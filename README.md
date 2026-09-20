# Atlas Sheets

Project drawing views, sheets, viewport placement and layout.

**Public beta 0.1.0-beta.2 — Windows x64, Revit 2025 and 2026.** Free for personal and commercial use under [Free Use Terms](FREE-USE-TERMS.txt). Implementation source remains private.

## Install and start

1. Add [Atlas Marketplace](https://github.com/mroshdy91/Atlas-Marketplace) to your AI client.
2. Install **atlas-core** and the specialists you need: **atlas-family**, **atlas-sheets**, **atlas-annotations**.
3. Ask your agent: **Set up RevitAtlas and check its connection to Revit.**
4. Save and close Revit if setup requests it. Restart your AI client once when requested, then open Revit.

The agent runs Core's packaged setup helper, verifies the public runtime download and configures the local connection. No private-repository access, development SDK or manual token entry is needed. Licensed Revit must already be installed. Marketplace installation supplies tools and guidance; Core's one-time Windows setup supplies the native integration.

All four Revit plugins share **one broker and one version-matched engine per Revit process**. Specialists start no extra engine. Sheets and Annotations can work with existing project content without Family. HAPAtlas is a separate product.

See [runtime setup](https://github.com/mroshdy91/RevitAtlas.Core-Plugin/blob/v0.1.0-beta.1/RUNTIME.md) and [supported scope and limitations](RELEASE-READINESS.md). The beta is not universal production qualification. Keep original models and review generated engineering outputs.
