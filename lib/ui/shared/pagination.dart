import 'package:flutter/material.dart';

mixin PaginatedScrollMixin<T extends StatefulWidget> on State<T> {
  ScrollController get paginationScrollController;
  bool get isLoadingMore;
  bool get hasNextPage;
  double get scrollThreshold => 300;

  void initPaginatedScroll() {
    paginationScrollController.addListener(_checkScroll);
  }

  void disposePaginatedScroll() {
    paginationScrollController.removeListener(_checkScroll);
  }

  void _checkScroll() {
    if (isLoadingMore || !hasNextPage) return;
    final pos = paginationScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - scrollThreshold) {
      loadNextPage();
    }
  }

  Future<void> loadNextPage();
}
