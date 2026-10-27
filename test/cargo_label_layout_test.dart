import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ntbp_plugin/ntbp_plugin.dart';

void main() {
  const sample = CargoLabel(
    brandName: 'BM Coach',
    bookingReference: 'BK-1025',
    item: 'BK1025-001',
    cargoName: 'Spare parts (engine)',
    sender: ['Otapp Agency Limited', 'Tel: +255 712 345 678'],
    receiver: ['John Mwakyusa', 'Tel: +255 765 432 109'],
    destination: 'DAR ES SALAAM',
    weight: '5.0 KG',
    package: '1 / 5',
    source: 'MWANZA',
    date: '2025-10-19',
  );

  List<String> lines(String job) => job.trimRight().split('\r\n');

  test('job starts with media setup and ends with PRINT', () {
    final job = CargoLabelLayout.buildJob(sample, const LabelPrintConfig());
    final l = lines(job);
    expect(l.first, 'SIZE 100 mm,150 mm');
    expect(l[1], 'GAP 3 mm,0 mm');
    expect(l, contains('DIRECTION 0,0'));
    expect(l, contains('REFERENCE 0,0'));
    expect(l, contains('CLS'));
    expect(l.last, 'PRINT 1,1');
    expect(job, isNot(contains('CLEAR')));
    expect(job, isNot(contains('GAPDETECT')));
    expect(job, isNot(contains('HOME')));
    expect(job, isNot(contains('FORMFEED')));
  });

  test('every field is present, no title, quotes are escaped', () {
    final job = CargoLabelLayout.buildJob(
      sample.copyWith(destination: 'DAR "ES" SALAAM'),
      const LabelPrintConfig(),
    );
    for (final text in [
      'BM Coach',
      'BOOKING REFERENCE',
      'BK-1025',
      'ITEM',
      'BK1025-001',
      'SENDER',
      'Otapp Agency Limited',
      'Tel: +255 712 345 678',
      'RECEIVER',
      'John Mwakyusa',
      'DESTINATION',
      'WEIGHT',
      '5.0 KG',
      'PACKAGE',
      '1 / 5',
      'SOURCE',
      'MWANZA',
      'DATE',
      '2025-10-19',
      'CARGO NAME',
      'Spare parts (engine)',
    ]) {
      expect(job, contains('"$text"'), reason: text);
    }
    expect(job, contains('"DAR \'ES\' SALAAM"'));
    expect(job, isNot(contains('CARGO SHIPMENT')));
    expect(job, isNot(contains('SERVICE TYPE')));
    expect(job, isNot(contains('TRACKING')));
    expect(job, isNot(contains('BARCODE')));
    expect(job, isNot(contains('BITMAP')), reason: 'no logo given');
  });

  test('cargo name uses the largest font that fits and wraps long names', () {
    final short = CargoLabelLayout.buildJob(sample, const LabelPrintConfig());
    expect(short, contains(RegExp(r'TEXT \d+,\d+,"5",0,1,1,"Spare parts \(engine\)"')));

    // 31 chars: too long for one line of font 4 (28 chars at 688 dots),
    // so it wraps to two lines of font 4.
    final medium = CargoLabelLayout.buildJob(
      sample.copyWith(cargoName: 'Assorted motorcycle spare parts'),
      const LabelPrintConfig(),
    );
    expect(medium, contains(RegExp(r'TEXT \d+,\d+,"4",0,1,1,"Assorted motorcycle spare"')));
    expect(medium, contains(RegExp(r'TEXT \d+,\d+,"4",0,1,1,"parts"')));

    // 59 chars needs three lines of font 4, so it drops to font 3 (43 chars
    // per line) where two lines are enough.
    final long = CargoLabelLayout.buildJob(
      sample.copyWith(cargoName: 'Twelve cartons of assorted motorcycle spare parts and tools'),
      const LabelPrintConfig(),
    );
    expect(long, contains(RegExp(r'TEXT \d+,\d+,"3",0,1,1,"Twelve cartons of assorted motorcycle"')));
    expect(long, contains(RegExp(r'TEXT \d+,\d+,"3",0,1,1,"spare parts and tools"')));
    expect(long, isNot(contains(RegExp(r'TEXT \d+,\d+,"4",0,1,1,"Twelve'))));

    final empty = CargoLabelLayout.buildJob(sample.copyWith(cargoName: ''), const LabelPrintConfig());
    expect(empty, contains('"CARGO NAME"'));

    expect(CargoLabelLayout.wrapText('a bb ccc dddd', 5), ['a bb', 'ccc', 'dddd']);
    expect(CargoLabelLayout.wrapText('abcdefgh', 3), ['abc', 'def', 'gh']);
  });

  test('generateReference builds clean Code 128 friendly ids', () {
    expect(CargoLabel.generateReference('BK-1025', 1), 'BK1025-001');
    expect(CargoLabel.generateReference('bk 10/25', 12), 'BK1025-012');
    expect(CargoLabel.generateReference('', 3), 'ITEM-003');
    expect(CargoLabel.generateReference('BK-1025', 7, digits: 2), 'BK1025-07');
  });

  test('all drawing stays inside the label', () {
    const config = LabelPrintConfig();
    final job = CargoLabelLayout.buildJob(sample, config);
    final w = config.widthDots;
    final h = config.heightDots;

    for (final line in lines(job)) {
      final m = RegExp(r'^(TEXT|QRCODE|BOX|BAR) (\d+),(\d+)').firstMatch(line);
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
    final job = CargoLabelLayout.buildJob(sample, const LabelPrintConfig());
    expect(job, contains(RegExp(r'TEXT \d+,\d+,"4",0,1,1,"DAR ES SALAAM"')));
    // Sender name gets the larger font, phone the body font.
    expect(job, contains(RegExp(r'TEXT \d+,\d+,"4",0,1,1,"Otapp Agency Limited"')));
    expect(job, contains(RegExp(r'TEXT \d+,\d+,"3",0,1,1,"Tel: \+255 712 345 678"')));
  });

  test('QR encodes a readable summary by default', () {
    final summary = sample.summaryText();
    expect(summary, startsWith('BOOKING REFERENCE: BK-1025 | ITEM: BK1025-001'));
    expect(summary, contains('SENDER: Otapp Agency Limited, Tel: +255 712 345 678'));
    expect(summary, contains('CARGO NAME: Spare parts (engine)'));
    expect(summary, contains('SOURCE: MWANZA'));
    expect(summary, isNot(contains('TRACKING')));
    expect(summary, isNot(contains('CARGO SHIPMENT')));
    expect(sample.effectiveQrData, summary);

    final job = CargoLabelLayout.buildJob(sample, const LabelPrintConfig());
    final qr = RegExp(r'QRCODE (\d+),(\d+),M,(\d+),A,0,"([^"]*)"').firstMatch(job)!;
    expect(qr.group(4), summary);
    expect(int.parse(qr.group(3)!), greaterThanOrEqualTo(3));
    expect(int.parse(qr.group(1)!), greaterThan(300));

    expect(sample.copyWith(qrContent: CargoQrContent.itemReference).effectiveQrData, 'BK1025-001');
    expect(sample.copyWith(qrContent: CargoQrContent.custom, qrData: 'https://x.y/z').effectiveQrData,
        'https://x.y/z');
  });

  test('logo is printed at the top right as a BITMAP, brand at the left', () {
    // 200 x 80 image: left half black, right half white.
    final image = img.Image(width: 200, height: 80);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    img.fillRect(image, x1: 0, y1: 0, x2: 99, y2: 79, color: img.ColorRgb8(0, 0, 0));
    final logo = CargoLogo.fromBytes(Uint8List.fromList(img.encodePng(image)))!;

    // Scaled up to fill the 110 dot high logo box (never more than 2x).
    final mono = logo.toMono(maxWidth: 360, maxHeight: 110);
    expect(mono.height, 110);
    expect(mono.width, 275);
    expect(mono.widthBytes, 35);
    expect(mono.data.length, 35 * 110);
    expect(mono.inkCoverage, closeTo(0.5, 0.02));
    // First byte of first row is black (0x00), last byte white (0xFF).
    expect(mono.data[0], 0x00);
    expect(mono.data[34], 0xFF);

    // A big logo is shrunk to the box.
    final big = logo.toMono(maxWidth: 100, maxHeight: 100);
    expect(big.width, 100);
    expect(big.height, 40);

    const config = LabelPrintConfig();
    final job = CargoLabelLayout.buildJob(sample, config, logo: logo);
    final m = RegExp(r'BITMAP (\d+),(\d+),(\d+),(\d+),0,').firstMatch(job)!;
    final bx = int.parse(m.group(1)!);
    expect(int.parse(m.group(3)!), 35);
    expect(int.parse(m.group(4)!), 110);
    // Right-aligned to the content edge (760 on the unscaled reference grid).
    expect(bx + 275, closeTo(760, 1));
    expect(int.parse(m.group(2)!), lessThan(150));
    // Brand name sits at the left of the band, in a font that fits beside the logo.
    final brand = RegExp(r'TEXT (\d+),(\d+),"(\d)",0,1,1,"BM Coach"').firstMatch(job)!;
    expect(int.parse(brand.group(1)!), 40);
    expect(int.parse(brand.group(2)!), lessThan(150));
    expect(TsplFont.textWidth(brand.group(3)!, 'BM Coach'), lessThan(bx - 40 - 24));

    // Bytes round-trip through latin1 and the readable preview hides them.
    final bytes = TsplBuilder()..raw('X');
    expect(bytes.toBytes(), [0x58, 0x0D, 0x0A]);
    final readable = TsplBuilder.makeReadable(job);
    expect(readable, contains('<3850 bytes of image data>'));
    expect(readable.length, lessThan(job.length));
  });

  test('copies and density flow into the job', () {
    final job = CargoLabelLayout.buildJob(
      sample,
      const LabelPrintConfig(copies: 3, density: 10, gapMm: 2.5),
    );
    expect(job, contains('DENSITY 10'));
    expect(job, contains('GAP 2.5 mm,0 mm'));
    expect(lines(job).last, 'PRINT 1,3');
  });

  test('scales to a smaller label', () {
    const config = LabelPrintConfig(widthMm: 75, heightMm: 112.5);
    final job = CargoLabelLayout.buildJob(sample, config);
    expect(job, startsWith('SIZE 75 mm,112.5 mm'));
    for (final line in lines(job)) {
      final m = RegExp(r'^BOX (\d+),(\d+),(\d+),(\d+)').firstMatch(line);
      if (m == null) continue;
      expect(int.parse(m.group(3)!), lessThanOrEqualTo(config.widthDots));
      expect(int.parse(m.group(4)!), lessThanOrEqualTo(config.heightDots));
    }
  });

  test('map round trip keeps every field and reads legacy serviceType', () {
    final copy = CargoLabel.fromMap(sample.toMap());
    expect(copy.toMap(), sample.toMap());
    final legacy = CargoLabel.fromMap({...sample.toMap()..remove('source'), 'serviceType': 'Express'});
    expect(legacy.source, 'Express');
  });

  test('non Latin-1 text is replaced so the byte stream stays valid', () {
    expect(TsplBuilder.escape('Café ✓ "x"'), "Café ? 'x'");
  });

  test('three-line label matches the v2 Android geometry', () {
    const config = LabelPrintConfig(widthMm: 75, heightMm: 60, gapMm: 3);
    final p = ThreeLineQrLayout.positions(config);
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
    expect(lines(job).last, 'PRINT 1,1');
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
