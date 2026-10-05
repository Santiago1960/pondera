import 'package:flutter/material.dart';
import '../domain/tare_weight.dart';
import '../domain/weight_unit.dart';

Future<TareWeight?> showTareDialog(BuildContext context, TareWeight tare) =>
    showDialog<TareWeight>(context: context, builder: (_) => _TareDialog(tare));

class _TareDialog extends StatefulWidget {
  const _TareDialog(this.tare);
  final TareWeight tare;
  @override
  State<_TareDialog> createState() => _TareDialogState();
}

class _TareDialogState extends State<_TareDialog> {
  late final _controller = TextEditingController(
    text: widget.tare.value.toString(),
  );
  late WeightUnit _unit = widget.tare.unit;
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final value = TareWeight.parse(_controller.text);
    if (value == null) {
      setState(() => _error = 'Ingrese un peso válido, mayor o igual a cero.');
      return;
    }
    Navigator.of(context).pop(TareWeight(value: value, unit: _unit));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tara manual'),
    content: SizedBox(
      width: 340,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Este valor se descontará de cada lectura. La tara vuelve a cero al abrir Pondera.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Peso de los ganchos',
              errorText: _error,
            ),
            onSubmitted: (_) => _apply(),
          ),
          DropdownButton<WeightUnit>(
            value: _unit,
            isExpanded: true,
            items: WeightUnit.values
                .map(
                  (unit) =>
                      DropdownMenuItem(value: unit, child: Text(unit.code)),
                )
                .toList(),
            onChanged: (unit) {
              if (unit != null) setState(() => _unit = unit);
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _apply, child: const Text('Aplicar')),
    ],
  );
}
