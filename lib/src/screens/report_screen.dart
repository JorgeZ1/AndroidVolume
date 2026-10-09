import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../app_language.dart';
import '../services/report_service.dart';
import '../services/monitoring_service.dart';

class ReportQuickAction extends StatelessWidget {
  const ReportQuickAction({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tr('Report a problem', 'Reportar un problema'),
    icon: const Icon(Icons.bug_report_outlined),
    onPressed:
        () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ReportScreen())),
  );
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    this.service,
    this.pickImage,
    this.pickImages,
  });
  final ReportService? service;
  final Future<ReportImage?> Function()? pickImage;
  final Future<List<ReportImage>> Function(int remaining)? pickImages;
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _descriptionKey = GlobalKey();
  final _images = <ReportImage>[];
  final _picker = ImagePicker();
  late final _service = widget.service ?? ReportService();
  ReportCategory _category = ReportCategory.volume;
  Map<String, Object?> _diagnostics = {};
  Map<String, Object?>? _submittedDiagnostics;
  String _id = ReportService.newId();
  bool _consent = false, _sending = false, _picking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
    if (widget.pickImage == null && widget.pickImages == null) _recoverImages();
  }

  Future<void> _loadDiagnostics() async {
    try {
      final data = await const MethodChannel(
        'floating_volume/settings',
      ).invokeMapMethod<String, Object?>('reportDiagnostics');
      if (mounted) _diagnostics = data ?? {};
    } on PlatformException {
      /* Report can still be submitted. */
    } on MissingPluginException {
      /* Widget tests. */
    }
  }

  Future<void> _recoverImages() async {
    try {
      final lost = await _picker.retrieveLostData();
      for (final file in lost.files ?? <XFile>[]) {
        await _acceptImage(await _readImage(file));
      }
    } catch (_) {
      /* No recovered image; normal picker remains available. */
    }
  }

  Future<ReportImage> _readImage(XFile file) async {
    if (await file.length() > ReportService.maxImageBytes) {
      throw const ReportException('images');
    }
    final bytes = await file.readAsBytes();
    final png =
        bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71;
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    if (!png && !jpeg) throw const ReportException('images');
    return ReportImage(
      Uint8List.fromList(bytes),
      png ? 'image/png' : 'image/jpeg',
    );
  }

  Future<void> _acceptImage(ReportImage image) async {
    if (!mounted || _images.length >= ReportService.maxImages) return;
    if (image.bytes.isEmpty ||
        image.bytes.length > ReportService.maxImageBytes) {
      throw const ReportException('images');
    }
    setState(() {
      _images.add(image);
      _changed();
    });
  }

  void _changed() {
    _id = ReportService.newId();
    _submittedDiagnostics = null;
    _error = null;
  }

  Future<void> _addImage() async {
    if (_sending || _picking || _images.length >= 2) return;
    setState(() => _picking = true);
    try {
      final remaining = ReportService.maxImages - _images.length;
      if (widget.pickImages != null) {
        final images = await widget.pickImages!(remaining);
        for (final image in images.take(remaining)) {
          await _acceptImage(image);
        }
      } else if (widget.pickImage != null) {
        final image = await widget.pickImage!();
        if (image != null) await _acceptImage(image);
      } else {
        final files = await _picker.pickMultiImage(
          limit: remaining,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80,
          requestFullMetadata: false,
        );
        for (final file in files.take(remaining)) {
          await _acceptImage(await _readImage(file));
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = tr(
                'Choose a JPG or PNG image under 2 MB.',
                'Elige una imagen JPG o PNG de menos de 2 MB.',
              ),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _send() async {
    if (_sending || _picking || !_consent) return;
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Describe the problem using at least 10 characters.',
              'Describe el problema con al menos 10 caracteres.',
            ),
          ),
        ),
      );
      final field = _descriptionKey.currentContext;
      if (field != null) {
        await Scrollable.ensureVisible(
          field,
          duration: const Duration(milliseconds: 200),
          alignment: 0.1,
        );
      }
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final id = await MonitoringService.measure(
        'support_report_submit',
        () => _service.submit(
          id: _id,
          category: _category,
          description: _description.text,
          images: List.of(_images),
          diagnostics: _submittedDiagnostics ??= Map.of(_diagnostics),
        ),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              title: Text(tr('Report sent', 'Reporte enviado')),
              content: SelectableText(
                tr(
                  'Thank you! We will review your report.\nReference: $id',
                  '¡Gracias! Revisaremos tu reporte.\nReferencia: $id',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr('Done', 'Listo')),
                ),
              ],
            ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(
        () =>
            _error =
                error is ReportException && error.code == 'limit'
                    ? tr(
                      'Too many reports. Please try again later.',
                      'Demasiados reportes. Intenta más tarde.',
                    )
                    : tr(
                      'Could not send. Check your connection and retry; your report is still here.',
                      'No se pudo enviar. Revisa tu conexión y reintenta; tu reporte sigue aquí.',
                    ),
      );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_error!)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _label(ReportCategory category) => switch (category) {
    ReportCategory.volume => tr(
      'Volume does not change',
      'El volumen no cambia',
    ),
    ReportCategory.positioning => tr('Position / rotation', 'Posición / giro'),
    ReportCategory.appearance => tr(
      'Appearance / styles',
      'Apariencia / estilos',
    ),
    ReportCategory.ads => tr('Ads / rewards', 'Anuncios / recompensas'),
    ReportCategory.crash => tr('Crash / freezing', 'Cierre / bloqueo'),
    ReportCategory.other => tr('Other', 'Otro'),
  };

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: Scaffold(
      appBar: AppBar(
        title: Text(tr('Report a problem', 'Reportar un problema')),
      ),
      // Keep the action outside the scroll content and above navigation/IME.
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _sending || _picking || !_consent ? null : _send,
              icon:
                  _sending
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.send_outlined),
              label: Text(
                _sending
                    ? tr('Sending…', 'Enviando…')
                    : tr('Send report', 'Enviar reporte'),
              ),
            ),
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              tr(
                'Tell us what happened so we can investigate.',
                'Cuéntanos qué ocurrió para poder investigarlo.',
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<ReportCategory>(
              initialValue: _category,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: tr('Error type', 'Tipo de error'),
                border: const OutlineInputBorder(),
              ),
              items:
                  ReportCategory.values
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c, child: Text(_label(c))),
                      )
                      .toList(),
              onChanged:
                  _sending
                      ? null
                      : (c) => setState(() {
                        _category = c!;
                        _changed();
                      }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: _descriptionKey,
              controller: _description,
              enabled: !_sending,
              minLines: 4,
              maxLines: 7,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: tr('Description', 'Descripción'),
                helperText: tr(
                  'At least 10 characters',
                  'Al menos 10 caracteres',
                ),
                hintText: tr(
                  'What were you doing? What did you expect to happen?',
                  '¿Qué estabas haciendo? ¿Qué esperabas que ocurriera?',
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => _changed(),
              validator:
                  (value) =>
                      (value?.trim().length ?? 0) < 10
                          ? tr(
                            'Please enter at least 10 characters.',
                            'Escribe al menos 10 caracteres.',
                          )
                          : null,
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                'Images (optional): ${_images.length}/2',
                'Imágenes (opcionales): ${_images.length}/2',
              ),
            ),
            const SizedBox(height: 8),
            if (_images.isNotEmpty)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(
                  _images.length,
                  (i) => SizedBox(
                    width: 130,
                    height: 130,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _images[i].bytes,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, _, _) =>
                                    const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton.filled(
                            tooltip: tr('Remove image', 'Quitar imagen'),
                            onPressed:
                                _sending
                                    ? null
                                    : () => setState(() {
                                      _images.removeAt(i);
                                      _changed();
                                    }),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed:
                  _sending || _picking || _images.length >= 2
                      ? null
                      : _addImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(tr('Add image', 'Agregar imagen')),
            ),
            Text(
              tr(
                'JPG or PNG, up to 2 MB each. Avoid personal information in screenshots.',
                'JPG o PNG, hasta 2 MB cada una. Evita información personal en las capturas.',
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _consent,
              onChanged:
                  _sending
                      ? null
                      : (v) => setState(() => _consent = v ?? false),
              title: Text(
                tr(
                  'I agree to send this description, the selected images and basic app/device information to support via Supabase. Only support can access them.',
                  'Acepto enviar esta descripción, las imágenes elegidas y datos básicos de la app/dispositivo a soporte mediante Supabase. Solo soporte podrá acceder a ellos.',
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _description.dispose();
    if (widget.service == null) _service.close();
    super.dispose();
  }
}
