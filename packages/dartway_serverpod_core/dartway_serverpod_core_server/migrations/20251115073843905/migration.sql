BEGIN;

--
-- ACTION ALTER TABLE
--
ALTER TABLE "dw_auth_verification" ADD COLUMN "failReason" text;

--
-- MIGRATION VERSION FOR dartway_serverpod_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('dartway_serverpod_core', '20251115073843905', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20251115073843905', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20240516151843329', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20240516151843329', "timestamp" = now();


COMMIT;
