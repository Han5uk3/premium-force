import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
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
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedValue,
              hint: widget.hint != null
                  ? Text(
                      widget.hint!,
                      style: const TextStyle(color: Colors.white54),
                    )
                  : null,
              isExpanded: true,
              dropdownColor: Colors.black,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedValue = newValue;
                });
                if (widget.onChanged != null) {
                  widget.onChanged!(newValue);
                }
              },
              selectedItemBuilder: (BuildContext context) {
                return widget.items.map<Widget>((String item) {
                  final imageUrl = widget.itemImages?[item];
                  return Row(
                    children: [
                      if (imageUrl != null && imageUrl.isNotEmpty) ...[
                        _buildThumbnail(imageUrl),
                        const SizedBox(width: 12),
                      ],
                      Text(item, style: const TextStyle(color: Colors.white)),
                    ],
                  );
                }).toList();
              },
              items: widget.items.map((String item) {
                final imageUrl = widget.itemImages?[item];
                return DropdownMenuItem<String>(
                  value: item,
                  child: Row(
                    children: [
                      if (imageUrl != null && imageUrl.isNotEmpty) ...[
                        _buildThumbnail(imageUrl),
                        const SizedBox(width: 12),
                      ],
                      Text(item, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
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
        placeholder: (context, url) => Container(color: Colors.grey.shade800),
        errorWidget: (context, url, error) =>
            const Icon(Icons.directions_car, size: 20, color: Colors.black),
      ),
    );
  }
}

