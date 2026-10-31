import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TimelineDialog extends StatefulWidget {
  const TimelineDialog({super.key, required this.weeks});
  final int weeks;
  @override
  State<TimelineDialog> createState() => _TimelineDialogState();
}

class _TimelineDialogState extends State<TimelineDialog> {
  late final input = TextEditingController(text: '${widget.weeks}');
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void submit() {
    if (form.currentState!.validate()) {
      Navigator.pop(context, int.parse(input.text));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Your training timeline'),
    content: Form(
      key: form,
      child: TextFormField(
        controller: input,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 3,
        decoration: const InputDecoration(
          labelText: 'Number of weeks',
          helperText: 'Take the time that works for you.',
        ),
        validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1
            ? 'Enter a number from 1 to 999.'
            : null,
        onFieldSubmitted: (_) => submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: submit, child: const Text('Use timeline')),
    ],
  );
}
