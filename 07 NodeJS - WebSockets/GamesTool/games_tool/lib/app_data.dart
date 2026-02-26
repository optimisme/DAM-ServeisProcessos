import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'game_animation.dart';
import 'game_data.dart';
import 'game_layer.dart';
import 'game_media_asset.dart';

typedef ProjectMutation = void Function();
typedef ProjectMutationValidator = String? Function();

class StoredProject {
  final String id;
  final String folderName;
  final String createdAt;
  String name;
  String comments;
  String updatedAt;

  StoredProject({
    required this.id,
    required this.name,
    required this.folderName,
    required this.createdAt,
    required this.updatedAt,
    this.comments = "",
  });

  factory StoredProject.fromJson(Map<String, dynamic> json) {
    final dynamic rawComments = json['comments'];
    return StoredProject(
      id: json['id'] as String,
      name: json['name'] as String,
      folderName: json['folderName'] as String,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      comments: rawComments is String ? rawComments : "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'folderName': folderName,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'comments': comments,
    };
  }
}

class AppData extends ChangeNotifier {
  static const String appFolderName = "GamesTool";
  static const String projectsFolderName = "projects";
  static const String projectsIndexFileName = "projects_index.json";
  static const String mediaFolderName = "media";
  static const String tilemapsFolderName = "tilemaps";
  static const String zonesFolderName = "zones";
  static const String tileMapFileFieldName = "tileMapFile";
  static const String zonesFileFieldName = "zonesFile";
  static const String projectCommentsFieldName = "projectComments";
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
  String autosaveInlineMessage = "";
  bool autosaveHasError = false;
  List<StoredProject> projects = [];

  Map<String, ui.Image> imagesCache = {};

  String selectedSection = "projects";
  int selectedLevel = -1;
  int selectedLayer = -1;
  int selectedZone = -1;
  int selectedSprite = -1;
  int selectedAnimation = -1;
  int selectedMedia = -1;
  int animationSelectionStartFrame = -1;
  int animationSelectionEndFrame = -1;

  static const Duration _autosaveDebounceDelay = Duration(milliseconds: 320);
  static const Duration _autosaveFollowupDelay = Duration(milliseconds: 80);
  static const Duration _autosaveRetryMinDelay = Duration(seconds: 1);
  static const Duration _autosaveRetryMaxDelay = Duration(seconds: 8);
  Timer? _autosaveDebounceTimer;
  Timer? _autosaveRetryTimer;
  bool _autosaveQueued = false;
  bool _autosaveRunning = false;
  int _autosaveRetryAttempt = 0;
  Completer<void>? _autosaveDrainCompleter;

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

  // Viewport drag state
  Offset viewportDragOffset = Offset.zero;
  Offset viewportResizeOffset = Offset.zero;
  bool viewportIsDragging = false;
  bool viewportIsResizing = false;
  int viewportPreviewX = 0;
  int viewportPreviewY = 0;
  int viewportPreviewWidth = 320;
  int viewportPreviewHeight = 180;
  int viewportPreviewLevel = -1;

  // Layers canvas viewport (zoom + pan)
  double layersViewScale = 1.0;
  Offset layersViewOffset = Offset.zero;
  Offset layerDragOffset = Offset.zero;

  // Undo / redo stacks (JSON snapshots of gameData)
  final List<Map<String, dynamic>> _undoStack = [];
  final List<Map<String, dynamic>> _redoStack = [];
  static const int _maxUndoSteps = 50;
  static const Duration _defaultUndoGroupWindow = Duration(seconds: 2);
  final Map<String, DateTime> _undoGroupCheckpointAt = {};

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

  void _clearUndoGroupingState() {
    _undoGroupCheckpointAt.clear();
  }

  bool _shouldPushUndoCheckpoint({
    required String? undoGroupKey,
    required Duration undoGroupWindow,
  }) {
    final String key = undoGroupKey?.trim() ?? '';
    if (key.isEmpty) {
      // Ungrouped mutations are "major" by default and must start a fresh
      // checkpoint sequence.
      _clearUndoGroupingState();
      return true;
    }

    final DateTime now = DateTime.now();
    final DateTime? lastCheckpointAt = _undoGroupCheckpointAt[key];
    if (lastCheckpointAt == null ||
        now.difference(lastCheckpointAt) > undoGroupWindow) {
      _undoGroupCheckpointAt[key] = now;
      return true;
    }
    return false;
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(gameData.toJson());
    gameData = GameData.fromJson(_undoStack.removeLast());
    _clearUndoGroupingState();
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(gameData.toJson());
    gameData = GameData.fromJson(_redoStack.removeLast());
    _clearUndoGroupingState();
    notifyListeners();
  }

  void update() {
    notifyListeners();
  }

  Duration _autosaveRetryDelay(int attempt) {
    final int cappedAttempt = attempt < 1 ? 1 : (attempt > 6 ? 6 : attempt);
    final int factor = 1 << (cappedAttempt - 1);
    final int nextMs = _autosaveRetryMinDelay.inMilliseconds * factor;
    final int clampedMs = nextMs < _autosaveRetryMinDelay.inMilliseconds
        ? _autosaveRetryMinDelay.inMilliseconds
        : (nextMs > _autosaveRetryMaxDelay.inMilliseconds
            ? _autosaveRetryMaxDelay.inMilliseconds
            : nextMs);
    return Duration(
      milliseconds: clampedMs,
    );
  }

  void queueAutosave({Duration debounce = _autosaveDebounceDelay}) {
    if (selectedProject == null) {
      return;
    }
    _autosaveQueued = true;
    _autosaveDebounceTimer?.cancel();
    _autosaveDebounceTimer = Timer(debounce, () {
      unawaited(_drainAutosaveQueue());
    });
  }

  Future<void> flushPendingAutosave() async {
    _autosaveDebounceTimer?.cancel();
    _autosaveDebounceTimer = null;
    _autosaveRetryTimer?.cancel();
    _autosaveRetryTimer = null;

    if (!_autosaveQueued && !_autosaveRunning) {
      return;
    }

    _autosaveQueued = true;
    await _drainAutosaveQueue(force: true);
  }

  Future<void> _drainAutosaveQueue({bool force = false}) async {
    if (selectedProject == null) {
      _autosaveQueued = false;
      return;
    }

    if (_autosaveRunning) {
      if (force) {
        await _autosaveDrainCompleter?.future;
        if (_autosaveQueued) {
          await _drainAutosaveQueue(force: true);
        }
      }
      return;
    }

    if (!_autosaveQueued && !force) {
      return;
    }

    _autosaveRunning = true;
    final Completer<void> drainCompleter = Completer<void>();
    _autosaveDrainCompleter = drainCompleter;
    _autosaveQueued = false;

    try {
      await _saveGameInternal(
        notifyOnSuccess: false,
      );

      if (autosaveInlineMessage.isNotEmpty || autosaveHasError) {
        autosaveInlineMessage = '';
        autosaveHasError = false;
        notifyListeners();
      }
      _autosaveRetryAttempt = 0;
    } catch (e) {
      _autosaveQueued = true;
      _autosaveRetryAttempt += 1;
      final Duration delay = _autosaveRetryDelay(_autosaveRetryAttempt);
      autosaveInlineMessage =
          'Autosave failed. Retrying in ${delay.inSeconds}s.';
      autosaveHasError = true;
      notifyListeners();

      _autosaveRetryTimer?.cancel();
      _autosaveRetryTimer = Timer(delay, () {
        _autosaveRetryTimer = null;
        _autosaveDebounceTimer?.cancel();
        _autosaveDebounceTimer = Timer(_autosaveFollowupDelay, () {
          unawaited(_drainAutosaveQueue());
        });
      });
    } finally {
      _autosaveRunning = false;
      if (!drainCompleter.isCompleted) {
        drainCompleter.complete();
      }
    }

    if (_autosaveQueued && _autosaveRetryTimer == null) {
      _autosaveDebounceTimer?.cancel();
      _autosaveDebounceTimer = Timer(_autosaveFollowupDelay, () {
        unawaited(_drainAutosaveQueue());
      });
    }
  }

  void _clearAutosaveState() {
    _autosaveDebounceTimer?.cancel();
    _autosaveDebounceTimer = null;
    _autosaveRetryTimer?.cancel();
    _autosaveRetryTimer = null;
    _autosaveQueued = false;
    _autosaveRunning = false;
    _autosaveRetryAttempt = 0;
    _autosaveDrainCompleter = null;
    autosaveInlineMessage = '';
    autosaveHasError = false;
  }

  Future<void> setSelectedSection(String value) async {
    if (selectedSection == value) {
      return;
    }
    await flushPendingAutosave();
    selectedSection = value;
    notifyListeners();
  }

  /// Canonical pathway for persisted editor mutations.
  ///
  /// Contract:
  /// - Optional validation gate before applying.
  /// - Optional undo checkpoint before data mutation.
  /// - UI refresh after mutation.
  /// - Optional autosave of project data.
  Future<bool> runProjectMutation({
    required ProjectMutation mutate,
    ProjectMutationValidator? validate,
    bool requireSelectedProject = true,
    bool pushUndoCheckpoint = true,
    String? undoGroupKey,
    Duration undoGroupWindow = _defaultUndoGroupWindow,
    bool refreshUi = true,
    bool autosave = true,
    bool notifyOnValidationFailure = true,
    String? debugLabel,
  }) async {
    if (requireSelectedProject && selectedProject == null) {
      return false;
    }

    final String? validationError = validate?.call();
    if (validationError != null) {
      projectStatusMessage = validationError;
      if (notifyOnValidationFailure) {
        notifyListeners();
      }
      return false;
    }

    try {
      if (pushUndoCheckpoint &&
          _shouldPushUndoCheckpoint(
            undoGroupKey: undoGroupKey,
            undoGroupWindow: undoGroupWindow,
          )) {
        pushUndo();
      }
      mutate();
      if (refreshUi) {
        update();
      }
      if (autosave && selectedProject != null) {
        queueAutosave();
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print("Error in runProjectMutation(${debugLabel ?? 'unnamed'}): $e");
      }
      projectStatusMessage = "Update failed: $e";
      notifyListeners();
      return false;
    }
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
        final String inferredComments =
            await _readProjectCommentsFromDisk(gameFile) ?? "";
        discoveredProjects.add(
          StoredProject(
            id: _newProjectId(),
            name: inferredName,
            folderName: folderName,
            createdAt: DateTime.now().toUtc().toIso8601String(),
            updatedAt: DateTime.now().toUtc().toIso8601String(),
            comments: inferredComments,
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

  Future<String?> _readProjectCommentsFromDisk(File gameFile) async {
    try {
      final dynamic decoded = jsonDecode(await gameFile.readAsString());
      if (decoded is! Map) {
        return null;
      }
      if (!decoded.containsKey(projectCommentsFieldName)) {
        return null;
      }
      final dynamic comments = decoded[projectCommentsFieldName];
      return comments is String ? _sanitizeProjectComments(comments) : "";
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

  String _sanitizeProjectComments(String? value) {
    if (value == null) {
      return "";
    }
    return value.replaceAll('\r\n', '\n').trim();
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

  Future<String> _buildUniqueDirectoryNameInDirectory(
    String parentDirectoryPath,
    String baseDirectoryName,
  ) async {
    String candidate = baseDirectoryName;
    int cnt = 2;
    while (await Directory(
      "$parentDirectoryPath${Platform.pathSeparator}$candidate",
    ).exists()) {
      candidate = "${baseDirectoryName}_$cnt";
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

  String _normalizeProjectRelativePath(String value) {
    String normalized = value.trim().replaceAll('\\', '/');
    while (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    if (normalized.isEmpty) {
      return '';
    }
    final List<String> segments = normalized.split('/');
    for (final segment in segments) {
      if (segment.isEmpty || segment == '.' || segment == '..') {
        return '';
      }
    }
    return segments.join('/');
  }

  String _defaultTileMapRelativePath(int levelIndex, int layerIndex) {
    final String level = (levelIndex + 1).toString().padLeft(3, '0');
    final String layer = (layerIndex + 1).toString().padLeft(3, '0');
    return '$tilemapsFolderName/level_${level}_layer_$layer.json';
  }

  String _defaultZonesRelativePath(int levelIndex) {
    final String level = (levelIndex + 1).toString().padLeft(3, '0');
    return '$zonesFolderName/level_${level}_zones.json';
  }

  bool _isMediaRelativePath(String value) {
    final String normalized = _normalizeProjectRelativePath(value);
    if (normalized.isEmpty) {
      return false;
    }
    return normalized == mediaFolderName ||
        normalized.startsWith('$mediaFolderName/');
  }

  String _mediaRelativePathForBaseName(String baseName) {
    return '$mediaFolderName/$baseName';
  }

  Future<void> _moveFileWithinProject({
    required String sourceAbsolutePath,
    required String destinationAbsolutePath,
  }) async {
    if (sourceAbsolutePath == destinationAbsolutePath) {
      return;
    }
    final File sourceFile = File(sourceAbsolutePath);
    if (!await sourceFile.exists()) {
      return;
    }
    final File destinationFile = File(destinationAbsolutePath);
    await destinationFile.parent.create(recursive: true);
    try {
      await sourceFile.rename(destinationAbsolutePath);
    } catch (_) {
      await sourceFile.copy(destinationAbsolutePath);
      try {
        await sourceFile.delete();
      } catch (_) {}
    }
  }

  String _normalizedTileMapRelativePath(
    dynamic rawValue, {
    required int levelIndex,
    required int layerIndex,
  }) {
    final String candidate = rawValue is String ? rawValue : '';
    final String normalized = _normalizeProjectRelativePath(candidate);
    if (normalized.isNotEmpty && normalized.toLowerCase().endsWith('.json')) {
      return normalized;
    }
    return _defaultTileMapRelativePath(levelIndex, layerIndex);
  }

  String _normalizedZonesRelativePath(
    dynamic rawValue, {
    required int levelIndex,
  }) {
    final String candidate = rawValue is String ? rawValue : '';
    final String normalized = _normalizeProjectRelativePath(candidate);
    if (normalized.isNotEmpty && normalized.toLowerCase().endsWith('.json')) {
      return normalized;
    }
    return _defaultZonesRelativePath(levelIndex);
  }

  String _relativePathFromProjectAbsolutePath(
    String projectDirectoryPath,
    String absolutePath,
  ) {
    final String projectPrefix =
        '$projectDirectoryPath${Platform.pathSeparator}';
    if (!absolutePath.startsWith(projectPrefix)) {
      return '';
    }
    return _normalizeProjectRelativePath(
      absolutePath.substring(projectPrefix.length),
    );
  }

  List<List<int>> _parseTileMapRows(dynamic value) {
    if (value is! List) {
      return <List<int>>[];
    }
    final List<List<int>> rows = <List<int>>[];
    for (final dynamic row in value) {
      if (row is! List) {
        continue;
      }
      rows.add(
        row
            .map<int>(
              (dynamic cell) => cell is num ? cell.toInt() : -1,
            )
            .toList(growable: false),
      );
    }
    return rows;
  }

  List<Map<String, dynamic>> _parseObjectList(dynamic value) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }
    final List<Map<String, dynamic>> entries = <Map<String, dynamic>>[];
    for (final dynamic item in value) {
      if (item is Map<String, dynamic>) {
        entries.add(item);
      } else if (item is Map) {
        entries.add(Map<String, dynamic>.from(item));
      }
    }
    return entries;
  }

  Future<List<List<int>>> _readExternalTileMapRows(String absolutePath) async {
    final File file = File(absolutePath);
    if (!await file.exists()) {
      throw Exception("Missing tilemap file: ${file.path}");
    }
    final dynamic decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, dynamic>) {
      return _parseTileMapRows(decoded['tileMap']);
    }
    return _parseTileMapRows(decoded);
  }

  Future<Map<String, dynamic>> _readExternalZonesData(
      String absolutePath) async {
    final File file = File(absolutePath);
    if (!await file.exists()) {
      throw Exception("Missing zones file: ${file.path}");
    }
    final dynamic decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, dynamic>) {
      return <String, dynamic>{
        'zones': _parseObjectList(decoded['zones']),
        'zoneGroups': _parseObjectList(decoded['zoneGroups']),
      };
    }
    if (decoded is Map) {
      final Map<String, dynamic> asMap = Map<String, dynamic>.from(decoded);
      return <String, dynamic>{
        'zones': _parseObjectList(asMap['zones']),
        'zoneGroups': _parseObjectList(asMap['zoneGroups']),
      };
    }
    if (decoded is List) {
      return <String, dynamic>{
        'zones': _parseObjectList(decoded),
        'zoneGroups': <Map<String, dynamic>>[],
      };
    }
    return <String, dynamic>{
      'zones': <Map<String, dynamic>>[],
      'zoneGroups': <Map<String, dynamic>>[],
    };
  }

  Future<bool> _migrateProjectMediaToMediaFolder({
    required String projectDirectoryPath,
  }) async {
    final Set<String> references = <String>{};
    void addReference(String value) {
      final String normalized = _normalizeProjectRelativePath(value);
      if (normalized.isNotEmpty && _hasSupportedImageExtension(normalized)) {
        references.add(normalized);
      }
    }

    for (final asset in gameData.mediaAssets) {
      addReference(asset.fileName);
    }
    for (final animation in gameData.animations) {
      addReference(animation.mediaFile);
    }
    for (final level in gameData.levels) {
      for (final layer in level.layers) {
        addReference(layer.tilesSheetFile);
      }
      for (final sprite in level.sprites) {
        addReference(sprite.imageFile);
      }
    }

    if (references.isEmpty) {
      return false;
    }

    final Directory mediaDirectory = Directory(
      '$projectDirectoryPath${Platform.pathSeparator}$mediaFolderName',
    );
    await mediaDirectory.create(recursive: true);

    final Map<String, String> migratedByOriginal = <String, String>{};
    bool changed = false;

    for (final String original in references) {
      String migrated = original;
      if (!_isMediaRelativePath(original)) {
        final String baseName = _lastPathSegment(original);
        final String sourceAbsolutePath =
            _projectAbsolutePathForRelativePath(projectDirectoryPath, original);
        final File sourceFile = File(sourceAbsolutePath);
        final bool sourceExists = await sourceFile.exists();
        if (baseName.isNotEmpty) {
          String destinationRelativePath =
              _mediaRelativePathForBaseName(baseName);
          String destinationAbsolutePath = _projectAbsolutePathForRelativePath(
            projectDirectoryPath,
            destinationRelativePath,
          );
          final File destinationFile = File(destinationAbsolutePath);
          if (sourceExists) {
            bool shouldMoveSource = true;
            if (await destinationFile.exists()) {
              final bool sameContent = await _filesHaveSameContent(
                sourceAbsolutePath,
                destinationAbsolutePath,
              );
              if (sameContent) {
                shouldMoveSource = false;
                if (sourceAbsolutePath != destinationAbsolutePath) {
                  try {
                    await sourceFile.delete();
                  } catch (_) {}
                }
              } else {
                final String uniqueBaseName =
                    await _buildUniqueFileNameInDirectory(
                  mediaDirectory.path,
                  baseName,
                );
                destinationRelativePath =
                    _mediaRelativePathForBaseName(uniqueBaseName);
                destinationAbsolutePath = _projectAbsolutePathForRelativePath(
                  projectDirectoryPath,
                  destinationRelativePath,
                );
              }
            }
            if (shouldMoveSource) {
              await _moveFileWithinProject(
                sourceAbsolutePath: sourceAbsolutePath,
                destinationAbsolutePath: destinationAbsolutePath,
              );
            }
            migrated = destinationRelativePath;
          } else if (await destinationFile.exists()) {
            migrated = destinationRelativePath;
          }
        }
      }
      migratedByOriginal[original] = migrated;
      if (migrated != original) {
        changed = true;
      }
    }

    String migratedValue(String value) {
      final String normalized = _normalizeProjectRelativePath(value);
      if (normalized.isEmpty) {
        return value;
      }
      return migratedByOriginal[normalized] ?? normalized;
    }

    for (final asset in gameData.mediaAssets) {
      final String next = migratedValue(asset.fileName);
      if (next != asset.fileName) {
        asset.fileName = next;
        changed = true;
      }
    }
    for (final animation in gameData.animations) {
      final String next = migratedValue(animation.mediaFile);
      if (next != animation.mediaFile) {
        animation.mediaFile = next;
        changed = true;
      }
    }
    for (final level in gameData.levels) {
      for (int layerIndex = 0; layerIndex < level.layers.length; layerIndex++) {
        final GameLayer layer = level.layers[layerIndex];
        final String next = migratedValue(layer.tilesSheetFile);
        if (next != layer.tilesSheetFile) {
          level.layers[layerIndex] = GameLayer(
            name: layer.name,
            x: layer.x,
            y: layer.y,
            depth: layer.depth,
            tilesSheetFile: next,
            tilesWidth: layer.tilesWidth,
            tilesHeight: layer.tilesHeight,
            tileMap: layer.tileMap,
            visible: layer.visible,
            groupId: layer.groupId,
          );
          changed = true;
        }
      }
      for (final sprite in level.sprites) {
        final String next = migratedValue(sprite.imageFile);
        if (next != sprite.imageFile) {
          sprite.imageFile = next;
          changed = true;
        }
      }
    }

    if (changed) {
      imagesCache.clear();
    }
    return changed;
  }

  String _canonicalJsonValue(dynamic value) {
    if (value is Map) {
      final List<String> keys = value.keys.map((k) => k.toString()).toList()
        ..sort();
      final List<String> parts = <String>[];
      for (final key in keys) {
        parts.add('${jsonEncode(key)}:${_canonicalJsonValue(value[key])}');
      }
      return '{${parts.join(',')}}';
    }
    if (value is List) {
      return '[${value.map(_canonicalJsonValue).join(',')}]';
    }
    return jsonEncode(value);
  }

  bool _projectNeedsStructureMigration({
    required Map<String, dynamic> decoded,
  }) {
    final Map<String, dynamic> normalized = gameData.toJson();
    return _canonicalJsonValue(decoded) != _canonicalJsonValue(normalized);
  }

  Future<void> _hydrateExternalTileMapsIntoDecodedGameData({
    required Map<String, dynamic> decoded,
    required String projectDirectoryPath,
  }) async {
    final dynamic rawLevels = decoded['levels'];
    if (rawLevels is! List) {
      return;
    }
    for (int levelIndex = 0; levelIndex < rawLevels.length; levelIndex++) {
      final dynamic rawLevel = rawLevels[levelIndex];
      if (rawLevel is! Map<String, dynamic>) {
        continue;
      }
      final dynamic rawLayers = rawLevel['layers'];
      if (rawLayers is! List) {
        continue;
      }
      for (int layerIndex = 0; layerIndex < rawLayers.length; layerIndex++) {
        final dynamic rawLayer = rawLayers[layerIndex];
        if (rawLayer is! Map<String, dynamic>) {
          continue;
        }
        final dynamic rawReference = rawLayer[tileMapFileFieldName];
        if (rawReference is! String) {
          throw Exception(
            'Unsupported project format: layer tilemaps must use "$tileMapFileFieldName".',
          );
        }
        final String relativePath = _normalizeProjectRelativePath(rawReference);
        if (relativePath.isEmpty ||
            !relativePath.toLowerCase().endsWith('.json')) {
          throw Exception(
            'Invalid "$tileMapFileFieldName" value for level ${levelIndex + 1}, layer ${layerIndex + 1}.',
          );
        }
        final List<List<int>> tileMapRows = await _readExternalTileMapRows(
          _projectAbsolutePathForRelativePath(
            projectDirectoryPath,
            relativePath,
          ),
        );
        rawLayer[tileMapFileFieldName] = relativePath;
        rawLayer['tileMap'] = tileMapRows;
      }
    }
  }

  Future<void> _hydrateExternalZonesIntoDecodedGameData({
    required Map<String, dynamic> decoded,
    required String projectDirectoryPath,
  }) async {
    final dynamic rawLevels = decoded['levels'];
    if (rawLevels is! List) {
      return;
    }

    for (int levelIndex = 0; levelIndex < rawLevels.length; levelIndex++) {
      final dynamic rawLevel = rawLevels[levelIndex];
      if (rawLevel is! Map<String, dynamic>) {
        continue;
      }

      final dynamic rawReference = rawLevel[zonesFileFieldName];
      if (rawReference is! String) {
        throw Exception(
          'Unsupported project format: level zones must use "$zonesFileFieldName".',
        );
      }
      final String relativePath = _normalizeProjectRelativePath(rawReference);
      if (relativePath.isEmpty ||
          !relativePath.toLowerCase().endsWith('.json')) {
        throw Exception(
          'Invalid "$zonesFileFieldName" value for level ${levelIndex + 1}.',
        );
      }

      final Map<String, dynamic> zonesData = await _readExternalZonesData(
        _projectAbsolutePathForRelativePath(
          projectDirectoryPath,
          relativePath,
        ),
      );
      rawLevel[zonesFileFieldName] = relativePath;
      rawLevel['zones'] = zonesData['zones'];
      rawLevel['zoneGroups'] = zonesData['zoneGroups'];
    }
  }

  Future<Set<String>> _writeExternalTileMapsAndStripInlineFromGameData({
    required Map<String, dynamic> encoded,
    required String projectDirectoryPath,
  }) async {
    final Set<String> writtenRelativePaths = <String>{};
    final dynamic rawLevels = encoded['levels'];
    if (rawLevels is! List) {
      return writtenRelativePaths;
    }
    for (int levelIndex = 0; levelIndex < rawLevels.length; levelIndex++) {
      final dynamic rawLevel = rawLevels[levelIndex];
      if (rawLevel is! Map<String, dynamic>) {
        continue;
      }
      final dynamic rawLayers = rawLevel['layers'];
      if (rawLayers is! List) {
        continue;
      }
      for (int layerIndex = 0; layerIndex < rawLayers.length; layerIndex++) {
        final dynamic rawLayer = rawLayers[layerIndex];
        if (rawLayer is! Map<String, dynamic>) {
          continue;
        }
        final List<List<int>> tileMapRows =
            _parseTileMapRows(rawLayer['tileMap']);
        final String relativePath = _normalizedTileMapRelativePath(
          rawLayer[tileMapFileFieldName],
          levelIndex: levelIndex,
          layerIndex: layerIndex,
        );
        final String absolutePath = _projectAbsolutePathForRelativePath(
          projectDirectoryPath,
          relativePath,
        );
        final File tileMapFile = File(absolutePath);
        await tileMapFile.parent.create(recursive: true);
        final String tileMapOutput = await _formatMapAsGameJson(
          <String, dynamic>{'tileMap': tileMapRows},
        );
        await tileMapFile.writeAsString(tileMapOutput);
        writtenRelativePaths.add(relativePath);
        rawLayer[tileMapFileFieldName] = relativePath;
        rawLayer.remove('tileMap');
      }
    }
    return writtenRelativePaths;
  }

  Future<Set<String>> _writeExternalZonesAndStripInlineFromGameData({
    required Map<String, dynamic> encoded,
    required String projectDirectoryPath,
  }) async {
    final Set<String> writtenRelativePaths = <String>{};
    final dynamic rawLevels = encoded['levels'];
    if (rawLevels is! List) {
      return writtenRelativePaths;
    }

    for (int levelIndex = 0; levelIndex < rawLevels.length; levelIndex++) {
      final dynamic rawLevel = rawLevels[levelIndex];
      if (rawLevel is! Map<String, dynamic>) {
        continue;
      }

      final List<Map<String, dynamic>> zones =
          _parseObjectList(rawLevel['zones']);
      final List<Map<String, dynamic>> zoneGroups =
          _parseObjectList(rawLevel['zoneGroups']);
      final String relativePath = _normalizedZonesRelativePath(
        rawLevel[zonesFileFieldName],
        levelIndex: levelIndex,
      );
      final String absolutePath = _projectAbsolutePathForRelativePath(
        projectDirectoryPath,
        relativePath,
      );
      final File zonesFile = File(absolutePath);
      await zonesFile.parent.create(recursive: true);
      final String zonesOutput = await _formatMapAsGameJson(
        <String, dynamic>{
          'zoneGroups': zoneGroups,
          'zones': zones,
        },
      );
      await zonesFile.writeAsString(zonesOutput);
      writtenRelativePaths.add(relativePath);
      rawLevel[zonesFileFieldName] = relativePath;
      rawLevel.remove('zones');
      rawLevel.remove('zoneGroups');
    }

    return writtenRelativePaths;
  }

  Future<void> _cleanupStaleExternalTileMapFiles({
    required String projectDirectoryPath,
    required Set<String> keepRelativePaths,
  }) async {
    final Directory tileMapsDirectory = Directory(
      '$projectDirectoryPath${Platform.pathSeparator}$tilemapsFolderName',
    );
    if (!await tileMapsDirectory.exists()) {
      return;
    }
    await for (final FileSystemEntity entity
        in tileMapsDirectory.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      if (!entity.path.toLowerCase().endsWith('.json')) {
        continue;
      }
      final String relativePath = _relativePathFromProjectAbsolutePath(
        projectDirectoryPath,
        entity.path,
      );
      if (relativePath.isEmpty || keepRelativePaths.contains(relativePath)) {
        continue;
      }
      try {
        await entity.delete();
      } catch (_) {}
    }
  }

  Future<void> _cleanupStaleExternalZoneFiles({
    required String projectDirectoryPath,
    required Set<String> keepRelativePaths,
  }) async {
    final Directory zonesDirectory = Directory(
      '$projectDirectoryPath${Platform.pathSeparator}$zonesFolderName',
    );
    if (!await zonesDirectory.exists()) {
      return;
    }
    await for (final FileSystemEntity entity
        in zonesDirectory.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      if (!entity.path.toLowerCase().endsWith('.json')) {
        continue;
      }
      final String relativePath = _relativePathFromProjectAbsolutePath(
        projectDirectoryPath,
        entity.path,
      );
      if (relativePath.isEmpty || keepRelativePaths.contains(relativePath)) {
        continue;
      }
      try {
        await entity.delete();
      } catch (_) {}
    }
  }

  Set<String> _collectExternalTileMapPathsFromDecodedGameData(
      dynamic decodedGameData) {
    final Set<String> paths = <String>{};
    if (decodedGameData is! Map<String, dynamic>) {
      return paths;
    }
    final dynamic rawLevels = decodedGameData['levels'];
    if (rawLevels is! List) {
      return paths;
    }
    for (int levelIndex = 0; levelIndex < rawLevels.length; levelIndex++) {
      final dynamic rawLevel = rawLevels[levelIndex];
      if (rawLevel is! Map<String, dynamic>) {
        continue;
      }
      final dynamic rawLayers = rawLevel['layers'];
      if (rawLayers is! List) {
        continue;
      }
      for (int layerIndex = 0; layerIndex < rawLayers.length; layerIndex++) {
        final dynamic rawLayer = rawLayers[layerIndex];
        if (rawLayer is! Map<String, dynamic>) {
          continue;
        }
        final dynamic rawReference = rawLayer[tileMapFileFieldName];
        if (rawReference is! String) {
          continue;
        }
        final String relativePath = _normalizeProjectRelativePath(rawReference);
        if (relativePath.isNotEmpty) {
          paths.add(relativePath);
        }
      }
    }
    return paths;
  }

  Set<String> _collectExternalZonePathsFromDecodedGameData(
      dynamic decodedGameData) {
    final Set<String> paths = <String>{};
    if (decodedGameData is! Map<String, dynamic>) {
      return paths;
    }
    final dynamic rawLevels = decodedGameData['levels'];
    if (rawLevels is! List) {
      return paths;
    }

    for (int levelIndex = 0; levelIndex < rawLevels.length; levelIndex++) {
      final dynamic rawLevel = rawLevels[levelIndex];
      if (rawLevel is! Map<String, dynamic>) {
        continue;
      }
      final dynamic rawReference = rawLevel[zonesFileFieldName];
      if (rawReference is! String) {
        continue;
      }
      final String relativePath = _normalizeProjectRelativePath(rawReference);
      if (relativePath.isNotEmpty) {
        paths.add(relativePath);
      }
    }
    return paths;
  }

  String _projectAbsolutePathForRelativePath(
    String projectDirectoryPath,
    String relativePath,
  ) {
    return '$projectDirectoryPath${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}';
  }

  bool _hasSupportedImageExtension(String fileName) {
    final String lower = fileName.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg');
  }

  Future<bool> _filesHaveSameContent(String pathA, String pathB) async {
    final File fileA = File(pathA);
    final File fileB = File(pathB);
    if (!await fileA.exists() || !await fileB.exists()) {
      return false;
    }
    final int lengthA = await fileA.length();
    final int lengthB = await fileB.length();
    if (lengthA != lengthB) {
      return false;
    }
    final List<int> bytesA = await fileA.readAsBytes();
    final List<int> bytesB = await fileB.readAsBytes();
    if (bytesA.length != bytesB.length) {
      return false;
    }
    for (int i = 0; i < bytesA.length; i++) {
      if (bytesA[i] != bytesB[i]) {
        return false;
      }
    }
    return true;
  }

  Set<String> referencedMediaFileNames() {
    final Set<String> references = <String>{};

    void addReference(String value) {
      final String normalized = _normalizeProjectRelativePath(value);
      if (normalized.isNotEmpty) {
        references.add(normalized);
      }
    }

    for (final asset in gameData.mediaAssets) {
      addReference(asset.fileName);
    }
    for (final animation in gameData.animations) {
      addReference(animation.mediaFile);
    }
    for (final level in gameData.levels) {
      for (final layer in level.layers) {
        addReference(layer.tilesSheetFile);
      }
      for (final sprite in level.sprites) {
        addReference(sprite.imageFile);
      }
    }

    return references;
  }

  Future<void> deleteProjectMediaFileIfUnreferenced(String fileName) async {
    if (selectedProject == null || filePath == "") {
      return;
    }

    final String normalized = _normalizeProjectRelativePath(fileName);
    if (normalized.isEmpty || !_hasSupportedImageExtension(normalized)) {
      return;
    }
    if (referencedMediaFileNames().contains(normalized)) {
      return;
    }

    final String absolutePath =
        _projectAbsolutePathForRelativePath(filePath, normalized);
    final File mediaFile = File(absolutePath);
    if (!await mediaFile.exists()) {
      return;
    }

    try {
      await mediaFile.delete();
      imagesCache.remove(fileName);
      imagesCache.remove(normalized);
    } catch (e) {
      if (kDebugMode) {
        print("Error deleting orphan media file \"$normalized\": $e");
      }
    }
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
    _clearAutosaveState();
    selectedProjectId = "";
    gameData = GameData(name: "", levels: []);
    filePath = "";
    fileName = "";
    selectedLevel = -1;
    selectedLayer = -1;
    selectedZone = -1;
    selectedSprite = -1;
    selectedAnimation = -1;
    selectedMedia = -1;
    animationSelectionStartFrame = -1;
    animationSelectionEndFrame = -1;
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
    viewportDragOffset = Offset.zero;
    viewportResizeOffset = Offset.zero;
    viewportIsDragging = false;
    viewportIsResizing = false;
    viewportPreviewX = 0;
    viewportPreviewY = 0;
    viewportPreviewWidth = 320;
    viewportPreviewHeight = 180;
    viewportPreviewLevel = -1;
    _undoStack.clear();
    _redoStack.clear();
    _clearUndoGroupingState();
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

  Future<String> createProject(
      {String? projectName, String? projectComments}) async {
    await flushPendingAutosave();
    if (projectsPath == "") {
      await initializeStorage();
    }

    final String defaultName = projectName?.trim().isNotEmpty == true
        ? projectName!.trim()
        : "New Project";
    final String defaultComments = _sanitizeProjectComments(projectComments);
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
      comments: defaultComments,
    );
    projects.add(newProject);
    selectedProjectId = newProject.id;

    gameData = GameData(name: defaultName, levels: []);
    selectedLevel = -1;
    selectedLayer = -1;
    selectedZone = -1;
    selectedSprite = -1;
    selectedAnimation = -1;
    selectedMedia = -1;
    animationSelectionStartFrame = -1;
    animationSelectionEndFrame = -1;
    selectedTileIndex = -1;
    selectedTilePattern = [];
    tilemapEraserEnabled = false;
    tilesetSelectionColStart = -1;
    tilesetSelectionRowStart = -1;
    tilesetSelectionColEnd = -1;
    tilesetSelectionRowEnd = -1;
    _undoStack.clear();
    _redoStack.clear();
    _clearUndoGroupingState();
    _clearAutosaveState();
    imagesCache.clear();
    viewportDragOffset = Offset.zero;
    viewportResizeOffset = Offset.zero;
    viewportIsDragging = false;
    viewportIsResizing = false;
    viewportPreviewX = 0;
    viewportPreviewY = 0;
    viewportPreviewWidth = 320;
    viewportPreviewHeight = 180;
    viewportPreviewLevel = -1;

    filePath = projectDirectory.path;
    fileName = gameFileName;
    await saveGame();
    await _saveProjectsIndex();
    projectStatusMessage = "Created project \"$defaultName\"";
    notifyListeners();
    return newProject.id;
  }

  Future<bool> renameProject(String projectId, String newName) async {
    return updateProjectInfo(
      projectId,
      newName: newName,
    );
  }

  Future<bool> updateProjectInfo(
    String projectId, {
    required String newName,
    String? comments,
  }) async {
    final String cleanName = newName.trim();
    if (cleanName.isEmpty) {
      return false;
    }
    final StoredProject? project = _findProjectById(projectId);
    if (project == null) {
      return false;
    }

    project.name = cleanName;
    project.comments = comments == null
        ? project.comments
        : _sanitizeProjectComments(comments);
    project.updatedAt = DateTime.now().toUtc().toIso8601String();

    final String projectPath =
        "$projectsPath${Platform.pathSeparator}${project.folderName}";
    final File file =
        File("$projectPath${Platform.pathSeparator}$gameFileName");
    if (await file.exists()) {
      final dynamic decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        decoded['name'] = cleanName;
        decoded[projectCommentsFieldName] = project.comments;
        final String output = await _formatMapAsGameJson(decoded);
        await file.writeAsString(output);
      }
    }

    if (selectedProjectId == projectId) {
      gameData = GameData(
        name: cleanName,
        levels: gameData.levels,
        levelGroups: gameData.levelGroups,
        mediaAssets: gameData.mediaAssets,
        mediaGroups: gameData.mediaGroups,
        animations: gameData.animations,
        animationGroups: gameData.animationGroups,
        zoneTypes: gameData.zoneTypes,
      );
    }

    await _saveProjectsIndex();
    projectStatusMessage = "Updated project \"$cleanName\"";
    notifyListeners();
    return true;
  }

  Future<bool> deleteProject(String projectId) async {
    await flushPendingAutosave();
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
      await flushPendingAutosave();
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
      await _hydrateExternalTileMapsIntoDecodedGameData(
        decoded: decoded,
        projectDirectoryPath: projectPath,
      );
      await _hydrateExternalZonesIntoDecodedGameData(
        decoded: decoded,
        projectDirectoryPath: projectPath,
      );

      gameData = GameData.fromJson(decoded);
      final bool migratedStructure = _projectNeedsStructureMigration(
        decoded: decoded,
      );
      selectedProjectId = projectId;
      filePath = projectPath;
      fileName = gameFileName;
      final bool migratedMedia = await _migrateProjectMediaToMediaFolder(
        projectDirectoryPath: projectPath,
      );
      if (migratedMedia || migratedStructure) {
        await _saveGameInternal(notifyOnSuccess: false);
      }
      selectedLevel = -1;
      selectedLayer = -1;
      selectedZone = -1;
      selectedSprite = -1;
      selectedAnimation = -1;
      selectedMedia = -1;
      animationSelectionStartFrame = -1;
      animationSelectionEndFrame = -1;
      selectedTileIndex = -1;
      selectedTilePattern = [];
      tilemapEraserEnabled = false;
      tilesetSelectionColStart = -1;
      tilesetSelectionRowStart = -1;
      tilesetSelectionColEnd = -1;
      tilesetSelectionRowEnd = -1;
      _undoStack.clear();
      _redoStack.clear();
      _clearUndoGroupingState();
      _clearAutosaveState();
      imagesCache.clear();
      viewportDragOffset = Offset.zero;
      viewportResizeOffset = Offset.zero;
      viewportIsDragging = false;
      viewportIsResizing = false;
      viewportPreviewX = 0;
      viewportPreviewY = 0;
      viewportPreviewWidth = 320;
      viewportPreviewHeight = 180;
      viewportPreviewLevel = -1;
      if (gameData.name.trim().isNotEmpty) {
        project.name = gameData.name.trim();
      }
      final String? commentsFromGameData =
          decoded.containsKey(projectCommentsFieldName)
              ? (decoded[projectCommentsFieldName] is String
                  ? _sanitizeProjectComments(
                      decoded[projectCommentsFieldName] as String)
                  : "")
              : null;
      if (commentsFromGameData != null) {
        project.comments = commentsFromGameData;
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
    await flushPendingAutosave();
    await openProject(selectedProjectId);
  }

  Future<String?> importProject() async {
    try {
      await flushPendingAutosave();
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
      final String inferredComments =
          await _readProjectCommentsFromDisk(importedGameFile) ?? "";

      final String now = DateTime.now().toUtc().toIso8601String();
      final StoredProject importedProject = StoredProject(
        id: _newProjectId(),
        name: inferredName,
        folderName: destinationFolderName,
        createdAt: now,
        updatedAt: now,
        comments: inferredComments,
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
      await flushPendingAutosave();
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
      final Map<String, List<int>> exportFiles = await _buildProjectExportFiles(
        project: project,
        sourceDirectoryPath: sourceDirectory.path,
      );
      final Archive archive = Archive();
      for (final MapEntry<String, List<int>> entry in exportFiles.entries) {
        archive.addFile(
          ArchiveFile(
            entry.key,
            entry.value.length,
            entry.value,
          ),
        );
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

  Future<Map<String, List<int>>> _buildProjectExportFiles({
    required StoredProject project,
    required String sourceDirectoryPath,
  }) async {
    final Map<String, List<int>> exportFiles = <String, List<int>>{};
    final Set<String> exportedRelativePaths = <String>{};

    final File gameDataFile = File(
      "$sourceDirectoryPath${Platform.pathSeparator}$gameFileName",
    );
    if (!await gameDataFile.exists()) {
      throw Exception("Cannot export: missing $gameFileName");
    }
    final List<int> gameDataBytesFromDisk = await gameDataFile.readAsBytes();
    List<int> gameDataBytesForExport = gameDataBytesFromDisk;
    dynamic decodedGameData;
    try {
      decodedGameData = jsonDecode(utf8.decode(gameDataBytesFromDisk));
      if (decodedGameData is Map<String, dynamic>) {
        decodedGameData[projectCommentsFieldName] = project.comments;
        final String output = await _formatMapAsGameJson(decodedGameData);
        gameDataBytesForExport = utf8.encode(output);
      }
    } catch (_) {
      decodedGameData = null;
    }
    exportFiles[gameFileName] = gameDataBytesForExport;
    exportedRelativePaths.add(gameFileName);

    Future<void> addReferencedFile({
      required String rawReference,
      required String debugLabel,
    }) async {
      final String relativePath = _normalizeProjectRelativePath(rawReference);
      if (relativePath.isEmpty ||
          relativePath == gameFileName ||
          exportedRelativePaths.contains(relativePath)) {
        return;
      }
      final File sourceFile = File(
        _projectAbsolutePathForRelativePath(sourceDirectoryPath, relativePath),
      );
      if (!await sourceFile.exists()) {
        if (kDebugMode) {
          print("Skipping missing referenced $debugLabel file: $relativePath");
        }
        return;
      }
      exportFiles[relativePath] = await sourceFile.readAsBytes();
      exportedRelativePaths.add(relativePath);
    }

    for (final String reference in referencedMediaFileNames()) {
      if (!_hasSupportedImageExtension(reference)) {
        continue;
      }
      await addReferencedFile(rawReference: reference, debugLabel: "media");
    }
    for (final String reference
        in _collectExternalTileMapPathsFromDecodedGameData(decodedGameData)) {
      await addReferencedFile(rawReference: reference, debugLabel: "tilemap");
    }
    for (final String reference
        in _collectExternalZonePathsFromDecodedGameData(decodedGameData)) {
      await addReferencedFile(rawReference: reference, debugLabel: "zones");
    }

    return exportFiles;
  }

  Future<bool> exportSelectedProjectToFolder() async {
    try {
      await flushPendingAutosave();
      final StoredProject? project = selectedProject;
      if (project == null) {
        return false;
      }

      final String? destinationRootPath =
          await FilePicker.platform.getDirectoryPath(
        dialogTitle: "Export Project to Folder",
        initialDirectory: projectsPath,
      );
      if (destinationRootPath == null) {
        return false;
      }

      final String destinationFolderName =
          await _buildUniqueDirectoryNameInDirectory(
        destinationRootPath,
        project.folderName,
      );
      final Directory destinationDirectory = Directory(
        "$destinationRootPath${Platform.pathSeparator}$destinationFolderName",
      );
      await destinationDirectory.create(recursive: true);

      final Directory sourceDirectory = Directory(
        "$projectsPath${Platform.pathSeparator}${project.folderName}",
      );
      final Map<String, List<int>> exportFiles = await _buildProjectExportFiles(
        project: project,
        sourceDirectoryPath: sourceDirectory.path,
      );

      for (final MapEntry<String, List<int>> entry in exportFiles.entries) {
        final String outputPath =
            "${destinationDirectory.path}${Platform.pathSeparator}${entry.key.replaceAll('/', Platform.pathSeparator)}";
        final File outputFile = File(outputPath);
        await outputFile.parent.create(recursive: true);
        await outputFile.writeAsBytes(entry.value);
      }

      projectStatusMessage = "Exported folder to ${destinationDirectory.path}";
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print("Error exporting project to folder: $e");
      }
      projectStatusMessage = "Export to folder failed: $e";
      notifyListeners();
      return false;
    }
  }

  Future<void> _saveGameInternal({
    bool notifyOnSuccess = true,
  }) async {
    final StoredProject? project = selectedProject;
    if (project == null) {
      throw Exception("No selected project");
    }

    if (filePath == "") {
      filePath = "$projectsPath${Platform.pathSeparator}${project.folderName}";
    }
    fileName = gameFileName;

    final Directory projectDirectory = Directory(filePath);
    if (!await projectDirectory.exists()) {
      await projectDirectory.create(recursive: true);
    }

    final file = File("$filePath${Platform.pathSeparator}$fileName");
    final Map<String, dynamic> encoded = gameData.toJson();
    encoded[projectCommentsFieldName] = project.comments;
    final Set<String> tileMapPaths =
        await _writeExternalTileMapsAndStripInlineFromGameData(
      encoded: encoded,
      projectDirectoryPath: filePath,
    );
    final Set<String> zonePaths =
        await _writeExternalZonesAndStripInlineFromGameData(
      encoded: encoded,
      projectDirectoryPath: filePath,
    );
    final String output = await _formatMapAsGameJson(encoded);
    await file.writeAsString(output);
    await _cleanupStaleExternalTileMapFiles(
      projectDirectoryPath: filePath,
      keepRelativePaths: tileMapPaths,
    );
    await _cleanupStaleExternalZoneFiles(
      projectDirectoryPath: filePath,
      keepRelativePaths: zonePaths,
    );

    if (gameData.name.trim().isNotEmpty) {
      project.name = gameData.name.trim();
    }
    project.updatedAt = DateTime.now().toUtc().toIso8601String();
    await _saveProjectsIndex();

    if (kDebugMode) {
      print("Game saved successfully to \"$filePath/$fileName\"");
    }

    if (notifyOnSuccess) {
      projectStatusMessage = "Saved project \"${project.name}\"";
      notifyListeners();
    }
  }

  Future<void> saveGame() async {
    try {
      await flushPendingAutosave();
      await _saveGameInternal();
    } catch (e) {
      if (kDebugMode) {
        print("Error saving game file: $e");
      }
      projectStatusMessage = "Save failed: $e";
      if (autosaveInlineMessage.isNotEmpty) {
        autosaveInlineMessage = '';
        autosaveHasError = false;
      }
      notifyListeners();
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

  GameAnimation? animationById(String animationId) {
    for (final animation in gameData.animations) {
      if (animation.id == animationId) {
        return animation;
      }
    }
    return null;
  }

  GameMediaAsset? mediaAssetByAnimationId(String animationId) {
    final GameAnimation? animation = animationById(animationId);
    if (animation == null) {
      return null;
    }
    return mediaAssetByFileName(animation.mediaFile);
  }

  String animationDisplayNameById(String animationId) {
    final GameAnimation? animation = animationById(animationId);
    if (animation == null) {
      return 'Unknown animation';
    }
    final String trimmed = animation.name.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    return GameMediaAsset.inferNameFromFileName(animation.mediaFile);
  }

  String mediaDisplayNameByFileName(String fileName) {
    final GameMediaAsset? asset = mediaAssetByFileName(fileName);
    if (asset == null) {
      return GameMediaAsset.inferNameFromFileName(fileName);
    }
    final String trimmed = asset.name.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    return GameMediaAsset.inferNameFromFileName(asset.fileName);
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
    String selectedFileName = _lastPathSegment(selectedPath);
    if (filePath == "") {
      filePath =
          "$projectsPath${Platform.pathSeparator}${selectedProject!.folderName}";
      fileName = gameFileName;
    }

    selectedFileName = _normalizeProjectRelativePath(selectedFileName);
    if (selectedFileName.isEmpty ||
        !_hasSupportedImageExtension(selectedFileName)) {
      return "";
    }
    final Directory mediaDirectory = Directory(
      "$filePath${Platform.pathSeparator}$mediaFolderName",
    );
    await mediaDirectory.create(recursive: true);

    final String preferredRelativePath =
        _mediaRelativePathForBaseName(selectedFileName);
    final String preferredDestinationPath =
        _projectAbsolutePathForRelativePath(filePath, preferredRelativePath);
    if (selectedPath != preferredDestinationPath &&
        await File(preferredDestinationPath).exists()) {
      final bool sameContent = await _filesHaveSameContent(
        selectedPath,
        preferredDestinationPath,
      );
      if (sameContent) {
        return preferredRelativePath;
      }
    }

    selectedFileName = await _buildUniqueFileNameInDirectory(
      mediaDirectory.path,
      selectedFileName,
    );
    selectedFileName = _mediaRelativePathForBaseName(selectedFileName);
    String destinationPath =
        _projectAbsolutePathForRelativePath(filePath, selectedFileName);

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
