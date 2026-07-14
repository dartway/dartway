// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get tabProfile => 'Профиль';

  @override
  String get ourServices => 'Наши услуги';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get adminPanel => 'Админ-панель';

  @override
  String get signOutAction => 'Выйти';

  @override
  String get firstNameLabel => 'Имя';

  @override
  String get firstNameHint => 'Введите имя';

  @override
  String get firstNameRequired => 'Имя обязательно';

  @override
  String get genderLabel => 'Пол';

  @override
  String get genderNotSpecified => 'Не указан';

  @override
  String genderValue(String gender) {
    String _temp0 = intl.Intl.selectLogic(gender, {
      'male': 'Мужской',
      'female': 'Женский',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get saveChanges => 'Сохранить изменения';

  @override
  String get profileUpdated => 'Профиль обновлён!';

  @override
  String authStepTitle(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      'greeting': 'Добро пожаловать!',
      'registration': 'Шаг 1 из 3',
      'login': 'Шаг 1 из 2',
      'registrationConfirmation': 'Шаг 2 из 3',
      'loginConfirmation': 'Шаг 2 из 2',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get completeLoginToContinue =>
      'Войдите или зарегистрируйтесь, чтобы продолжить';

  @override
  String get registrationAction => 'Регистрация';

  @override
  String get loginAction => 'Вход';

  @override
  String get fillRegistrationData => 'Заполните данные регистрации';

  @override
  String get nameLabel => 'Имя';

  @override
  String get requiredField => 'Обязательное поле';

  @override
  String get youMustAgree => 'Нужно согласие';

  @override
  String get agreeTermsPrefix => 'Я ознакомлен и согласен с условиями';

  @override
  String get offerLink => 'оферты,';

  @override
  String get userAgreementLink => 'пользовательского соглашения,';

  @override
  String get acceptTermsPrefix => 'принимаю условия';

  @override
  String get dataPolicyLinkComma => 'политики обработки данных,';

  @override
  String get iGive => 'Я даю';

  @override
  String get consentLink => 'согласие';

  @override
  String get marketingConsentText =>
      'на получение информационных и рекламных рассылок, а также даю';

  @override
  String get dataProcessingConsentText =>
      'на обработку персональных данных в соответствии с';

  @override
  String get dataPolicyLink => 'политикой обработки данных';

  @override
  String get continueAction => 'Продолжить';

  @override
  String get alreadyHaveAccount => 'Уже есть аккаунт? ';

  @override
  String get stillNoAccount => 'Ещё нет аккаунта? ';

  @override
  String get enterSmsCode => 'Введите код из СМС';

  @override
  String sentCodeToNumber(String phone) {
    return 'Отправили 6-значный код на номер\n$phone';
  }

  @override
  String get adminDashboard => 'Дашборд';

  @override
  String get adminUsers => 'Пользователи';

  @override
  String get adminSettings => 'Настройки';

  @override
  String get backToApp => 'Назад в приложение';

  @override
  String get countersLiveHint =>
      'Счётчики живые: обновляются в реальном времени при изменении данных.';

  @override
  String get countMembers => 'Участники';

  @override
  String get searchLabel => 'Поиск';

  @override
  String get searchHint => 'Имя или телефон';

  @override
  String get allRoles => 'Все роли';

  @override
  String roleName(String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'client': 'Клиент',
      'staff': 'Команда',
      'admin': 'Админ',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get noMembersYet => 'Участников пока нет.';

  @override
  String get noMembersMatch => 'Никто не подходит под фильтр.';

  @override
  String confirmChangeRole(String name, String role) {
    return 'Сменить роль $name на «$role»?';
  }

  @override
  String get appSettings => 'Настройки приложения';

  @override
  String get appNameLabel => 'Название приложения';

  @override
  String get saveAction => 'Сохранить';

  @override
  String get settingsSaved => 'Настройки сохранены';

  @override
  String get noSettingsConfigured => 'Настройки не заданы.';

  @override
  String get networkErrorTryAgain => 'Ошибка сети. Попробуйте снова.';

  @override
  String get tabHome => 'Главная';

  @override
  String get homeTitle => 'Главная';

  @override
  String homeGreeting(String name) {
    return 'Привет, $name!';
  }

  @override
  String homeAppNameFromDatabase(String appName) {
    return 'Название приложения из базы: $appName';
  }

  @override
  String get homeNoAppName => 'Название ещё не задано — задайте его в админке.';

  @override
  String get homeNextStepTitle => 'Твоя первая фича';

  @override
  String get homeNextStepBody =>
      'Опиши модель, дай ей DwCrudConfig на сервере и прочитай через ref.watchModelList в виджете. Эндпоинты писать не нужно.';

  @override
  String get countSettings => 'Настройки';
}
