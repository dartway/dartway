class DwPaginationParams {
  final int? offset;
  final int? limit;

  final int? beforeId;
  final int? afterId;

  const DwPaginationParams({
    this.offset,
    this.limit,
    this.beforeId,
    this.afterId,
  });
}
