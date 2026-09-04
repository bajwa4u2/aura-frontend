/* Aura — presentation motion.
   Serves /deck and /demo. Not part of the Flutter bundle.

   THE ONE RULE THIS FILE FOLLOWS.
   `company/visuals/visual-language/visual-philosophy.md` §5: "No motion that
   competes with the substance." So nothing here animates for interest. Three
   things move, and each of them is reporting a fact the reader already cares
   about:

     * the progress bar   — how much of the publication is left
     * the causal spine   — how far into an ORDERED argument the reader is,
                            where the order is the argument
     * a step's node      — which step of that order they have reached

   Everything degrades to a fully readable page. `.rv` is hidden only under a
   `js-reveal` class this script's inline counterpart adds, and the spine
   defaults to fully drawn via `var(--spine-drawn, 100%)`, so a blocked or
   failed script leaves the page complete rather than blank. */

(function () {
  'use strict';

  var reduced = window.matchMedia &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // ── reveal ────────────────────────────────────────────────────────────
  var revealables = document.querySelectorAll('.rv');

  if (!('IntersectionObserver' in window) || reduced) {
    for (var i = 0; i < revealables.length; i++) {
      revealables[i].classList.add('in');
    }
  } else {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) {
          e.target.classList.add('in');
          io.unobserve(e.target);
        }
      });
    }, { rootMargin: '0px 0px -8% 0px' });
    Array.prototype.forEach.call(revealables, function (el) { io.observe(el); });
  }

  // ── progress + spine ──────────────────────────────────────────────────
  var progress = document.getElementById('progress');
  var spine = document.querySelector('.spine');
  var steps = spine ? spine.querySelectorAll('.step') : [];

  // Under reduced motion the spine stays fully drawn and every node lit: the
  // end state, declared rather than approached. Same discipline as the CSS.
  if (reduced) {
    if (spine) spine.style.setProperty('--spine-drawn', '100%');
    Array.prototype.forEach.call(steps, function (s) { s.classList.add('lit'); });
    return;
  }

  var ticking = false;

  function frame() {
    ticking = false;

    if (progress) {
      var doc = document.documentElement;
      var scrollable = doc.scrollHeight - doc.clientHeight;
      var pct = scrollable > 0 ? (doc.scrollTop || window.pageYOffset) / scrollable : 0;
      progress.style.width = Math.max(0, Math.min(1, pct)) * 100 + '%';
    }

    if (spine) {
      var box = spine.getBoundingClientRect();
      // The line is drawn to wherever the reader's eye is — two thirds down
      // the viewport, which is where a person reads rather than the very top.
      var eye = window.innerHeight * 0.66;
      var drawn = (eye - box.top) / (box.height || 1);
      spine.style.setProperty(
        '--spine-drawn',
        Math.max(0, Math.min(1, drawn)) * 100 + '%'
      );

      Array.prototype.forEach.call(steps, function (step) {
        var top = step.getBoundingClientRect().top;
        if (top < eye) step.classList.add('lit');
        else step.classList.remove('lit');
      });
    }
  }

  function onScroll() {
    if (ticking) return;
    ticking = true;
    window.requestAnimationFrame(frame);
  }

  window.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('resize', onScroll, { passive: true });
  frame();
})();
