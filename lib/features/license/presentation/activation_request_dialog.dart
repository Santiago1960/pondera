import 'package:flutter/material.dart';

class ActivationRequestFormData {
  const ActivationRequestFormData({
    required this.customerName,
    required this.siteName,
    required this.city,
    required this.deviceLabel,
    this.assetTag,
  });

  final String customerName;
  final String siteName;
  final String city;
  final String deviceLabel;
  final String? assetTag;
}

Future<ActivationRequestFormData?> showActivationRequestDialog(
  BuildContext context, {
  required String suggestedDeviceLabel,
}) {
  return showDialog<ActivationRequestFormData>(
    context: context,
    builder: (context) =>
        _ActivationRequestDialog(suggestedDeviceLabel: suggestedDeviceLabel),
  );
}

class _ActivationRequestDialog extends StatefulWidget {
  const _ActivationRequestDialog({required this.suggestedDeviceLabel});

  final String suggestedDeviceLabel;

  @override
  State<_ActivationRequestDialog> createState() =>
      _ActivationRequestDialogState();
}

class _ActivationRequestDialogState extends State<_ActivationRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customerController = TextEditingController();
  final _siteController = TextEditingController();
  final _cityController = TextEditingController();
  final _assetTagController = TextEditingController();
  late final TextEditingController _deviceController;

  @override
  void initState() {
    super.initState();
    _deviceController = TextEditingController(
      text: widget.suggestedDeviceLabel,
    );
  }

  @override
  void dispose() {
    _customerController.dispose();
    _siteController.dispose();
    _cityController.dispose();
    _deviceController.dispose();
    _assetTagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generar solicitud de activación'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Estos datos permiten identificar humanamente el equipo. '
                  'Pondera añadirá automáticamente el identificador técnico de la instalación.',
                ),
                const SizedBox(height: 16),
                _requiredField(
                  controller: _customerController,
                  label: 'Nombre del cliente',
                  hint: 'Ej.: SIGMA ALIMENTOS',
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                _requiredField(
                  controller: _siteController,
                  label: 'Sucursal o planta',
                  hint: 'Ej.: Planta de embutidos',
                ),
                const SizedBox(height: 12),
                _requiredField(
                  controller: _cityController,
                  label: 'Ciudad',
                  hint: 'Ej.: Cuenca',
                ),
                const SizedBox(height: 12),
                _requiredField(
                  controller: _deviceController,
                  label: 'Nombre del equipo',
                  hint: 'Ej.: PC-Producción-01',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _assetTagController,
                  decoration: const InputDecoration(
                    labelText: 'Código interno o activo (opcional)',
                    hintText: 'Ej.: SIG-PC-042',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_alt),
          label: const Text('Guardar solicitud'),
        ),
      ],
    );
  }

  Widget _requiredField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool autofocus = false,
  }) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Este dato es obligatorio.';
        }
        return null;
      },
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final assetTag = _assetTagController.text.trim();
    Navigator.of(context).pop(
      ActivationRequestFormData(
        customerName: _customerController.text.trim(),
        siteName: _siteController.text.trim(),
        city: _cityController.text.trim(),
        deviceLabel: _deviceController.text.trim(),
        assetTag: assetTag.isEmpty ? null : assetTag,
      ),
    );
  }
}
