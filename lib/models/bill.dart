enum BillStatus { unpaid, screenshotUploaded, confirmed }

/// One flat's computed bill for one month.
/// amountDue = openingBalance + waterCharge + commonShare − offsetCredits
///
/// Advances are NOT a separate term here: recording an advance recovery
/// applies it directly to the flat's [Flat.openingBalancePaise] at the
/// point it's recorded, so it flows through the same carry-forward the
/// opening balance always uses. This matches the canonical formula exactly
/// — see [SocietyProvider.addAdvance].
class Bill {
  Bill({
    required this.flatNumber,
    required this.monthId,
    this.openingBalancePaise = 0,
    this.waterChargePaise = 0,
    this.commonSharePaise = 0,
    this.offsetCreditsPaise = 0,
    this.status = BillStatus.unpaid,
    this.screenshotAdded = false,
    this.paymentScreenshotUrl,
    this.screenshotSubmittedAt,
    this.confirmedAt,
  });

  final String flatNumber;
  final String monthId;
  int openingBalancePaise;
  int waterChargePaise;
  int commonSharePaise;
  int offsetCreditsPaise;
  BillStatus status;

  /// Kept alongside [paymentScreenshotUrl] as the status-flow flag — the
  /// URL is what lets the admin actually view what was uploaded.
  bool screenshotAdded;
  String? paymentScreenshotUrl;

  DateTime? screenshotSubmittedAt;
  DateTime? confirmedAt;

  int get subtotalPaise =>
      openingBalancePaise + waterChargePaise + commonSharePaise;

  int get amountDuePaise => subtotalPaise - offsetCreditsPaise;

  Map<String, dynamic> toMap() => {
    'flatNumber': flatNumber,
    'monthId': monthId,
    'openingBalancePaise': openingBalancePaise,
    'waterChargePaise': waterChargePaise,
    'commonSharePaise': commonSharePaise,
    'offsetCreditsPaise': offsetCreditsPaise,
    'status': status.name,
    'screenshotAdded': screenshotAdded,
    'paymentScreenshotUrl': paymentScreenshotUrl,
    'screenshotSubmittedAt': screenshotSubmittedAt?.millisecondsSinceEpoch,
    'confirmedAt': confirmedAt?.millisecondsSinceEpoch,
  };

  factory Bill.fromMap(Map<String, dynamic> map) => Bill(
    flatNumber: map['flatNumber'] as String,
    monthId: map['monthId'] as String? ?? '',
    openingBalancePaise: map['openingBalancePaise'] as int? ?? 0,
    waterChargePaise: map['waterChargePaise'] as int? ?? 0,
    commonSharePaise: map['commonSharePaise'] as int? ?? 0,
    offsetCreditsPaise: map['offsetCreditsPaise'] as int? ?? 0,
    status: BillStatus.values.byName(map['status'] as String? ?? 'unpaid'),
    screenshotAdded: map['screenshotAdded'] as bool? ?? false,
    paymentScreenshotUrl: map['paymentScreenshotUrl'] as String?,
    screenshotSubmittedAt: map['screenshotSubmittedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['screenshotSubmittedAt'] as int)
        : null,
    confirmedAt: map['confirmedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['confirmedAt'] as int)
        : null,
  );
}
