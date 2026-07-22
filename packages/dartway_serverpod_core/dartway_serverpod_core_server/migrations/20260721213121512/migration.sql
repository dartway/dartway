BEGIN;

--
-- ACTION CREATE TABLE
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

-- Keep vacuum/analyze responsive on this intentionally high-churn queue.
ALTER TABLE "dw_push_delivery" SET (
    autovacuum_vacuum_scale_factor = 0.01,
    autovacuum_vacuum_threshold = 100,
    autovacuum_analyze_scale_factor = 0.02,
    autovacuum_analyze_threshold = 100
);

--
-- ACTION CREATE TABLE
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
-- ACTION CREATE TABLE
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

-- Compact recipient tombstones are inserted and removed in large batches.
ALTER TABLE "dw_push_message_recipient" SET (
    autovacuum_vacuum_scale_factor = 0.01,
    autovacuum_vacuum_threshold = 100,
    autovacuum_analyze_scale_factor = 0.02,
    autovacuum_analyze_threshold = 100
);

--
-- ACTION CREATE TABLE
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
-- ACTION CREATE TABLE
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
-- ACTION CREATE TABLE
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
-- ACTION ALTER TABLE
--
-- The module's previous migration predates this Serverpod schema revision.
-- Make the generated upgrade safe when a host already applied the same change.
ALTER TABLE "serverpod_session_log" ADD COLUMN IF NOT EXISTS "userId" text;
CREATE INDEX IF NOT EXISTS "serverpod_session_log_time_idx" ON "serverpod_session_log" USING btree ("time");
--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "dw_push_delivery"
    ADD CONSTRAINT "dw_push_delivery_fk_0"
    FOREIGN KEY("messageId")
    REFERENCES "dw_push_message"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "dw_push_message_recipient"
    ADD CONSTRAINT "dw_push_message_recipient_fk_0"
    FOREIGN KEY("messageId")
    REFERENCES "dw_push_message"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR dartway_serverpod_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('dartway_serverpod_core', '20260721213121512', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260721213121512', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


COMMIT;
