import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../core/geo/coord.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/vibe_widgets.dart';
import '../../domain/models/status.dart';

const pinEmojis = ['📍', '🏠', '🍜', '☕', '🎬', '🌳', '🛍️', '🎂', '💍', '🏖️', '🚉', '🏥'];

/// D3：新建或编辑共同标记（内容端到端加密后同步）。
Future<void> showPinEditor(BuildContext context, WidgetRef ref, {LatLngD? at, MapPin? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => UncontrolledProviderScope(container: ProviderScope.containerOf(context), child: _PinEditor(at: at, existing: existing)),
  );
}

class _PinEditor extends ConsumerStatefulWidget {
  const _PinEditor({this.at, this.existing});
  final LatLngD? at;
  final MapPin? existing;
  @override
  ConsumerState<_PinEditor> createState() => _PinEditorState();
}

class _PinEditorState extends ConsumerState<_PinEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late String _emoji = widget.existing?.emoji ?? '📍';
  String? _photo;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _photo = widget.existing?.photoB64;
    if (widget.existing == null && widget.at != null) {
      ref.read(syncProvider.notifier).placeName(widget.at!.lat, widget.at!.lng).then((n) {
        if (mounted && _name.text.isEmpty) _name.text = n;
      });
    }
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 480, maxHeight: 480, imageQuality: 60);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() => _photo = base64Encode(bytes));
  }

  Future<void> _save({bool delete = false}) async {
    setState(() => _busy = true);
    try {
      final ex = widget.existing;
      final pin = MapPin(
        id: ex?.id ?? const Uuid().v4(),
        lat: ex?.lat ?? widget.at!.lat,
        lng: ex?.lng ?? widget.at!.lng,
        name: _name.text.trim().isEmpty ? '未命名地点' : _name.text.trim(),
        emoji: _emoji,
        note: _note.text.trim(),
        photoB64: _photo,
        updatedAt: DateTime.now(),
        ownerId: ex?.ownerId ?? '',
      );
      await ref.read(syncProvider.notifier).savePin(pin, delete: delete);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vibes;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: GlassPanel(
        radius: AppRadii.card,
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.existing == null ? '添加共同标记' : '编辑标记', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('内容端到端加密，只有你们两人能看到。', style: TextStyle(color: v.inkSoft, fontSize: 12)),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: pinEmojis.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Squish(
                  onTap: () => setState(() => _emoji = pinEmojis[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52,
                    decoration: BoxDecoration(
                      color: _emoji == pinEmojis[i] ? _coral.withValues(alpha: 0.25) : v.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppRadii.small),
                      border: Border.all(color: _emoji == pinEmojis[i] ? _coral : Colors.transparent, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(pinEmojis[i], style: const TextStyle(fontSize: 26)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: _name, decoration: const InputDecoration(hintText: '名称，例如「第一次约会的咖啡店」')),
            const SizedBox(height: 10),
            TextField(controller: _note, maxLines: 3, decoration: const InputDecoration(hintText: '备注（可选）')),
            const SizedBox(height: 10),
            Row(children: [
              SoftButton(label: _photo == null ? '添加照片' : '更换照片', icon: PhosphorIconsRegular.image, onTap: _pickPhoto),
              if (_photo != null) ...[
                const SizedBox(width: 10),
                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(base64Decode(_photo!), width: 48, height: 48, fit: BoxFit.cover)),
              ],
            ]),
            const SizedBox(height: 16),
            Row(children: [
              if (widget.existing != null) ...[
                SoftButton(label: '删除', color: v.danger, icon: PhosphorIconsRegular.trash, onTap: _busy ? null : () => _save(delete: true)),
                const SizedBox(width: 10),
              ],
              Expanded(child: PrimaryButton(label: '保存', busy: _busy, onTap: _busy ? null : _save)),
            ]),
          ]),
        ),
      ),
    );
  }
}


const _coral = AppColors.accent;
