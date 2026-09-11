import 'dart:async';
import 'package:flutter/material.dart';

import 'services/adult_birth_date.dart';
import 'services/birth_profile_input.dart';

import 'services/profile_session.dart';
import 'services/jyotara_api.dart';
import 'services/ui_language.dart';
import 'services/profile_gender.dart';

class BirthForm extends StatefulWidget {
  const BirthForm({
    super.key,
    required this.session,
    this.onSubmit,
    this.onCompleted,
    this.initialGender,
    this.initialDetails,
  });
  final Future<void> Function(Map<String, dynamic>)? onSubmit;
  final VoidCallback? onCompleted;
  final ProfileGender? initialGender;
  final Map<String, dynamic>? initialDetails;
  final ProfileSession session;
  @override
  State<BirthForm> createState() => _BirthFormState();
}

class _BirthFormState extends State<BirthForm> {
  final _placeQuery = TextEditingController();
  final _nickname = TextEditingController();
  ProfileGender? _gender;
  bool _showGender = false;
  DateTime? _date;
  TimeOfDay? _time;
  bool _unknown = false, _consent = false, _busy = false, _searching = false;
  List<List<dynamic>> _places = [];
  List<dynamic>? _place;
  String? _error;
  int _searchRevision = 0;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _nickname.text =
        widget.initialDetails?['nickname'] as String? ??
        widget.session.nickname;
    _gender = widget.initialGender ?? widget.session.gender;
    _showGender = _gender == null && widget.session.birthInput == null;
    final input = widget.initialDetails;
    final saved = input == null
        ? widget.session.birthInput
        : BirthProfileInput(
            input['datetime'] as String,
            (input['latitude'] as num).toDouble(),
            (input['longitude'] as num).toDouble(),
            input['exactTime'] == true,
          );
    if (saved == null) return;
    final stamp = saved.indiaDateTime;
    _date = DateTime(stamp.year, stamp.month, stamp.day);
    _unknown = !saved.exactTime;
    _time = saved.exactTime
        ? TimeOfDay(hour: stamp.hour, minute: stamp.minute)
        : null;
    final label =
        widget.initialDetails?['birthplaceLabel'] as String? ??
        widget.session.birthplaceLabel ??
        'Saved birthplace (${saved.latitude.toStringAsFixed(4)}, ${saved.longitude.toStringAsFixed(4)})';
    _placeQuery.text = label;
    _place = [
      'saved',
      label,
      '',
      '',
      'IN',
      'Asia/Kolkata',
      saved.latitude,
      saved.longitude,
    ];
    // Processing consent must be confirmed for this edit, not inferred from
    // having a saved chart. Research consent remains a separate control.
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _placeQuery.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    _searchDebounce?.cancel();
    final query = _placeQuery.text.trim();
    if (query.length < 3) return;
    final revision = ++_searchRevision;
    setState(() {
      _searching = true;
      _error = null;
      _place = null;
    });
    try {
      final rows = await widget.session.searchLocations(query);
      if (!mounted || revision != _searchRevision) return;
      setState(() {
        _places = rows;
        if (rows.isEmpty) _error = 'No Indian birthplace found. Try the nearest town name in English.';
      });
    } catch (_) {
      if (mounted && revision == _searchRevision) {
        setState(
          () => _error = 'Place search is unavailable. Please retry; no chart was requested.',
        );
      }
    } finally {
      if (mounted && revision == _searchRevision) setState(() => _searching = false);
    }
  }

  Future<void> _calculate() async {
    if (_busy) return;
    if (_gender == null) {
      setState(() => _showGender = true);
      return;
    }
    if (_date == null ||
        (!_unknown && _time == null) ||
        _place == null ||
        !_consent) {
      setState(
        () => _error =
            'Choose your date, time and birthplace, then confirm consent.',
      );
      return;
    }
    if (_date!.isAfter(latestEligibleBirthDate(DateTime.now()))) {
      setState(() => _error = 'This test app supports personal birth profiles for people aged 13 or older.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final time = _unknown ? const TimeOfDay(hour: 12, minute: 0) : _time!;
    final stamp =
        '${_date!.toIso8601String().substring(0, 10)}T${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00+05:30';
    try {
      if (widget.onSubmit != null) {
        await widget.onSubmit!({
          'datetime': stamp,
          'latitude': (_place![6] as num).toDouble(),
          'longitude': (_place![7] as num).toDouble(),
          'exactTime': !_unknown,
          'nickname': _nickname.text.trim(),
          'birthplaceLabel': _place![1] as String,
        });
      } else {
        await widget.session.calculate(
          dateTime: stamp,
          latitude: (_place![6] as num).toDouble(),
          longitude: (_place![7] as num).toDouble(),
          exactTime: !_unknown,
          nickname: _nickname.text,
          gender: _gender,
          birthplaceLabel: _place![0] == 'saved'
              ? widget.session.birthplaceLabel
              : '${_place![1]}, ${_place![2]}',
        );
      }
      if (mounted) {
        if (widget.onCompleted != null) {
          widget.onCompleted!();
        } else {
          Navigator.of(context).pop();
        }
      }
    } on JyotaraApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'The chart could not be verified. Please try again later.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showGender) {
      return Scaffold(
        appBar: AppBar(title: const UiText('Your birth profile')),
        body: ListView(
          key: const ValueKey('gender-step-list'),
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            const UiText(
              'Select your gender',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const UiText(
              'Choose what you want to share. You can change this later.',
            ),
            const SizedBox(height: 20),
            for (final option in ProfileGender.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  selected: _gender == option,
                  child: ListTile(
                    key: ValueKey('gender-${option.value}'),
                    title: UiText(option.label),
                    selected: _gender == option,
                    trailing: Icon(
                      _gender == option
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    onTap: () => setState(() => _gender = option),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('gender-continue'),
              onPressed: _gender == null
                  ? null
                  : () => setState(() => _showGender = false),
              child: const UiText('Continue'),
            ),
            const SizedBox(height: 16),
            const UiText(
              'Saved with your profile. Your selected gender is used when requesting a detailed astrology report.',
            ),
          ],
        ),
      );
    }
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const UiText('Your birth profile')),
        body: ListView(
          key: const ValueKey('birth-details-list'),
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            const UiText(
              'Personal guidance starts with your chart',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const UiText(
              'India · Age 13+ · Times are Indian Standard Time (UTC+05:30).',
            ),
            if (widget.session.facts != null) ...[
              const SizedBox(height: 12),
              const UiText(
                'Changing your birth date, time or place replaces this device’s chart and clears its previous guide chats only after the new chart is verified. If calculation fails, your existing profile and chats stay unchanged. Refreshing the same details keeps your chats.',
              ),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _nickname,
              enabled: !_busy,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: uiText(
                  context,
                  'Name or alias (used on detailed reports)',
                ),
              ),
            ),
            ListTile(
              key: const ValueKey('edit-gender'),
              title: const UiText('Gender'),
              subtitle: UiText(_gender?.label ?? 'Not selected'),
              trailing: const Icon(Icons.edit_outlined),
              onTap: _busy ? null : () => setState(() => _showGender = true),
            ),
            ListTile(
              title: const UiText('Date of birth'),
              subtitle: UiText(
                _date == null
                    ? 'Select date'
                    : '${_date!.day}/${_date!.month}/${_date!.year}',
              ),
              trailing: const Icon(Icons.calendar_month),
              onTap: _busy
                  ? null
                  : () async {
                      final now = DateTime.now();
                      final latest = latestEligibleBirthDate(now);
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _date == null || _date!.isAfter(latest)
                            ? latest
                            : _date!.isBefore(DateTime(1900))
                            ? DateTime(1900)
                            : _date,
                        firstDate: DateTime(1900),
                        lastDate: latest,
                      );
                      if (date != null && mounted) setState(() => _date = date);
                    },
            ),
            SwitchListTile(
              title: const UiText('I don’t know my exact birth time'),
              value: _unknown,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _unknown = value),
            ),
            if (!_unknown)
              ListTile(
                title: const UiText('Exact birth time'),
                subtitle: UiText(
                  _time?.format(context) ?? 'Select time (AM/PM)',
                ),
                trailing: const Icon(Icons.schedule),
                onTap: _busy
                    ? null
                    : () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime:
                              _time ?? const TimeOfDay(hour: 12, minute: 0),
                        );
                        if (time != null && mounted) {
                          setState(() => _time = time);
                        }
                      },
              ),
            if (_unknown)
              const UiText(
                'A noon estimate will be used. Rasi/Nakshatra may change during the day; Lagnam and Dasa guidance are withheld.',
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _placeQuery,
              enabled: !_busy,
              onChanged: (_) {
                _searchDebounce?.cancel();
                _searchRevision++;
                setState(() {
                  _place = null;
                  _places = [];
                  _error = null;
                  _searching = false;
                });
                if (_placeQuery.text.trim().length >= 3) {
                  _searchDebounce = Timer(const Duration(milliseconds: 350), _search);
                }
              },
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: uiText(context, 'Birth town, city or district'),
                hintText: uiText(context, 'For example: Erode'),
              ),
            ),
            TextButton.icon(
              onPressed: _busy || _searching ? null : _search,
              icon: const Icon(Icons.search),
              label: UiText(_searching ? 'Searching…' : 'Search birthplace'),
            ),
            const UiText(
              'Location data: astrology calculation service',
              style: TextStyle(fontSize: 12),
            ),
            ..._places.map(
              (row) => ListTile(
                selected: _place?[0] == row[0],
                trailing: Icon(
                  _place?[0] == row[0]
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                ),
                onTap: _busy ? null : () {
                  _searchDebounce?.cancel();
                  _searchRevision++;
                  setState(() {
                    _place = row;
                    _placeQuery.text = '${row[1]}, ${row[2]}';
                    _places = [];
                    _searching = false;
                  });
                },
                title: UiText('${row[1]}, ${row[2]}'),
                subtitle: const UiText('India · IST'),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _consent,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _consent = value ?? false),
              title: const UiText(
                'I am 13+ and agree to process my birth details for automated Vedic guidance.',
              ),
              subtitle: const UiText(
                'Name or alias, selected gender and birth details go to astrology calculation service when a detailed report is requested; chart facts and your question go to the language service. Your chart and chat history are saved in encrypted storage on this device. Delete them from the Chart tab. Creating a profile turns optional research sharing off; you can choose it separately in Account. For a connected profile, the Chart tab can also delete server chart and answer copies. Minimal usage records remain; backup copies expire within eight days.',
              ),
            ),
            const UiText(
              'Retry recovery is separate from research: the server keeps an encrypted answer until this chart session expires (up to 24 hours). Expired copies are cleared when requests arrive, not on a guaranteed schedule. Request receipts remain to prevent duplicate usage.',
            ),
            const UiText(
              'For same-day retry recovery, the server also keeps an encrypted chart response for up to 23 hours, separately from research consent. Expired copies are removed when chart requests arrive; scheduled deletion is not yet available.',
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: UiText(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: _busy ? null : _calculate,
              child: UiText(
                widget.onSubmit != null
                    ? (_busy ? 'Saving details…' : 'Use these birth details')
                    : (_busy
                          ? 'Calculating your chart…'
                          : 'Calculate my chart'),
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 12),
            const UiText(
              'Traditional guidance is interpretive, not a guarantee of future events. Pilot usage limits apply.',
            ),
          ],
        ),
      ),
    );
  }
}
