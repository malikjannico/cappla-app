import 'package:flutter/material.dart';

class HoverCell extends StatefulWidget {
  final double width;
  final double height;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final String? tooltip;
  final Decoration? decoration;
  final MouseCursor? cursor;
  final PointerDownEventListener? onPointerDown;
  final PointerMoveEventListener? onPointerMove;
  final PointerUpEventListener? onPointerUp;
  final GestureTapDownCallback? onSecondaryTapDown;
  final VoidCallback? onHoverEnter;
  final GestureDragStartCallback? onPanStart;
  final GestureDragUpdateCallback? onPanUpdate;
  final GestureDragEndCallback? onPanEnd;

  const HoverCell({
    super.key,
    required this.width,
    required this.height,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.tooltip,
    this.decoration,
    this.cursor,
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
    this.onSecondaryTapDown,
    this.onHoverEnter,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
  });

  @override
  State<HoverCell> createState() => HoverCellState();
}

class HoverCellState extends State<HoverCell> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Decoration combinedDecoration = widget.decoration ?? const BoxDecoration();
    if (_isHovered) {
      if (combinedDecoration is BoxDecoration) {
        combinedDecoration = combinedDecoration.copyWith(
          color:
              (combinedDecoration.color ?? Colors.transparent).withValues(
                    alpha: 0.24,
                  ) ==
                  Colors.transparent
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.12)
              : Color.alphaBlend(
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.12),
                  combinedDecoration.color ?? Colors.transparent,
                ),
        );
      }
    }

    Widget cell = MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        widget.onHoverEnter?.call();
      },
      onExit: (_) => setState(() => _isHovered = false),
      cursor:
          widget.cursor ??
          (widget.onTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.text),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: combinedDecoration,
        child: widget.child,
      ),
    );

    if (widget.onPointerDown != null ||
        widget.onPointerMove != null ||
        widget.onPointerUp != null) {
      cell = Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: widget.onPointerDown,
        onPointerMove: widget.onPointerMove,
        onPointerUp: widget.onPointerUp,
        child: cell,
      );
    }

    if (widget.onPanStart != null ||
        widget.onTap != null ||
        widget.onDoubleTap != null ||
        widget.onSecondaryTapDown != null) {
      cell = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onPanStart: widget.onPanStart,
        onPanUpdate: widget.onPanUpdate,
        onPanEnd: widget.onPanEnd,
        onSecondaryTapDown: widget.onSecondaryTapDown,
        child: cell,
      );
    }

    if (widget.tooltip != null) {
      cell = Tooltip(message: widget.tooltip!, child: cell);
    }

    return cell;
  }
}
