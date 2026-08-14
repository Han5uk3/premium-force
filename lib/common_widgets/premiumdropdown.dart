import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Dropdown whose menu opens directly below the field.
///
/// Material's [DropdownButton] overlays its menu *on top of* the button,
/// aligning the selected row with it, which hides the field the user is
/// answering. This uses a [MenuAnchor] anchored to the field's bottom edge
/// instead, with the menu constrained to the field's own width. A long list
/// (e.g. 1–24 hours) scrolls inside [_menuMaxHeight] rather than running off
/// the screen.
class PremiumDropDown extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final String? hint;
  final Map<String, String>? itemImages;

  const PremiumDropDown({
    super.key,
    required this.title,
    this.items = const [],
    this.value,
    this.onChanged,
    this.hint,
    this.itemImages,
  });

  @override
  State<PremiumDropDown> createState() => _PremiumDropDownState();
}

class _PremiumDropDownState extends State<PremiumDropDown> {
  static const double _fieldMinHeight = 60;
  static const double _itemMinHeight = 48;
  static const double _menuMaxHeight = 320;
  static const double _horizontalPadding = 16;
  static const double _radius = 8;

  final MenuController _menuController = MenuController();
  String? _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.value;
  }

  @override
  void didUpdateWidget(PremiumDropDown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _selectedValue = widget.value;
    }
  }

  void _select(String item) {
    setState(() => _selectedValue = item);
    widget.onChanged?.call(item);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.items.contains(_selectedValue)
        ? _selectedValue
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title.isNotEmpty) ...[
          Text(
            widget.title,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(height: 8),
        ],
        // The menu is sized from the field, so the field's width has to be
        // measured before the menu can be built.
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            return MenuAnchor(
              controller: _menuController,
              // Left-aligned under the field. MenuAnchor's own default is
              // `topEnd` — beside the anchor, which is submenu behaviour.
              alignmentOffset: const Offset(0, 4),
              consumeOutsideTap: true,
              style: MenuStyle(
                alignment: AlignmentDirectional.bottomStart,
                backgroundColor: const WidgetStatePropertyAll(Colors.black),
                surfaceTintColor: const WidgetStatePropertyAll(
                  Colors.transparent,
                ),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(vertical: 4),
                ),
                maximumSize: WidgetStatePropertyAll(
                  Size(width, _menuMaxHeight),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_radius),
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              menuChildren: [
                for (final item in widget.items) _buildMenuItem(item, width),
              ],
              builder: (context, controller, _) =>
                  _buildField(controller, selected),
            );
          },
        ),
      ],
    );
  }

  /// The closed field: what the old button looked like, made tappable.
  Widget _buildField(MenuController controller, String? selected) {
    final imageUrl = selected == null ? null : widget.itemImages?[selected];

    return Material(
      color: Colors.black,
      borderRadius: BorderRadius.circular(_radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(_radius),
        // Nothing to show for an empty list, so the field stays inert.
        onTap: widget.items.isEmpty
            ? null
            : () => controller.isOpen ? controller.close() : controller.open(),
        child: Container(
          constraints: const BoxConstraints(minHeight: _fieldMinHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: _horizontalPadding,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty) ...[
                _buildThumbnail(imageUrl),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  selected ?? widget.hint ?? '',
                  style: TextStyle(
                    color: selected == null ? Colors.white54 : Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  /// One menu row, sized to [width] so the menu is never wider than the field.
  Widget _buildMenuItem(String item, double width) {
    final imageUrl = widget.itemImages?[item];

    return MenuItemButton(
      onPressed: () => _select(item),
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(width, _itemMinHeight)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: _horizontalPadding),
        ),
        backgroundColor: WidgetStatePropertyAll(
          item == _selectedValue ? Colors.white10 : Colors.transparent,
        ),
      ),
      child: SizedBox(
        // Padding is on the button, so the row fills what is left of the field.
        width: width - _horizontalPadding * 2,
        child: Row(
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              _buildThumbnail(imageUrl),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                item,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(String imageUrl) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(4),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.contain,
        // 32pt thumbnail at 3x.
        memCacheWidth: 100,
        placeholder: (context, url) => Container(color: Colors.grey.shade800),
        errorWidget: (context, url, error) =>
            const Icon(Icons.directions_car, size: 20, color: Colors.black),
      ),
    );
  }
}
