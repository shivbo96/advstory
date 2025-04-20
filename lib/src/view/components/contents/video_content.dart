import 'dart:io';

import 'package:advstory/src/view/components/contents/contents_base.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoContent extends ManagedContent {
  const VideoContent({
    required super.url,
    super.requestHeaders,
    super.cacheKey,
    super.header,
    super.footer,
    super.timeout,
    Widget Function()? errorBuilder,
    super.key,
  }) : super(errorBuiler: errorBuilder);

  @override
  StoryContentState<VideoContent> createState() => _VideoContentState();
}

class _VideoContentState extends StoryContentState<VideoContent> {
  VideoPlayerController? _videoController;
  bool _hasError = false;

  @override
  Future<void> initContent() async {
    if (widget.timeout != null) setTimeout(widget.timeout!);

    try {
      final file = await loadFile(
        url: widget.url,
        cacheKey: widget.cacheKey,
        requestHeaders: widget.requestHeaders,
      );

      if (!mounted) return;
      print('file=${file.path}');
      final isValid = await _isProbablyPlayable(file);
      if (!isValid) {
        throw Exception('Invalid video file detected');
      }

      final controller = VideoPlayerController.file(file);
      await controller.initialize();

      if (!mounted) return;
      setState(() {
        _videoController = controller;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        markReady(duration: controller.value.duration);
      });
    } catch (e) {
      print('VideoContent Error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  Future<bool> _isProbablyPlayable(File file) async {
    try {
      final List<int> bytes = await file
          .openRead(0, 12)
          .first;
      final magic = String.fromCharCodes(bytes);

      // Check for common video "ftyp" headers
      return magic.contains('ftyp');
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_hasError && widget.errorBuiler != null) {
      return widget.errorBuiler!.call();
    }

    if (_videoController?.value.isInitialized == true) {
      return Center(
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
      );
    }

    return shouldShowLoading ? loadingScreen : const SizedBox();
  }

  @override
  void onStart() {
    _videoController?.play();
  }

  @override
  void onResume() {
    _videoController?.play();
  }

  @override
  void onPause() {
    _videoController?.pause();
  }

  @override
  void onStop() {
    _videoController?.pause();
    _videoController?.seekTo(Duration.zero);
  }

  @override
  void onTimeout() {
    setState(() {
      _hasError = true;
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }
}
