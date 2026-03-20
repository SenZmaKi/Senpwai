import 'package:flutter/material.dart';
import 'package:senpwai/anilist/anilist.dart';
import 'package:senpwai/ui/components/anime_card/card_switcher.dart';
import 'package:senpwai/ui/shared/responsive.dart';

class SearchToolbar extends StatelessWidget {
  final AnilistMediaSort? sort;
  final bool sortDescending;
  final bool sortDisabled;
  final CardViewMode viewMode;
  final AnimationController sortIconController;
  final ValueChanged<AnilistMediaSort?> onSortChanged;
  final VoidCallback onSortDirectionToggled;
  final ValueChanged<CardViewMode> onViewModeChanged;

  const SearchToolbar({
    super.key,
    required this.sort,
    required this.sortDescending,
    required this.sortDisabled,
    required this.viewMode,
    required this.sortIconController,
    required this.onSortChanged,
    required this.onSortDirectionToggled,
    required this.onViewModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Opacity(
            opacity: sortDisabled ? 0.5 : 1.0,
            child: IgnorePointer(
              ignoring: sortDisabled,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 100,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<AnilistMediaSort?>(
                        value: sort,
                        isExpanded: true,
                        isDense: true,
                        icon: Icon(
                          Icons.unfold_more,
                          size: 16,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        hint: Text(
                          'Sort by',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                            fontSize: isMobile(context) ? 11 : null,
                          ),
                        ),
                        items: AnilistMediaSort.values
                            .map(
                              (sort) => DropdownMenuItem<AnilistMediaSort?>(
                                value: sort,
                                child: Text(
                                  sort.toLabel(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: isMobile(context) ? 11 : null,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: onSortChanged,
                        dropdownColor:
                            theme.colorScheme.surfaceContainerHighest,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: isMobile(context) ? 11 : null,
                        ),
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: sortDisabled ? 0.5 : 1.0,
                    child: IgnorePointer(
                      ignoring: sortDisabled,
                      child: IconButton(
                        constraints: const BoxConstraints.tightFor(
                          width: 30,
                          height: 30,
                        ),
                        padding: EdgeInsets.zero,
                        icon: AnimatedBuilder(
                          animation: sortIconController,
                          builder: (context, child) => Transform.rotate(
                            angle: sortIconController.value * 3.14159,
                            child: child,
                          ),
                          child: Icon(
                            sortDescending
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            size: 18,
                          ),
                        ),
                        tooltip: sortDescending ? 'Descending' : 'Ascending',
                        onPressed: onSortDirectionToggled,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        CardSwitcher(selected: viewMode, onSwitch: onViewModeChanged),
      ],
    );
  }
}
