import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import 'institution_domains_repository.dart';

final institutionDomainsRepositoryProvider =
    Provider<InstitutionDomainsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return InstitutionDomainsRepository(dio);
});