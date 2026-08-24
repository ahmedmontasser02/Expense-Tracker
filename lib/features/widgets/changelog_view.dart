import 'package:flutter/material.dart';

/// Minimal, dependency-free renderer for the bundled CHANGELOG.md.
/// Supports the subset we author: `# Title`, `## version` headers,
/// `- bullet` items and plain paragraphs.
class ChangelogView extends StatelessWidget {
  const ChangelogView({
    super.key,
    required this.markdown,
    this.onlyVersion,
  });

  final String markdown;

  /// When set, only the section for this version is shown.
  final String? onlyVersion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = <Widget>[];
    var skip = onlyVersion != null;
    var currentVersionMatched = false;

    for (final rawLine in markdown.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('## ')) {
        final version = line.substring(3).trim();
        currentVersionMatched =
            onlyVersion == null || version == onlyVersion;
        if (onlyVersion != null && !currentVersionMatched) {
          // Stop once we leave the requested section (sections are ordered
          // newest first).
          if (blocks.isNotEmpty && version != onlyVersion) break;
        }
        if (onlyVersion != null && version == onlyVersion) skip = false;
        if (skip) continue;
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text('v$version',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ));
        continue;
      }
      if (line.startsWith('# ')) continue; // document title — redundant
      if (skip && onlyVersion != null) continue;

      if (line.startsWith('- ')) {
        blocks.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  '),
              Expanded(
                child: Text(line.substring(2).trim(),
                    style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
        ));
      } else {
        blocks.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(line, style: theme.textTheme.bodyMedium),
        ));
      }
    }

    if (blocks.isEmpty) {
      return Text('No notes for this version.',
          style: theme.textTheme.bodySmall);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }
}
