// Global maintenance mode configuration
// Toggle this to enable/disable the maintenance gate.
window.SITE_MAINTENANCE = false; // Set to false to turn maintenance mode OFF
window.SITE_MAINTENANCE_KEY = '448m12040'; // Query-string key for bypass: ?key=448m12040

// Guaranteed cleanup: strip any stray rn / `r`n text nodes directly under <body>
document.addEventListener('DOMContentLoaded', () => {
  try {
    const bad = new Set(['rn', 'r n', '`r`n']);
    if (!document.body) return;
    Array.from(document.body.childNodes).forEach(node => {
      if (node.nodeType !== Node.TEXT_NODE) return;
      const t = (node.textContent || '').trim();
      if (bad.has(t)) node.remove();
    });
  } catch {}
});

// Simple maintenance-mode gate with query-string + cookie bypass
(function () {
  try {
    if (window.SITE_MAINTENANCE !== true) return;

    const path = window.location.pathname || '/';

    // Always allow these paths even during maintenance
    const alwaysAllowed = [
      '/maintenance.html',
      '/robots.txt',
      '/sitemap.xml'
    ];

    const isAlwaysAllowed = (
      alwaysAllowed.includes(path) ||
      path.startsWith('/assets/') ||
      path.startsWith('/partials/')
    );

    if (isAlwaysAllowed) return;

    const params = new URLSearchParams(window.location.search || '');
    const expectedKey = String(window.SITE_MAINTENANCE_KEY || '448m12040');
    const providedKey = params.get('key');

    function hasBypassCookie() {
      return document.cookie.split(';').some(c => c.trim().startsWith('maint_bypass=1'));
    }

    let bypass = hasBypassCookie();

    if (providedKey && providedKey === expectedKey) {
      const expires = new Date();
      expires.setDate(expires.getDate() + 7);
      document.cookie = 'maint_bypass=1; path=/; expires=' + expires.toUTCString() + '; SameSite=Lax';
      bypass = true;
    }

    if (!bypass) {
      window.location.replace('/maintenance.html');
    }
  } catch {
    // Fail open if anything goes wrong to avoid locking out the site
  }
})();

async function loadPartial(id, url) {
  try {
    const res = await fetch(url, { cache: 'no-cache' });
    if (!res.ok) return;
    const html = await res.text();
    document.getElementById(id).innerHTML = html;
  } catch {}
}

async function boot() {
  const headerC = document.getElementById('site-header');
  const footerC = document.getElementById('site-footer');
  if (headerC) await loadPartial('site-header', '/partials/header.html');
  if (footerC) await loadPartial('site-footer', '/partials/footer.html');

  // Force-refresh theme.css to avoid CDN/browser cache after updates
  try {
    const links = Array.from(document.querySelectorAll('link[rel="stylesheet"]'));
    links.forEach(l => {
      const href = l.getAttribute('href') || '';
      if (href.includes('/assets/theme.css')) {
        const url = new URL(href, window.location.origin);
        url.searchParams.set('v', String(Math.floor(Date.now() / 1000)));
        l.setAttribute('href', url.pathname + '?' + url.searchParams.toString());
      }
    });
  } catch {}

  // After injection, wire up mobile menu
  const btn = document.getElementById('mobileMenuBtn');
  const menu = document.getElementById('mobileMenu');
  if (btn && menu) {
    btn.addEventListener('click', () => {
      const open = menu.classList.toggle('hidden') === false;
      btn.setAttribute('aria-expanded', String(open));
    });
  }

  // Active link highlighting in header nav
  try {
    const current = window.location.pathname.replace(/\/index\.html$/, '/');
    const header = document.getElementById('site-header');
    if (header) {
      const links = header.querySelectorAll('a[href]');
      links.forEach(a => {
        try {
          const u = new URL(a.getAttribute('href'), window.location.origin);
          let p = u.pathname;
          if (p.endsWith('/index.html')) p = p.replace(/\/index\.html$/, '/');
          // Treat root as / or /index.html equivalently
          const isActive = (p === current) || (p === '/index.html' && current === '/') || (p === '/' && current === '/');
          if (isActive) {
            a.classList.add('active');
            a.setAttribute('aria-current', 'page');
          }
        } catch {}
      });
    }
  } catch {}

  // Home-page-only RMP badge in the top utility bar
  try {
    const path = window.location.pathname || '/';
    const isHome = path === '/' || path === '/index.html';
    const rmpTopbar = document.querySelector('[data-home-rmp-topbar]');
    if (rmpTopbar) {
      rmpTopbar.style.display = isHome ? '' : 'none';
    }
  } catch {}
}

document.addEventListener('DOMContentLoaded', boot);
