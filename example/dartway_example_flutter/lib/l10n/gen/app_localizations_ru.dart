// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get tabSchedule => 'Расписание';

  @override
  String get tabBookings => 'Мои записи';

  @override
  String get tabNews => 'Новости';

  @override
  String get tabChat => 'Чат команды';

  @override
  String get tabProfile => 'Профиль';

  @override
  String helloUser(String name) {
    return 'Привет, $name';
  }

  @override
  String get noUpcomingSessions => 'Пока нет предстоящих занятий';

  @override
  String get sessionFallbackTitle => 'Занятие';

  @override
  String minutesShort(int minutes) {
    return '$minutes мин';
  }

  @override
  String withCoach(String name) {
    return 'с $name';
  }

  @override
  String upToPeople(int count) {
    return 'до $count чел.';
  }

  @override
  String get book => 'Записаться';

  @override
  String get cancel => 'Отменить';

  @override
  String get youAreBooked => 'Вы записаны!';

  @override
  String get bookingCancelled => 'Запись отменена';

  @override
  String get noBookingsYet => 'Пока нет записей — выберите занятие!';

  @override
  String bookingStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'booked': 'Записан',
      'cancelled': 'Отменена',
      'attended': 'Посещено',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get cancelBooking => 'Отменить запись';

  @override
  String get leaveReview => 'Оставить отзыв';

  @override
  String get thanksForReview => 'Спасибо за отзыв!';

  @override
  String get reviewSheetTitle => 'Как прошло занятие?';

  @override
  String get reviewLabel => 'Отзыв';

  @override
  String get reviewHint => 'Расскажите, что понравилось (необязательно)';

  @override
  String get submitReview => 'Отправить отзыв';

  @override
  String get thanksForFeedback => 'Спасибо за обратную связь!';

  @override
  String get clubNews => 'Новости клуба';

  @override
  String get noNewsYet => 'Новостей пока нет — следите за обновлениями!';

  @override
  String get newClubPost => 'Новый пост клуба';

  @override
  String get postTitleLabel => 'Заголовок';

  @override
  String get postTitleHint => 'Что происходит?';

  @override
  String get postContentLabel => 'Текст';

  @override
  String get postContentHint => 'Расскажите участникам...';

  @override
  String get publish => 'Опубликовать';

  @override
  String get postPublished => 'Пост опубликован!';

  @override
  String get staffOnlyArea => 'Этот раздел — для команды клуба';

  @override
  String get noChatChannels => 'Пока нет каналов чата';

  @override
  String get sayHiToTeam => 'Поздоровайтесь с командой!';

  @override
  String get messageTheTeam => 'Напишите команде...';

  @override
  String get ourServices => 'Наши услуги';

  @override
  String get priceListComingSoon => 'Прайс-лист скоро появится';

  @override
  String serviceDurationPrice(int minutes, int price) {
    return '$minutes мин · $price ₽';
  }

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
      'Каждый счётчик — типизированный живой список: одна строка watchModelList, без кода загрузки. Обновляется, когда админ перезагружает данные.';

  @override
  String get countMembers => 'Участники';

  @override
  String get countSessions => 'Занятия';

  @override
  String get countNews => 'Новости';

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
  String get clubSettings => 'Настройки клуба';

  @override
  String get clubNameLabel => 'Название клуба';

  @override
  String get saveAction => 'Сохранить';

  @override
  String get settingsSaved => 'Настройки сохранены';

  @override
  String get noSettingsConfigured => 'Настройки не заданы.';

  @override
  String get networkErrorTryAgain => 'Ошибка сети. Попробуйте снова.';
}
