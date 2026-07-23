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
-- ACTION CREATE TABLE
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
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "dw_push_source_link"
    ADD CONSTRAINT "dw_push_source_link_fk_0"
    FOREIGN KEY("messageId")
    REFERENCES "dw_push_message"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR dartway_example
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('dartway_example', '20260723102537568', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260723102537568', "timestamp" = now();

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

--
-- MIGRATION VERSION FOR dartway_push
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('dartway_push', '20260723051437434', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260723051437434', "timestamp" = now();


COMMIT;
