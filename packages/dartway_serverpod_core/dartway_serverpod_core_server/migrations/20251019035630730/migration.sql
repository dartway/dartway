BEGIN;

--
-- ACTION ALTER TABLE
--
ALTER TABLE "dw_auth_key" DROP COLUMN "scopeNames";
ALTER TABLE "dw_auth_key" DROP COLUMN "method";
--
-- ACTION ALTER TABLE
--
ALTER TABLE "dw_auth_request" DROP COLUMN "errorMessage";
ALTER TABLE "dw_auth_request" DROP COLUMN "errorData";
ALTER TABLE "dw_auth_request" DROP COLUMN "verifiedAt";
ALTER TABLE "dw_auth_request" ADD COLUMN "userId" bigint;
ALTER TABLE "dw_auth_request" ADD COLUMN "failReason" text;
ALTER TABLE "dw_auth_request" ALTER COLUMN "status" SET DEFAULT 'created'::text;
--
-- ACTION ALTER TABLE
--
CREATE UNIQUE INDEX "dw_user_password_user_id_idx" ON "dw_user_password" USING btree ("userId");

--
-- MIGRATION VERSION FOR dartway_serverpod_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('dartway_serverpod_core', '20251019035630730', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20251019035630730', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20240516151843329', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20240516151843329', "timestamp" = now();


COMMIT;
