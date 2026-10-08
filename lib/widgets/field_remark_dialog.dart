import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class FieldRemarkDialog extends StatefulWidget {
  final bool isCheckOut;

  const FieldRemarkDialog({
    super.key,
    this.isCheckOut = false,
  });

  /// Static helper to show the dialog cleanly and return the entered remark string
  static Future<String?> show(BuildContext context, {bool isCheckOut = false}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FieldRemarkDialog(isCheckOut: isCheckOut),
    );
  }

  @override
  State<FieldRemarkDialog> createState() => _FieldRemarkDialogState();
}

class _FieldRemarkDialogState extends State<FieldRemarkDialog> {
  final _remarkController = TextEditingController();
  final _focusNode = FocusNode();
  String? _selectedChip;

  final List<String> _quickTags = [
    'Client Meeting',
    'Site Inspection',
    'Product Delivery',
    'Vendor Visit',
    'Emergency Work',
    'Other',
  ];

  @override
  void dispose() {
    _focusNode.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  void _onChipSelected(String tag) {
    setState(() {
      if (_selectedChip == tag) {
        _selectedChip = null;
      } else {
        _selectedChip = tag;
        if (tag == 'Other') {
          _remarkController.clear();
          FocusScope.of(context).requestFocus(_focusNode);
        } else {
          _remarkController.text = tag;
        }
      }
    });
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final text = _remarkController.text.trim();
    if (text.isNotEmpty) {
      Navigator.of(context).pop(text);
    } else if (_selectedChip != null && _selectedChip != 'Other') {
      Navigator.of(context).pop(_selectedChip);
    } else {
      final defaultRemark = widget.isCheckOut ? 'Work Completed at Location' : 'Field Visit';
      Navigator.of(context).pop(defaultRemark);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = widget.isCheckOut ? 'FIELD CHECK-OUT REMARK' : 'FIELD VISIT PURPOSE';
    final subtitleText = widget.isCheckOut
        ? 'Briefly describe work completed at this location:'
        : 'Select purpose or enter site/client details:';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    widget.isCheckOut ? Icons.edit_note_rounded : Icons.explore_rounded,
                    color: AppTheme.primaryOrange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.darkNavy,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Location Proof & Audit Log',
                        style: TextStyle(fontSize: 10, color: AppTheme.primaryOrange, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Text(
              subtitleText,
              style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            // Quick Purpose Choice Chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _quickTags.map((tag) {
                final isSelected = _selectedChip == tag;
                return ChoiceChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (_) => _onChipSelected(tag),
                  selectedColor: AppTheme.primaryOrange,
                  backgroundColor: Colors.grey[100],
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppTheme.darkNavy,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primaryOrange : Colors.grey.shade300,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Custom Text Field
            TextField(
              controller: _remarkController,
              focusNode: _focusNode,
              maxLines: 1,
              style: const TextStyle(fontSize: 13, color: AppTheme.darkNavy, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: widget.isCheckOut ? 'e.g., Completed site inspection at Unit 4' : 'e.g., Meeting Mr. Sharma at Sharma Traders',
                hintStyle: TextStyle(fontSize: 11, color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[50],
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.primaryOrange, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(color: AppTheme.secondaryText, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryOrange, AppTheme.secondaryOrange],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryOrange.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: _submit,
                        borderRadius: BorderRadius.circular(14),
                        child: const Center(
                          child: Text(
                            'PROCEED',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
