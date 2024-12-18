import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:modal_gif_picker/src/model/giphy_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  String girUrl = "";
  @override
  void initState() {
    if (widget.useUrlToSaveMemory) {
    } else {
      _loadPreview = widget.repo.getPreview(widget.index);
    }
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      if (widget.useUrlToSaveMemory) {
        final url = await widget.repo.getPreview4Url(widget.index);
        if (url != null) {
          girUrl = url;
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

  @override
  Widget build(BuildContext context) => widget.useUrlToSaveMemory
      ? true
          ? CachedNetworkImage(
              imageUrl: girUrl,
              placeholder: (context, url) => loading(),
              errorWidget: (context, url, error) => loading(),
              imageBuilder: (context, imageProvider) => Container(
                    //     width: w,
                    //   height: w / 1.2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      borderRadius: BorderRadius.all(
                        Radius.circular(10),
                      ),
                      image: DecorationImage(
                          image: imageProvider, fit: BoxFit.fill),
                    ),
                  ))
          : Image.network(
              girUrl,
              gaplessPlayback: true,
              fit: BoxFit.fill,
              loadingBuilder: (context, child, loadingProgress) => loading(),
              errorBuilder: (context, error, stackTrace) => loading(),
            )
      : FutureBuilder(
          future: _loadPreview,
          builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
            if (!snapshot.hasData) {
              return loading();
            }
            return Image.memory(snapshot.data!, fit: BoxFit.cover);
          });
}
