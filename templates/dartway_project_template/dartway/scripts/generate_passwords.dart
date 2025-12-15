import 'dart:io';
import 'dart:math';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('❌ Usage: dart run scripts/rename.dart <new_project_name>');
    exit(1);
  }

  final newName = args.first.trim();

  await generatePasswords(newName);
}

generatePasswords(String newName) async {
  print('🔐 Setting up docker-compose.yaml and passwords.yaml...\n');

  // Generate random passwords
  final databasePasswordDevelopment = _generateRandomPassword();
  final redisPasswordDevelopment = _generateRandomPassword();
  final serviceSecretDevelopment = _generateRandomPassword();
  final databasePasswordTest = _generateRandomPassword();
  final redisPasswordTest = _generateRandomPassword();

  // Copy and process passwords template
  final passwordsTemplate = File('dartway/templates/passwords.template.yaml');
  final passwordsTarget = File('${newName}_server/config/passwords.yaml');

  if (passwordsTemplate.existsSync()) {
    try {
      var content = await passwordsTemplate.readAsString();
      content = content.replaceAll(
        '\${DATABASE_PASSWORD_DEVELOPMENT}',
        databasePasswordDevelopment,
      );
      content = content.replaceAll(
        '\${REDIS_PASSWORD_DEVELOPMENT}',
        redisPasswordDevelopment,
      );
      content = content.replaceAll(
        '\${SERVICE_SECRET_DEVELOPMENT}',
        serviceSecretDevelopment,
      );
      content = content.replaceAll(
        '\${DATABASE_PASSWORD_TEST}',
        databasePasswordTest,
      );
      content = content.replaceAll(
        '\${REDIS_PASSWORD_TEST}',
        redisPasswordTest,
      );

      await passwordsTarget.writeAsString(content);
      print('✏️  Generated passwords.yaml with random passwords');
    } catch (e) {
      print('⚠️ Could not process passwords template ($e)');
    }
  }

  // Copy and process docker-compose template
  final dockerTemplate = File('dartway/templates/docker-compose.template.yaml');
  final dockerTarget = File('${newName}_server/docker-compose.yaml');

  if (dockerTemplate.existsSync()) {
    try {
      var content = await dockerTemplate.readAsString();
      content = content.replaceAll(
        '\${DATABASE_PASSWORD_DEVELOPMENT}',
        databasePasswordDevelopment,
      );
      content = content.replaceAll(
        '\${REDIS_PASSWORD_DEVELOPMENT}',
        redisPasswordDevelopment,
      );
      content = content.replaceAll(
        '\${DATABASE_PASSWORD_TEST}',
        databasePasswordTest,
      );
      content = content.replaceAll(
        '\${REDIS_PASSWORD_TEST}',
        redisPasswordTest,
      );

      await dockerTarget.writeAsString(content);
      print('✏️  Generated docker-compose.yaml with random passwords');
    } catch (e) {
      print('⚠️ Could not process docker-compose template ($e)');
    }
  }

  print('✅ Passwords and templates generated successfully\n');
}

String _generateRandomPassword() {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random();
  final buffer = StringBuffer();

  for (int i = 0; i < 32; i++) {
    buffer.write(chars[random.nextInt(chars.length)]);
  }

  final password = buffer.toString();
  print('🔐 Generated password: $password');

  return password;
}
