// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get loadFailed =>
      'Не удалось загрузить — проверьте связь и попробуйте снова.';

  @override
  String get retry => 'Повторить';

  @override
  String get actionFailed => 'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get connectionOnline => 'онлайн';

  @override
  String get connectionConnecting => 'подключение';

  @override
  String get connectionOffline => 'офлайн';

  @override
  String get connectionIncompatible => 'обновите приложение';

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
  String minutesShort(int minutes) {
    return '$minutes мин';
  }

  @override
  String withCoach(String name) {
    return 'с $name';
  }

  @override
  String spotsLeft(int left, int capacity) {
    return 'Свободно $left из $capacity';
  }

  @override
  String get sessionFull => 'Мест нет';

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
  String get notifyAboutNews => 'Уведомлять о новостях';

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
  String get sendMessage => 'Отправить';

  @override
  String get chatUnreadDivider => 'Непрочитанные сообщения';

  @override
  String get chatToday => 'Сегодня';

  @override
  String get chatYesterday => 'Вчера';

  @override
  String get chatEdited => 'изменено';

  @override
  String get chatDeletedMember => 'Участник удалён';

  @override
  String get chatDeletedMessage => 'Удалённое сообщение';

  @override
  String get chatPinnedMessage => 'Закреплённое сообщение';

  @override
  String chatPinnedPosition(int index, int count) {
    return '$index из $count';
  }

  @override
  String get chatReply => 'Ответить';

  @override
  String get chatEdit => 'Редактировать';

  @override
  String get chatCopyText => 'Скопировать текст';

  @override
  String get chatCopied => 'Скопировано';

  @override
  String get chatPin => 'Закрепить';

  @override
  String get chatUnpin => 'Открепить';

  @override
  String get chatDelete => 'Удалить';

  @override
  String get chatDeleteQuestion => 'Удалить сообщение?';

  @override
  String get chatDeleteExplanation =>
      'Оно пропадёт у всей команды. В ответах останется пометка, что сообщение удалено.';

  @override
  String chatReplyTo(String name) {
    return 'Ответ $name';
  }

  @override
  String get chatEditingMessage => 'Редактирование сообщения';

  @override
  String get chatAttachFile => 'Прикрепить файл';

  @override
  String chatAttachmentLimit(int max) {
    return 'Не больше $max файлов в одном сообщении';
  }

  @override
  String chatFileTooLarge(String name, int megabytes) {
    return '$name больше $megabytes МБ';
  }

  @override
  String chatUploadFailed(String name) {
    return '$name не загрузился';
  }

  @override
  String get chatPhoto => 'Фото';

  @override
  String get chatSearch => 'Поиск по чату';

  @override
  String get chatSearchHint => 'Искать сообщения';

  @override
  String get chatSearchNothing => 'Ничего не найдено';

  @override
  String chatSearchPosition(int index, int count) {
    return '$index из $count';
  }

  @override
  String get chatSearchOlder => 'Совпадение старше';

  @override
  String get chatSearchNewer => 'Совпадение новее';

  @override
  String get chatCloseSearch => 'Закрыть поиск';

  @override
  String get chatJumpToNewest => 'К новым сообщениям';

  @override
  String get chatMessageGone => 'Этого сообщения в чате больше нет';

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
  String get phoneLabel => 'Телефон';

  @override
  String get requiredField => 'Обязательное поле';

  @override
  String get invalidPhoneNumber => 'Некорректный номер';

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
  String get whatIsYourName => 'Как вас зовут?';

  @override
  String get whatIsYourNameHint => 'Имя увидит команда клуба в ваших записях';

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
      'Счётчики считает сервер, и они меняются вживую вместе с клубом — без перезагрузки.';

  @override
  String get countMembers => 'Участники';

  @override
  String get countSessions => 'Предстоящие занятия';

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
  String membersPage(int page, int pageCount, int total) {
    return 'Страница $page из $pageCount · участников: $total';
  }

  @override
  String get previousPage => 'Предыдущая страница';

  @override
  String get nextPage => 'Следующая страница';

  @override
  String confirmChangeRole(String name, String role) {
    return 'Сменить роль $name на «$role»?';
  }

  @override
  String get clubSettings => 'Настройки клуба';

  @override
  String get clubNameLabel => 'Название клуба';

  @override
  String get bookingEnabledLabel => 'Запись открыта';

  @override
  String get supportPhoneLabel => 'Телефон поддержки';

  @override
  String get saveAction => 'Сохранить';

  @override
  String get settingsSaved => 'Настройки сохранены';

  @override
  String get refusalGeneric => 'Запрос отклонён.';

  @override
  String get refusalTitleRequired => 'Добавьте заголовок.';

  @override
  String get refusalTextRequired => 'Добавьте текст.';

  @override
  String get refusalDurationNotPositive =>
      'Длительность должна быть больше нуля.';

  @override
  String get refusalPriceNegative => 'Цена не может быть отрицательной.';

  @override
  String get refusalCapacityTooSmall =>
      'На занятии должно быть хотя бы одно место.';

  @override
  String get refusalSessionInPast => 'Нельзя назначить занятие в прошлом.';

  @override
  String get refusalSessionStarted => 'Занятие уже началось.';

  @override
  String get refusalNoSpotsLeft => 'Мест на занятии не осталось.';

  @override
  String get refusalAlreadyBooked => 'Вы уже записаны на это занятие.';

  @override
  String get refusalBookingNotActive => 'Эта запись уже неактивна.';

  @override
  String get refusalRatingOutOfRange => 'Выберите оценку от 1 до 5.';

  @override
  String get refusalReviewNeedsAttendance =>
      'Отзыв можно оставить после посещения.';

  @override
  String get refusalAlreadyReviewed =>
      'Вы уже оставили отзыв об этом посещении.';

  @override
  String get refusalMessageEmpty => 'Сообщение пустое.';

  @override
  String refusalMessageTooLong(int max) {
    return 'Сообщение длиннее $max символов.';
  }

  @override
  String refusalTooManyAttachments(int max) {
    return 'Не больше $max файлов в одном сообщении.';
  }

  @override
  String get refusalEditWindowClosed =>
      'Сообщение нельзя изменить через сутки после отправки.';

  @override
  String refusalSearchQueryTooShort(int min) {
    return 'Для поиска нужно хотя бы $min символа.';
  }

  @override
  String get refusalSettingKeyUnknown => 'Такой настройки нет.';

  @override
  String get refusalFirstNameRequired => 'Введите имя.';

  @override
  String get refusalForbidden => 'У вас нет прав на это действие.';

  @override
  String get refusalNotFound => 'Этого больше не существует.';

  @override
  String get refusalConflict =>
      'Данные только что изменились — попробуйте ещё раз.';

  @override
  String get refusalInvalid => 'Проверьте введённые данные.';

  @override
  String get refusalInvalidPhone => 'Введите корректный номер телефона.';

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
      'Версия приложения не совпадает с сервером — обновите приложение.';

  @override
  String get updateRequiredTitle => 'Обновите приложение';

  @override
  String get updateRequiredBody =>
      'Эта версия приложения больше не поддерживается. Установите последнюю, чтобы продолжить пользоваться клубом.';

  @override
  String get serverMismatchTitle => 'Приложение не может связаться с сервером';

  @override
  String get serverMismatchBody =>
      'Приложение и сервер клуба говорят на разных версиях. Мы уже чиним — попробуйте позже.';

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
  String get refusalFileNotOwned => 'Этот файл здесь использовать нельзя.';

  @override
  String get refusalUploadFailed => 'Файл не загрузился. Попробуйте ещё раз.';
}
