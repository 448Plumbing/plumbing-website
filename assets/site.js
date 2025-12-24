// Global maintenance mode configuration
// Toggle this to enable/disable the maintenance gate.
window.SITE_MAINTENANCE = true; // Set to false to turn maintenance mode OFF
window.SITE_MAINTENANCE_KEY = '448'; // Query-string key for bypass: ?key=448

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
    const expectedKey = String(window.SITE_MAINTENANCE_KEY || '448');
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

  // Formspree drop-in integration (optional)
  try {
    const form = document.getElementById('contactForm');
    if (form) {
      const id = form.dataset.formspree || '';
      const hasRealId = id && id !== 'your_form_id';
      if (hasRealId) {
        const endpoint = `https://formspree.io/f/${id}`;
        form.addEventListener('submit', async (e) => {
          e.preventDefault();
          if (!form.reportValidity()) return;
          const data = Object.fromEntries(new FormData(form).entries());
          try {
            const res = await fetch(endpoint, {
              method: 'POST',
              headers: { 'Accept': 'application/json', 'Content-Type': 'application/json' },
              body: JSON.stringify(data)
            });
            if (res.ok) {
              alert('Thanks! Your message has been sent.');
              form.reset();
            } else {
              alert('Sorry, there was a problem sending your message. Please try again later.');
            }
          } catch {
            alert('Network error. Please try again later.');
          }
        });
      }
    }
  } catch {}
}

document.addEventListener('DOMContentLoaded', boot);
