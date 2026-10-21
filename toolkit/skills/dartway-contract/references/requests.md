## 3. Choosing the request kind — by the shape of the screen

| The screen shows | Kind | Declared as | Handler (`dartway-server`) |
|---|---|---|---|
| one object that must exist | `DwSingleRequest<T>` | `const GetInvoice({required this.invoiceId})` | `single`; `null` → `dw.notFound` |
| one object that may be absent | `DwMaybeRequest<T>` | overrides `matches` | `maybe`; `null` is an answer |
| a whole list the domain bounds — a member's settings, a team's members | `DwListRequest<T>` | `super()`; `super(maxItems: 500)` only with the reason in its doc comment | `list` |
| a list whose membership only the server decides | `DwListRequest<T>` | `super.updateOnly()` | `list` |
| a derived list the client cannot compute (a ranking, an aggregate) | `DwListRequest<T>` | `super.refetchOnUpdate()` | `list` |
| an endless feed | `DwPageRequest<T>` | `super(pageSize: 20, maxPageSize: 100)` | `page` |
| numbered pages with a total | `DwTableRequest<T>` | `page`/`pageSize` fields, `super(maxPageSize: 100)` — below 1 is refused by the framework | `table` |
| a newest-first sequence at an anchor — a chat, a log | `DwWindowRequest<T, S, I>` | `super(pageSize: 40)`, `positionOf` | `window` |

A `DwListRequest` is for lists bounded by the domain; anything that grows with use — invoices,
tasks, messages, history — is a page, table or window. A list has a bound, `maxItems` (200 unless the
class raises it, with a one-line reason): a handler answering past it fails the call in tests and on
a development server, and in production is served whole with a warning in the server log
(`dartway-server`). A list near its bound is a list that should be a page.

What an update does to each kind is `dartway-realtime`. The order a page, table or window handler reads
in is total (`createdAt, id`). A window names a row's place for both sides:
`DwWindowPosition<DateTime, int> positionOf(InvoiceEvent item) => (sortValue: item.happenedAt, id: item.id);`
(`S` is `int`, `String`, `DateTime` or `DwCalendarDay`; `I` is `int` or `String`). A calendar day
sorts by its components and its cursor uses the canonical date string.

```dart
/// A team's members, by name, live on the team's channel.
final class ListTeamMembers extends DwListRequest<TeamMember>
    with _$ListTeamMembers {
  const ListTeamMembers({required this.teamId});

  final int teamId;

  @override
  List<DwLiveChannel> get channels => [DwLiveChannel(AcmeChannel.team, teamId)];

  @override
  bool matches(TeamMember item) => item.teamId == teamId;

  @override
  int Function(TeamMember a, TeamMember b) get sort =>
      (a, b) => a.name.compareTo(b.name);
}
```
