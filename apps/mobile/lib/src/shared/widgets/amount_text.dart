import 'package:flutter/material.dart';

class LargeAmountText extends StatelessWidget {
  const LargeAmountText(
    this.text, {
    super.key,
    this.semanticLabel,
    this.textAlign,
    this.style,
    this.maxLines = 1,
  });

  final String text;
  final String? semanticLabel;
  final TextAlign? textAlign;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStyle =
        style ??
        theme.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
          height: 1,
        );
    final textWidget = Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: effectiveStyle,
    );
    final fitted = Align(
      alignment: switch (textAlign) {
        TextAlign.center => Alignment.center,
        TextAlign.right || TextAlign.end => Alignment.centerRight,
        _ => Alignment.centerLeft,
      },
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: switch (textAlign) {
          TextAlign.center => Alignment.center,
          TextAlign.right || TextAlign.end => Alignment.centerRight,
          _ => Alignment.centerLeft,
        },
        child: textWidget,
      ),
    );

    if (semanticLabel == null) return fitted;

    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(child: fitted),
    );
  }
}
