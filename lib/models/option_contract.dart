class OptionContract {
  final String securityId;
  final String tradingSymbol;
  final String underlying;
  final String expiry;
  final double strike;
  final String optionType; // CE or PE
  final String exchangeSegment; // NSE_FNO
  final double tickSize;
  final int lotSize;

  OptionContract({
    required this.securityId,
    required this.tradingSymbol,
    required this.underlying,
    required this.expiry,
    required this.strike,
    required this.optionType,
    required this.exchangeSegment,
    required this.tickSize,
    required this.lotSize,
  });

  String get displayName =>
      '$underlying $expiry $strike $optionType';

  factory OptionContract.fromScripRow(Map<String, dynamic> row) {
    return OptionContract(
      securityId: row['SEM_SMST_SECURITY_ID']?.toString() ?? '',
      tradingSymbol: row['SEM_TRADING_SYMBOL']?.toString() ?? '',
      underlying: row['SEM_CUSTOM_SYMBOL']?.toString().split(' ').first ?? '',
      expiry: row['SEM_EXPIRY_DATE']?.toString() ?? '',
      strike: double.tryParse(row['SEM_STRIKE_PRICE']?.toString() ?? '0') ?? 0,
      optionType: row['SEM_OPTION_TYPE']?.toString() ?? '',
      exchangeSegment: 'NSE_FNO',
      tickSize: double.tryParse(row['SEM_TICK_SIZE']?.toString() ?? '0.05') ?? 0.05,
      lotSize: int.tryParse(row['SEM_LOT_UNITS']?.toString() ?? '1') ?? 1,
    );
  }
}
