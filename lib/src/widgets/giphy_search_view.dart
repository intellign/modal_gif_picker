// ignore_for_file: must_be_immutable

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:modal_gif_picker/src/model/giphy_repository.dart';
import 'package:modal_gif_picker/src/utils/debouncer.dart';
import 'package:modal_gif_picker/src/widgets/giphy_context.dart';
import 'package:modal_gif_picker/src/widgets/giphy_grid_view.dart';

/// Provides the UI for searching Giphy gif images.
class GiphySearchView extends StatefulWidget {
  /// added scroll controller
  final ScrollController? sheetScrollController;
  int crossAxisCount;
  double childAspectRatio;
  double crossAxisSpacing;
  double mainAxisSpacing;
  Widget? addMediaTopWidget;
  bool useUrlToSaveMemory;
  GiphySearchView({
    Key? key,
    this.sheetScrollController,
    this.childAspectRatio = 1.6,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 5,
    this.mainAxisSpacing = 5,
    this.addMediaTopWidget,
    this.useUrlToSaveMemory = false,
  }) : super(key: key);
  @override
  _GiphySearchViewState createState() => _GiphySearchViewState();
}

class _GiphySearchViewState extends State<GiphySearchView> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final _repoController = StreamController<GiphyRepository>();
  late Debouncer _debouncer;

  @override
  void initState() {
    // initiate search on next frame (we need context)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final giphy = GiphyContext.of(context);
      _debouncer = Debouncer(
        delay: giphy.searchDelay,
      );
      _search(giphy);
    });
    super.initState();
  }

  @override
  void dispose() {
    _repoController.close();
    _debouncer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final giphy = GiphyContext.of(context);

    /// customize text field search and some font styles
    return Column(children: <Widget>[
      Material(
        elevation: 0,
        color: Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: TextField(
                  focusNode: _focusNode,
                  controller: _textController,
                  decoration: InputDecoration(
                    icon: Icon(
                      Icons.search,
                      color: Colors.white.withOpacity(0.8),
                      size: 30,
                    ),
                    border: InputBorder.none,
                    hintText: 'Search',
                    hintStyle: TextStyle(
                        color: Colors.white54.withOpacity(0.5), fontSize: 22),
                  ),
                  style: TextStyle(
                      color: Colors.white54.withOpacity(0.7), fontSize: 22),
                  onChanged: (value) {
                    _delayedSearch(giphy, value);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      Expanded(
          child: NestedScrollView(
              controller: widget.sheetScrollController,
              floatHeaderSlivers: true,
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    if (widget.addMediaTopWidget != null &&
                        _textController.text.isEmpty)
                      SliverToBoxAdapter(
                          child: Container(
                              margin: EdgeInsets.only(top: 17, bottom: 20),
                              child: widget.addMediaTopWidget!)),
                    SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Trending on GIPHY',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Align(
                                alignment: Alignment.centerRight,
                                child: Image.asset(
                                    'assets/PoweredBy_200px-Black_HorizLogo.png',
                                    package: 'modal_gif_picker',
                                    height: 20)),
                          )
                        ],
                      ),
                    ),
                  ],
              body: StreamBuilder(
                  stream: _repoController.stream,
                  builder: (BuildContext context,
                      AsyncSnapshot<GiphyRepository> snapshot) {
                    if (snapshot.hasData) {
                      return snapshot.data!.totalCount > 0
                          ? NotificationListener(
                              onNotification: (n) {
                                // hide keyboard when scrolling
                                if (n is UserScrollNotification) {
                                  FocusScope.of(context)
                                      .requestFocus(FocusNode());
                                  return true;
                                }
                                return false;
                              },
                              child: RefreshIndicator(
                                onRefresh: () =>
                                    _search(giphy, term: _textController.text),
                                child: GiphyGridView(
                                    key: Key('${snapshot.data.hashCode}'),
                                    crossAxisCount: widget.crossAxisCount,
                                    childAspectRatio: widget.childAspectRatio,
                                    crossAxisSpacing: widget.crossAxisSpacing,
                                    mainAxisSpacing: widget.mainAxisSpacing,
                                    repo: snapshot.data!,
                                    useUrlToSaveMemory:
                                        widget.useUrlToSaveMemory,

                                    /// add scroll controller
                                    scrollController:
                                        widget.sheetScrollController),
                              ),
                            )
                          : Center(
                              child: Text(
                              'No results',
                              style: TextStyle(
                                  color: Colors.white54.withOpacity(0.5),
                                  fontSize: 18),
                            ));
                    } else if (snapshot.hasError) {
                      Center(
                          child: Text('An error occurred',
                              style: TextStyle(
                                  color: Colors.white54.withOpacity(0.5),
                                  fontSize: 18)));
                    }
                    return const Center(
                        child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.red),
                      strokeWidth: 1.2,
                    ));
                  })))
    ]);
  }

  void _delayedSearch(GiphyContext giphy, String term) =>
      _debouncer.call(() => _search(giphy, term: term));

  Future _search(GiphyContext giphy, {String term = ''}) async {
    // skip search if term does not match current search text
    if (term != _textController.text) {
      return;
    }

    try {
      // search, or trending when term is empty
      final repo = await (term.isEmpty
          ? GiphyRepository.trending(
              apiKey: giphy.apiKey,
              rating: giphy.rating,
              sticker: giphy.sticker,
              previewType: giphy.previewType,
              onError: giphy.onError,
              useUrlToSaveMemory: widget.useUrlToSaveMemory)
          : GiphyRepository.search(
              apiKey: giphy.apiKey,
              query: term,
              rating: giphy.rating,
              lang: giphy.language,
              sticker: giphy.sticker,
              previewType: giphy.previewType,
              onError: giphy.onError,
            ));

      // scroll up
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      if (mounted) {
        _repoController.add(repo);
      }
    } catch (error) {
      if (mounted) {
        _repoController.addError(error);
      }
      giphy.onError?.call(error);
    }
  }
}
