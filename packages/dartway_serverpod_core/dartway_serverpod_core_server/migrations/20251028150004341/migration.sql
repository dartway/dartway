BEGIN;

--
-- ACTION CREATE TABLE
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
-- MIGRATION VERSION FOR dartway_serverpod_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('dartway_serverpod_core', '20251028150004341', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20251028150004341', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20240516151843329', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20240516151843329', "timestamp" = now();


COMMIT;
