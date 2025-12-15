BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "dw_user_password" (
    "id" bigserial PRIMARY KEY,
    "userId" bigint NOT NULL,
    "passwordHash" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL
);


--
-- MIGRATION VERSION FOR dartway_serverpod_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('dartway_serverpod_core', '20251018094133619', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20251018094133619', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20240516151843329', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20240516151843329', "timestamp" = now();


COMMIT;
