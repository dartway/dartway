import 'dart:convert';

/// Browser upload policy owned by the CLI satellite. Its contract test keeps
/// it equal to server provisioning without a runtime family dependency.
const dwStorageCorsPolicy = {
  'AllowedMethods': ['GET', 'PUT'],
  'AllowedHeaders': ['*'],
  'MaxAgeSeconds': 3000,
};

String dwStorageCorsJson(Iterable<String> origins) => jsonEncode({
  'CORSRules': [
    {'AllowedOrigins': origins.toList(), ...dwStorageCorsPolicy},
  ],
});
