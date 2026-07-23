BEGIN;

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
