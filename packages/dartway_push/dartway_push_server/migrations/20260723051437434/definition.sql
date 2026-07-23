BEGIN;

--
-- Class DwDevicePushToken as table dw_device_push_token
--
CREATE TABLE "dw_device_push_token" (
    "id" bigserial PRIMARY KEY,
    "recipientId" bigint NOT NULL,
    "token" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "dw_device_push_token_token_unique_idx" ON "dw_device_push_token" USING btree ("token");
CREATE INDEX "dw_device_push_token_recipient_id_idx" ON "dw_device_push_token" USING btree ("recipientId");
CREATE INDEX "dw_device_push_token_recipient_updated_id_idx" ON "dw_device_push_token" USING btree ("recipientId", "updatedAt", "id");

--
-- Class DwPushDelivery as table dw_push_delivery
--
CREATE TABLE "dw_push_delivery" (
    "id" bigserial PRIMARY KEY,
    "messageId" bigint NOT NULL,
    "recipientId" bigint NOT NULL,
    "availableAt" timestamp without time zone NOT NULL,
    "attemptCount" bigint NOT NULL DEFAULT 0,
    "leaseId" text,
    "leaseExpiresAt" timestamp without time zone,
    "lastError" text,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE UNIQUE INDEX "dw_push_delivery_message_recipient_idx" ON "dw_push_delivery" USING btree ("messageId", "recipientId");
CREATE INDEX "dw_push_delivery_claim_idx" ON "dw_push_delivery" USING btree ("availableAt", "leaseExpiresAt");
CREATE INDEX "dw_push_delivery_recipient_idx" ON "dw_push_delivery" USING btree ("recipientId");

--
-- Class DwPushMessage as table dw_push_message
--
CREATE TABLE "dw_push_message" (
    "id" bigserial PRIMARY KEY,
    "deduplicationKey" text NOT NULL,
    "category" text NOT NULL,
    "title" text NOT NULL,
    "body" text,
    "imageUrl" text,
    "data" json,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "audienceClosedAt" timestamp without time zone,
    "scheduledAt" timestamp without time zone NOT NULL,
    "expiresAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "dw_push_message_deduplication_key_idx" ON "dw_push_message" USING btree ("deduplicationKey");
CREATE INDEX "dw_push_message_expires_at_idx" ON "dw_push_message" USING btree ("expiresAt");

--
-- Class DwPushMessageRecipient as table dw_push_message_recipient
--
CREATE TABLE "dw_push_message_recipient" (
    "id" bigserial PRIMARY KEY,
    "messageId" bigint NOT NULL,
    "recipientId" bigint NOT NULL,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE UNIQUE INDEX "dw_push_message_recipient_unique_idx" ON "dw_push_message_recipient" USING btree ("messageId", "recipientId");
CREATE INDEX "dw_push_message_recipient_recipient_idx" ON "dw_push_message_recipient" USING btree ("recipientId");

--
-- Class DwPushMetricBucket as table dw_push_metric_bucket
--
CREATE TABLE "dw_push_metric_bucket" (
    "id" bigserial PRIMARY KEY,
    "bucketStart" timestamp without time zone NOT NULL,
    "category" text NOT NULL,
    "outcome" text NOT NULL,
    "eventCount" bigint NOT NULL DEFAULT 0,
    "updatedAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE UNIQUE INDEX "dw_push_metric_bucket_identity_idx" ON "dw_push_metric_bucket" USING btree ("bucketStart", "category", "outcome");
CREATE INDEX "dw_push_metric_bucket_start_idx" ON "dw_push_metric_bucket" USING btree ("bucketStart");

--
-- Class DwPushRecipientState as table dw_push_recipient_state
--
CREATE TABLE "dw_push_recipient_state" (
    "id" bigserial PRIMARY KEY,
    "recipientId" bigint NOT NULL,
    "stateKey" text NOT NULL,
    "nextAllowedAt" timestamp without time zone NOT NULL,
    "metadata" json,
    "updatedAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE UNIQUE INDEX "dw_push_recipient_state_identity_idx" ON "dw_push_recipient_state" USING btree ("recipientId", "stateKey");
CREATE INDEX "dw_push_recipient_state_next_allowed_idx" ON "dw_push_recipient_state" USING btree ("nextAllowedAt");

--
-- Class DwPushRuntimeState as table dw_push_runtime_state
--
CREATE TABLE "dw_push_runtime_state" (
    "id" bigserial PRIMARY KEY,
    "workerName" text NOT NULL,
    "isPaused" boolean NOT NULL DEFAULT false,
    "pausedUntil" timestamp without time zone,
    "lastClaimedAt" timestamp without time zone,
    "lastCompletedAt" timestamp without time zone,
    "lastErrorAt" timestamp without time zone,
    "lastError" text,
    "updatedAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE UNIQUE INDEX "dw_push_runtime_state_worker_name_idx" ON "dw_push_runtime_state" USING btree ("workerName");

--
-- Class DwPushSourceLink as table dw_push_source_link
--
CREATE TABLE "dw_push_source_link" (
    "id" bigserial PRIMARY KEY,
    "sourceType" text NOT NULL,
    "sourceId" text NOT NULL,
    "messageId" bigint NOT NULL,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE UNIQUE INDEX "dw_push_source_link_unique_idx" ON "dw_push_source_link" USING btree ("sourceType", "sourceId", "messageId");
CREATE INDEX "dw_push_source_link_message_id_idx" ON "dw_push_source_link" USING btree ("messageId");

--
-- Class CloudStorageEntry as table serverpod_cloud_storage
--
CREATE TABLE "serverpod_cloud_storage" (
    "id" bigserial PRIMARY KEY,
    "storageId" text NOT NULL,
    "path" text NOT NULL,
    "addedTime" timestamp without time zone NOT NULL,
    "expiration" timestamp without time zone,
    "byteData" bytea NOT NULL,
    "verified" boolean NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "serverpod_cloud_storage_path_idx" ON "serverpod_cloud_storage" USING btree ("storageId", "path");
CREATE INDEX "serverpod_cloud_storage_expiration" ON "serverpod_cloud_storage" USING btree ("expiration");

--
-- Class CloudStorageDirectUploadEntry as table serverpod_cloud_storage_direct_upload
--
CREATE TABLE "serverpod_cloud_storage_direct_upload" (
    "id" bigserial PRIMARY KEY,
    "storageId" text NOT NULL,
    "path" text NOT NULL,
    "expiration" timestamp without time zone NOT NULL,
    "authKey" text NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "serverpod_cloud_storage_direct_upload_storage_path" ON "serverpod_cloud_storage_direct_upload" USING btree ("storageId", "path");

--
-- Class FutureCallEntry as table serverpod_future_call
--
CREATE TABLE "serverpod_future_call" (
    "id" bigserial PRIMARY KEY,
    "name" text NOT NULL,
    "time" timestamp without time zone NOT NULL,
    "serializedObject" text,
    "serverId" text NOT NULL,
    "identifier" text
);

-- Indexes
CREATE INDEX "serverpod_future_call_time_idx" ON "serverpod_future_call" USING btree ("time");
CREATE INDEX "serverpod_future_call_serverId_idx" ON "serverpod_future_call" USING btree ("serverId");
CREATE INDEX "serverpod_future_call_identifier_idx" ON "serverpod_future_call" USING btree ("identifier");

--
-- Class ServerHealthConnectionInfo as table serverpod_health_connection_info
--
CREATE TABLE "serverpod_health_connection_info" (
    "id" bigserial PRIMARY KEY,
    "serverId" text NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    "active" bigint NOT NULL,
    "closing" bigint NOT NULL,
    "idle" bigint NOT NULL,
    "granularity" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "serverpod_health_connection_info_timestamp_idx" ON "serverpod_health_connection_info" USING btree ("timestamp", "serverId", "granularity");

--
-- Class ServerHealthMetric as table serverpod_health_metric
--
CREATE TABLE "serverpod_health_metric" (
    "id" bigserial PRIMARY KEY,
    "name" text NOT NULL,
    "serverId" text NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    "isHealthy" boolean NOT NULL,
    "value" double precision NOT NULL,
    "granularity" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "serverpod_health_metric_timestamp_idx" ON "serverpod_health_metric" USING btree ("timestamp", "serverId", "name", "granularity");

--
-- Class LogEntry as table serverpod_log
--
CREATE TABLE "serverpod_log" (
    "id" bigserial PRIMARY KEY,
    "sessionLogId" bigint NOT NULL,
    "messageId" bigint,
    "reference" text,
    "serverId" text NOT NULL,
    "time" timestamp without time zone NOT NULL,
    "logLevel" bigint NOT NULL,
    "message" text NOT NULL,
    "error" text,
    "stackTrace" text,
    "order" bigint NOT NULL
);

-- Indexes
CREATE INDEX "serverpod_log_sessionLogId_idx" ON "serverpod_log" USING btree ("sessionLogId");

--
-- Class MessageLogEntry as table serverpod_message_log
--
CREATE TABLE "serverpod_message_log" (
    "id" bigserial PRIMARY KEY,
    "sessionLogId" bigint NOT NULL,
    "serverId" text NOT NULL,
    "messageId" bigint NOT NULL,
    "endpoint" text NOT NULL,
    "messageName" text NOT NULL,
    "duration" double precision NOT NULL,
    "error" text,
    "stackTrace" text,
    "slow" boolean NOT NULL,
    "order" bigint NOT NULL
);

--
-- Class MethodInfo as table serverpod_method
--
CREATE TABLE "serverpod_method" (
    "id" bigserial PRIMARY KEY,
    "endpoint" text NOT NULL,
    "method" text NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "serverpod_method_endpoint_method_idx" ON "serverpod_method" USING btree ("endpoint", "method");

--
-- Class DatabaseMigrationVersion as table serverpod_migrations
--
CREATE TABLE "serverpod_migrations" (
    "id" bigserial PRIMARY KEY,
    "module" text NOT NULL,
    "version" text NOT NULL,
    "timestamp" timestamp without time zone
);

-- Indexes
CREATE UNIQUE INDEX "serverpod_migrations_ids" ON "serverpod_migrations" USING btree ("module");

--
-- Class QueryLogEntry as table serverpod_query_log
--
CREATE TABLE "serverpod_query_log" (
    "id" bigserial PRIMARY KEY,
    "serverId" text NOT NULL,
    "sessionLogId" bigint NOT NULL,
    "messageId" bigint,
    "query" text NOT NULL,
    "duration" double precision NOT NULL,
    "numRows" bigint,
    "error" text,
    "stackTrace" text,
    "slow" boolean NOT NULL,
    "order" bigint NOT NULL
);

-- Indexes
CREATE INDEX "serverpod_query_log_sessionLogId_idx" ON "serverpod_query_log" USING btree ("sessionLogId");

--
-- Class ReadWriteTestEntry as table serverpod_readwrite_test
--
CREATE TABLE "serverpod_readwrite_test" (
    "id" bigserial PRIMARY KEY,
    "number" bigint NOT NULL
);

--
-- Class RuntimeSettings as table serverpod_runtime_settings
--
CREATE TABLE "serverpod_runtime_settings" (
    "id" bigserial PRIMARY KEY,
    "logSettings" json NOT NULL,
    "logSettingsOverrides" json NOT NULL,
    "logServiceCalls" boolean NOT NULL,
    "logMalformedCalls" boolean NOT NULL
);

--
-- Class SessionLogEntry as table serverpod_session_log
--
CREATE TABLE "serverpod_session_log" (
    "id" bigserial PRIMARY KEY,
    "serverId" text NOT NULL,
    "time" timestamp without time zone NOT NULL,
    "module" text,
    "endpoint" text,
    "method" text,
    "duration" double precision,
    "numQueries" bigint,
    "slow" boolean,
    "error" text,
    "stackTrace" text,
    "authenticatedUserId" bigint,
    "userId" text,
    "isOpen" boolean,
    "touched" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "serverpod_session_log_serverid_idx" ON "serverpod_session_log" USING btree ("serverId");
CREATE INDEX "serverpod_session_log_time_idx" ON "serverpod_session_log" USING btree ("time");
CREATE INDEX "serverpod_session_log_touched_idx" ON "serverpod_session_log" USING btree ("touched");
CREATE INDEX "serverpod_session_log_isopen_idx" ON "serverpod_session_log" USING btree ("isOpen");

--
-- Class DwAppNotification as table dw_app_notification
--
CREATE TABLE "dw_app_notification" (
    "id" bigserial PRIMARY KEY,
    "toUserId" bigint NOT NULL,
    "identifier" text,
    "timestamp" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "title" text NOT NULL,
    "body" text,
    "goToPath" text,
    "isRead" boolean NOT NULL DEFAULT false
);

--
-- Class DwAuthKey as table dw_auth_key
--
CREATE TABLE "dw_auth_key" (
    "id" bigserial PRIMARY KEY,
    "userId" bigint NOT NULL,
    "hash" text NOT NULL
);

-- Indexes
CREATE INDEX "dw_auth_key_userId_idx" ON "dw_auth_key" USING btree ("userId");

--
-- Class DwAuthRequest as table dw_auth_request
--
CREATE TABLE "dw_auth_request" (
    "id" bigserial PRIMARY KEY,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "requestType" text NOT NULL,
    "userIdentifier" text NOT NULL,
    "userId" bigint,
    "authProvider" text NOT NULL,
    "verificationType" bigint,
    "verificationHash" text,
    "status" text NOT NULL DEFAULT 'created'::text,
    "failReason" text,
    "extraData" json
);

--
-- Class DwAuthVerification as table dw_auth_verification
--
CREATE TABLE "dw_auth_verification" (
    "id" bigserial PRIMARY KEY,
    "dwAuthRequestId" bigint NOT NULL,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "failReason" text,
    "accessToken" text
);

--
-- Class DwCloudFile as table dw_cloud_file
--
CREATE TABLE "dw_cloud_file" (
    "id" bigserial PRIMARY KEY,
    "createdBy" bigint,
    "bucket" text NOT NULL,
    "path" text NOT NULL,
    "publicUrl" text NOT NULL,
    "size" bigint,
    "mimeType" text,
    "createdAt" timestamp without time zone NOT NULL,
    "verifiedAt" timestamp without time zone
);

--
-- Class DwUserPassword as table dw_user_password
--
CREATE TABLE "dw_user_password" (
    "id" bigserial PRIMARY KEY,
    "userId" bigint NOT NULL,
    "passwordHash" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "dw_user_password_user_id_idx" ON "dw_user_password" USING btree ("userId");

--
-- Class DwWebServerLog as table dw_web_server_log
--
CREATE TABLE "dw_web_server_log" (
    "id" bigserial PRIMARY KEY,
    "createdAt" timestamp without time zone NOT NULL,
    "method" text NOT NULL,
    "url" text NOT NULL,
    "headers" text,
    "body" text,
    "statusCode" bigint,
    "status" text,
    "error" text,
    "durationMs" bigint,
    "handler" text,
    "ip" text
);

--
-- Foreign relations for "dw_push_delivery" table
--
ALTER TABLE ONLY "dw_push_delivery"
    ADD CONSTRAINT "dw_push_delivery_fk_0"
    FOREIGN KEY("messageId")
    REFERENCES "dw_push_message"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- Foreign relations for "dw_push_message_recipient" table
--
ALTER TABLE ONLY "dw_push_message_recipient"
    ADD CONSTRAINT "dw_push_message_recipient_fk_0"
    FOREIGN KEY("messageId")
    REFERENCES "dw_push_message"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- Foreign relations for "dw_push_source_link" table
--
ALTER TABLE ONLY "dw_push_source_link"
    ADD CONSTRAINT "dw_push_source_link_fk_0"
    FOREIGN KEY("messageId")
    REFERENCES "dw_push_message"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- Foreign relations for "serverpod_log" table
--
ALTER TABLE ONLY "serverpod_log"
    ADD CONSTRAINT "serverpod_log_fk_0"
    FOREIGN KEY("sessionLogId")
    REFERENCES "serverpod_session_log"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- Foreign relations for "serverpod_message_log" table
--
ALTER TABLE ONLY "serverpod_message_log"
    ADD CONSTRAINT "serverpod_message_log_fk_0"
    FOREIGN KEY("sessionLogId")
    REFERENCES "serverpod_session_log"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- Foreign relations for "serverpod_query_log" table
--
ALTER TABLE ONLY "serverpod_query_log"
    ADD CONSTRAINT "serverpod_query_log_fk_0"
    FOREIGN KEY("sessionLogId")
    REFERENCES "serverpod_session_log"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- Foreign relations for "dw_auth_verification" table
--
ALTER TABLE ONLY "dw_auth_verification"
    ADD CONSTRAINT "dw_auth_verification_fk_0"
    FOREIGN KEY("dwAuthRequestId")
    REFERENCES "dw_auth_request"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR dartway_push
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('dartway_push', '20260723051437434', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260723051437434', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();

--
-- MIGRATION VERSION FOR dartway_serverpod_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('dartway_serverpod_core', '20251115073843905', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20251115073843905', "timestamp" = now();


COMMIT;
