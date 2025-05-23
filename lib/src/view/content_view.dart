import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:advstory/src/contants/enums.dart';
import 'package:advstory/src/model/story.dart';
import 'package:advstory/src/model/story_position.dart';
import 'package:advstory/src/util/extended_page_controller.dart';
import 'package:advstory/src/view/components/contents/contents_base.dart';
import 'package:advstory/src/view/components/contents/simple_custom_content.dart';
import 'package:advstory/src/view/components/story_indicator.dart';
import 'package:advstory/src/view/inherited_widgets/content_position_provider.dart';
import 'package:advstory/src/view/inherited_widgets/data_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// View for story contents. This widget uses a PageView to show story content
/// in a sequence.
class ContentView extends StatefulWidget {
  /// Creates a widget to display story, indicators, footer and header.
  const ContentView({
    required this.storyIndex,
    required this.story,
    super.key,
  });

  /// Index of the story in the story list.
  final int storyIndex;

  /// Story that is being displayed in this view.
  final Story story;

  @override
  ContentViewState createState() => ContentViewState();
}

/// State for [ContentView].
class ContentViewState extends State<ContentView> with AutomaticKeepAliveClientMixin {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  ExtendedPageController? _pageController;
  DataProvider? _provider;

  /// Returns width without using [MediaQuery].
  double get width => (window.physicalSize / window.devicePixelRatio).width;

  @override
  void didChangeDependencies() {
    _provider ??= DataProvider.of(context)!;
    final initialPage = _provider!.positionNotifier.initialPosition.story == widget.storyIndex ? _provider!.positionNotifier.content : 0;
    _pageController ??= ExtendedPageController(
      itemCount: widget.story.contentCount,
      initialPage: initialPage,
    );
    _provider!.controller.setContentController(_pageController!, widget.storyIndex);

    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _provider!.controller.cleanContentController(widget.storyIndex);
    super.dispose();
  }

  /// Skips to the next content if touched position is in the right 23
  /// percent of screen.
  ///
  /// Skips to the previous content if touched position is in the left 23
  /// percent of screen.
  void _handleTapUp(TapUpDetails event) {
    final viewWidth = scaffoldKey.currentContext?.size?.width ?? width;
    final x = event.localPosition.dx;

    if (x > viewWidth * .77) {
      _provider!.controller.toNextContent();
    } else if (x < viewWidth * .23) {
      _provider!.controller.toPreviousContent();
    } else {
      _provider!.controller.resume();
    }
  }

  /// Pause the story and unfocus if the user taps anywhere on the screen
  /// including footer and header areas.
  void _handleDownPress(_) {
    // Close keyboard if opened.
    if (window.viewInsets.bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();

      if (_provider!.style.hideBars) {
        // Hide status bar and navigation bar. Keyboard causing show up.
        Future.delayed(const Duration(seconds: 1), () {
          SystemChrome.restoreSystemUIOverlays();
        });
      }
    }

    _provider!.controller.pause(innerCall: true);
  }

  ({Widget? header, Widget? footer}) _getComponents(AdvStoryContent content) {
    Widget? headerWidget;
    Widget? footerWidget;
    VoidCallback? onHeaderTap, onFooterTap;

    if (content is SimpleCustomContent) {
      headerWidget = content.useStoryHeader ? widget.story.header : null;
      footerWidget = content.useStoryFooter ? widget.story.footer : null;

      onHeaderTap = content.useStoryHeader ? widget.story.onHeaderTap : null;
      onFooterTap = content.useStoryFooter ? widget.story.onFooterTap : null;
    } else if (content is ManagedContent) {
      headerWidget = content.header ?? widget.story.header;
      footerWidget = content.footer ?? widget.story.footer;

      onHeaderTap = content.onHeaderTap ?? widget.story.onHeaderTap;
      onFooterTap = content.onFooterTap ?? widget.story.onFooterTap;
    }

    Widget? header = headerWidget != null
        ? GestureDetector(
            onTap: onHeaderTap,
            behavior: HitTestBehavior.opaque,
            child: headerWidget,
          )
        : null;

    Widget? footer = footerWidget != null
        ? GestureDetector(
            onTap: onFooterTap,
            child: footerWidget,
          )
        : null;

    return (header: header, footer: footer);
  }

  void onVerticalDrag(DragEndDetails details) {
    if (details.primaryVelocity! < 0) {
      _provider!.controller.resume();
      return;
    }

    final interception = _provider!.controller.interceptor?.call(
      StoryEvent.close,
    );

    if (interception != null) {
      interception();
    } else {
      /*!_provider!.hasTrays ? _provider!.controller.positionNotifier.shouldShowView.value = false :*/ Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return SafeArea(
      bottom: false,
      child: Scaffold(
        backgroundColor: _provider!.style.backgroundColor,
        key: scaffoldKey,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onLongPressDown: _handleDownPress,
              onLongPressCancel: _provider!.controller.resume,
              onLongPressUp: _provider!.controller.resume,
              onLongPress: _provider!.controller.exactPause,
              onTapUp: _handleTapUp,
              onVerticalDragEnd: onVerticalDrag,
              child: PageView.builder(
                allowImplicitScrolling: _provider!.preloadContent,
                controller: _pageController,
                itemCount: widget.story.contentCount,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final AdvStoryContent content = widget.story.contentBuilder(index);
                  log("Built story content $index, widget is ${content.runtimeType}");
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                          child: SafeArea(
                        child: Stack(
                          children: [
                            Positioned.fill(
                                child: FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                        width: MediaQuery.sizeOf(context).width,
                                        child: ContentPositionProvider(position: StoryPosition(index, widget.storyIndex), child: content)))),
                            FadeTransition(
                              opacity: _provider!.controller.opacityController,
                              child: Padding(
                                padding: EdgeInsets.only(top: _provider!.style.indicatorStyle.height + 16),
                                child: _getComponents(content).header ?? SizedBox.shrink(),
                              ),
                            )
                          ],
                        ),
                      )),
                      FadeTransition(
                        opacity: _provider!.controller.opacityController,
                        child: Padding(
                          padding: getBottomPadding(context),
                          child: _getComponents(content).footer ?? SizedBox.shrink(),
                        ),
                      )
                    ],
                  );
                },
              ),
            ),
            Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ValueListenableBuilder(
                  valueListenable: _provider!.positionNotifier,
                  builder: (context, value, child) {
                    return value == widget.storyIndex
                        ? StoryIndicator(
                            activeIndicatorIndex: _pageController!.page?.toInt() ?? _pageController!.initialPage.toInt(),
                            count: widget.story.contentCount,
                            controller: _provider!.controller.flowManager.indicatorController,
                            style: _provider!.style.indicatorStyle,
                          )
                        : StoryIndicator.placeholder(
                            count: widget.story.contentCount,
                            style: _provider!.style.indicatorStyle,
                          );
                  },
                )),
          ],
        ),
      ),
    );
  }

  EdgeInsets getBottomPadding(final BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final bottomPadding = math.max(mediaQuery.viewInsets.bottom - mediaQuery.viewPadding.bottom, 0.0);

    debugPrint(MediaQuery.of(context).viewInsets.toString());
    debugPrint(MediaQuery.of(context).viewPadding.toString());

    debugPrint("Bottom padding: $bottomPadding");

    return EdgeInsets.only(bottom: bottomPadding + (Platform.isIOS ? 40 : 0));
  }

  @override
  bool get wantKeepAlive => true;
}
