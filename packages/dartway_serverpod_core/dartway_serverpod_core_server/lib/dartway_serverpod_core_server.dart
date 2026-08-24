export 'package:dartway_serverpod_core_shared/dartway_serverpod_core_shared.dart';

export 'src/business/alerts/dw_proxy_http_client.dart';
export 'src/business/auth/dw_auth_config.dart';
export 'src/business/auth/dw_authentification_handler.dart';
export 'src/business/auth/dw_password_hashing.dart';
export 'src/business/dw_advisory_lock.dart';
export 'src/business/dw_db.dart';
export 'src/business/auth/dw_orphaned_auth_key_cleanup.dart';
export 'src/business/dw_recurring_future_call.dart';
export 'src/business/cloud_storage/dw_cloud_storage_config.dart';
export 'src/business/dw_session_extension.dart';
export 'src/core/dw_core.dart';
export 'src/domain/api/dw_api_response.dart';
export 'src/domain/api/dw_auth_data.dart';
export 'src/domain/api/dw_backend_filter.dart';
export 'src/domain/api/dw_model_wrapper.dart';
export 'src/domain/channels/dw_channel_config.dart';
export 'src/domain/crud/domain/dw_save_context.dart';
export 'src/domain/crud/dto_configs/dw_dto_action_config.dart';
export 'src/domain/crud/dto_configs/dw_dto_get_list_config.dart';
export 'src/domain/crud/dw_crud_config.dart';
export 'src/domain/crud/model_configs/dw_delete_config.dart';
export 'src/domain/crud/model_configs/dw_get_model_config.dart';
export 'src/domain/crud/model_configs/dw_get_model_list_config.dart';
export 'src/domain/crud/model_configs/dw_save_config.dart';
// `ServerpodFutureCallsGetter` is hidden, and it has to be. Serverpod's
// generator writes that exact extension — same name, same `on Serverpod`, same
// `futureCalls` member — into *every* project that has a future call of its own,
// and the core has had one since it started sweeping orphaned auth keys.
// Exported, the two collide by construction: any file importing both this
// barrel and its own `generated/` stops compiling with
// `ambiguous_extension_member_access`, and the error lands on the app's line, in
// the app's file, the day the app writes its first future call — long after the
// upgrade that caused it. Renaming ours would not help: Dart resolves by member
// name and receiver type, not by the extension's name.
//
// The generated file itself carries DO NOT MODIFY, so the fix lives here, in the
// hand-written barrel the generator never touches. Nothing is lost: the core
// schedules its own jobs through `DwRecurringJobs.startAll`, which registers
// them on the `Serverpod` instance directly.
export 'src/generated/endpoints.dart' hide ServerpodFutureCallsGetter;
export 'src/generated/protocol.dart';
export 'src/static/dw_configuration_keys.dart';
export 'src/utils/web_logs/dw_web_server_logger.dart';
