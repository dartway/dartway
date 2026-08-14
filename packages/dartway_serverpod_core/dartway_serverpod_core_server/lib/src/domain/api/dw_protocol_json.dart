import 'package:serverpod/serverpod.dart';

/// The JSON a model is allowed to put on the wire.
///
/// The generator writes **two** maps for every model: [SerializableModel.toJson]
/// is the whole row, and [ProtocolSerialization.toJsonForProtocol] is that row
/// minus its `scope=serverOnly` fields. Serverpod picks the second one for
/// everything it sends a client — but only for the objects it reaches itself,
/// walking the value it was handed. It never reaches inside an envelope this
/// package has already flattened into a map.
///
/// So each hand-written payload here — `DwApiResponse`, `DwModelWrapper`,
/// `DwAuthData` — has to make that choice for its own contents, and this is the
/// one place that makes it. Calling `toJson` on a nested model instead
/// publishes the columns the schema marked server-side.
///
/// **The failure is silent from the app, which is what makes it worth a named
/// function.** The generated client class has no field for a `serverOnly`
/// column, so its `fromJson` drops the key on arrival and every screen looks
/// correct — while the value itself has already crossed the network and sits in
/// the response body, readable by anyone holding the socket.
///
/// No fallback to `toJson` once [ProtocolSerialization] is on the model: a
/// fallback is how the leak comes back.
dynamic dwJsonForProtocol(SerializableModel model) => model
        is ProtocolSerialization
    ? (model as ProtocolSerialization).toJsonForProtocol()
    : model.toJson();
