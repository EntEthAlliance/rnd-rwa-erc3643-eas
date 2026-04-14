/* Shibui — Minimal JS
   - Scroll-spy for nav highlighting
   - Smooth scroll for anchor links
   No external dependencies.
*/

(function () {
  'use strict';

  const nav = document.querySelector('.nav');
  if (!nav) return;

  const links = Array.from(nav.querySelectorAll('a[href^="#"]'));
  const sections = links
    .map(a => document.querySelector(a.getAttribute('href')))
    .filter(Boolean);

  // Set active nav link
  function setActive(id) {
    links.forEach(a => {
      const isActive = a.getAttribute('href') === '#' + id;
      a.setAttribute('aria-current', isActive ? 'true' : 'false');
    });
  }

  // Scroll spy with IntersectionObserver
  if ('IntersectionObserver' in window && sections.length) {
    const observer = new IntersectionObserver(
      (entries) => {
        const visible = entries
          .filter(e => e.isIntersecting)
          .sort((a, b) => b.intersectionRatio - a.intersectionRatio);

        if (visible.length && visible[0].target.id) {
          setActive(visible[0].target.id);
        }
      },
      {
        threshold: [0.2, 0.4, 0.6],
        rootMargin: '-10% 0px -60% 0px'
      }
    );

    sections.forEach(s => observer.observe(s));
  }

  // Smooth scroll on click (for browsers without native support)
  links.forEach(a => {
    a.addEventListener('click', (e) => {
      const href = a.getAttribute('href');
      const target = document.querySelector(href);
      if (!target) return;

      e.preventDefault();
      target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      history.pushState(null, '', href);
    });
  });
})();
