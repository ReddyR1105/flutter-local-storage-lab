import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'card_repository.dart';
import 'legacy_roster.dart';
import 'models.dart';

String writeError(Object error) {
  if (error is DatabaseException && error.isUniqueConstraintError()) {
    return 'That folder name already exists. Choose another name.';
  }
  if (error is DatabaseException &&
      error.toString().contains('FOREIGN KEY constraint failed')) {
    return 'The selected folder no longer exists. Choose another folder.';
  }
  return 'Could not save. Your input is kept. Check the logs and retry.';
}

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key, required this.repository});
  final CardRepository repository;
  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  List<Folder> _folders = [];
  bool _busy = false;
  bool _loaded = false;
  String? _feedback;
  String? _error;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _load(String? result) async {
    try {
      final folders = await widget.repository.getFoldersWithCounts();
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _loaded = true;
        _error = null;
        _feedback = result;
      });
    } catch (error, stack) {
      debugPrint('Folder read failed: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _error = 'Could not refresh. Any displayed list is from the last successful read.';
        _feedback = result == null
            ? null
            : '$result Refresh failed; retry Refresh, not the write.';
      });
    }
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _load('Folders refreshed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([Folder? folder]) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            FolderEditor(repository: widget.repository, folder: folder),
      );
      if (!mounted) return;
      if (result != null) await _load(result);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFolder(Folder folder) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CardsScreen(repository: widget.repository, folder: folder),
        ),
      );
      if (mounted) await _load(null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Folder folder) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete folder?'),
          content: Text(
            'Delete "${folder.name}" (ID ${folder.id}) and its ${folder.cardCount} cards? This cannot be undone.',
          ),
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
      if (yes != true) {
        setState(() => _feedback = 'Folder deletion canceled. No changes.');
        return;
      }
      final affected = await widget.repository.deleteFolder(folder.id!);
      if (mounted) {
        await _load(
          affected == 1
              ? 'Deleted folder ID ${folder.id} and its cards. Deleted 1 folder row.'
              : 'Folder ID ${folder.id} no longer exists. Deleted $affected rows.',
        );
      }
    } catch (error, stack) {
      debugPrint('Folder delete failed: $error\n$stack');
      if (mounted) {
        setState(
          () => _feedback =
              'Could not delete the folder. Refresh before retrying.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Card Catalogue'),
      actions: [
        IconButton(
          tooltip: 'Part I roster',
          onPressed: _busy
              ? null
              : () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        DirectoryScreen(helper: widget.repository.helper),
                  ),
                ),
          icon: const Icon(Icons.people_outline),
        ),
        IconButton(
          tooltip: 'Refresh folders',
          onPressed: _busy ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Folders',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const Text('Choose a folder to view its cards.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : () => _edit(),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Add folder'),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_feedback != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Semantics(liveRegion: true, child: Text(_feedback!)),
            ),
          if (_error != null) Text(_error!),
          if (_loaded) Text('Folder count: ${_folders.length}'),
          if (_loaded && !_busy && _error == null && _folders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No folders yet. Add a folder to start your catalogue.',
              ),
            ),
          for (final folder in _folders)
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(folder.name),
                    subtitle: Text(
                      'Folder ID ${folder.id} • ${folder.cardCount} cards',
                    ),
                    onTap: _busy ? null : () => _openFolder(folder),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _busy ? null : () => _edit(folder),
                        child: Text('Edit folder ${folder.id}'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => _delete(folder),
                        child: Text('Delete folder ${folder.id}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class FolderEditor extends StatefulWidget {
  const FolderEditor({super.key, required this.repository, this.folder});
  final CardRepository repository;
  final Folder? folder;
  @override
  State<FolderEditor> createState() => _FolderEditorState();
}

class _FolderEditorState extends State<FolderEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.folder?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final folder = widget.folder;
      if (folder == null) {
        final id = await widget.repository.insertFolder(_name.text);
        if (mounted) Navigator.pop(context, 'Saved folder ID $id.');
      } else {
        final affected = await widget.repository.updateFolder(
          folder.id!,
          _name.text,
        );
        if (!mounted) return;
        if (affected == 1) {
          Navigator.pop(
            context,
            'Saved folder ID ${folder.id}. Updated 1 row.',
          );
        } else {
          setState(
            () => _error =
                'Folder ID ${folder.id} no longer exists. Updated $affected rows. Cancel and refresh.',
          );
        }
      }
    } catch (error, stack) {
      debugPrint('Folder save failed: $error\n$stack');
      if (mounted) setState(() => _error = writeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(
        widget.folder == null
            ? 'Add folder'
            : 'Edit folder ID ${widget.folder!.id}',
      ),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Folder name'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a folder name.' : null,
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Save folder'),
        ),
      ],
    ),
  );
}

class CardsScreen extends StatefulWidget {
  const CardsScreen({
    super.key,
    required this.repository,
    required this.folder,
  });
  final CardRepository repository;
  final Folder folder;
  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  List<CatalogueCard> _cards = [];
  bool _busy = false;
  bool _loaded = false;
  String? _feedback;
  String? _error;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _load(String? result) async {
    try {
      final cards = await widget.repository.getCards(widget.folder.id!);
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loaded = true;
        _error = null;
        _feedback = result;
      });
    } catch (error, stack) {
      debugPrint('Card read failed: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _error = 'Could not refresh. The displayed list may be out of date.';
        _feedback = result == null
            ? null
            : '$result Refresh failed; retry Refresh, not the write.';
      });
    }
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _load('Cards refreshed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([CatalogueCard? card]) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => CardEditor(
            repository: widget.repository,
            folderId: widget.folder.id!,
            card: card,
          ),
        ),
      );
      if (!mounted) return;
      await _load(
        result ?? 'Edit canceled. No database changes from the form.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(CatalogueCard card) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete card?'),
          content: Text('Delete "${card.title}" (ID ${card.id})?'),
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
      if (yes != true) {
        setState(() => _feedback = 'Card deletion canceled. No changes.');
        return;
      }
      final affected = await widget.repository.deleteCard(card.id!);
      if (mounted) {
        await _load(
          affected == 1
              ? 'Deleted card ID ${card.id}. Deleted 1 row.'
              : 'Card ID ${card.id} no longer exists. Deleted $affected rows.',
        );
      }
    } catch (error, stack) {
      debugPrint('Card delete failed: $error\n$stack');
      if (mounted) {
        setState(
          () =>
              _feedback = 'Could not delete the card. Refresh before retrying.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.folder.name),
      actions: [
        IconButton(
          tooltip: 'Refresh cards',
          onPressed: _busy ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Folder ID ${widget.folder.id}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_loaded) Text('Card count: ${_cards.length}'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Add card'),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_feedback != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Semantics(liveRegion: true, child: Text(_feedback!)),
            ),
          if (_error != null) Text(_error!),
          if (_loaded && !_busy && _error == null && _cards.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No cards in this folder yet.'),
            ),
          for (final card in _cards)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CardImage(card: card),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                'Card ID ${card.id} • ${card.suit} • Folder ID ${card.folderId}',
                              ),
                              if (card.notes.isNotEmpty) Text(card.notes),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _busy ? null : () => _edit(card),
                          child: Text('Edit card ${card.id}'),
                        ),
                        TextButton(
                          onPressed: _busy ? null : () => _delete(card),
                          child: Text('Delete card ${card.id}'),
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

class CardEditor extends StatefulWidget {
  const CardEditor({
    super.key,
    required this.repository,
    required this.folderId,
    this.card,
  });
  final CardRepository repository;
  final int folderId;
  final CatalogueCard? card;
  @override
  State<CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<CardEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _image;
  List<Folder> _folders = [];
  int? _folderId;
  String? _suit;
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    final card = widget.card;
    _title = TextEditingController(text: card?.title ?? '');
    _notes = TextEditingController(text: card?.notes ?? '');
    _image = TextEditingController(text: card?.imageRef ?? '');
    _folderId = card?.folderId ?? widget.folderId;
    _suit = card?.suit ?? 'spades';
    _loadFolders();
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _image.dispose();
    super.dispose();
  }

  Future<void> _loadFolders() async {
    setState(() => _busy = true);
    try {
      final folders = await widget.repository.getFoldersWithCounts();
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _error = null;
        if (!folders.any((f) => f.id == _folderId)) _folderId = null;
      });
    } catch (error, stack) {
      debugPrint('Folder options failed: $error\n$stack');
      if (mounted) {
        setState(
          () => _error = 'Could not load folders. Your input is kept. Retry loading folders.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final card = CatalogueCard(
      id: widget.card?.id,
      title: _title.text.trim(),
      suit: _suit!,
      notes: _notes.text,
      imageRef: _image.text,
      folderId: _folderId!,
    );
    try {
      if (card.id == null) {
        final id = await widget.repository.insertCard(card);
        if (mounted) Navigator.pop(context, 'Saved card ID $id.');
      } else {
        final affected = await widget.repository.updateCard(card);
        if (!mounted) return;
        if (affected == 1) {
          Navigator.pop(context, 'Saved card ID ${card.id}. Updated 1 row.');
        } else {
          setState(
            () => _error =
                'Card ID ${card.id} no longer exists. Updated $affected rows. Cancel and refresh.',
          );
        }
      }
    } catch (error, stack) {
      debugPrint('Card save failed: $error\n$stack');
      if (mounted) setState(() => _error = writeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.card == null ? 'Add card' : 'Edit card ID ${widget.card!.id}',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            Form(
              key: _form,
              child: Column(
                children: [
                  TextFormField(
                    controller: _title,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Enter a card title.' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: ValueKey(_folderId),
                    initialValue: _folderId,
                    decoration: const InputDecoration(
                      labelText: 'Folder',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final f in _folders)
                        DropdownMenuItem(
                          value: f.id,
                          child: Text('${f.name} (ID ${f.id})'),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _folderId = v),
                    validator: (v) => _folders.any((f) => f.id == v)
                        ? null
                        : 'Choose a valid folder.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _suit,
                    decoration: const InputDecoration(
                      labelText: 'Suit',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final s in CatalogueCard.suits)
                        DropdownMenuItem(
                          value: s,
                          child: Text('${CatalogueCard.symbols[s]} $s'),
                        ),
                    ],
                    onChanged: _busy ? null : (v) => setState(() => _suit = v),
                    validator: (v) => CatalogueCard.suits.contains(v)
                        ? null
                        : 'Choose a supported suit.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notes,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _image,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Image reference (optional)',
                      border: OutlineInputBorder(),
                      helperText: 'Leave blank for a suit symbol. Supports asset: paths or HTTPS URLs.',
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Semantics(liveRegion: true, child: Text(_error!)),
              ),
            if (_folders.isEmpty && !_busy)
              OutlinedButton(
                onPressed: _loadFolders,
                child: const Text('Retry loading folders'),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Save card'),
            ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel edit'),
            ),
          ],
        ),
      ),
    ),
  );
}

class CardImage extends StatelessWidget {
  const CardImage({super.key, required this.card});
  final CatalogueCard card;
  Widget _fallback() => Semantics(
    label: 'Image fallback: ${card.suit}',
    child: SizedBox(
      width: 56,
      height: 72,
      child: Center(
        child: Text(
          CatalogueCard.symbols[card.suit] ?? '?',
          style: TextStyle(
            fontSize: 40,
            color: ['hearts', 'diamonds'].contains(card.suit)
                ? Colors.red.shade700
                : Colors.black87,
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final reference = card.imageRef?.trim();
    if (reference == null || reference.isEmpty) return _fallback();
    if (reference.startsWith('asset:') && reference.length > 6) {
      return Image.asset(
        reference.substring(6),
        width: 56,
        height: 72,
        fit: BoxFit.contain,
        errorBuilder: (_, error, stack) => _fallback(),
      );
    }
    final uri = Uri.tryParse(reference);
    if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
      return Image.network(
        reference,
        width: 56,
        height: 72,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _fallback(),
        errorBuilder: (_, error, stack) => _fallback(),
      );
    }
    return _fallback();
  }
}
