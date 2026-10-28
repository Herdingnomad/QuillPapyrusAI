import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Printing and PDF packages can generate document', () async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Text('Hello Manuscript'),
          );
        },
      ),
    );

    final bytes = await pdf.save();
    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(100));
  });
}
