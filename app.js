/* Shibui — static story page
   Purpose: light progressive enhancement (no framework).

   Features:
   - Scroll-spy highlights the active nav item
   - Optional reveal-on-scroll animation (respects reduced motion)
*/

(function () {
  'use strict';

  const nav = document.querySelector('.nav');
  const links = nav ? Array.from(nav.querySelectorAll('a[href^="#"]')) : [];
  const sections = links
    .map(a => document.querySelector(a.getAttribute('href')))
    .filter(Boolean);

  // Mark elements for reveal animation
  const revealables = Array.from(document.querySelectorAll('.card, .beat, .quote-block, .callout, .endcap-inner'));
  revealables.forEach(el => el.setAttribute('data-reveal', ''));

  function setActive(id) {
    links.forEach(a => {
      const href = a.getAttribute('href');
      const on = href === `#${id}`;
      a.setAttribute('aria-current', on ? 'true' : 'false');
    });
  }

  // Scroll spy
  if ('IntersectionObserver' in window && sections.length) {
    const spy = new IntersectionObserver(
      (entries) => {
        // Choose the most visible intersecting section.
        const visible = entries
          .filter(e => e.isIntersecting)
          .sort((a, b) => (b.intersectionRatio || 0) - (a.intersectionRatio || 0));
        if (visible[0] && visible[0].target && visible[0].target.id) {
          setActive(visible[0].target.id);
        }
      },
      {
        root: null,
        threshold: [0.15, 0.25, 0.4, 0.6],
        rootMargin: '-20% 0px -70% 0px'
      }
    );

    sections.forEach(s => spy.observe(s));
  }

  // Reveal on scroll
  if ('IntersectionObserver' in window) {
    const reveal = new IntersectionObserver(
      (entries) => {
        entries.forEach(e => {
          if (e.isIntersecting) {
            e.target.classList.add('is-visible');
            reveal.unobserve(e.target);
          }
        });
      },
      { threshold: 0.12 }
    );

    revealables.forEach(el => reveal.observe(el));
  } else {
    // No IO support: just show everything.
    revealables.forEach(el => el.classList.add('is-visible'));
  }

  // Smooth scroll (native where supported)
  links.forEach(a => {
    a.addEventListener('click', (ev) => {
      const href = a.getAttribute('href');
      const target = href ? document.querySelector(href) : null;
      if (!target) return;
      ev.preventDefault();
      target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      history.pushState(null, '', href);
    });
  });
})();
