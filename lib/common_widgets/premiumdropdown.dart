import 'package:flutter/material.dart';

class PremiumDropDown extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final String? hint;

  const PremiumDropDown({
    super.key,
    required this.title,
    this.items = const [],
    this.value,
    this.onChanged,
    this.hint,
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
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 8),
        ],
        Container(
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
              dropdownColor: Colors.black, // dropdown menu background
              icon: const Icon(
                Icons.arrow_drop_down,
                color: Colors.white,
              ), // white icon
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ), // white texts
              onChanged: (String? newValue) {
                setState(() {
                  _selectedValue = newValue;
                });
                if (widget.onChanged != null) {
                  widget.onChanged!(newValue);
                }
              },
              items: widget.items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
