// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get loadFailed =>
      'Не удалось загрузить — проверьте соединение и попробуйте ещё раз.';

  @override
  String get retry => 'Повторить';

  @override
  String get actionFailed => 'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get notImplementedYet => 'Пока не реализовано';

  @override
  String get connectionOnline => 'онлайн';

  @override
  String get connectionConnecting => 'подключение';

  @override
  String get connectionOffline => 'нет связи';

  @override
  String get connectionIncompatible => 'обновите приложение';

  @override
  String get requiredField => 'Обязательное поле';

  @override
  String get continueAction => 'Продолжить';

  @override
  String get saveAction => 'Сохранить';

  @override
  String get saveChanges => 'Сохранить изменения';

  @override
  String get tabHome => 'Главная';

  @override
  String get tabProfile => 'Профиль';

  @override
  String get homeTitle => 'Главная';

  @override
  String helloUser(String name) {
    return 'Привет, $name';
  }

  @override
  String homeAppName(String appName) {
    return 'Вы в приложении $appName';
  }

  @override
  String get homeLiveHint =>
      'Название выше — настройка на сервере: поменяйте её в админке, и все открытые экраны обновятся сами, без перезагрузки.';

  @override
  String get homeNextStepTitle => 'Ваша первая фича';

  @override
  String get homeNextStepBody =>
      'Опишите объект данных и запрос в shared-пакете, строку и обработчик на сервере, запустите dartway generate и подпишитесь на запрос через dw.request в виджете.';

  @override
  String authStepTitle(String step) {
    String _temp0 = intl.Intl.selectLogic(step, {
      'identifier': 'Вход',
      'code': 'Подтверждение',
      'consents': 'Новая учётная запись',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get authIntro =>
      'Войдите по номеру телефона или e-mail. Если мы его ещё не знаем, вход создаст учётную запись.';

  @override
  String identifierKind(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'phone': 'Телефон',
      'email': 'E-mail',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get phoneLabel => 'Номер телефона';

  @override
  String get phoneHint => '+7 999 123-45-67';

  @override
  String get invalidPhoneNumber => 'Введите номер из 10–15 цифр';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get emailHint => 'name@example.com';

  @override
  String get invalidEmail => 'Введите адрес e-mail';

  @override
  String get getCodeAction => 'Получить код';

  @override
  String get codeTitle => 'Введите код';

  @override
  String codeSentTo(String identifier) {
    return 'Мы отправили код на $identifier';
  }

  @override
  String resendCodeIn(int seconds) {
    return 'Новый код через $seconds с';
  }

  @override
  String get resendCodeAction => 'Отправить новый код';

  @override
  String get changeIdentifierAction => 'Другой телефон или e-mail';

  @override
  String consentsIntro(String identifier) {
    return '$identifier у нас впервые. Представьтесь и примите условия, чтобы создать учётную запись.';
  }

  @override
  String get nameLabel => 'Имя';

  @override
  String get termsConsentPrefix => 'Я принимаю ';

  @override
  String get termsLink => 'условия использования';

  @override
  String get termsConsentMiddle => ' и ';

  @override
  String get privacyLink => 'политику конфиденциальности';

  @override
  String get marketingConsent => 'Присылать мне новости и предложения';

  @override
  String get youMustAgree => 'Чтобы продолжить, примите условия';

  @override
  String get createAccountAction => 'Создать учётную запись';

  @override
  String get whatIsYourName => 'Как вас зовут?';

  @override
  String get whatIsYourNameHint => 'Так вас будут видеть в приложении.';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get adminPanel => 'Админка';

  @override
  String get signOutAction => 'Выйти';

  @override
  String get deleteAccountAction => 'Удалить аккаунт';

  @override
  String get deleteAccountConfirmation =>
      'Удалить аккаунт и все данные в нём? Отменить это нельзя.';

  @override
  String get firstNameLabel => 'Имя';

  @override
  String get firstNameHint => 'Введите имя';

  @override
  String get lastNameLabel => 'Фамилия';

  @override
  String get firstNameRequired => 'Введите имя';

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
  String get profileUpdated => 'Профиль сохранён';

  @override
  String get profilePhotoHint => 'Нажмите на фото, чтобы сменить его';

  @override
  String get profilePhotoUpdated => 'Фото обновлено';

  @override
  String get profilePhotoRemove => 'Удалить фото';

  @override
  String get profilePhotoRemoved => 'Фото удалено';

  @override
  String get identitySectionTitle => 'Вход';

  @override
  String get identityNotSet => 'Не добавлен';

  @override
  String get identityAddAction => 'Добавить';

  @override
  String get identityChangeAction => 'Изменить';

  @override
  String identitySheetTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'phone': 'Новый номер телефона',
      'email': 'Новый e-mail',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get identitySheetIntro =>
      'Мы пришлём код для подтверждения. До этого ничего не изменится, и вы останетесь в приложении.';

  @override
  String get identityConfirmAction => 'Подтвердить';

  @override
  String identitySaved(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'phone': 'Номер сохранён',
      'email': 'E-mail сохранён',
      'other': 'Сохранено',
    });
    return '$_temp0';
  }

  @override
  String get adminDashboard => 'Сводка';

  @override
  String get adminUsers => 'Пользователи';

  @override
  String get adminSettings => 'Настройки';

  @override
  String get backToApp => 'Вернуться в приложение';

  @override
  String get countersLiveHint =>
      'Числа считает сервер, и они меняются сразу — без перезагрузки.';

  @override
  String get countMembers => 'Пользователи';

  @override
  String get countAdmins => 'Администраторы';

  @override
  String get countMarketingOptIns => 'Подписаны на новости';

  @override
  String get searchLabel => 'Поиск';

  @override
  String get searchHint => 'Имя, телефон или e-mail';

  @override
  String get allRoles => 'Все роли';

  @override
  String roleName(String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'user': 'Пользователь',
      'admin': 'Администратор',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get noMembersYet => 'Пользователей пока нет.';

  @override
  String get noMembersMatch => 'Никто не подходит.';

  @override
  String membersPage(int page, int pageCount, int total) {
    return 'Страница $page из $pageCount · всего $total';
  }

  @override
  String get previousPage => 'Предыдущая страница';

  @override
  String get nextPage => 'Следующая страница';

  @override
  String confirmChangeRole(String name, String role) {
    return 'Сменить роль пользователя $name на «$role»?';
  }

  @override
  String get roleLabel => 'Роль';

  @override
  String get ownRoleHint => 'Свою роль меняет другой администратор.';

  @override
  String get userCardNotFound => 'Такого пользователя нет.';

  @override
  String userCardJoined(String date) {
    return 'С нами с $date';
  }

  @override
  String userCardTermsAccepted(String date) {
    return 'Условия приняты $date';
  }

  @override
  String get userCardTermsNotAccepted =>
      'Создан системой: условия не принимались';

  @override
  String userCardMarketing(String agreed) {
    String _temp0 = intl.Intl.selectLogic(agreed, {
      'true': 'Подписан на новости и предложения',
      'other': 'Не подписан на новости и предложения',
    });
    return '$_temp0';
  }

  @override
  String get userCardIdentifiers => 'Входит через';

  @override
  String identifierVerified(String date) {
    return 'подтверждён $date';
  }

  @override
  String get identifierNotVerified => 'ни разу не подтверждён';

  @override
  String get appSettingsTitle => 'Настройки приложения';

  @override
  String get appNameLabel => 'Название приложения';

  @override
  String get signUpEnabledLabel => 'Регистрация новых учётных записей открыта';

  @override
  String get settingsSaved => 'Настройки сохранены';

  @override
  String get refusalGeneric => 'Запрос отклонён.';

  @override
  String get refusalConsentsRequired =>
      'Чтобы создать учётную запись, примите условия.';

  @override
  String get refusalSignUpClosed =>
      'Регистрация новых учётных записей сейчас закрыта.';

  @override
  String get refusalFirstNameRequired => 'Введите имя.';

  @override
  String get refusalSettingKeyUnknown => 'Такой настройки нет.';

  @override
  String get refusalOwnRoleLocked => 'Свою роль меняет другой администратор.';

  @override
  String get refusalForbidden => 'Недостаточно прав.';

  @override
  String get refusalNotFound => 'Этого больше нет.';

  @override
  String get refusalConflict =>
      'Данные только что изменились — попробуйте ещё раз.';

  @override
  String get refusalInvalid => 'Проверьте введённые данные.';

  @override
  String get refusalInvalidIdentifier =>
      'Введите корректный телефон или e-mail.';

  @override
  String get refusalWrongCode => 'Неверный код.';

  @override
  String refusalWrongCodeAttemptsLeft(int attemptsLeft) {
    return 'Неверный код. Осталось попыток: $attemptsLeft';
  }

  @override
  String get refusalCodeExpired => 'Код больше не действует — запросите новый.';

  @override
  String get refusalTooManyRequests =>
      'Слишком много попыток. Подождите немного.';

  @override
  String refusalTooManyRequestsRetryIn(int seconds) {
    return 'Слишком много попыток. Повторите через $seconds с.';
  }

  @override
  String get refusalUnknownChannel =>
      'Эта версия приложения не совпадает с сервером — обновите его.';

  @override
  String get refusalIdentifierTaken =>
      'Это уже используется другой учётной записью.';

  @override
  String refusalUploadTooLarge(int megabytes) {
    return 'Файл слишком большой: не больше $megabytes МБ.';
  }

  @override
  String get refusalUploadTypeRejected => 'Файлы такого типа не принимаются.';

  @override
  String get refusalUploadFailed => 'Файл не загрузился. Попробуйте ещё раз.';

  @override
  String get refusalFileNotOwned => 'Этот файл здесь использовать нельзя.';

  @override
  String get updateRequiredTitle => 'Обновите приложение';

  @override
  String get updateRequiredBody =>
      'Эта версия приложения больше не поддерживается. Установите последнюю, чтобы продолжить.';

  @override
  String get serverMismatchTitle => 'Приложение не может связаться с сервером';

  @override
  String get serverMismatchBody =>
      'Приложение и сервер говорят на разных версиях. Мы уже чиним — попробуйте позже.';
}
