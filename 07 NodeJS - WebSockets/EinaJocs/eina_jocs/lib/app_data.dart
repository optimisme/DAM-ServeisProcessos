import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'game_data.dart';

class AppData extends ChangeNotifier {
  int frame = 0;
  final gameFileName = "game_data.json";

  GameData gameData = GameData(name: "", levels: []);
  String filePath = "";
  String fileName = "";

  Map<String, ui.Image> imagesCache = {};

  String selectedSection = "game";
  int selectedLevel = -1;
  int selectedLayer = -1;
  int selectedZone = -1;
  int selectedSprite = -1;

  bool dragging = false;
  DragUpdateDetails? dragUpdateDetails;
  DragStartDetails? dragStartDetails;
  DragEndDetails? dragEndDetails;
  Offset draggingOffset = Offset.zero;

  // Relació entre la imatge dibuixada i el canvas de dibuix
  late Offset imageOffset;
  late double scaleFactor;

  // "tilemap", relació entre el "tilemap" i la imatge dibuixada al canvas
  late Offset tilemapOffset;
  late double tilemapScaleFactor;

  // "tilemap", relació entre el "tileset" i la imatge dibuixada al canvas
  late Offset tilesetOffset;
  late double tilesetScaleFactor;
  int draggingTileIndex = -1;
  int selectedTileIndex = -1;

  // Drag offsets
  late Offset zoneDragOffset = Offset.zero;
  late Offset spriteDragOffset = Offset.zero;

  void update() {
    notifyListeners();
  }

  Future<void> loadGame() async {
    try {
      String? pickerPath = await FilePicker.platform.getDirectoryPath();

      if (pickerPath == null) {
        return;
      }

      String tmpPath = "$pickerPath/$gameFileName";
      final file = File(tmpPath);

      if (!await file.exists()) {
        throw Exception("File not found: $tmpPath");
      }

      filePath = file.parent.path;
      fileName = file.uri.pathSegments.last;

      final content = await file.readAsString();
      final jsonData = jsonDecode(content);
      gameData = GameData.fromJson(jsonData);

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print("Error loading game file: $e");
      }
    }
  }

  Future<void> saveGame() async {
    try {
      if (filePath == "") {
        String? pickerPath = await FilePicker.platform.getDirectoryPath();

        final file = File("$pickerPath/$gameFileName");
        filePath = file.parent.path;
        fileName = file.uri.pathSegments.last;
      }

      final file = File("$filePath/$fileName");
      final jsonData = jsonEncode(gameData.toJson());
      final prettyJson =
          const JsonEncoder.withIndent('  ').convert(jsonDecode(jsonData));

      final numberArrayRegex = RegExp(r'\[\s*((?:-?\d+\s*,\s*)*-?\d+\s*)\]');
      final output = prettyJson.replaceAllMapped(numberArrayRegex, (match) {
        final numbers = match.group(1)!;
        return '[${numbers.replaceAll(RegExp(r'\s+'), ' ').trim()}]';
      });
      await file.writeAsString(output);

      if (kDebugMode) {
        print("Game saved successfully to \"$filePath/$fileName\"");
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print("Error saving game file: $e");
      }
    }
  }

  Future<String> pickImageFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      initialDirectory: filePath != "" ? filePath : null,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );

    if (result == null || result.files.single.path == null) {
      return "";
    }

    String selectedPath = result.files.single.path!;
    String selectedFileName = selectedPath.split(Platform.pathSeparator).last;
    String destinationPath = "$filePath/$selectedFileName";

    if (selectedPath != destinationPath) {
      try {
        await File(selectedPath).copy(destinationPath);
        if (kDebugMode) {
          print("File copied to: $destinationPath");
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error copying file: $e");
        }
        return "";
      }
    }

    return selectedFileName;
  }

  Future<ui.Image> getImage(String imageFileName) async {
    if (!imagesCache.containsKey(imageFileName)) {
      final File file = File("$filePath/$imageFileName");
      if (!await file.exists()) {
        throw Exception("File does not exist: $imageFileName");
      }

      final Uint8List bytes = await file.readAsBytes();
      imagesCache[imageFileName] = await decodeImage(bytes);
    }

    return imagesCache[imageFileName]!;
  }

  Future<ui.Image> decodeImage(Uint8List bytes) {
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(bytes, (ui.Image img) => completer.complete(img));
    return completer.future;
  }
}
