import 'package:flutter/material.dart';
import '../main.dart';
import '../models/models.dart';

class TrackDownloadCard extends StatelessWidget {
  final DownloadItem item;

  const TrackDownloadCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _borderColor,
          width: item.status == DownloadStatus.completed ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusIcon(status: item.status),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.filename,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle,
                      style: TextStyle(
                        color: _subtitleColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.status == DownloadStatus.completed)
                const Icon(Icons.check_circle_rounded,
                    color: AppTheme.accentGreen, size: 20),
              if (item.status == DownloadStatus.failed)
                const Icon(Icons.error_rounded,
                    color: Colors.redAccent, size: 20),
            ],
          ),
          if (item.status == DownloadStatus.downloading) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: item.progress,
                backgroundColor: AppTheme.borderColor,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentGreen),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatBytes(item.receivedBytes)} / ${_formatBytes(item.totalBytes)}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 10),
                ),
                Text(
                  '${(item.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: AppTheme.accentGreen, fontSize: 10),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color get _borderColor {
    switch (item.status) {
      case DownloadStatus.completed:
        return AppTheme.accentGreen.withValues(alpha: 0.4);
      case DownloadStatus.failed:
        return Colors.redAccent.withValues(alpha: 0.4);
      case DownloadStatus.downloading:
        return AppTheme.accentCyan.withValues(alpha: 0.3);
      default:
        return AppTheme.borderColor;
    }
  }

  String get _subtitle {
    switch (item.status) {
      case DownloadStatus.pending:
        return 'Waiting...';
      case DownloadStatus.downloading:
        return 'Downloading...';
      case DownloadStatus.completed:
        return '✓ Saved to ${item.savePath}';
      case DownloadStatus.failed:
        return item.errorMessage ?? 'Download failed';
      case DownloadStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get _subtitleColor {
    switch (item.status) {
      case DownloadStatus.completed:
        return AppTheme.accentGreen;
      case DownloadStatus.failed:
        return Colors.redAccent;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return '--';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class _StatusIcon extends StatelessWidget {
  final DownloadStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    bool animated = false;

    switch (status) {
      case DownloadStatus.pending:
        icon = Icons.hourglass_empty_rounded;
        color = AppTheme.textSecondary;
        break;
      case DownloadStatus.downloading:
        icon = Icons.download_rounded;
        color = AppTheme.accentCyan;
        animated = true;
        break;
      case DownloadStatus.completed:
        icon = Icons.audio_file_rounded;
        color = AppTheme.accentGreen;
        break;
      case DownloadStatus.failed:
        icon = Icons.error_outline_rounded;
        color = Colors.redAccent;
        break;
      case DownloadStatus.cancelled:
        icon = Icons.cancel_outlined;
        color = AppTheme.textSecondary;
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: animated
          ? _AnimatedDownloadIcon(color: color)
          : Icon(icon, color: color, size: 20),
    );
  }
}

class _AnimatedDownloadIcon extends StatefulWidget {
  final Color color;

  const _AnimatedDownloadIcon({required this.color});

  @override
  State<_AnimatedDownloadIcon> createState() => _AnimatedDownloadIconState();
}

class _AnimatedDownloadIconState extends State<_AnimatedDownloadIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Icon(
        Icons.download_rounded,
        color: widget.color.withValues(alpha: 0.5 + _ctrl.value * 0.5),
        size: 20,
      ),
    );
  }
}
