import 'package:flutter_test/flutter_test.dart';
import 'package:ntbp_plugin/ntbp_plugin.dart';

void main() {
  const sample = CargoLabel(
    bookingReference: 'BK-1025',
    item: 'ITEM-001 / 5',
    sender: [
      'Otapp Agency Limited',
      'P.O. Box 1234',
      'Dar es Salaam, Tanzania',
      'Tel: +255 712 345 678',
    ],
    receiver: [
      'John Mwakyusa',
      'P.O. Box 5678',
      'Kinondoni, Dar es Salaam',
      'Tel: +255 765 432 109',
    ],
    destination: 'DAR ES SALAAM',
    weight: '5.0 KG',
    package: '1 / 5',
    serviceType: 'Standard',
    date: '2025-10-19',
    trackingNumber: '123456789012',
  );

  test('job starts with media setup and ends with PRINT', () {
    final job = CargoLabelLayout.buildJob(sample, const LabelPrintConfig());
    final lines = job.trimRight().split('\r\n');
    expect(lines.first, 'SIZE 100 mm,150 mm');
    expect(lines[1], 'GAP 3 mm,0 mm');
    expect(lines, contains('DIRECTION 0,0'));
    expect(lines, contains('REFERENCE 0,0'));
    expect(lines, contains('CLS'));
    expect(lines.last, 'PRINT 1,1');
    expect(job, isNot(contains('CLEAR')));
    expect(job, isNot(contains('GAPDETECT')));
    expect(job, isNot(contains('HOME')));
    expect(job, isNot(contains('FORMFEED')));
  });

  test('every field is present and quotes are escaped', () {
    final job = CargoLabelLayout.buildJob(
      sample.copyWithTitle('CARGO "X"'),
      const LabelPrintConfig(),
    );
    for (final text in [
      'BOOKING REFERENCE',
      'BK-1025',
      'ITEM-001 / 5',
      'SENDER',
      'Otapp Agency Limited',
      'RECEIVER',
      'John Mwakyusa',
      'DESTINATION',
      'DAR ES SALAAM',
      'WEIGHT',
      '5.0 KG',
      'PACKAGE',
      '1 / 5',
      'SERVICE TYPE',
      'Standard',
      'DATE',
      '2025-10-19',
      'TRACKING NO.',
    ]) {
      expect(job, contains('"$text"'), reason: text);
    }
    expect(job, contains('"CARGO \'X\'"'));
    expect(job, contains('BARCODE'));
    expect(job, contains('"128",'));
    expect(job, contains('QRCODE'));
    expect(job, contains('"123456789012"'));
  });

  test('all drawing stays inside the label', () {
    const config = LabelPrintConfig();
    final job = CargoLabelLayout.buildJob(sample, config);
    final w = config.widthDots;
    final h = config.heightDots;

    for (final line in job.split('\r\n')) {
      final m = RegExp(r'^(TEXT|QRCODE|BARCODE|BOX|BAR) (\d+),(\d+)').firstMatch(line);
      if (m == null) continue;
      final x = int.parse(m.group(2)!);
      final y = int.parse(m.group(3)!);
      expect(x, inInclusiveRange(0, w), reason: line);
      expect(y, inInclusiveRange(0, h), reason: line);
      if (m.group(1) == 'BOX') {
        final parts = line.substring(4).split(',');
        expect(int.parse(parts[2]), lessThanOrEqualTo(w), reason: line);
        expect(int.parse(parts[3]), lessThanOrEqualTo(h), reason: line);
      }
    }
  });

  test('value fonts shrink to fit their cells', () {
    final job = CargoLabelLayout.buildJob(
      sample,
      const LabelPrintConfig(),
    );
    // DAR ES SALAAM is 13 chars; font 5 (32 px) would be 416 wide, which
    // does not fit the 348 px cell, so font 4 must be chosen.
    expect(job, contains(RegExp(r'TEXT \d+,\d+,"4",0,1,1,"DAR ES SALAAM"')));
    // Title fits in font 5.
    expect(job, contains(RegExp(r'TEXT \d+,\d+,"5",0,1,1,"CARGO SHIPMENT"')));
  });

  test('copies and density flow into the job', () {
    final job = CargoLabelLayout.buildJob(
      sample,
      const LabelPrintConfig(copies: 3, density: 10, gapMm: 2.5),
    );
    expect(job, contains('DENSITY 10'));
    expect(job, contains('GAP 2.5 mm,0 mm'));
    expect(job.trimRight().split('\r\n').last, 'PRINT 1,3');
  });

  test('scales to a smaller label', () {
    const config = LabelPrintConfig(widthMm: 75, heightMm: 112.5);
    final job = CargoLabelLayout.buildJob(sample, config);
    expect(job, startsWith('SIZE 75 mm,112.5 mm'));
    for (final line in job.split('\r\n')) {
      final m = RegExp(r'^BOX (\d+),(\d+),(\d+),(\d+)').firstMatch(line);
      if (m == null) continue;
      expect(int.parse(m.group(3)!), lessThanOrEqualTo(config.widthDots));
      expect(int.parse(m.group(4)!), lessThanOrEqualTo(config.heightDots));
    }
  });

  test('three-line label matches the v2 Android geometry', () {
    const config = LabelPrintConfig(widthMm: 75, heightMm: 60, gapMm: 3);
    final p = ThreeLineQrLayout.positions(config);
    // 75 mm at 203 dpi = 599 dots, margin 4 mm = 31 dots.
    expect(config.widthDots, 599);
    expect(p['qrX'], 31 + (537 - p['qrSize']!) ~/ 2);
    expect(p['textX'], p['qrX']);
    expect(p['textY2']! - p['textY1']!, 31);
    final job = ThreeLineQrLayout.buildJob(
      const ThreeLineQrLabel(qrData: 'XYZ', line1: 'A', line2: 'B', line3: 'C'),
      config,
    );
    expect(job, contains('QRCODE ${p['qrX']},${p['qrY']},H,10,A,0,"XYZ"'));
    expect(job, contains('TEXT ${p['textX']},${p['textY1']},"9",0,1,1,"A"'));
    expect(job.trimRight().split('\r\n').last, 'PRINT 1,1');
  });

  test('printer status decodes the bit field', () {
    expect(const PrinterStatus(0).name, 'ready');
    expect(const PrinterStatus(4).name, 'out_of_paper');
    expect(const PrinterStatus(5).name, 'head_open+out_of_paper');
    expect(const PrinterStatus(32).isPrinting, isTrue);
    expect(const PrinterStatus(32).hasError, isFalse);
    expect(PrinterStatus.noResponse.responded, isFalse);
  });
}

extension on CargoLabel {
  CargoLabel copyWithTitle(String title) =>
      CargoLabel.fromMap({...toMap(), 'title': title});
}
