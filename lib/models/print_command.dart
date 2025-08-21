enum PrintAlignment { left, center, right }
enum PrintFontSize { small, medium, large }
enum PrintFontWeight { normal, bold }

class PrintCommand {
  final String text;
  final PrintAlignment alignment;
  final PrintFontSize fontSize;
  final PrintFontWeight fontWeight;
  final bool isBarcode;
  final bool isQRCode;
  final String? barcodeData;
  final int? lineSpacing;
  
  // Advanced positioning
  final double? x;
  final double? y;
  final double? xMultiplication;
  final double? yMultiplication;
  final int? rotation;
  final String? codePage;
  final int? fontNumber;
  
  // Image printing
  final bool isImage;
  final String? imagePath;
  final double? imageWidth;
  final double? imageHeight;
  
  // Block printing
  final bool isBlock;
  final double? blockWidth;
  final double? blockHeight;
  final int? blockLineWidth;
  final int? blockLineStyle;
  final String? blockText;

  PrintCommand({
    required this.text,
    this.alignment = PrintAlignment.left,
    this.fontSize = PrintFontSize.medium,
    this.fontWeight = PrintFontWeight.normal,
    this.isBarcode = false,
    this.isQRCode = false,
    this.barcodeData,
    this.lineSpacing,
    this.x,
    this.y,
    this.xMultiplication,
    this.yMultiplication,
    this.rotation,
    this.codePage,
    this.fontNumber,
    this.isImage = false,
    this.imagePath,
    this.imageWidth,
    this.imageHeight,
    this.isBlock = false,
    this.blockWidth,
    this.blockHeight,
    this.blockLineWidth,
    this.blockLineStyle,
    this.blockText,
  });

  factory PrintCommand.text(
    String text, {
    PrintAlignment alignment = PrintAlignment.left,
    PrintFontSize fontSize = PrintFontSize.medium,
    PrintFontWeight fontWeight = PrintFontWeight.normal,
    double? x,
    double? y,
    double? xMultiplication,
    double? yMultiplication,
    int? rotation,
    String? codePage,
    int? fontNumber,
  }) {
    return PrintCommand(
      text: text,
      alignment: alignment,
      fontSize: fontSize,
      fontWeight: fontWeight,
      x: x,
      y: y,
      xMultiplication: xMultiplication,
      yMultiplication: yMultiplication,
      rotation: rotation,
      codePage: codePage,
      fontNumber: fontNumber,
    );
  }

  factory PrintCommand.barcode(
    String data, {
    double? x,
    double? y,
    int? rotation,
    String? codePage,
  }) {
    return PrintCommand(
      text: '',
      isBarcode: true,
      barcodeData: data,
      x: x,
      y: y,
      rotation: rotation,
      codePage: codePage,
    );
  }

  factory PrintCommand.qrCode(
    String data, {
    double? x,
    double? y,
    String? size = "M",
    String? errorCorrection = "5",
    String? model = "M1",
    int? rotation = 0,
  }) {
    return PrintCommand(
      text: '',
      isQRCode: true,
      barcodeData: data,
      x: x,
      y: y,
      rotation: rotation,
    );
  }

  factory PrintCommand.lineSpacing(int spacing) {
    return PrintCommand(
      text: '',
      lineSpacing: spacing,
    );
  }

  factory PrintCommand.image(
    String imagePath, {
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return PrintCommand(
      text: '',
      isImage: true,
      imagePath: imagePath,
      x: x,
      y: y,
      imageWidth: width,
      imageHeight: height,
    );
  }

  factory PrintCommand.block(
    String text, {
    double? x,
    double? y,
    double? width,
    double? height,
    int? lineWidth = 0,
    int? lineStyle = 0,
  }) {
    return PrintCommand(
      text: '',
      isBlock: true,
      blockText: text,
      x: x,
      y: y,
      blockWidth: width,
      blockHeight: height,
      blockLineWidth: lineWidth,
      blockLineStyle: lineStyle,
    );
  }

  factory PrintCommand.setPrintArea(double width, double height) {
    return PrintCommand(
      text: '',
      x: width,
      y: height,
    );
  }

  factory PrintCommand.clearScreen() {
    return PrintCommand(
      text: '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'alignment': alignment.name,
      'fontSize': fontSize.name,
      'fontWeight': fontWeight.name,
      'isBarcode': isBarcode,
      'isQRCode': isQRCode,
      'barcodeData': barcodeData,
      'lineSpacing': lineSpacing,
      'x': x,
      'y': y,
      'xMultiplication': xMultiplication,
      'yMultiplication': yMultiplication,
      'rotation': rotation,
      'codePage': codePage,
      'fontNumber': fontNumber,
      'isImage': isImage,
      'imagePath': imagePath,
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
      'isBlock': isBlock,
      'blockWidth': blockWidth,
      'blockHeight': blockHeight,
      'blockLineWidth': blockLineWidth,
      'blockLineStyle': blockLineStyle,
      'blockText': blockText,
    };
  }
} 