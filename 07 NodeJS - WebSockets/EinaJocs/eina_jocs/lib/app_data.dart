import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'game_data.dart';
import 'game_media_asset.dart';

class StoredProject {
  final String id;
  final String folderName;
  final String createdAt;
  String name;
  String updatedAt;

  StoredProject({
    required this.id,
    required this.name,
    required this.folderName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StoredProject.fromJson(Map<String, dynamic> json) {
    return StoredProject(
      id: json['id'] as String,
      name: json['name'] as String,
      folderName: json['folderName'] as String,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'folderName': folderName,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class AppData extends ChangeNotifier {
  static const String appFolderName = "EinaJocs";
  static const String projectsFolderName = "projects";
  static const String projectsIndexFileName = "projects_index.json";
  static const Color defaultTilesetSelectionColor = Color(0xFFFFCC00);
  int frame = 0;
  final gameFileName = "game_data.json";

  GameData gameData = GameData(name: "", levels: []);
  String filePath = "";
  String fileName = "";
  bool storageReady = false;
  String storagePath = "";
  String projectsPath = "";
  String selectedProjectId = "";
  String projectStatusMessage = "";
  List<StoredProject> projects = [];

  Map<String, ui.Image> imagesCache = {};

  String selectedSection = "projects";
  int selectedLevel = -1;
  int selectedLayer = -1;
  int selectedZone = -1;
  int selectedSprite = -1;
  int selectedMedia = -1;

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
  List<List<int>> selectedTilePattern = [];
  bool tilemapEraserEnabled = false;
  int tilesetSelectionColStart = -1;
  int tilesetSelectionRowStart = -1;
  int tilesetSelectionColEnd = -1;
  int tilesetSelectionRowEnd = -1;

  // Drag offsets
  late Offset zoneDragOffset = Offset.zero;
  late Offset spriteDragOffset = Offset.zero;

  // Layers canvas viewport (zoom + pan)
  double layersViewScale = 1.0;
  Offset layersViewOffset = Offset.zero;
  Offset layerDragOffset = Offset.zero;

  // Undo / redo stacks (JSON snapshots of gameData)
  final List<Map<String, dynamic>> _undoStack = [];
  final List<Map<String, dynamic>> _redoStack = [];
  static const int _maxUndoSteps = 50;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Call this BEFORE mutating gameData to record a checkpoint.
  void pushUndo() {
    _undoStack.add(gameData.toJson());
    if (_undoStack.length > _maxUndoSteps) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(gameData.toJson());
    gameData = GameData.fromJson(_undoStack.removeLast());
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(gameData.toJson());
    gameData = GameData.fromJson(_redoStack.removeLast());
    notifyListeners();
  }

  void update() {
    notifyListeners();
  }

  StoredProject? _findProjectById(String projectId) {
    for (final project in projects) {
      if (project.id == projectId) {
        return project;
      }
    }
    return null;
  }

  StoredProject? get selectedProject {
    return _findProjectById(selectedProjectId);
  }

  Future<void> initializeStorage() async {
    try {
      final Directory appSupportDirectory =
          await getApplicationSupportDirectory();
      final Directory appStorageDirectory = Directory(
          "${appSupportDirectory.path}${Platform.pathSeparator}$appFolderName");
      if (!await appStorageDirectory.exists()) {
        await appStorageDirectory.create(recursive: true);
      }
      storagePath = appStorageDirectory.path;
      projectsPath = "$storagePath${Platform.pathSeparator}$projectsFolderName";

      await _loadProjectsIndex();

      final Directory projectsDirectory = Directory(projectsPath);
      if (!await projectsDirectory.exists()) {
        await projectsDirectory.create(recursive: true);
      }

      await _syncProjectsWithDisk();

      if (selectedProjectId != "" && selectedProject != null) {
        await openProject(selectedProjectId, notify: false);
      } else {
        selectedProjectId = "";
        gameData = GameData(name: "", levels: []);
        filePath = "";
        fileName = "";
      }

      storageReady = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print("Error initializing storage: $e");
      }
      projectStatusMessage = "Storage initialization failed: $e";
      notifyListeners();
    }
  }

  Future<void> _loadProjectsIndex() async {
    projects = [];
    selectedProjectId = "";

    final File indexFile = File(
      "$storagePath${Platform.pathSeparator}$projectsIndexFileName",
    );
    if (!await indexFile.exists()) {
      return;
    }

    final String raw = await indexFile.readAsString();
    if (raw.trim().isEmpty) {
      return;
    }

    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    selectedProjectId = (decoded['selectedProjectId'] as String?) ?? "";
    final dynamic listDynamic = decoded['projects'];
    if (listDynamic is! List<dynamic>) {
      return;
    }

    projects = listDynamic
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(StoredProject.fromJson)
        .toList();
  }

  Future<void> _saveProjectsIndex() async {
    if (storagePath == "") {
      return;
    }
    final File indexFile =
        File("$storagePath${Platform.pathSeparator}$projectsIndexFileName");
    final String content = const JsonEncoder.withIndent("  ").convert({
      'version': 1,
      'selectedProjectId': selectedProjectId,
      'projects': projects.map((project) => project.toJson()).toList(),
    });
    await indexFile.writeAsString(content);
  }

  Future<void> _syncProjectsWithDisk() async {
    final Directory projectsDirectory = Directory(projectsPath);
    if (!await projectsDirectory.exists()) {
      return;
    }

    final Set<String> knownFolders =
        projects.map((project) => project.folderName).toSet();
    final List<StoredProject> discoveredProjects = [];

    await for (final entity in projectsDirectory.list(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }
      final File gameFile =
          File("${entity.path}${Platform.pathSeparator}$gameFileName");
      if (!await gameFile.exists()) {
        continue;
      }

      final String folderName = _lastPathSegment(entity.path);
      if (!knownFolders.contains(folderName)) {
        final String inferredName =
            await _readProjectNameFromDisk(gameFile) ?? folderName;
        discoveredProjects.add(
          StoredProject(
            id: _newProjectId(),
            name: inferredName,
            folderName: folderName,
            createdAt: DateTime.now().toUtc().toIso8601String(),
            updatedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        );
      }
    }

    projects = projects.where((project) {
      final File gameFile = File(
        "$projectsPath${Platform.pathSeparator}${project.folderName}${Platform.pathSeparator}$gameFileName",
      );
      return gameFile.existsSync();
    }).toList();

    projects.addAll(discoveredProjects);
    await _saveProjectsIndex();
  }

  Future<String?> _readProjectNameFromDisk(File gameFile) async {
    try {
      final dynamic decoded = jsonDecode(await gameFile.readAsString());
      if (decoded is Map<String, dynamic>) {
        final dynamic name = decoded['name'];
        if (name is String && name.trim().isNotEmpty) {
          return name.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  String _newProjectId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  String _lastPathSegment(String value) {
    final List<String> parts = value
        .split(Platform.pathSeparator)
        .where((item) => item != "")
        .toList();
    return parts.isEmpty ? value : parts.last;
  }

  String _sanitizeFolderName(String value) {
    final String cleaned = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_\-]+'), "_")
        .replaceAll(RegExp(r'_+'), "_")
        .replaceAll(RegExp(r'^_|_$'), "");
    return cleaned.isEmpty ? "project" : cleaned;
  }

  Future<String> _buildUniqueProjectFolderName(String baseFolderName) async {
    String candidate = baseFolderName;
    int cnt = 2;
    while (await Directory(
      "$projectsPath${Platform.pathSeparator}$candidate",
    ).exists()) {
      candidate = "${baseFolderName}_$cnt";
      cnt++;
    }
    return candidate;
  }

  Future<String> _buildUniqueFileNameInDirectory(
    String directoryPath,
    String originalFileName,
  ) async {
    final int dotIndex = originalFileName.lastIndexOf('.');
    final String baseName = dotIndex <= 0
        ? originalFileName
        : originalFileName.substring(0, dotIndex);
    final String extension =
        dotIndex <= 0 ? "" : originalFileName.substring(dotIndex);

    String candidate = originalFileName;
    int cnt = 2;
    while (await File(
      "$directoryPath${Platform.pathSeparator}$candidate",
    ).exists()) {
      candidate = "${baseName}_$cnt$extension";
      cnt++;
    }
    return candidate;
  }

  String _normalizeArchivePath(String value) {
    return value.replaceAll('\\', '/');
  }

  String _archiveRootPrefixFromGameData(Archive archive) {
    final List<String> gameDataEntries = archive.files
        .where((file) => file.isFile)
        .map((file) => _normalizeArchivePath(file.name))
        .where(
            (name) => name == gameFileName || name.endsWith('/$gameFileName'))
        .toList();

    if (gameDataEntries.isEmpty) {
      throw Exception("ZIP does not contain $gameFileName");
    }

    gameDataEntries.sort((a, b) {
      final int depthA = a.split('/').length;
      final int depthB = b.split('/').length;
      return depthA.compareTo(depthB);
    });
    final String selected = gameDataEntries.first;
    if (selected == gameFileName) {
      return "";
    }
    return selected.substring(0, selected.length - gameFileName.length);
  }

  void _resetWorkingProjectData() {
    selectedProjectId = "";
    gameData = GameData(name: "", levels: []);
    filePath = "";
    fileName = "";
    selectedLevel = -1;
    selectedLayer = -1;
    selectedZone = -1;
    selectedSprite = -1;
    selectedMedia = -1;
    selectedTileIndex = -1;
    selectedTilePattern = [];
    tilemapEraserEnabled = false;
    tilesetSelectionColStart = -1;
    tilesetSelectionRowStart = -1;
    tilesetSelectionColEnd = -1;
    tilesetSelectionRowEnd = -1;
    layersViewScale = 1.0;
    layersViewOffset = Offset.zero;
    layerDragOffset = Offset.zero;
    _undoStack.clear();
    _redoStack.clear();
    imagesCache.clear();
  }

  Future<String> _formatMapAsGameJson(Map<String, dynamic> data) async {
    final String jsonData = jsonEncode(data);
    final String prettyJson =
        const JsonEncoder.withIndent('  ').convert(jsonDecode(jsonData));

    final numberArrayRegex = RegExp(r'\[\s*((?:-?\d+\s*,\s*)*-?\d+\s*)\]');
    return prettyJson.replaceAllMapped(numberArrayRegex, (match) {
      final numbers = match.group(1)!;
      return '[${numbers.replaceAll(RegExp(r'\s+'), ' ').trim()}]';
    });
  }

  Future<String> createProject({String? projectName}) async {
    if (projectsPath == "") {
      await initializeStorage();
    }

    final String defaultName = projectName?.trim().isNotEmpty == true
        ? projectName!.trim()
        : "New Project";
    final String folderName = await _buildUniqueProjectFolderName(
      _sanitizeFolderName(defaultName),
    );
    final Directory projectDirectory =
        Directory("$projectsPath${Platform.pathSeparator}$folderName");
    await projectDirectory.create(recursive: true);

    final String now = DateTime.now().toUtc().toIso8601String();
    final StoredProject newProject = StoredProject(
      id: _newProjectId(),
      name: defaultName,
      folderName: folderName,
      createdAt: now,
      updatedAt: now,
    );
    projects.add(newProject);
    selectedProjectId = newProject.id;

    gameData = GameData(name: defaultName, levels: []);
    selectedLevel = -1;
    selectedLayer = -1;
    selectedZone = -1;
    selectedSprite = -1;
    selectedMedia = -1;
    selectedTileIndex = -1;
    selectedTilePattern = [];
    tilemapEraserEnabled = false;
    tilesetSelectionColStart = -1;
    tilesetSelectionRowStart = -1;
    tilesetSelectionColEnd = -1;
    tilesetSelectionRowEnd = -1;
    _undoStack.clear();
    _redoStack.clear();
    imagesCache.clear();

    filePath = projectDirectory.path;
    fileName = gameFileName;
    await saveGame();
    await _saveProjectsIndex();
    projectStatusMessage = "Created project \"$defaultName\"";
    notifyListeners();
    return newProject.id;
  }

  Future<bool> renameProject(String projectId, String newName) async {
    final String cleanName = newName.trim();
    if (cleanName.isEmpty) {
      return false;
    }
    final StoredProject? project = _findProjectById(projectId);
    if (project == null) {
      return false;
    }

    project.name = cleanName;
    project.updatedAt = DateTime.now().toUtc().toIso8601String();

    final String projectPath =
        "$projectsPath${Platform.pathSeparator}${project.folderName}";
    final File file =
        File("$projectPath${Platform.pathSeparator}$gameFileName");
    if (await file.exists()) {
      final dynamic decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        decoded['name'] = cleanName;
        final String output = await _formatMapAsGameJson(decoded);
        await file.writeAsString(output);
      }
    }

    if (selectedProjectId == projectId) {
      gameData = GameData(
        name: cleanName,
        levels: gameData.levels,
        mediaAssets: gameData.mediaAssets,
      );
    }

    await _saveProjectsIndex();
    projectStatusMessage = "Renamed project to \"$cleanName\"";
    notifyListeners();
    return true;
  }

  Future<bool> deleteProject(String projectId) async {
    final StoredProject? project = _findProjectById(projectId);
    if (project == null) {
      return false;
    }

    try {
      final Directory projectDirectory = Directory(
        "$projectsPath${Platform.pathSeparator}${project.folderName}",
      );
      if (await projectDirectory.exists()) {
        await projectDirectory.delete(recursive: true);
      }
      projects.removeWhere((item) => item.id == projectId);
      if (selectedProjectId == projectId) {
        _resetWorkingProjectData();
      }
      await _saveProjectsIndex();
      projectStatusMessage = "Deleted project \"${project.name}\"";
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print("Error deleting project: $e");
      }
      projectStatusMessage = "Delete failed: $e";
      notifyListeners();
      return false;
    }
  }

  Future<void> openProject(String projectId, {bool notify = true}) async {
    try {
      final StoredProject? project = _findProjectById(projectId);
      if (project == null) {
        return;
      }

      final String projectPath =
          "$projectsPath${Platform.pathSeparator}${project.folderName}";
      final File file =
          File("$projectPath${Platform.pathSeparator}$gameFileName");
      if (!await file.exists()) {
        throw Exception("Project file not found in: ${file.path}");
      }

      final dynamic decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw Exception("Invalid game_data.json structure");
      }

      gameData = GameData.fromJson(decoded);
      selectedProjectId = projectId;
      filePath = projectPath;
      fileName = gameFileName;
      selectedLevel = -1;
      selectedLayer = -1;
      selectedZone = -1;
      selectedSprite = -1;
      selectedMedia = -1;
      selectedTileIndex = -1;
      selectedTilePattern = [];
      tilemapEraserEnabled = false;
      tilesetSelectionColStart = -1;
      tilesetSelectionRowStart = -1;
      tilesetSelectionColEnd = -1;
      tilesetSelectionRowEnd = -1;
      _undoStack.clear();
      _redoStack.clear();
      imagesCache.clear();
      if (gameData.name.trim().isNotEmpty) {
        project.name = gameData.name.trim();
      }
      project.updatedAt = DateTime.now().toUtc().toIso8601String();
      await _saveProjectsIndex();

      if (notify) {
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error opening project: $e");
      }
      projectStatusMessage = "Open failed: $e";
      if (notify) {
        notifyListeners();
      }
    }
  }

  Future<void> reloadWorkingProject() async {
    if (selectedProjectId == "") {
      return;
    }
    await openProject(selectedProjectId);
  }

  Future<String?> importProject() async {
    try {
      if (projectsPath == "") {
        await initializeStorage();
      }

      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        allowMultiple: false,
        initialDirectory: projectsPath,
      );
      if (result == null || result.files.single.path == null) {
        return null;
      }

      final String zipPath = result.files.single.path!;
      final String zipFileName = _lastPathSegment(zipPath);
      final String baseName = zipFileName.toLowerCase().endsWith('.zip')
          ? zipFileName.substring(0, zipFileName.length - 4)
          : zipFileName;
      final List<int> zipBytes = await File(zipPath).readAsBytes();
      final Archive archive = ZipDecoder().decodeBytes(zipBytes, verify: true);
      final String archiveRootPrefix = _archiveRootPrefixFromGameData(archive);

      final String destinationFolderName = await _buildUniqueProjectFolderName(
        _sanitizeFolderName(baseName),
      );
      final Directory destinationDirectory = Directory(
        "$projectsPath${Platform.pathSeparator}$destinationFolderName",
      );
      await destinationDirectory.create(recursive: true);

      bool wroteAnyFile = false;
      for (final archiveFile in archive.files) {
        if (!archiveFile.isFile) {
          continue;
        }

        String entryPath = _normalizeArchivePath(archiveFile.name);
        if (archiveRootPrefix != "") {
          if (!entryPath.startsWith(archiveRootPrefix)) {
            continue;
          }
          entryPath = entryPath.substring(archiveRootPrefix.length);
        }
        if (entryPath.startsWith('/')) {
          entryPath = entryPath.substring(1);
        }
        if (entryPath.isEmpty) {
          continue;
        }

        final String outputPath =
            "${destinationDirectory.path}${Platform.pathSeparator}${entryPath.replaceAll('/', Platform.pathSeparator)}";
        final File outputFile = File(outputPath);
        await outputFile.parent.create(recursive: true);

        final dynamic content = archiveFile.content;
        if (content is! List<int>) {
          throw Exception("Invalid ZIP content for entry: $entryPath");
        }
        await outputFile.writeAsBytes(content);
        wroteAnyFile = true;
      }

      if (!wroteAnyFile) {
        throw Exception("ZIP archive is empty");
      }

      final File importedGameFile = File(
        "${destinationDirectory.path}${Platform.pathSeparator}$gameFileName",
      );
      if (!await importedGameFile.exists()) {
        throw Exception("ZIP does not include $gameFileName at project root");
      }

      final String inferredName = await _readProjectNameFromDisk(
            File(
              "${destinationDirectory.path}${Platform.pathSeparator}$gameFileName",
            ),
          ) ??
          baseName;

      final String now = DateTime.now().toUtc().toIso8601String();
      final StoredProject importedProject = StoredProject(
        id: _newProjectId(),
        name: inferredName,
        folderName: destinationFolderName,
        createdAt: now,
        updatedAt: now,
      );
      projects.add(importedProject);
      selectedProjectId = importedProject.id;
      await _saveProjectsIndex();
      await openProject(importedProject.id, notify: false);
      projectStatusMessage = "Imported ZIP \"$zipFileName\"";
      notifyListeners();
      return importedProject.id;
    } catch (e) {
      if (kDebugMode) {
        print("Error importing project: $e");
      }
      projectStatusMessage = "Import failed: $e";
      notifyListeners();
      return null;
    }
  }

  Future<bool> exportSelectedProject() async {
    try {
      final StoredProject? project = selectedProject;
      if (project == null) {
        return false;
      }

      String? destinationZipPath = await FilePicker.platform.saveFile(
        dialogTitle: "Export Project as ZIP",
        fileName: "${project.folderName}.zip",
        initialDirectory: projectsPath,
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (destinationZipPath == null) {
        return false;
      }
      if (!destinationZipPath.toLowerCase().endsWith('.zip')) {
        destinationZipPath = "$destinationZipPath.zip";
      }

      final Directory sourceDirectory = Directory(
        "$projectsPath${Platform.pathSeparator}${project.folderName}",
      );
      final Archive archive = Archive();
      await for (final entity
          in sourceDirectory.list(recursive: true, followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        final String relativePath = entity.path
            .substring(sourceDirectory.path.length + 1)
            .replaceAll(Platform.pathSeparator, '/');
        final List<int> bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
      }

      final List<int> zipBytes = ZipEncoder().encode(archive);
      await File(destinationZipPath).writeAsBytes(zipBytes);
      projectStatusMessage = "Exported ZIP to $destinationZipPath";
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print("Error exporting project: $e");
      }
      projectStatusMessage = "Export failed: $e";
      notifyListeners();
      return false;
    }
  }

  Future<void> saveGame() async {
    try {
      final StoredProject? project = selectedProject;
      if (project == null) {
        throw Exception("No selected project");
      }

      if (filePath == "") {
        filePath =
            "$projectsPath${Platform.pathSeparator}${project.folderName}";
      }
      fileName = gameFileName;

      final Directory projectDirectory = Directory(filePath);
      if (!await projectDirectory.exists()) {
        await projectDirectory.create(recursive: true);
      }

      final file = File("$filePath${Platform.pathSeparator}$fileName");
      final output = await _formatMapAsGameJson(gameData.toJson());
      await file.writeAsString(output);

      if (gameData.name.trim().isNotEmpty) {
        project.name = gameData.name.trim();
      }
      project.updatedAt = DateTime.now().toUtc().toIso8601String();
      await _saveProjectsIndex();

      if (kDebugMode) {
        print("Game saved successfully to \"$filePath/$fileName\"");
      }

      projectStatusMessage = "Saved project \"${project.name}\"";
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print("Error saving game file: $e");
      }
    }
  }

  GameMediaAsset? mediaAssetByFileName(String fileName) {
    for (final asset in gameData.mediaAssets) {
      if (asset.fileName == fileName) {
        return asset;
      }
    }
    return null;
  }

  Color tilesetSelectionColorForFile(String fileName) {
    final asset = mediaAssetByFileName(fileName);
    if (asset == null) {
      return defaultTilesetSelectionColor;
    }
    return _parseHexColor(
        asset.selectionColorHex, defaultTilesetSelectionColor);
  }

  bool setTilesetSelectionColorForFile(String fileName, Color color) {
    final asset = mediaAssetByFileName(fileName);
    if (asset == null) {
      return false;
    }
    final String nextHex = _toHexColor(color);
    if (asset.selectionColorHex == nextHex) {
      return false;
    }
    asset.selectionColorHex = nextHex;
    return true;
  }

  Color _parseHexColor(String hex, Color fallback) {
    final String cleaned = hex.trim().replaceFirst('#', '').toUpperCase();
    final RegExp sixHex = RegExp(r'^[0-9A-F]{6}$');
    if (!sixHex.hasMatch(cleaned)) {
      return fallback;
    }
    final int? rgb = int.tryParse(cleaned, radix: 16);
    if (rgb == null) {
      return fallback;
    }
    return Color(0xFF000000 | rgb);
  }

  String _toHexColor(Color color) {
    final int rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Future<String> pickImageFile() async {
    if (selectedProject == null) {
      return "";
    }

    final String initialDirectory = filePath != ""
        ? filePath
        : "$projectsPath${Platform.pathSeparator}${selectedProject!.folderName}";

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      initialDirectory: initialDirectory,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );

    if (result == null || result.files.single.path == null) {
      return "";
    }

    String selectedPath = result.files.single.path!;
    String selectedFileName = selectedPath.split(Platform.pathSeparator).last;
    if (filePath == "") {
      filePath =
          "$projectsPath${Platform.pathSeparator}${selectedProject!.folderName}";
      fileName = gameFileName;
    }
    selectedFileName =
        await _buildUniqueFileNameInDirectory(filePath, selectedFileName);
    String destinationPath =
        "$filePath${Platform.pathSeparator}$selectedFileName";

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
      final File file =
          File("$filePath${Platform.pathSeparator}$imageFileName");
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
