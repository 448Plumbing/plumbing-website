# DNS cutover for 448Plumbing.com (Google Workspace-managed DNS)

Your domain shows “managed by Google Workspace,” which means DNS changes must be applied in Google Admin / Google Domains DNS. Email (MX) will stay on Google — we’ll only change web (A/AAAA/CNAME).

## Records to set (Google DNS)

1) www host (canonical web site)
- Type: CNAME
- Host/Name: www
- Value: 448Plumbing.github.io
- TTL: 3600 (or default)

2) Apex root (@)
Preferred (if ALIAS/ANAME/flattening exists): point @ to www.448Plumbing.com
Fallback (standard GitHub Pages IPs): add all A/AAAA records
- A @ 185.199.108.153
- A @ 185.199.109.153
- A @ 185.199.110.153
- A @ 185.199.111.153
- AAAA @ 2606:50c0:8000::153
- AAAA @ 2606:50c0:8001::153
- AAAA @ 2606:50c0:8002::153
- AAAA @ 2606:50c0:8003::153

Do NOT change MX records (email).

## Copy/paste request for Google Support

Hello Google Support,

Please update our DNS to host our website on GitHub Pages while leaving email (MX) on Google Workspace.

Domain: 448Plumbing.com
Desired changes:
1) CNAME for host "www" → 448Plumbing.github.io
2) Set apex @ to ALIAS/ANAME/CNAME flattening to www.448Plumbing.com if supported. If not, add the following A/AAAA records:
   A @ 185.199.108.153
   A @ 185.199.109.153
   A @ 185.199.110.153
   A @ 185.199.111.153
   AAAA @ 2606:50c0:8000::153
   AAAA @ 2606:50c0:8001::153
   AAAA @ 2606:50c0:8002::153
   AAAA @ 2606:50c0:8003::153

Please do not change MX or other email-related records.

Thank you.

## After DNS propagates

- In GitHub > repo Settings > Pages: set custom domain to www.448Plumbing.com, click Save.
- Enable “Enforce HTTPS” to provision the certificate (takes up to ~30 minutes).
- Verify:
  - https://www.448Plumbing.com returns 200 OK
  - https://448Plumbing.com redirects to https://www.448Plumbing.com

## Current state (detected)

As of the last check, DNS is still pointed at Squarespace:
- www CNAME → ext-sq.squarespace.com
- Root A → 198.185.159.145

Once the above changes are applied, your GitHub Pages deployment will serve the site.
