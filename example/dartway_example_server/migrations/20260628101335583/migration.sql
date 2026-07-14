BEGIN;

--
-- ACTION DROP TABLE
--
DROP TABLE "user_profile" CASCADE;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "user_profile" (
    "id" bigserial PRIMARY KEY,
    "userIdentifier" text NOT NULL,
    "phone" text NOT NULL,
    "agreedForMarketingCommunications" boolean NOT NULL,
    "conditionsAcceptedAt" timestamp without time zone NOT NULL,
    "firstName" text NOT NULL,
    "lastName" text,
    "imageUrl" text,
    "gender" text
);


--
-- MIGRATION VERSION FOR dartway_example
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('dartway_example', '20260628101335583', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260628101335583', "timestamp" = now();

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
