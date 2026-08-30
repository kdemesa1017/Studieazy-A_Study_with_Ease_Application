import 'package:flutter/material.dart';

enum SweetAlertType {
  success,
  warning,
  error,
  info,
  confirm,
}

class SweetAlert extends StatefulWidget {
  final SweetAlertType type;
  final String title;
  final String? subtitle;
  final Widget? customContent;
  final String confirmButtonText;
  final String? cancelButtonText;
  final Color? confirmButtonColor;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool showCancelButton;

  const SweetAlert({
    super.key,
    required this.type,
    required this.title,
    this.subtitle,
    this.customContent,
    this.confirmButtonText = 'OK',
    this.cancelButtonText = 'Cancel',
    this.confirmButtonColor,
    this.onConfirm,
    this.onCancel,
    this.showCancelButton = false,
  });

  /// Static helper for showing a Success alert
  static Future<bool?> showSuccess(
    BuildContext context, {
    required String title,
    String? subtitle,
    String confirmButtonText = 'OK',
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SweetAlert(
        type: SweetAlertType.success,
        title: title,
        subtitle: subtitle,
        confirmButtonText: confirmButtonText,
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
  }

  /// Static helper for showing an Error alert
  static Future<bool?> showError(
    BuildContext context, {
    required String title,
    String? subtitle,
    String confirmButtonText = 'OK',
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SweetAlert(
        type: SweetAlertType.error,
        title: title,
        subtitle: subtitle,
        confirmButtonText: confirmButtonText,
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
  }

  /// Static helper for showing a Warning alert
  static Future<bool?> showWarning(
    BuildContext context, {
    required String title,
    String? subtitle,
    Widget? customContent,
    String confirmButtonText = 'Proceed',
    String cancelButtonText = 'Cancel',
    Color? confirmButtonColor,
    bool showCancelButton = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SweetAlert(
        type: SweetAlertType.warning,
        title: title,
        subtitle: subtitle,
        customContent: customContent,
        confirmButtonText: confirmButtonText,
        cancelButtonText: cancelButtonText,
        confirmButtonColor: confirmButtonColor,
        showCancelButton: showCancelButton,
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  /// Static helper for showing a Confirm/Danger alert
  static Future<bool?> showConfirm(
    BuildContext context, {
    required String title,
    String? subtitle,
    Widget? customContent,
    String confirmButtonText = 'Yes, do it!',
    String cancelButtonText = 'Cancel',
    Color? confirmButtonColor,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SweetAlert(
        type: SweetAlertType.confirm,
        title: title,
        subtitle: subtitle,
        customContent: customContent,
        confirmButtonText: confirmButtonText,
        cancelButtonText: cancelButtonText,
        confirmButtonColor: confirmButtonColor ?? Colors.redAccent,
        showCancelButton: true,
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  @override
  State<SweetAlert> createState() => _SweetAlertState();
}

class _SweetAlertState extends State<SweetAlert> with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _iconScaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutBack,
    );
    _iconScaleAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Color get _primaryColor {
    switch (widget.type) {
      case SweetAlertType.success:
        return const Color(0xFF10B981); // Emerald
      case SweetAlertType.warning:
        return const Color(0xFFF59E0B); // Amber
      case SweetAlertType.error:
        return const Color(0xFFEF4444); // Red
      case SweetAlertType.info:
        return const Color(0xFF3B82F6); // Blue
      case SweetAlertType.confirm:
        return widget.confirmButtonColor ?? const Color(0xFFEF4444);
    }
  }

  Widget _buildAnimatedIcon() {
    IconData iconData;
    switch (widget.type) {
      case SweetAlertType.success:
        iconData = Icons.check_rounded;
        break;
      case SweetAlertType.warning:
        iconData = Icons.priority_high_rounded;
        break;
      case SweetAlertType.error:
        iconData = Icons.close_rounded;
        break;
      case SweetAlertType.info:
        iconData = Icons.info_outline_rounded;
        break;
      case SweetAlertType.confirm:
        iconData = Icons.warning_amber_rounded;
        break;
    }

    return ScaleTransition(
      scale: _iconScaleAnim,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _primaryColor.withValues(alpha: 0.12),
          border: Border.all(
            color: _primaryColor.withValues(alpha: 0.45),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Icon(
            iconData,
            color: _primaryColor,
            size: 44,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.grey.shade400 : const Color(0xFF64748B);

    return ScaleTransition(
      scale: _scaleAnim,
      child: Dialog(
        backgroundColor: dialogBg,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAnimatedIcon(),
                const SizedBox(height: 20),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                    letterSpacing: -0.3,
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    widget.subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: subtitleColor,
                    ),
                  ),
                ],
                if (widget.customContent != null) ...[
                  const SizedBox(height: 16),
                  widget.customContent!,
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (widget.showCancelButton) ...[
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            if (widget.onCancel != null) {
                              widget.onCancel!();
                            } else {
                              Navigator.of(context).pop(false);
                            }
                          },
                          child: Text(
                            widget.cancelButtonText ?? 'Cancel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: subtitleColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.confirmButtonColor ?? _primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          if (widget.onConfirm != null) {
                            widget.onConfirm!();
                          } else {
                            Navigator.of(context).pop(true);
                          }
                        },
                        child: Text(
                          widget.confirmButtonText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
