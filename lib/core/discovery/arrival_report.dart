/// REPORTING AN ARRIVAL — the browser's half of AURA_REFERRAL.
///
/// Discovery declared six sources and shipped two. Google and Bing need a
/// credential from a search provider; IndexNow has no read side at all. This
/// is the fourth — Aura observing its own published pages being reached — and
/// it needed nothing from anybody, which is why leaving it unbuilt was the one
/// absence with no excuse.
///
/// THE FULL REFERRER NEVER LEAVES THE BROWSER.
///
/// `document.referrer` is a complete URL and a URL carries a query string and
/// a query string carries people. The origin is extracted HERE, before the
/// request is made, so the sensitive part is discarded on the device rather
/// than trusted to be discarded on the server. The server reduces it again
/// anyway — a client is not a place to enforce a privacy rule — but the
/// network never sees more than a scheme and a host.
///
/// WHAT IS NOT SENT: no user id (this fires for signed-out visitors and is
/// identical when signed in), no session, no timestamp finer than the day the
/// server stamps, no path beyond the canonical URL that was already public.
///
/// WEB ONLY, DELIBERATELY. This observes arrivals from the outside world at
/// Aura's public web pages. A native client did not arrive from a search
/// engine, and reporting from one would be inventing evidence.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../continuation/native_continuation.dart';
import '../net/dio_provider.dart';

/// Reduces a referrer to scheme+host, or null when there is nothing to say.
///
/// Pure and exported so the rule is testable without a browser: this is the
/// disclosure boundary, and a boundary that can only be checked by running a
/// browser is a boundary nobody checks.
String? referrerOriginOf(String? rawReferrer) {
  final raw = (rawReferrer ?? '').trim();
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasAuthority) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  // `origin` is scheme + host + port and NOTHING else. No path, no query, no
  // fragment, no credentials.
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port';
}

/// Whether an arrival at this path is worth observing at all.
///
/// Canonical `/p/` share URLs only — the addresses Aura actually publishes and
/// the ones the published inventory knows about. An arrival at an internal
/// route is a person already inside Aura, which is not discovery evidence.
bool isObservableArrival(String path) => isCanonicalSharePath(path);

/// Reports one arrival. Fire-and-forget, and silent on every failure.
///
/// A page view must never fail, slow down or surface an error because
/// Discovery could not count it. Nothing here awaits, retries or reports.
class ArrivalReporter {
  ArrivalReporter(this._dio, {required this.publicOrigin});

  final Dio _dio;

  /// The public origin the canonical URL is built from.
  final String publicOrigin;

  /// Reported paths, so a rebuild or a redirect does not double-count.
  final Set<String> _seen = <String>{};

  void report({required String path, String? referrer}) {
    // NATIVE CLIENTS DO NOT ARRIVE FROM SEARCH. Reporting from one would
    // manufacture evidence about a channel that was not used.
    if (!kIsWeb) return;
    if (!isObservableArrival(path)) return;
    if (!_seen.add(path)) return;

    final origin = referrerOriginOf(referrer);

    // AN ARRIVAL FROM AURA IS NOT AN ARRIVAL. Somebody following a link
    // inside the product is not the outside world finding a page, and
    // counting it would make Discovery's most flattering number its least
    // truthful one.
    if (origin != null && origin == publicOrigin) return;

    // Fire and forget. Nothing awaits this, nothing retries it, and every
    // failure is silent — a page view must never fail because Discovery could
    // not count it.
    unawaited(
      _dio.post<void>(
        '/v1/discovery/arrival',
        data: {
          'canonicalUrl': '$publicOrigin$path',
          if (origin != null) 'referrer': origin,
        },
      ).catchError((Object _) => Response<void>(
            requestOptions: RequestOptions(path: '/v1/discovery/arrival'),
          )),
    );
  }
}

/// The reporter, wired to the app's transport and public origin.
final arrivalReporterProvider = Provider<ArrivalReporter>((ref) {
  return ArrivalReporter(
    ref.watch(dioProvider),
    publicOrigin: AppConfig.publicWebUrl,
  );
});
