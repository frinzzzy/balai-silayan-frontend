/// Centralized business info para sa official receipts / bills ng Balai Silayan.
/// Pwede mong i-edit dito ang TIN, address, at VAT status nang direkta.
class BusinessInfo {
  static const String restaurantName = 'BALAI SILAYAN';
  static const String tagline = 'Heritage Restaurant & Cafe';
  static const String address = 'Nagcarlan, Laguna';
  static const String tin = '000-000-000-000';
  static const bool vatRegistered = true;

  static String get receiptHeaderLine =>
      '$address • TIN: $tin ${vatRegistered ? '• VAT REG' : '• NON-VAT REG'}';
}
