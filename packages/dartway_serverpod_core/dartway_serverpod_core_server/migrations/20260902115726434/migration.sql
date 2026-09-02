BEGIN;

--
-- ACTION ALTER TABLE
--
CREATE INDEX "dw_auth_request_identifier_created_idx" ON "dw_auth_request" USING btree ("userIdentifier", "createdAt");
--
-- ACTION ALTER TABLE
--
ALTER TABLE "serverpod_session_log" ADD COLUMN "userId" text;
CREATE INDEX "serverpod_session_log_time_idx" ON "serverpod_session_log" USING btree ("time");

--
-- MIGRATION VERSION FOR dartway_serverpod_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('dartway_serverpod_core', '20260902115726434', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260902115726434', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


COMMIT;
