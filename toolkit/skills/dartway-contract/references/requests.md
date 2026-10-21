## 3. Choosing the request kind — by the shape of the screen

| The screen shows | Kind | Declared as | Handler (`dartway-server`) |
|---|---|---|---|
| one object that must exist | `DwSingleRequest<T>` | `const GetInvoice({required this.invoiceId})` | `single`; `null` → `dw.notFound` |
| one object that may be absent | `DwMaybeRequest<T>` | overrides `matches` | `maybe`; `null` is an answer |
| a small whole list | `DwListRequest<T>` | `super()` | `list` |
| a list whose membership only the server decides | `DwListRequest<T>` | `super.updateOnly()` | `list` |
| a derived list the client cannot compute (a ranking, an aggregate) | `DwListRequest<T>` | `super.refetchOnUpdate()` | `list` |
| an endless feed | `DwPageRequest<T>` | `super(pageSize: 20, maxPageSize: 100)` | `page` |
| numbered pages with a total | `DwTableRequest<T>` | `page`/`pageSize` fields, `super(maxPageSize: 100)` — below 1 is refused by the framework | `table` |
| a newest-first sequence at an anchor — a chat, a log | `DwWindowRequest<T, S, I>` | `super(pageSize: 40)`, `positionOf` | `window` |

What an update does to each kind is `dartway-realtime`. The order a page, table or window handler reads
in is total (`createdAt, id`). A window names a row's place for both sides:
`DwWindowPosition<DateTime, int> positionOf(InvoiceEvent item) => (sortValue: item.happenedAt, id: item.id);`
(`S` is `int`, `String`, `DateTime` or `DwCalendarDay`; `I` is `int` or `String`). A calendar day
sorts by its components and its cursor uses the canonical date string.

```dart
/// The caller's invoices, newest first, live on the caller's own channel.
final class ListMyInvoices extends DwListRequest<CustomerInvoice>
    with _$ListMyInvoices {
  const ListMyInvoices();

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel.ofCaller(AcmeChannel.invoices),
  ];

  @override
  int Function(CustomerInvoice a, CustomerInvoice b) get sort =>
      (a, b) => b.id.compareTo(a.id);
}
```
