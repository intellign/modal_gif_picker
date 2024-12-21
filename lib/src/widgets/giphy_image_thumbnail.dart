import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';

import 'package:modal_gif_picker/src/model/giphy_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:modal_gif_picker/src/model/client/gif.dart';

/// Loads and renders a gif thumbnail image using a GiphyRepostory and an index.
class GiphyImageThumbnail extends StatefulWidget {
  final bool useUrlToSaveMemory;
  final GiphyRepository repo;
  final int index;
  final Widget? placeholder;

  const GiphyImageThumbnail(
      {Key? key,
      required this.repo,
      required this.index,
      this.placeholder,
      this.useUrlToSaveMemory = false})
      : super(key: key);

  @override
  _GiphyImageThumbnailState createState() => _GiphyImageThumbnailState();
}

class _GiphyImageThumbnailState extends State<GiphyImageThumbnail> {
  late Future<Uint8List?> _loadPreview;
  GiphyGif? gif;
  @override
  void initState() {
    if (widget.useUrlToSaveMemory) {
    } else {
      _loadPreview = widget.repo.getPreview(widget.index);
    }
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      if (widget.useUrlToSaveMemory) {
        gif = await widget.repo.getPreview4Url(widget.index);
        if (gif != null && mounted) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    widget.repo.cancelGetPreview(widget.index);
    super.dispose();
  }

  Widget loading() {
    return widget.placeholder ??
        Container(
          alignment: Alignment.center,
          color: Colors.transparent,
          height: 50,
          width: 50,
          child: const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Colors.white54),
            strokeWidth: 1,
          ),
        );
  }

  Widget gifWidget() {
    if (gif!.images.fixedWidth == null ||
        (gif!.images.fixedWidth != null &&
            gif!.images.fixedWidth!.width == null)) {
      return loading();
    }
    double _aspectRatio = 0.0;
    _aspectRatio = (double.parse(gif!.images.fixedWidth!.width!) /
        double.parse(gif!.images.fixedWidth!.height!));

    return true
        ? ExtendedImage.network(
            gif?.images.fixedWidth!.webp! ?? "",
            semanticLabel: gif?.title,
            cache: true,
            gaplessPlayback: true,
            fit: BoxFit.fill,
            headers: const {'accept': 'image/*'},
            loadStateChanged: (state) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: gif == null
                  ? Container()
                  : case2(
                      state.extendedImageLoadState,
                      {
                        LoadState.loading: AspectRatio(
                          aspectRatio: _aspectRatio,
                          child: Container(
                            alignment: Alignment.center,
                            color: Colors.transparent,
                            height: 30,
                            width: 30,
                            child: const CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white54),
                              strokeWidth: 1,
                            ),
                          ),
                        ),
                        LoadState.completed: AspectRatio(
                          aspectRatio: _aspectRatio,
                          child: ExtendedRawImage(
                            fit: BoxFit.fill,
                            image: state.extendedImageInfo?.image,
                          ),
                        ),
                        LoadState.failed: AspectRatio(
                          aspectRatio: _aspectRatio,
                          child: Container(
                            color: Theme.of(context).cardColor,
                          ),
                        ),
                      },
                      AspectRatio(
                        aspectRatio: _aspectRatio,
                        child: Container(
                          color: Theme.of(context).cardColor,
                        ),
                      ),
                    ),
            ),
          )
        : gif != null && gif!.images.fixedWidth!.webp != null
            ? true
                ? CachedNetworkImage(
                    imageUrl: gif!.images.fixedWidth!.webp!,
                    placeholder: (context, url) => loading(),
                    errorWidget: (context, url, error) => loading(),
                    imageBuilder: (context, imageProvider) => Container(
                          //     width: w,
                          //   height: w / 1.2,
                          decoration: BoxDecoration(
                            //     shape: BoxShape.circle,
                            //  borderRadius: BorderRadius.all( Radius.circular(10)),
                            image: DecorationImage(
                                image: imageProvider, fit: BoxFit.fill),
                          ),
                        ))
                : Image.network(
                    gif!.images.fixedWidth!.webp!,
                    gaplessPlayback: true,
                    fit: BoxFit.fill,
                    loadingBuilder: (context, child, loadingProgress) =>
                        loading(),
                    errorBuilder: (context, error, stackTrace) => loading(),
                  )
            : loading();
  }

//////////////////
  TValue? case2<TOptionType, TValue>(
    TOptionType selectedOption,
    Map<TOptionType, TValue> branches, [
    TValue? defaultValue = null,
  ]) {
    if (!branches.containsKey(selectedOption)) {
      return defaultValue;
    }

    return branches[selectedOption];
  }

  @override
  Widget build(BuildContext context) => widget.useUrlToSaveMemory
      ? gifWidget()
      : FutureBuilder(
          future: _loadPreview,
          builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
            if (!snapshot.hasData) {
              return loading();
            }
            return Image.memory(snapshot.data!, fit: BoxFit.cover);
          });
}
