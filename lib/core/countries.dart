/// Curated country → currency catalog for first-run selection.
/// Symbols are display-only; amounts stay in minor units internally.
class CountryCurrency {
  const CountryCurrency({
    required this.code,
    required this.name,
    required this.flag,
    required this.currencyCode,
    required this.symbol,
  });

  /// ISO 3166-1 alpha-2
  final String code;
  final String name;

  /// Flag emoji
  final String flag;

  /// ISO 4217
  final String currencyCode;
  final String symbol;
}

const List<CountryCurrency> kCountries = [
  CountryCurrency(code: 'AR', name: 'Argentina', flag: '🇦🇷', currencyCode: 'ARS', symbol: r'$'),
  CountryCurrency(code: 'AU', name: 'Australia', flag: '🇦🇺', currencyCode: 'AUD', symbol: r'$'),
  CountryCurrency(code: 'AT', name: 'Austria', flag: '🇦🇹', currencyCode: 'EUR', symbol: '€'),
  CountryCurrency(code: 'BH', name: 'Bahrain', flag: '🇧🇭', currencyCode: 'BHD', symbol: '.د.ب'),
  CountryCurrency(code: 'BD', name: 'Bangladesh', flag: '🇧🇩', currencyCode: 'BDT', symbol: '৳'),
  CountryCurrency(code: 'BE', name: 'Belgium', flag: '🇧🇪', currencyCode: 'EUR', symbol: '€'),
  CountryCurrency(code: 'BR', name: 'Brazil', flag: '🇧🇷', currencyCode: 'BRL', symbol: 'R\$'),
  CountryCurrency(code: 'BG', name: 'Bulgaria', flag: '🇧🇬', currencyCode: 'BGN', symbol: 'лв'),
  CountryCurrency(code: 'CM', name: 'Cameroon', flag: '🇨🇲', currencyCode: 'XAF', symbol: 'FCFA'),
  CountryCurrency(code: 'CA', name: 'Canada', flag: '🇨🇦', currencyCode: 'CAD', symbol: r'$'),
  CountryCurrency(code: 'CL', name: 'Chile', flag: '🇨🇱', currencyCode: 'CLP', symbol: r'$'),
  CountryCurrency(code: 'CN', name: 'China', flag: '🇨🇳', currencyCode: 'CNY', symbol: '¥'),
  CountryCurrency(code: 'CO', name: 'Colombia', flag: '🇨🇴', currencyCode: 'COP', symbol: r'$'),
  CountryCurrency(code: 'HR', name: 'Croatia', flag: '🇭🇷', currencyCode: 'EUR', symbol: '€'),
  CountryCurrency(code: 'CZ', name: 'Czechia', flag: '🇨🇿', currencyCode: 'CZK', symbol: 'Kč'),
  CountryCurrency(code: 'DK', name: 'Denmark', flag: '🇩🇰', currencyCode: 'DKK', symbol: 'kr'),
  CountryCurrency(code: 'EG', name: 'Egypt', flag: '🇪🇬', currencyCode: 'EGP', symbol: 'E£'),
  CountryCurrency(code: 'ET', name: 'Ethiopia', flag: '🇪🇹', currencyCode: 'ETB', symbol: 'Br'),
  CountryCurrency(code: 'FI', name: 'Finland', flag: '🇫🇮', currencyCode: 'EUR', symbol: '€'),
  CountryCurrency(code: 'FR', name: 'France', flag: '🇫🇷', currencyCode: 'EUR', symbol: '€'),
  CountryCurrency(code: 'DE', name: 'Germany', flag: '🇩🇪', currencyCode: 'EUR', symbol: '€'),
  CountryCurrency(code: 'GH', name: 'Ghana', flag: '🇬🇭', currencyCode: 'GHS', symbol: '₵'),
  CountryCurrency(code: 'GR', name: 'Greece', flag: '🇬🇷', currencyCode: 'EUR', symbol: '€'),
  CountryCurrency(code: 'HK', name: 'Hong Kong', flag: '🇭🇰', currencyCode: 'HKD', symbol: 'HK\$'),
  CountryCurrency(code: 'HU', name: 'Hungary', flag: '🇭🇺', currencyCode: 'HUF', symbol: 'Ft'),
  CountryCurrency(code: 'IN', name: 'India', flag: '🇮🇳', currencyCode: 'INR', symbol: '₹'),
  CountryCurrency(code: 'ID', name: 'Indonesia', flag: '🇮🇩', currencyCode: 'IDR', symbol: 'Rp'),
  CountryCurrency(code: 'IQ', name: 'Iraq', flag: '🇮🇶', currencyCode: 'IQD', symbol: 'ع.د'),
  CountryCurrency(code: 'IE', name: 'Ireland', flag: '🇮🇪', currencyCode: 'EUR', symbol: '€'),
  CountryCurrency(code: 'IT', name: 'Italy', flag: '🇮🇹', currencyCode: 'EUR', symbol: '€'),
  CountryCurrency(code: 'JP', name: 'Japan', flag: '🇯🇵', currencyCode: 'JPY', symbol: '¥'),
  CountryCurrency(code: 'JO', name: 'Jordan', flag: '🇯🇴', currencyCode: 'JOD', symbol: 'د.ا'),
  CountryCurrency(code: 'KE', name: 'Kenya', flag: '🇰🇪', currencyCode: 'KES', symbol: 'KSh'),
  CountryCurrency(code: 'KW', name: 'Kuwait', flag: '🇰🇼', currencyCode: 'KWD', symbol: 'د.ك'),
  CountryCurrency(code: 'LB', name: 'Lebanon', flag: '🇱🇧', currencyCode: 'LBP', symbol: 'ل.ل'),
  CountryCurrency(code: 'LY', name: 'Libya', flag: '🇱🇾', currencyCode: 'LYD', symbol: 'ل.د'),
  CountryCurrency(code: 'MY', name: 'Malaysia', flag: '🇲🇾', currencyCode: 'MYR', symbol: 'RM'),
  CountryCurrency(code: 'MX', name: 'Mexico', flag: '🇲🇽', currencyCode: 'MXN', symbol: r'$'),
  CountryCurrency(code: 'MA', name: 'Morocco', flag: '🇲🇦', currencyCode: 'MAD', symbol: 'د.م.'),
  CountryCurrency(code: 'NL', name: 'Netherlands', flag: '🇳🇱', currencyCode: 'EUR', symbol: '€'),
  CountryCurrency(code: 'NZ', name: 'New Zealand', flag: '🇳🇿', currencyCode: 'NZD', symbol: r'$'),
  CountryCurrency(code: 'NG', name: 'Nigeria', flag: '🇳🇬', currencyCode: 'NGN', symbol: '₦'),
  CountryCurrency(code: 'NO', name: 'Norway', flag: '🇳🇴', currencyCode: 'NOK', symbol: 'kr'),
  CountryCurrency(code: 'OM', name: 'Oman', flag: '🇴🇲', currencyCode: 'OMR', symbol: 'ر.ع.'),
  CountryCurrency(code: 'PK', name: 'Pakistan', flag: '🇵🇰', currencyCode: 'PKR', symbol: '₨'),
  CountryCurrency(code: 'PS', name: 'Palestine', flag: '🇵🇸', currencyCode: 'ILS', symbol: '₪'),
  CountryCurrency(code: 'PE', name: 'Peru', flag: '🇵🇪', currencyCode: 'PEN', symbol: 'S/'),
  CountryCurrency(code: 'PH', name: 'Philippines', flag: '🇵🇭', currencyCode: 'PHP', symbol: '₱'),
  CountryCurrency(code: 'PL', name: 'Poland', flag: '🇵🇱', currencyCode: 'PLN', symbol: 'zł'),
  CountryCurrency(code: 'PT', name: 'Portugal', flag: '🇵🇹', currencyCode: 'EUR', symbol: '€'),
  CountryCurrency(code: 'QA', name: 'Qatar', flag: '🇶🇦', currencyCode: 'QAR', symbol: 'ر.ق'),
  CountryCurrency(code: 'RO', name: 'Romania', flag: '🇷🇴', currencyCode: 'RON', symbol: 'lei'),
  CountryCurrency(code: 'RU', name: 'Russia', flag: '🇷🇺', currencyCode: 'RUB', symbol: '₽'),
  CountryCurrency(code: 'SA', name: 'Saudi Arabia', flag: '🇸🇦', currencyCode: 'SAR', symbol: '﷼'),
  CountryCurrency(code: 'RS', name: 'Serbia', flag: '🇷🇸', currencyCode: 'RSD', symbol: 'дин.'),
  CountryCurrency(code: 'SG', name: 'Singapore', flag: '🇸🇬', currencyCode: 'SGD', symbol: 'S\$'),
  CountryCurrency(code: 'ZA', name: 'South Africa', flag: '🇿🇦', currencyCode: 'ZAR', symbol: 'R'),
  CountryCurrency(code: 'KR', name: 'South Korea', flag: '🇰🇷', currencyCode: 'KRW', symbol: '₩'),
  CountryCurrency(code: 'ES', name: 'Spain', flag: '🇪🇸', currencyCode: 'EUR', symbol: '€'),
  CountryCurrency(code: 'SD', name: 'Sudan', flag: '🇸🇩', currencyCode: 'SDG', symbol: 'ج.س.'),
  CountryCurrency(code: 'SE', name: 'Sweden', flag: '🇸🇪', currencyCode: 'SEK', symbol: 'kr'),
  CountryCurrency(code: 'CH', name: 'Switzerland', flag: '🇨🇭', currencyCode: 'CHF', symbol: 'CHF'),
  CountryCurrency(code: 'SY', name: 'Syria', flag: '🇸🇾', currencyCode: 'SYP', symbol: '£S'),
  CountryCurrency(code: 'TW', name: 'Taiwan', flag: '🇹🇼', currencyCode: 'TWD', symbol: 'NT\$'),
  CountryCurrency(code: 'TZ', name: 'Tanzania', flag: '🇹🇿', currencyCode: 'TZS', symbol: 'TSh'),
  CountryCurrency(code: 'TH', name: 'Thailand', flag: '🇹🇭', currencyCode: 'THB', symbol: '฿'),
  CountryCurrency(code: 'TN', name: 'Tunisia', flag: '🇹🇳', currencyCode: 'TND', symbol: 'د.ت'),
  CountryCurrency(code: 'TR', name: 'Türkiye', flag: '🇹🇷', currencyCode: 'TRY', symbol: '₺'),
  CountryCurrency(code: 'UG', name: 'Uganda', flag: '🇺🇬', currencyCode: 'UGX', symbol: 'USh'),
  CountryCurrency(code: 'AE', name: 'United Arab Emirates', flag: '🇦🇪', currencyCode: 'AED', symbol: 'د.إ'),
  CountryCurrency(code: 'GB', name: 'United Kingdom', flag: '🇬🇧', currencyCode: 'GBP', symbol: '£'),
  CountryCurrency(code: 'US', name: 'United States', flag: '🇺🇸', currencyCode: 'USD', symbol: r'$'),
  CountryCurrency(code: 'UA', name: 'Ukraine', flag: '🇺🇦', currencyCode: 'UAH', symbol: '₴'),
  CountryCurrency(code: 'UY', name: 'Uruguay', flag: '🇺🇾', currencyCode: 'UYU', symbol: r'$'),
  CountryCurrency(code: 'YE', name: 'Yemen', flag: '🇾🇪', currencyCode: 'YER', symbol: '﷼'),
];

CountryCurrency? findCountry(String isoCode) {
  final c = isoCode.toUpperCase();
  for (final k in kCountries) {
    if (k.code == c) return k;
  }
  return null;
}

List<CountryCurrency> searchCountries(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return kCountries;
  return kCountries
      .where((c) =>
          c.name.toLowerCase().contains(q) ||
          c.code.toLowerCase().contains(q) ||
          c.currencyCode.toLowerCase().contains(q))
      .toList();
}
