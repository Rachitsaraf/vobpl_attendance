import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../models/attendance_model.dart';

class PdfService {
  static Future<void> generateAttendanceReport(List<AttendanceModel> history, String employeeName) async {
    try {
      debugPrint('Generating PDF for $employeeName...');
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) => [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('VOBPL', 
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo)),
                    pw.Text('Monthly Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Text(DateFormat('MMMM yyyy').format(DateTime.now()), 
                  style: const pw.TextStyle(fontSize: 16)),
              ],
            ),
            pw.SizedBox(height: 30),

            // Employee Info
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                children: [
                  pw.Text('EMPLOYEE: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(employeeName),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Attendance Table
            pw.TableHelper.fromTextArray(
              border: null,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
              },
              headers: ['Date', 'Check-In', 'Check-Out', 'Status', 'Duration'],
              data: history.map((record) {
                final duration = record.checkOutTime != null 
                    ? record.checkOutTime!.difference(record.checkInTime)
                    : Duration.zero;
                
                return [
                  DateFormat('yyyy-MM-dd').format(record.checkInTime),
                  DateFormat('hh:mm a').format(record.checkInTime),
                  record.checkOutTime != null ? DateFormat('hh:mm a').format(record.checkOutTime!) : '--:--',
                  record.status,
                  '${duration.inHours}h ${duration.inMinutes.remainder(60)}m',
                ];
              }).toList(),
            ),

            pw.Spacer(),
            
            // Footer
            pw.Divider(color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generated via Vobpl App', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
                pw.Text('Report Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}', 
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
              ],
            ),
          ],
        ),
      );

      // This will open the native print/save dialog on Android/iOS
      await Printing.layoutPdf(
        name: 'Attendance_Report_${employeeName.replaceAll(' ', '_')}.pdf',
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
      
      debugPrint('PDF layout triggered successfully');
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      rethrow;
    }
  }
}
