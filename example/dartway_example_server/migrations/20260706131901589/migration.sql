BEGIN;

--
-- ACTION DROP TABLE
--
DROP TABLE "water_intake" CASCADE;

--
-- ACTION DROP TABLE
--
DROP TABLE "feed_post" CASCADE;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "app_setting" (
    "id" bigserial PRIMARY KEY,
    "settingKey" text NOT NULL,
    "settingValue" text NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "app_setting_key_unique_idx" ON "app_setting" USING btree ("settingKey");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "chat_channel" (
    "id" bigserial PRIMARY KEY,
    "title" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

--
-- ACTION CREATE TABLE
--
CREATE TABLE "chat_message" (
    "id" bigserial PRIMARY KEY,
    "channelId" bigint NOT NULL,
    "authorProfileId" bigint NOT NULL,
    "messageText" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

--
-- ACTION CREATE TABLE
--
CREATE TABLE "club_service" (
    "id" bigserial PRIMARY KEY,
    "title" text NOT NULL,
    "description" text NOT NULL,
    "durationMinutes" bigint NOT NULL,
    "price" bigint NOT NULL,
    "imageUrl" text
);

--
-- ACTION CREATE TABLE
--
CREATE TABLE "club_session" (
    "id" bigserial PRIMARY KEY,
    "serviceId" bigint NOT NULL,
    "coachProfileId" bigint NOT NULL,
    "startsAt" timestamp without time zone NOT NULL,
    "capacity" bigint NOT NULL
);

--
-- ACTION CREATE TABLE
--
CREATE TABLE "news_post" (
    "id" bigserial PRIMARY KEY,
    "authorProfileId" bigint NOT NULL,
    "title" text NOT NULL,
    "text" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

--
-- ACTION CREATE TABLE
--
CREATE TABLE "session_booking" (
    "id" bigserial PRIMARY KEY,
    "sessionId" bigint NOT NULL,
    "clientProfileId" bigint NOT NULL,
    "status" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

--
-- ACTION CREATE TABLE
--
CREATE TABLE "session_review" (
    "id" bigserial PRIMARY KEY,
    "bookingId" bigint NOT NULL,
    "rating" bigint NOT NULL,
    "reviewText" text,
    "createdAt" timestamp without time zone NOT NULL
);

--
-- ACTION ALTER TABLE
--
ALTER TABLE "user_profile" ADD COLUMN "role" text NOT NULL DEFAULT 'client'::text;
--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "chat_message"
    ADD CONSTRAINT "chat_message_fk_0"
    FOREIGN KEY("channelId")
    REFERENCES "chat_channel"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "chat_message"
    ADD CONSTRAINT "chat_message_fk_1"
    FOREIGN KEY("authorProfileId")
    REFERENCES "user_profile"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "club_session"
    ADD CONSTRAINT "club_session_fk_0"
    FOREIGN KEY("serviceId")
    REFERENCES "club_service"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "club_session"
    ADD CONSTRAINT "club_session_fk_1"
    FOREIGN KEY("coachProfileId")
    REFERENCES "user_profile"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "news_post"
    ADD CONSTRAINT "news_post_fk_0"
    FOREIGN KEY("authorProfileId")
    REFERENCES "user_profile"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "session_booking"
    ADD CONSTRAINT "session_booking_fk_0"
    FOREIGN KEY("sessionId")
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
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "session_review"
    ADD CONSTRAINT "session_review_fk_0"
    FOREIGN KEY("bookingId")
    REFERENCES "session_booking"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR dartway_example
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('dartway_example', '20260706131901589', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260706131901589', "timestamp" = now();

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
