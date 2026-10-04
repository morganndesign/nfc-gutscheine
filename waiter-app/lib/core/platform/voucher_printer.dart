import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../format/format.dart';
import '../theme/brand_color.dart' show parseBrandColor;

/// Texts the guest reads on the printed voucher. They follow the restaurant's
/// language, not the waiter's UI language, and match the dashboard's printout.
/// The value that was bought is part of the design (ADR-003); it is not a
/// balance — the balance lives on the server. No voucher number is printed:
/// the QR is the voucher.
@immutable
class GuestCopy {
  const GuestCopy._({
    required this.voucher,
    required this.value,
    required this.howTo,
    required this.keepSafe,
    required this.noExpiry,
    required this.validUntil,
    required this.forRecipient,
    required this.dateLanguage,
  });

  /// German, Bosnian/Croatian/Serbian or English by the restaurant locale
  /// (`de_AT`, `bs_BA`, …).
  factory GuestCopy.of(String locale) {
    final String language = locale.toLowerCase().substring(0, locale.length < 2 ? locale.length : 2);
    if (language == 'de') return _de;
    if (language == 'bs' || language == 'hr' || language == 'sr') return _bhs;
    return _en;
  }

  static const GuestCopy _de = GuestCopy._(
    voucher: 'Gutschein',
    value: 'Wert',
    howTo: 'Bitte zeigen Sie diesen Code beim Bezahlen vor.',
    keepSafe: 'Wie Bargeld aufbewahren: Wer den Code besitzt, kann den Gutschein einlösen.',
    noExpiry: 'Unbefristet gültig',
    validUntil: 'Gültig bis',
    forRecipient: 'für',
    dateLanguage: UiLanguage.de,
  );

  static const GuestCopy _en = GuestCopy._(
    voucher: 'Voucher',
    value: 'Value',
    howTo: 'Please show this code when you pay.',
    keepSafe: 'Keep it safe like cash: whoever holds the code can redeem the voucher.',
    noExpiry: 'No expiry date',
    validUntil: 'Valid until',
    forRecipient: 'for',
    dateLanguage: UiLanguage.en,
  );

  static const GuestCopy _bhs = GuestCopy._(
    voucher: 'Vaučer',
    value: 'Vrijednost',
    howTo: 'Molimo pokažite ovaj kôd prilikom plaćanja.',
    keepSafe: 'Čuvajte ga kao gotovinu: ko ima kôd, može iskoristiti vaučer.',
    noExpiry: 'Bez roka važenja',
    validUntil: 'Vrijedi do',
    forRecipient: 'za',
    dateLanguage: UiLanguage.bhs,
  );

  final String voucher;

  /// Label above the printed value.
  final String value;
  final String howTo;
  final String keepSafe;
  final String noExpiry;
  final String validUntil;

  /// "für Anna": the word before the recipient's name.
  final String forRecipient;
  final UiLanguage dateLanguage;

  /// [cents] in the restaurant's money format, in the guest language.
  String money(int cents, String currency, String restaurantLocale) => MoneyFormat.format(
    cents,
    currency: currency,
    language: dateLanguage,
    restaurantLocale: RestaurantLocale.parse(restaurantLocale),
  );

  String validity(CalendarDate? expiresOn) =>
      expiresOn == null ? noExpiry : '$validUntil ${DateTimeFormat.date(expiresOn, dateLanguage)}';
}

/// One sold voucher as printed for the guest.
@immutable
class PrintableVoucher {
  const PrintableVoucher({
    required this.payload,
    required this.restaurantName,
    required this.restaurantLocale,
    required this.value,
    required this.currency,
    this.brandColor,
    this.expiresOn,
    this.recipientName,
    this.giftMessage,
  });

  /// The QR text. Held in memory only while the sale screen is open.
  final String payload;
  final String restaurantName;

  /// e.g. `de_AT`: decides the language of the printout.
  final String restaurantLocale;

  /// The value sold, in cents (printed as part of the design, not a balance).
  final int value;
  final String currency;

  /// `#RRGGBB` of the header band, null = ink.
  final String? brandColor;

  /// Expiry date in the restaurant time zone, null = no expiry.
  final CalendarDate? expiresOn;

  /// For whom, and the buyer's message (as on the e-mailed PDF).
  final String? recipientName;
  final String? giftMessage;
}

/// Prints a sold voucher through the operating system's print dialog (AirPrint
/// on iPhone, the Android print service). Returns true when the job was handed
/// to a printer, false when the dialog was closed without printing.
abstract interface class VoucherPrinter {
  Future<bool> print(PrintableVoucher voucher);
}

class SystemVoucherPrinter implements VoucherPrinter {
  const SystemVoucherPrinter();

  @override
  Future<bool> print(PrintableVoucher voucher) async {
    final Uint8List document = await voucherSheetPdf(voucher);
    return Printing.layoutPdf(name: voucher.restaurantName, onLayout: (PdfPageFormat _) async => document);
  }
}

/// The A6 voucher sheet, like the e-mailed PDF: the voucher as a card
/// (brand colour, restaurant, "für Anna", value), the buyer's message, then the
/// QR without a frame, how to use it, validity and the keep-safe line. Built in
/// memory, never written to disk.
Future<Uint8List> voucherSheetPdf(PrintableVoucher voucher, {pw.Font? regular, pw.Font? bold}) async {
  final pw.Font body = regular ?? pw.Font.ttf(await rootBundle.load('assets/fonts/Geist-Regular.ttf'));
  final pw.Font heading = bold ?? pw.Font.ttf(await rootBundle.load('assets/fonts/Geist-SemiBold.ttf'));
  final GuestCopy copy = GuestCopy.of(voucher.restaurantLocale);
  final int band = parseBrandColor(voucher.brandColor)?.toARGB32() ?? 0xFF18181B;
  final PdfColor cardColor = PdfColor.fromInt(band);
  final PdfColor ink = cardColor.luminance > 0.6 ? const PdfColor.fromInt(0xFF18181B) : PdfColors.white;
  final PdfColor soft = ink == PdfColors.white ? const PdfColor(1, 1, 1, 0.72) : const PdfColor.fromInt(0xFF52525B);
  const PdfColor muted = PdfColor.fromInt(0xFF71717A);
  final String? recipient = _clean(voucher.recipientName);
  final String? message = _clean(voucher.giftMessage);
  final double qr = message == null ? 128 : 104;

  final pw.Document doc = pw.Document(title: copy.voucher, author: voucher.restaurantName);
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a6,
      margin: const pw.EdgeInsets.fromLTRB(18, 20, 18, 16),
      theme: pw.ThemeData.withFont(base: body, bold: heading),
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          // ID-1 proportions (85.6 × 54 mm) at the sheet's width.
          pw.AspectRatio(
            aspectRatio: 85.6 / 54,
            child: pw.Container(
              decoration: pw.BoxDecoration(color: cardColor, borderRadius: pw.BorderRadius.circular(9)),
              padding: const pw.EdgeInsets.fromLTRB(14, 13, 14, 12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.Expanded(
                        child: pw.Text(
                          voucher.restaurantName,
                          maxLines: 2,
                          style: pw.TextStyle(color: ink, fontSize: 10.5, font: heading),
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        copy.voucher.toUpperCase(),
                        style: pw.TextStyle(color: soft, fontSize: 5.5, letterSpacing: 2, font: heading),
                      ),
                    ],
                  ),
                  pw.Spacer(),
                  if (recipient != null) ...<pw.Widget>[
                    pw.Text(
                      '${copy.forRecipient} $recipient',
                      maxLines: 1,
                      style: pw.TextStyle(color: ink, fontSize: 9.5),
                    ),
                    pw.SizedBox(height: 5),
                  ],
                  pw.Text(
                    copy.value.toUpperCase(),
                    style: pw.TextStyle(color: soft, fontSize: 5.5, letterSpacing: 2, font: heading),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    copy.money(voucher.value, voucher.currency, voucher.restaurantLocale),
                    style: pw.TextStyle(color: ink, fontSize: 22, font: heading),
                  ),
                ],
              ),
            ),
          ),
          if (message != null) ...<pw.Widget>[
            pw.SizedBox(height: 12),
            pw.Text(
              '\u201C$message\u201D',
              textAlign: pw.TextAlign.center,
              maxLines: 6,
              // Geist has no italic; the default italic (Helvetica) lacks č/ć/š.
              style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 2),
            ),
          ],
          pw.Expanded(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: <pw.Widget>[
                // No frame around the code (decision 2026-10-04).
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium),
                  data: voucher.payload,
                  width: qr,
                  height: qr,
                ),
                pw.SizedBox(height: 10),
                pw.Text(copy.howTo, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8.5, font: heading)),
                pw.SizedBox(height: 4),
                pw.Text(
                  copy.validity(voucher.expiresOn),
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7, color: muted),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  copy.keepSafe,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

String? _clean(String? text) {
  final String? trimmed = text?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
