/* Aura — the time-decay rule, driven rather than photographed.
   Serves /demo. Not part of the Flutter bundle.

   THE RULE, TRANSCRIBED FROM THE CLIENT.
   `lib/features/feed/presentation/unified_feed_card.dart` computes an age
   bucket for an institution's announcement and applies two numbers, so that
   "an old statement no longer competes with fresh institutional speech":

     bucket   age        border alpha              eyebrow opacity
     fresh    <= 24h     0.45                      1.00
     recent   24 - 72h   0.28                      0.85
     stale    >  72h     none (plain divider)      0.65

   The NEW chip is separate and simpler: shown inside 24 hours, gone after.

   Nothing here interpolates between the buckets. The product does not, and a
   smooth fade would be a nicer-looking lie about a rule that steps. */

(function () {
  'use strict';

  var range = document.getElementById('decayRange');
  var card = document.getElementById('decayCard');
  if (!range || !card) return;

  var out = {
    age: document.getElementById('decayAge'),
    bucket: document.getElementById('decayBucket'),
    alpha: document.getElementById('decayAlpha'),
    eyebrow: document.getElementById('decayEyebrow'),
    chip: document.getElementById('decayChip'),
    time: document.getElementById('decayTime'),
    newChip: document.getElementById('decayNew')
  };

  var thresholds = document.querySelectorAll('#decayThresholds .chip');

  var BUCKETS = {
    fresh:  { alpha: 0.45, eyebrow: 1.00, tone: 'accent' },
    recent: { alpha: 0.28, eyebrow: 0.85, tone: 'quiet' },
    stale:  { alpha: null, eyebrow: 0.65, tone: 'quiet' }
  };

  function bucketFor(hours) {
    if (hours <= 24) return 'fresh';
    if (hours <= 72) return 'recent';
    return 'stale';
  }

  /// The same shorthand the feed uses on a publication's meta line.
  function relative(hours) {
    if (hours < 1) return 'now';
    if (hours < 24) return Math.round(hours) + 'h';
    return Math.round(hours / 24) + 'd';
  }

  function spelled(hours) {
    if (hours < 1) return 'Published just now';
    if (hours === 1) return '1 hour old';
    if (hours < 48) return hours + ' hours old';
    var days = Math.round(hours / 24);
    return days + ' days old';
  }

  function apply() {
    var hours = parseInt(range.value, 10) || 0;
    var name = bucketFor(hours);
    var b = BUCKETS[name];

    // `null` alpha means the accent is withdrawn entirely and the edge
    // returns to the plain divider — the client's own wording.
    if (b.alpha === null) {
      card.style.setProperty('--age-alpha', '0');
      card.style.borderColor = 'rgba(255,255,255,0.08)';
    } else {
      card.style.removeProperty('border-color');
      card.style.setProperty('--age-alpha', String(b.alpha));
    }
    card.style.setProperty('--eyebrow-op', String(b.eyebrow));

    var isNew = hours < 24;
    if (out.newChip) out.newChip.hidden = !isNew;

    if (out.age) out.age.textContent = spelled(hours);
    if (out.time) out.time.textContent = relative(hours);
    if (out.alpha) out.alpha.textContent = b.alpha === null ? 'divider' : b.alpha.toFixed(2);
    if (out.eyebrow) out.eyebrow.textContent = b.eyebrow.toFixed(2);
    if (out.chip) out.chip.textContent = isNew ? 'shown' : 'gone';
    if (out.bucket) {
      out.bucket.textContent = name.toUpperCase();
      out.bucket.setAttribute('data-t', b.tone);
    }

    // The threshold table marks which row is actually in force. A static
    // highlight on the first row would be a small lie for two thirds of the
    // range this control covers.
    if (thresholds) {
      Array.prototype.forEach.call(thresholds, function (chip) {
        var active = chip.getAttribute('data-bucket') === name;
        chip.setAttribute('data-t', active ? 'accent' : 'quiet');
        chip.setAttribute('aria-current', active ? 'true' : 'false');
      });
    }
  }

  range.addEventListener('input', apply);
  apply();
})();
