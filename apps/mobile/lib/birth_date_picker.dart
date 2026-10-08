import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String formatBirthDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().padLeft(4, '0')}';

DateTime? parseBirthDate(String text) {
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text);
  if (match == null) return null;
  final day = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final year = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  return date.day == day && date.month == month && date.year == year
      ? date
      : null;
}

/// Formats both typing and pasted digits, preserving edits and cursor position.
class BirthDateInputFormatter extends TextInputFormatter {
  const BirthDateInputFormatter();
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    var raw = newValue.text;
    var cursor = newValue.selection.isValid
        ? newValue.selection.extentOffset
        : raw.length;
    // Backspace at an inserted separator also deletes the preceding digit.
    if (oldValue.selection.isCollapsed &&
        newValue.selection.isCollapsed &&
        oldValue.text.length == raw.length + 1 &&
        oldValue.selection.extentOffset == cursor + 1 &&
        cursor >= 0 &&
        cursor < oldValue.text.length &&
        oldValue.text[cursor] == '/' &&
        cursor > 0) {
      raw = raw.replaceRange(cursor - 1, cursor, '');
      cursor--;
    }
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digits.substring(0, digits.length.clamp(0, 8));
    final output = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i == 2 || i == 4) output.write('/');
      output.write(limited[i]);
    }
    final digitsBeforeCursor = raw
        .substring(0, cursor.clamp(0, raw.length))
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length
        .clamp(0, limited.length);
    final offset =
        digitsBeforeCursor +
        (digitsBeforeCursor > 2 ? 1 : 0) +
        (digitsBeforeCursor > 4 ? 1 : 0);
    return TextEditingValue(
      text: output.toString(),
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

Future<DateTime?> showBirthDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) => showDialog<DateTime>(
  context: context,
  builder: (_) => _BirthDateDialog(
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  ),
);

/// Standard Material calendar and input modes with Indian date input formatting.
class _BirthDateDialog extends StatefulWidget {
  const _BirthDateDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });
  final DateTime initialDate, firstDate, lastDate;
  @override
  State<_BirthDateDialog> createState() => _BirthDateDialogState();
}

class _BirthDateDialogState extends State<_BirthDateDialog> {
  late DateTime _selected = widget.initialDate;
  late final _input = TextEditingController(text: formatBirthDate(_selected));
  bool _typing = false;
  String? _error;
  bool _allowed(DateTime date) =>
      !date.isBefore(widget.firstDate) && !date.isAfter(widget.lastDate);
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _changed(String text) {
    final date = parseBirthDate(text);
    setState(() {
      _error = null;
      if (date != null && _allowed(date)) _selected = date;
    });
  }

  bool _validate() {
    if (!_typing) return true;
    final local = MaterialLocalizations.of(context);
    final date = parseBirthDate(_input.text);
    if (date == null || !_allowed(date)) {
      setState(
        () => _error = date == null
            ? local.invalidDateFormatLabel
            : local.dateOutOfRangeLabel,
      );
      return false;
    }
    _selected = date;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final local = MaterialLocalizations.of(context);
    return Dialog(
      child: SizedBox(
        width: 328,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(local.datePickerHelpText),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            local.formatMediumDate(_selected),
                            key: const Key('birth-date-heading'),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: _typing
                              ? local.calendarModeButtonLabel
                              : local.inputDateModeButtonLabel,
                          icon: Icon(
                            _typing
                                ? Icons.calendar_month
                                : Icons.edit_outlined,
                          ),
                          onPressed: () {
                            if (_typing && !_validate()) return;
                            setState(() {
                              _typing = !_typing;
                              _input.text = formatBirthDate(_selected);
                              _error = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_typing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: TextField(
                    key: const Key('birth-date-input'),
                    controller: _input,
                    autofocus: true,
                    keyboardType: TextInputType.datetime,
                    inputFormatters: const [BirthDateInputFormatter()],
                    decoration: InputDecoration(
                      labelText: local.dateInputLabel,
                      hintText: 'DD/MM/YYYY',
                      helperText: 'DD/MM/YYYY',
                      errorText: _error,
                    ),
                    onChanged: _changed,
                    onSubmitted: (_) {
                      if (_validate()) Navigator.pop(context, _selected);
                    },
                  ),
                )
              else
                CalendarDatePicker(
                    initialDate: _selected,
                  firstDate: widget.firstDate,
                  lastDate: widget.lastDate,
                  onDateChanged: (date) => setState(() => _selected = date),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(local.cancelButtonLabel),
                    ),
                    TextButton(
                      onPressed: () {
                        if (_validate()) Navigator.pop(context, _selected);
                      },
                      child: Text(local.okButtonLabel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
