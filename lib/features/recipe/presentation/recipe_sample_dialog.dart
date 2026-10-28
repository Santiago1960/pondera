import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../scale_reading/domain/reading_parser.dart';
import '../domain/recipe_sample.dart';

class RecipeSampleDialog extends StatefulWidget {
  const RecipeSampleDialog({
    required this.sample,
    this.initialExpectedValue = '',
    this.submitLabel = 'Enviar',
    super.key,
  });

  final RecipeSample sample;
  final String initialExpectedValue;
  final String submitLabel;

  @override
  State<RecipeSampleDialog> createState() => _RecipeSampleDialogState();
}

class _RecipeSampleDialogState extends State<RecipeSampleDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _enteredValue;

  @override
  void initState() {
    super.initState();
    _enteredValue =
        widget.sample.suggestedExpectedValue ?? widget.initialExpectedValue;
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_enteredValue.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Valor esperado'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Muestra capturada'),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      widget.sample.visibleRawData,
                      style: const TextStyle(fontFamily: 'IBMPlexMono'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Esta muestra queda fija. Ingresa el peso que corresponde a ella, aunque el indicador cambie después.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ingresa el peso completo del indicador, con punto o coma. '
                  'Para elegir el separador, los decimales y si deseas redondear '
                  'o recortar al escribir en Excel, usa «Formato de salida».',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _enteredValue,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Peso correspondiente a la muestra',
                    hintText: 'Ej.: 0.130 o -0,130',
                    errorMaxLines: 3,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (!ReadingParser.isValidExpectedValue(value ?? '')) {
                      return 'Ingrese un valor válido, por ejemplo 0.130 o -0,130.';
                    }
                    final suggested = widget.sample.suggestedExpectedValue;
                    if (suggested != null &&
                        double.tryParse(value!.trim().replaceAll(',', '.')) !=
                            double.tryParse(suggested.replaceAll(',', '.'))) {
                      return 'Ingresa el peso completo: $suggested. Ajusta los decimales en «Formato de salida».';
                    }
                    return null;
                  },
                  onChanged: (value) => _enteredValue = value,
                  onFieldSubmitted: (_) => _submit(),
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
        FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
      ],
    );
  }
}
