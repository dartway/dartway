BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "dw_chat_channel" (
    "id" bigserial PRIMARY KEY,
    "channel" text NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "channel_name_idx" ON "dw_chat_channel" USING btree ("channel");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "dw_chat_message" (
    "id" bigserial PRIMARY KEY,
    "userId" bigint NOT NULL,
    "chatChannelId" bigint NOT NULL,
    "sentAt" timestamp without time zone NOT NULL,
    "text" text,
    "attachmentIds" json,
    "customMessageType" json,
    "replyMessageId" bigint,
    "isDeleted" boolean NOT NULL DEFAULT false
);

--
-- ACTION CREATE TABLE
--
CREATE TABLE "dw_chat_participant" (
    "id" bigserial PRIMARY KEY,
    "userId" bigint NOT NULL,
    "chatChannelId" bigint NOT NULL,
    "lastMessageId" bigint,
    "lastMessageSentAt" timestamp without time zone,
    "unreadCount" bigint NOT NULL DEFAULT 0,
    "lastReadMessageId" bigint,
    "isDeleted" boolean NOT NULL DEFAULT false
);

-- Indexes
CREATE UNIQUE INDEX "dw_chat_participants_idx" ON "dw_chat_participant" USING btree ("userId", "chatChannelId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "dw_app_notification" (
    "id" bigserial PRIMARY KEY,
    "toUserId" bigint NOT NULL,
    "identifier" text,
    "timestamp" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "title" text NOT NULL,
    "body" text,
    "goToPath" text,
    "isRead" boolean NOT NULL DEFAULT false
);

--
-- ACTION CREATE TABLE
--
CREATE TABLE "dw_auth_key" (
    "id" bigserial PRIMARY KEY,
    "userId" bigint NOT NULL,
    "hash" text NOT NULL
);

-- Indexes
CREATE INDEX "dw_auth_key_userId_idx" ON "dw_auth_key" USING btree ("userId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "dw_auth_request" (
    "id" bigserial PRIMARY KEY,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "requestType" text NOT NULL,
    "userIdentifier" text NOT NULL,
    "userId" bigint,
    "authProvider" text NOT NULL,
    "verificationType" bigint,
    "verificationHash" text,
    "status" text NOT NULL DEFAULT 'created'::text,
    "failReason" text,
    "extraData" json
);

--
-- ACTION CREATE TABLE
--
CREATE TABLE "dw_auth_verification" (
    "id" bigserial PRIMARY KEY,
    "dwAuthRequestId" bigint NOT NULL,
    "createdAt" timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "failReason" text,
    "accessToken" text
);

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
-- ACTION CREATE TABLE
--
CREATE TABLE "dw_user_password" (
    "id" bigserial PRIMARY KEY,
    "userId" bigint NOT NULL,
    "passwordHash" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "dw_user_password_user_id_idx" ON "dw_user_password" USING btree ("userId");

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
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "dw_chat_message"
    ADD CONSTRAINT "dw_chat_message_fk_0"
    FOREIGN KEY("chatChannelId")
    REFERENCES "dw_chat_channel"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "dw_chat_participant"
    ADD CONSTRAINT "dw_chat_participant_fk_0"
    FOREIGN KEY("chatChannelId")
    REFERENCES "dw_chat_channel"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "dw_chat_participant"
    ADD CONSTRAINT "dw_chat_participant_fk_1"
    FOREIGN KEY("lastMessageId")
    REFERENCES "dw_chat_message"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "dw_chat_participant"
    ADD CONSTRAINT "dw_chat_participant_fk_2"
    FOREIGN KEY("lastReadMessageId")
    REFERENCES "dw_chat_message"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "dw_auth_verification"
    ADD CONSTRAINT "dw_auth_verification_fk_0"
    FOREIGN KEY("dwAuthRequestId")
    REFERENCES "dw_auth_request"("id")
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR dartway_serverpod_chat
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('dartway_serverpod_chat', '20251204043649077', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20251204043649077', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20240516151843329', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20240516151843329', "timestamp" = now();

--
-- MIGRATION VERSION FOR dartway_serverpod_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('dartway_serverpod_core', '20251115073843905', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20251115073843905', "timestamp" = now();


COMMIT;
