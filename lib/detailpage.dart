import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_svprogresshud/flutter_svprogresshud.dart';
import 'package:photo_view/photo_view.dart';
import 'dart:io';
import 'package:path/path.dart' as p; // Import the path package
import 'package:path_provider/path_provider.dart';

class DetailPage extends StatefulWidget {
  final BluetoothDevice server;

  const DetailPage({required this.server});

  @override
  _DetailPageState createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  BluetoothConnection? connection;
  bool isConnecting = true;

  bool get isConnected => connection?.isConnected ?? false;

  bool isDisconnecting = false;

  List<List<int>> chunks = <List<int>>[];
  int contentLength = 0;
  Uint8List? _bytes;

  // Add constants for start/end markers
  static const int START_MARKER = 0xFF; // JPEG starts with FF D8
  static const int START_MARKER2 = 0xD8;
  static const int END_MARKER = 0xD9; // JPEG ends with FF D9

  bool isStartFound = false;

  // Add counter for saved images
  int savedImageCount = 0;

  // Add command constants
  static const String START_CAPTURE_CMD = "START";

  // Add new variables
  Timer? reconnectionTimer;
  static const reconnectDelay = Duration(seconds: 2); // Adjust timing as needed
  bool shouldTryReconnecting = true;

  @override
  void initState() {
    super.initState();
    _getBTConnection();
  }

  @override
  void dispose() {
    shouldTryReconnecting = false;
    reconnectionTimer?.cancel();
    if (isConnected) {
      isDisconnecting = true;
      connection?.dispose();
      connection = null;
    }
    super.dispose();
  }

  _getBTConnection() {
    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      print('Connected to device');
      connection = _connection;
      isConnecting = false;
      isDisconnecting = false;


      SVProgressHUD.show(status: "Restarting continuous capture...");
      _sendMessage(START_CAPTURE_CMD);

      SVProgressHUD.dismiss();
      setState(() {});
      connection?.input?.listen(_onDataReceived).onDone(() {
        if (isDisconnecting) {
          print('Disconnecting locally');
          shouldTryReconnecting = false;
        } else {
          print('Disconnected remotely');
          if (shouldTryReconnecting) {
            _startReconnectionTimer();
          }
        }
        
        if (this.mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      print('Failed to connect: $error');
      if (shouldTryReconnecting) {
        _startReconnectionTimer();
      }
    });
  }

  void _startReconnectionTimer() {
    reconnectionTimer?.cancel();
    reconnectionTimer = Timer(reconnectDelay, () {
      if (mounted && shouldTryReconnecting && !isConnected) {
        print('Attempting to reconnect...');
        _getBTConnection();
      }
    });
  }

  // Modify _drawImage to just save without displaying
  _processReceivedImage() {
    if (chunks.isEmpty || contentLength == 0) return;

    Uint8List imageBytes = Uint8List(contentLength);
    int offset = 0;
    for (final List<int> chunk in chunks) {
      imageBytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    saveImage(imageBytes);
    setState(() {
      savedImageCount++;
    });


    contentLength = 0;
    chunks.clear();
  }

  Future<void> saveImage(Uint8List imageBytes) async {
    try {
      // Get the public directory for storing pictures
      Directory? picturesDirectory = await getExternalStorageDirectory();

      if (picturesDirectory != null) {
        // Construct the path to the Pictures directory
        String picturesPath = '/storage/emulated/0/Pictures/UbiPictures';

        // Create the folder if it doesn't exist
        Directory saveDir = Directory(picturesPath);
        if (!saveDir.existsSync()) {
          saveDir.createSync(recursive: true);
        }

        // Set the filename and full path
        String fileName = "image_${DateTime.now().millisecondsSinceEpoch}.jpg";
        String filePath = p.join(picturesPath, fileName);

        // Save the image to the file
        File file = File(filePath);
        await file.writeAsBytes(imageBytes);

        print("Image saved at $filePath");
      } else {
        print("Error: Could not access Pictures directory");
      }
    } catch (e) {
      print("Error saving image: $e");
    }
  }

  void _onDataReceived(Uint8List data) {
    if (data.length > 1) {
      // Check for JPEG start marker (FF D8)
      if (data[0] == START_MARKER && data[1] == START_MARKER2) {
        chunks.clear();
        contentLength = 0;
        isStartFound = true;
      }

      if (isStartFound) {
        chunks.add(data);
        contentLength += data.length;

        if (data.length >= 2 && data[data.length - 1] == END_MARKER) {
          _processReceivedImage(); // Renamed from _drawImage
          isStartFound = false;
        }
      }
    }
  }

  void _sendMessage(String text) async {
    text = text.trim();
    if (text.length > 0) {
      try {
        connection?.output.add(utf8.encode(text));

        await connection?.output.allSent;
      } catch (e) {
        setState(() {});
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: (isConnecting
              ? Text('Connecting to ${widget.server.name} ...')
              : isConnected
                  ? Text('Connected with ${widget.server.name}')
                  : Text('Disconnected - Trying to reconnect...')),
        ),
        body: SafeArea(
          child: isConnected
              ? Column(
                  children: <Widget>[
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: 16),
                            Text(
                              'Images saved: $savedImageCount',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Text(
                    "Connecting...",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
        ));
  }
}
