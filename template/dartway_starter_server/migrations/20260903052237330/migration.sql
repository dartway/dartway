BEGIN;

--
-- ACTION ALTER TABLE
--
CREATE INDEX "dw_auth_request_identifier_created_idx" ON "dw_auth_request" USING btree ("userIdentifier", "createdAt");
--
-- ACTION ALTER TABLE
--
ALTER TABLE "dw_cloud_file" ADD COLUMN "fileName" text;
CREATE UNIQUE INDEX "dw_cloud_file_bucket_path_idx" ON "dw_cloud_file" USING btree ("bucket", "path");

--
-- MIGRATION VERSION FOR dartway_starter
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('dartway_starter', '20260903052237330', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260903052237330', "timestamp" = now();

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
    VALUES ('dartway_serverpod_core', '20260903052214334', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260903052214334', "timestamp" = now();


COMMIT;
