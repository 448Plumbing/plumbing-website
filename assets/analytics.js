/* 448 Plumbing: optional GA4 reporting. Never send customer form contents. */
(function () {
  'use strict';
  const measurementId = 'G-87YTSTSNCJ';
  const preferenceKey = '448-analytics-consent-v1';
  const hostname = window.location.hostname;
  const production = hostname === 'www.448plumbing.com' || hostname === '448plumbing.com';
  let preference = '';
  let started = false;
  let banner;
  try { preference = localStorage.getItem(preferenceKey) || ''; } catch (_) {}
  if (navigator.globalPrivacyControl === true || navigator.doNotTrack === '1') preference = 'no';

  function cleanUrl(value) {
    try { const url = new URL(value); return url.origin + url.pathname; } catch (_) { return ''; }
  }

  function start() {
    if (started || preference !== 'yes' || !production) return;
    started = true;
    window['ga-disable-' + measurementId] = false;
    window.dataLayer = window.dataLayer || [];
    window.gtag = window.gtag || function () { window.dataLayer.push(arguments); };
    window.gtag('consent', 'default', {
      analytics_storage: 'granted', ad_storage: 'denied',
      ad_user_data: 'denied', ad_personalization: 'denied'
    });
    window.gtag('js', new Date());
    const config = {
      allow_google_signals: false,
      allow_ad_personalization_signals: false,
      page_location: cleanUrl(window.location.href),
      page_referrer: cleanUrl(document.referrer),
      cookie_expires: 60 * 60 * 24 * 90,
      cookie_update: false
    };
    // Accept only short marketing labels; never arbitrary query strings or form data.
    const params = new URLSearchParams(window.location.search);
    const fields = { utm_source: 'campaign_source', utm_medium: 'campaign_medium', utm_campaign: 'campaign_name', utm_content: 'campaign_content' };
    Object.keys(fields).forEach(function (key) {
      const value = params.get(key);
      if (value && /^[a-z0-9_-]{1,64}$/i.test(value)) config[fields[key]] = value;
    });
    window.gtag('config', measurementId, config);
    const script = document.createElement('script');
    script.async = true;
    script.src = 'https://www.googletagmanager.com/gtag/js?id=' + measurementId;
    document.head.appendChild(script);
  }

  function track(name, params) {
    if (preference === 'yes' && started && typeof window.gtag === 'function') window.gtag('event', name, params || {});
  }

  function choose(value) {
    preference = value;
    try { localStorage.setItem(preferenceKey, value); } catch (_) {}
    if (value === 'yes') {
      if (started && window.gtag) window.gtag('consent', 'update', { analytics_storage: 'granted' });
      window['ga-disable-' + measurementId] = false;
      start();
    } else {
      if (started && window.gtag) window.gtag('consent', 'update', { analytics_storage: 'denied' });
      window['ga-disable-' + measurementId] = true;
      document.cookie.split(';').forEach(function (cookie) {
        const name = cookie.split('=')[0].trim();
        if (!/^_ga(?:_|$)/.test(name)) return;
        ['', '; domain=' + hostname, '; domain=.448plumbing.com'].forEach(function (domain) {
          document.cookie = name + '=; Max-Age=0; path=/' + domain + '; SameSite=Lax';
        });
      });
    }
    banner.hidden = true;
  }

  function init() {
    banner = document.createElement('aside');
    banner.className = 'analytics-choice';
    banner.setAttribute('aria-label', 'Optional analytics');
    banner.hidden = !!preference;
    banner.innerHTML = '<p>May we use optional analytics cookies to understand visits and improve this website? Your choice won’t affect calling, texting, or requesting service. <a href="/privacy.html">Privacy details</a></p><div class="analytics-actions"><button type="button" data-choice="yes">Allow analytics</button><button type="button" data-choice="no">No thanks</button></div>';
    document.body.appendChild(banner);
    banner.addEventListener('click', function (event) {
      const button = event.target.closest('button[data-choice]');
      if (button) choose(button.dataset.choice);
    });
    document.addEventListener('click', function (event) {
      const settings = event.target.closest('[data-analytics-settings]');
      if (settings) { banner.hidden = false; banner.querySelector('button').focus(); return; }
      const link = event.target.closest('a[href]');
      if (!link) return;
      const href = link.getAttribute('href');
      const eventName = href.startsWith('sms:') ? 'click_text' : href.startsWith('tel:') ? 'click_call' : href.startsWith('mailto:') ? 'click_email' : '';
      if (eventName) track(eventName, { contact_location: link.dataset.contactLocation || 'page', page_path: window.location.pathname });
    });
    // Fires only after a successful response from the existing form provider.
    const form = document.getElementById('contactForm');
    if (form) {
      const status = document.createElement('p');
      status.className = 'md:col-span-2 text-sm';
      status.setAttribute('role', 'status');
      form.appendChild(status);
      form.addEventListener('submit', async function (event) {
        if (!window.fetch || !window.FormData) return;
        event.preventDefault();
        if (!form.reportValidity()) return;
        const button = form.querySelector('button[type="submit"]');
        if (button.disabled) return;
        button.disabled = true;
        button.textContent = 'Sending…';
        status.textContent = '';
        try {
          const response = await fetch(form.action, { method: 'POST', body: new FormData(form), headers: { Accept: 'application/json' } });
          if (!response.ok) throw new Error('Submission not accepted');
          track('generate_lead', { method: 'contact_form' });
          form.reset();
          button.textContent = 'Message sent';
          status.textContent = 'Thank you. Your message was submitted. We’ll follow up about your project. For urgent help, call 214-718-6990 between 7 a.m. and 10 p.m.';
        } catch (_) {
          status.textContent = 'We could not confirm your message was sent. Please try again, or call/text 214-718-6990.';
          button.disabled = false;
          button.textContent = 'Send message';
        }
      });
    }
    start();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
