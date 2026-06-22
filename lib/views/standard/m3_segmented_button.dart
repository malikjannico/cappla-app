// File: lib/views/standard/m3_segmented_button.dart

import 'package:flutter/material.dart';

class M3SegmentedButton<T> extends StatelessWidget {
  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;
  final bool showSelectedIcon;
  final Key? segmentedButtonKey;
  final double height;

  const M3SegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.showSelectedIcon = true,
    this.segmentedButtonKey,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outlineColor = theme.colorScheme.outlineVariant;

    return SizedBox(
      height: height,
      child: Material(
        key: segmentedButtonKey,
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(height / 2),
          side: BorderSide(color: outlineColor, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(segments.length * 2 - 1, (index) {
            if (index.isOdd) {
              // Divider line between segments
              final segIndex = index ~/ 2;
              final leftSelected = selected.contains(segments[segIndex].value);
              final rightSelected = selected.contains(segments[segIndex + 1].value);
              if (leftSelected || rightSelected) {
                return const SizedBox(width: 0);
              }
              return Container(width: 1, color: outlineColor);
            }

            final segIndex = index ~/ 2;
            final segment = segments[segIndex];
            final isSelected = selected.contains(segment.value);

            return InkWell(
              onTap: segment.enabled
                  ? () => onSelectionChanged({segment.value})
                  : null,
              child: Ink(
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                child: Center(
                  widthFactor: 1.0,
                  heightFactor: 1.0,
                  child: Padding(
                    padding: isSelected && showSelectedIcon
                        ? EdgeInsets.symmetric(horizontal: 12, vertical: height == 32 ? 6 : 8)
                        : EdgeInsets.symmetric(horizontal: 16, vertical: height == 32 ? 6 : 8),
                    child: IconTheme.merge(
                      data: IconThemeData(
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                        size: 18,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected && showSelectedIcon) ...[
                            Icon(
                              Icons.check,
                              size: 18,
                              color: theme.colorScheme.onPrimary,
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (segment.icon != null) ...[
                            segment.icon!,
                            const SizedBox(width: 8),
                          ],
                          if (segment.label != null)
                            DefaultTextStyle(
                              style: theme.textTheme.labelLarge!.copyWith(
                                color: isSelected
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              child: segment.label!,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
