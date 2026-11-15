import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/glossary_item.dart';

/// Expandable glossary term card shared by the Info feed and `/glossary`.
class GlossaryExpandableCard extends StatefulWidget {
  final GlossaryItem item;

  const GlossaryExpandableCard({super.key, required this.item});

  @override
  State<GlossaryExpandableCard> createState() => _GlossaryExpandableCardState();
}

class _GlossaryExpandableCardState extends State<GlossaryExpandableCard> {
  static const _animDuration = Duration(milliseconds: 280);
  static const _animCurve = Curves.easeOutCubic;

  bool _expanded = false;
  bool _pressed = false;

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
  }

  String get _monogram {
    final raw = widget.item.title.trim();
    if (raw.isEmpty) return '·';
    return raw.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final shadows = _expanded
        ? AppShadows.cardPremium
        : const [
            BoxShadow(
              color: Color(0x07000000),
              blurRadius: 12,
              spreadRadius: -2,
              offset: Offset(0, 5),
            ),
          ];

    final borderColor = AppColors.border.withValues(
      alpha: _expanded ? 0.0 : 0.5,
    );

    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.987 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: AnimatedContainer(
          duration: _animDuration,
          curve: _animCurve,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: shadows,
            border: Border.all(color: borderColor, width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md + 2,
                  AppSpacing.md + 2,
                  AppSpacing.md,
                  AppSpacing.md + 2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CardHeaderRow(
                      monogram: _monogram,
                      title: widget.item.title,
                      expanded: _expanded,
                      animDuration: _animDuration,
                      animCurve: _animCurve,
                    ),
                    AnimatedSize(
                      duration: _animDuration,
                      curve: _animCurve,
                      alignment: Alignment.topLeft,
                      clipBehavior: Clip.none,
                      child: _expanded
                          ? _ExpandedBody(
                              key: const ValueKey('expanded'),
                              text: widget.item.description,
                            )
                          : _CollapsedPreview(
                              key: const ValueKey('collapsed'),
                              text: widget.item.description,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardHeaderRow extends StatelessWidget {
  final String monogram;
  final String title;
  final bool expanded;
  final Duration animDuration;
  final Curve animCurve;

  const _CardHeaderRow({
    required this.monogram,
    required this.title,
    required this.expanded,
    required this.animDuration,
    required this.animCurve,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _MonogramChip(letter: monogram, expanded: expanded),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary.withValues(alpha: 0.94),
              height: 1.2,
              letterSpacing: -0.25,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _ExpandIndicator(
          expanded: expanded,
          animDuration: animDuration,
          animCurve: animCurve,
        ),
      ],
    );
  }
}

class _MonogramChip extends StatelessWidget {
  final String letter;
  final bool expanded;

  const _MonogramChip({required this.letter, required this.expanded});

  static const _size = 36.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceWarm, AppColors.creamSubtle],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md - 2),
        border: Border.all(
          color: AppColors.textPrimary.withValues(
            alpha: expanded ? 0.14 : 0.08,
          ),
          width: 0.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary.withValues(alpha: 0.78),
          height: 1.0,
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}

class _ExpandIndicator extends StatelessWidget {
  final bool expanded;
  final Duration animDuration;
  final Curve animCurve;

  const _ExpandIndicator({
    required this.expanded,
    required this.animDuration,
    required this.animCurve,
  });

  static const _size = 28.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: animDuration,
      curve: animCurve,
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.textPrimary.withValues(alpha: expanded ? 0.06 : 0.0),
      ),
      alignment: Alignment.center,
      child: AnimatedRotation(
        turns: expanded ? 0.5 : 0.0,
        duration: animDuration,
        curve: animCurve,
        child: Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 20,
          color: AppColors.textSecondary.withValues(
            alpha: expanded ? 0.92 : 0.7,
          ),
        ),
      ),
    );
  }
}

class _CollapsedPreview extends StatelessWidget {
  final String text;

  const _CollapsedPreview({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        left: 36 + AppSpacing.md,
        right: AppSpacing.sm,
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: AppColors.textSecondary.withValues(alpha: 0.85),
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _ExpandedBody extends StatelessWidget {
  final String text;

  const _ExpandedBody({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 2),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg - 2,
          AppSpacing.md + 2,
          AppSpacing.lg - 2,
          AppSpacing.md + 4,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceWarm,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.68,
            color: AppColors.textPrimary.withValues(alpha: 0.82),
            fontWeight: FontWeight.w400,
            letterSpacing: 0.08,
          ),
        ),
      ),
    );
  }
}
