# Themed Dashboard UI Redesign Stitch Export

This folder contains the Stitch reference export for the SpendLens UI redesign.
Use it as visual and structural input alongside `DESIGN.md`; do not copy the
generated HTML directly into Flutter.

## Source

- Stitch project: `Themed Dashboard UI Redesign`
- Project ID: `10071489564617817936`
- Exported from Stitch MCP on 2026-06-13.
- Metadata has been sanitized before committing: `downloadUrl` fields are not
  stored in this repository, and no API keys or auth headers are stored here.

## Contents

- `screens/`: full-resolution Stitch screenshots downloaded from each screen's
  `screenshot.downloadUrl` with `=s0`.
- `html/`: exported Stitch HTML for each screen.
- `metadata/`: sanitized `get_project` and `get_screen` JSON responses.
- `manifest.tsv`: repo-relative file index with screen IDs and dimensions.
- `screens.tsv`: source list of requested Stitch screen IDs and labels.

## Screen Mapping

| Stitch screen | Stitch ID | SpendLens target |
|---|---|---|
| Dashboard - Unified Navigation | `f3403aaa393140f6af702dae86c3faf3` | Dashboard |
| Activity - Scandi-Fintech Refinement | `dae6dd5b20574983b06dcafcc13254f4` | Transactions / activity inspiration |
| Activity - Unified Navigation | `33365c7d10234c68a19502f1b5c468f0` | Transactions list |
| Review - Unified Navigation | `5c775bc19f8f48719fbb8bb5b3de2028` | Merchant Review |
| Vaults - Scandi-Fintech Refinement | `b6bed4ed3bf84003a1a13afd745d4e06` | Piggy Banks |
| Settings - Focused View (No Nav) | `889d58d6265146c4be5b2b0ce6cb6d04` | Settings |
| Transactions - Details (Refined Shapes) | `63469319783552923` | Transaction detail bottom sheet |
| Transactions - Edit Metadata | `10339973839206114960` | Transaction metadata editor |

## Refresh Rules

1. Use the Stitch MCP tools `get_project`, `list_screens`, and `get_screen`.
2. For screenshots, download each `screenshot.downloadUrl` with `=s0` appended
   to keep the full available dimensions.
3. For code references, download each `htmlCode.downloadUrl`.
4. Before committing metadata, remove all `downloadUrl` fields.
5. Keep this folder as reference material only; production Flutter UI should use
   native widgets, shared theme tokens, and responsive layouts.
