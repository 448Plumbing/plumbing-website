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
