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

  Map<String, Object?> toQueryMap() => <String, Object?>{
    if (offset != null) 'offset': offset,
    if (limit != null) 'limit': limit,
    if (beforeId != null) 'beforeId': beforeId,
    if (afterId != null) 'afterId': afterId,
  };
}
