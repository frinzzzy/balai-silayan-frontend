import 'package:intl/intl.dart';

/// Isang lugar lang para sa peso formatting ng customer UI.
///
/// Dati kasi halo-halo ang `toStringAsFixed(0)`, `toStringAsFixed(2)` at walang
/// thousands separator, kaya hindi tugma ang presyo sa Menu, Cart at Bill.
final NumberFormat _pesoWithDecimals = NumberFormat.currency(
  locale: 'en_PH',
  symbol: '₱',
  decimalDigits: 2,
);

final NumberFormat _pesoWhole = NumberFormat.currency(
  locale: 'en_PH',
  symbol: '₱',
  decimalDigits: 0,
);

/// Halimbawa: `formatPeso(1234.5)` -> `₱1,234.50`
String formatPeso(num value, {bool decimals = true}) {
  return (decimals ? _pesoWithDecimals : _pesoWhole).format(value);
}

/// Halimbawa: `formatPesoWhole(1234.5)` -> `₱1,235`
String formatPesoWhole(num value) => _pesoWhole.format(value);
