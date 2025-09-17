448 Plumbing — build & deploy

This workspace contains utilities to build and prepare the static 448 Plumbing site for deployment.

Files added:
- `build.ps1` — copies the site into a `dist` folder, performs light minification of CSS/JS, generates `sitemap.xml` (if `-BaseUrl` provided), creates `robots.txt`, and zips the result.
- `.github/workflows/deploy.yml` — GitHub Actions workflow that runs `build.ps1` and deploys the `dist` folder to GitHub Pages using `peaceiris/actions-gh-pages`.
- `serve.ps1` — a tiny PowerShell static server to preview the site locally (already present).

Quick local preview

Start the local server and open the site in your browser:

pwsh -NoProfile -ExecutionPolicy Bypass -File 'C:\workspace\site\serve.ps1'

Then open http://localhost:8000 in your browser.

Build for production locally

pwsh -NoProfile -ExecutionPolicy Bypass -File 'C:\workspace\site\build.ps1' -Root 'C:\Users\Maitray\Desktop\448Plumbing\448 Plumbing website' -Dist 'C:\workspace\site\dist' -DryRun:$false -BaseUrl 'https://yourdomain.example'

Deploy to GitHub Pages

1. Push this workspace to a GitHub repository's `main` branch.
2. Edit `.github/workflows/deploy.yml` to set the correct `BaseUrl` in the build step (or provide it via workflow env).
3. The workflow will run on push to `main` and publish the `dist` folder to GitHub Pages.

Notes

- The Actions workflow uses the repository `GITHUB_TOKEN` so no additional secrets are required for standard GitHub Pages deployment.
- If you prefer Netlify or Vercel, you can drag the `dist` folder into those UIs for instant deploy.

If you want, I can:
- Add automated image optimizations.
- Replace placeholder images with free stock placeholders.
- Create a polished `CNAME` and set up SSL for a custom domain (requires DNS access).

Tell me which of the above you'd like me to do next.