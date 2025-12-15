BEGIN;

--
-- ACTION DROP TABLE
--
DROP TABLE "dw_media" CASCADE;

--
-- ACTION CREATE TABLE
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
-- MIGRATION VERSION FOR dartway_serverpod_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('dartway_serverpod_core', '20251028091633008', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20251028091633008', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20240516151843329', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20240516151843329', "timestamp" = now();


COMMIT;
