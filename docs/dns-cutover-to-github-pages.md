# DNS cutover for 448Plumbing.com to GitHub Pages

This pack contains the exact DNS records to move the website hosting from Squarespace to GitHub Pages, keeping email/MX records untouched.

Target: GitHub Pages site for repo 448Plumbing/plumbing-website
- Pages hostname: 448Plumbing.github.io
- Project site path: /plumbing-website/
- Custom domain: www.448Plumbing.com (apex 448Plumbing.com will redirect to www)

## Records to set at Squarespace DNS

Important: Only update A/AAAA and CNAME for web. Do not change MX or other email-related records.

1) www host (canonical web site)
- Type: CNAME
- Host/Name: www
- Value: 448Plumbing.github.io
- TTL: 1 hour (or lowest allowed)

2) Apex root (redirect to www)
If Squarespace DNS supports ANAME/ALIAS at the root, point it to www. Otherwise, use A + AAAA records below.

Option A (preferred where supported):
- Type: CNAME/ALIAS/ANAME
- Host: @
- Value: www.448Plumbing.com
- TTL: 1 hour

Option B (standard GitHub Pages IPs): Add all four A records and two AAAA records.
- Type: A, Host: @, Value: 185.199.108.153
- Type: A, Host: @, Value: 185.199.109.153
- Type: A, Host: @, Value: 185.199.110.153
- Type: A, Host: @, Value: 185.199.111.153
- Type: AAAA, Host: @, Value: 2606:50c0:8000::153
- Type: AAAA, Host: @, Value: 2606:50c0:8001::153
- Type: AAAA, Host: @, Value: 2606:50c0:8002::153
- Type: AAAA, Host: @, Value: 2606:50c0:8003::153
- TTL for all: 1 hour

Note: Some providers require a trailing dot for hostnames (448Plumbing.github.io.). Use it if required.

## Ticket text (copy/paste to Squarespace support)

Hello Squarespace Support,

Please update our DNS records to move web hosting from Squarespace to GitHub Pages, keeping our email records unchanged.

Domain: 448Plumbing.com
Desired changes:
1) Set CNAME for host "www" to 448Plumbing.github.io
2) Set root/apex 448Plumbing.com to point to www.448Plumbing.com (ALIAS/ANAME/CNAME if supported). If not supported, set A/AAAA records to GitHub Pages:
   A @ 185.199.108.153
   A @ 185.199.109.153
   A @ 185.199.110.153
   A @ 185.199.111.153
   AAAA @ 2606:50c0:8000::153
   AAAA @ 2606:50c0:8001::153
   AAAA @ 2606:50c0:8002::153
   AAAA @ 2606:50c0:8003::153

Please do not change MX or any email-related records.

Thanks!

## After DNS propagates

- In GitHub > repo Settings > Pages: set custom domain to www.448Plumbing.com and enable Enforce HTTPS.
- Pages will provision a TLS certificate (can take 5–30 minutes).
- Verify both:
  - https://www.448Plumbing.com (200 OK)
  - https://448Plumbing.com redirects to https://www.448Plumbing.com

## Troubleshooting

- If www shows GitHub 404: The site may still be building; wait a few minutes. Also ensure the repo is public or the Pages source is set to gh-pages.
- If apex doesn’t redirect: Double-check ALIAS/ANAME, or ensure all A/AAAA records are present if CNAME-at-root is not allowed.
- If email breaks: Revert MX changes (we didn’t change them here) and contact Squarespace.
