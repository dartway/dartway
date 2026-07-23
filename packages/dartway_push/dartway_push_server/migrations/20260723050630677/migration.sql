BEGIN;

--
-- ACTION CREATE TABLE
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
-- MIGRATION VERSION FOR dartway_push
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('dartway_push', '20260723050630677', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260723050630677', "timestamp" = now();

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
