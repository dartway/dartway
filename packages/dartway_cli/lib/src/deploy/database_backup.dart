import 'deploy_target.dart';
import 'stack.dart';

/// Host script installed by `deploy setup` for daily, pre-deploy and restore
/// verification work. Credentials are read at execution time from the
/// deployment's root-only secret store; the age identity is needed only on a
/// verification stand, never on the production host.
String dwDatabaseBackupScript(DwStack stack) {
  final target = stack.target;
  final backup = target.backup!;
  final compose =
      "cd '${target.appDir}' && docker compose -f docker-compose.yml";
  final dump = target.database == DwDatabaseMode.bundled
      ? "$compose exec -T postgres pg_dump -U '${stack.databaseName}' -d '${stack.databaseName}' -Fc"
      : "docker run --rm --network host --env-file \"\$pg_env\" '${stack.resolvedImage(DwStack.postgresImage)}' pg_dump -h \"\$DW_DATABASE_HOST\" -p \"\$DW_DATABASE_PORT\" -U \"\$DW_DATABASE_USER\" -d \"\$DW_DATABASE_NAME\" -Fc";
  return '''#!/bin/bash
set -euo pipefail
mode=\${1:-daily}
version=\${2:-unknown}
set -a
source '${target.runtimeConfigDir}/secrets.env'
source '${target.appDir}/.env'
set +a
sslmode=require
[ "\${DW_DATABASE_SSL:-true}" = false ] && sslmode=disable
root='${target.runtimeConfigDir}/backups'
mkdir -p "\$root/daily" "\$root/weekly" "\$root/pre-deploy"
aws_endpoint='${backup.endpoint}'
aws_region='${backup.region}'
timestamp=\$(date -u +%Y%m%dT%H%M%SZ)
case "\$mode" in
  daily) prefix=daily; name="\$timestamp" ;;
  pre-deploy) prefix=pre-deploy; name="\${version}-\${timestamp}" ;;
  verify)
    : "\${BACKUP_AGE_IDENTITY:?BACKUP_AGE_IDENTITY is required on the verification target}"
    key="\$(aws --endpoint-url "\$aws_endpoint" --region "\$aws_region" s3api list-objects-v2 --bucket '${backup.bucket}' --prefix backups/ --query 'sort_by(Contents,&LastModified)[-1].Key' --output text)"
    [ "\$key" != None ] || { echo 'No off-host backup exists' >&2; exit 1; }
    tmp="dw_backup_verify_\$\$"
    cleanup() { $compose exec -T postgres dropdb -U '${stack.databaseName}' --if-exists "\$tmp" >/dev/null 2>&1 || true; }
    trap cleanup EXIT
    $compose exec -T postgres createdb -U '${stack.databaseName}' "\$tmp"
    aws --endpoint-url "\$aws_endpoint" --region "\$aws_region" s3 cp "s3://${backup.bucket}/\$key" - | age -d -i "\$BACKUP_AGE_IDENTITY" | $compose exec -T postgres pg_restore -U '${stack.databaseName}' -d "\$tmp" --no-owner --no-privileges
    echo "Backup: \$key"
    aws --endpoint-url "\$aws_endpoint" --region "\$aws_region" s3api head-object --bucket '${backup.bucket}' --key "\$key" --query LastModified --output text | awk '{print "Created: " \$0}'
    while IFS= read -r table; do
      count=\$($compose exec -T postgres psql -U '${stack.databaseName}' -d "\$tmp" -Atc "select count(*) from \$table")
      printf '%s\\t%s\\n' "\$table" "\$count"
    done < <($compose exec -T postgres psql -U '${stack.databaseName}' -d "\$tmp" -Atc "select quote_ident(schemaname)||'.'||quote_ident(relname) from pg_stat_user_tables order by 1")
    exit 0 ;;
  *) echo "usage: \$0 daily|pre-deploy|verify [version]" >&2; exit 2 ;;
esac
plain="\$root/\$prefix/\$name.dump"
encrypted="\$plain.age"
pg_env="\$root/.pg-env.\$\$"
keep_encrypted=false
cleanup() {
  rm -f "\$plain" "\$pg_env"
  [ "\$keep_encrypted" = true ] || rm -f "\$encrypted"
}
trap cleanup EXIT
if [ '${target.database.name}' = external ]; then
  (umask 077; printf 'PGPASSWORD=%s\\nPGSSLMODE=%s\\n' "\$DW_DATABASE_PASSWORD" "\$sslmode" > "\$pg_env")
fi
$dump > "\$plain"
age -r '${backup.recipient}' -o "\$encrypted" "\$plain"
aws --endpoint-url "\$aws_endpoint" --region "\$aws_region" s3 cp "\$encrypted" "s3://${backup.bucket}/backups/\$prefix/\$name.dump.age"
keep_encrypted=true
date -u +%FT%TZ > "\$root/last-off-host-success"
rm -f "\$plain"
find "\$root/daily" -type f -name '*.age' -printf '%T@ %p\n' | sort -nr | tail -n +${backup.dailyRetention + 1} | cut -d' ' -f2- | xargs -r rm -f
if [ "\$(date -u +%u)" = 7 ]; then cp "\$encrypted" "\$root/weekly/\$name.dump.age"; fi
find "\$root/weekly" -type f -name '*.age' -printf '%T@ %p\n' | sort -nr | tail -n +${backup.weeklyRetention + 1} | cut -d' ' -f2- | xargs -r rm -f
echo "Uploaded backups/\$prefix/\$name.dump.age"
''';
}

String dwBackupService(DwDeployTarget target) =>
    '''[Unit]
Description=DartWay encrypted database backup (${target.projectName})
[Service]
Type=oneshot
User=${target.deployUser}
ExecStart=${target.runtimeConfigDir}/backup daily
''';

String dwBackupTimer(DwDeployTarget target) {
  final [hour, minute] = target.backup!.schedule.split(':');
  return '''[Unit]
Description=Daily DartWay database backup (${target.projectName})
[Timer]
OnCalendar=*-*-* $hour:$minute:00 UTC
Persistent=true
[Install]
WantedBy=timers.target
''';
}
