import 'package:flutter/material.dart';
import 'dart:ui';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? color;
  final Gradient? gradient;
  final Border? border;
  final double? blur;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.gradient,
    this.border,
    this.blur = 10.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Default border radius
    final radius = borderRadius ?? BorderRadius.circular(20);

    // Default frosting color if no gradient/color provided
    final baseColor = color ?? Colors.white.withOpacity(0.1);

    // Glass styling
    final decoration = BoxDecoration(
      borderRadius: radius,
      color: gradient == null ? baseColor : null,
      gradient: gradient,
      border: border ??
          Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: (color ?? Colors.black).withOpacity(0.1),
          blurRadius: 16,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
      ],
    );

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      decoration: decoration,
      child: child,
    );

    // Apply Blur (Frosted Effect)
    // Note: Use ClipRRect to constrain the blur to the container's shape
    content = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur!, sigmaY: blur!),
        child: content,
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}
