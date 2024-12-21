import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:modal_gif_picker/src/model/client/gif.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:extended_image/extended_image.dart';

/// Loads and renders a Giphy image.
class GiphyRenderImage extends StatefulWidget {
  final String? url;
  final Widget? placeholder;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final bool renderGiphyOverlay;
  final bool useUrlToSaveMemory;
  final GiphyGif gif;

  /// Loads an image from given url.
  const GiphyRenderImage(
      {Key? key,
      this.url,
      this.placeholder,
      this.width,
      this.height,
      this.fit,
      required this.gif,
      this.renderGiphyOverlay = true,
      this.useUrlToSaveMemory = false})
      : super(key: key);

  /// Loads the original image for given Giphy gif.
  GiphyRenderImage.original(
      {Key? key,
      required this.gif,
      this.placeholder,
      this.width,
      this.height,
      this.fit,
      this.renderGiphyOverlay = true,
      this.useUrlToSaveMemory = false})
      : url = gif.images.original?.url,
        super(key: key ?? Key(gif.id));

  /// Loads the original still image for given Giphy gif.
  GiphyRenderImage.originalStill(
      {Key? key,
      required this.gif,
      this.placeholder,
      this.width,
      this.height,
      this.fit,
      this.renderGiphyOverlay = true,
      this.useUrlToSaveMemory = false})
      : url = gif.images.originalStill?.url,
        super(key: key ?? Key(gif.id));

  /// Loads the original still image for given Giphy gif.
  GiphyRenderImage.fixedWidth(
      {Key? key,
      required this.gif,
      this.placeholder,
      this.width,
      this.height,
      this.fit,
      this.renderGiphyOverlay = true,
      this.useUrlToSaveMemory = false})
      : url = gif.images.fixedWidth?.webp,
        super(key: key ?? Key(gif.id));

  @override
  _GiphyRenderImageState createState() => _GiphyRenderImageState();

  /// Loads the images bytes for given url from Giphy.
  static Future<Uint8List?> load(String? url, {Client? client}) async {
    if (url == null) {
      return null;
    }
    final response = await (client ?? Client())
        .get(Uri.parse(url), headers: {'accept': 'image/*'});

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    return null;
  }
}

class _GiphyRenderImageState extends State<GiphyRenderImage> {
  late Future<Uint8List?> _loadImage;

  @override
  void initState() {
    _loadImage = GiphyRenderImage.load(widget.url);
    super.initState();
  }

  Widget loading() {
    return widget.placeholder ??
        const Center(child: CircularProgressIndicator());
  }

  Widget gifWidget() {
    if (widget.gif.images.fixedWidth == null ||
        (widget.gif.images.fixedWidth != null &&
            widget.gif.images.fixedWidth!.width == null)) {
      return loading();
    }
    double _aspectRatio = 0.0;
    _aspectRatio = (double.parse(widget.gif.images.fixedWidth!.width!) /
        double.parse(widget.gif.images.fixedWidth!.height!));

    return true
        ? ExtendedImage.network(
            widget.gif.images.fixedWidth!.webp!,
            semanticLabel: widget.gif.title,
            cache: true,
            gaplessPlayback: true,
            fit: BoxFit.fill,
            headers: const {'accept': 'image/*'},
            loadStateChanged: (state) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: widget.gif.images.fixedWidth == null
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
        : widget.gif.images != null &&
                widget.gif.images.fixedWidth!.webp != null
            ? true
                ? CachedNetworkImage(
                    imageUrl: widget.gif.images.fixedWidth!.webp!,
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
                    widget.gif.images.fixedWidth!.webp!,
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
          future: _loadImage,
          builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
            if (snapshot.hasData) {
              final image = Image.memory(snapshot.data!,
                  width: widget.width, height: widget.height, fit: widget.fit);

              if (widget.renderGiphyOverlay) {
                /// removed giphy overlay
                return image;
              }
              return image;
            }
            return loading();
          });
}
