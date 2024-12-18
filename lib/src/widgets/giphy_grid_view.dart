// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'package:modal_gif_picker/src/model/giphy_repository.dart';
import 'package:modal_gif_picker/src/widgets/giphy_context.dart';
import 'package:modal_gif_picker/src/widgets/giphy_image_thumbnail.dart';

/// A selectable grid view of gif thumbnails.
class GiphyGridView extends StatelessWidget {
  final GiphyRepository repo;
  bool useUrlToSaveMemory;

  /// added scroll controller
  final ScrollController? scrollController;
  int crossAxisCount;
  double childAspectRatio;
  double crossAxisSpacing;
  double mainAxisSpacing;

  GiphyGridView({
    Key? key,
    required this.repo,
    this.scrollController,
    this.childAspectRatio = 1.6,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 5,
    this.mainAxisSpacing = 5,
    this.useUrlToSaveMemory = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
        //  addAutomaticKeepAlives: true,
        padding: const EdgeInsets.all(10),
        controller: scrollController,
        itemCount: repo.totalCount,
        //   shrinkWrap: true,
        physics: BouncingScrollPhysics(),
        itemBuilder: (BuildContext context, int index) => GestureDetector(
            child: GiphyImageThumbnail(
                useUrlToSaveMemory: useUrlToSaveMemory,
                key: Key('$index'),
                repo: repo,
                index: index),
            onTap: () async {
              final giphy = GiphyContext.of(context);
              final gif = await repo.get(index);
              giphy.onSelected?.call(gif);
            }),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing));
  }
}
