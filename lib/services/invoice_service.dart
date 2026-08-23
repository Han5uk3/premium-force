import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:premium_force_main/api/booking_api_v2.dart';
import 'package:premium_force_main/models/v2/booking_v2.dart';

/// Opens the VAT invoice for a booking in the device's PDF viewer.
///
/// The endpoint is authenticated, so the PDF cannot simply be handed to the
/// browser: it is fetched with the customer's bearer token, cached under the
/// app's documents directory, and handed to the platform viewer from there.
/// Caching by booking number also means re-opening the same invoice is instant
/// and works offline.
///
/// Usage:
/// ```dart
/// final outcome = await InvoiceService().open(booking);
/// if (!outcome.success) showError(outcome.message);
/// ```
class InvoiceService {
  InvoiceService({BookingApiV2? api}) : _api = api ?? BookingApiV2();

  final BookingApiV2 _api;

  /// Download (or reuse) the invoice PDF for [booking] and open it.
  Future<InvoiceOutcome> open(BookingV2 booking) async {
    if (!booking.hasInvoice) {
      return const InvoiceOutcome.failure('unavailable');
    }

    final result = await _api.downloadInvoice(
      bookingId: booking.id,
      invoicePath: booking.invoiceUrl,
    );

    if (!result.hasData) {
      return InvoiceOutcome.failure(result.message ?? 'failed');
    }

    try {
      final file = await _writeToCache(booking, result.data!);
      final opened = await OpenFilex.open(
        file.path,
        type: 'application/pdf',
        uti: 'com.adobe.pdf',
      );

      if (opened.type == ResultType.done) {
        return InvoiceOutcome.success(file.path);
      }

      // No installed viewer, or the platform refused to hand the file over. The
      // download itself succeeded, so the file path is still reported back.
      return InvoiceOutcome.failure('noViewer', filePath: file.path);
    } catch (error) {
      return const InvoiceOutcome.failure('failed');
    }
  }

  /// Write the PDF into the app's documents directory.
  ///
  /// The name mirrors the `Content-Disposition` the API sends, so a customer who
  /// finds the file outside the app can still tell which ride it belongs to.
  Future<File> _writeToCache(BookingV2 booking, Uint8List bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final invoices = Directory('${directory.path}/invoices');
    if (!await invoices.exists()) {
      await invoices.create(recursive: true);
    }

    final reference = booking.bookingNumber.trim().isNotEmpty
        ? booking.bookingNumber.trim()
        : booking.id;
    final safeReference = reference.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');

    final file = File('${invoices.path}/PF-Invoice-$safeReference.pdf');
    return file.writeAsBytes(bytes, flush: true);
  }
}

/// What came of an attempt to open an invoice.
///
/// [message] is either a server-supplied string worth showing verbatim or one of
/// the sentinels below, which the caller maps to a localised string:
///
/// - `unavailable` — the booking carries no `invoiceUrl` (unpaid or failed).
/// - `noViewer` — the PDF downloaded but no app on the device could open it.
/// - `failed` — the download or the file write failed.
class InvoiceOutcome {
  const InvoiceOutcome.success(this.filePath) : success = true, message = null;

  const InvoiceOutcome.failure(this.message, {this.filePath}) : success = false;

  final bool success;
  final String? message;

  /// Where the PDF was cached, when it made it to disk.
  final String? filePath;

  /// Whether the failure was "nothing on this device can open a PDF", which is
  /// worth a different message than a download that never landed.
  bool get isMissingViewer => !success && message == 'noViewer';

  /// Whether the booking simply has no invoice yet.
  bool get isUnavailable => !success && message == 'unavailable';

  /// Whether the failure has no server-supplied explanation to show.
  bool get isGenericFailure => !success && message == 'failed';
}
