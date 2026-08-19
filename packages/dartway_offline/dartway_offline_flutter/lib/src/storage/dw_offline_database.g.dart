// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dw_offline_database.dart';

// ignore_for_file: type=lint
class $DwOfflinePackagesTable extends DwOfflinePackages
    with TableInfo<$DwOfflinePackagesTable, DwOfflinePackageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DwOfflinePackagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userScopeIdMeta = const VerificationMeta(
    'userScopeId',
  );
  @override
  late final GeneratedColumn<String> userScopeId = GeneratedColumn<String>(
    'user_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(trim(user_scope_id)) > 0)',
  );
  static const VerificationMeta _packageIdMeta = const VerificationMeta(
    'packageId',
  );
  @override
  late final GeneratedColumn<String> packageId = GeneratedColumn<String>(
    'package_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentIdentityMeta = const VerificationMeta(
    'contentIdentity',
  );
  @override
  late final GeneratedColumn<String> contentIdentity = GeneratedColumn<String>(
    'content_identity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeManifestRevisionMeta =
      const VerificationMeta('activeManifestRevision');
  @override
  late final GeneratedColumn<String> activeManifestRevision =
      GeneratedColumn<String>(
        'active_manifest_revision',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _activeManifestDigestMeta =
      const VerificationMeta('activeManifestDigest');
  @override
  late final GeneratedColumn<String> activeManifestDigest =
      GeneratedColumn<String>(
        'active_manifest_digest',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _stagingManifestRevisionMeta =
      const VerificationMeta('stagingManifestRevision');
  @override
  late final GeneratedColumn<String> stagingManifestRevision =
      GeneratedColumn<String>(
        'staging_manifest_revision',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _stagingManifestDigestMeta =
      const VerificationMeta('stagingManifestDigest');
  @override
  late final GeneratedColumn<String> stagingManifestDigest =
      GeneratedColumn<String>(
        'staging_manifest_digest',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _aggregateStatusMeta = const VerificationMeta(
    'aggregateStatus',
  );
  @override
  late final GeneratedColumn<String> aggregateStatus = GeneratedColumn<String>(
    'aggregate_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAssetCountMeta =
      const VerificationMeta('completedAssetCount');
  @override
  late final GeneratedColumn<int> completedAssetCount = GeneratedColumn<int>(
    'completed_asset_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (completed_asset_count >= 0)',
  );
  static const VerificationMeta _totalAssetCountMeta = const VerificationMeta(
    'totalAssetCount',
  );
  @override
  late final GeneratedColumn<int> totalAssetCount = GeneratedColumn<int>(
    'total_asset_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (total_asset_count >= completed_asset_count)',
  );
  static const VerificationMeta _createdAtEpochMsMeta = const VerificationMeta(
    'createdAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> createdAtEpochMs = GeneratedColumn<int>(
    'created_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtEpochMsMeta = const VerificationMeta(
    'updatedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtEpochMs = GeneratedColumn<int>(
    'updated_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userScopeId,
    packageId,
    contentIdentity,
    activeManifestRevision,
    activeManifestDigest,
    stagingManifestRevision,
    stagingManifestDigest,
    aggregateStatus,
    completedAssetCount,
    totalAssetCount,
    createdAtEpochMs,
    updatedAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dw_offline_packages';
  @override
  VerificationContext validateIntegrity(
    Insertable<DwOfflinePackageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_scope_id')) {
      context.handle(
        _userScopeIdMeta,
        userScopeId.isAcceptableOrUnknown(
          data['user_scope_id']!,
          _userScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_userScopeIdMeta);
    }
    if (data.containsKey('package_id')) {
      context.handle(
        _packageIdMeta,
        packageId.isAcceptableOrUnknown(data['package_id']!, _packageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_packageIdMeta);
    }
    if (data.containsKey('content_identity')) {
      context.handle(
        _contentIdentityMeta,
        contentIdentity.isAcceptableOrUnknown(
          data['content_identity']!,
          _contentIdentityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentIdentityMeta);
    }
    if (data.containsKey('active_manifest_revision')) {
      context.handle(
        _activeManifestRevisionMeta,
        activeManifestRevision.isAcceptableOrUnknown(
          data['active_manifest_revision']!,
          _activeManifestRevisionMeta,
        ),
      );
    }
    if (data.containsKey('active_manifest_digest')) {
      context.handle(
        _activeManifestDigestMeta,
        activeManifestDigest.isAcceptableOrUnknown(
          data['active_manifest_digest']!,
          _activeManifestDigestMeta,
        ),
      );
    }
    if (data.containsKey('staging_manifest_revision')) {
      context.handle(
        _stagingManifestRevisionMeta,
        stagingManifestRevision.isAcceptableOrUnknown(
          data['staging_manifest_revision']!,
          _stagingManifestRevisionMeta,
        ),
      );
    }
    if (data.containsKey('staging_manifest_digest')) {
      context.handle(
        _stagingManifestDigestMeta,
        stagingManifestDigest.isAcceptableOrUnknown(
          data['staging_manifest_digest']!,
          _stagingManifestDigestMeta,
        ),
      );
    }
    if (data.containsKey('aggregate_status')) {
      context.handle(
        _aggregateStatusMeta,
        aggregateStatus.isAcceptableOrUnknown(
          data['aggregate_status']!,
          _aggregateStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_aggregateStatusMeta);
    }
    if (data.containsKey('completed_asset_count')) {
      context.handle(
        _completedAssetCountMeta,
        completedAssetCount.isAcceptableOrUnknown(
          data['completed_asset_count']!,
          _completedAssetCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAssetCountMeta);
    }
    if (data.containsKey('total_asset_count')) {
      context.handle(
        _totalAssetCountMeta,
        totalAssetCount.isAcceptableOrUnknown(
          data['total_asset_count']!,
          _totalAssetCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalAssetCountMeta);
    }
    if (data.containsKey('created_at_epoch_ms')) {
      context.handle(
        _createdAtEpochMsMeta,
        createdAtEpochMs.isAcceptableOrUnknown(
          data['created_at_epoch_ms']!,
          _createdAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMsMeta);
    }
    if (data.containsKey('updated_at_epoch_ms')) {
      context.handle(
        _updatedAtEpochMsMeta,
        updatedAtEpochMs.isAcceptableOrUnknown(
          data['updated_at_epoch_ms']!,
          _updatedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userScopeId, packageId};
  @override
  DwOfflinePackageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DwOfflinePackageRow(
      userScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_scope_id'],
      )!,
      packageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_id'],
      )!,
      contentIdentity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_identity'],
      )!,
      activeManifestRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_manifest_revision'],
      ),
      activeManifestDigest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_manifest_digest'],
      ),
      stagingManifestRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}staging_manifest_revision'],
      ),
      stagingManifestDigest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}staging_manifest_digest'],
      ),
      aggregateStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aggregate_status'],
      )!,
      completedAssetCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_asset_count'],
      )!,
      totalAssetCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_asset_count'],
      )!,
      createdAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_epoch_ms'],
      )!,
      updatedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_epoch_ms'],
      )!,
    );
  }

  @override
  $DwOfflinePackagesTable createAlias(String alias) {
    return $DwOfflinePackagesTable(attachedDatabase, alias);
  }
}

class DwOfflinePackageRow extends DataClass
    implements Insertable<DwOfflinePackageRow> {
  final String userScopeId;
  final String packageId;
  final String contentIdentity;
  final String? activeManifestRevision;
  final String? activeManifestDigest;
  final String? stagingManifestRevision;
  final String? stagingManifestDigest;
  final String aggregateStatus;
  final int completedAssetCount;
  final int totalAssetCount;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  const DwOfflinePackageRow({
    required this.userScopeId,
    required this.packageId,
    required this.contentIdentity,
    this.activeManifestRevision,
    this.activeManifestDigest,
    this.stagingManifestRevision,
    this.stagingManifestDigest,
    required this.aggregateStatus,
    required this.completedAssetCount,
    required this.totalAssetCount,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_scope_id'] = Variable<String>(userScopeId);
    map['package_id'] = Variable<String>(packageId);
    map['content_identity'] = Variable<String>(contentIdentity);
    if (!nullToAbsent || activeManifestRevision != null) {
      map['active_manifest_revision'] = Variable<String>(
        activeManifestRevision,
      );
    }
    if (!nullToAbsent || activeManifestDigest != null) {
      map['active_manifest_digest'] = Variable<String>(activeManifestDigest);
    }
    if (!nullToAbsent || stagingManifestRevision != null) {
      map['staging_manifest_revision'] = Variable<String>(
        stagingManifestRevision,
      );
    }
    if (!nullToAbsent || stagingManifestDigest != null) {
      map['staging_manifest_digest'] = Variable<String>(stagingManifestDigest);
    }
    map['aggregate_status'] = Variable<String>(aggregateStatus);
    map['completed_asset_count'] = Variable<int>(completedAssetCount);
    map['total_asset_count'] = Variable<int>(totalAssetCount);
    map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs);
    map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs);
    return map;
  }

  DwOfflinePackagesCompanion toCompanion(bool nullToAbsent) {
    return DwOfflinePackagesCompanion(
      userScopeId: Value(userScopeId),
      packageId: Value(packageId),
      contentIdentity: Value(contentIdentity),
      activeManifestRevision: activeManifestRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(activeManifestRevision),
      activeManifestDigest: activeManifestDigest == null && nullToAbsent
          ? const Value.absent()
          : Value(activeManifestDigest),
      stagingManifestRevision: stagingManifestRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(stagingManifestRevision),
      stagingManifestDigest: stagingManifestDigest == null && nullToAbsent
          ? const Value.absent()
          : Value(stagingManifestDigest),
      aggregateStatus: Value(aggregateStatus),
      completedAssetCount: Value(completedAssetCount),
      totalAssetCount: Value(totalAssetCount),
      createdAtEpochMs: Value(createdAtEpochMs),
      updatedAtEpochMs: Value(updatedAtEpochMs),
    );
  }

  factory DwOfflinePackageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DwOfflinePackageRow(
      userScopeId: serializer.fromJson<String>(json['userScopeId']),
      packageId: serializer.fromJson<String>(json['packageId']),
      contentIdentity: serializer.fromJson<String>(json['contentIdentity']),
      activeManifestRevision: serializer.fromJson<String?>(
        json['activeManifestRevision'],
      ),
      activeManifestDigest: serializer.fromJson<String?>(
        json['activeManifestDigest'],
      ),
      stagingManifestRevision: serializer.fromJson<String?>(
        json['stagingManifestRevision'],
      ),
      stagingManifestDigest: serializer.fromJson<String?>(
        json['stagingManifestDigest'],
      ),
      aggregateStatus: serializer.fromJson<String>(json['aggregateStatus']),
      completedAssetCount: serializer.fromJson<int>(
        json['completedAssetCount'],
      ),
      totalAssetCount: serializer.fromJson<int>(json['totalAssetCount']),
      createdAtEpochMs: serializer.fromJson<int>(json['createdAtEpochMs']),
      updatedAtEpochMs: serializer.fromJson<int>(json['updatedAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userScopeId': serializer.toJson<String>(userScopeId),
      'packageId': serializer.toJson<String>(packageId),
      'contentIdentity': serializer.toJson<String>(contentIdentity),
      'activeManifestRevision': serializer.toJson<String?>(
        activeManifestRevision,
      ),
      'activeManifestDigest': serializer.toJson<String?>(activeManifestDigest),
      'stagingManifestRevision': serializer.toJson<String?>(
        stagingManifestRevision,
      ),
      'stagingManifestDigest': serializer.toJson<String?>(
        stagingManifestDigest,
      ),
      'aggregateStatus': serializer.toJson<String>(aggregateStatus),
      'completedAssetCount': serializer.toJson<int>(completedAssetCount),
      'totalAssetCount': serializer.toJson<int>(totalAssetCount),
      'createdAtEpochMs': serializer.toJson<int>(createdAtEpochMs),
      'updatedAtEpochMs': serializer.toJson<int>(updatedAtEpochMs),
    };
  }

  DwOfflinePackageRow copyWith({
    String? userScopeId,
    String? packageId,
    String? contentIdentity,
    Value<String?> activeManifestRevision = const Value.absent(),
    Value<String?> activeManifestDigest = const Value.absent(),
    Value<String?> stagingManifestRevision = const Value.absent(),
    Value<String?> stagingManifestDigest = const Value.absent(),
    String? aggregateStatus,
    int? completedAssetCount,
    int? totalAssetCount,
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
  }) => DwOfflinePackageRow(
    userScopeId: userScopeId ?? this.userScopeId,
    packageId: packageId ?? this.packageId,
    contentIdentity: contentIdentity ?? this.contentIdentity,
    activeManifestRevision: activeManifestRevision.present
        ? activeManifestRevision.value
        : this.activeManifestRevision,
    activeManifestDigest: activeManifestDigest.present
        ? activeManifestDigest.value
        : this.activeManifestDigest,
    stagingManifestRevision: stagingManifestRevision.present
        ? stagingManifestRevision.value
        : this.stagingManifestRevision,
    stagingManifestDigest: stagingManifestDigest.present
        ? stagingManifestDigest.value
        : this.stagingManifestDigest,
    aggregateStatus: aggregateStatus ?? this.aggregateStatus,
    completedAssetCount: completedAssetCount ?? this.completedAssetCount,
    totalAssetCount: totalAssetCount ?? this.totalAssetCount,
    createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
    updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
  );
  DwOfflinePackageRow copyWithCompanion(DwOfflinePackagesCompanion data) {
    return DwOfflinePackageRow(
      userScopeId: data.userScopeId.present
          ? data.userScopeId.value
          : this.userScopeId,
      packageId: data.packageId.present ? data.packageId.value : this.packageId,
      contentIdentity: data.contentIdentity.present
          ? data.contentIdentity.value
          : this.contentIdentity,
      activeManifestRevision: data.activeManifestRevision.present
          ? data.activeManifestRevision.value
          : this.activeManifestRevision,
      activeManifestDigest: data.activeManifestDigest.present
          ? data.activeManifestDigest.value
          : this.activeManifestDigest,
      stagingManifestRevision: data.stagingManifestRevision.present
          ? data.stagingManifestRevision.value
          : this.stagingManifestRevision,
      stagingManifestDigest: data.stagingManifestDigest.present
          ? data.stagingManifestDigest.value
          : this.stagingManifestDigest,
      aggregateStatus: data.aggregateStatus.present
          ? data.aggregateStatus.value
          : this.aggregateStatus,
      completedAssetCount: data.completedAssetCount.present
          ? data.completedAssetCount.value
          : this.completedAssetCount,
      totalAssetCount: data.totalAssetCount.present
          ? data.totalAssetCount.value
          : this.totalAssetCount,
      createdAtEpochMs: data.createdAtEpochMs.present
          ? data.createdAtEpochMs.value
          : this.createdAtEpochMs,
      updatedAtEpochMs: data.updatedAtEpochMs.present
          ? data.updatedAtEpochMs.value
          : this.updatedAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflinePackageRow(')
          ..write('userScopeId: $userScopeId, ')
          ..write('packageId: $packageId, ')
          ..write('contentIdentity: $contentIdentity, ')
          ..write('activeManifestRevision: $activeManifestRevision, ')
          ..write('activeManifestDigest: $activeManifestDigest, ')
          ..write('stagingManifestRevision: $stagingManifestRevision, ')
          ..write('stagingManifestDigest: $stagingManifestDigest, ')
          ..write('aggregateStatus: $aggregateStatus, ')
          ..write('completedAssetCount: $completedAssetCount, ')
          ..write('totalAssetCount: $totalAssetCount, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userScopeId,
    packageId,
    contentIdentity,
    activeManifestRevision,
    activeManifestDigest,
    stagingManifestRevision,
    stagingManifestDigest,
    aggregateStatus,
    completedAssetCount,
    totalAssetCount,
    createdAtEpochMs,
    updatedAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DwOfflinePackageRow &&
          other.userScopeId == this.userScopeId &&
          other.packageId == this.packageId &&
          other.contentIdentity == this.contentIdentity &&
          other.activeManifestRevision == this.activeManifestRevision &&
          other.activeManifestDigest == this.activeManifestDigest &&
          other.stagingManifestRevision == this.stagingManifestRevision &&
          other.stagingManifestDigest == this.stagingManifestDigest &&
          other.aggregateStatus == this.aggregateStatus &&
          other.completedAssetCount == this.completedAssetCount &&
          other.totalAssetCount == this.totalAssetCount &&
          other.createdAtEpochMs == this.createdAtEpochMs &&
          other.updatedAtEpochMs == this.updatedAtEpochMs);
}

class DwOfflinePackagesCompanion extends UpdateCompanion<DwOfflinePackageRow> {
  final Value<String> userScopeId;
  final Value<String> packageId;
  final Value<String> contentIdentity;
  final Value<String?> activeManifestRevision;
  final Value<String?> activeManifestDigest;
  final Value<String?> stagingManifestRevision;
  final Value<String?> stagingManifestDigest;
  final Value<String> aggregateStatus;
  final Value<int> completedAssetCount;
  final Value<int> totalAssetCount;
  final Value<int> createdAtEpochMs;
  final Value<int> updatedAtEpochMs;
  final Value<int> rowid;
  const DwOfflinePackagesCompanion({
    this.userScopeId = const Value.absent(),
    this.packageId = const Value.absent(),
    this.contentIdentity = const Value.absent(),
    this.activeManifestRevision = const Value.absent(),
    this.activeManifestDigest = const Value.absent(),
    this.stagingManifestRevision = const Value.absent(),
    this.stagingManifestDigest = const Value.absent(),
    this.aggregateStatus = const Value.absent(),
    this.completedAssetCount = const Value.absent(),
    this.totalAssetCount = const Value.absent(),
    this.createdAtEpochMs = const Value.absent(),
    this.updatedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DwOfflinePackagesCompanion.insert({
    required String userScopeId,
    required String packageId,
    required String contentIdentity,
    this.activeManifestRevision = const Value.absent(),
    this.activeManifestDigest = const Value.absent(),
    this.stagingManifestRevision = const Value.absent(),
    this.stagingManifestDigest = const Value.absent(),
    required String aggregateStatus,
    required int completedAssetCount,
    required int totalAssetCount,
    required int createdAtEpochMs,
    required int updatedAtEpochMs,
    this.rowid = const Value.absent(),
  }) : userScopeId = Value(userScopeId),
       packageId = Value(packageId),
       contentIdentity = Value(contentIdentity),
       aggregateStatus = Value(aggregateStatus),
       completedAssetCount = Value(completedAssetCount),
       totalAssetCount = Value(totalAssetCount),
       createdAtEpochMs = Value(createdAtEpochMs),
       updatedAtEpochMs = Value(updatedAtEpochMs);
  static Insertable<DwOfflinePackageRow> custom({
    Expression<String>? userScopeId,
    Expression<String>? packageId,
    Expression<String>? contentIdentity,
    Expression<String>? activeManifestRevision,
    Expression<String>? activeManifestDigest,
    Expression<String>? stagingManifestRevision,
    Expression<String>? stagingManifestDigest,
    Expression<String>? aggregateStatus,
    Expression<int>? completedAssetCount,
    Expression<int>? totalAssetCount,
    Expression<int>? createdAtEpochMs,
    Expression<int>? updatedAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userScopeId != null) 'user_scope_id': userScopeId,
      if (packageId != null) 'package_id': packageId,
      if (contentIdentity != null) 'content_identity': contentIdentity,
      if (activeManifestRevision != null)
        'active_manifest_revision': activeManifestRevision,
      if (activeManifestDigest != null)
        'active_manifest_digest': activeManifestDigest,
      if (stagingManifestRevision != null)
        'staging_manifest_revision': stagingManifestRevision,
      if (stagingManifestDigest != null)
        'staging_manifest_digest': stagingManifestDigest,
      if (aggregateStatus != null) 'aggregate_status': aggregateStatus,
      if (completedAssetCount != null)
        'completed_asset_count': completedAssetCount,
      if (totalAssetCount != null) 'total_asset_count': totalAssetCount,
      if (createdAtEpochMs != null) 'created_at_epoch_ms': createdAtEpochMs,
      if (updatedAtEpochMs != null) 'updated_at_epoch_ms': updatedAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DwOfflinePackagesCompanion copyWith({
    Value<String>? userScopeId,
    Value<String>? packageId,
    Value<String>? contentIdentity,
    Value<String?>? activeManifestRevision,
    Value<String?>? activeManifestDigest,
    Value<String?>? stagingManifestRevision,
    Value<String?>? stagingManifestDigest,
    Value<String>? aggregateStatus,
    Value<int>? completedAssetCount,
    Value<int>? totalAssetCount,
    Value<int>? createdAtEpochMs,
    Value<int>? updatedAtEpochMs,
    Value<int>? rowid,
  }) {
    return DwOfflinePackagesCompanion(
      userScopeId: userScopeId ?? this.userScopeId,
      packageId: packageId ?? this.packageId,
      contentIdentity: contentIdentity ?? this.contentIdentity,
      activeManifestRevision:
          activeManifestRevision ?? this.activeManifestRevision,
      activeManifestDigest: activeManifestDigest ?? this.activeManifestDigest,
      stagingManifestRevision:
          stagingManifestRevision ?? this.stagingManifestRevision,
      stagingManifestDigest:
          stagingManifestDigest ?? this.stagingManifestDigest,
      aggregateStatus: aggregateStatus ?? this.aggregateStatus,
      completedAssetCount: completedAssetCount ?? this.completedAssetCount,
      totalAssetCount: totalAssetCount ?? this.totalAssetCount,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userScopeId.present) {
      map['user_scope_id'] = Variable<String>(userScopeId.value);
    }
    if (packageId.present) {
      map['package_id'] = Variable<String>(packageId.value);
    }
    if (contentIdentity.present) {
      map['content_identity'] = Variable<String>(contentIdentity.value);
    }
    if (activeManifestRevision.present) {
      map['active_manifest_revision'] = Variable<String>(
        activeManifestRevision.value,
      );
    }
    if (activeManifestDigest.present) {
      map['active_manifest_digest'] = Variable<String>(
        activeManifestDigest.value,
      );
    }
    if (stagingManifestRevision.present) {
      map['staging_manifest_revision'] = Variable<String>(
        stagingManifestRevision.value,
      );
    }
    if (stagingManifestDigest.present) {
      map['staging_manifest_digest'] = Variable<String>(
        stagingManifestDigest.value,
      );
    }
    if (aggregateStatus.present) {
      map['aggregate_status'] = Variable<String>(aggregateStatus.value);
    }
    if (completedAssetCount.present) {
      map['completed_asset_count'] = Variable<int>(completedAssetCount.value);
    }
    if (totalAssetCount.present) {
      map['total_asset_count'] = Variable<int>(totalAssetCount.value);
    }
    if (createdAtEpochMs.present) {
      map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs.value);
    }
    if (updatedAtEpochMs.present) {
      map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflinePackagesCompanion(')
          ..write('userScopeId: $userScopeId, ')
          ..write('packageId: $packageId, ')
          ..write('contentIdentity: $contentIdentity, ')
          ..write('activeManifestRevision: $activeManifestRevision, ')
          ..write('activeManifestDigest: $activeManifestDigest, ')
          ..write('stagingManifestRevision: $stagingManifestRevision, ')
          ..write('stagingManifestDigest: $stagingManifestDigest, ')
          ..write('aggregateStatus: $aggregateStatus, ')
          ..write('completedAssetCount: $completedAssetCount, ')
          ..write('totalAssetCount: $totalAssetCount, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DwOfflineAssetsTable extends DwOfflineAssets
    with TableInfo<$DwOfflineAssetsTable, DwOfflineAssetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DwOfflineAssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userScopeIdMeta = const VerificationMeta(
    'userScopeId',
  );
  @override
  late final GeneratedColumn<String> userScopeId = GeneratedColumn<String>(
    'user_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(trim(user_scope_id)) > 0)',
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetRevisionMeta = const VerificationMeta(
    'assetRevision',
  );
  @override
  late final GeneratedColumn<String> assetRevision = GeneratedColumn<String>(
    'asset_revision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expectedSizeBytesMeta = const VerificationMeta(
    'expectedSizeBytes',
  );
  @override
  late final GeneratedColumn<int> expectedSizeBytes = GeneratedColumn<int>(
    'expected_size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (expected_size_bytes >= 0)',
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _downloadUrlMeta = const VerificationMeta(
    'downloadUrl',
  );
  @override
  late final GeneratedColumn<String> downloadUrl = GeneratedColumn<String>(
    'download_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allowedRedirectHostsJsonMeta =
      const VerificationMeta('allowedRedirectHostsJson');
  @override
  late final GeneratedColumn<String> allowedRedirectHostsJson =
      GeneratedColumn<String>(
        'allowed_redirect_hosts_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _blobNameMeta = const VerificationMeta(
    'blobName',
  );
  @override
  late final GeneratedColumn<String> blobName = GeneratedColumn<String>(
    'blob_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _assetStateMeta = const VerificationMeta(
    'assetState',
  );
  @override
  late final GeneratedColumn<String> assetState = GeneratedColumn<String>(
    'asset_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _refCountMeta = const VerificationMeta(
    'refCount',
  );
  @override
  late final GeneratedColumn<int> refCount = GeneratedColumn<int>(
    'ref_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (ref_count >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _isTombstonedMeta = const VerificationMeta(
    'isTombstoned',
  );
  @override
  late final GeneratedColumn<bool> isTombstoned = GeneratedColumn<bool>(
    'is_tombstoned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_tombstoned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtEpochMsMeta = const VerificationMeta(
    'createdAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> createdAtEpochMs = GeneratedColumn<int>(
    'created_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtEpochMsMeta = const VerificationMeta(
    'updatedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtEpochMs = GeneratedColumn<int>(
    'updated_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userScopeId,
    assetId,
    assetRevision,
    expectedSizeBytes,
    checksum,
    mimeType,
    relativePath,
    downloadUrl,
    allowedRedirectHostsJson,
    blobName,
    assetState,
    refCount,
    isTombstoned,
    createdAtEpochMs,
    updatedAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dw_offline_assets';
  @override
  VerificationContext validateIntegrity(
    Insertable<DwOfflineAssetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_scope_id')) {
      context.handle(
        _userScopeIdMeta,
        userScopeId.isAcceptableOrUnknown(
          data['user_scope_id']!,
          _userScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_userScopeIdMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('asset_revision')) {
      context.handle(
        _assetRevisionMeta,
        assetRevision.isAcceptableOrUnknown(
          data['asset_revision']!,
          _assetRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_assetRevisionMeta);
    }
    if (data.containsKey('expected_size_bytes')) {
      context.handle(
        _expectedSizeBytesMeta,
        expectedSizeBytes.isAcceptableOrUnknown(
          data['expected_size_bytes']!,
          _expectedSizeBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_expectedSizeBytesMeta);
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    } else if (isInserting) {
      context.missing(_checksumMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('download_url')) {
      context.handle(
        _downloadUrlMeta,
        downloadUrl.isAcceptableOrUnknown(
          data['download_url']!,
          _downloadUrlMeta,
        ),
      );
    }
    if (data.containsKey('allowed_redirect_hosts_json')) {
      context.handle(
        _allowedRedirectHostsJsonMeta,
        allowedRedirectHostsJson.isAcceptableOrUnknown(
          data['allowed_redirect_hosts_json']!,
          _allowedRedirectHostsJsonMeta,
        ),
      );
    }
    if (data.containsKey('blob_name')) {
      context.handle(
        _blobNameMeta,
        blobName.isAcceptableOrUnknown(data['blob_name']!, _blobNameMeta),
      );
    }
    if (data.containsKey('asset_state')) {
      context.handle(
        _assetStateMeta,
        assetState.isAcceptableOrUnknown(data['asset_state']!, _assetStateMeta),
      );
    } else if (isInserting) {
      context.missing(_assetStateMeta);
    }
    if (data.containsKey('ref_count')) {
      context.handle(
        _refCountMeta,
        refCount.isAcceptableOrUnknown(data['ref_count']!, _refCountMeta),
      );
    }
    if (data.containsKey('is_tombstoned')) {
      context.handle(
        _isTombstonedMeta,
        isTombstoned.isAcceptableOrUnknown(
          data['is_tombstoned']!,
          _isTombstonedMeta,
        ),
      );
    }
    if (data.containsKey('created_at_epoch_ms')) {
      context.handle(
        _createdAtEpochMsMeta,
        createdAtEpochMs.isAcceptableOrUnknown(
          data['created_at_epoch_ms']!,
          _createdAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMsMeta);
    }
    if (data.containsKey('updated_at_epoch_ms')) {
      context.handle(
        _updatedAtEpochMsMeta,
        updatedAtEpochMs.isAcceptableOrUnknown(
          data['updated_at_epoch_ms']!,
          _updatedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userScopeId, assetId, assetRevision};
  @override
  DwOfflineAssetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DwOfflineAssetRow(
      userScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_scope_id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      assetRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_revision'],
      )!,
      expectedSizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expected_size_bytes'],
      )!,
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      downloadUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}download_url'],
      ),
      allowedRedirectHostsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}allowed_redirect_hosts_json'],
      ),
      blobName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blob_name'],
      ),
      assetState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_state'],
      )!,
      refCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ref_count'],
      )!,
      isTombstoned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_tombstoned'],
      )!,
      createdAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_epoch_ms'],
      )!,
      updatedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_epoch_ms'],
      )!,
    );
  }

  @override
  $DwOfflineAssetsTable createAlias(String alias) {
    return $DwOfflineAssetsTable(attachedDatabase, alias);
  }
}

class DwOfflineAssetRow extends DataClass
    implements Insertable<DwOfflineAssetRow> {
  final String userScopeId;
  final String assetId;
  final String assetRevision;
  final int expectedSizeBytes;
  final String checksum;
  final String mimeType;
  final String relativePath;
  final String? downloadUrl;
  final String? allowedRedirectHostsJson;
  final String? blobName;
  final String assetState;
  final int refCount;
  final bool isTombstoned;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  const DwOfflineAssetRow({
    required this.userScopeId,
    required this.assetId,
    required this.assetRevision,
    required this.expectedSizeBytes,
    required this.checksum,
    required this.mimeType,
    required this.relativePath,
    this.downloadUrl,
    this.allowedRedirectHostsJson,
    this.blobName,
    required this.assetState,
    required this.refCount,
    required this.isTombstoned,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_scope_id'] = Variable<String>(userScopeId);
    map['asset_id'] = Variable<String>(assetId);
    map['asset_revision'] = Variable<String>(assetRevision);
    map['expected_size_bytes'] = Variable<int>(expectedSizeBytes);
    map['checksum'] = Variable<String>(checksum);
    map['mime_type'] = Variable<String>(mimeType);
    map['relative_path'] = Variable<String>(relativePath);
    if (!nullToAbsent || downloadUrl != null) {
      map['download_url'] = Variable<String>(downloadUrl);
    }
    if (!nullToAbsent || allowedRedirectHostsJson != null) {
      map['allowed_redirect_hosts_json'] = Variable<String>(
        allowedRedirectHostsJson,
      );
    }
    if (!nullToAbsent || blobName != null) {
      map['blob_name'] = Variable<String>(blobName);
    }
    map['asset_state'] = Variable<String>(assetState);
    map['ref_count'] = Variable<int>(refCount);
    map['is_tombstoned'] = Variable<bool>(isTombstoned);
    map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs);
    map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs);
    return map;
  }

  DwOfflineAssetsCompanion toCompanion(bool nullToAbsent) {
    return DwOfflineAssetsCompanion(
      userScopeId: Value(userScopeId),
      assetId: Value(assetId),
      assetRevision: Value(assetRevision),
      expectedSizeBytes: Value(expectedSizeBytes),
      checksum: Value(checksum),
      mimeType: Value(mimeType),
      relativePath: Value(relativePath),
      downloadUrl: downloadUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadUrl),
      allowedRedirectHostsJson: allowedRedirectHostsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(allowedRedirectHostsJson),
      blobName: blobName == null && nullToAbsent
          ? const Value.absent()
          : Value(blobName),
      assetState: Value(assetState),
      refCount: Value(refCount),
      isTombstoned: Value(isTombstoned),
      createdAtEpochMs: Value(createdAtEpochMs),
      updatedAtEpochMs: Value(updatedAtEpochMs),
    );
  }

  factory DwOfflineAssetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DwOfflineAssetRow(
      userScopeId: serializer.fromJson<String>(json['userScopeId']),
      assetId: serializer.fromJson<String>(json['assetId']),
      assetRevision: serializer.fromJson<String>(json['assetRevision']),
      expectedSizeBytes: serializer.fromJson<int>(json['expectedSizeBytes']),
      checksum: serializer.fromJson<String>(json['checksum']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      downloadUrl: serializer.fromJson<String?>(json['downloadUrl']),
      allowedRedirectHostsJson: serializer.fromJson<String?>(
        json['allowedRedirectHostsJson'],
      ),
      blobName: serializer.fromJson<String?>(json['blobName']),
      assetState: serializer.fromJson<String>(json['assetState']),
      refCount: serializer.fromJson<int>(json['refCount']),
      isTombstoned: serializer.fromJson<bool>(json['isTombstoned']),
      createdAtEpochMs: serializer.fromJson<int>(json['createdAtEpochMs']),
      updatedAtEpochMs: serializer.fromJson<int>(json['updatedAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userScopeId': serializer.toJson<String>(userScopeId),
      'assetId': serializer.toJson<String>(assetId),
      'assetRevision': serializer.toJson<String>(assetRevision),
      'expectedSizeBytes': serializer.toJson<int>(expectedSizeBytes),
      'checksum': serializer.toJson<String>(checksum),
      'mimeType': serializer.toJson<String>(mimeType),
      'relativePath': serializer.toJson<String>(relativePath),
      'downloadUrl': serializer.toJson<String?>(downloadUrl),
      'allowedRedirectHostsJson': serializer.toJson<String?>(
        allowedRedirectHostsJson,
      ),
      'blobName': serializer.toJson<String?>(blobName),
      'assetState': serializer.toJson<String>(assetState),
      'refCount': serializer.toJson<int>(refCount),
      'isTombstoned': serializer.toJson<bool>(isTombstoned),
      'createdAtEpochMs': serializer.toJson<int>(createdAtEpochMs),
      'updatedAtEpochMs': serializer.toJson<int>(updatedAtEpochMs),
    };
  }

  DwOfflineAssetRow copyWith({
    String? userScopeId,
    String? assetId,
    String? assetRevision,
    int? expectedSizeBytes,
    String? checksum,
    String? mimeType,
    String? relativePath,
    Value<String?> downloadUrl = const Value.absent(),
    Value<String?> allowedRedirectHostsJson = const Value.absent(),
    Value<String?> blobName = const Value.absent(),
    String? assetState,
    int? refCount,
    bool? isTombstoned,
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
  }) => DwOfflineAssetRow(
    userScopeId: userScopeId ?? this.userScopeId,
    assetId: assetId ?? this.assetId,
    assetRevision: assetRevision ?? this.assetRevision,
    expectedSizeBytes: expectedSizeBytes ?? this.expectedSizeBytes,
    checksum: checksum ?? this.checksum,
    mimeType: mimeType ?? this.mimeType,
    relativePath: relativePath ?? this.relativePath,
    downloadUrl: downloadUrl.present ? downloadUrl.value : this.downloadUrl,
    allowedRedirectHostsJson: allowedRedirectHostsJson.present
        ? allowedRedirectHostsJson.value
        : this.allowedRedirectHostsJson,
    blobName: blobName.present ? blobName.value : this.blobName,
    assetState: assetState ?? this.assetState,
    refCount: refCount ?? this.refCount,
    isTombstoned: isTombstoned ?? this.isTombstoned,
    createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
    updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
  );
  DwOfflineAssetRow copyWithCompanion(DwOfflineAssetsCompanion data) {
    return DwOfflineAssetRow(
      userScopeId: data.userScopeId.present
          ? data.userScopeId.value
          : this.userScopeId,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      assetRevision: data.assetRevision.present
          ? data.assetRevision.value
          : this.assetRevision,
      expectedSizeBytes: data.expectedSizeBytes.present
          ? data.expectedSizeBytes.value
          : this.expectedSizeBytes,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      downloadUrl: data.downloadUrl.present
          ? data.downloadUrl.value
          : this.downloadUrl,
      allowedRedirectHostsJson: data.allowedRedirectHostsJson.present
          ? data.allowedRedirectHostsJson.value
          : this.allowedRedirectHostsJson,
      blobName: data.blobName.present ? data.blobName.value : this.blobName,
      assetState: data.assetState.present
          ? data.assetState.value
          : this.assetState,
      refCount: data.refCount.present ? data.refCount.value : this.refCount,
      isTombstoned: data.isTombstoned.present
          ? data.isTombstoned.value
          : this.isTombstoned,
      createdAtEpochMs: data.createdAtEpochMs.present
          ? data.createdAtEpochMs.value
          : this.createdAtEpochMs,
      updatedAtEpochMs: data.updatedAtEpochMs.present
          ? data.updatedAtEpochMs.value
          : this.updatedAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflineAssetRow(')
          ..write('userScopeId: $userScopeId, ')
          ..write('assetId: $assetId, ')
          ..write('assetRevision: $assetRevision, ')
          ..write('expectedSizeBytes: $expectedSizeBytes, ')
          ..write('checksum: $checksum, ')
          ..write('mimeType: $mimeType, ')
          ..write('relativePath: $relativePath, ')
          ..write('downloadUrl: $downloadUrl, ')
          ..write('allowedRedirectHostsJson: $allowedRedirectHostsJson, ')
          ..write('blobName: $blobName, ')
          ..write('assetState: $assetState, ')
          ..write('refCount: $refCount, ')
          ..write('isTombstoned: $isTombstoned, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userScopeId,
    assetId,
    assetRevision,
    expectedSizeBytes,
    checksum,
    mimeType,
    relativePath,
    downloadUrl,
    allowedRedirectHostsJson,
    blobName,
    assetState,
    refCount,
    isTombstoned,
    createdAtEpochMs,
    updatedAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DwOfflineAssetRow &&
          other.userScopeId == this.userScopeId &&
          other.assetId == this.assetId &&
          other.assetRevision == this.assetRevision &&
          other.expectedSizeBytes == this.expectedSizeBytes &&
          other.checksum == this.checksum &&
          other.mimeType == this.mimeType &&
          other.relativePath == this.relativePath &&
          other.downloadUrl == this.downloadUrl &&
          other.allowedRedirectHostsJson == this.allowedRedirectHostsJson &&
          other.blobName == this.blobName &&
          other.assetState == this.assetState &&
          other.refCount == this.refCount &&
          other.isTombstoned == this.isTombstoned &&
          other.createdAtEpochMs == this.createdAtEpochMs &&
          other.updatedAtEpochMs == this.updatedAtEpochMs);
}

class DwOfflineAssetsCompanion extends UpdateCompanion<DwOfflineAssetRow> {
  final Value<String> userScopeId;
  final Value<String> assetId;
  final Value<String> assetRevision;
  final Value<int> expectedSizeBytes;
  final Value<String> checksum;
  final Value<String> mimeType;
  final Value<String> relativePath;
  final Value<String?> downloadUrl;
  final Value<String?> allowedRedirectHostsJson;
  final Value<String?> blobName;
  final Value<String> assetState;
  final Value<int> refCount;
  final Value<bool> isTombstoned;
  final Value<int> createdAtEpochMs;
  final Value<int> updatedAtEpochMs;
  final Value<int> rowid;
  const DwOfflineAssetsCompanion({
    this.userScopeId = const Value.absent(),
    this.assetId = const Value.absent(),
    this.assetRevision = const Value.absent(),
    this.expectedSizeBytes = const Value.absent(),
    this.checksum = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.downloadUrl = const Value.absent(),
    this.allowedRedirectHostsJson = const Value.absent(),
    this.blobName = const Value.absent(),
    this.assetState = const Value.absent(),
    this.refCount = const Value.absent(),
    this.isTombstoned = const Value.absent(),
    this.createdAtEpochMs = const Value.absent(),
    this.updatedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DwOfflineAssetsCompanion.insert({
    required String userScopeId,
    required String assetId,
    required String assetRevision,
    required int expectedSizeBytes,
    required String checksum,
    required String mimeType,
    required String relativePath,
    this.downloadUrl = const Value.absent(),
    this.allowedRedirectHostsJson = const Value.absent(),
    this.blobName = const Value.absent(),
    required String assetState,
    this.refCount = const Value.absent(),
    this.isTombstoned = const Value.absent(),
    required int createdAtEpochMs,
    required int updatedAtEpochMs,
    this.rowid = const Value.absent(),
  }) : userScopeId = Value(userScopeId),
       assetId = Value(assetId),
       assetRevision = Value(assetRevision),
       expectedSizeBytes = Value(expectedSizeBytes),
       checksum = Value(checksum),
       mimeType = Value(mimeType),
       relativePath = Value(relativePath),
       assetState = Value(assetState),
       createdAtEpochMs = Value(createdAtEpochMs),
       updatedAtEpochMs = Value(updatedAtEpochMs);
  static Insertable<DwOfflineAssetRow> custom({
    Expression<String>? userScopeId,
    Expression<String>? assetId,
    Expression<String>? assetRevision,
    Expression<int>? expectedSizeBytes,
    Expression<String>? checksum,
    Expression<String>? mimeType,
    Expression<String>? relativePath,
    Expression<String>? downloadUrl,
    Expression<String>? allowedRedirectHostsJson,
    Expression<String>? blobName,
    Expression<String>? assetState,
    Expression<int>? refCount,
    Expression<bool>? isTombstoned,
    Expression<int>? createdAtEpochMs,
    Expression<int>? updatedAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userScopeId != null) 'user_scope_id': userScopeId,
      if (assetId != null) 'asset_id': assetId,
      if (assetRevision != null) 'asset_revision': assetRevision,
      if (expectedSizeBytes != null) 'expected_size_bytes': expectedSizeBytes,
      if (checksum != null) 'checksum': checksum,
      if (mimeType != null) 'mime_type': mimeType,
      if (relativePath != null) 'relative_path': relativePath,
      if (downloadUrl != null) 'download_url': downloadUrl,
      if (allowedRedirectHostsJson != null)
        'allowed_redirect_hosts_json': allowedRedirectHostsJson,
      if (blobName != null) 'blob_name': blobName,
      if (assetState != null) 'asset_state': assetState,
      if (refCount != null) 'ref_count': refCount,
      if (isTombstoned != null) 'is_tombstoned': isTombstoned,
      if (createdAtEpochMs != null) 'created_at_epoch_ms': createdAtEpochMs,
      if (updatedAtEpochMs != null) 'updated_at_epoch_ms': updatedAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DwOfflineAssetsCompanion copyWith({
    Value<String>? userScopeId,
    Value<String>? assetId,
    Value<String>? assetRevision,
    Value<int>? expectedSizeBytes,
    Value<String>? checksum,
    Value<String>? mimeType,
    Value<String>? relativePath,
    Value<String?>? downloadUrl,
    Value<String?>? allowedRedirectHostsJson,
    Value<String?>? blobName,
    Value<String>? assetState,
    Value<int>? refCount,
    Value<bool>? isTombstoned,
    Value<int>? createdAtEpochMs,
    Value<int>? updatedAtEpochMs,
    Value<int>? rowid,
  }) {
    return DwOfflineAssetsCompanion(
      userScopeId: userScopeId ?? this.userScopeId,
      assetId: assetId ?? this.assetId,
      assetRevision: assetRevision ?? this.assetRevision,
      expectedSizeBytes: expectedSizeBytes ?? this.expectedSizeBytes,
      checksum: checksum ?? this.checksum,
      mimeType: mimeType ?? this.mimeType,
      relativePath: relativePath ?? this.relativePath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      allowedRedirectHostsJson:
          allowedRedirectHostsJson ?? this.allowedRedirectHostsJson,
      blobName: blobName ?? this.blobName,
      assetState: assetState ?? this.assetState,
      refCount: refCount ?? this.refCount,
      isTombstoned: isTombstoned ?? this.isTombstoned,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userScopeId.present) {
      map['user_scope_id'] = Variable<String>(userScopeId.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (assetRevision.present) {
      map['asset_revision'] = Variable<String>(assetRevision.value);
    }
    if (expectedSizeBytes.present) {
      map['expected_size_bytes'] = Variable<int>(expectedSizeBytes.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (downloadUrl.present) {
      map['download_url'] = Variable<String>(downloadUrl.value);
    }
    if (allowedRedirectHostsJson.present) {
      map['allowed_redirect_hosts_json'] = Variable<String>(
        allowedRedirectHostsJson.value,
      );
    }
    if (blobName.present) {
      map['blob_name'] = Variable<String>(blobName.value);
    }
    if (assetState.present) {
      map['asset_state'] = Variable<String>(assetState.value);
    }
    if (refCount.present) {
      map['ref_count'] = Variable<int>(refCount.value);
    }
    if (isTombstoned.present) {
      map['is_tombstoned'] = Variable<bool>(isTombstoned.value);
    }
    if (createdAtEpochMs.present) {
      map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs.value);
    }
    if (updatedAtEpochMs.present) {
      map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflineAssetsCompanion(')
          ..write('userScopeId: $userScopeId, ')
          ..write('assetId: $assetId, ')
          ..write('assetRevision: $assetRevision, ')
          ..write('expectedSizeBytes: $expectedSizeBytes, ')
          ..write('checksum: $checksum, ')
          ..write('mimeType: $mimeType, ')
          ..write('relativePath: $relativePath, ')
          ..write('downloadUrl: $downloadUrl, ')
          ..write('allowedRedirectHostsJson: $allowedRedirectHostsJson, ')
          ..write('blobName: $blobName, ')
          ..write('assetState: $assetState, ')
          ..write('refCount: $refCount, ')
          ..write('isTombstoned: $isTombstoned, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DwOfflinePackageAssetsTable extends DwOfflinePackageAssets
    with TableInfo<$DwOfflinePackageAssetsTable, DwOfflinePackageAssetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DwOfflinePackageAssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userScopeIdMeta = const VerificationMeta(
    'userScopeId',
  );
  @override
  late final GeneratedColumn<String> userScopeId = GeneratedColumn<String>(
    'user_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(trim(user_scope_id)) > 0)',
  );
  static const VerificationMeta _packageIdMeta = const VerificationMeta(
    'packageId',
  );
  @override
  late final GeneratedColumn<String> packageId = GeneratedColumn<String>(
    'package_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetRevisionMeta = const VerificationMeta(
    'assetRevision',
  );
  @override
  late final GeneratedColumn<String> assetRevision = GeneratedColumn<String>(
    'asset_revision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isRequiredMeta = const VerificationMeta(
    'isRequired',
  );
  @override
  late final GeneratedColumn<bool> isRequired = GeneratedColumn<bool>(
    'is_required',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_required" IN (0, 1))',
    ),
  );
  static const VerificationMeta _createdAtEpochMsMeta = const VerificationMeta(
    'createdAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> createdAtEpochMs = GeneratedColumn<int>(
    'created_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userScopeId,
    packageId,
    assetId,
    assetRevision,
    isRequired,
    createdAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dw_offline_package_assets';
  @override
  VerificationContext validateIntegrity(
    Insertable<DwOfflinePackageAssetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_scope_id')) {
      context.handle(
        _userScopeIdMeta,
        userScopeId.isAcceptableOrUnknown(
          data['user_scope_id']!,
          _userScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_userScopeIdMeta);
    }
    if (data.containsKey('package_id')) {
      context.handle(
        _packageIdMeta,
        packageId.isAcceptableOrUnknown(data['package_id']!, _packageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_packageIdMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('asset_revision')) {
      context.handle(
        _assetRevisionMeta,
        assetRevision.isAcceptableOrUnknown(
          data['asset_revision']!,
          _assetRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_assetRevisionMeta);
    }
    if (data.containsKey('is_required')) {
      context.handle(
        _isRequiredMeta,
        isRequired.isAcceptableOrUnknown(data['is_required']!, _isRequiredMeta),
      );
    } else if (isInserting) {
      context.missing(_isRequiredMeta);
    }
    if (data.containsKey('created_at_epoch_ms')) {
      context.handle(
        _createdAtEpochMsMeta,
        createdAtEpochMs.isAcceptableOrUnknown(
          data['created_at_epoch_ms']!,
          _createdAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    userScopeId,
    packageId,
    assetId,
    assetRevision,
  };
  @override
  DwOfflinePackageAssetRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DwOfflinePackageAssetRow(
      userScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_scope_id'],
      )!,
      packageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      assetRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_revision'],
      )!,
      isRequired: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_required'],
      )!,
      createdAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_epoch_ms'],
      )!,
    );
  }

  @override
  $DwOfflinePackageAssetsTable createAlias(String alias) {
    return $DwOfflinePackageAssetsTable(attachedDatabase, alias);
  }
}

class DwOfflinePackageAssetRow extends DataClass
    implements Insertable<DwOfflinePackageAssetRow> {
  final String userScopeId;
  final String packageId;
  final String assetId;
  final String assetRevision;
  final bool isRequired;
  final int createdAtEpochMs;
  const DwOfflinePackageAssetRow({
    required this.userScopeId,
    required this.packageId,
    required this.assetId,
    required this.assetRevision,
    required this.isRequired,
    required this.createdAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_scope_id'] = Variable<String>(userScopeId);
    map['package_id'] = Variable<String>(packageId);
    map['asset_id'] = Variable<String>(assetId);
    map['asset_revision'] = Variable<String>(assetRevision);
    map['is_required'] = Variable<bool>(isRequired);
    map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs);
    return map;
  }

  DwOfflinePackageAssetsCompanion toCompanion(bool nullToAbsent) {
    return DwOfflinePackageAssetsCompanion(
      userScopeId: Value(userScopeId),
      packageId: Value(packageId),
      assetId: Value(assetId),
      assetRevision: Value(assetRevision),
      isRequired: Value(isRequired),
      createdAtEpochMs: Value(createdAtEpochMs),
    );
  }

  factory DwOfflinePackageAssetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DwOfflinePackageAssetRow(
      userScopeId: serializer.fromJson<String>(json['userScopeId']),
      packageId: serializer.fromJson<String>(json['packageId']),
      assetId: serializer.fromJson<String>(json['assetId']),
      assetRevision: serializer.fromJson<String>(json['assetRevision']),
      isRequired: serializer.fromJson<bool>(json['isRequired']),
      createdAtEpochMs: serializer.fromJson<int>(json['createdAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userScopeId': serializer.toJson<String>(userScopeId),
      'packageId': serializer.toJson<String>(packageId),
      'assetId': serializer.toJson<String>(assetId),
      'assetRevision': serializer.toJson<String>(assetRevision),
      'isRequired': serializer.toJson<bool>(isRequired),
      'createdAtEpochMs': serializer.toJson<int>(createdAtEpochMs),
    };
  }

  DwOfflinePackageAssetRow copyWith({
    String? userScopeId,
    String? packageId,
    String? assetId,
    String? assetRevision,
    bool? isRequired,
    int? createdAtEpochMs,
  }) => DwOfflinePackageAssetRow(
    userScopeId: userScopeId ?? this.userScopeId,
    packageId: packageId ?? this.packageId,
    assetId: assetId ?? this.assetId,
    assetRevision: assetRevision ?? this.assetRevision,
    isRequired: isRequired ?? this.isRequired,
    createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
  );
  DwOfflinePackageAssetRow copyWithCompanion(
    DwOfflinePackageAssetsCompanion data,
  ) {
    return DwOfflinePackageAssetRow(
      userScopeId: data.userScopeId.present
          ? data.userScopeId.value
          : this.userScopeId,
      packageId: data.packageId.present ? data.packageId.value : this.packageId,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      assetRevision: data.assetRevision.present
          ? data.assetRevision.value
          : this.assetRevision,
      isRequired: data.isRequired.present
          ? data.isRequired.value
          : this.isRequired,
      createdAtEpochMs: data.createdAtEpochMs.present
          ? data.createdAtEpochMs.value
          : this.createdAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflinePackageAssetRow(')
          ..write('userScopeId: $userScopeId, ')
          ..write('packageId: $packageId, ')
          ..write('assetId: $assetId, ')
          ..write('assetRevision: $assetRevision, ')
          ..write('isRequired: $isRequired, ')
          ..write('createdAtEpochMs: $createdAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userScopeId,
    packageId,
    assetId,
    assetRevision,
    isRequired,
    createdAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DwOfflinePackageAssetRow &&
          other.userScopeId == this.userScopeId &&
          other.packageId == this.packageId &&
          other.assetId == this.assetId &&
          other.assetRevision == this.assetRevision &&
          other.isRequired == this.isRequired &&
          other.createdAtEpochMs == this.createdAtEpochMs);
}

class DwOfflinePackageAssetsCompanion
    extends UpdateCompanion<DwOfflinePackageAssetRow> {
  final Value<String> userScopeId;
  final Value<String> packageId;
  final Value<String> assetId;
  final Value<String> assetRevision;
  final Value<bool> isRequired;
  final Value<int> createdAtEpochMs;
  final Value<int> rowid;
  const DwOfflinePackageAssetsCompanion({
    this.userScopeId = const Value.absent(),
    this.packageId = const Value.absent(),
    this.assetId = const Value.absent(),
    this.assetRevision = const Value.absent(),
    this.isRequired = const Value.absent(),
    this.createdAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DwOfflinePackageAssetsCompanion.insert({
    required String userScopeId,
    required String packageId,
    required String assetId,
    required String assetRevision,
    required bool isRequired,
    required int createdAtEpochMs,
    this.rowid = const Value.absent(),
  }) : userScopeId = Value(userScopeId),
       packageId = Value(packageId),
       assetId = Value(assetId),
       assetRevision = Value(assetRevision),
       isRequired = Value(isRequired),
       createdAtEpochMs = Value(createdAtEpochMs);
  static Insertable<DwOfflinePackageAssetRow> custom({
    Expression<String>? userScopeId,
    Expression<String>? packageId,
    Expression<String>? assetId,
    Expression<String>? assetRevision,
    Expression<bool>? isRequired,
    Expression<int>? createdAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userScopeId != null) 'user_scope_id': userScopeId,
      if (packageId != null) 'package_id': packageId,
      if (assetId != null) 'asset_id': assetId,
      if (assetRevision != null) 'asset_revision': assetRevision,
      if (isRequired != null) 'is_required': isRequired,
      if (createdAtEpochMs != null) 'created_at_epoch_ms': createdAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DwOfflinePackageAssetsCompanion copyWith({
    Value<String>? userScopeId,
    Value<String>? packageId,
    Value<String>? assetId,
    Value<String>? assetRevision,
    Value<bool>? isRequired,
    Value<int>? createdAtEpochMs,
    Value<int>? rowid,
  }) {
    return DwOfflinePackageAssetsCompanion(
      userScopeId: userScopeId ?? this.userScopeId,
      packageId: packageId ?? this.packageId,
      assetId: assetId ?? this.assetId,
      assetRevision: assetRevision ?? this.assetRevision,
      isRequired: isRequired ?? this.isRequired,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userScopeId.present) {
      map['user_scope_id'] = Variable<String>(userScopeId.value);
    }
    if (packageId.present) {
      map['package_id'] = Variable<String>(packageId.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (assetRevision.present) {
      map['asset_revision'] = Variable<String>(assetRevision.value);
    }
    if (isRequired.present) {
      map['is_required'] = Variable<bool>(isRequired.value);
    }
    if (createdAtEpochMs.present) {
      map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflinePackageAssetsCompanion(')
          ..write('userScopeId: $userScopeId, ')
          ..write('packageId: $packageId, ')
          ..write('assetId: $assetId, ')
          ..write('assetRevision: $assetRevision, ')
          ..write('isRequired: $isRequired, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DwOfflineJobsTable extends DwOfflineJobs
    with TableInfo<$DwOfflineJobsTable, DwOfflineJobRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DwOfflineJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userScopeIdMeta = const VerificationMeta(
    'userScopeId',
  );
  @override
  late final GeneratedColumn<String> userScopeId = GeneratedColumn<String>(
    'user_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(trim(user_scope_id)) > 0)',
  );
  static const VerificationMeta _jobIdMeta = const VerificationMeta('jobId');
  @override
  late final GeneratedColumn<String> jobId = GeneratedColumn<String>(
    'job_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packageIdMeta = const VerificationMeta(
    'packageId',
  );
  @override
  late final GeneratedColumn<String> packageId = GeneratedColumn<String>(
    'package_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _jobTypeMeta = const VerificationMeta(
    'jobType',
  );
  @override
  late final GeneratedColumn<String> jobType = GeneratedColumn<String>(
    'job_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jobStateMeta = const VerificationMeta(
    'jobState',
  );
  @override
  late final GeneratedColumn<String> jobState = GeneratedColumn<String>(
    'job_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _manifestRevisionMeta = const VerificationMeta(
    'manifestRevision',
  );
  @override
  late final GeneratedColumn<String> manifestRevision = GeneratedColumn<String>(
    'manifest_revision',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _manifestDigestMeta = const VerificationMeta(
    'manifestDigest',
  );
  @override
  late final GeneratedColumn<String> manifestDigest = GeneratedColumn<String>(
    'manifest_digest',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (priority >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _packageTotalBytesMeta = const VerificationMeta(
    'packageTotalBytes',
  );
  @override
  late final GeneratedColumn<int> packageTotalBytes = GeneratedColumn<int>(
    'package_total_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints:
        'CHECK (package_total_bytes IS NULL OR package_total_bytes >= 0)',
  );
  static const VerificationMeta _consentedManifestDigestMeta =
      const VerificationMeta('consentedManifestDigest');
  @override
  late final GeneratedColumn<String> consentedManifestDigest =
      GeneratedColumn<String>(
        'consented_manifest_digest',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _nextEligibleAtEpochMsMeta =
      const VerificationMeta('nextEligibleAtEpochMs');
  @override
  late final GeneratedColumn<int> nextEligibleAtEpochMs = GeneratedColumn<int>(
    'next_eligible_at_epoch_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pauseReasonMeta = const VerificationMeta(
    'pauseReason',
  );
  @override
  late final GeneratedColumn<String> pauseReason = GeneratedColumn<String>(
    'pause_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (attempt_count >= 0)',
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastErrorJsonMeta = const VerificationMeta(
    'lastErrorJson',
  );
  @override
  late final GeneratedColumn<String> lastErrorJson = GeneratedColumn<String>(
    'last_error_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtEpochMsMeta = const VerificationMeta(
    'createdAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> createdAtEpochMs = GeneratedColumn<int>(
    'created_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtEpochMsMeta = const VerificationMeta(
    'updatedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtEpochMs = GeneratedColumn<int>(
    'updated_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userScopeId,
    jobId,
    packageId,
    jobType,
    jobState,
    manifestRevision,
    manifestDigest,
    priority,
    packageTotalBytes,
    consentedManifestDigest,
    nextEligibleAtEpochMs,
    pauseReason,
    attemptCount,
    payloadJson,
    lastErrorJson,
    createdAtEpochMs,
    updatedAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dw_offline_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<DwOfflineJobRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_scope_id')) {
      context.handle(
        _userScopeIdMeta,
        userScopeId.isAcceptableOrUnknown(
          data['user_scope_id']!,
          _userScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_userScopeIdMeta);
    }
    if (data.containsKey('job_id')) {
      context.handle(
        _jobIdMeta,
        jobId.isAcceptableOrUnknown(data['job_id']!, _jobIdMeta),
      );
    } else if (isInserting) {
      context.missing(_jobIdMeta);
    }
    if (data.containsKey('package_id')) {
      context.handle(
        _packageIdMeta,
        packageId.isAcceptableOrUnknown(data['package_id']!, _packageIdMeta),
      );
    }
    if (data.containsKey('job_type')) {
      context.handle(
        _jobTypeMeta,
        jobType.isAcceptableOrUnknown(data['job_type']!, _jobTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_jobTypeMeta);
    }
    if (data.containsKey('job_state')) {
      context.handle(
        _jobStateMeta,
        jobState.isAcceptableOrUnknown(data['job_state']!, _jobStateMeta),
      );
    } else if (isInserting) {
      context.missing(_jobStateMeta);
    }
    if (data.containsKey('manifest_revision')) {
      context.handle(
        _manifestRevisionMeta,
        manifestRevision.isAcceptableOrUnknown(
          data['manifest_revision']!,
          _manifestRevisionMeta,
        ),
      );
    }
    if (data.containsKey('manifest_digest')) {
      context.handle(
        _manifestDigestMeta,
        manifestDigest.isAcceptableOrUnknown(
          data['manifest_digest']!,
          _manifestDigestMeta,
        ),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('package_total_bytes')) {
      context.handle(
        _packageTotalBytesMeta,
        packageTotalBytes.isAcceptableOrUnknown(
          data['package_total_bytes']!,
          _packageTotalBytesMeta,
        ),
      );
    }
    if (data.containsKey('consented_manifest_digest')) {
      context.handle(
        _consentedManifestDigestMeta,
        consentedManifestDigest.isAcceptableOrUnknown(
          data['consented_manifest_digest']!,
          _consentedManifestDigestMeta,
        ),
      );
    }
    if (data.containsKey('next_eligible_at_epoch_ms')) {
      context.handle(
        _nextEligibleAtEpochMsMeta,
        nextEligibleAtEpochMs.isAcceptableOrUnknown(
          data['next_eligible_at_epoch_ms']!,
          _nextEligibleAtEpochMsMeta,
        ),
      );
    }
    if (data.containsKey('pause_reason')) {
      context.handle(
        _pauseReasonMeta,
        pauseReason.isAcceptableOrUnknown(
          data['pause_reason']!,
          _pauseReasonMeta,
        ),
      );
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attemptCountMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('last_error_json')) {
      context.handle(
        _lastErrorJsonMeta,
        lastErrorJson.isAcceptableOrUnknown(
          data['last_error_json']!,
          _lastErrorJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at_epoch_ms')) {
      context.handle(
        _createdAtEpochMsMeta,
        createdAtEpochMs.isAcceptableOrUnknown(
          data['created_at_epoch_ms']!,
          _createdAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMsMeta);
    }
    if (data.containsKey('updated_at_epoch_ms')) {
      context.handle(
        _updatedAtEpochMsMeta,
        updatedAtEpochMs.isAcceptableOrUnknown(
          data['updated_at_epoch_ms']!,
          _updatedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userScopeId, jobId};
  @override
  DwOfflineJobRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DwOfflineJobRow(
      userScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_scope_id'],
      )!,
      jobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_id'],
      )!,
      packageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_id'],
      ),
      jobType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_type'],
      )!,
      jobState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_state'],
      )!,
      manifestRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest_revision'],
      ),
      manifestDigest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest_digest'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      packageTotalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}package_total_bytes'],
      ),
      consentedManifestDigest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}consented_manifest_digest'],
      ),
      nextEligibleAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_eligible_at_epoch_ms'],
      ),
      pauseReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pause_reason'],
      ),
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      lastErrorJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_json'],
      ),
      createdAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_epoch_ms'],
      )!,
      updatedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_epoch_ms'],
      )!,
    );
  }

  @override
  $DwOfflineJobsTable createAlias(String alias) {
    return $DwOfflineJobsTable(attachedDatabase, alias);
  }
}

class DwOfflineJobRow extends DataClass implements Insertable<DwOfflineJobRow> {
  final String userScopeId;
  final String jobId;
  final String? packageId;
  final String jobType;
  final String jobState;
  final String? manifestRevision;
  final String? manifestDigest;
  final int priority;
  final int? packageTotalBytes;
  final String? consentedManifestDigest;
  final int? nextEligibleAtEpochMs;
  final String? pauseReason;
  final int attemptCount;
  final String payloadJson;
  final String? lastErrorJson;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  const DwOfflineJobRow({
    required this.userScopeId,
    required this.jobId,
    this.packageId,
    required this.jobType,
    required this.jobState,
    this.manifestRevision,
    this.manifestDigest,
    required this.priority,
    this.packageTotalBytes,
    this.consentedManifestDigest,
    this.nextEligibleAtEpochMs,
    this.pauseReason,
    required this.attemptCount,
    required this.payloadJson,
    this.lastErrorJson,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_scope_id'] = Variable<String>(userScopeId);
    map['job_id'] = Variable<String>(jobId);
    if (!nullToAbsent || packageId != null) {
      map['package_id'] = Variable<String>(packageId);
    }
    map['job_type'] = Variable<String>(jobType);
    map['job_state'] = Variable<String>(jobState);
    if (!nullToAbsent || manifestRevision != null) {
      map['manifest_revision'] = Variable<String>(manifestRevision);
    }
    if (!nullToAbsent || manifestDigest != null) {
      map['manifest_digest'] = Variable<String>(manifestDigest);
    }
    map['priority'] = Variable<int>(priority);
    if (!nullToAbsent || packageTotalBytes != null) {
      map['package_total_bytes'] = Variable<int>(packageTotalBytes);
    }
    if (!nullToAbsent || consentedManifestDigest != null) {
      map['consented_manifest_digest'] = Variable<String>(
        consentedManifestDigest,
      );
    }
    if (!nullToAbsent || nextEligibleAtEpochMs != null) {
      map['next_eligible_at_epoch_ms'] = Variable<int>(nextEligibleAtEpochMs);
    }
    if (!nullToAbsent || pauseReason != null) {
      map['pause_reason'] = Variable<String>(pauseReason);
    }
    map['attempt_count'] = Variable<int>(attemptCount);
    map['payload_json'] = Variable<String>(payloadJson);
    if (!nullToAbsent || lastErrorJson != null) {
      map['last_error_json'] = Variable<String>(lastErrorJson);
    }
    map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs);
    map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs);
    return map;
  }

  DwOfflineJobsCompanion toCompanion(bool nullToAbsent) {
    return DwOfflineJobsCompanion(
      userScopeId: Value(userScopeId),
      jobId: Value(jobId),
      packageId: packageId == null && nullToAbsent
          ? const Value.absent()
          : Value(packageId),
      jobType: Value(jobType),
      jobState: Value(jobState),
      manifestRevision: manifestRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(manifestRevision),
      manifestDigest: manifestDigest == null && nullToAbsent
          ? const Value.absent()
          : Value(manifestDigest),
      priority: Value(priority),
      packageTotalBytes: packageTotalBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(packageTotalBytes),
      consentedManifestDigest: consentedManifestDigest == null && nullToAbsent
          ? const Value.absent()
          : Value(consentedManifestDigest),
      nextEligibleAtEpochMs: nextEligibleAtEpochMs == null && nullToAbsent
          ? const Value.absent()
          : Value(nextEligibleAtEpochMs),
      pauseReason: pauseReason == null && nullToAbsent
          ? const Value.absent()
          : Value(pauseReason),
      attemptCount: Value(attemptCount),
      payloadJson: Value(payloadJson),
      lastErrorJson: lastErrorJson == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorJson),
      createdAtEpochMs: Value(createdAtEpochMs),
      updatedAtEpochMs: Value(updatedAtEpochMs),
    );
  }

  factory DwOfflineJobRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DwOfflineJobRow(
      userScopeId: serializer.fromJson<String>(json['userScopeId']),
      jobId: serializer.fromJson<String>(json['jobId']),
      packageId: serializer.fromJson<String?>(json['packageId']),
      jobType: serializer.fromJson<String>(json['jobType']),
      jobState: serializer.fromJson<String>(json['jobState']),
      manifestRevision: serializer.fromJson<String?>(json['manifestRevision']),
      manifestDigest: serializer.fromJson<String?>(json['manifestDigest']),
      priority: serializer.fromJson<int>(json['priority']),
      packageTotalBytes: serializer.fromJson<int?>(json['packageTotalBytes']),
      consentedManifestDigest: serializer.fromJson<String?>(
        json['consentedManifestDigest'],
      ),
      nextEligibleAtEpochMs: serializer.fromJson<int?>(
        json['nextEligibleAtEpochMs'],
      ),
      pauseReason: serializer.fromJson<String?>(json['pauseReason']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      lastErrorJson: serializer.fromJson<String?>(json['lastErrorJson']),
      createdAtEpochMs: serializer.fromJson<int>(json['createdAtEpochMs']),
      updatedAtEpochMs: serializer.fromJson<int>(json['updatedAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userScopeId': serializer.toJson<String>(userScopeId),
      'jobId': serializer.toJson<String>(jobId),
      'packageId': serializer.toJson<String?>(packageId),
      'jobType': serializer.toJson<String>(jobType),
      'jobState': serializer.toJson<String>(jobState),
      'manifestRevision': serializer.toJson<String?>(manifestRevision),
      'manifestDigest': serializer.toJson<String?>(manifestDigest),
      'priority': serializer.toJson<int>(priority),
      'packageTotalBytes': serializer.toJson<int?>(packageTotalBytes),
      'consentedManifestDigest': serializer.toJson<String?>(
        consentedManifestDigest,
      ),
      'nextEligibleAtEpochMs': serializer.toJson<int?>(nextEligibleAtEpochMs),
      'pauseReason': serializer.toJson<String?>(pauseReason),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'lastErrorJson': serializer.toJson<String?>(lastErrorJson),
      'createdAtEpochMs': serializer.toJson<int>(createdAtEpochMs),
      'updatedAtEpochMs': serializer.toJson<int>(updatedAtEpochMs),
    };
  }

  DwOfflineJobRow copyWith({
    String? userScopeId,
    String? jobId,
    Value<String?> packageId = const Value.absent(),
    String? jobType,
    String? jobState,
    Value<String?> manifestRevision = const Value.absent(),
    Value<String?> manifestDigest = const Value.absent(),
    int? priority,
    Value<int?> packageTotalBytes = const Value.absent(),
    Value<String?> consentedManifestDigest = const Value.absent(),
    Value<int?> nextEligibleAtEpochMs = const Value.absent(),
    Value<String?> pauseReason = const Value.absent(),
    int? attemptCount,
    String? payloadJson,
    Value<String?> lastErrorJson = const Value.absent(),
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
  }) => DwOfflineJobRow(
    userScopeId: userScopeId ?? this.userScopeId,
    jobId: jobId ?? this.jobId,
    packageId: packageId.present ? packageId.value : this.packageId,
    jobType: jobType ?? this.jobType,
    jobState: jobState ?? this.jobState,
    manifestRevision: manifestRevision.present
        ? manifestRevision.value
        : this.manifestRevision,
    manifestDigest: manifestDigest.present
        ? manifestDigest.value
        : this.manifestDigest,
    priority: priority ?? this.priority,
    packageTotalBytes: packageTotalBytes.present
        ? packageTotalBytes.value
        : this.packageTotalBytes,
    consentedManifestDigest: consentedManifestDigest.present
        ? consentedManifestDigest.value
        : this.consentedManifestDigest,
    nextEligibleAtEpochMs: nextEligibleAtEpochMs.present
        ? nextEligibleAtEpochMs.value
        : this.nextEligibleAtEpochMs,
    pauseReason: pauseReason.present ? pauseReason.value : this.pauseReason,
    attemptCount: attemptCount ?? this.attemptCount,
    payloadJson: payloadJson ?? this.payloadJson,
    lastErrorJson: lastErrorJson.present
        ? lastErrorJson.value
        : this.lastErrorJson,
    createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
    updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
  );
  DwOfflineJobRow copyWithCompanion(DwOfflineJobsCompanion data) {
    return DwOfflineJobRow(
      userScopeId: data.userScopeId.present
          ? data.userScopeId.value
          : this.userScopeId,
      jobId: data.jobId.present ? data.jobId.value : this.jobId,
      packageId: data.packageId.present ? data.packageId.value : this.packageId,
      jobType: data.jobType.present ? data.jobType.value : this.jobType,
      jobState: data.jobState.present ? data.jobState.value : this.jobState,
      manifestRevision: data.manifestRevision.present
          ? data.manifestRevision.value
          : this.manifestRevision,
      manifestDigest: data.manifestDigest.present
          ? data.manifestDigest.value
          : this.manifestDigest,
      priority: data.priority.present ? data.priority.value : this.priority,
      packageTotalBytes: data.packageTotalBytes.present
          ? data.packageTotalBytes.value
          : this.packageTotalBytes,
      consentedManifestDigest: data.consentedManifestDigest.present
          ? data.consentedManifestDigest.value
          : this.consentedManifestDigest,
      nextEligibleAtEpochMs: data.nextEligibleAtEpochMs.present
          ? data.nextEligibleAtEpochMs.value
          : this.nextEligibleAtEpochMs,
      pauseReason: data.pauseReason.present
          ? data.pauseReason.value
          : this.pauseReason,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      lastErrorJson: data.lastErrorJson.present
          ? data.lastErrorJson.value
          : this.lastErrorJson,
      createdAtEpochMs: data.createdAtEpochMs.present
          ? data.createdAtEpochMs.value
          : this.createdAtEpochMs,
      updatedAtEpochMs: data.updatedAtEpochMs.present
          ? data.updatedAtEpochMs.value
          : this.updatedAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflineJobRow(')
          ..write('userScopeId: $userScopeId, ')
          ..write('jobId: $jobId, ')
          ..write('packageId: $packageId, ')
          ..write('jobType: $jobType, ')
          ..write('jobState: $jobState, ')
          ..write('manifestRevision: $manifestRevision, ')
          ..write('manifestDigest: $manifestDigest, ')
          ..write('priority: $priority, ')
          ..write('packageTotalBytes: $packageTotalBytes, ')
          ..write('consentedManifestDigest: $consentedManifestDigest, ')
          ..write('nextEligibleAtEpochMs: $nextEligibleAtEpochMs, ')
          ..write('pauseReason: $pauseReason, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('lastErrorJson: $lastErrorJson, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userScopeId,
    jobId,
    packageId,
    jobType,
    jobState,
    manifestRevision,
    manifestDigest,
    priority,
    packageTotalBytes,
    consentedManifestDigest,
    nextEligibleAtEpochMs,
    pauseReason,
    attemptCount,
    payloadJson,
    lastErrorJson,
    createdAtEpochMs,
    updatedAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DwOfflineJobRow &&
          other.userScopeId == this.userScopeId &&
          other.jobId == this.jobId &&
          other.packageId == this.packageId &&
          other.jobType == this.jobType &&
          other.jobState == this.jobState &&
          other.manifestRevision == this.manifestRevision &&
          other.manifestDigest == this.manifestDigest &&
          other.priority == this.priority &&
          other.packageTotalBytes == this.packageTotalBytes &&
          other.consentedManifestDigest == this.consentedManifestDigest &&
          other.nextEligibleAtEpochMs == this.nextEligibleAtEpochMs &&
          other.pauseReason == this.pauseReason &&
          other.attemptCount == this.attemptCount &&
          other.payloadJson == this.payloadJson &&
          other.lastErrorJson == this.lastErrorJson &&
          other.createdAtEpochMs == this.createdAtEpochMs &&
          other.updatedAtEpochMs == this.updatedAtEpochMs);
}

class DwOfflineJobsCompanion extends UpdateCompanion<DwOfflineJobRow> {
  final Value<String> userScopeId;
  final Value<String> jobId;
  final Value<String?> packageId;
  final Value<String> jobType;
  final Value<String> jobState;
  final Value<String?> manifestRevision;
  final Value<String?> manifestDigest;
  final Value<int> priority;
  final Value<int?> packageTotalBytes;
  final Value<String?> consentedManifestDigest;
  final Value<int?> nextEligibleAtEpochMs;
  final Value<String?> pauseReason;
  final Value<int> attemptCount;
  final Value<String> payloadJson;
  final Value<String?> lastErrorJson;
  final Value<int> createdAtEpochMs;
  final Value<int> updatedAtEpochMs;
  final Value<int> rowid;
  const DwOfflineJobsCompanion({
    this.userScopeId = const Value.absent(),
    this.jobId = const Value.absent(),
    this.packageId = const Value.absent(),
    this.jobType = const Value.absent(),
    this.jobState = const Value.absent(),
    this.manifestRevision = const Value.absent(),
    this.manifestDigest = const Value.absent(),
    this.priority = const Value.absent(),
    this.packageTotalBytes = const Value.absent(),
    this.consentedManifestDigest = const Value.absent(),
    this.nextEligibleAtEpochMs = const Value.absent(),
    this.pauseReason = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.lastErrorJson = const Value.absent(),
    this.createdAtEpochMs = const Value.absent(),
    this.updatedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DwOfflineJobsCompanion.insert({
    required String userScopeId,
    required String jobId,
    this.packageId = const Value.absent(),
    required String jobType,
    required String jobState,
    this.manifestRevision = const Value.absent(),
    this.manifestDigest = const Value.absent(),
    this.priority = const Value.absent(),
    this.packageTotalBytes = const Value.absent(),
    this.consentedManifestDigest = const Value.absent(),
    this.nextEligibleAtEpochMs = const Value.absent(),
    this.pauseReason = const Value.absent(),
    required int attemptCount,
    required String payloadJson,
    this.lastErrorJson = const Value.absent(),
    required int createdAtEpochMs,
    required int updatedAtEpochMs,
    this.rowid = const Value.absent(),
  }) : userScopeId = Value(userScopeId),
       jobId = Value(jobId),
       jobType = Value(jobType),
       jobState = Value(jobState),
       attemptCount = Value(attemptCount),
       payloadJson = Value(payloadJson),
       createdAtEpochMs = Value(createdAtEpochMs),
       updatedAtEpochMs = Value(updatedAtEpochMs);
  static Insertable<DwOfflineJobRow> custom({
    Expression<String>? userScopeId,
    Expression<String>? jobId,
    Expression<String>? packageId,
    Expression<String>? jobType,
    Expression<String>? jobState,
    Expression<String>? manifestRevision,
    Expression<String>? manifestDigest,
    Expression<int>? priority,
    Expression<int>? packageTotalBytes,
    Expression<String>? consentedManifestDigest,
    Expression<int>? nextEligibleAtEpochMs,
    Expression<String>? pauseReason,
    Expression<int>? attemptCount,
    Expression<String>? payloadJson,
    Expression<String>? lastErrorJson,
    Expression<int>? createdAtEpochMs,
    Expression<int>? updatedAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userScopeId != null) 'user_scope_id': userScopeId,
      if (jobId != null) 'job_id': jobId,
      if (packageId != null) 'package_id': packageId,
      if (jobType != null) 'job_type': jobType,
      if (jobState != null) 'job_state': jobState,
      if (manifestRevision != null) 'manifest_revision': manifestRevision,
      if (manifestDigest != null) 'manifest_digest': manifestDigest,
      if (priority != null) 'priority': priority,
      if (packageTotalBytes != null) 'package_total_bytes': packageTotalBytes,
      if (consentedManifestDigest != null)
        'consented_manifest_digest': consentedManifestDigest,
      if (nextEligibleAtEpochMs != null)
        'next_eligible_at_epoch_ms': nextEligibleAtEpochMs,
      if (pauseReason != null) 'pause_reason': pauseReason,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (lastErrorJson != null) 'last_error_json': lastErrorJson,
      if (createdAtEpochMs != null) 'created_at_epoch_ms': createdAtEpochMs,
      if (updatedAtEpochMs != null) 'updated_at_epoch_ms': updatedAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DwOfflineJobsCompanion copyWith({
    Value<String>? userScopeId,
    Value<String>? jobId,
    Value<String?>? packageId,
    Value<String>? jobType,
    Value<String>? jobState,
    Value<String?>? manifestRevision,
    Value<String?>? manifestDigest,
    Value<int>? priority,
    Value<int?>? packageTotalBytes,
    Value<String?>? consentedManifestDigest,
    Value<int?>? nextEligibleAtEpochMs,
    Value<String?>? pauseReason,
    Value<int>? attemptCount,
    Value<String>? payloadJson,
    Value<String?>? lastErrorJson,
    Value<int>? createdAtEpochMs,
    Value<int>? updatedAtEpochMs,
    Value<int>? rowid,
  }) {
    return DwOfflineJobsCompanion(
      userScopeId: userScopeId ?? this.userScopeId,
      jobId: jobId ?? this.jobId,
      packageId: packageId ?? this.packageId,
      jobType: jobType ?? this.jobType,
      jobState: jobState ?? this.jobState,
      manifestRevision: manifestRevision ?? this.manifestRevision,
      manifestDigest: manifestDigest ?? this.manifestDigest,
      priority: priority ?? this.priority,
      packageTotalBytes: packageTotalBytes ?? this.packageTotalBytes,
      consentedManifestDigest:
          consentedManifestDigest ?? this.consentedManifestDigest,
      nextEligibleAtEpochMs:
          nextEligibleAtEpochMs ?? this.nextEligibleAtEpochMs,
      pauseReason: pauseReason ?? this.pauseReason,
      attemptCount: attemptCount ?? this.attemptCount,
      payloadJson: payloadJson ?? this.payloadJson,
      lastErrorJson: lastErrorJson ?? this.lastErrorJson,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userScopeId.present) {
      map['user_scope_id'] = Variable<String>(userScopeId.value);
    }
    if (jobId.present) {
      map['job_id'] = Variable<String>(jobId.value);
    }
    if (packageId.present) {
      map['package_id'] = Variable<String>(packageId.value);
    }
    if (jobType.present) {
      map['job_type'] = Variable<String>(jobType.value);
    }
    if (jobState.present) {
      map['job_state'] = Variable<String>(jobState.value);
    }
    if (manifestRevision.present) {
      map['manifest_revision'] = Variable<String>(manifestRevision.value);
    }
    if (manifestDigest.present) {
      map['manifest_digest'] = Variable<String>(manifestDigest.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (packageTotalBytes.present) {
      map['package_total_bytes'] = Variable<int>(packageTotalBytes.value);
    }
    if (consentedManifestDigest.present) {
      map['consented_manifest_digest'] = Variable<String>(
        consentedManifestDigest.value,
      );
    }
    if (nextEligibleAtEpochMs.present) {
      map['next_eligible_at_epoch_ms'] = Variable<int>(
        nextEligibleAtEpochMs.value,
      );
    }
    if (pauseReason.present) {
      map['pause_reason'] = Variable<String>(pauseReason.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (lastErrorJson.present) {
      map['last_error_json'] = Variable<String>(lastErrorJson.value);
    }
    if (createdAtEpochMs.present) {
      map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs.value);
    }
    if (updatedAtEpochMs.present) {
      map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflineJobsCompanion(')
          ..write('userScopeId: $userScopeId, ')
          ..write('jobId: $jobId, ')
          ..write('packageId: $packageId, ')
          ..write('jobType: $jobType, ')
          ..write('jobState: $jobState, ')
          ..write('manifestRevision: $manifestRevision, ')
          ..write('manifestDigest: $manifestDigest, ')
          ..write('priority: $priority, ')
          ..write('packageTotalBytes: $packageTotalBytes, ')
          ..write('consentedManifestDigest: $consentedManifestDigest, ')
          ..write('nextEligibleAtEpochMs: $nextEligibleAtEpochMs, ')
          ..write('pauseReason: $pauseReason, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('lastErrorJson: $lastErrorJson, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DwOfflineDownloadTasksTable extends DwOfflineDownloadTasks
    with TableInfo<$DwOfflineDownloadTasksTable, DwOfflineDownloadTaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DwOfflineDownloadTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userScopeIdMeta = const VerificationMeta(
    'userScopeId',
  );
  @override
  late final GeneratedColumn<String> userScopeId = GeneratedColumn<String>(
    'user_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(trim(user_scope_id)) > 0)',
  );
  static const VerificationMeta _jobIdMeta = const VerificationMeta('jobId');
  @override
  late final GeneratedColumn<String> jobId = GeneratedColumn<String>(
    'job_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetRevisionMeta = const VerificationMeta(
    'assetRevision',
  );
  @override
  late final GeneratedColumn<String> assetRevision = GeneratedColumn<String>(
    'asset_revision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isRequiredMeta = const VerificationMeta(
    'isRequired',
  );
  @override
  late final GeneratedColumn<bool> isRequired = GeneratedColumn<bool>(
    'is_required',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_required" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _taskStateMeta = const VerificationMeta(
    'taskState',
  );
  @override
  late final GeneratedColumn<String> taskState = GeneratedColumn<String>(
    'task_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nativeTaskIdMeta = const VerificationMeta(
    'nativeTaskId',
  );
  @override
  late final GeneratedColumn<String> nativeTaskId = GeneratedColumn<String>(
    'native_task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _temporaryFilePathMeta = const VerificationMeta(
    'temporaryFilePath',
  );
  @override
  late final GeneratedColumn<String> temporaryFilePath =
      GeneratedColumn<String>(
        'temporary_file_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _transferredBytesMeta = const VerificationMeta(
    'transferredBytes',
  );
  @override
  late final GeneratedColumn<int> transferredBytes = GeneratedColumn<int>(
    'transferred_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (transferred_bytes >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (attempt_count >= 0)',
  );
  static const VerificationMeta _nextEligibleAtEpochMsMeta =
      const VerificationMeta('nextEligibleAtEpochMs');
  @override
  late final GeneratedColumn<int> nextEligibleAtEpochMs = GeneratedColumn<int>(
    'next_eligible_at_epoch_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorJsonMeta = const VerificationMeta(
    'lastErrorJson',
  );
  @override
  late final GeneratedColumn<String> lastErrorJson = GeneratedColumn<String>(
    'last_error_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtEpochMsMeta = const VerificationMeta(
    'createdAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> createdAtEpochMs = GeneratedColumn<int>(
    'created_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtEpochMsMeta = const VerificationMeta(
    'updatedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtEpochMs = GeneratedColumn<int>(
    'updated_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userScopeId,
    jobId,
    assetId,
    assetRevision,
    isRequired,
    taskState,
    nativeTaskId,
    temporaryFilePath,
    transferredBytes,
    attemptCount,
    nextEligibleAtEpochMs,
    lastErrorJson,
    createdAtEpochMs,
    updatedAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dw_offline_download_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DwOfflineDownloadTaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_scope_id')) {
      context.handle(
        _userScopeIdMeta,
        userScopeId.isAcceptableOrUnknown(
          data['user_scope_id']!,
          _userScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_userScopeIdMeta);
    }
    if (data.containsKey('job_id')) {
      context.handle(
        _jobIdMeta,
        jobId.isAcceptableOrUnknown(data['job_id']!, _jobIdMeta),
      );
    } else if (isInserting) {
      context.missing(_jobIdMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('asset_revision')) {
      context.handle(
        _assetRevisionMeta,
        assetRevision.isAcceptableOrUnknown(
          data['asset_revision']!,
          _assetRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_assetRevisionMeta);
    }
    if (data.containsKey('is_required')) {
      context.handle(
        _isRequiredMeta,
        isRequired.isAcceptableOrUnknown(data['is_required']!, _isRequiredMeta),
      );
    }
    if (data.containsKey('task_state')) {
      context.handle(
        _taskStateMeta,
        taskState.isAcceptableOrUnknown(data['task_state']!, _taskStateMeta),
      );
    } else if (isInserting) {
      context.missing(_taskStateMeta);
    }
    if (data.containsKey('native_task_id')) {
      context.handle(
        _nativeTaskIdMeta,
        nativeTaskId.isAcceptableOrUnknown(
          data['native_task_id']!,
          _nativeTaskIdMeta,
        ),
      );
    }
    if (data.containsKey('temporary_file_path')) {
      context.handle(
        _temporaryFilePathMeta,
        temporaryFilePath.isAcceptableOrUnknown(
          data['temporary_file_path']!,
          _temporaryFilePathMeta,
        ),
      );
    }
    if (data.containsKey('transferred_bytes')) {
      context.handle(
        _transferredBytesMeta,
        transferredBytes.isAcceptableOrUnknown(
          data['transferred_bytes']!,
          _transferredBytesMeta,
        ),
      );
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attemptCountMeta);
    }
    if (data.containsKey('next_eligible_at_epoch_ms')) {
      context.handle(
        _nextEligibleAtEpochMsMeta,
        nextEligibleAtEpochMs.isAcceptableOrUnknown(
          data['next_eligible_at_epoch_ms']!,
          _nextEligibleAtEpochMsMeta,
        ),
      );
    }
    if (data.containsKey('last_error_json')) {
      context.handle(
        _lastErrorJsonMeta,
        lastErrorJson.isAcceptableOrUnknown(
          data['last_error_json']!,
          _lastErrorJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at_epoch_ms')) {
      context.handle(
        _createdAtEpochMsMeta,
        createdAtEpochMs.isAcceptableOrUnknown(
          data['created_at_epoch_ms']!,
          _createdAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMsMeta);
    }
    if (data.containsKey('updated_at_epoch_ms')) {
      context.handle(
        _updatedAtEpochMsMeta,
        updatedAtEpochMs.isAcceptableOrUnknown(
          data['updated_at_epoch_ms']!,
          _updatedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    userScopeId,
    jobId,
    assetId,
    assetRevision,
  };
  @override
  DwOfflineDownloadTaskRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DwOfflineDownloadTaskRow(
      userScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_scope_id'],
      )!,
      jobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      assetRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_revision'],
      )!,
      isRequired: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_required'],
      )!,
      taskState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_state'],
      )!,
      nativeTaskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}native_task_id'],
      ),
      temporaryFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}temporary_file_path'],
      ),
      transferredBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transferred_bytes'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      nextEligibleAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_eligible_at_epoch_ms'],
      ),
      lastErrorJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_json'],
      ),
      createdAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_epoch_ms'],
      )!,
      updatedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_epoch_ms'],
      )!,
    );
  }

  @override
  $DwOfflineDownloadTasksTable createAlias(String alias) {
    return $DwOfflineDownloadTasksTable(attachedDatabase, alias);
  }
}

class DwOfflineDownloadTaskRow extends DataClass
    implements Insertable<DwOfflineDownloadTaskRow> {
  final String userScopeId;
  final String jobId;
  final String assetId;
  final String assetRevision;
  final bool isRequired;
  final String taskState;
  final String? nativeTaskId;
  final String? temporaryFilePath;
  final int transferredBytes;
  final int attemptCount;
  final int? nextEligibleAtEpochMs;
  final String? lastErrorJson;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  const DwOfflineDownloadTaskRow({
    required this.userScopeId,
    required this.jobId,
    required this.assetId,
    required this.assetRevision,
    required this.isRequired,
    required this.taskState,
    this.nativeTaskId,
    this.temporaryFilePath,
    required this.transferredBytes,
    required this.attemptCount,
    this.nextEligibleAtEpochMs,
    this.lastErrorJson,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_scope_id'] = Variable<String>(userScopeId);
    map['job_id'] = Variable<String>(jobId);
    map['asset_id'] = Variable<String>(assetId);
    map['asset_revision'] = Variable<String>(assetRevision);
    map['is_required'] = Variable<bool>(isRequired);
    map['task_state'] = Variable<String>(taskState);
    if (!nullToAbsent || nativeTaskId != null) {
      map['native_task_id'] = Variable<String>(nativeTaskId);
    }
    if (!nullToAbsent || temporaryFilePath != null) {
      map['temporary_file_path'] = Variable<String>(temporaryFilePath);
    }
    map['transferred_bytes'] = Variable<int>(transferredBytes);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || nextEligibleAtEpochMs != null) {
      map['next_eligible_at_epoch_ms'] = Variable<int>(nextEligibleAtEpochMs);
    }
    if (!nullToAbsent || lastErrorJson != null) {
      map['last_error_json'] = Variable<String>(lastErrorJson);
    }
    map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs);
    map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs);
    return map;
  }

  DwOfflineDownloadTasksCompanion toCompanion(bool nullToAbsent) {
    return DwOfflineDownloadTasksCompanion(
      userScopeId: Value(userScopeId),
      jobId: Value(jobId),
      assetId: Value(assetId),
      assetRevision: Value(assetRevision),
      isRequired: Value(isRequired),
      taskState: Value(taskState),
      nativeTaskId: nativeTaskId == null && nullToAbsent
          ? const Value.absent()
          : Value(nativeTaskId),
      temporaryFilePath: temporaryFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(temporaryFilePath),
      transferredBytes: Value(transferredBytes),
      attemptCount: Value(attemptCount),
      nextEligibleAtEpochMs: nextEligibleAtEpochMs == null && nullToAbsent
          ? const Value.absent()
          : Value(nextEligibleAtEpochMs),
      lastErrorJson: lastErrorJson == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorJson),
      createdAtEpochMs: Value(createdAtEpochMs),
      updatedAtEpochMs: Value(updatedAtEpochMs),
    );
  }

  factory DwOfflineDownloadTaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DwOfflineDownloadTaskRow(
      userScopeId: serializer.fromJson<String>(json['userScopeId']),
      jobId: serializer.fromJson<String>(json['jobId']),
      assetId: serializer.fromJson<String>(json['assetId']),
      assetRevision: serializer.fromJson<String>(json['assetRevision']),
      isRequired: serializer.fromJson<bool>(json['isRequired']),
      taskState: serializer.fromJson<String>(json['taskState']),
      nativeTaskId: serializer.fromJson<String?>(json['nativeTaskId']),
      temporaryFilePath: serializer.fromJson<String?>(
        json['temporaryFilePath'],
      ),
      transferredBytes: serializer.fromJson<int>(json['transferredBytes']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      nextEligibleAtEpochMs: serializer.fromJson<int?>(
        json['nextEligibleAtEpochMs'],
      ),
      lastErrorJson: serializer.fromJson<String?>(json['lastErrorJson']),
      createdAtEpochMs: serializer.fromJson<int>(json['createdAtEpochMs']),
      updatedAtEpochMs: serializer.fromJson<int>(json['updatedAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userScopeId': serializer.toJson<String>(userScopeId),
      'jobId': serializer.toJson<String>(jobId),
      'assetId': serializer.toJson<String>(assetId),
      'assetRevision': serializer.toJson<String>(assetRevision),
      'isRequired': serializer.toJson<bool>(isRequired),
      'taskState': serializer.toJson<String>(taskState),
      'nativeTaskId': serializer.toJson<String?>(nativeTaskId),
      'temporaryFilePath': serializer.toJson<String?>(temporaryFilePath),
      'transferredBytes': serializer.toJson<int>(transferredBytes),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'nextEligibleAtEpochMs': serializer.toJson<int?>(nextEligibleAtEpochMs),
      'lastErrorJson': serializer.toJson<String?>(lastErrorJson),
      'createdAtEpochMs': serializer.toJson<int>(createdAtEpochMs),
      'updatedAtEpochMs': serializer.toJson<int>(updatedAtEpochMs),
    };
  }

  DwOfflineDownloadTaskRow copyWith({
    String? userScopeId,
    String? jobId,
    String? assetId,
    String? assetRevision,
    bool? isRequired,
    String? taskState,
    Value<String?> nativeTaskId = const Value.absent(),
    Value<String?> temporaryFilePath = const Value.absent(),
    int? transferredBytes,
    int? attemptCount,
    Value<int?> nextEligibleAtEpochMs = const Value.absent(),
    Value<String?> lastErrorJson = const Value.absent(),
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
  }) => DwOfflineDownloadTaskRow(
    userScopeId: userScopeId ?? this.userScopeId,
    jobId: jobId ?? this.jobId,
    assetId: assetId ?? this.assetId,
    assetRevision: assetRevision ?? this.assetRevision,
    isRequired: isRequired ?? this.isRequired,
    taskState: taskState ?? this.taskState,
    nativeTaskId: nativeTaskId.present ? nativeTaskId.value : this.nativeTaskId,
    temporaryFilePath: temporaryFilePath.present
        ? temporaryFilePath.value
        : this.temporaryFilePath,
    transferredBytes: transferredBytes ?? this.transferredBytes,
    attemptCount: attemptCount ?? this.attemptCount,
    nextEligibleAtEpochMs: nextEligibleAtEpochMs.present
        ? nextEligibleAtEpochMs.value
        : this.nextEligibleAtEpochMs,
    lastErrorJson: lastErrorJson.present
        ? lastErrorJson.value
        : this.lastErrorJson,
    createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
    updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
  );
  DwOfflineDownloadTaskRow copyWithCompanion(
    DwOfflineDownloadTasksCompanion data,
  ) {
    return DwOfflineDownloadTaskRow(
      userScopeId: data.userScopeId.present
          ? data.userScopeId.value
          : this.userScopeId,
      jobId: data.jobId.present ? data.jobId.value : this.jobId,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      assetRevision: data.assetRevision.present
          ? data.assetRevision.value
          : this.assetRevision,
      isRequired: data.isRequired.present
          ? data.isRequired.value
          : this.isRequired,
      taskState: data.taskState.present ? data.taskState.value : this.taskState,
      nativeTaskId: data.nativeTaskId.present
          ? data.nativeTaskId.value
          : this.nativeTaskId,
      temporaryFilePath: data.temporaryFilePath.present
          ? data.temporaryFilePath.value
          : this.temporaryFilePath,
      transferredBytes: data.transferredBytes.present
          ? data.transferredBytes.value
          : this.transferredBytes,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      nextEligibleAtEpochMs: data.nextEligibleAtEpochMs.present
          ? data.nextEligibleAtEpochMs.value
          : this.nextEligibleAtEpochMs,
      lastErrorJson: data.lastErrorJson.present
          ? data.lastErrorJson.value
          : this.lastErrorJson,
      createdAtEpochMs: data.createdAtEpochMs.present
          ? data.createdAtEpochMs.value
          : this.createdAtEpochMs,
      updatedAtEpochMs: data.updatedAtEpochMs.present
          ? data.updatedAtEpochMs.value
          : this.updatedAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflineDownloadTaskRow(')
          ..write('userScopeId: $userScopeId, ')
          ..write('jobId: $jobId, ')
          ..write('assetId: $assetId, ')
          ..write('assetRevision: $assetRevision, ')
          ..write('isRequired: $isRequired, ')
          ..write('taskState: $taskState, ')
          ..write('nativeTaskId: $nativeTaskId, ')
          ..write('temporaryFilePath: $temporaryFilePath, ')
          ..write('transferredBytes: $transferredBytes, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextEligibleAtEpochMs: $nextEligibleAtEpochMs, ')
          ..write('lastErrorJson: $lastErrorJson, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userScopeId,
    jobId,
    assetId,
    assetRevision,
    isRequired,
    taskState,
    nativeTaskId,
    temporaryFilePath,
    transferredBytes,
    attemptCount,
    nextEligibleAtEpochMs,
    lastErrorJson,
    createdAtEpochMs,
    updatedAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DwOfflineDownloadTaskRow &&
          other.userScopeId == this.userScopeId &&
          other.jobId == this.jobId &&
          other.assetId == this.assetId &&
          other.assetRevision == this.assetRevision &&
          other.isRequired == this.isRequired &&
          other.taskState == this.taskState &&
          other.nativeTaskId == this.nativeTaskId &&
          other.temporaryFilePath == this.temporaryFilePath &&
          other.transferredBytes == this.transferredBytes &&
          other.attemptCount == this.attemptCount &&
          other.nextEligibleAtEpochMs == this.nextEligibleAtEpochMs &&
          other.lastErrorJson == this.lastErrorJson &&
          other.createdAtEpochMs == this.createdAtEpochMs &&
          other.updatedAtEpochMs == this.updatedAtEpochMs);
}

class DwOfflineDownloadTasksCompanion
    extends UpdateCompanion<DwOfflineDownloadTaskRow> {
  final Value<String> userScopeId;
  final Value<String> jobId;
  final Value<String> assetId;
  final Value<String> assetRevision;
  final Value<bool> isRequired;
  final Value<String> taskState;
  final Value<String?> nativeTaskId;
  final Value<String?> temporaryFilePath;
  final Value<int> transferredBytes;
  final Value<int> attemptCount;
  final Value<int?> nextEligibleAtEpochMs;
  final Value<String?> lastErrorJson;
  final Value<int> createdAtEpochMs;
  final Value<int> updatedAtEpochMs;
  final Value<int> rowid;
  const DwOfflineDownloadTasksCompanion({
    this.userScopeId = const Value.absent(),
    this.jobId = const Value.absent(),
    this.assetId = const Value.absent(),
    this.assetRevision = const Value.absent(),
    this.isRequired = const Value.absent(),
    this.taskState = const Value.absent(),
    this.nativeTaskId = const Value.absent(),
    this.temporaryFilePath = const Value.absent(),
    this.transferredBytes = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextEligibleAtEpochMs = const Value.absent(),
    this.lastErrorJson = const Value.absent(),
    this.createdAtEpochMs = const Value.absent(),
    this.updatedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DwOfflineDownloadTasksCompanion.insert({
    required String userScopeId,
    required String jobId,
    required String assetId,
    required String assetRevision,
    this.isRequired = const Value.absent(),
    required String taskState,
    this.nativeTaskId = const Value.absent(),
    this.temporaryFilePath = const Value.absent(),
    this.transferredBytes = const Value.absent(),
    required int attemptCount,
    this.nextEligibleAtEpochMs = const Value.absent(),
    this.lastErrorJson = const Value.absent(),
    required int createdAtEpochMs,
    required int updatedAtEpochMs,
    this.rowid = const Value.absent(),
  }) : userScopeId = Value(userScopeId),
       jobId = Value(jobId),
       assetId = Value(assetId),
       assetRevision = Value(assetRevision),
       taskState = Value(taskState),
       attemptCount = Value(attemptCount),
       createdAtEpochMs = Value(createdAtEpochMs),
       updatedAtEpochMs = Value(updatedAtEpochMs);
  static Insertable<DwOfflineDownloadTaskRow> custom({
    Expression<String>? userScopeId,
    Expression<String>? jobId,
    Expression<String>? assetId,
    Expression<String>? assetRevision,
    Expression<bool>? isRequired,
    Expression<String>? taskState,
    Expression<String>? nativeTaskId,
    Expression<String>? temporaryFilePath,
    Expression<int>? transferredBytes,
    Expression<int>? attemptCount,
    Expression<int>? nextEligibleAtEpochMs,
    Expression<String>? lastErrorJson,
    Expression<int>? createdAtEpochMs,
    Expression<int>? updatedAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userScopeId != null) 'user_scope_id': userScopeId,
      if (jobId != null) 'job_id': jobId,
      if (assetId != null) 'asset_id': assetId,
      if (assetRevision != null) 'asset_revision': assetRevision,
      if (isRequired != null) 'is_required': isRequired,
      if (taskState != null) 'task_state': taskState,
      if (nativeTaskId != null) 'native_task_id': nativeTaskId,
      if (temporaryFilePath != null) 'temporary_file_path': temporaryFilePath,
      if (transferredBytes != null) 'transferred_bytes': transferredBytes,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (nextEligibleAtEpochMs != null)
        'next_eligible_at_epoch_ms': nextEligibleAtEpochMs,
      if (lastErrorJson != null) 'last_error_json': lastErrorJson,
      if (createdAtEpochMs != null) 'created_at_epoch_ms': createdAtEpochMs,
      if (updatedAtEpochMs != null) 'updated_at_epoch_ms': updatedAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DwOfflineDownloadTasksCompanion copyWith({
    Value<String>? userScopeId,
    Value<String>? jobId,
    Value<String>? assetId,
    Value<String>? assetRevision,
    Value<bool>? isRequired,
    Value<String>? taskState,
    Value<String?>? nativeTaskId,
    Value<String?>? temporaryFilePath,
    Value<int>? transferredBytes,
    Value<int>? attemptCount,
    Value<int?>? nextEligibleAtEpochMs,
    Value<String?>? lastErrorJson,
    Value<int>? createdAtEpochMs,
    Value<int>? updatedAtEpochMs,
    Value<int>? rowid,
  }) {
    return DwOfflineDownloadTasksCompanion(
      userScopeId: userScopeId ?? this.userScopeId,
      jobId: jobId ?? this.jobId,
      assetId: assetId ?? this.assetId,
      assetRevision: assetRevision ?? this.assetRevision,
      isRequired: isRequired ?? this.isRequired,
      taskState: taskState ?? this.taskState,
      nativeTaskId: nativeTaskId ?? this.nativeTaskId,
      temporaryFilePath: temporaryFilePath ?? this.temporaryFilePath,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      attemptCount: attemptCount ?? this.attemptCount,
      nextEligibleAtEpochMs:
          nextEligibleAtEpochMs ?? this.nextEligibleAtEpochMs,
      lastErrorJson: lastErrorJson ?? this.lastErrorJson,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userScopeId.present) {
      map['user_scope_id'] = Variable<String>(userScopeId.value);
    }
    if (jobId.present) {
      map['job_id'] = Variable<String>(jobId.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (assetRevision.present) {
      map['asset_revision'] = Variable<String>(assetRevision.value);
    }
    if (isRequired.present) {
      map['is_required'] = Variable<bool>(isRequired.value);
    }
    if (taskState.present) {
      map['task_state'] = Variable<String>(taskState.value);
    }
    if (nativeTaskId.present) {
      map['native_task_id'] = Variable<String>(nativeTaskId.value);
    }
    if (temporaryFilePath.present) {
      map['temporary_file_path'] = Variable<String>(temporaryFilePath.value);
    }
    if (transferredBytes.present) {
      map['transferred_bytes'] = Variable<int>(transferredBytes.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (nextEligibleAtEpochMs.present) {
      map['next_eligible_at_epoch_ms'] = Variable<int>(
        nextEligibleAtEpochMs.value,
      );
    }
    if (lastErrorJson.present) {
      map['last_error_json'] = Variable<String>(lastErrorJson.value);
    }
    if (createdAtEpochMs.present) {
      map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs.value);
    }
    if (updatedAtEpochMs.present) {
      map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflineDownloadTasksCompanion(')
          ..write('userScopeId: $userScopeId, ')
          ..write('jobId: $jobId, ')
          ..write('assetId: $assetId, ')
          ..write('assetRevision: $assetRevision, ')
          ..write('isRequired: $isRequired, ')
          ..write('taskState: $taskState, ')
          ..write('nativeTaskId: $nativeTaskId, ')
          ..write('temporaryFilePath: $temporaryFilePath, ')
          ..write('transferredBytes: $transferredBytes, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextEligibleAtEpochMs: $nextEligibleAtEpochMs, ')
          ..write('lastErrorJson: $lastErrorJson, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DwOfflineSnapshotsTable extends DwOfflineSnapshots
    with TableInfo<$DwOfflineSnapshotsTable, DwOfflineSnapshotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DwOfflineSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userScopeIdMeta = const VerificationMeta(
    'userScopeId',
  );
  @override
  late final GeneratedColumn<String> userScopeId = GeneratedColumn<String>(
    'user_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(trim(user_scope_id)) > 0)',
  );
  static const VerificationMeta _queryKeyMeta = const VerificationMeta(
    'queryKey',
  );
  @override
  late final GeneratedColumn<String> queryKey = GeneratedColumn<String>(
    'query_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _envelopeJsonMeta = const VerificationMeta(
    'envelopeJson',
  );
  @override
  late final GeneratedColumn<String> envelopeJson = GeneratedColumn<String>(
    'envelope_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedAtEpochMsMeta = const VerificationMeta(
    'capturedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> capturedAtEpochMs = GeneratedColumn<int>(
    'captured_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtEpochMsMeta = const VerificationMeta(
    'expiresAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> expiresAtEpochMs = GeneratedColumn<int>(
    'expires_at_epoch_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userScopeId,
    queryKey,
    envelopeJson,
    capturedAtEpochMs,
    expiresAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dw_offline_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<DwOfflineSnapshotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_scope_id')) {
      context.handle(
        _userScopeIdMeta,
        userScopeId.isAcceptableOrUnknown(
          data['user_scope_id']!,
          _userScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_userScopeIdMeta);
    }
    if (data.containsKey('query_key')) {
      context.handle(
        _queryKeyMeta,
        queryKey.isAcceptableOrUnknown(data['query_key']!, _queryKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_queryKeyMeta);
    }
    if (data.containsKey('envelope_json')) {
      context.handle(
        _envelopeJsonMeta,
        envelopeJson.isAcceptableOrUnknown(
          data['envelope_json']!,
          _envelopeJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_envelopeJsonMeta);
    }
    if (data.containsKey('captured_at_epoch_ms')) {
      context.handle(
        _capturedAtEpochMsMeta,
        capturedAtEpochMs.isAcceptableOrUnknown(
          data['captured_at_epoch_ms']!,
          _capturedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capturedAtEpochMsMeta);
    }
    if (data.containsKey('expires_at_epoch_ms')) {
      context.handle(
        _expiresAtEpochMsMeta,
        expiresAtEpochMs.isAcceptableOrUnknown(
          data['expires_at_epoch_ms']!,
          _expiresAtEpochMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userScopeId, queryKey};
  @override
  DwOfflineSnapshotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DwOfflineSnapshotRow(
      userScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_scope_id'],
      )!,
      queryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}query_key'],
      )!,
      envelopeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}envelope_json'],
      )!,
      capturedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_at_epoch_ms'],
      )!,
      expiresAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_at_epoch_ms'],
      ),
    );
  }

  @override
  $DwOfflineSnapshotsTable createAlias(String alias) {
    return $DwOfflineSnapshotsTable(attachedDatabase, alias);
  }
}

class DwOfflineSnapshotRow extends DataClass
    implements Insertable<DwOfflineSnapshotRow> {
  final String userScopeId;
  final String queryKey;
  final String envelopeJson;
  final int capturedAtEpochMs;
  final int? expiresAtEpochMs;
  const DwOfflineSnapshotRow({
    required this.userScopeId,
    required this.queryKey,
    required this.envelopeJson,
    required this.capturedAtEpochMs,
    this.expiresAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_scope_id'] = Variable<String>(userScopeId);
    map['query_key'] = Variable<String>(queryKey);
    map['envelope_json'] = Variable<String>(envelopeJson);
    map['captured_at_epoch_ms'] = Variable<int>(capturedAtEpochMs);
    if (!nullToAbsent || expiresAtEpochMs != null) {
      map['expires_at_epoch_ms'] = Variable<int>(expiresAtEpochMs);
    }
    return map;
  }

  DwOfflineSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return DwOfflineSnapshotsCompanion(
      userScopeId: Value(userScopeId),
      queryKey: Value(queryKey),
      envelopeJson: Value(envelopeJson),
      capturedAtEpochMs: Value(capturedAtEpochMs),
      expiresAtEpochMs: expiresAtEpochMs == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAtEpochMs),
    );
  }

  factory DwOfflineSnapshotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DwOfflineSnapshotRow(
      userScopeId: serializer.fromJson<String>(json['userScopeId']),
      queryKey: serializer.fromJson<String>(json['queryKey']),
      envelopeJson: serializer.fromJson<String>(json['envelopeJson']),
      capturedAtEpochMs: serializer.fromJson<int>(json['capturedAtEpochMs']),
      expiresAtEpochMs: serializer.fromJson<int?>(json['expiresAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userScopeId': serializer.toJson<String>(userScopeId),
      'queryKey': serializer.toJson<String>(queryKey),
      'envelopeJson': serializer.toJson<String>(envelopeJson),
      'capturedAtEpochMs': serializer.toJson<int>(capturedAtEpochMs),
      'expiresAtEpochMs': serializer.toJson<int?>(expiresAtEpochMs),
    };
  }

  DwOfflineSnapshotRow copyWith({
    String? userScopeId,
    String? queryKey,
    String? envelopeJson,
    int? capturedAtEpochMs,
    Value<int?> expiresAtEpochMs = const Value.absent(),
  }) => DwOfflineSnapshotRow(
    userScopeId: userScopeId ?? this.userScopeId,
    queryKey: queryKey ?? this.queryKey,
    envelopeJson: envelopeJson ?? this.envelopeJson,
    capturedAtEpochMs: capturedAtEpochMs ?? this.capturedAtEpochMs,
    expiresAtEpochMs: expiresAtEpochMs.present
        ? expiresAtEpochMs.value
        : this.expiresAtEpochMs,
  );
  DwOfflineSnapshotRow copyWithCompanion(DwOfflineSnapshotsCompanion data) {
    return DwOfflineSnapshotRow(
      userScopeId: data.userScopeId.present
          ? data.userScopeId.value
          : this.userScopeId,
      queryKey: data.queryKey.present ? data.queryKey.value : this.queryKey,
      envelopeJson: data.envelopeJson.present
          ? data.envelopeJson.value
          : this.envelopeJson,
      capturedAtEpochMs: data.capturedAtEpochMs.present
          ? data.capturedAtEpochMs.value
          : this.capturedAtEpochMs,
      expiresAtEpochMs: data.expiresAtEpochMs.present
          ? data.expiresAtEpochMs.value
          : this.expiresAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflineSnapshotRow(')
          ..write('userScopeId: $userScopeId, ')
          ..write('queryKey: $queryKey, ')
          ..write('envelopeJson: $envelopeJson, ')
          ..write('capturedAtEpochMs: $capturedAtEpochMs, ')
          ..write('expiresAtEpochMs: $expiresAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userScopeId,
    queryKey,
    envelopeJson,
    capturedAtEpochMs,
    expiresAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DwOfflineSnapshotRow &&
          other.userScopeId == this.userScopeId &&
          other.queryKey == this.queryKey &&
          other.envelopeJson == this.envelopeJson &&
          other.capturedAtEpochMs == this.capturedAtEpochMs &&
          other.expiresAtEpochMs == this.expiresAtEpochMs);
}

class DwOfflineSnapshotsCompanion
    extends UpdateCompanion<DwOfflineSnapshotRow> {
  final Value<String> userScopeId;
  final Value<String> queryKey;
  final Value<String> envelopeJson;
  final Value<int> capturedAtEpochMs;
  final Value<int?> expiresAtEpochMs;
  final Value<int> rowid;
  const DwOfflineSnapshotsCompanion({
    this.userScopeId = const Value.absent(),
    this.queryKey = const Value.absent(),
    this.envelopeJson = const Value.absent(),
    this.capturedAtEpochMs = const Value.absent(),
    this.expiresAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DwOfflineSnapshotsCompanion.insert({
    required String userScopeId,
    required String queryKey,
    required String envelopeJson,
    required int capturedAtEpochMs,
    this.expiresAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userScopeId = Value(userScopeId),
       queryKey = Value(queryKey),
       envelopeJson = Value(envelopeJson),
       capturedAtEpochMs = Value(capturedAtEpochMs);
  static Insertable<DwOfflineSnapshotRow> custom({
    Expression<String>? userScopeId,
    Expression<String>? queryKey,
    Expression<String>? envelopeJson,
    Expression<int>? capturedAtEpochMs,
    Expression<int>? expiresAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userScopeId != null) 'user_scope_id': userScopeId,
      if (queryKey != null) 'query_key': queryKey,
      if (envelopeJson != null) 'envelope_json': envelopeJson,
      if (capturedAtEpochMs != null) 'captured_at_epoch_ms': capturedAtEpochMs,
      if (expiresAtEpochMs != null) 'expires_at_epoch_ms': expiresAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DwOfflineSnapshotsCompanion copyWith({
    Value<String>? userScopeId,
    Value<String>? queryKey,
    Value<String>? envelopeJson,
    Value<int>? capturedAtEpochMs,
    Value<int?>? expiresAtEpochMs,
    Value<int>? rowid,
  }) {
    return DwOfflineSnapshotsCompanion(
      userScopeId: userScopeId ?? this.userScopeId,
      queryKey: queryKey ?? this.queryKey,
      envelopeJson: envelopeJson ?? this.envelopeJson,
      capturedAtEpochMs: capturedAtEpochMs ?? this.capturedAtEpochMs,
      expiresAtEpochMs: expiresAtEpochMs ?? this.expiresAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userScopeId.present) {
      map['user_scope_id'] = Variable<String>(userScopeId.value);
    }
    if (queryKey.present) {
      map['query_key'] = Variable<String>(queryKey.value);
    }
    if (envelopeJson.present) {
      map['envelope_json'] = Variable<String>(envelopeJson.value);
    }
    if (capturedAtEpochMs.present) {
      map['captured_at_epoch_ms'] = Variable<int>(capturedAtEpochMs.value);
    }
    if (expiresAtEpochMs.present) {
      map['expires_at_epoch_ms'] = Variable<int>(expiresAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflineSnapshotsCompanion(')
          ..write('userScopeId: $userScopeId, ')
          ..write('queryKey: $queryKey, ')
          ..write('envelopeJson: $envelopeJson, ')
          ..write('capturedAtEpochMs: $capturedAtEpochMs, ')
          ..write('expiresAtEpochMs: $expiresAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DwOfflineOutboxTable extends DwOfflineOutbox
    with TableInfo<$DwOfflineOutboxTable, DwOfflineOutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DwOfflineOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userScopeIdMeta = const VerificationMeta(
    'userScopeId',
  );
  @override
  late final GeneratedColumn<String> userScopeId = GeneratedColumn<String>(
    'user_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(trim(user_scope_id)) > 0)',
  );
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  @override
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mutationTypeMeta = const VerificationMeta(
    'mutationType',
  );
  @override
  late final GeneratedColumn<String> mutationType = GeneratedColumn<String>(
    'mutation_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _envelopeJsonMeta = const VerificationMeta(
    'envelopeJson',
  );
  @override
  late final GeneratedColumn<String> envelopeJson = GeneratedColumn<String>(
    'envelope_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtEpochMsMeta = const VerificationMeta(
    'createdAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> createdAtEpochMs = GeneratedColumn<int>(
    'created_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtEpochMsMeta = const VerificationMeta(
    'updatedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtEpochMs = GeneratedColumn<int>(
    'updated_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userScopeId,
    mutationId,
    entityType,
    entityId,
    mutationType,
    idempotencyKey,
    envelopeJson,
    createdAtEpochMs,
    updatedAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dw_offline_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<DwOfflineOutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_scope_id')) {
      context.handle(
        _userScopeIdMeta,
        userScopeId.isAcceptableOrUnknown(
          data['user_scope_id']!,
          _userScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_userScopeIdMeta);
    }
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('mutation_type')) {
      context.handle(
        _mutationTypeMeta,
        mutationType.isAcceptableOrUnknown(
          data['mutation_type']!,
          _mutationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mutationTypeMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('envelope_json')) {
      context.handle(
        _envelopeJsonMeta,
        envelopeJson.isAcceptableOrUnknown(
          data['envelope_json']!,
          _envelopeJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_envelopeJsonMeta);
    }
    if (data.containsKey('created_at_epoch_ms')) {
      context.handle(
        _createdAtEpochMsMeta,
        createdAtEpochMs.isAcceptableOrUnknown(
          data['created_at_epoch_ms']!,
          _createdAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMsMeta);
    }
    if (data.containsKey('updated_at_epoch_ms')) {
      context.handle(
        _updatedAtEpochMsMeta,
        updatedAtEpochMs.isAcceptableOrUnknown(
          data['updated_at_epoch_ms']!,
          _updatedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userScopeId, mutationId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {userScopeId, entityType, entityId},
  ];
  @override
  DwOfflineOutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DwOfflineOutboxRow(
      userScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_scope_id'],
      )!,
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      mutationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_type'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      envelopeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}envelope_json'],
      )!,
      createdAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_epoch_ms'],
      )!,
      updatedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_epoch_ms'],
      )!,
    );
  }

  @override
  $DwOfflineOutboxTable createAlias(String alias) {
    return $DwOfflineOutboxTable(attachedDatabase, alias);
  }
}

class DwOfflineOutboxRow extends DataClass
    implements Insertable<DwOfflineOutboxRow> {
  final String userScopeId;
  final String mutationId;
  final String entityType;
  final String entityId;
  final String mutationType;
  final String idempotencyKey;
  final String envelopeJson;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  const DwOfflineOutboxRow({
    required this.userScopeId,
    required this.mutationId,
    required this.entityType,
    required this.entityId,
    required this.mutationType,
    required this.idempotencyKey,
    required this.envelopeJson,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_scope_id'] = Variable<String>(userScopeId);
    map['mutation_id'] = Variable<String>(mutationId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['mutation_type'] = Variable<String>(mutationType);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['envelope_json'] = Variable<String>(envelopeJson);
    map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs);
    map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs);
    return map;
  }

  DwOfflineOutboxCompanion toCompanion(bool nullToAbsent) {
    return DwOfflineOutboxCompanion(
      userScopeId: Value(userScopeId),
      mutationId: Value(mutationId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      mutationType: Value(mutationType),
      idempotencyKey: Value(idempotencyKey),
      envelopeJson: Value(envelopeJson),
      createdAtEpochMs: Value(createdAtEpochMs),
      updatedAtEpochMs: Value(updatedAtEpochMs),
    );
  }

  factory DwOfflineOutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DwOfflineOutboxRow(
      userScopeId: serializer.fromJson<String>(json['userScopeId']),
      mutationId: serializer.fromJson<String>(json['mutationId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      mutationType: serializer.fromJson<String>(json['mutationType']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      envelopeJson: serializer.fromJson<String>(json['envelopeJson']),
      createdAtEpochMs: serializer.fromJson<int>(json['createdAtEpochMs']),
      updatedAtEpochMs: serializer.fromJson<int>(json['updatedAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userScopeId': serializer.toJson<String>(userScopeId),
      'mutationId': serializer.toJson<String>(mutationId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'mutationType': serializer.toJson<String>(mutationType),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'envelopeJson': serializer.toJson<String>(envelopeJson),
      'createdAtEpochMs': serializer.toJson<int>(createdAtEpochMs),
      'updatedAtEpochMs': serializer.toJson<int>(updatedAtEpochMs),
    };
  }

  DwOfflineOutboxRow copyWith({
    String? userScopeId,
    String? mutationId,
    String? entityType,
    String? entityId,
    String? mutationType,
    String? idempotencyKey,
    String? envelopeJson,
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
  }) => DwOfflineOutboxRow(
    userScopeId: userScopeId ?? this.userScopeId,
    mutationId: mutationId ?? this.mutationId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    mutationType: mutationType ?? this.mutationType,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    envelopeJson: envelopeJson ?? this.envelopeJson,
    createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
    updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
  );
  DwOfflineOutboxRow copyWithCompanion(DwOfflineOutboxCompanion data) {
    return DwOfflineOutboxRow(
      userScopeId: data.userScopeId.present
          ? data.userScopeId.value
          : this.userScopeId,
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      mutationType: data.mutationType.present
          ? data.mutationType.value
          : this.mutationType,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      envelopeJson: data.envelopeJson.present
          ? data.envelopeJson.value
          : this.envelopeJson,
      createdAtEpochMs: data.createdAtEpochMs.present
          ? data.createdAtEpochMs.value
          : this.createdAtEpochMs,
      updatedAtEpochMs: data.updatedAtEpochMs.present
          ? data.updatedAtEpochMs.value
          : this.updatedAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflineOutboxRow(')
          ..write('userScopeId: $userScopeId, ')
          ..write('mutationId: $mutationId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('mutationType: $mutationType, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('envelopeJson: $envelopeJson, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userScopeId,
    mutationId,
    entityType,
    entityId,
    mutationType,
    idempotencyKey,
    envelopeJson,
    createdAtEpochMs,
    updatedAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DwOfflineOutboxRow &&
          other.userScopeId == this.userScopeId &&
          other.mutationId == this.mutationId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.mutationType == this.mutationType &&
          other.idempotencyKey == this.idempotencyKey &&
          other.envelopeJson == this.envelopeJson &&
          other.createdAtEpochMs == this.createdAtEpochMs &&
          other.updatedAtEpochMs == this.updatedAtEpochMs);
}

class DwOfflineOutboxCompanion extends UpdateCompanion<DwOfflineOutboxRow> {
  final Value<String> userScopeId;
  final Value<String> mutationId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> mutationType;
  final Value<String> idempotencyKey;
  final Value<String> envelopeJson;
  final Value<int> createdAtEpochMs;
  final Value<int> updatedAtEpochMs;
  final Value<int> rowid;
  const DwOfflineOutboxCompanion({
    this.userScopeId = const Value.absent(),
    this.mutationId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.mutationType = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.envelopeJson = const Value.absent(),
    this.createdAtEpochMs = const Value.absent(),
    this.updatedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DwOfflineOutboxCompanion.insert({
    required String userScopeId,
    required String mutationId,
    required String entityType,
    required String entityId,
    required String mutationType,
    required String idempotencyKey,
    required String envelopeJson,
    required int createdAtEpochMs,
    required int updatedAtEpochMs,
    this.rowid = const Value.absent(),
  }) : userScopeId = Value(userScopeId),
       mutationId = Value(mutationId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       mutationType = Value(mutationType),
       idempotencyKey = Value(idempotencyKey),
       envelopeJson = Value(envelopeJson),
       createdAtEpochMs = Value(createdAtEpochMs),
       updatedAtEpochMs = Value(updatedAtEpochMs);
  static Insertable<DwOfflineOutboxRow> custom({
    Expression<String>? userScopeId,
    Expression<String>? mutationId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? mutationType,
    Expression<String>? idempotencyKey,
    Expression<String>? envelopeJson,
    Expression<int>? createdAtEpochMs,
    Expression<int>? updatedAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userScopeId != null) 'user_scope_id': userScopeId,
      if (mutationId != null) 'mutation_id': mutationId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (mutationType != null) 'mutation_type': mutationType,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (envelopeJson != null) 'envelope_json': envelopeJson,
      if (createdAtEpochMs != null) 'created_at_epoch_ms': createdAtEpochMs,
      if (updatedAtEpochMs != null) 'updated_at_epoch_ms': updatedAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DwOfflineOutboxCompanion copyWith({
    Value<String>? userScopeId,
    Value<String>? mutationId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? mutationType,
    Value<String>? idempotencyKey,
    Value<String>? envelopeJson,
    Value<int>? createdAtEpochMs,
    Value<int>? updatedAtEpochMs,
    Value<int>? rowid,
  }) {
    return DwOfflineOutboxCompanion(
      userScopeId: userScopeId ?? this.userScopeId,
      mutationId: mutationId ?? this.mutationId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      mutationType: mutationType ?? this.mutationType,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      envelopeJson: envelopeJson ?? this.envelopeJson,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userScopeId.present) {
      map['user_scope_id'] = Variable<String>(userScopeId.value);
    }
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (mutationType.present) {
      map['mutation_type'] = Variable<String>(mutationType.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (envelopeJson.present) {
      map['envelope_json'] = Variable<String>(envelopeJson.value);
    }
    if (createdAtEpochMs.present) {
      map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs.value);
    }
    if (updatedAtEpochMs.present) {
      map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflineOutboxCompanion(')
          ..write('userScopeId: $userScopeId, ')
          ..write('mutationId: $mutationId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('mutationType: $mutationType, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('envelopeJson: $envelopeJson, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DwOfflineManifestsTable extends DwOfflineManifests
    with TableInfo<$DwOfflineManifestsTable, DwOfflineManifestRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DwOfflineManifestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userScopeIdMeta = const VerificationMeta(
    'userScopeId',
  );
  @override
  late final GeneratedColumn<String> userScopeId = GeneratedColumn<String>(
    'user_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packageIdMeta = const VerificationMeta(
    'packageId',
  );
  @override
  late final GeneratedColumn<String> packageId = GeneratedColumn<String>(
    'package_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _manifestRevisionMeta = const VerificationMeta(
    'manifestRevision',
  );
  @override
  late final GeneratedColumn<String> manifestRevision = GeneratedColumn<String>(
    'manifest_revision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadDigestMeta = const VerificationMeta(
    'payloadDigest',
  );
  @override
  late final GeneratedColumn<String> payloadDigest = GeneratedColumn<String>(
    'payload_digest',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _envelopeJsonMeta = const VerificationMeta(
    'envelopeJson',
  );
  @override
  late final GeneratedColumn<String> envelopeJson = GeneratedColumn<String>(
    'envelope_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadBytesMeta = const VerificationMeta(
    'payloadBytes',
  );
  @override
  late final GeneratedColumn<Uint8List> payloadBytes =
      GeneratedColumn<Uint8List>(
        'payload_bytes',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _createdAtEpochMsMeta = const VerificationMeta(
    'createdAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> createdAtEpochMs = GeneratedColumn<int>(
    'created_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userScopeId,
    packageId,
    manifestRevision,
    payloadDigest,
    envelopeJson,
    payloadBytes,
    createdAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dw_offline_manifests';
  @override
  VerificationContext validateIntegrity(
    Insertable<DwOfflineManifestRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_scope_id')) {
      context.handle(
        _userScopeIdMeta,
        userScopeId.isAcceptableOrUnknown(
          data['user_scope_id']!,
          _userScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_userScopeIdMeta);
    }
    if (data.containsKey('package_id')) {
      context.handle(
        _packageIdMeta,
        packageId.isAcceptableOrUnknown(data['package_id']!, _packageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_packageIdMeta);
    }
    if (data.containsKey('manifest_revision')) {
      context.handle(
        _manifestRevisionMeta,
        manifestRevision.isAcceptableOrUnknown(
          data['manifest_revision']!,
          _manifestRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_manifestRevisionMeta);
    }
    if (data.containsKey('payload_digest')) {
      context.handle(
        _payloadDigestMeta,
        payloadDigest.isAcceptableOrUnknown(
          data['payload_digest']!,
          _payloadDigestMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadDigestMeta);
    }
    if (data.containsKey('envelope_json')) {
      context.handle(
        _envelopeJsonMeta,
        envelopeJson.isAcceptableOrUnknown(
          data['envelope_json']!,
          _envelopeJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_envelopeJsonMeta);
    }
    if (data.containsKey('payload_bytes')) {
      context.handle(
        _payloadBytesMeta,
        payloadBytes.isAcceptableOrUnknown(
          data['payload_bytes']!,
          _payloadBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadBytesMeta);
    }
    if (data.containsKey('created_at_epoch_ms')) {
      context.handle(
        _createdAtEpochMsMeta,
        createdAtEpochMs.isAcceptableOrUnknown(
          data['created_at_epoch_ms']!,
          _createdAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    userScopeId,
    packageId,
    manifestRevision,
  };
  @override
  DwOfflineManifestRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DwOfflineManifestRow(
      userScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_scope_id'],
      )!,
      packageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_id'],
      )!,
      manifestRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest_revision'],
      )!,
      payloadDigest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_digest'],
      )!,
      envelopeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}envelope_json'],
      )!,
      payloadBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}payload_bytes'],
      )!,
      createdAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_epoch_ms'],
      )!,
    );
  }

  @override
  $DwOfflineManifestsTable createAlias(String alias) {
    return $DwOfflineManifestsTable(attachedDatabase, alias);
  }
}

class DwOfflineManifestRow extends DataClass
    implements Insertable<DwOfflineManifestRow> {
  final String userScopeId;
  final String packageId;
  final String manifestRevision;
  final String payloadDigest;
  final String envelopeJson;
  final Uint8List payloadBytes;
  final int createdAtEpochMs;
  const DwOfflineManifestRow({
    required this.userScopeId,
    required this.packageId,
    required this.manifestRevision,
    required this.payloadDigest,
    required this.envelopeJson,
    required this.payloadBytes,
    required this.createdAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_scope_id'] = Variable<String>(userScopeId);
    map['package_id'] = Variable<String>(packageId);
    map['manifest_revision'] = Variable<String>(manifestRevision);
    map['payload_digest'] = Variable<String>(payloadDigest);
    map['envelope_json'] = Variable<String>(envelopeJson);
    map['payload_bytes'] = Variable<Uint8List>(payloadBytes);
    map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs);
    return map;
  }

  DwOfflineManifestsCompanion toCompanion(bool nullToAbsent) {
    return DwOfflineManifestsCompanion(
      userScopeId: Value(userScopeId),
      packageId: Value(packageId),
      manifestRevision: Value(manifestRevision),
      payloadDigest: Value(payloadDigest),
      envelopeJson: Value(envelopeJson),
      payloadBytes: Value(payloadBytes),
      createdAtEpochMs: Value(createdAtEpochMs),
    );
  }

  factory DwOfflineManifestRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DwOfflineManifestRow(
      userScopeId: serializer.fromJson<String>(json['userScopeId']),
      packageId: serializer.fromJson<String>(json['packageId']),
      manifestRevision: serializer.fromJson<String>(json['manifestRevision']),
      payloadDigest: serializer.fromJson<String>(json['payloadDigest']),
      envelopeJson: serializer.fromJson<String>(json['envelopeJson']),
      payloadBytes: serializer.fromJson<Uint8List>(json['payloadBytes']),
      createdAtEpochMs: serializer.fromJson<int>(json['createdAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userScopeId': serializer.toJson<String>(userScopeId),
      'packageId': serializer.toJson<String>(packageId),
      'manifestRevision': serializer.toJson<String>(manifestRevision),
      'payloadDigest': serializer.toJson<String>(payloadDigest),
      'envelopeJson': serializer.toJson<String>(envelopeJson),
      'payloadBytes': serializer.toJson<Uint8List>(payloadBytes),
      'createdAtEpochMs': serializer.toJson<int>(createdAtEpochMs),
    };
  }

  DwOfflineManifestRow copyWith({
    String? userScopeId,
    String? packageId,
    String? manifestRevision,
    String? payloadDigest,
    String? envelopeJson,
    Uint8List? payloadBytes,
    int? createdAtEpochMs,
  }) => DwOfflineManifestRow(
    userScopeId: userScopeId ?? this.userScopeId,
    packageId: packageId ?? this.packageId,
    manifestRevision: manifestRevision ?? this.manifestRevision,
    payloadDigest: payloadDigest ?? this.payloadDigest,
    envelopeJson: envelopeJson ?? this.envelopeJson,
    payloadBytes: payloadBytes ?? this.payloadBytes,
    createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
  );
  DwOfflineManifestRow copyWithCompanion(DwOfflineManifestsCompanion data) {
    return DwOfflineManifestRow(
      userScopeId: data.userScopeId.present
          ? data.userScopeId.value
          : this.userScopeId,
      packageId: data.packageId.present ? data.packageId.value : this.packageId,
      manifestRevision: data.manifestRevision.present
          ? data.manifestRevision.value
          : this.manifestRevision,
      payloadDigest: data.payloadDigest.present
          ? data.payloadDigest.value
          : this.payloadDigest,
      envelopeJson: data.envelopeJson.present
          ? data.envelopeJson.value
          : this.envelopeJson,
      payloadBytes: data.payloadBytes.present
          ? data.payloadBytes.value
          : this.payloadBytes,
      createdAtEpochMs: data.createdAtEpochMs.present
          ? data.createdAtEpochMs.value
          : this.createdAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflineManifestRow(')
          ..write('userScopeId: $userScopeId, ')
          ..write('packageId: $packageId, ')
          ..write('manifestRevision: $manifestRevision, ')
          ..write('payloadDigest: $payloadDigest, ')
          ..write('envelopeJson: $envelopeJson, ')
          ..write('payloadBytes: $payloadBytes, ')
          ..write('createdAtEpochMs: $createdAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userScopeId,
    packageId,
    manifestRevision,
    payloadDigest,
    envelopeJson,
    $driftBlobEquality.hash(payloadBytes),
    createdAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DwOfflineManifestRow &&
          other.userScopeId == this.userScopeId &&
          other.packageId == this.packageId &&
          other.manifestRevision == this.manifestRevision &&
          other.payloadDigest == this.payloadDigest &&
          other.envelopeJson == this.envelopeJson &&
          $driftBlobEquality.equals(other.payloadBytes, this.payloadBytes) &&
          other.createdAtEpochMs == this.createdAtEpochMs);
}

class DwOfflineManifestsCompanion
    extends UpdateCompanion<DwOfflineManifestRow> {
  final Value<String> userScopeId;
  final Value<String> packageId;
  final Value<String> manifestRevision;
  final Value<String> payloadDigest;
  final Value<String> envelopeJson;
  final Value<Uint8List> payloadBytes;
  final Value<int> createdAtEpochMs;
  final Value<int> rowid;
  const DwOfflineManifestsCompanion({
    this.userScopeId = const Value.absent(),
    this.packageId = const Value.absent(),
    this.manifestRevision = const Value.absent(),
    this.payloadDigest = const Value.absent(),
    this.envelopeJson = const Value.absent(),
    this.payloadBytes = const Value.absent(),
    this.createdAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DwOfflineManifestsCompanion.insert({
    required String userScopeId,
    required String packageId,
    required String manifestRevision,
    required String payloadDigest,
    required String envelopeJson,
    required Uint8List payloadBytes,
    required int createdAtEpochMs,
    this.rowid = const Value.absent(),
  }) : userScopeId = Value(userScopeId),
       packageId = Value(packageId),
       manifestRevision = Value(manifestRevision),
       payloadDigest = Value(payloadDigest),
       envelopeJson = Value(envelopeJson),
       payloadBytes = Value(payloadBytes),
       createdAtEpochMs = Value(createdAtEpochMs);
  static Insertable<DwOfflineManifestRow> custom({
    Expression<String>? userScopeId,
    Expression<String>? packageId,
    Expression<String>? manifestRevision,
    Expression<String>? payloadDigest,
    Expression<String>? envelopeJson,
    Expression<Uint8List>? payloadBytes,
    Expression<int>? createdAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userScopeId != null) 'user_scope_id': userScopeId,
      if (packageId != null) 'package_id': packageId,
      if (manifestRevision != null) 'manifest_revision': manifestRevision,
      if (payloadDigest != null) 'payload_digest': payloadDigest,
      if (envelopeJson != null) 'envelope_json': envelopeJson,
      if (payloadBytes != null) 'payload_bytes': payloadBytes,
      if (createdAtEpochMs != null) 'created_at_epoch_ms': createdAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DwOfflineManifestsCompanion copyWith({
    Value<String>? userScopeId,
    Value<String>? packageId,
    Value<String>? manifestRevision,
    Value<String>? payloadDigest,
    Value<String>? envelopeJson,
    Value<Uint8List>? payloadBytes,
    Value<int>? createdAtEpochMs,
    Value<int>? rowid,
  }) {
    return DwOfflineManifestsCompanion(
      userScopeId: userScopeId ?? this.userScopeId,
      packageId: packageId ?? this.packageId,
      manifestRevision: manifestRevision ?? this.manifestRevision,
      payloadDigest: payloadDigest ?? this.payloadDigest,
      envelopeJson: envelopeJson ?? this.envelopeJson,
      payloadBytes: payloadBytes ?? this.payloadBytes,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userScopeId.present) {
      map['user_scope_id'] = Variable<String>(userScopeId.value);
    }
    if (packageId.present) {
      map['package_id'] = Variable<String>(packageId.value);
    }
    if (manifestRevision.present) {
      map['manifest_revision'] = Variable<String>(manifestRevision.value);
    }
    if (payloadDigest.present) {
      map['payload_digest'] = Variable<String>(payloadDigest.value);
    }
    if (envelopeJson.present) {
      map['envelope_json'] = Variable<String>(envelopeJson.value);
    }
    if (payloadBytes.present) {
      map['payload_bytes'] = Variable<Uint8List>(payloadBytes.value);
    }
    if (createdAtEpochMs.present) {
      map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflineManifestsCompanion(')
          ..write('userScopeId: $userScopeId, ')
          ..write('packageId: $packageId, ')
          ..write('manifestRevision: $manifestRevision, ')
          ..write('payloadDigest: $payloadDigest, ')
          ..write('envelopeJson: $envelopeJson, ')
          ..write('payloadBytes: $payloadBytes, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DwOfflinePackageSnapshotsTable extends DwOfflinePackageSnapshots
    with
        TableInfo<
          $DwOfflinePackageSnapshotsTable,
          DwOfflinePackageSnapshotRow
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DwOfflinePackageSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userScopeIdMeta = const VerificationMeta(
    'userScopeId',
  );
  @override
  late final GeneratedColumn<String> userScopeId = GeneratedColumn<String>(
    'user_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packageIdMeta = const VerificationMeta(
    'packageId',
  );
  @override
  late final GeneratedColumn<String> packageId = GeneratedColumn<String>(
    'package_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _manifestRevisionMeta = const VerificationMeta(
    'manifestRevision',
  );
  @override
  late final GeneratedColumn<String> manifestRevision = GeneratedColumn<String>(
    'manifest_revision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _queryKeyMeta = const VerificationMeta(
    'queryKey',
  );
  @override
  late final GeneratedColumn<String> queryKey = GeneratedColumn<String>(
    'query_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _envelopeJsonMeta = const VerificationMeta(
    'envelopeJson',
  );
  @override
  late final GeneratedColumn<String> envelopeJson = GeneratedColumn<String>(
    'envelope_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedAtEpochMsMeta = const VerificationMeta(
    'capturedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> capturedAtEpochMs = GeneratedColumn<int>(
    'captured_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userScopeId,
    packageId,
    manifestRevision,
    queryKey,
    envelopeJson,
    capturedAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dw_offline_package_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<DwOfflinePackageSnapshotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_scope_id')) {
      context.handle(
        _userScopeIdMeta,
        userScopeId.isAcceptableOrUnknown(
          data['user_scope_id']!,
          _userScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_userScopeIdMeta);
    }
    if (data.containsKey('package_id')) {
      context.handle(
        _packageIdMeta,
        packageId.isAcceptableOrUnknown(data['package_id']!, _packageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_packageIdMeta);
    }
    if (data.containsKey('manifest_revision')) {
      context.handle(
        _manifestRevisionMeta,
        manifestRevision.isAcceptableOrUnknown(
          data['manifest_revision']!,
          _manifestRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_manifestRevisionMeta);
    }
    if (data.containsKey('query_key')) {
      context.handle(
        _queryKeyMeta,
        queryKey.isAcceptableOrUnknown(data['query_key']!, _queryKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_queryKeyMeta);
    }
    if (data.containsKey('envelope_json')) {
      context.handle(
        _envelopeJsonMeta,
        envelopeJson.isAcceptableOrUnknown(
          data['envelope_json']!,
          _envelopeJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_envelopeJsonMeta);
    }
    if (data.containsKey('captured_at_epoch_ms')) {
      context.handle(
        _capturedAtEpochMsMeta,
        capturedAtEpochMs.isAcceptableOrUnknown(
          data['captured_at_epoch_ms']!,
          _capturedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capturedAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    userScopeId,
    packageId,
    manifestRevision,
    queryKey,
  };
  @override
  DwOfflinePackageSnapshotRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DwOfflinePackageSnapshotRow(
      userScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_scope_id'],
      )!,
      packageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_id'],
      )!,
      manifestRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest_revision'],
      )!,
      queryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}query_key'],
      )!,
      envelopeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}envelope_json'],
      )!,
      capturedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_at_epoch_ms'],
      )!,
    );
  }

  @override
  $DwOfflinePackageSnapshotsTable createAlias(String alias) {
    return $DwOfflinePackageSnapshotsTable(attachedDatabase, alias);
  }
}

class DwOfflinePackageSnapshotRow extends DataClass
    implements Insertable<DwOfflinePackageSnapshotRow> {
  final String userScopeId;
  final String packageId;
  final String manifestRevision;
  final String queryKey;
  final String envelopeJson;
  final int capturedAtEpochMs;
  const DwOfflinePackageSnapshotRow({
    required this.userScopeId,
    required this.packageId,
    required this.manifestRevision,
    required this.queryKey,
    required this.envelopeJson,
    required this.capturedAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_scope_id'] = Variable<String>(userScopeId);
    map['package_id'] = Variable<String>(packageId);
    map['manifest_revision'] = Variable<String>(manifestRevision);
    map['query_key'] = Variable<String>(queryKey);
    map['envelope_json'] = Variable<String>(envelopeJson);
    map['captured_at_epoch_ms'] = Variable<int>(capturedAtEpochMs);
    return map;
  }

  DwOfflinePackageSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return DwOfflinePackageSnapshotsCompanion(
      userScopeId: Value(userScopeId),
      packageId: Value(packageId),
      manifestRevision: Value(manifestRevision),
      queryKey: Value(queryKey),
      envelopeJson: Value(envelopeJson),
      capturedAtEpochMs: Value(capturedAtEpochMs),
    );
  }

  factory DwOfflinePackageSnapshotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DwOfflinePackageSnapshotRow(
      userScopeId: serializer.fromJson<String>(json['userScopeId']),
      packageId: serializer.fromJson<String>(json['packageId']),
      manifestRevision: serializer.fromJson<String>(json['manifestRevision']),
      queryKey: serializer.fromJson<String>(json['queryKey']),
      envelopeJson: serializer.fromJson<String>(json['envelopeJson']),
      capturedAtEpochMs: serializer.fromJson<int>(json['capturedAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userScopeId': serializer.toJson<String>(userScopeId),
      'packageId': serializer.toJson<String>(packageId),
      'manifestRevision': serializer.toJson<String>(manifestRevision),
      'queryKey': serializer.toJson<String>(queryKey),
      'envelopeJson': serializer.toJson<String>(envelopeJson),
      'capturedAtEpochMs': serializer.toJson<int>(capturedAtEpochMs),
    };
  }

  DwOfflinePackageSnapshotRow copyWith({
    String? userScopeId,
    String? packageId,
    String? manifestRevision,
    String? queryKey,
    String? envelopeJson,
    int? capturedAtEpochMs,
  }) => DwOfflinePackageSnapshotRow(
    userScopeId: userScopeId ?? this.userScopeId,
    packageId: packageId ?? this.packageId,
    manifestRevision: manifestRevision ?? this.manifestRevision,
    queryKey: queryKey ?? this.queryKey,
    envelopeJson: envelopeJson ?? this.envelopeJson,
    capturedAtEpochMs: capturedAtEpochMs ?? this.capturedAtEpochMs,
  );
  DwOfflinePackageSnapshotRow copyWithCompanion(
    DwOfflinePackageSnapshotsCompanion data,
  ) {
    return DwOfflinePackageSnapshotRow(
      userScopeId: data.userScopeId.present
          ? data.userScopeId.value
          : this.userScopeId,
      packageId: data.packageId.present ? data.packageId.value : this.packageId,
      manifestRevision: data.manifestRevision.present
          ? data.manifestRevision.value
          : this.manifestRevision,
      queryKey: data.queryKey.present ? data.queryKey.value : this.queryKey,
      envelopeJson: data.envelopeJson.present
          ? data.envelopeJson.value
          : this.envelopeJson,
      capturedAtEpochMs: data.capturedAtEpochMs.present
          ? data.capturedAtEpochMs.value
          : this.capturedAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflinePackageSnapshotRow(')
          ..write('userScopeId: $userScopeId, ')
          ..write('packageId: $packageId, ')
          ..write('manifestRevision: $manifestRevision, ')
          ..write('queryKey: $queryKey, ')
          ..write('envelopeJson: $envelopeJson, ')
          ..write('capturedAtEpochMs: $capturedAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userScopeId,
    packageId,
    manifestRevision,
    queryKey,
    envelopeJson,
    capturedAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DwOfflinePackageSnapshotRow &&
          other.userScopeId == this.userScopeId &&
          other.packageId == this.packageId &&
          other.manifestRevision == this.manifestRevision &&
          other.queryKey == this.queryKey &&
          other.envelopeJson == this.envelopeJson &&
          other.capturedAtEpochMs == this.capturedAtEpochMs);
}

class DwOfflinePackageSnapshotsCompanion
    extends UpdateCompanion<DwOfflinePackageSnapshotRow> {
  final Value<String> userScopeId;
  final Value<String> packageId;
  final Value<String> manifestRevision;
  final Value<String> queryKey;
  final Value<String> envelopeJson;
  final Value<int> capturedAtEpochMs;
  final Value<int> rowid;
  const DwOfflinePackageSnapshotsCompanion({
    this.userScopeId = const Value.absent(),
    this.packageId = const Value.absent(),
    this.manifestRevision = const Value.absent(),
    this.queryKey = const Value.absent(),
    this.envelopeJson = const Value.absent(),
    this.capturedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DwOfflinePackageSnapshotsCompanion.insert({
    required String userScopeId,
    required String packageId,
    required String manifestRevision,
    required String queryKey,
    required String envelopeJson,
    required int capturedAtEpochMs,
    this.rowid = const Value.absent(),
  }) : userScopeId = Value(userScopeId),
       packageId = Value(packageId),
       manifestRevision = Value(manifestRevision),
       queryKey = Value(queryKey),
       envelopeJson = Value(envelopeJson),
       capturedAtEpochMs = Value(capturedAtEpochMs);
  static Insertable<DwOfflinePackageSnapshotRow> custom({
    Expression<String>? userScopeId,
    Expression<String>? packageId,
    Expression<String>? manifestRevision,
    Expression<String>? queryKey,
    Expression<String>? envelopeJson,
    Expression<int>? capturedAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userScopeId != null) 'user_scope_id': userScopeId,
      if (packageId != null) 'package_id': packageId,
      if (manifestRevision != null) 'manifest_revision': manifestRevision,
      if (queryKey != null) 'query_key': queryKey,
      if (envelopeJson != null) 'envelope_json': envelopeJson,
      if (capturedAtEpochMs != null) 'captured_at_epoch_ms': capturedAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DwOfflinePackageSnapshotsCompanion copyWith({
    Value<String>? userScopeId,
    Value<String>? packageId,
    Value<String>? manifestRevision,
    Value<String>? queryKey,
    Value<String>? envelopeJson,
    Value<int>? capturedAtEpochMs,
    Value<int>? rowid,
  }) {
    return DwOfflinePackageSnapshotsCompanion(
      userScopeId: userScopeId ?? this.userScopeId,
      packageId: packageId ?? this.packageId,
      manifestRevision: manifestRevision ?? this.manifestRevision,
      queryKey: queryKey ?? this.queryKey,
      envelopeJson: envelopeJson ?? this.envelopeJson,
      capturedAtEpochMs: capturedAtEpochMs ?? this.capturedAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userScopeId.present) {
      map['user_scope_id'] = Variable<String>(userScopeId.value);
    }
    if (packageId.present) {
      map['package_id'] = Variable<String>(packageId.value);
    }
    if (manifestRevision.present) {
      map['manifest_revision'] = Variable<String>(manifestRevision.value);
    }
    if (queryKey.present) {
      map['query_key'] = Variable<String>(queryKey.value);
    }
    if (envelopeJson.present) {
      map['envelope_json'] = Variable<String>(envelopeJson.value);
    }
    if (capturedAtEpochMs.present) {
      map['captured_at_epoch_ms'] = Variable<int>(capturedAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflinePackageSnapshotsCompanion(')
          ..write('userScopeId: $userScopeId, ')
          ..write('packageId: $packageId, ')
          ..write('manifestRevision: $manifestRevision, ')
          ..write('queryKey: $queryKey, ')
          ..write('envelopeJson: $envelopeJson, ')
          ..write('capturedAtEpochMs: $capturedAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DwOfflineLeasesTable extends DwOfflineLeases
    with TableInfo<$DwOfflineLeasesTable, DwOfflineLeaseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DwOfflineLeasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userScopeIdMeta = const VerificationMeta(
    'userScopeId',
  );
  @override
  late final GeneratedColumn<String> userScopeId = GeneratedColumn<String>(
    'user_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(trim(user_scope_id)) > 0)',
  );
  static const VerificationMeta _leaseIdMeta = const VerificationMeta(
    'leaseId',
  );
  @override
  late final GeneratedColumn<String> leaseId = GeneratedColumn<String>(
    'lease_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _leaseEnvelopeJsonMeta = const VerificationMeta(
    'leaseEnvelopeJson',
  );
  @override
  late final GeneratedColumn<String> leaseEnvelopeJson =
      GeneratedColumn<String>(
        'lease_envelope_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _trustedAtEpochMsMeta = const VerificationMeta(
    'trustedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> trustedAtEpochMs = GeneratedColumn<int>(
    'trusted_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtEpochMsMeta = const VerificationMeta(
    'expiresAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> expiresAtEpochMs = GeneratedColumn<int>(
    'expires_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userScopeId,
    leaseId,
    leaseEnvelopeJson,
    trustedAtEpochMs,
    expiresAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dw_offline_leases';
  @override
  VerificationContext validateIntegrity(
    Insertable<DwOfflineLeaseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_scope_id')) {
      context.handle(
        _userScopeIdMeta,
        userScopeId.isAcceptableOrUnknown(
          data['user_scope_id']!,
          _userScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_userScopeIdMeta);
    }
    if (data.containsKey('lease_id')) {
      context.handle(
        _leaseIdMeta,
        leaseId.isAcceptableOrUnknown(data['lease_id']!, _leaseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_leaseIdMeta);
    }
    if (data.containsKey('lease_envelope_json')) {
      context.handle(
        _leaseEnvelopeJsonMeta,
        leaseEnvelopeJson.isAcceptableOrUnknown(
          data['lease_envelope_json']!,
          _leaseEnvelopeJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_leaseEnvelopeJsonMeta);
    }
    if (data.containsKey('trusted_at_epoch_ms')) {
      context.handle(
        _trustedAtEpochMsMeta,
        trustedAtEpochMs.isAcceptableOrUnknown(
          data['trusted_at_epoch_ms']!,
          _trustedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_trustedAtEpochMsMeta);
    }
    if (data.containsKey('expires_at_epoch_ms')) {
      context.handle(
        _expiresAtEpochMsMeta,
        expiresAtEpochMs.isAcceptableOrUnknown(
          data['expires_at_epoch_ms']!,
          _expiresAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_expiresAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userScopeId, leaseId};
  @override
  DwOfflineLeaseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DwOfflineLeaseRow(
      userScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_scope_id'],
      )!,
      leaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lease_id'],
      )!,
      leaseEnvelopeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lease_envelope_json'],
      )!,
      trustedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trusted_at_epoch_ms'],
      )!,
      expiresAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_at_epoch_ms'],
      )!,
    );
  }

  @override
  $DwOfflineLeasesTable createAlias(String alias) {
    return $DwOfflineLeasesTable(attachedDatabase, alias);
  }
}

class DwOfflineLeaseRow extends DataClass
    implements Insertable<DwOfflineLeaseRow> {
  final String userScopeId;
  final String leaseId;
  final String leaseEnvelopeJson;
  final int trustedAtEpochMs;
  final int expiresAtEpochMs;
  const DwOfflineLeaseRow({
    required this.userScopeId,
    required this.leaseId,
    required this.leaseEnvelopeJson,
    required this.trustedAtEpochMs,
    required this.expiresAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_scope_id'] = Variable<String>(userScopeId);
    map['lease_id'] = Variable<String>(leaseId);
    map['lease_envelope_json'] = Variable<String>(leaseEnvelopeJson);
    map['trusted_at_epoch_ms'] = Variable<int>(trustedAtEpochMs);
    map['expires_at_epoch_ms'] = Variable<int>(expiresAtEpochMs);
    return map;
  }

  DwOfflineLeasesCompanion toCompanion(bool nullToAbsent) {
    return DwOfflineLeasesCompanion(
      userScopeId: Value(userScopeId),
      leaseId: Value(leaseId),
      leaseEnvelopeJson: Value(leaseEnvelopeJson),
      trustedAtEpochMs: Value(trustedAtEpochMs),
      expiresAtEpochMs: Value(expiresAtEpochMs),
    );
  }

  factory DwOfflineLeaseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DwOfflineLeaseRow(
      userScopeId: serializer.fromJson<String>(json['userScopeId']),
      leaseId: serializer.fromJson<String>(json['leaseId']),
      leaseEnvelopeJson: serializer.fromJson<String>(json['leaseEnvelopeJson']),
      trustedAtEpochMs: serializer.fromJson<int>(json['trustedAtEpochMs']),
      expiresAtEpochMs: serializer.fromJson<int>(json['expiresAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userScopeId': serializer.toJson<String>(userScopeId),
      'leaseId': serializer.toJson<String>(leaseId),
      'leaseEnvelopeJson': serializer.toJson<String>(leaseEnvelopeJson),
      'trustedAtEpochMs': serializer.toJson<int>(trustedAtEpochMs),
      'expiresAtEpochMs': serializer.toJson<int>(expiresAtEpochMs),
    };
  }

  DwOfflineLeaseRow copyWith({
    String? userScopeId,
    String? leaseId,
    String? leaseEnvelopeJson,
    int? trustedAtEpochMs,
    int? expiresAtEpochMs,
  }) => DwOfflineLeaseRow(
    userScopeId: userScopeId ?? this.userScopeId,
    leaseId: leaseId ?? this.leaseId,
    leaseEnvelopeJson: leaseEnvelopeJson ?? this.leaseEnvelopeJson,
    trustedAtEpochMs: trustedAtEpochMs ?? this.trustedAtEpochMs,
    expiresAtEpochMs: expiresAtEpochMs ?? this.expiresAtEpochMs,
  );
  DwOfflineLeaseRow copyWithCompanion(DwOfflineLeasesCompanion data) {
    return DwOfflineLeaseRow(
      userScopeId: data.userScopeId.present
          ? data.userScopeId.value
          : this.userScopeId,
      leaseId: data.leaseId.present ? data.leaseId.value : this.leaseId,
      leaseEnvelopeJson: data.leaseEnvelopeJson.present
          ? data.leaseEnvelopeJson.value
          : this.leaseEnvelopeJson,
      trustedAtEpochMs: data.trustedAtEpochMs.present
          ? data.trustedAtEpochMs.value
          : this.trustedAtEpochMs,
      expiresAtEpochMs: data.expiresAtEpochMs.present
          ? data.expiresAtEpochMs.value
          : this.expiresAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflineLeaseRow(')
          ..write('userScopeId: $userScopeId, ')
          ..write('leaseId: $leaseId, ')
          ..write('leaseEnvelopeJson: $leaseEnvelopeJson, ')
          ..write('trustedAtEpochMs: $trustedAtEpochMs, ')
          ..write('expiresAtEpochMs: $expiresAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userScopeId,
    leaseId,
    leaseEnvelopeJson,
    trustedAtEpochMs,
    expiresAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DwOfflineLeaseRow &&
          other.userScopeId == this.userScopeId &&
          other.leaseId == this.leaseId &&
          other.leaseEnvelopeJson == this.leaseEnvelopeJson &&
          other.trustedAtEpochMs == this.trustedAtEpochMs &&
          other.expiresAtEpochMs == this.expiresAtEpochMs);
}

class DwOfflineLeasesCompanion extends UpdateCompanion<DwOfflineLeaseRow> {
  final Value<String> userScopeId;
  final Value<String> leaseId;
  final Value<String> leaseEnvelopeJson;
  final Value<int> trustedAtEpochMs;
  final Value<int> expiresAtEpochMs;
  final Value<int> rowid;
  const DwOfflineLeasesCompanion({
    this.userScopeId = const Value.absent(),
    this.leaseId = const Value.absent(),
    this.leaseEnvelopeJson = const Value.absent(),
    this.trustedAtEpochMs = const Value.absent(),
    this.expiresAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DwOfflineLeasesCompanion.insert({
    required String userScopeId,
    required String leaseId,
    required String leaseEnvelopeJson,
    required int trustedAtEpochMs,
    required int expiresAtEpochMs,
    this.rowid = const Value.absent(),
  }) : userScopeId = Value(userScopeId),
       leaseId = Value(leaseId),
       leaseEnvelopeJson = Value(leaseEnvelopeJson),
       trustedAtEpochMs = Value(trustedAtEpochMs),
       expiresAtEpochMs = Value(expiresAtEpochMs);
  static Insertable<DwOfflineLeaseRow> custom({
    Expression<String>? userScopeId,
    Expression<String>? leaseId,
    Expression<String>? leaseEnvelopeJson,
    Expression<int>? trustedAtEpochMs,
    Expression<int>? expiresAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userScopeId != null) 'user_scope_id': userScopeId,
      if (leaseId != null) 'lease_id': leaseId,
      if (leaseEnvelopeJson != null) 'lease_envelope_json': leaseEnvelopeJson,
      if (trustedAtEpochMs != null) 'trusted_at_epoch_ms': trustedAtEpochMs,
      if (expiresAtEpochMs != null) 'expires_at_epoch_ms': expiresAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DwOfflineLeasesCompanion copyWith({
    Value<String>? userScopeId,
    Value<String>? leaseId,
    Value<String>? leaseEnvelopeJson,
    Value<int>? trustedAtEpochMs,
    Value<int>? expiresAtEpochMs,
    Value<int>? rowid,
  }) {
    return DwOfflineLeasesCompanion(
      userScopeId: userScopeId ?? this.userScopeId,
      leaseId: leaseId ?? this.leaseId,
      leaseEnvelopeJson: leaseEnvelopeJson ?? this.leaseEnvelopeJson,
      trustedAtEpochMs: trustedAtEpochMs ?? this.trustedAtEpochMs,
      expiresAtEpochMs: expiresAtEpochMs ?? this.expiresAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userScopeId.present) {
      map['user_scope_id'] = Variable<String>(userScopeId.value);
    }
    if (leaseId.present) {
      map['lease_id'] = Variable<String>(leaseId.value);
    }
    if (leaseEnvelopeJson.present) {
      map['lease_envelope_json'] = Variable<String>(leaseEnvelopeJson.value);
    }
    if (trustedAtEpochMs.present) {
      map['trusted_at_epoch_ms'] = Variable<int>(trustedAtEpochMs.value);
    }
    if (expiresAtEpochMs.present) {
      map['expires_at_epoch_ms'] = Variable<int>(expiresAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflineLeasesCompanion(')
          ..write('userScopeId: $userScopeId, ')
          ..write('leaseId: $leaseId, ')
          ..write('leaseEnvelopeJson: $leaseEnvelopeJson, ')
          ..write('trustedAtEpochMs: $trustedAtEpochMs, ')
          ..write('expiresAtEpochMs: $expiresAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DwOfflineReaderPinsTable extends DwOfflineReaderPins
    with TableInfo<$DwOfflineReaderPinsTable, DwOfflineReaderPinRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DwOfflineReaderPinsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userScopeIdMeta = const VerificationMeta(
    'userScopeId',
  );
  @override
  late final GeneratedColumn<String> userScopeId = GeneratedColumn<String>(
    'user_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(trim(user_scope_id)) > 0)',
  );
  static const VerificationMeta _readerIdMeta = const VerificationMeta(
    'readerId',
  );
  @override
  late final GeneratedColumn<String> readerId = GeneratedColumn<String>(
    'reader_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetRevisionMeta = const VerificationMeta(
    'assetRevision',
  );
  @override
  late final GeneratedColumn<String> assetRevision = GeneratedColumn<String>(
    'asset_revision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinnedAtEpochMsMeta = const VerificationMeta(
    'pinnedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> pinnedAtEpochMs = GeneratedColumn<int>(
    'pinned_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userScopeId,
    readerId,
    assetId,
    assetRevision,
    pinnedAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dw_offline_reader_pins';
  @override
  VerificationContext validateIntegrity(
    Insertable<DwOfflineReaderPinRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_scope_id')) {
      context.handle(
        _userScopeIdMeta,
        userScopeId.isAcceptableOrUnknown(
          data['user_scope_id']!,
          _userScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_userScopeIdMeta);
    }
    if (data.containsKey('reader_id')) {
      context.handle(
        _readerIdMeta,
        readerId.isAcceptableOrUnknown(data['reader_id']!, _readerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_readerIdMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('asset_revision')) {
      context.handle(
        _assetRevisionMeta,
        assetRevision.isAcceptableOrUnknown(
          data['asset_revision']!,
          _assetRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_assetRevisionMeta);
    }
    if (data.containsKey('pinned_at_epoch_ms')) {
      context.handle(
        _pinnedAtEpochMsMeta,
        pinnedAtEpochMs.isAcceptableOrUnknown(
          data['pinned_at_epoch_ms']!,
          _pinnedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pinnedAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    userScopeId,
    readerId,
    assetId,
    assetRevision,
  };
  @override
  DwOfflineReaderPinRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DwOfflineReaderPinRow(
      userScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_scope_id'],
      )!,
      readerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reader_id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      assetRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_revision'],
      )!,
      pinnedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pinned_at_epoch_ms'],
      )!,
    );
  }

  @override
  $DwOfflineReaderPinsTable createAlias(String alias) {
    return $DwOfflineReaderPinsTable(attachedDatabase, alias);
  }
}

class DwOfflineReaderPinRow extends DataClass
    implements Insertable<DwOfflineReaderPinRow> {
  final String userScopeId;
  final String readerId;
  final String assetId;
  final String assetRevision;
  final int pinnedAtEpochMs;
  const DwOfflineReaderPinRow({
    required this.userScopeId,
    required this.readerId,
    required this.assetId,
    required this.assetRevision,
    required this.pinnedAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_scope_id'] = Variable<String>(userScopeId);
    map['reader_id'] = Variable<String>(readerId);
    map['asset_id'] = Variable<String>(assetId);
    map['asset_revision'] = Variable<String>(assetRevision);
    map['pinned_at_epoch_ms'] = Variable<int>(pinnedAtEpochMs);
    return map;
  }

  DwOfflineReaderPinsCompanion toCompanion(bool nullToAbsent) {
    return DwOfflineReaderPinsCompanion(
      userScopeId: Value(userScopeId),
      readerId: Value(readerId),
      assetId: Value(assetId),
      assetRevision: Value(assetRevision),
      pinnedAtEpochMs: Value(pinnedAtEpochMs),
    );
  }

  factory DwOfflineReaderPinRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DwOfflineReaderPinRow(
      userScopeId: serializer.fromJson<String>(json['userScopeId']),
      readerId: serializer.fromJson<String>(json['readerId']),
      assetId: serializer.fromJson<String>(json['assetId']),
      assetRevision: serializer.fromJson<String>(json['assetRevision']),
      pinnedAtEpochMs: serializer.fromJson<int>(json['pinnedAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userScopeId': serializer.toJson<String>(userScopeId),
      'readerId': serializer.toJson<String>(readerId),
      'assetId': serializer.toJson<String>(assetId),
      'assetRevision': serializer.toJson<String>(assetRevision),
      'pinnedAtEpochMs': serializer.toJson<int>(pinnedAtEpochMs),
    };
  }

  DwOfflineReaderPinRow copyWith({
    String? userScopeId,
    String? readerId,
    String? assetId,
    String? assetRevision,
    int? pinnedAtEpochMs,
  }) => DwOfflineReaderPinRow(
    userScopeId: userScopeId ?? this.userScopeId,
    readerId: readerId ?? this.readerId,
    assetId: assetId ?? this.assetId,
    assetRevision: assetRevision ?? this.assetRevision,
    pinnedAtEpochMs: pinnedAtEpochMs ?? this.pinnedAtEpochMs,
  );
  DwOfflineReaderPinRow copyWithCompanion(DwOfflineReaderPinsCompanion data) {
    return DwOfflineReaderPinRow(
      userScopeId: data.userScopeId.present
          ? data.userScopeId.value
          : this.userScopeId,
      readerId: data.readerId.present ? data.readerId.value : this.readerId,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      assetRevision: data.assetRevision.present
          ? data.assetRevision.value
          : this.assetRevision,
      pinnedAtEpochMs: data.pinnedAtEpochMs.present
          ? data.pinnedAtEpochMs.value
          : this.pinnedAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflineReaderPinRow(')
          ..write('userScopeId: $userScopeId, ')
          ..write('readerId: $readerId, ')
          ..write('assetId: $assetId, ')
          ..write('assetRevision: $assetRevision, ')
          ..write('pinnedAtEpochMs: $pinnedAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userScopeId,
    readerId,
    assetId,
    assetRevision,
    pinnedAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DwOfflineReaderPinRow &&
          other.userScopeId == this.userScopeId &&
          other.readerId == this.readerId &&
          other.assetId == this.assetId &&
          other.assetRevision == this.assetRevision &&
          other.pinnedAtEpochMs == this.pinnedAtEpochMs);
}

class DwOfflineReaderPinsCompanion
    extends UpdateCompanion<DwOfflineReaderPinRow> {
  final Value<String> userScopeId;
  final Value<String> readerId;
  final Value<String> assetId;
  final Value<String> assetRevision;
  final Value<int> pinnedAtEpochMs;
  final Value<int> rowid;
  const DwOfflineReaderPinsCompanion({
    this.userScopeId = const Value.absent(),
    this.readerId = const Value.absent(),
    this.assetId = const Value.absent(),
    this.assetRevision = const Value.absent(),
    this.pinnedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DwOfflineReaderPinsCompanion.insert({
    required String userScopeId,
    required String readerId,
    required String assetId,
    required String assetRevision,
    required int pinnedAtEpochMs,
    this.rowid = const Value.absent(),
  }) : userScopeId = Value(userScopeId),
       readerId = Value(readerId),
       assetId = Value(assetId),
       assetRevision = Value(assetRevision),
       pinnedAtEpochMs = Value(pinnedAtEpochMs);
  static Insertable<DwOfflineReaderPinRow> custom({
    Expression<String>? userScopeId,
    Expression<String>? readerId,
    Expression<String>? assetId,
    Expression<String>? assetRevision,
    Expression<int>? pinnedAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userScopeId != null) 'user_scope_id': userScopeId,
      if (readerId != null) 'reader_id': readerId,
      if (assetId != null) 'asset_id': assetId,
      if (assetRevision != null) 'asset_revision': assetRevision,
      if (pinnedAtEpochMs != null) 'pinned_at_epoch_ms': pinnedAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DwOfflineReaderPinsCompanion copyWith({
    Value<String>? userScopeId,
    Value<String>? readerId,
    Value<String>? assetId,
    Value<String>? assetRevision,
    Value<int>? pinnedAtEpochMs,
    Value<int>? rowid,
  }) {
    return DwOfflineReaderPinsCompanion(
      userScopeId: userScopeId ?? this.userScopeId,
      readerId: readerId ?? this.readerId,
      assetId: assetId ?? this.assetId,
      assetRevision: assetRevision ?? this.assetRevision,
      pinnedAtEpochMs: pinnedAtEpochMs ?? this.pinnedAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userScopeId.present) {
      map['user_scope_id'] = Variable<String>(userScopeId.value);
    }
    if (readerId.present) {
      map['reader_id'] = Variable<String>(readerId.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (assetRevision.present) {
      map['asset_revision'] = Variable<String>(assetRevision.value);
    }
    if (pinnedAtEpochMs.present) {
      map['pinned_at_epoch_ms'] = Variable<int>(pinnedAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflineReaderPinsCompanion(')
          ..write('userScopeId: $userScopeId, ')
          ..write('readerId: $readerId, ')
          ..write('assetId: $assetId, ')
          ..write('assetRevision: $assetRevision, ')
          ..write('pinnedAtEpochMs: $pinnedAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DwOfflineStagingAssetsTable extends DwOfflineStagingAssets
    with TableInfo<$DwOfflineStagingAssetsTable, DwOfflineStagingAssetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DwOfflineStagingAssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userScopeIdMeta = const VerificationMeta(
    'userScopeId',
  );
  @override
  late final GeneratedColumn<String> userScopeId = GeneratedColumn<String>(
    'user_scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packageIdMeta = const VerificationMeta(
    'packageId',
  );
  @override
  late final GeneratedColumn<String> packageId = GeneratedColumn<String>(
    'package_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _manifestRevisionMeta = const VerificationMeta(
    'manifestRevision',
  );
  @override
  late final GeneratedColumn<String> manifestRevision = GeneratedColumn<String>(
    'manifest_revision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetRevisionMeta = const VerificationMeta(
    'assetRevision',
  );
  @override
  late final GeneratedColumn<String> assetRevision = GeneratedColumn<String>(
    'asset_revision',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isRequiredMeta = const VerificationMeta(
    'isRequired',
  );
  @override
  late final GeneratedColumn<bool> isRequired = GeneratedColumn<bool>(
    'is_required',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_required" IN (0, 1))',
    ),
  );
  static const VerificationMeta _createdAtEpochMsMeta = const VerificationMeta(
    'createdAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> createdAtEpochMs = GeneratedColumn<int>(
    'created_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userScopeId,
    packageId,
    manifestRevision,
    assetId,
    assetRevision,
    isRequired,
    createdAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dw_offline_staging_assets';
  @override
  VerificationContext validateIntegrity(
    Insertable<DwOfflineStagingAssetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_scope_id')) {
      context.handle(
        _userScopeIdMeta,
        userScopeId.isAcceptableOrUnknown(
          data['user_scope_id']!,
          _userScopeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_userScopeIdMeta);
    }
    if (data.containsKey('package_id')) {
      context.handle(
        _packageIdMeta,
        packageId.isAcceptableOrUnknown(data['package_id']!, _packageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_packageIdMeta);
    }
    if (data.containsKey('manifest_revision')) {
      context.handle(
        _manifestRevisionMeta,
        manifestRevision.isAcceptableOrUnknown(
          data['manifest_revision']!,
          _manifestRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_manifestRevisionMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('asset_revision')) {
      context.handle(
        _assetRevisionMeta,
        assetRevision.isAcceptableOrUnknown(
          data['asset_revision']!,
          _assetRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_assetRevisionMeta);
    }
    if (data.containsKey('is_required')) {
      context.handle(
        _isRequiredMeta,
        isRequired.isAcceptableOrUnknown(data['is_required']!, _isRequiredMeta),
      );
    } else if (isInserting) {
      context.missing(_isRequiredMeta);
    }
    if (data.containsKey('created_at_epoch_ms')) {
      context.handle(
        _createdAtEpochMsMeta,
        createdAtEpochMs.isAcceptableOrUnknown(
          data['created_at_epoch_ms']!,
          _createdAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    userScopeId,
    packageId,
    manifestRevision,
    assetId,
    assetRevision,
  };
  @override
  DwOfflineStagingAssetRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DwOfflineStagingAssetRow(
      userScopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_scope_id'],
      )!,
      packageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_id'],
      )!,
      manifestRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest_revision'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      assetRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_revision'],
      )!,
      isRequired: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_required'],
      )!,
      createdAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_epoch_ms'],
      )!,
    );
  }

  @override
  $DwOfflineStagingAssetsTable createAlias(String alias) {
    return $DwOfflineStagingAssetsTable(attachedDatabase, alias);
  }
}

class DwOfflineStagingAssetRow extends DataClass
    implements Insertable<DwOfflineStagingAssetRow> {
  final String userScopeId;
  final String packageId;
  final String manifestRevision;
  final String assetId;
  final String assetRevision;
  final bool isRequired;
  final int createdAtEpochMs;
  const DwOfflineStagingAssetRow({
    required this.userScopeId,
    required this.packageId,
    required this.manifestRevision,
    required this.assetId,
    required this.assetRevision,
    required this.isRequired,
    required this.createdAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_scope_id'] = Variable<String>(userScopeId);
    map['package_id'] = Variable<String>(packageId);
    map['manifest_revision'] = Variable<String>(manifestRevision);
    map['asset_id'] = Variable<String>(assetId);
    map['asset_revision'] = Variable<String>(assetRevision);
    map['is_required'] = Variable<bool>(isRequired);
    map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs);
    return map;
  }

  DwOfflineStagingAssetsCompanion toCompanion(bool nullToAbsent) {
    return DwOfflineStagingAssetsCompanion(
      userScopeId: Value(userScopeId),
      packageId: Value(packageId),
      manifestRevision: Value(manifestRevision),
      assetId: Value(assetId),
      assetRevision: Value(assetRevision),
      isRequired: Value(isRequired),
      createdAtEpochMs: Value(createdAtEpochMs),
    );
  }

  factory DwOfflineStagingAssetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DwOfflineStagingAssetRow(
      userScopeId: serializer.fromJson<String>(json['userScopeId']),
      packageId: serializer.fromJson<String>(json['packageId']),
      manifestRevision: serializer.fromJson<String>(json['manifestRevision']),
      assetId: serializer.fromJson<String>(json['assetId']),
      assetRevision: serializer.fromJson<String>(json['assetRevision']),
      isRequired: serializer.fromJson<bool>(json['isRequired']),
      createdAtEpochMs: serializer.fromJson<int>(json['createdAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userScopeId': serializer.toJson<String>(userScopeId),
      'packageId': serializer.toJson<String>(packageId),
      'manifestRevision': serializer.toJson<String>(manifestRevision),
      'assetId': serializer.toJson<String>(assetId),
      'assetRevision': serializer.toJson<String>(assetRevision),
      'isRequired': serializer.toJson<bool>(isRequired),
      'createdAtEpochMs': serializer.toJson<int>(createdAtEpochMs),
    };
  }

  DwOfflineStagingAssetRow copyWith({
    String? userScopeId,
    String? packageId,
    String? manifestRevision,
    String? assetId,
    String? assetRevision,
    bool? isRequired,
    int? createdAtEpochMs,
  }) => DwOfflineStagingAssetRow(
    userScopeId: userScopeId ?? this.userScopeId,
    packageId: packageId ?? this.packageId,
    manifestRevision: manifestRevision ?? this.manifestRevision,
    assetId: assetId ?? this.assetId,
    assetRevision: assetRevision ?? this.assetRevision,
    isRequired: isRequired ?? this.isRequired,
    createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
  );
  DwOfflineStagingAssetRow copyWithCompanion(
    DwOfflineStagingAssetsCompanion data,
  ) {
    return DwOfflineStagingAssetRow(
      userScopeId: data.userScopeId.present
          ? data.userScopeId.value
          : this.userScopeId,
      packageId: data.packageId.present ? data.packageId.value : this.packageId,
      manifestRevision: data.manifestRevision.present
          ? data.manifestRevision.value
          : this.manifestRevision,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      assetRevision: data.assetRevision.present
          ? data.assetRevision.value
          : this.assetRevision,
      isRequired: data.isRequired.present
          ? data.isRequired.value
          : this.isRequired,
      createdAtEpochMs: data.createdAtEpochMs.present
          ? data.createdAtEpochMs.value
          : this.createdAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflineStagingAssetRow(')
          ..write('userScopeId: $userScopeId, ')
          ..write('packageId: $packageId, ')
          ..write('manifestRevision: $manifestRevision, ')
          ..write('assetId: $assetId, ')
          ..write('assetRevision: $assetRevision, ')
          ..write('isRequired: $isRequired, ')
          ..write('createdAtEpochMs: $createdAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userScopeId,
    packageId,
    manifestRevision,
    assetId,
    assetRevision,
    isRequired,
    createdAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DwOfflineStagingAssetRow &&
          other.userScopeId == this.userScopeId &&
          other.packageId == this.packageId &&
          other.manifestRevision == this.manifestRevision &&
          other.assetId == this.assetId &&
          other.assetRevision == this.assetRevision &&
          other.isRequired == this.isRequired &&
          other.createdAtEpochMs == this.createdAtEpochMs);
}

class DwOfflineStagingAssetsCompanion
    extends UpdateCompanion<DwOfflineStagingAssetRow> {
  final Value<String> userScopeId;
  final Value<String> packageId;
  final Value<String> manifestRevision;
  final Value<String> assetId;
  final Value<String> assetRevision;
  final Value<bool> isRequired;
  final Value<int> createdAtEpochMs;
  final Value<int> rowid;
  const DwOfflineStagingAssetsCompanion({
    this.userScopeId = const Value.absent(),
    this.packageId = const Value.absent(),
    this.manifestRevision = const Value.absent(),
    this.assetId = const Value.absent(),
    this.assetRevision = const Value.absent(),
    this.isRequired = const Value.absent(),
    this.createdAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DwOfflineStagingAssetsCompanion.insert({
    required String userScopeId,
    required String packageId,
    required String manifestRevision,
    required String assetId,
    required String assetRevision,
    required bool isRequired,
    required int createdAtEpochMs,
    this.rowid = const Value.absent(),
  }) : userScopeId = Value(userScopeId),
       packageId = Value(packageId),
       manifestRevision = Value(manifestRevision),
       assetId = Value(assetId),
       assetRevision = Value(assetRevision),
       isRequired = Value(isRequired),
       createdAtEpochMs = Value(createdAtEpochMs);
  static Insertable<DwOfflineStagingAssetRow> custom({
    Expression<String>? userScopeId,
    Expression<String>? packageId,
    Expression<String>? manifestRevision,
    Expression<String>? assetId,
    Expression<String>? assetRevision,
    Expression<bool>? isRequired,
    Expression<int>? createdAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userScopeId != null) 'user_scope_id': userScopeId,
      if (packageId != null) 'package_id': packageId,
      if (manifestRevision != null) 'manifest_revision': manifestRevision,
      if (assetId != null) 'asset_id': assetId,
      if (assetRevision != null) 'asset_revision': assetRevision,
      if (isRequired != null) 'is_required': isRequired,
      if (createdAtEpochMs != null) 'created_at_epoch_ms': createdAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DwOfflineStagingAssetsCompanion copyWith({
    Value<String>? userScopeId,
    Value<String>? packageId,
    Value<String>? manifestRevision,
    Value<String>? assetId,
    Value<String>? assetRevision,
    Value<bool>? isRequired,
    Value<int>? createdAtEpochMs,
    Value<int>? rowid,
  }) {
    return DwOfflineStagingAssetsCompanion(
      userScopeId: userScopeId ?? this.userScopeId,
      packageId: packageId ?? this.packageId,
      manifestRevision: manifestRevision ?? this.manifestRevision,
      assetId: assetId ?? this.assetId,
      assetRevision: assetRevision ?? this.assetRevision,
      isRequired: isRequired ?? this.isRequired,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userScopeId.present) {
      map['user_scope_id'] = Variable<String>(userScopeId.value);
    }
    if (packageId.present) {
      map['package_id'] = Variable<String>(packageId.value);
    }
    if (manifestRevision.present) {
      map['manifest_revision'] = Variable<String>(manifestRevision.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (assetRevision.present) {
      map['asset_revision'] = Variable<String>(assetRevision.value);
    }
    if (isRequired.present) {
      map['is_required'] = Variable<bool>(isRequired.value);
    }
    if (createdAtEpochMs.present) {
      map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DwOfflineStagingAssetsCompanion(')
          ..write('userScopeId: $userScopeId, ')
          ..write('packageId: $packageId, ')
          ..write('manifestRevision: $manifestRevision, ')
          ..write('assetId: $assetId, ')
          ..write('assetRevision: $assetRevision, ')
          ..write('isRequired: $isRequired, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$DwOfflineDatabase extends GeneratedDatabase {
  _$DwOfflineDatabase(QueryExecutor e) : super(e);
  $DwOfflineDatabaseManager get managers => $DwOfflineDatabaseManager(this);
  late final $DwOfflinePackagesTable dwOfflinePackages =
      $DwOfflinePackagesTable(this);
  late final $DwOfflineAssetsTable dwOfflineAssets = $DwOfflineAssetsTable(
    this,
  );
  late final $DwOfflinePackageAssetsTable dwOfflinePackageAssets =
      $DwOfflinePackageAssetsTable(this);
  late final $DwOfflineJobsTable dwOfflineJobs = $DwOfflineJobsTable(this);
  late final $DwOfflineDownloadTasksTable dwOfflineDownloadTasks =
      $DwOfflineDownloadTasksTable(this);
  late final $DwOfflineSnapshotsTable dwOfflineSnapshots =
      $DwOfflineSnapshotsTable(this);
  late final $DwOfflineOutboxTable dwOfflineOutbox = $DwOfflineOutboxTable(
    this,
  );
  late final $DwOfflineManifestsTable dwOfflineManifests =
      $DwOfflineManifestsTable(this);
  late final $DwOfflinePackageSnapshotsTable dwOfflinePackageSnapshots =
      $DwOfflinePackageSnapshotsTable(this);
  late final $DwOfflineLeasesTable dwOfflineLeases = $DwOfflineLeasesTable(
    this,
  );
  late final $DwOfflineReaderPinsTable dwOfflineReaderPins =
      $DwOfflineReaderPinsTable(this);
  late final $DwOfflineStagingAssetsTable dwOfflineStagingAssets =
      $DwOfflineStagingAssetsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    dwOfflinePackages,
    dwOfflineAssets,
    dwOfflinePackageAssets,
    dwOfflineJobs,
    dwOfflineDownloadTasks,
    dwOfflineSnapshots,
    dwOfflineOutbox,
    dwOfflineManifests,
    dwOfflinePackageSnapshots,
    dwOfflineLeases,
    dwOfflineReaderPins,
    dwOfflineStagingAssets,
  ];
}

typedef $$DwOfflinePackagesTableCreateCompanionBuilder =
    DwOfflinePackagesCompanion Function({
      required String userScopeId,
      required String packageId,
      required String contentIdentity,
      Value<String?> activeManifestRevision,
      Value<String?> activeManifestDigest,
      Value<String?> stagingManifestRevision,
      Value<String?> stagingManifestDigest,
      required String aggregateStatus,
      required int completedAssetCount,
      required int totalAssetCount,
      required int createdAtEpochMs,
      required int updatedAtEpochMs,
      Value<int> rowid,
    });
typedef $$DwOfflinePackagesTableUpdateCompanionBuilder =
    DwOfflinePackagesCompanion Function({
      Value<String> userScopeId,
      Value<String> packageId,
      Value<String> contentIdentity,
      Value<String?> activeManifestRevision,
      Value<String?> activeManifestDigest,
      Value<String?> stagingManifestRevision,
      Value<String?> stagingManifestDigest,
      Value<String> aggregateStatus,
      Value<int> completedAssetCount,
      Value<int> totalAssetCount,
      Value<int> createdAtEpochMs,
      Value<int> updatedAtEpochMs,
      Value<int> rowid,
    });

class $$DwOfflinePackagesTableFilterComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflinePackagesTable> {
  $$DwOfflinePackagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentIdentity => $composableBuilder(
    column: $table.contentIdentity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeManifestRevision => $composableBuilder(
    column: $table.activeManifestRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeManifestDigest => $composableBuilder(
    column: $table.activeManifestDigest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stagingManifestRevision => $composableBuilder(
    column: $table.stagingManifestRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stagingManifestDigest => $composableBuilder(
    column: $table.stagingManifestDigest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aggregateStatus => $composableBuilder(
    column: $table.aggregateStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAssetCount => $composableBuilder(
    column: $table.completedAssetCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalAssetCount => $composableBuilder(
    column: $table.totalAssetCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DwOfflinePackagesTableOrderingComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflinePackagesTable> {
  $$DwOfflinePackagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentIdentity => $composableBuilder(
    column: $table.contentIdentity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeManifestRevision => $composableBuilder(
    column: $table.activeManifestRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeManifestDigest => $composableBuilder(
    column: $table.activeManifestDigest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stagingManifestRevision => $composableBuilder(
    column: $table.stagingManifestRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stagingManifestDigest => $composableBuilder(
    column: $table.stagingManifestDigest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aggregateStatus => $composableBuilder(
    column: $table.aggregateStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAssetCount => $composableBuilder(
    column: $table.completedAssetCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalAssetCount => $composableBuilder(
    column: $table.totalAssetCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DwOfflinePackagesTableAnnotationComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflinePackagesTable> {
  $$DwOfflinePackagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get packageId =>
      $composableBuilder(column: $table.packageId, builder: (column) => column);

  GeneratedColumn<String> get contentIdentity => $composableBuilder(
    column: $table.contentIdentity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activeManifestRevision => $composableBuilder(
    column: $table.activeManifestRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activeManifestDigest => $composableBuilder(
    column: $table.activeManifestDigest,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stagingManifestRevision => $composableBuilder(
    column: $table.stagingManifestRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stagingManifestDigest => $composableBuilder(
    column: $table.stagingManifestDigest,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aggregateStatus => $composableBuilder(
    column: $table.aggregateStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedAssetCount => $composableBuilder(
    column: $table.completedAssetCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalAssetCount => $composableBuilder(
    column: $table.totalAssetCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => column,
  );
}

class $$DwOfflinePackagesTableTableManager
    extends
        RootTableManager<
          _$DwOfflineDatabase,
          $DwOfflinePackagesTable,
          DwOfflinePackageRow,
          $$DwOfflinePackagesTableFilterComposer,
          $$DwOfflinePackagesTableOrderingComposer,
          $$DwOfflinePackagesTableAnnotationComposer,
          $$DwOfflinePackagesTableCreateCompanionBuilder,
          $$DwOfflinePackagesTableUpdateCompanionBuilder,
          (
            DwOfflinePackageRow,
            BaseReferences<
              _$DwOfflineDatabase,
              $DwOfflinePackagesTable,
              DwOfflinePackageRow
            >,
          ),
          DwOfflinePackageRow,
          PrefetchHooks Function()
        > {
  $$DwOfflinePackagesTableTableManager(
    _$DwOfflineDatabase db,
    $DwOfflinePackagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DwOfflinePackagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DwOfflinePackagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DwOfflinePackagesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userScopeId = const Value.absent(),
                Value<String> packageId = const Value.absent(),
                Value<String> contentIdentity = const Value.absent(),
                Value<String?> activeManifestRevision = const Value.absent(),
                Value<String?> activeManifestDigest = const Value.absent(),
                Value<String?> stagingManifestRevision = const Value.absent(),
                Value<String?> stagingManifestDigest = const Value.absent(),
                Value<String> aggregateStatus = const Value.absent(),
                Value<int> completedAssetCount = const Value.absent(),
                Value<int> totalAssetCount = const Value.absent(),
                Value<int> createdAtEpochMs = const Value.absent(),
                Value<int> updatedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DwOfflinePackagesCompanion(
                userScopeId: userScopeId,
                packageId: packageId,
                contentIdentity: contentIdentity,
                activeManifestRevision: activeManifestRevision,
                activeManifestDigest: activeManifestDigest,
                stagingManifestRevision: stagingManifestRevision,
                stagingManifestDigest: stagingManifestDigest,
                aggregateStatus: aggregateStatus,
                completedAssetCount: completedAssetCount,
                totalAssetCount: totalAssetCount,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userScopeId,
                required String packageId,
                required String contentIdentity,
                Value<String?> activeManifestRevision = const Value.absent(),
                Value<String?> activeManifestDigest = const Value.absent(),
                Value<String?> stagingManifestRevision = const Value.absent(),
                Value<String?> stagingManifestDigest = const Value.absent(),
                required String aggregateStatus,
                required int completedAssetCount,
                required int totalAssetCount,
                required int createdAtEpochMs,
                required int updatedAtEpochMs,
                Value<int> rowid = const Value.absent(),
              }) => DwOfflinePackagesCompanion.insert(
                userScopeId: userScopeId,
                packageId: packageId,
                contentIdentity: contentIdentity,
                activeManifestRevision: activeManifestRevision,
                activeManifestDigest: activeManifestDigest,
                stagingManifestRevision: stagingManifestRevision,
                stagingManifestDigest: stagingManifestDigest,
                aggregateStatus: aggregateStatus,
                completedAssetCount: completedAssetCount,
                totalAssetCount: totalAssetCount,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DwOfflinePackagesTableProcessedTableManager =
    ProcessedTableManager<
      _$DwOfflineDatabase,
      $DwOfflinePackagesTable,
      DwOfflinePackageRow,
      $$DwOfflinePackagesTableFilterComposer,
      $$DwOfflinePackagesTableOrderingComposer,
      $$DwOfflinePackagesTableAnnotationComposer,
      $$DwOfflinePackagesTableCreateCompanionBuilder,
      $$DwOfflinePackagesTableUpdateCompanionBuilder,
      (
        DwOfflinePackageRow,
        BaseReferences<
          _$DwOfflineDatabase,
          $DwOfflinePackagesTable,
          DwOfflinePackageRow
        >,
      ),
      DwOfflinePackageRow,
      PrefetchHooks Function()
    >;
typedef $$DwOfflineAssetsTableCreateCompanionBuilder =
    DwOfflineAssetsCompanion Function({
      required String userScopeId,
      required String assetId,
      required String assetRevision,
      required int expectedSizeBytes,
      required String checksum,
      required String mimeType,
      required String relativePath,
      Value<String?> downloadUrl,
      Value<String?> allowedRedirectHostsJson,
      Value<String?> blobName,
      required String assetState,
      Value<int> refCount,
      Value<bool> isTombstoned,
      required int createdAtEpochMs,
      required int updatedAtEpochMs,
      Value<int> rowid,
    });
typedef $$DwOfflineAssetsTableUpdateCompanionBuilder =
    DwOfflineAssetsCompanion Function({
      Value<String> userScopeId,
      Value<String> assetId,
      Value<String> assetRevision,
      Value<int> expectedSizeBytes,
      Value<String> checksum,
      Value<String> mimeType,
      Value<String> relativePath,
      Value<String?> downloadUrl,
      Value<String?> allowedRedirectHostsJson,
      Value<String?> blobName,
      Value<String> assetState,
      Value<int> refCount,
      Value<bool> isTombstoned,
      Value<int> createdAtEpochMs,
      Value<int> updatedAtEpochMs,
      Value<int> rowid,
    });

class $$DwOfflineAssetsTableFilterComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineAssetsTable> {
  $$DwOfflineAssetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetRevision => $composableBuilder(
    column: $table.assetRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedSizeBytes => $composableBuilder(
    column: $table.expectedSizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get downloadUrl => $composableBuilder(
    column: $table.downloadUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get allowedRedirectHostsJson => $composableBuilder(
    column: $table.allowedRedirectHostsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blobName => $composableBuilder(
    column: $table.blobName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetState => $composableBuilder(
    column: $table.assetState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get refCount => $composableBuilder(
    column: $table.refCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isTombstoned => $composableBuilder(
    column: $table.isTombstoned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DwOfflineAssetsTableOrderingComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineAssetsTable> {
  $$DwOfflineAssetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetRevision => $composableBuilder(
    column: $table.assetRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedSizeBytes => $composableBuilder(
    column: $table.expectedSizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get downloadUrl => $composableBuilder(
    column: $table.downloadUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get allowedRedirectHostsJson => $composableBuilder(
    column: $table.allowedRedirectHostsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blobName => $composableBuilder(
    column: $table.blobName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetState => $composableBuilder(
    column: $table.assetState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get refCount => $composableBuilder(
    column: $table.refCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isTombstoned => $composableBuilder(
    column: $table.isTombstoned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DwOfflineAssetsTableAnnotationComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineAssetsTable> {
  $$DwOfflineAssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<String> get assetRevision => $composableBuilder(
    column: $table.assetRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expectedSizeBytes => $composableBuilder(
    column: $table.expectedSizeBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get downloadUrl => $composableBuilder(
    column: $table.downloadUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get allowedRedirectHostsJson => $composableBuilder(
    column: $table.allowedRedirectHostsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get blobName =>
      $composableBuilder(column: $table.blobName, builder: (column) => column);

  GeneratedColumn<String> get assetState => $composableBuilder(
    column: $table.assetState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get refCount =>
      $composableBuilder(column: $table.refCount, builder: (column) => column);

  GeneratedColumn<bool> get isTombstoned => $composableBuilder(
    column: $table.isTombstoned,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => column,
  );
}

class $$DwOfflineAssetsTableTableManager
    extends
        RootTableManager<
          _$DwOfflineDatabase,
          $DwOfflineAssetsTable,
          DwOfflineAssetRow,
          $$DwOfflineAssetsTableFilterComposer,
          $$DwOfflineAssetsTableOrderingComposer,
          $$DwOfflineAssetsTableAnnotationComposer,
          $$DwOfflineAssetsTableCreateCompanionBuilder,
          $$DwOfflineAssetsTableUpdateCompanionBuilder,
          (
            DwOfflineAssetRow,
            BaseReferences<
              _$DwOfflineDatabase,
              $DwOfflineAssetsTable,
              DwOfflineAssetRow
            >,
          ),
          DwOfflineAssetRow,
          PrefetchHooks Function()
        > {
  $$DwOfflineAssetsTableTableManager(
    _$DwOfflineDatabase db,
    $DwOfflineAssetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DwOfflineAssetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DwOfflineAssetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DwOfflineAssetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userScopeId = const Value.absent(),
                Value<String> assetId = const Value.absent(),
                Value<String> assetRevision = const Value.absent(),
                Value<int> expectedSizeBytes = const Value.absent(),
                Value<String> checksum = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<String?> downloadUrl = const Value.absent(),
                Value<String?> allowedRedirectHostsJson = const Value.absent(),
                Value<String?> blobName = const Value.absent(),
                Value<String> assetState = const Value.absent(),
                Value<int> refCount = const Value.absent(),
                Value<bool> isTombstoned = const Value.absent(),
                Value<int> createdAtEpochMs = const Value.absent(),
                Value<int> updatedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DwOfflineAssetsCompanion(
                userScopeId: userScopeId,
                assetId: assetId,
                assetRevision: assetRevision,
                expectedSizeBytes: expectedSizeBytes,
                checksum: checksum,
                mimeType: mimeType,
                relativePath: relativePath,
                downloadUrl: downloadUrl,
                allowedRedirectHostsJson: allowedRedirectHostsJson,
                blobName: blobName,
                assetState: assetState,
                refCount: refCount,
                isTombstoned: isTombstoned,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userScopeId,
                required String assetId,
                required String assetRevision,
                required int expectedSizeBytes,
                required String checksum,
                required String mimeType,
                required String relativePath,
                Value<String?> downloadUrl = const Value.absent(),
                Value<String?> allowedRedirectHostsJson = const Value.absent(),
                Value<String?> blobName = const Value.absent(),
                required String assetState,
                Value<int> refCount = const Value.absent(),
                Value<bool> isTombstoned = const Value.absent(),
                required int createdAtEpochMs,
                required int updatedAtEpochMs,
                Value<int> rowid = const Value.absent(),
              }) => DwOfflineAssetsCompanion.insert(
                userScopeId: userScopeId,
                assetId: assetId,
                assetRevision: assetRevision,
                expectedSizeBytes: expectedSizeBytes,
                checksum: checksum,
                mimeType: mimeType,
                relativePath: relativePath,
                downloadUrl: downloadUrl,
                allowedRedirectHostsJson: allowedRedirectHostsJson,
                blobName: blobName,
                assetState: assetState,
                refCount: refCount,
                isTombstoned: isTombstoned,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DwOfflineAssetsTableProcessedTableManager =
    ProcessedTableManager<
      _$DwOfflineDatabase,
      $DwOfflineAssetsTable,
      DwOfflineAssetRow,
      $$DwOfflineAssetsTableFilterComposer,
      $$DwOfflineAssetsTableOrderingComposer,
      $$DwOfflineAssetsTableAnnotationComposer,
      $$DwOfflineAssetsTableCreateCompanionBuilder,
      $$DwOfflineAssetsTableUpdateCompanionBuilder,
      (
        DwOfflineAssetRow,
        BaseReferences<
          _$DwOfflineDatabase,
          $DwOfflineAssetsTable,
          DwOfflineAssetRow
        >,
      ),
      DwOfflineAssetRow,
      PrefetchHooks Function()
    >;
typedef $$DwOfflinePackageAssetsTableCreateCompanionBuilder =
    DwOfflinePackageAssetsCompanion Function({
      required String userScopeId,
      required String packageId,
      required String assetId,
      required String assetRevision,
      required bool isRequired,
      required int createdAtEpochMs,
      Value<int> rowid,
    });
typedef $$DwOfflinePackageAssetsTableUpdateCompanionBuilder =
    DwOfflinePackageAssetsCompanion Function({
      Value<String> userScopeId,
      Value<String> packageId,
      Value<String> assetId,
      Value<String> assetRevision,
      Value<bool> isRequired,
      Value<int> createdAtEpochMs,
      Value<int> rowid,
    });

class $$DwOfflinePackageAssetsTableFilterComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflinePackageAssetsTable> {
  $$DwOfflinePackageAssetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetRevision => $composableBuilder(
    column: $table.assetRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRequired => $composableBuilder(
    column: $table.isRequired,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DwOfflinePackageAssetsTableOrderingComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflinePackageAssetsTable> {
  $$DwOfflinePackageAssetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetRevision => $composableBuilder(
    column: $table.assetRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRequired => $composableBuilder(
    column: $table.isRequired,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DwOfflinePackageAssetsTableAnnotationComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflinePackageAssetsTable> {
  $$DwOfflinePackageAssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get packageId =>
      $composableBuilder(column: $table.packageId, builder: (column) => column);

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<String> get assetRevision => $composableBuilder(
    column: $table.assetRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isRequired => $composableBuilder(
    column: $table.isRequired,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => column,
  );
}

class $$DwOfflinePackageAssetsTableTableManager
    extends
        RootTableManager<
          _$DwOfflineDatabase,
          $DwOfflinePackageAssetsTable,
          DwOfflinePackageAssetRow,
          $$DwOfflinePackageAssetsTableFilterComposer,
          $$DwOfflinePackageAssetsTableOrderingComposer,
          $$DwOfflinePackageAssetsTableAnnotationComposer,
          $$DwOfflinePackageAssetsTableCreateCompanionBuilder,
          $$DwOfflinePackageAssetsTableUpdateCompanionBuilder,
          (
            DwOfflinePackageAssetRow,
            BaseReferences<
              _$DwOfflineDatabase,
              $DwOfflinePackageAssetsTable,
              DwOfflinePackageAssetRow
            >,
          ),
          DwOfflinePackageAssetRow,
          PrefetchHooks Function()
        > {
  $$DwOfflinePackageAssetsTableTableManager(
    _$DwOfflineDatabase db,
    $DwOfflinePackageAssetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DwOfflinePackageAssetsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DwOfflinePackageAssetsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DwOfflinePackageAssetsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userScopeId = const Value.absent(),
                Value<String> packageId = const Value.absent(),
                Value<String> assetId = const Value.absent(),
                Value<String> assetRevision = const Value.absent(),
                Value<bool> isRequired = const Value.absent(),
                Value<int> createdAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DwOfflinePackageAssetsCompanion(
                userScopeId: userScopeId,
                packageId: packageId,
                assetId: assetId,
                assetRevision: assetRevision,
                isRequired: isRequired,
                createdAtEpochMs: createdAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userScopeId,
                required String packageId,
                required String assetId,
                required String assetRevision,
                required bool isRequired,
                required int createdAtEpochMs,
                Value<int> rowid = const Value.absent(),
              }) => DwOfflinePackageAssetsCompanion.insert(
                userScopeId: userScopeId,
                packageId: packageId,
                assetId: assetId,
                assetRevision: assetRevision,
                isRequired: isRequired,
                createdAtEpochMs: createdAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DwOfflinePackageAssetsTableProcessedTableManager =
    ProcessedTableManager<
      _$DwOfflineDatabase,
      $DwOfflinePackageAssetsTable,
      DwOfflinePackageAssetRow,
      $$DwOfflinePackageAssetsTableFilterComposer,
      $$DwOfflinePackageAssetsTableOrderingComposer,
      $$DwOfflinePackageAssetsTableAnnotationComposer,
      $$DwOfflinePackageAssetsTableCreateCompanionBuilder,
      $$DwOfflinePackageAssetsTableUpdateCompanionBuilder,
      (
        DwOfflinePackageAssetRow,
        BaseReferences<
          _$DwOfflineDatabase,
          $DwOfflinePackageAssetsTable,
          DwOfflinePackageAssetRow
        >,
      ),
      DwOfflinePackageAssetRow,
      PrefetchHooks Function()
    >;
typedef $$DwOfflineJobsTableCreateCompanionBuilder =
    DwOfflineJobsCompanion Function({
      required String userScopeId,
      required String jobId,
      Value<String?> packageId,
      required String jobType,
      required String jobState,
      Value<String?> manifestRevision,
      Value<String?> manifestDigest,
      Value<int> priority,
      Value<int?> packageTotalBytes,
      Value<String?> consentedManifestDigest,
      Value<int?> nextEligibleAtEpochMs,
      Value<String?> pauseReason,
      required int attemptCount,
      required String payloadJson,
      Value<String?> lastErrorJson,
      required int createdAtEpochMs,
      required int updatedAtEpochMs,
      Value<int> rowid,
    });
typedef $$DwOfflineJobsTableUpdateCompanionBuilder =
    DwOfflineJobsCompanion Function({
      Value<String> userScopeId,
      Value<String> jobId,
      Value<String?> packageId,
      Value<String> jobType,
      Value<String> jobState,
      Value<String?> manifestRevision,
      Value<String?> manifestDigest,
      Value<int> priority,
      Value<int?> packageTotalBytes,
      Value<String?> consentedManifestDigest,
      Value<int?> nextEligibleAtEpochMs,
      Value<String?> pauseReason,
      Value<int> attemptCount,
      Value<String> payloadJson,
      Value<String?> lastErrorJson,
      Value<int> createdAtEpochMs,
      Value<int> updatedAtEpochMs,
      Value<int> rowid,
    });

class $$DwOfflineJobsTableFilterComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineJobsTable> {
  $$DwOfflineJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jobId => $composableBuilder(
    column: $table.jobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jobType => $composableBuilder(
    column: $table.jobType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jobState => $composableBuilder(
    column: $table.jobState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manifestRevision => $composableBuilder(
    column: $table.manifestRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manifestDigest => $composableBuilder(
    column: $table.manifestDigest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get packageTotalBytes => $composableBuilder(
    column: $table.packageTotalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get consentedManifestDigest => $composableBuilder(
    column: $table.consentedManifestDigest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextEligibleAtEpochMs => $composableBuilder(
    column: $table.nextEligibleAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pauseReason => $composableBuilder(
    column: $table.pauseReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorJson => $composableBuilder(
    column: $table.lastErrorJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DwOfflineJobsTableOrderingComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineJobsTable> {
  $$DwOfflineJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jobId => $composableBuilder(
    column: $table.jobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jobType => $composableBuilder(
    column: $table.jobType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jobState => $composableBuilder(
    column: $table.jobState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifestRevision => $composableBuilder(
    column: $table.manifestRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifestDigest => $composableBuilder(
    column: $table.manifestDigest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get packageTotalBytes => $composableBuilder(
    column: $table.packageTotalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get consentedManifestDigest => $composableBuilder(
    column: $table.consentedManifestDigest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextEligibleAtEpochMs => $composableBuilder(
    column: $table.nextEligibleAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pauseReason => $composableBuilder(
    column: $table.pauseReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorJson => $composableBuilder(
    column: $table.lastErrorJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DwOfflineJobsTableAnnotationComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineJobsTable> {
  $$DwOfflineJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get jobId =>
      $composableBuilder(column: $table.jobId, builder: (column) => column);

  GeneratedColumn<String> get packageId =>
      $composableBuilder(column: $table.packageId, builder: (column) => column);

  GeneratedColumn<String> get jobType =>
      $composableBuilder(column: $table.jobType, builder: (column) => column);

  GeneratedColumn<String> get jobState =>
      $composableBuilder(column: $table.jobState, builder: (column) => column);

  GeneratedColumn<String> get manifestRevision => $composableBuilder(
    column: $table.manifestRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get manifestDigest => $composableBuilder(
    column: $table.manifestDigest,
    builder: (column) => column,
  );

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get packageTotalBytes => $composableBuilder(
    column: $table.packageTotalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get consentedManifestDigest => $composableBuilder(
    column: $table.consentedManifestDigest,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextEligibleAtEpochMs => $composableBuilder(
    column: $table.nextEligibleAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pauseReason => $composableBuilder(
    column: $table.pauseReason,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorJson => $composableBuilder(
    column: $table.lastErrorJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => column,
  );
}

class $$DwOfflineJobsTableTableManager
    extends
        RootTableManager<
          _$DwOfflineDatabase,
          $DwOfflineJobsTable,
          DwOfflineJobRow,
          $$DwOfflineJobsTableFilterComposer,
          $$DwOfflineJobsTableOrderingComposer,
          $$DwOfflineJobsTableAnnotationComposer,
          $$DwOfflineJobsTableCreateCompanionBuilder,
          $$DwOfflineJobsTableUpdateCompanionBuilder,
          (
            DwOfflineJobRow,
            BaseReferences<
              _$DwOfflineDatabase,
              $DwOfflineJobsTable,
              DwOfflineJobRow
            >,
          ),
          DwOfflineJobRow,
          PrefetchHooks Function()
        > {
  $$DwOfflineJobsTableTableManager(
    _$DwOfflineDatabase db,
    $DwOfflineJobsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DwOfflineJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DwOfflineJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DwOfflineJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userScopeId = const Value.absent(),
                Value<String> jobId = const Value.absent(),
                Value<String?> packageId = const Value.absent(),
                Value<String> jobType = const Value.absent(),
                Value<String> jobState = const Value.absent(),
                Value<String?> manifestRevision = const Value.absent(),
                Value<String?> manifestDigest = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int?> packageTotalBytes = const Value.absent(),
                Value<String?> consentedManifestDigest = const Value.absent(),
                Value<int?> nextEligibleAtEpochMs = const Value.absent(),
                Value<String?> pauseReason = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String?> lastErrorJson = const Value.absent(),
                Value<int> createdAtEpochMs = const Value.absent(),
                Value<int> updatedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DwOfflineJobsCompanion(
                userScopeId: userScopeId,
                jobId: jobId,
                packageId: packageId,
                jobType: jobType,
                jobState: jobState,
                manifestRevision: manifestRevision,
                manifestDigest: manifestDigest,
                priority: priority,
                packageTotalBytes: packageTotalBytes,
                consentedManifestDigest: consentedManifestDigest,
                nextEligibleAtEpochMs: nextEligibleAtEpochMs,
                pauseReason: pauseReason,
                attemptCount: attemptCount,
                payloadJson: payloadJson,
                lastErrorJson: lastErrorJson,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userScopeId,
                required String jobId,
                Value<String?> packageId = const Value.absent(),
                required String jobType,
                required String jobState,
                Value<String?> manifestRevision = const Value.absent(),
                Value<String?> manifestDigest = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int?> packageTotalBytes = const Value.absent(),
                Value<String?> consentedManifestDigest = const Value.absent(),
                Value<int?> nextEligibleAtEpochMs = const Value.absent(),
                Value<String?> pauseReason = const Value.absent(),
                required int attemptCount,
                required String payloadJson,
                Value<String?> lastErrorJson = const Value.absent(),
                required int createdAtEpochMs,
                required int updatedAtEpochMs,
                Value<int> rowid = const Value.absent(),
              }) => DwOfflineJobsCompanion.insert(
                userScopeId: userScopeId,
                jobId: jobId,
                packageId: packageId,
                jobType: jobType,
                jobState: jobState,
                manifestRevision: manifestRevision,
                manifestDigest: manifestDigest,
                priority: priority,
                packageTotalBytes: packageTotalBytes,
                consentedManifestDigest: consentedManifestDigest,
                nextEligibleAtEpochMs: nextEligibleAtEpochMs,
                pauseReason: pauseReason,
                attemptCount: attemptCount,
                payloadJson: payloadJson,
                lastErrorJson: lastErrorJson,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DwOfflineJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$DwOfflineDatabase,
      $DwOfflineJobsTable,
      DwOfflineJobRow,
      $$DwOfflineJobsTableFilterComposer,
      $$DwOfflineJobsTableOrderingComposer,
      $$DwOfflineJobsTableAnnotationComposer,
      $$DwOfflineJobsTableCreateCompanionBuilder,
      $$DwOfflineJobsTableUpdateCompanionBuilder,
      (
        DwOfflineJobRow,
        BaseReferences<
          _$DwOfflineDatabase,
          $DwOfflineJobsTable,
          DwOfflineJobRow
        >,
      ),
      DwOfflineJobRow,
      PrefetchHooks Function()
    >;
typedef $$DwOfflineDownloadTasksTableCreateCompanionBuilder =
    DwOfflineDownloadTasksCompanion Function({
      required String userScopeId,
      required String jobId,
      required String assetId,
      required String assetRevision,
      Value<bool> isRequired,
      required String taskState,
      Value<String?> nativeTaskId,
      Value<String?> temporaryFilePath,
      Value<int> transferredBytes,
      required int attemptCount,
      Value<int?> nextEligibleAtEpochMs,
      Value<String?> lastErrorJson,
      required int createdAtEpochMs,
      required int updatedAtEpochMs,
      Value<int> rowid,
    });
typedef $$DwOfflineDownloadTasksTableUpdateCompanionBuilder =
    DwOfflineDownloadTasksCompanion Function({
      Value<String> userScopeId,
      Value<String> jobId,
      Value<String> assetId,
      Value<String> assetRevision,
      Value<bool> isRequired,
      Value<String> taskState,
      Value<String?> nativeTaskId,
      Value<String?> temporaryFilePath,
      Value<int> transferredBytes,
      Value<int> attemptCount,
      Value<int?> nextEligibleAtEpochMs,
      Value<String?> lastErrorJson,
      Value<int> createdAtEpochMs,
      Value<int> updatedAtEpochMs,
      Value<int> rowid,
    });

class $$DwOfflineDownloadTasksTableFilterComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineDownloadTasksTable> {
  $$DwOfflineDownloadTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jobId => $composableBuilder(
    column: $table.jobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetRevision => $composableBuilder(
    column: $table.assetRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRequired => $composableBuilder(
    column: $table.isRequired,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskState => $composableBuilder(
    column: $table.taskState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nativeTaskId => $composableBuilder(
    column: $table.nativeTaskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get temporaryFilePath => $composableBuilder(
    column: $table.temporaryFilePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get transferredBytes => $composableBuilder(
    column: $table.transferredBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextEligibleAtEpochMs => $composableBuilder(
    column: $table.nextEligibleAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorJson => $composableBuilder(
    column: $table.lastErrorJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DwOfflineDownloadTasksTableOrderingComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineDownloadTasksTable> {
  $$DwOfflineDownloadTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jobId => $composableBuilder(
    column: $table.jobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetRevision => $composableBuilder(
    column: $table.assetRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRequired => $composableBuilder(
    column: $table.isRequired,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskState => $composableBuilder(
    column: $table.taskState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nativeTaskId => $composableBuilder(
    column: $table.nativeTaskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get temporaryFilePath => $composableBuilder(
    column: $table.temporaryFilePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get transferredBytes => $composableBuilder(
    column: $table.transferredBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextEligibleAtEpochMs => $composableBuilder(
    column: $table.nextEligibleAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorJson => $composableBuilder(
    column: $table.lastErrorJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DwOfflineDownloadTasksTableAnnotationComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineDownloadTasksTable> {
  $$DwOfflineDownloadTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get jobId =>
      $composableBuilder(column: $table.jobId, builder: (column) => column);

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<String> get assetRevision => $composableBuilder(
    column: $table.assetRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isRequired => $composableBuilder(
    column: $table.isRequired,
    builder: (column) => column,
  );

  GeneratedColumn<String> get taskState =>
      $composableBuilder(column: $table.taskState, builder: (column) => column);

  GeneratedColumn<String> get nativeTaskId => $composableBuilder(
    column: $table.nativeTaskId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get temporaryFilePath => $composableBuilder(
    column: $table.temporaryFilePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get transferredBytes => $composableBuilder(
    column: $table.transferredBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextEligibleAtEpochMs => $composableBuilder(
    column: $table.nextEligibleAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorJson => $composableBuilder(
    column: $table.lastErrorJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => column,
  );
}

class $$DwOfflineDownloadTasksTableTableManager
    extends
        RootTableManager<
          _$DwOfflineDatabase,
          $DwOfflineDownloadTasksTable,
          DwOfflineDownloadTaskRow,
          $$DwOfflineDownloadTasksTableFilterComposer,
          $$DwOfflineDownloadTasksTableOrderingComposer,
          $$DwOfflineDownloadTasksTableAnnotationComposer,
          $$DwOfflineDownloadTasksTableCreateCompanionBuilder,
          $$DwOfflineDownloadTasksTableUpdateCompanionBuilder,
          (
            DwOfflineDownloadTaskRow,
            BaseReferences<
              _$DwOfflineDatabase,
              $DwOfflineDownloadTasksTable,
              DwOfflineDownloadTaskRow
            >,
          ),
          DwOfflineDownloadTaskRow,
          PrefetchHooks Function()
        > {
  $$DwOfflineDownloadTasksTableTableManager(
    _$DwOfflineDatabase db,
    $DwOfflineDownloadTasksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DwOfflineDownloadTasksTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DwOfflineDownloadTasksTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DwOfflineDownloadTasksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userScopeId = const Value.absent(),
                Value<String> jobId = const Value.absent(),
                Value<String> assetId = const Value.absent(),
                Value<String> assetRevision = const Value.absent(),
                Value<bool> isRequired = const Value.absent(),
                Value<String> taskState = const Value.absent(),
                Value<String?> nativeTaskId = const Value.absent(),
                Value<String?> temporaryFilePath = const Value.absent(),
                Value<int> transferredBytes = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<int?> nextEligibleAtEpochMs = const Value.absent(),
                Value<String?> lastErrorJson = const Value.absent(),
                Value<int> createdAtEpochMs = const Value.absent(),
                Value<int> updatedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DwOfflineDownloadTasksCompanion(
                userScopeId: userScopeId,
                jobId: jobId,
                assetId: assetId,
                assetRevision: assetRevision,
                isRequired: isRequired,
                taskState: taskState,
                nativeTaskId: nativeTaskId,
                temporaryFilePath: temporaryFilePath,
                transferredBytes: transferredBytes,
                attemptCount: attemptCount,
                nextEligibleAtEpochMs: nextEligibleAtEpochMs,
                lastErrorJson: lastErrorJson,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userScopeId,
                required String jobId,
                required String assetId,
                required String assetRevision,
                Value<bool> isRequired = const Value.absent(),
                required String taskState,
                Value<String?> nativeTaskId = const Value.absent(),
                Value<String?> temporaryFilePath = const Value.absent(),
                Value<int> transferredBytes = const Value.absent(),
                required int attemptCount,
                Value<int?> nextEligibleAtEpochMs = const Value.absent(),
                Value<String?> lastErrorJson = const Value.absent(),
                required int createdAtEpochMs,
                required int updatedAtEpochMs,
                Value<int> rowid = const Value.absent(),
              }) => DwOfflineDownloadTasksCompanion.insert(
                userScopeId: userScopeId,
                jobId: jobId,
                assetId: assetId,
                assetRevision: assetRevision,
                isRequired: isRequired,
                taskState: taskState,
                nativeTaskId: nativeTaskId,
                temporaryFilePath: temporaryFilePath,
                transferredBytes: transferredBytes,
                attemptCount: attemptCount,
                nextEligibleAtEpochMs: nextEligibleAtEpochMs,
                lastErrorJson: lastErrorJson,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DwOfflineDownloadTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$DwOfflineDatabase,
      $DwOfflineDownloadTasksTable,
      DwOfflineDownloadTaskRow,
      $$DwOfflineDownloadTasksTableFilterComposer,
      $$DwOfflineDownloadTasksTableOrderingComposer,
      $$DwOfflineDownloadTasksTableAnnotationComposer,
      $$DwOfflineDownloadTasksTableCreateCompanionBuilder,
      $$DwOfflineDownloadTasksTableUpdateCompanionBuilder,
      (
        DwOfflineDownloadTaskRow,
        BaseReferences<
          _$DwOfflineDatabase,
          $DwOfflineDownloadTasksTable,
          DwOfflineDownloadTaskRow
        >,
      ),
      DwOfflineDownloadTaskRow,
      PrefetchHooks Function()
    >;
typedef $$DwOfflineSnapshotsTableCreateCompanionBuilder =
    DwOfflineSnapshotsCompanion Function({
      required String userScopeId,
      required String queryKey,
      required String envelopeJson,
      required int capturedAtEpochMs,
      Value<int?> expiresAtEpochMs,
      Value<int> rowid,
    });
typedef $$DwOfflineSnapshotsTableUpdateCompanionBuilder =
    DwOfflineSnapshotsCompanion Function({
      Value<String> userScopeId,
      Value<String> queryKey,
      Value<String> envelopeJson,
      Value<int> capturedAtEpochMs,
      Value<int?> expiresAtEpochMs,
      Value<int> rowid,
    });

class $$DwOfflineSnapshotsTableFilterComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineSnapshotsTable> {
  $$DwOfflineSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get queryKey => $composableBuilder(
    column: $table.queryKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedAtEpochMs => $composableBuilder(
    column: $table.capturedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresAtEpochMs => $composableBuilder(
    column: $table.expiresAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DwOfflineSnapshotsTableOrderingComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineSnapshotsTable> {
  $$DwOfflineSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get queryKey => $composableBuilder(
    column: $table.queryKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedAtEpochMs => $composableBuilder(
    column: $table.capturedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAtEpochMs => $composableBuilder(
    column: $table.expiresAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DwOfflineSnapshotsTableAnnotationComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineSnapshotsTable> {
  $$DwOfflineSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get queryKey =>
      $composableBuilder(column: $table.queryKey, builder: (column) => column);

  GeneratedColumn<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get capturedAtEpochMs => $composableBuilder(
    column: $table.capturedAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expiresAtEpochMs => $composableBuilder(
    column: $table.expiresAtEpochMs,
    builder: (column) => column,
  );
}

class $$DwOfflineSnapshotsTableTableManager
    extends
        RootTableManager<
          _$DwOfflineDatabase,
          $DwOfflineSnapshotsTable,
          DwOfflineSnapshotRow,
          $$DwOfflineSnapshotsTableFilterComposer,
          $$DwOfflineSnapshotsTableOrderingComposer,
          $$DwOfflineSnapshotsTableAnnotationComposer,
          $$DwOfflineSnapshotsTableCreateCompanionBuilder,
          $$DwOfflineSnapshotsTableUpdateCompanionBuilder,
          (
            DwOfflineSnapshotRow,
            BaseReferences<
              _$DwOfflineDatabase,
              $DwOfflineSnapshotsTable,
              DwOfflineSnapshotRow
            >,
          ),
          DwOfflineSnapshotRow,
          PrefetchHooks Function()
        > {
  $$DwOfflineSnapshotsTableTableManager(
    _$DwOfflineDatabase db,
    $DwOfflineSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DwOfflineSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DwOfflineSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DwOfflineSnapshotsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userScopeId = const Value.absent(),
                Value<String> queryKey = const Value.absent(),
                Value<String> envelopeJson = const Value.absent(),
                Value<int> capturedAtEpochMs = const Value.absent(),
                Value<int?> expiresAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DwOfflineSnapshotsCompanion(
                userScopeId: userScopeId,
                queryKey: queryKey,
                envelopeJson: envelopeJson,
                capturedAtEpochMs: capturedAtEpochMs,
                expiresAtEpochMs: expiresAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userScopeId,
                required String queryKey,
                required String envelopeJson,
                required int capturedAtEpochMs,
                Value<int?> expiresAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DwOfflineSnapshotsCompanion.insert(
                userScopeId: userScopeId,
                queryKey: queryKey,
                envelopeJson: envelopeJson,
                capturedAtEpochMs: capturedAtEpochMs,
                expiresAtEpochMs: expiresAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DwOfflineSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$DwOfflineDatabase,
      $DwOfflineSnapshotsTable,
      DwOfflineSnapshotRow,
      $$DwOfflineSnapshotsTableFilterComposer,
      $$DwOfflineSnapshotsTableOrderingComposer,
      $$DwOfflineSnapshotsTableAnnotationComposer,
      $$DwOfflineSnapshotsTableCreateCompanionBuilder,
      $$DwOfflineSnapshotsTableUpdateCompanionBuilder,
      (
        DwOfflineSnapshotRow,
        BaseReferences<
          _$DwOfflineDatabase,
          $DwOfflineSnapshotsTable,
          DwOfflineSnapshotRow
        >,
      ),
      DwOfflineSnapshotRow,
      PrefetchHooks Function()
    >;
typedef $$DwOfflineOutboxTableCreateCompanionBuilder =
    DwOfflineOutboxCompanion Function({
      required String userScopeId,
      required String mutationId,
      required String entityType,
      required String entityId,
      required String mutationType,
      required String idempotencyKey,
      required String envelopeJson,
      required int createdAtEpochMs,
      required int updatedAtEpochMs,
      Value<int> rowid,
    });
typedef $$DwOfflineOutboxTableUpdateCompanionBuilder =
    DwOfflineOutboxCompanion Function({
      Value<String> userScopeId,
      Value<String> mutationId,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> mutationType,
      Value<String> idempotencyKey,
      Value<String> envelopeJson,
      Value<int> createdAtEpochMs,
      Value<int> updatedAtEpochMs,
      Value<int> rowid,
    });

class $$DwOfflineOutboxTableFilterComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineOutboxTable> {
  $$DwOfflineOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mutationType => $composableBuilder(
    column: $table.mutationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DwOfflineOutboxTableOrderingComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineOutboxTable> {
  $$DwOfflineOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mutationType => $composableBuilder(
    column: $table.mutationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DwOfflineOutboxTableAnnotationComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineOutboxTable> {
  $$DwOfflineOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get mutationType => $composableBuilder(
    column: $table.mutationType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => column,
  );
}

class $$DwOfflineOutboxTableTableManager
    extends
        RootTableManager<
          _$DwOfflineDatabase,
          $DwOfflineOutboxTable,
          DwOfflineOutboxRow,
          $$DwOfflineOutboxTableFilterComposer,
          $$DwOfflineOutboxTableOrderingComposer,
          $$DwOfflineOutboxTableAnnotationComposer,
          $$DwOfflineOutboxTableCreateCompanionBuilder,
          $$DwOfflineOutboxTableUpdateCompanionBuilder,
          (
            DwOfflineOutboxRow,
            BaseReferences<
              _$DwOfflineDatabase,
              $DwOfflineOutboxTable,
              DwOfflineOutboxRow
            >,
          ),
          DwOfflineOutboxRow,
          PrefetchHooks Function()
        > {
  $$DwOfflineOutboxTableTableManager(
    _$DwOfflineDatabase db,
    $DwOfflineOutboxTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DwOfflineOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DwOfflineOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DwOfflineOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userScopeId = const Value.absent(),
                Value<String> mutationId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> mutationType = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<String> envelopeJson = const Value.absent(),
                Value<int> createdAtEpochMs = const Value.absent(),
                Value<int> updatedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DwOfflineOutboxCompanion(
                userScopeId: userScopeId,
                mutationId: mutationId,
                entityType: entityType,
                entityId: entityId,
                mutationType: mutationType,
                idempotencyKey: idempotencyKey,
                envelopeJson: envelopeJson,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userScopeId,
                required String mutationId,
                required String entityType,
                required String entityId,
                required String mutationType,
                required String idempotencyKey,
                required String envelopeJson,
                required int createdAtEpochMs,
                required int updatedAtEpochMs,
                Value<int> rowid = const Value.absent(),
              }) => DwOfflineOutboxCompanion.insert(
                userScopeId: userScopeId,
                mutationId: mutationId,
                entityType: entityType,
                entityId: entityId,
                mutationType: mutationType,
                idempotencyKey: idempotencyKey,
                envelopeJson: envelopeJson,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DwOfflineOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$DwOfflineDatabase,
      $DwOfflineOutboxTable,
      DwOfflineOutboxRow,
      $$DwOfflineOutboxTableFilterComposer,
      $$DwOfflineOutboxTableOrderingComposer,
      $$DwOfflineOutboxTableAnnotationComposer,
      $$DwOfflineOutboxTableCreateCompanionBuilder,
      $$DwOfflineOutboxTableUpdateCompanionBuilder,
      (
        DwOfflineOutboxRow,
        BaseReferences<
          _$DwOfflineDatabase,
          $DwOfflineOutboxTable,
          DwOfflineOutboxRow
        >,
      ),
      DwOfflineOutboxRow,
      PrefetchHooks Function()
    >;
typedef $$DwOfflineManifestsTableCreateCompanionBuilder =
    DwOfflineManifestsCompanion Function({
      required String userScopeId,
      required String packageId,
      required String manifestRevision,
      required String payloadDigest,
      required String envelopeJson,
      required Uint8List payloadBytes,
      required int createdAtEpochMs,
      Value<int> rowid,
    });
typedef $$DwOfflineManifestsTableUpdateCompanionBuilder =
    DwOfflineManifestsCompanion Function({
      Value<String> userScopeId,
      Value<String> packageId,
      Value<String> manifestRevision,
      Value<String> payloadDigest,
      Value<String> envelopeJson,
      Value<Uint8List> payloadBytes,
      Value<int> createdAtEpochMs,
      Value<int> rowid,
    });

class $$DwOfflineManifestsTableFilterComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineManifestsTable> {
  $$DwOfflineManifestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manifestRevision => $composableBuilder(
    column: $table.manifestRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadDigest => $composableBuilder(
    column: $table.payloadDigest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get payloadBytes => $composableBuilder(
    column: $table.payloadBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DwOfflineManifestsTableOrderingComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineManifestsTable> {
  $$DwOfflineManifestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifestRevision => $composableBuilder(
    column: $table.manifestRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadDigest => $composableBuilder(
    column: $table.payloadDigest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get payloadBytes => $composableBuilder(
    column: $table.payloadBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DwOfflineManifestsTableAnnotationComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineManifestsTable> {
  $$DwOfflineManifestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get packageId =>
      $composableBuilder(column: $table.packageId, builder: (column) => column);

  GeneratedColumn<String> get manifestRevision => $composableBuilder(
    column: $table.manifestRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadDigest => $composableBuilder(
    column: $table.payloadDigest,
    builder: (column) => column,
  );

  GeneratedColumn<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get payloadBytes => $composableBuilder(
    column: $table.payloadBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => column,
  );
}

class $$DwOfflineManifestsTableTableManager
    extends
        RootTableManager<
          _$DwOfflineDatabase,
          $DwOfflineManifestsTable,
          DwOfflineManifestRow,
          $$DwOfflineManifestsTableFilterComposer,
          $$DwOfflineManifestsTableOrderingComposer,
          $$DwOfflineManifestsTableAnnotationComposer,
          $$DwOfflineManifestsTableCreateCompanionBuilder,
          $$DwOfflineManifestsTableUpdateCompanionBuilder,
          (
            DwOfflineManifestRow,
            BaseReferences<
              _$DwOfflineDatabase,
              $DwOfflineManifestsTable,
              DwOfflineManifestRow
            >,
          ),
          DwOfflineManifestRow,
          PrefetchHooks Function()
        > {
  $$DwOfflineManifestsTableTableManager(
    _$DwOfflineDatabase db,
    $DwOfflineManifestsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DwOfflineManifestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DwOfflineManifestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DwOfflineManifestsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userScopeId = const Value.absent(),
                Value<String> packageId = const Value.absent(),
                Value<String> manifestRevision = const Value.absent(),
                Value<String> payloadDigest = const Value.absent(),
                Value<String> envelopeJson = const Value.absent(),
                Value<Uint8List> payloadBytes = const Value.absent(),
                Value<int> createdAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DwOfflineManifestsCompanion(
                userScopeId: userScopeId,
                packageId: packageId,
                manifestRevision: manifestRevision,
                payloadDigest: payloadDigest,
                envelopeJson: envelopeJson,
                payloadBytes: payloadBytes,
                createdAtEpochMs: createdAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userScopeId,
                required String packageId,
                required String manifestRevision,
                required String payloadDigest,
                required String envelopeJson,
                required Uint8List payloadBytes,
                required int createdAtEpochMs,
                Value<int> rowid = const Value.absent(),
              }) => DwOfflineManifestsCompanion.insert(
                userScopeId: userScopeId,
                packageId: packageId,
                manifestRevision: manifestRevision,
                payloadDigest: payloadDigest,
                envelopeJson: envelopeJson,
                payloadBytes: payloadBytes,
                createdAtEpochMs: createdAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DwOfflineManifestsTableProcessedTableManager =
    ProcessedTableManager<
      _$DwOfflineDatabase,
      $DwOfflineManifestsTable,
      DwOfflineManifestRow,
      $$DwOfflineManifestsTableFilterComposer,
      $$DwOfflineManifestsTableOrderingComposer,
      $$DwOfflineManifestsTableAnnotationComposer,
      $$DwOfflineManifestsTableCreateCompanionBuilder,
      $$DwOfflineManifestsTableUpdateCompanionBuilder,
      (
        DwOfflineManifestRow,
        BaseReferences<
          _$DwOfflineDatabase,
          $DwOfflineManifestsTable,
          DwOfflineManifestRow
        >,
      ),
      DwOfflineManifestRow,
      PrefetchHooks Function()
    >;
typedef $$DwOfflinePackageSnapshotsTableCreateCompanionBuilder =
    DwOfflinePackageSnapshotsCompanion Function({
      required String userScopeId,
      required String packageId,
      required String manifestRevision,
      required String queryKey,
      required String envelopeJson,
      required int capturedAtEpochMs,
      Value<int> rowid,
    });
typedef $$DwOfflinePackageSnapshotsTableUpdateCompanionBuilder =
    DwOfflinePackageSnapshotsCompanion Function({
      Value<String> userScopeId,
      Value<String> packageId,
      Value<String> manifestRevision,
      Value<String> queryKey,
      Value<String> envelopeJson,
      Value<int> capturedAtEpochMs,
      Value<int> rowid,
    });

class $$DwOfflinePackageSnapshotsTableFilterComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflinePackageSnapshotsTable> {
  $$DwOfflinePackageSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manifestRevision => $composableBuilder(
    column: $table.manifestRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get queryKey => $composableBuilder(
    column: $table.queryKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedAtEpochMs => $composableBuilder(
    column: $table.capturedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DwOfflinePackageSnapshotsTableOrderingComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflinePackageSnapshotsTable> {
  $$DwOfflinePackageSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifestRevision => $composableBuilder(
    column: $table.manifestRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get queryKey => $composableBuilder(
    column: $table.queryKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedAtEpochMs => $composableBuilder(
    column: $table.capturedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DwOfflinePackageSnapshotsTableAnnotationComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflinePackageSnapshotsTable> {
  $$DwOfflinePackageSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get packageId =>
      $composableBuilder(column: $table.packageId, builder: (column) => column);

  GeneratedColumn<String> get manifestRevision => $composableBuilder(
    column: $table.manifestRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get queryKey =>
      $composableBuilder(column: $table.queryKey, builder: (column) => column);

  GeneratedColumn<String> get envelopeJson => $composableBuilder(
    column: $table.envelopeJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get capturedAtEpochMs => $composableBuilder(
    column: $table.capturedAtEpochMs,
    builder: (column) => column,
  );
}

class $$DwOfflinePackageSnapshotsTableTableManager
    extends
        RootTableManager<
          _$DwOfflineDatabase,
          $DwOfflinePackageSnapshotsTable,
          DwOfflinePackageSnapshotRow,
          $$DwOfflinePackageSnapshotsTableFilterComposer,
          $$DwOfflinePackageSnapshotsTableOrderingComposer,
          $$DwOfflinePackageSnapshotsTableAnnotationComposer,
          $$DwOfflinePackageSnapshotsTableCreateCompanionBuilder,
          $$DwOfflinePackageSnapshotsTableUpdateCompanionBuilder,
          (
            DwOfflinePackageSnapshotRow,
            BaseReferences<
              _$DwOfflineDatabase,
              $DwOfflinePackageSnapshotsTable,
              DwOfflinePackageSnapshotRow
            >,
          ),
          DwOfflinePackageSnapshotRow,
          PrefetchHooks Function()
        > {
  $$DwOfflinePackageSnapshotsTableTableManager(
    _$DwOfflineDatabase db,
    $DwOfflinePackageSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DwOfflinePackageSnapshotsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DwOfflinePackageSnapshotsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DwOfflinePackageSnapshotsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userScopeId = const Value.absent(),
                Value<String> packageId = const Value.absent(),
                Value<String> manifestRevision = const Value.absent(),
                Value<String> queryKey = const Value.absent(),
                Value<String> envelopeJson = const Value.absent(),
                Value<int> capturedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DwOfflinePackageSnapshotsCompanion(
                userScopeId: userScopeId,
                packageId: packageId,
                manifestRevision: manifestRevision,
                queryKey: queryKey,
                envelopeJson: envelopeJson,
                capturedAtEpochMs: capturedAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userScopeId,
                required String packageId,
                required String manifestRevision,
                required String queryKey,
                required String envelopeJson,
                required int capturedAtEpochMs,
                Value<int> rowid = const Value.absent(),
              }) => DwOfflinePackageSnapshotsCompanion.insert(
                userScopeId: userScopeId,
                packageId: packageId,
                manifestRevision: manifestRevision,
                queryKey: queryKey,
                envelopeJson: envelopeJson,
                capturedAtEpochMs: capturedAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DwOfflinePackageSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$DwOfflineDatabase,
      $DwOfflinePackageSnapshotsTable,
      DwOfflinePackageSnapshotRow,
      $$DwOfflinePackageSnapshotsTableFilterComposer,
      $$DwOfflinePackageSnapshotsTableOrderingComposer,
      $$DwOfflinePackageSnapshotsTableAnnotationComposer,
      $$DwOfflinePackageSnapshotsTableCreateCompanionBuilder,
      $$DwOfflinePackageSnapshotsTableUpdateCompanionBuilder,
      (
        DwOfflinePackageSnapshotRow,
        BaseReferences<
          _$DwOfflineDatabase,
          $DwOfflinePackageSnapshotsTable,
          DwOfflinePackageSnapshotRow
        >,
      ),
      DwOfflinePackageSnapshotRow,
      PrefetchHooks Function()
    >;
typedef $$DwOfflineLeasesTableCreateCompanionBuilder =
    DwOfflineLeasesCompanion Function({
      required String userScopeId,
      required String leaseId,
      required String leaseEnvelopeJson,
      required int trustedAtEpochMs,
      required int expiresAtEpochMs,
      Value<int> rowid,
    });
typedef $$DwOfflineLeasesTableUpdateCompanionBuilder =
    DwOfflineLeasesCompanion Function({
      Value<String> userScopeId,
      Value<String> leaseId,
      Value<String> leaseEnvelopeJson,
      Value<int> trustedAtEpochMs,
      Value<int> expiresAtEpochMs,
      Value<int> rowid,
    });

class $$DwOfflineLeasesTableFilterComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineLeasesTable> {
  $$DwOfflineLeasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leaseId => $composableBuilder(
    column: $table.leaseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leaseEnvelopeJson => $composableBuilder(
    column: $table.leaseEnvelopeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trustedAtEpochMs => $composableBuilder(
    column: $table.trustedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresAtEpochMs => $composableBuilder(
    column: $table.expiresAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DwOfflineLeasesTableOrderingComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineLeasesTable> {
  $$DwOfflineLeasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leaseId => $composableBuilder(
    column: $table.leaseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leaseEnvelopeJson => $composableBuilder(
    column: $table.leaseEnvelopeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trustedAtEpochMs => $composableBuilder(
    column: $table.trustedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAtEpochMs => $composableBuilder(
    column: $table.expiresAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DwOfflineLeasesTableAnnotationComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineLeasesTable> {
  $$DwOfflineLeasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get leaseId =>
      $composableBuilder(column: $table.leaseId, builder: (column) => column);

  GeneratedColumn<String> get leaseEnvelopeJson => $composableBuilder(
    column: $table.leaseEnvelopeJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get trustedAtEpochMs => $composableBuilder(
    column: $table.trustedAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expiresAtEpochMs => $composableBuilder(
    column: $table.expiresAtEpochMs,
    builder: (column) => column,
  );
}

class $$DwOfflineLeasesTableTableManager
    extends
        RootTableManager<
          _$DwOfflineDatabase,
          $DwOfflineLeasesTable,
          DwOfflineLeaseRow,
          $$DwOfflineLeasesTableFilterComposer,
          $$DwOfflineLeasesTableOrderingComposer,
          $$DwOfflineLeasesTableAnnotationComposer,
          $$DwOfflineLeasesTableCreateCompanionBuilder,
          $$DwOfflineLeasesTableUpdateCompanionBuilder,
          (
            DwOfflineLeaseRow,
            BaseReferences<
              _$DwOfflineDatabase,
              $DwOfflineLeasesTable,
              DwOfflineLeaseRow
            >,
          ),
          DwOfflineLeaseRow,
          PrefetchHooks Function()
        > {
  $$DwOfflineLeasesTableTableManager(
    _$DwOfflineDatabase db,
    $DwOfflineLeasesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DwOfflineLeasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DwOfflineLeasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DwOfflineLeasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userScopeId = const Value.absent(),
                Value<String> leaseId = const Value.absent(),
                Value<String> leaseEnvelopeJson = const Value.absent(),
                Value<int> trustedAtEpochMs = const Value.absent(),
                Value<int> expiresAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DwOfflineLeasesCompanion(
                userScopeId: userScopeId,
                leaseId: leaseId,
                leaseEnvelopeJson: leaseEnvelopeJson,
                trustedAtEpochMs: trustedAtEpochMs,
                expiresAtEpochMs: expiresAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userScopeId,
                required String leaseId,
                required String leaseEnvelopeJson,
                required int trustedAtEpochMs,
                required int expiresAtEpochMs,
                Value<int> rowid = const Value.absent(),
              }) => DwOfflineLeasesCompanion.insert(
                userScopeId: userScopeId,
                leaseId: leaseId,
                leaseEnvelopeJson: leaseEnvelopeJson,
                trustedAtEpochMs: trustedAtEpochMs,
                expiresAtEpochMs: expiresAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DwOfflineLeasesTableProcessedTableManager =
    ProcessedTableManager<
      _$DwOfflineDatabase,
      $DwOfflineLeasesTable,
      DwOfflineLeaseRow,
      $$DwOfflineLeasesTableFilterComposer,
      $$DwOfflineLeasesTableOrderingComposer,
      $$DwOfflineLeasesTableAnnotationComposer,
      $$DwOfflineLeasesTableCreateCompanionBuilder,
      $$DwOfflineLeasesTableUpdateCompanionBuilder,
      (
        DwOfflineLeaseRow,
        BaseReferences<
          _$DwOfflineDatabase,
          $DwOfflineLeasesTable,
          DwOfflineLeaseRow
        >,
      ),
      DwOfflineLeaseRow,
      PrefetchHooks Function()
    >;
typedef $$DwOfflineReaderPinsTableCreateCompanionBuilder =
    DwOfflineReaderPinsCompanion Function({
      required String userScopeId,
      required String readerId,
      required String assetId,
      required String assetRevision,
      required int pinnedAtEpochMs,
      Value<int> rowid,
    });
typedef $$DwOfflineReaderPinsTableUpdateCompanionBuilder =
    DwOfflineReaderPinsCompanion Function({
      Value<String> userScopeId,
      Value<String> readerId,
      Value<String> assetId,
      Value<String> assetRevision,
      Value<int> pinnedAtEpochMs,
      Value<int> rowid,
    });

class $$DwOfflineReaderPinsTableFilterComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineReaderPinsTable> {
  $$DwOfflineReaderPinsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readerId => $composableBuilder(
    column: $table.readerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetRevision => $composableBuilder(
    column: $table.assetRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pinnedAtEpochMs => $composableBuilder(
    column: $table.pinnedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DwOfflineReaderPinsTableOrderingComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineReaderPinsTable> {
  $$DwOfflineReaderPinsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readerId => $composableBuilder(
    column: $table.readerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetRevision => $composableBuilder(
    column: $table.assetRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pinnedAtEpochMs => $composableBuilder(
    column: $table.pinnedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DwOfflineReaderPinsTableAnnotationComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineReaderPinsTable> {
  $$DwOfflineReaderPinsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get readerId =>
      $composableBuilder(column: $table.readerId, builder: (column) => column);

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<String> get assetRevision => $composableBuilder(
    column: $table.assetRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pinnedAtEpochMs => $composableBuilder(
    column: $table.pinnedAtEpochMs,
    builder: (column) => column,
  );
}

class $$DwOfflineReaderPinsTableTableManager
    extends
        RootTableManager<
          _$DwOfflineDatabase,
          $DwOfflineReaderPinsTable,
          DwOfflineReaderPinRow,
          $$DwOfflineReaderPinsTableFilterComposer,
          $$DwOfflineReaderPinsTableOrderingComposer,
          $$DwOfflineReaderPinsTableAnnotationComposer,
          $$DwOfflineReaderPinsTableCreateCompanionBuilder,
          $$DwOfflineReaderPinsTableUpdateCompanionBuilder,
          (
            DwOfflineReaderPinRow,
            BaseReferences<
              _$DwOfflineDatabase,
              $DwOfflineReaderPinsTable,
              DwOfflineReaderPinRow
            >,
          ),
          DwOfflineReaderPinRow,
          PrefetchHooks Function()
        > {
  $$DwOfflineReaderPinsTableTableManager(
    _$DwOfflineDatabase db,
    $DwOfflineReaderPinsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DwOfflineReaderPinsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DwOfflineReaderPinsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DwOfflineReaderPinsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userScopeId = const Value.absent(),
                Value<String> readerId = const Value.absent(),
                Value<String> assetId = const Value.absent(),
                Value<String> assetRevision = const Value.absent(),
                Value<int> pinnedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DwOfflineReaderPinsCompanion(
                userScopeId: userScopeId,
                readerId: readerId,
                assetId: assetId,
                assetRevision: assetRevision,
                pinnedAtEpochMs: pinnedAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userScopeId,
                required String readerId,
                required String assetId,
                required String assetRevision,
                required int pinnedAtEpochMs,
                Value<int> rowid = const Value.absent(),
              }) => DwOfflineReaderPinsCompanion.insert(
                userScopeId: userScopeId,
                readerId: readerId,
                assetId: assetId,
                assetRevision: assetRevision,
                pinnedAtEpochMs: pinnedAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DwOfflineReaderPinsTableProcessedTableManager =
    ProcessedTableManager<
      _$DwOfflineDatabase,
      $DwOfflineReaderPinsTable,
      DwOfflineReaderPinRow,
      $$DwOfflineReaderPinsTableFilterComposer,
      $$DwOfflineReaderPinsTableOrderingComposer,
      $$DwOfflineReaderPinsTableAnnotationComposer,
      $$DwOfflineReaderPinsTableCreateCompanionBuilder,
      $$DwOfflineReaderPinsTableUpdateCompanionBuilder,
      (
        DwOfflineReaderPinRow,
        BaseReferences<
          _$DwOfflineDatabase,
          $DwOfflineReaderPinsTable,
          DwOfflineReaderPinRow
        >,
      ),
      DwOfflineReaderPinRow,
      PrefetchHooks Function()
    >;
typedef $$DwOfflineStagingAssetsTableCreateCompanionBuilder =
    DwOfflineStagingAssetsCompanion Function({
      required String userScopeId,
      required String packageId,
      required String manifestRevision,
      required String assetId,
      required String assetRevision,
      required bool isRequired,
      required int createdAtEpochMs,
      Value<int> rowid,
    });
typedef $$DwOfflineStagingAssetsTableUpdateCompanionBuilder =
    DwOfflineStagingAssetsCompanion Function({
      Value<String> userScopeId,
      Value<String> packageId,
      Value<String> manifestRevision,
      Value<String> assetId,
      Value<String> assetRevision,
      Value<bool> isRequired,
      Value<int> createdAtEpochMs,
      Value<int> rowid,
    });

class $$DwOfflineStagingAssetsTableFilterComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineStagingAssetsTable> {
  $$DwOfflineStagingAssetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manifestRevision => $composableBuilder(
    column: $table.manifestRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetRevision => $composableBuilder(
    column: $table.assetRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRequired => $composableBuilder(
    column: $table.isRequired,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DwOfflineStagingAssetsTableOrderingComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineStagingAssetsTable> {
  $$DwOfflineStagingAssetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifestRevision => $composableBuilder(
    column: $table.manifestRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetRevision => $composableBuilder(
    column: $table.assetRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRequired => $composableBuilder(
    column: $table.isRequired,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DwOfflineStagingAssetsTableAnnotationComposer
    extends Composer<_$DwOfflineDatabase, $DwOfflineStagingAssetsTable> {
  $$DwOfflineStagingAssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userScopeId => $composableBuilder(
    column: $table.userScopeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get packageId =>
      $composableBuilder(column: $table.packageId, builder: (column) => column);

  GeneratedColumn<String> get manifestRevision => $composableBuilder(
    column: $table.manifestRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<String> get assetRevision => $composableBuilder(
    column: $table.assetRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isRequired => $composableBuilder(
    column: $table.isRequired,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => column,
  );
}

class $$DwOfflineStagingAssetsTableTableManager
    extends
        RootTableManager<
          _$DwOfflineDatabase,
          $DwOfflineStagingAssetsTable,
          DwOfflineStagingAssetRow,
          $$DwOfflineStagingAssetsTableFilterComposer,
          $$DwOfflineStagingAssetsTableOrderingComposer,
          $$DwOfflineStagingAssetsTableAnnotationComposer,
          $$DwOfflineStagingAssetsTableCreateCompanionBuilder,
          $$DwOfflineStagingAssetsTableUpdateCompanionBuilder,
          (
            DwOfflineStagingAssetRow,
            BaseReferences<
              _$DwOfflineDatabase,
              $DwOfflineStagingAssetsTable,
              DwOfflineStagingAssetRow
            >,
          ),
          DwOfflineStagingAssetRow,
          PrefetchHooks Function()
        > {
  $$DwOfflineStagingAssetsTableTableManager(
    _$DwOfflineDatabase db,
    $DwOfflineStagingAssetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DwOfflineStagingAssetsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DwOfflineStagingAssetsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DwOfflineStagingAssetsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userScopeId = const Value.absent(),
                Value<String> packageId = const Value.absent(),
                Value<String> manifestRevision = const Value.absent(),
                Value<String> assetId = const Value.absent(),
                Value<String> assetRevision = const Value.absent(),
                Value<bool> isRequired = const Value.absent(),
                Value<int> createdAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DwOfflineStagingAssetsCompanion(
                userScopeId: userScopeId,
                packageId: packageId,
                manifestRevision: manifestRevision,
                assetId: assetId,
                assetRevision: assetRevision,
                isRequired: isRequired,
                createdAtEpochMs: createdAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userScopeId,
                required String packageId,
                required String manifestRevision,
                required String assetId,
                required String assetRevision,
                required bool isRequired,
                required int createdAtEpochMs,
                Value<int> rowid = const Value.absent(),
              }) => DwOfflineStagingAssetsCompanion.insert(
                userScopeId: userScopeId,
                packageId: packageId,
                manifestRevision: manifestRevision,
                assetId: assetId,
                assetRevision: assetRevision,
                isRequired: isRequired,
                createdAtEpochMs: createdAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DwOfflineStagingAssetsTableProcessedTableManager =
    ProcessedTableManager<
      _$DwOfflineDatabase,
      $DwOfflineStagingAssetsTable,
      DwOfflineStagingAssetRow,
      $$DwOfflineStagingAssetsTableFilterComposer,
      $$DwOfflineStagingAssetsTableOrderingComposer,
      $$DwOfflineStagingAssetsTableAnnotationComposer,
      $$DwOfflineStagingAssetsTableCreateCompanionBuilder,
      $$DwOfflineStagingAssetsTableUpdateCompanionBuilder,
      (
        DwOfflineStagingAssetRow,
        BaseReferences<
          _$DwOfflineDatabase,
          $DwOfflineStagingAssetsTable,
          DwOfflineStagingAssetRow
        >,
      ),
      DwOfflineStagingAssetRow,
      PrefetchHooks Function()
    >;

class $DwOfflineDatabaseManager {
  final _$DwOfflineDatabase _db;
  $DwOfflineDatabaseManager(this._db);
  $$DwOfflinePackagesTableTableManager get dwOfflinePackages =>
      $$DwOfflinePackagesTableTableManager(_db, _db.dwOfflinePackages);
  $$DwOfflineAssetsTableTableManager get dwOfflineAssets =>
      $$DwOfflineAssetsTableTableManager(_db, _db.dwOfflineAssets);
  $$DwOfflinePackageAssetsTableTableManager get dwOfflinePackageAssets =>
      $$DwOfflinePackageAssetsTableTableManager(
        _db,
        _db.dwOfflinePackageAssets,
      );
  $$DwOfflineJobsTableTableManager get dwOfflineJobs =>
      $$DwOfflineJobsTableTableManager(_db, _db.dwOfflineJobs);
  $$DwOfflineDownloadTasksTableTableManager get dwOfflineDownloadTasks =>
      $$DwOfflineDownloadTasksTableTableManager(
        _db,
        _db.dwOfflineDownloadTasks,
      );
  $$DwOfflineSnapshotsTableTableManager get dwOfflineSnapshots =>
      $$DwOfflineSnapshotsTableTableManager(_db, _db.dwOfflineSnapshots);
  $$DwOfflineOutboxTableTableManager get dwOfflineOutbox =>
      $$DwOfflineOutboxTableTableManager(_db, _db.dwOfflineOutbox);
  $$DwOfflineManifestsTableTableManager get dwOfflineManifests =>
      $$DwOfflineManifestsTableTableManager(_db, _db.dwOfflineManifests);
  $$DwOfflinePackageSnapshotsTableTableManager get dwOfflinePackageSnapshots =>
      $$DwOfflinePackageSnapshotsTableTableManager(
        _db,
        _db.dwOfflinePackageSnapshots,
      );
  $$DwOfflineLeasesTableTableManager get dwOfflineLeases =>
      $$DwOfflineLeasesTableTableManager(_db, _db.dwOfflineLeases);
  $$DwOfflineReaderPinsTableTableManager get dwOfflineReaderPins =>
      $$DwOfflineReaderPinsTableTableManager(_db, _db.dwOfflineReaderPins);
  $$DwOfflineStagingAssetsTableTableManager get dwOfflineStagingAssets =>
      $$DwOfflineStagingAssetsTableTableManager(
        _db,
        _db.dwOfflineStagingAssets,
      );
}
