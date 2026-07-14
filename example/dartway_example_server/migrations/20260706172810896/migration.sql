BEGIN;

--
-- ACTION DROP TABLE
--
DROP TABLE "session_booking" CASCADE;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "session_booking" (
    "id" bigserial PRIMARY KEY,
    "clubSessionId" bigint NOT NULL,
    "clientProfileId" bigint NOT NULL,
    "status" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "session_booking"
    ADD CONSTRAINT "session_booking_fk_0"
    FOREIGN KEY("clubSessionId")
    REFERENCES "club_session"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "session_booking"
    ADD CONSTRAINT "session_booking_fk_1"
    FOREIGN KEY("clientProfileId")
    REFERENCES "user_profile"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR dartway_example
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('dartway_example', '20260706172810896', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260706172810896', "timestamp" = now();

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
