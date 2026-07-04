---
name: dartway-clean-code
description: >-
  DartwayTeam strict clean-code rules for ALL Flutter/Dart work (DartWay-проекты):
  self-explanatory naming (min 2 words), files ≤120 lines / single
  responsibility, never pass BuildContext or WidgetRef as params, no _buildXxx()
  widget-returning methods, no ref.invalidate, no GlobalKey tree lookups, no
  outer padding/margin inside a widget, no private widget classes in public
  feature files; plus SOLID, KISS, DRY, YAGNI, Law of Demeter, composition over
  inheritance, separation of concerns, fail-fast, tell-don't-ask, single source
  of truth, and tests for complex features / non-trivial bugfixes.
---

# Dartway Clean Code — правила DartwayTeam

Свод обязательных правил для **любого** Dart/Flutter кода в проектах **DartwayTeam**
(DartWay-проекты; dartway-first). Это не «рекомендации», а контракт стиля —
команда сознательно держит код чистым, чтобы не накапливать перечисленные ниже антипаттерны.

## Как пользоваться

- Сверяйся с правилами при **написании, генерации, рефакторинге и ревью** кода — даже маленького сниппета.
- Каждый блок: коротко **зачем** правило, затем `❌` (как нельзя) и `✅` (как нужно).
- Перед тем как отдать код — пройди [чек-лист](#чек-лист-перед-сдачей-кода) в конце.
- Часть 1 — жёсткие правила команды (самые неочевидные, нарушаются чаще всего). Часть 2 — общие принципы чистого кода. Часть 3 — тесты для сложного.

---

# Часть 1. Жёсткие правила команды

Эти правила специфичны для dartway-стека и нарушаются чаще всего. Держи их в голове первыми.

## 1.1 Нейминг: self-explanatory, минимум 2 слова

**Зачем:** имя должно отвечать «что это» без чтения типа и тела. Однословные и абстрактные имена заставляют читателя гадать.

```dart
// ❌ что это — модель? виджет? dto?
class User {}
final model = UserProfileModel();
final data = fetchData();
final order2 = getNewOrder();        // order2 — это что?
class DeliveryCard { final String s; final int n; final Function cb; }

// ✅ имя несёт смысл
class UserProfileModel {}
final userProfile = UserProfileModel();
final fetchedProfile = fetchProfile();
final updatedOrder = getNewOrder();  // рядом: initialOrder
class DeliveryCard { final String deliveryStatus; final int itemsCount; final VoidCallback onTap; }
```

## 1.2 Файл ≤ ~120 строк и одна ответственность

**Зачем:** один файл — одна причина для изменения. Модель + репозиторий + стейт + UI в одном файле невозможно ни читать, ни переиспользовать.

```
// ❌ order_screen.dart: OrderItemModel + OrderRepository + OrderState + OrderListScreen

// ✅ раздельно:
//   models/order_item_model.dart
//   data/order_repository.dart
//   state/order_state.dart
//   ui/order_list_screen.dart
```

## 1.3 Не передавай `BuildContext` / `WidgetRef` как параметры

**Зачем:** сервис/доменный код не должен знать про UI и жизненный цикл виджета. Это рвёт слои и плодит «протухший context».

```dart
// ❌ сервис лезет в UI
class PaymentService {
  void processPayment(BuildContext context, double amount) {
    ScaffoldMessenger.of(context).showSnackBar(...);
    Navigator.of(context).pop();
  }
}
void loadUserData(WidgetRef ref) { ref.read(userProvider); }

// ✅ сервис возвращает результат, UI сам решает что показать
class PaymentService {
  Future<PaymentResult> processPayment(double amount) async { ... }
}
// в виджете: final result = await service.processPayment(amount);
//            if (result.isSuccess) { ScaffoldMessenger.of(context)...; Navigator.of(context).pop(); }
```

## 1.4 Никаких `_buildXxx()`-методов, возвращающих виджет

**Зачем:** приватные build-методы не имеют `const`, не переиспользуются, ломают границы перестроения. Виджет — это класс, а не метод.

```dart
// ❌
class ProfilePage extends StatelessWidget {
  Widget _buildHeader() => Container(...);
  Widget _buildStats(int orders, int reviews) => Row(...);
  @override
  Widget build(BuildContext context) => Column(children: [_buildHeader(), _buildStats(10, 5)]);
}

// ✅ отдельные виджет-классы
class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Column(children: [ProfileHeader(), ProfileStats(orders: 10, reviews: 5)]);
}
// ProfileHeader / ProfileStats — каждый в своём файле (см. 1.8)
```

## 1.5 Никакого `ref.invalidate(...)` для рефреша

**Зачем:** `invalidate` — грубый сброс, который роняет связанные провайдеры и мигает UI. Обновляй состояние через нормальный механизм стейта (в dartway — refresh у `DwRepository`/state-провайдера, перезапрос данных).

```dart
// ❌
onPressed: () { ref.invalidate(cartProvider); ref.invalidate(userProvider); }

// ✅ явный рефреш стейта
onPressed: () => ref.read(cartStateProvider.notifier).refresh(),
```

## 1.6 Не ищи виджеты в дереве через `GlobalKey`

**Зачем:** `GlobalKey().currentState` — обращение к чужому состоянию мимо стейт-менеджмента. Управляй данными через провайдер/контроллер, а не дёргай дерево.

```dart
// ❌
final nameFieldKey = GlobalKey<FormFieldState>();
void validate() => nameFieldKey.currentState?.validate();

// ✅ состояние формы — в провайдере/контроллере; валидация по данным, а не по виджету
final isNameValid = ref.read(signUpFormProvider).isNameValid;
```

## 1.7 Никаких внешних отступов (`padding`/`margin`) внутри виджета

**Зачем:** внешний отступ — ответственность **родителя**, который размещает виджет. Если виджет добавляет себе внешние поля, его нельзя переиспользовать в другом контексте.

```dart
// ❌ виджет сам себе делает внешний отступ
class ProductCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Container(...));
}
class ActionButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(margin: const EdgeInsets.all(12), child: ElevatedButton(...)); // margin = внешний отступ
}

// ✅ виджет рисует только себя; отступ задаёт родитель
class ProductCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(...); // внутренний padding контента — можно
}
// родитель: Padding(padding: ..., child: ProductCard())  /  ListView(padding: ...)
```

## 1.8 Никаких приватных виджет-классов (`_Foo`) в публичных файлах фич

**Зачем:** `_MessageBubble` в `chat_message_list.dart` нельзя переиспользовать и тестировать снаружи. Каждый виджет — публичный класс в своём файле.

```dart
// ❌ chat_message_list.dart содержит class _MessageBubble и class _DateSeparator
// ✅ message_bubble.dart -> class MessageBubble; date_separator.dart -> class DateSeparator
```

---

# Часть 2. Принципы чистого кода

Общеизвестные принципы. Здесь — как они выглядят в Dart/Flutter и чего избегать.

## 2.1 SRP — Single Responsibility

**Зачем:** класс, который грузит данные, кэширует, валидирует, форматирует и показывает SnackBar, невозможно менять безопасно.

```dart
// ❌ OrderManager: fetchOrdersFromApi + cacheOrder + validateOrder + formatPrice + trackAnalytics + showSuccess(context)
// ✅ OrderRepository (данные) | OrderCache | OrderValidator (domain) | PriceFormatter (ui_kit) | AnalyticsService
```

## 2.2 OCP — Open/Closed

**Зачем:** добавление нового типа не должно требовать правки старого кода. Расширяй абстракцией, а не новой веткой `if/switch`.

```dart
// ❌ для нового канала лезем внутрь send()
void send(NotificationType type, String message) {
  if (type == email) {...} else if (type == push) {...} else if (type == telegram) {...}
}
// ✅ abstract class NotificationChannel { void send(String message); }
//    EmailChannel / PushChannel / TelegramChannel — новый канал = новый класс, send() не трогаем
```

## 2.3 LSP — Liskov Substitution

**Зачем:** наследник обязан работать везде, где работает родитель. Бросать `UnsupportedError` из переопределённого метода — сломанный контракт.

```dart
// ❌ class CachedReadOnlyRepository extends ReadOnlyRepository { @override save(x) => throw UnsupportedError(); }
// ✅ раздели интерфейсы: abstract Readable { getAll(); } / abstract Writable { save(x); }
```

## 2.4 ISP — Interface Segregation

**Зачем:** «жирный» интерфейс заставляет реализовывать ненужное через заглушки/исключения.

```dart
// ❌ abstract Worker { writeCode(); reviewCode(); designUI(); manageTeam(); deployToProduction(); }
//    class JuniorDeveloper implements Worker { designUI() => throw UnimplementedError(); ... }
// ✅ узкие роли: Coder / Reviewer / Designer / Manager — реализуй только нужные
```

## 2.5 DIP — Dependency Inversion

**Зачем:** высокоуровневый код должен зависеть от абстракции, а не от конкретной реализации. Переезд Firebase→Supabase не должен трогать экраны.

```dart
// ❌ final authService = FirebaseAuthService();    // прибили гвоздями к реализации
// ✅ зависим от abstract class AuthService; конкретику внедряем через провайдер/DI
final authService = ref.read(authServiceProvider); // -> FirebaseAuthService под капотом
```

## 2.6 KISS — проще

**Зачем:** лишняя сложность = лишние баги. Не пиши 15 строк и «паттерн стратегия» там, где хватит одной строки.

```dart
// ❌ 15 строк с циклом ради проверки пустоты;  Strategy+Context ради склейки двух строк
// ✅ items?.isEmpty ?? true;      '$first $last';
// ❌ Builder→LayoutBuilder→AnimatedContainer→MediaQuery→DefaultTextStyle ради одного Text
// ✅ Text(text)
```

## 2.7 DRY — не повторяйся

**Зачем:** скопированная карточка/логика расходится при первом же изменении. Выноси в общий виджет / extension / domain.

```dart
// ❌ три одинаковых Container-карточки подряд через Ctrl+C; одинаковый маппинг в ViewModel и ExportService
// ✅ OrderStatusCard(title: ..., status: ..., color: ...);
//    extension ActiveOrderFilter on List<OrderItemModel> { List<String> get exportTitles => ...; }
```

## 2.8 YAGNI — не делай впрок

**Зачем:** 20 полей «вдруг пригодятся» и абстракция при единственной реализации — это мёртвый груз, который надо поддерживать.

```dart
// ❌ UserProfileState с tiktokHandle/linkedInUrl/isInfluencer/... когда используются только name и email
// ❌ abstract BaseAnalyticsProvider + единственный FirebaseAnalyticsProvider
// ✅ держи только реальные поля; вводи абстракцию, когда появится второй провайдер
```

## 2.9 Law of Demeter — не лезь в чужие кишки

**Зачем:** цепочка `a.b.c.d` означает, что вызывающий знает всю внутреннюю структуру чужих объектов. Сломается любое звено.

```dart
// ❌ company.department.team.teamLead.getEmail();
// ❌ ref.read(appStateProvider).currentSession.activeUser.profile.displayName;
// ✅ company.teamLeadEmail;     ref.watch(currentUserDisplayNameProvider);
```

## 2.10 Composition over Inheritance

**Зачем:** 5-уровневая иерархия `AnimatedShadowedRoundedStyledWidget` нечитаема и неотлаживаема. Собирай поведение из частей.

```dart
// ❌ Base -> Styled -> RoundedStyled -> ShadowedRoundedStyled -> Animated...
// ✅ композиция: AnimatedOpacity(child: DecoratedBox(child: ClipRRect(child: child)))  / миксины / параметры
```

## 2.11 Separation of Concerns

**Зачем:** виджет с HTTP-запросом, расчётом скидки и валидацией нельзя ни тестировать, ни переиспользовать. UI только отображает.

```dart
// ❌ _ProductPageState: http.get(...) + calculateDiscount(...) + canAddToCart(...) прямо в State
// ✅ запросы -> repository; расчёты/правила -> domain; State только держит и показывает данные
```

## 2.12 Fail Fast — не глотай ошибки

**Зачем:** пустой `catch` прячет баг навсегда. Логируй, пробрасывай или обрабатывай конкретную ошибку.

```dart
// ❌ try { ... } catch (e) { return null; }      try { ... } catch (_) {}
// ✅ try { ... } on ApiException catch (e, st) { log.error(e, st); rethrow; }
```

## 2.13 Avoid Premature Optimization

**Зачем:** кастомный LRU-кэш на 50 пользователей — сложность без причины. Сначала измерь, потом оптимизируй.

```dart
// ❌ ручной LRU с _accessOrder и _maxCacheSize = 1000 для списка из 50 имён
// ✅ простой Map (или вообще без кэша), пока профайлер не покажет реальную проблему
```

## 2.14 Tell, Don't Ask

**Зачем:** не вытаскивай поля объекта, чтобы посчитать снаружи — пусть объект сам себя считает. Логика живёт рядом с данными.

```dart
// ❌ снаружи: складываем cart.itemPrices, вычитаем cart.promoDiscount, клампим...
// ✅ cart.total;   // ShoppingCart сам знает, как считать свой итог
```

## 2.15 Avoid God Object

**Зачем:** класс, который держит auth + orders + cart + profile + settings + navigation + analytics, — это всё приложение в одном файле.

```dart
// ❌ class AppController { login(); loadOrders(); addToCart(); updateProfile(); toggleTheme(); goToHome(); trackEvent(); }
// ✅ AuthService | OrderRepository | CartState | ProfileService | SettingsState | Router | AnalyticsService
```

## 2.16 Avoid Magic Numbers / Strings

**Зачем:** `if (distance > 50)` и `status == 'pndng'` — опечатка не ловится компилятором, смысл числа неизвестен. Имена и enum'ы.

```dart
// ❌ return weight * 3.5 + 299;          if (status == 'pndng') ...
// ✅ static const longDistanceBaseFee = 299;   enum OrderStatus { pending, delivered, inTransit }
//    switch (status) { case OrderStatus.pending: ... }   // компилятор требует покрыть все ветки
```

## 2.17 Single Source of Truth

**Зачем:** локальная копия глобального стейта рассинхронизируется — забыл записать обратно, и UI врёт.

```dart
// ❌ initState() { userName = GlobalAppState.userName; }  save() { GlobalAppState.userName = userName; }
// ✅ виджет читает и пишет напрямую через провайдер — один источник истины
final userName = ref.watch(userProfileProvider.select((p) => p.name));
```

---

# Часть 3. Тесты для сложного

**Зачем:** сложную логику нельзя проверить «на глаз» — она ломается на краевых случаях и тихо деградирует со временем. Тест фиксирует ожидаемое поведение и ловит регресс. Порог — по **сложности поведения**, а не по факту изменения.

**Что покрываем тестами:**
- Сложные фичи и нетривиальная логика — расчёты, бизнес-правила, стейт-машины, деньги (напр. кошелёк/оплаты).
- Краевые случаи и сценарии отката/деградации («даунгрейд»: истёк бизнес-профиль → снялся бейдж, отменили подписку, баланс ушёл в минус).
- Любой багфикс нетривиального поведения.

**Что НЕ тестируем:** косметику — перекрасил кнопку, поправил отступ, переименовал. Тест ради галочки противоречит KISS/YAGNI.

**Багфикс — строго «причина → фикс»:**
1. Сначала тест, **воспроизводящий баг**. Он падает — это и есть локализация причины.
2. Чинишь код, пока тест не позеленеет.
3. Тест остаётся в репо регрессионным стражем, чтобы баг не вернулся.

**Уровень теста — по тому, где живёт поведение** (сам уровень не догма):
- Логика (домен/сервисы/стейт/репозиторий) → юнит-тест. Сюда попадает большинство — логика и так вынесена из виджетов (см. 2.11 SoC).
- Поведение в UI → widget-тест на ключевой сценарий.

```dart
// ❌ сложный расчёт кошелька правится «на глаз», тестов нет — регресс ловят пользователи
// ❌ багфикс без теста: причина не зафиксирована, через месяц баг вернётся

// ✅ багфикс reproduce-first: красный тест на причину → фикс → остаётся регрессионным
test('кошелёк не уходит в минус при списании больше баланса', () {
  final wallet = Wallet(balance: 100);
  expect(() => wallet.charge(150), throwsA(isA<InsufficientFundsException>()));
});
```

---

## Капстоун: всё плохо → как надо

```dart
// ❌ имя в 1 слово + build-метод + context/ref как параметры + invalidate + внешний padding + дублирование
class Page extends ConsumerWidget {
  Widget _buildItem(BuildContext context, WidgetRef ref, dynamic d) => GestureDetector(
        onTap: () { ref.invalidate(someProvider); Navigator.of(context).pop(); },
        child: Padding(padding: const EdgeInsets.all(16), child: Text(d.toString())),
      );
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Column(children: [_buildItem(context, ref, 'один'), _buildItem(context, ref, 'два')]);
}

// ✅ осмысленное имя + отдельный виджет-класс + данные через стейт + отступ снаружи + список без копипасты
class ItemsListPage extends ConsumerWidget {
  const ItemsListPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsStateProvider);
    return Column(children: [for (final item in items) ItemTile(item: item)]);
  }
}
// item_tile.dart -> class ItemTile (внешний отступ задаёт родитель/ListView, рефреш через notifier)
```

---

## Чек-лист перед сдачей кода

- [ ] **Имена** осмысленные, ≥2 слов; нет `model`/`data`/`list`/`s`/`n`/`cb`/`order2`.
- [ ] **Файл** ≤ ~120 строк и одна ответственность (модель/репозиторий/стейт/UI раздельно).
- [ ] **Нет** `BuildContext`/`WidgetRef` в параметрах сервисов и функций.
- [ ] **Нет** `_buildXxx()`-методов, возвращающих виджет — это отдельные виджет-классы.
- [ ] **Нет** `ref.invalidate(...)` — рефреш через стейт.
- [ ] **Нет** `GlobalKey` для поиска виджетов в дереве.
- [ ] **Нет** внешних `padding`/`margin` внутри виджета — отступ задаёт родитель.
- [ ] **Нет** приватных виджет-классов (`_Foo`) в публичных файлах фич.
- [ ] **Сложное** (нетривиальная логика/поведение, деньги, откаты-«даунгрейд») покрыто тестом; багфикс — сначала падающий тест на причину, потом фикс. Косметику не тестируем.
- [ ] Соблюдены SOLID, KISS, DRY, YAGNI, Law of Demeter.
- [ ] Композиция вместо глубокого наследования; логика не в UI (SoC).
- [ ] Ошибки не проглатываются (fail fast); нет преждевременной оптимизации.
- [ ] Tell-don't-ask; нет god-объектов; нет магических чисел/строк (enum/const).
- [ ] Один источник истины — нет локальных копий глобального стейта.
