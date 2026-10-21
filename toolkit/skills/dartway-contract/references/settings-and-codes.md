## 5. A settings object

One data object with a default for every field and a fixed `id`; read with a `DwSingleRequest`,
changed by a command whose fields keep when absent — `null` for a non-nullable setting, a
`DwFieldPatch` for a nullable one. `null` means none, never `''`. The server side: `dartway-server`.
The skeleton's `__SHARED_PKG__/lib/src/settings.dart` is the sample.

## 6. Refusal codes, channel kinds, upload purposes

```dart
/// Why the server refuses. Each code needs a text in the app's refusal texts.
enum AcmeRefusal with DwRefusalCodes {
  /// An invoice that is paid cannot be edited or paid again.
  invoiceAlreadyPaid,

  /// An amount is a positive number of cents.
  amountNotPositive,
}

/// The app's live channels; the server declares who may subscribe to each.
enum AcmeChannel with DwChannelKind { invoices, billing }

/// What an uploaded file is for; the server declares one rule per purpose.
enum AcmeUpload with DwUploadPurpose {
  invoiceScan;

  static const int invoiceScanMaxBytes = 10 * 1024 * 1024;
}
```

- A refusal is a code with parameters (`field:`, `params:` as strings), never a sentence. Check first
  whether `DwCoreRefusal.notFound`, `forbidden`, `conflict` or `invalid` with a `field` already says it.
  Doc-comment every code: when it happens, what the user can do. Its text: `dartway-data-layer`.
- A channel kind's name has no `:`. Its rule: `dartway-realtime`.
- Limits both sides read sit on the purpose enum as constants. The rule: `dartway-uploads`.
