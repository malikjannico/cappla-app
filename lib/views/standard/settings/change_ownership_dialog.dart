// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../../models/org_unit_model.dart';

class ChangeOwnershipDialog extends StatefulWidget {
  final String title;
  final String currentOwnerId;
  final List<OrgUnitModel> orgUnits;
  final ValueChanged<OrgUnitModel> onConfirm;

  const ChangeOwnershipDialog({
    super.key,
    required this.title,
    required this.currentOwnerId,
    required this.orgUnits,
    required this.onConfirm,
  });

  @override
  State<ChangeOwnershipDialog> createState() => _ChangeOwnershipDialogState();
}

class _ChangeOwnershipDialogState extends State<ChangeOwnershipDialog> {
  String _searchQuery = '';
  OrgUnitModel? _selectedOrg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final eligibleOrgs = widget.orgUnits.where((org) {
      if (org.id == widget.currentOwnerId) return false;
      final query = _searchQuery.trim().toLowerCase();
      if (query.isEmpty) return true;
      return org.name.toLowerCase().contains(query) ||
          org.abbreviation.toLowerCase().contains(query);
    }).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(widget.title),
      content: SizedBox(
        width: 450,
        height: 400,
        child: Column(
          children: [
            TextField(
              key: const Key('ownership_modal_search_input'),
              decoration: InputDecoration(
                labelText: 'Search organization units',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: eligibleOrgs.isEmpty
                  ? const Center(child: Text('No organization units found.'))
                  : ListView.builder(
                      itemCount: eligibleOrgs.length,
                      itemBuilder: (context, index) {
                        final org = eligibleOrgs[index];
                        return RadioListTile<OrgUnitModel>(
                          key: Key('ownership_modal_org_radio_${org.id}'),
                          title: Text('${org.name} (${org.abbreviation})'),
                          value: org,
                          groupValue: _selectedOrg,
                          activeColor: theme.colorScheme.primary,
                          onChanged: (val) {
                            setState(() {
                              _selectedOrg = val;
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('ownership_modal_confirm_button'),
          onPressed: _selectedOrg != null
              ? () {
                  widget.onConfirm(_selectedOrg!);
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
