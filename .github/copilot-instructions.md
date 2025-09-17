# AI Assistant Project Instructions

## Project Overview
Static marketing site for "448 Plumbing" plus PowerShell utilities for SEO enhancement (`seo-enhance.ps1`), building/minifying (`build.ps1`), and local preview (`serve.ps1`, `start-server.ps1`). GitHub Actions workflow (`.github/workflows/deploy.yml`) builds and deploys to GitHub Pages. No dynamic backend; treat all HTML as static.

## Key Conventions
- Page-per-directory pattern: Each logical page may exist as `pagename.html/index.html` inside the upstream authoring root (outside this repo). Root `site/` here currently holds flat `.html` pages; the SEO script expects a structure with directories named like `services.html` containing `index.html`.
- Use UTF-8 without BOM for all generated/modified files.
- PowerShell scripts are idempotent and support `-DryRun` to preview changes.
- Canonical URLs: root index => BaseUrl; other pages => BaseUrl + `<basename>/` (trailing slash) when processed by `seo-enhance.ps1`.
- SEO meta insertion only if a matching tag (by regex) is absent; never duplicate existing tags.
- Backups: `seo-enhance.ps1` writes originals to `SEOBackup/` with sanitized file name before modifying.
- Build output: `build.ps1` recreates `dist/`, performs naive whitespace/comment minification for CSS/JS/HTML, then (optionally) generates `sitemap.xml` and always writes `robots.txt`.

## Scripts & Typical Flows
1. Enhance SEO for directory-based source (if using that structure):
   `pwsh -File seo-enhance.ps1 -Root <sourceRoot> -BaseUrl https://www.example.com/ -DryRun` then rerun with `-DryRun:$false`.
2. (Planned) Run accessibility & link audit (to be added as `site-audit.ps1`) before build.
3. Build & deploy:
   - Local build: `pwsh -File build.ps1 -Root <sourceRoot> -Dist ./dist -BaseUrl https://www.example.com -DryRun:$false`
   - GitHub Actions auto-runs `build.ps1` and deploys `./dist`.
4. Local preview (PowerShell custom server): `pwsh -File serve.ps1 -Root <sourceRoot>` or Python helper `start-server.ps1` / `start-server.bat`.

## HTML Patterns
- Consistent `<meta name="viewport" content="width=device-width,initial-scale=1">` expected; retain when modifying head.
- Some pages include JSON-LD `<script type="application/ld+json">`; treat contents as opaque—do not minify or reformat.
- External libraries loaded via CDN (Tailwind, AOS, feather-icons); avoid adding build-time dependencies unless explicitly requested.
- Accessibility gaps noticed (e.g., duplicated `contact-button` attributes, missing `alt` on some images in other pages) should be reported rather than auto-fixed unless trivial (adding empty alt for purely decorative images, or synthesizing alt from filename).

## Safe Modification Rules
- Always compute diff-based changes; do not reorder existing meta/link tags except to append newly required ones just before `</head>`.
- Preserve inline scripts & styles. Do not attempt aggressive JS minification (current build uses regex-based stripping only).
- When adding new scripts or utilities, mirror parameter style: positional params avoided; use named params with validation where practical.
- Provide `-DryRun` and JSON report outputs for any new automation (match pattern of `seo-report.json`).

## Reporting & Backups
- New automation should emit a summary object and (non-dry) write `*-report.json` in the root of the processed source.
- Backups stored in a single folder (e.g., `SEOBackup/` or `AuditBackup/`); never overwrite an existing backup copy.

## Future Extension Hooks
- `site-audit.ps1` (to implement) should scan for: broken internal links, missing `lang` attribute, images lacking `alt`, duplicate IDs, and output `accessibility-report.json` with severities.
- Consider combining `seo-enhance` + `site-audit` + `build` into a wrapper script (`optimize-and-build.ps1`).

## What NOT to Do
- Do not introduce server-side tech (Node/Express, etc.).
- Do not change deployment workflow trigger semantics without request.
- Do not inline external CDN libraries into the repo unless bandwidth/offline requirement is specified.

## Quick Reference (Examples)
- Insert canonical if missing: `<link rel="canonical" href="https://example.com/services/" />`
- Insert OG tag if missing: `<meta property="og:title" content="Plumbing Services — 448 Plumbing" />`
- Build invocation (prod): `pwsh -File build.ps1 -Root "C:\path\source" -Dist "C:\path\repo\site\dist" -BaseUrl "https://www.448plumbing.com" -DryRun:$false`

---
If unclear whether to modify content vs. report, prefer reporting and add TODO comments above the affected line in the generated file or surface in JSON report.

## AI execution preference (when asked to finish autonomously)
- Run `site-audit.ps1` first and apply safe fixes (`-Fix`), emitting GitHub-style annotations for issues.
- Execute `optimize-and-build.ps1` to run SEO, audit, and build in sequence.
- Commit and push results to `main` to trigger deployment via GitHub Actions.
- If an analyzer flags likely false positives, prefer running the PowerShell scripts to validate behavior before altering logic.