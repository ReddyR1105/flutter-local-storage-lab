import 'package:flutter/material.dart';

import 'database_helper.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key, required this.helper});
  final DatabaseHelper helper;
  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  int? _count;
  int? _selectedId;
  bool _busy = false;
  String? _readError;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  // Called while one action owns _busy. A failed read retains the last
  // successfully loaded roster instead of presenting a false empty state.
  Future<void> _loadRows() async {
    final rows = await widget.helper.queryAllRows();
    final count = await widget.helper.queryRowCount();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _count = count;
      _readError = null;
    });
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _loadRows();
      if (mounted) {
        setState(() => _feedback = 'Roster refreshed from local storage.');
      }
    } catch (error, stackTrace) {
      debugPrint('Roster read failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _readError =
            'Could not read the roster. Tap Refresh to retry. '
            'Any displayed records are from the last successful read.';
        _feedback = null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearForm() {
    _selectedId = null;
    _nameController.clear();
    _ageController.clear();
    _formKey.currentState?.reset();
  }

  // A read retry never repeats a completed write.
  Future<void> _reloadAfterWrite(String result) async {
    try {
      await _loadRows();
      if (mounted) setState(() => _feedback = result);
    } catch (error, stackTrace) {
      debugPrint('Refresh after write failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _feedback = '$result But refresh failed. Tap Refresh to retry.';
        _readError = 'The displayed roster may be out of date.';
      });
    }
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final selectedId = _selectedId;
    final values = <String, dynamic>{
      DatabaseHelper.columnName: _nameController.text.trim(),
      DatabaseHelper.columnAge: int.parse(_ageController.text.trim()),
    };
    setState(() => _busy = true);
    try {
      String result;
      if (selectedId == null) {
        final id = await widget.helper.insert(values);
        result = 'Saved guest ID $id.';
        if (!mounted) return;
        setState(_clearForm);
      } else {
        final affected = await widget.helper.update({
          ...values,
          DatabaseHelper.columnId: selectedId,
        });
        if (!mounted) return;
        if (affected == 1) {
          result = 'Saved ID $selectedId. Updated 1 row.';
          setState(_clearForm);
        } else if (affected == 0) {
          result =
              'ID $selectedId no longer exists. Updated 0 rows. '
              'Cancel edit to add a new guest.';
        } else {
          result = 'Unexpected update result: $affected rows. Check the logs.';
          debugPrint(result);
        }
      }
      await _reloadAfterWrite(result);
    } catch (error, stackTrace) {
      debugPrint('Save failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(
        () => _feedback =
            'Could not save. Your input is preserved. '
            'Check the logs, then retry Save or Add.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _edit(Map<String, dynamic> row) {
    if (_busy) return;
    setState(() {
      _formKey.currentState?.reset();
      _selectedId = row[DatabaseHelper.columnId] as int;
      _nameController.text = row[DatabaseHelper.columnName] as String;
      _ageController.text = '${row[DatabaseHelper.columnAge]}';
      _feedback = 'Editing ID $_selectedId. Save writes; Cancel edit does not.';
    });
  }

  void _cancelEdit() {
    if (_busy) return;
    setState(() {
      _clearForm();
      _feedback = 'Edit canceled. No database changes.';
    });
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final id = row[DatabaseHelper.columnId] as int;
    final name = row[DatabaseHelper.columnName] as String;
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete guest?'),
          content: Text('Delete ID $id: $name? This removes the saved record.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (confirmed != true) {
        setState(() => _feedback = 'Deletion canceled for ID $id. No changes.');
        return;
      }
      final affected = await widget.helper.delete(id);
      if (!mounted) return;
      String result;
      if (affected == 1) {
        result = 'Deleted ID $id. Deleted 1 row.';
        if (_selectedId == id) setState(_clearForm);
      } else if (affected == 0) {
        result = 'ID $id no longer exists. Deleted 0 rows.';
      } else {
        result = 'Unexpected deletion result: $affected rows. Check the logs.';
        debugPrint(result);
      }
      await _reloadAfterWrite(result);
    } catch (error, stackTrace) {
      debugPrint('Delete failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(
        () => _feedback =
            'Could not delete ID $id. '
            'Check the logs, Refresh the roster, then retry.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fall Festival Roster')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _selectedId == null
                ? 'Register a guest'
                : 'Editing guest ID $_selectedId',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter a nonempty name.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ageController,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Age (0–130)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  validator: (value) {
                    final age = int.tryParse((value ?? '').trim());
                    if (age == null) return 'Enter a whole-number age.';
                    if (age < 0 || age > 130) {
                      return 'Age must be from 0 through 130.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_selectedId == null ? 'Add' : 'Save'),
              ),
              if (_selectedId != null)
                OutlinedButton(
                  onPressed: _busy ? null : _cancelEdit,
                  child: const Text('Cancel edit'),
                ),
              OutlinedButton(
                onPressed: _busy ? null : _refresh,
                child: const Text('Refresh'),
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const Text('Working with local storage…'),
          ],
          if (_feedback != null) ...[
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Text(_feedback!)),
          ],
          if (_readError != null) ...[
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Text(_readError!)),
          ],
          const Divider(height: 32),
          Text(
            _count == null
                ? 'Record count: unavailable'
                : 'Record count: $_count',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (!_busy && _readError == null && _count == 0)
            const Text('No festival guests yet'),
          for (final row in _rows)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ID ${row[DatabaseHelper.columnId]}: ${row[DatabaseHelper.columnName]} — age ${row[DatabaseHelper.columnAge]}',
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _busy ? null : () => _edit(row),
                          child: const Text('Edit'),
                        ),
                        TextButton(
                          onPressed: _busy ? null : () => _delete(row),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
