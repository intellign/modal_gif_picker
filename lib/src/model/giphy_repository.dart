import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:modal_gif_picker/modal_gif_picker.dart';
import 'package:modal_gif_picker/src/model/repository.dart';

typedef GetCollection = Future<GiphyCollection> Function(
    GiphyClient client, int offset, int limit);

/// Retrieves and caches gif collections from Giphy.
class GiphyRepository extends Repository<GiphyGif> {
  final _client = http.Client();
  final _previewCompleters = HashMap<int, Completer<Uint8List?>>();
  final _previewCompletersUrl = HashMap<int, Completer<GiphyGif?>>();
  final _previewQueue = Queue<int>();
  final GetCollection getCollection;
  final int maxConcurrentPreviewLoad;
  late GiphyClient _giphyClient;
  int _previewLoad = 0;
  final GiphyPreviewType? previewType;

  final bool useUrlToSaveMemory;

  GiphyRepository({
    required String apiKey,
    required this.getCollection,
    this.maxConcurrentPreviewLoad = 4,
    int pageSize = 25,
    ErrorListener? onError,
    this.previewType,
    this.useUrlToSaveMemory = false,
  }) : super(pageSize: pageSize, onError: onError) {
    _giphyClient = GiphyClient(apiKey: apiKey, client: _client);
  }

  /// Retrieves specified page of gif data from Giphy.
  @override
  Future<Page<GiphyGif>> getPage(int page) async {
    final offset = page * pageSize;
    final collection = await getCollection(_giphyClient, offset, pageSize);
    return Page(collection.data, page, collection.pagination?.totalCount ?? 0);
  }

  /// Retrieves a preview Gif image at specified index.
  Future<Uint8List?> getPreview(
    int index,
  ) async {
    var completer = _previewCompleters[index];
    if (completer == null) {
      completer = Completer<Uint8List?>();
      _previewCompleters[index] = completer;
      _previewQueue.add(index);

      // initiate next load
      _loadNextPreview();
    }

    return completer.future;
  }

  Future<GiphyGif?> getPreview4Url(
    int index,
  ) async {
    if (useUrlToSaveMemory) {
      var completer = _previewCompletersUrl[index];
      if (completer == null) {
        completer = Completer<GiphyGif?>();
        _previewCompletersUrl[index] = completer;
        _previewQueue.add(index);

        // initiate next load
        _loadNextPreview();
      }

      return completer.future;
    }
  }

  /// Cancels retrieving specified preview image, by removing it from the queue.
  void cancelGetPreview(int index) {
    final completer =
        (useUrlToSaveMemory ? _previewCompletersUrl : _previewCompleters)
            .remove(index);
    if (completer != null) {
      // remove from queue
      _previewQueue.remove(index);

      // and complete with null
      completer.complete(null);
    }
  }

  void _loadNextPreview() {
    if (_previewLoad < maxConcurrentPreviewLoad && _previewQueue.isNotEmpty) {
      _previewLoad++;
      if (useUrlToSaveMemory) {
        final index = _previewQueue.removeLast();
        final completer = _previewCompletersUrl.remove(index);
        if (completer != null) {
          get(index).then(_loadPreviewImageGif).then((gif) {
            if (!completer.isCompleted) {
              completer.complete(gif);
            }
          }).whenComplete(() {
            _previewLoad--;
            _loadNextPreview();
          });
        } else {
          _previewLoad--;
        }

        _loadNextPreview();
      } else {
        final index = _previewQueue.removeLast();
        final completer = _previewCompleters.remove(index);
        if (completer != null) {
          get(index).then(_loadPreviewImage).then((bytes) {
            if (!completer.isCompleted) {
              completer.complete(bytes);
            }
          }).whenComplete(() {
            _previewLoad--;
            _loadNextPreview();
          });
        } else {
          _previewLoad--;
        }

        _loadNextPreview();
      }
    }
  }

  String? getUrl(GiphyGif gif, {bool justUrl = false}) {
    String? url;
    switch (previewType) {
      case GiphyPreviewType.fixedWidthSmallStill:
        url = gif.images.fixedWidthSmallStill?.url;
        break;
      case GiphyPreviewType.previewGif:
        url = gif.images.previewGif?.url;
        break;
      case GiphyPreviewType.fixedHeight:
        url = gif.images.fixedHeight?.url;
        break;
      case GiphyPreviewType.fixedWidth:
        url = gif.images.fixedWidth?.webp;
        break;
      case GiphyPreviewType.original:
        url = gif.images.original?.url;
        break;
      case GiphyPreviewType.previewWebp:
        url = gif.images.previewWebp?.url;
        break;
      case GiphyPreviewType.downsizedLarge:
        url = gif.images.downsizedLarge?.url;
        break;
      case GiphyPreviewType.originalStill:
        url = gif.images.originalStill?.url;
        break;
      default:
        url = null;
        break;
    }
    if (justUrl) {
      url ??= gif.images.fixedWidth?.webp ??
          gif.images.fixedWidthSmallStill?.url ??
          gif.images.fixedHeightDownsampled?.webp ??
          gif.images.original?.webp;
    } else {
      url ??= gif.images.previewGif?.url ??
          gif.images.fixedWidthSmallStill?.url ??
          gif.images.fixedHeightDownsampled?.url ??
          gif.images.original?.url;
    }
    return url;
  }

  Future<Uint8List?> _loadPreviewImage(GiphyGif gif) async {
    // fallback to still image if preview is empty

    final url = getUrl(gif);

    if (url != null) {
      return await GiphyRenderImage.load(url, client: _client);
    }

    return null;
  }

  GiphyGif _loadPreviewImageGif(GiphyGif gif) {
    // fallback to still image if preview is empty

    //// final url = getUrl(gif, justUrl: true);
    /// return url;
    return gif;
  }

  /// The repository of trending gif images.
  static Future<GiphyRepository> trending({
    required String apiKey,
    String rating = GiphyRating.g,
    bool sticker = false,
    ErrorListener? onError,
    GiphyPreviewType? previewType,
    bool useUrlToSaveMemory = false,
  }) async {
    final repo = GiphyRepository(
        useUrlToSaveMemory: useUrlToSaveMemory,
        apiKey: apiKey,
        previewType: previewType,
        getCollection: (client, offset, limit) => client.trending(
            offset: offset, limit: limit, rating: rating, sticker: sticker),
        onError: onError);

    // retrieve first page
    await repo.get(0);

    return repo;
  }

  /// A repository of images for given search query.
  static Future<GiphyRepository> search(
      {required String apiKey,
      required String query,
      String rating = GiphyRating.g,
      String lang = GiphyLanguage.english,
      bool sticker = false,
      GiphyPreviewType? previewType,
      ErrorListener? onError}) async {
    final repo = GiphyRepository(
        apiKey: apiKey,
        previewType: previewType,
        getCollection: (client, offset, limit) => client.search(query,
            offset: offset,
            limit: limit,
            rating: rating,
            lang: lang,
            sticker: sticker),
        onError: onError);

    // retrieve first page
    await repo.get(0);

    return repo;
  }
}
