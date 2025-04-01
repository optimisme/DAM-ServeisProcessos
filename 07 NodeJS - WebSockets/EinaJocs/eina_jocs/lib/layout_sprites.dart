import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';
import 'titled_text_filed.dart';
import 'game_sprite.dart';

class LayoutSprites extends StatefulWidget {
  const LayoutSprites({super.key});

  @override
  LayoutSpritesState createState() => LayoutSpritesState();
}

class LayoutSpritesState extends State<LayoutSprites> {
  late TextEditingController typeController;
  late TextEditingController xController;
  late TextEditingController yController;
  late TextEditingController widthController;
  late TextEditingController heightController;
  String imageFile = "";
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    typeController = TextEditingController();
    xController = TextEditingController();
    yController = TextEditingController();
    widthController = TextEditingController();
    heightController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appData = Provider.of<AppData>(context, listen: false);
      updateForm(appData);
    });
  }

  @override
  void dispose() {
    typeController.dispose();
    xController.dispose();
    yController.dispose();
    widthController.dispose();
    heightController.dispose();
    super.dispose();
  }

  void updateForm(AppData appData) {
    if (appData.selectedLevel != -1 && appData.selectedSprite != -1) {
      final sprite = appData.gameData.levels[appData.selectedLevel]
          .sprites[appData.selectedSprite];
      typeController.text = sprite.type;
      xController.text = sprite.x.toString();
      yController.text = sprite.y.toString();
      widthController.text = sprite.spriteWidth.toString();
      heightController.text = sprite.spriteHeight.toString();
      imageFile = sprite.imageFile;
    } else {
      typeController.clear();
      xController.clear();
      yController.clear();
      widthController.clear();
      heightController.clear();
      imageFile = "";
    }
  }

  Future<void> _pickImage(AppData appData) async {
    imageFile = await appData.pickImageFile();
    appData.update();
  }

  void _addSprite(AppData appData) {
    if (appData.selectedLevel == -1) return;
    final newSprite = GameSprite(
      type: typeController.text,
      x: int.tryParse(xController.text) ?? 0,
      y: int.tryParse(yController.text) ?? 0,
      spriteWidth: int.tryParse(widthController.text) ?? 32,
      spriteHeight: int.tryParse(heightController.text) ?? 32,
      imageFile: imageFile,
    );
    appData.gameData.levels[appData.selectedLevel].sprites.add(newSprite);
    appData.selectedSprite = -1;
    imageFile = "";
    updateForm(appData);
    appData.update();
  }

  void _updateSprite(AppData appData) {
    if (appData.selectedLevel != -1 && appData.selectedSprite != -1) {
      appData.gameData.levels[appData.selectedLevel]
          .sprites[appData.selectedSprite] = GameSprite(
        type: typeController.text,
        x: int.tryParse(xController.text) ?? 0,
        y: int.tryParse(yController.text) ?? 0,
        spriteWidth: int.tryParse(widthController.text) ?? 32,
        spriteHeight: int.tryParse(heightController.text) ?? 32,
        imageFile: imageFile,
      );
      appData.update();
    }
  }

  void _deleteSprite(AppData appData) {
    if (appData.selectedLevel != -1 && appData.selectedSprite != -1) {
      appData.gameData.levels[appData.selectedLevel].sprites
          .removeAt(appData.selectedSprite);
      appData.selectedSprite = -1;
      updateForm(appData);
      appData.update();
    }
  }

  void selectSprite(AppData appData, int index, bool isSelected) {
    appData.selectedSprite = isSelected ? -1 : index;
    updateForm(appData);
    appData.update();
  }

  void _onReorder(AppData appData, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final sprites = appData.gameData.levels[appData.selectedLevel].sprites;
    final int selectedIndex = appData.selectedSprite;
    final sprite = sprites.removeAt(oldIndex);
    sprites.insert(newIndex, sprite);
    if (selectedIndex == oldIndex) {
      appData.selectedSprite = newIndex;
    } else if (selectedIndex > oldIndex && selectedIndex <= newIndex) {
      appData.selectedSprite -= 1;
    } else if (selectedIndex < oldIndex && selectedIndex >= newIndex) {
      appData.selectedSprite += 1;
    }
    appData.update();
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context);
    if (appData.selectedLevel == -1) {
      return const Center(child: Text('No level selected'));
    }
    final level = appData.gameData.levels[appData.selectedLevel];
    final sprites = level.sprites;
    final bool isFormFilled = typeController.text.isNotEmpty &&
        xController.text.isNotEmpty &&
        yController.text.isNotEmpty &&
        widthController.text.isNotEmpty &&
        heightController.text.isNotEmpty &&
        imageFile.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('Editing Sprites for level "${level.name}"',
              style:
                  const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: sprites.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text('(No sprites defined)',
                      style: TextStyle(
                          fontSize: 12.0, color: CupertinoColors.systemGrey)),
                )
              : CupertinoScrollbar(
                  controller: scrollController,
                  child: Localizations.override(
                    context: context,
                    delegates: [
                      DefaultMaterialLocalizations.delegate,
                      DefaultWidgetsLocalizations.delegate,
                    ],
                    child: ReorderableListView.builder(
                      itemCount: sprites.length,
                      onReorder: (oldIndex, newIndex) =>
                          _onReorder(appData, oldIndex, newIndex),
                      itemBuilder: (context, index) {
                        final isSelected = index == appData.selectedSprite;
                        final sprite = sprites[index];
                        String subtitle =
                            "${sprite.x}, ${sprite.y} - ${sprite.imageFile}";
                        return GestureDetector(
                          key: ValueKey(sprites[index]),
                          onTap: () =>
                              selectSprite(appData, index, isSelected),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            color: isSelected
                                ? CupertinoColors.systemBlue.withOpacity(0.2)
                                : CupertinoColors.systemBackground,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(sprite.type,
                                          style: TextStyle(
                                              fontSize: 14.0,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal)),
                                      const SizedBox(height: 2),
                                      Text(subtitle,
                                          style: const TextStyle(
                                              fontSize: 12.0,
                                              color:
                                                  CupertinoColors.systemGrey)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
              appData.selectedSprite == -1 ? 'Add sprite:' : 'Modify sprite:',
              style:
                  const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: TitledTextfield(
              title: "Sprite type",
              controller: typeController,
              onChanged: (_) => setState(() {})),
        ),
        const SizedBox(height: 16),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'Sprite image:',
              style:
                  const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
            )),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  imageFile.isEmpty ? "No file selected" : imageFile,
                  style: const TextStyle(
                      fontSize: 12.0, color: CupertinoColors.systemGrey),
                ),
              ),
              CupertinoButton.filled(
                sizeStyle: CupertinoButtonSize.small,
                borderRadius: BorderRadius.all(Radius.circular(5)),
                child: const Text("Choose File",
                    style:
                        TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold)),
                onPressed: () => _pickImage(appData),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Expanded(
                child: TitledTextfield(
                  title: 'Start X (px)',
                  controller: xController,
                  placeholder: '0',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TitledTextfield(
                  title: 'Start Y (px)',
                  controller: yController,
                  placeholder: '0',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Expanded(
                child: TitledTextfield(
                  title: 'Sprite Width (px)',
                  controller: widthController,
                  placeholder: '32',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TitledTextfield(
                  title: 'Sprite Height (px)',
                  controller: heightController,
                  placeholder: '32',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (appData.selectedSprite != -1) ...[
              CupertinoButton.filled(
                sizeStyle: CupertinoButtonSize.small,
                borderRadius: BorderRadius.all(Radius.circular(5)),
                onPressed: isFormFilled ? () => _updateSprite(appData) : null,
                child: const Text('Update'),
              ),
              CupertinoButton(
                sizeStyle: CupertinoButtonSize.small,
                borderRadius: BorderRadius.all(Radius.circular(5)),
                color: CupertinoColors.destructiveRed,
                onPressed: () => _deleteSprite(appData),
                child:
                    const Text('Delete', style: TextStyle(color: Colors.white)),
              ),
            ] else
              CupertinoButton.filled(
                sizeStyle: CupertinoButtonSize.small,
                borderRadius: BorderRadius.all(Radius.circular(5)),
                onPressed: isFormFilled ? () => _addSprite(appData) : null,
                child: const Text('Add Sprite'),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
