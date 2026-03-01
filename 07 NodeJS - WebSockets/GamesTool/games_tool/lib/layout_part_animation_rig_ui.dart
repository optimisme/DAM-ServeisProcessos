part of 'layout.dart';

/// Animation-rig canvas overlay widgets (grid toggle & frame strip).
extension _LayoutAnimationRigUI on _LayoutState {
  Widget _buildAnimationRigGridOverlay(AppData appData) {
    final GameAnimation? animation = _selectedAnimationForRig(appData);
    final bool enabled = animation != null;
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: CDKButton(
          style: CDKButtonStyle.normal,
          onPressed: !enabled
              ? null
              : () {
                  appData.animationRigShowPixelGrid =
                      !appData.animationRigShowPixelGrid;
                  appData.update();
                },
          child: Text(
            appData.animationRigShowPixelGrid ? 'Grid: On' : 'Grid: Off',
          ),
        ),
      ),
    );
  }

  Widget _buildAnimationRigFrameStripOverlay(AppData appData) {
    final GameAnimation? animation = _selectedAnimationForRig(appData);
    if (animation == null) {
      return const SizedBox.shrink();
    }
    final int animationStart =
        animation.startFrame < 0 ? 0 : animation.startFrame;
    final int animationEnd = animation.endFrame < animationStart
        ? animationStart
        : animation.endFrame;
    final List<int> selectedFrames = _animationRigSelectedFrames(
      appData,
      animation,
      writeBack: true,
    );
    final int selectedStart =
        selectedFrames.isEmpty ? animationStart : selectedFrames.first;
    final int selectedEnd =
        selectedFrames.isEmpty ? animationEnd : selectedFrames.last;
    final int activeFrame = _animationRigActiveFrame(
      appData,
      animation,
      writeBack: true,
    );
    final ui.Image? sourceImage = appData.imagesCache[animation.mediaFile];
    final mediaAsset = appData.mediaAssetByFileName(animation.mediaFile);
    final bool canDrawFramePreview = sourceImage != null &&
        mediaAsset != null &&
        mediaAsset.tileWidth > 0 &&
        mediaAsset.tileHeight > 0;
    final double frameWidth =
        canDrawFramePreview ? mediaAsset.tileWidth.toDouble() : 0.0;
    final double frameHeight =
        canDrawFramePreview ? mediaAsset.tileHeight.toDouble() : 0.0;
    final int columns = canDrawFramePreview
        ? ((sourceImage.width / mediaAsset.tileWidth).floor().clamp(1, 99999))
        : 1;
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    const Color selectionColor = Color(0xFFFFC94A);
    const Color activeColor = Color(0xFFFFA928);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        child: Container(
          height: _LayoutState._animationRigFrameStripReservedHeight,
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          decoration: BoxDecoration(
            color: cdkColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border(
              top: BorderSide(
                color: cdkColors.colorTextSecondary.withValues(alpha: 0.30),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CDKButton(
                    style: CDKButtonStyle.normal,
                    onPressed: () {
                      _setAnimationRigFrameSelection(
                        appData,
                        animation,
                        startFrame: animationStart,
                        endFrame: animationEnd,
                      );
                      appData.update();
                      layoutAnimationRigsKey.currentState?.updateForm(appData);
                    },
                    child: const Text('All'),
                  ),
                  const SizedBox(width: 10),
                  CDKText(
                    selectedStart == selectedEnd
                        ? 'Frame $selectedStart selected'
                        : 'Frames $selectedStart-$selectedEnd selected',
                    role: CDKTextRole.caption,
                    secondary: true,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List<Widget>.generate(
                      animationEnd - animationStart + 1,
                      (index) {
                        final int frame = animationStart + index;
                        final bool inSelection =
                            frame >= selectedStart && frame <= selectedEnd;
                        final bool isActive = frame == activeFrame;
                        final Color borderColor = isActive
                            ? activeColor
                            : (inSelection
                                ? selectionColor
                                : cdkColors.colorTextSecondary
                                    .withValues(alpha: 0.35));
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () {
                              final bool expandSelection =
                                  _isLayerSelectionModifierPressed();
                              if (expandSelection) {
                                final int baseStart =
                                    appData.animationRigSelectionStartFrame >= 0
                                        ? appData
                                            .animationRigSelectionStartFrame
                                        : frame;
                                _setAnimationRigFrameSelection(
                                  appData,
                                  animation,
                                  startFrame: baseStart,
                                  endFrame: frame,
                                );
                              } else if (selectedStart == selectedEnd &&
                                  selectedStart != frame) {
                                _setAnimationRigFrameSelection(
                                  appData,
                                  animation,
                                  startFrame: selectedStart,
                                  endFrame: frame,
                                );
                              } else {
                                _setAnimationRigFrameSelection(
                                  appData,
                                  animation,
                                  startFrame: frame,
                                  endFrame: frame,
                                );
                              }
                              appData.update();
                              layoutAnimationRigsKey.currentState
                                  ?.updateForm(appData);
                            },
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: cdkColors.backgroundSecondary1,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: borderColor,
                                  width: isActive
                                      ? 2.2
                                      : (inSelection ? 1.8 : 1.0),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.all(3),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: canDrawFramePreview
                                            ? CustomPaint(
                                                painter:
                                                    _AnimationRigFramePreviewPainter(
                                                  image: sourceImage,
                                                  frameWidth: frameWidth,
                                                  frameHeight: frameHeight,
                                                  columns: columns,
                                                  frameIndex: frame,
                                                ),
                                              )
                                            : Center(
                                                child: CDKText(
                                                  '$frame',
                                                  role: CDKTextRole.caption,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 2,
                                    bottom: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xAA000000),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: CDKText(
                                        '$frame',
                                        role: CDKTextRole.caption,
                                        color: CupertinoColors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
