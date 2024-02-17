import 'dart:ui' as ui;
import 'dart:ui';
import 'package:opencv_4/opencv_4.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_qr_bar_scanner/qr_bar_scanner_camera.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter QR Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: QRScanScreen(),
    );
  }
}

class QRScanScreen extends StatefulWidget {
  @override
  _QRScanScreenState createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  List<CameraDescription>? cameras;
  CameraController? controller;
  bool isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    cameras = await availableCameras();
    controller = CameraController(cameras![0], ResolutionPreset.high);
    await controller!.initialize();
    setState(() {
      isCameraInitialized = true;
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isCameraInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: Text('QR Scanner'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('QR Scanner'),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          AspectRatio(
            aspectRatio: controller!.value.aspectRatio,
            child: QRBarScannerCamera(
              onError: (context, error) => Text(
                error.toString(),
                style: TextStyle(color: Colors.red),
              ),
              qrCodeCallback: (code) {
                onQRCodeScanned(code!);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(
                    color: Colors.red,
                    width: 3.0,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            child: Text(
              'Align QR Code within the frame to scan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String encodeForFilename(String qrData) {
    // Replace invalid characters with underscores
    return qrData.replaceAll(RegExp(r'[^\w\d]+'), '_');
  }

  void onQRCodeScanned(String qrData) async {
    print('QR Code Data: $qrData');

    // Encode the QR code data for use in file paths
    final encodedQrData = encodeForFilename(qrData);

    // Generate the QR code image
    final qrImage = await generateQRCodeImage(encodedQrData, Colors.white);

    // Get the directory for saving files
    final directory = await getApplicationDocumentsDirectory();
    print('Directory: ${directory.path}');

    // Save the image to a file with a unique filename based on the QR code data
    final file = File('${directory.path}/qr_code_$encodedQrData.png');

    try {
      await Gal.putImageBytes(qrImage);
      print('Image saved successfully: ${file.path}');
    } catch (e) {
      print('Error saving image: $e');
    }

    setState(() {});
  }


  Future<Uint8List> generateQRCodeImage(String qrData, Color backgroundColor) async {
    final qrPainter = QrPainter(
      data: qrData,
      version: QrVersions.auto,
      gapless: false,
      color: Colors.black, // Set QR code color as needed
      errorCorrectionLevel: QrErrorCorrectLevel.L,
    );

    final qrSize = 700.0; // Adjust the size as needed
    final double borderWidth = 10.0; // Adjust border width as needed
    final double devicePixelRatio = 3.0; // Adjust pixel ratio as needed

    final imageSize = (qrSize * devicePixelRatio).toInt();
    final Paint paint = Paint()..color = backgroundColor;

    // Create a rectangle slightly larger than the QR code to accommodate the border
    final Rect rect = Rect.fromLTWH(0, 0, (imageSize.toDouble()), (imageSize.toDouble()));
    final PictureRecorder recorder = PictureRecorder();
    final Canvas canvas = Canvas(recorder, rect);

    // Draw white background
    canvas.drawRect(rect, paint);

    // Calculate the size of the QR code within the border
    final double qrRectSize = qrSize - borderWidth * 2;

    // Calculate the position to center the QR code within the border
    final double qrOffset = (imageSize - qrRectSize) / 2;

    // Apply translation to move the canvas to the center
    canvas.translate(qrOffset + borderWidth, qrOffset + borderWidth);

    // Create a rectangle for the QR code inside the border
    final ui.Rect qrRect = ui.Rect.fromLTWH(0, 0, qrRectSize, qrRectSize);

    // Draw the QR code onto the canvas
    qrPainter.paint(canvas, Size(qrRectSize, qrRectSize));

    final ui.Picture picture = recorder.endRecording();
    final img = await picture.toImage(imageSize, imageSize);
    final ByteData? byteData = await img.toByteData(format: ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to generate QR code image.');
    }

    return byteData.buffer.asUint8List();
  }



}
