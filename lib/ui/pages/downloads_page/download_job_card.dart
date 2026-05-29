import 'package:flutter/material.dart';
import 'package:senpwai/downloads/models.dart';
import 'package:senpwai/ui/pages/downloads_page/active_download_card.dart';
import 'package:senpwai/ui/pages/downloads_page/history_download_card.dart';

class DownloadJobCard extends StatelessWidget {
  final DownloadQueueItem item;

  const DownloadJobCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.status.isTerminal) {
      return HistoryDownloadCard(item: item);
    }
    return ActiveDownloadCard(item: item);
  }
}
