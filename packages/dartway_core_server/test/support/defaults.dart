// Hand-written input of `dartway generate`; its part is the generator's
// output, reproduced byte for byte by the generator's tests (D-041).
import 'package:dartway_core_server/dartway_core_server.dart';

part 'defaults.dw.dart';

enum Tone { plain, warm }

/// A command whose fields, except [text], have constructor defaults: a raw
/// call may send only `text`.
final class Compose extends DwActionCommand<String> with _$Compose {
  const Compose({
    required this.text,
    this.times = 2,
    this.separator = ' ',
    this.loud = false,
    this.tone = Tone.plain,
    this.tags = const ['draft'],
    this.limits = const {},
    this.signature = 'team',
  });

  final String text;
  final int times;
  final String separator;
  final bool loud;
  final Tone tone;
  final List<String> tags;
  final Map<String, int> limits;
  final String? signature;
}

/// A request with only defaulted fields: an empty body is a whole request.
final class Echoes extends DwListRequest<Echo> with _$Echoes {
  const Echoes({this.count = 3, this.prefix = 'echo'});

  final int count;
  final String prefix;
}

final class Echo extends DwDataObject with _$Echo {
  const Echo({required this.id, this.label = ''});

  @override
  final int id;
  final String label;
}
