import 'services/user_journey.dart';
import 'bronze_theme.dart';

import 'package:flutter/material.dart';

import 'birth_date_picker.dart';
import 'premium_onboarding.dart';
import 'privacy_links.dart';
import 'location_search_sheet.dart';
import 'services/full_name.dart';

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
    this.onboarding = false,
  });
  final Future<void> Function(Map<String, dynamic>)? onSubmit;
  final VoidCallback? onCompleted;
  final ProfileGender? initialGender;
  final Map<String, dynamic>? initialDetails;
  final bool onboarding;
  final ProfileSession session;
  @override
  State<BirthForm> createState() => _BirthFormState();
}

class _BirthFormState extends State<BirthForm> {
  final _placeQuery = TextEditingController();
  final _nickname = TextEditingController();
  ProfileGender? _gender;
  String _chatLanguage = 'english', _relationship = '', _profession = '';
  DateTime? _date;
  TimeOfDay? _time;
  bool _unknown = false, _consent = false, _busy = false;
  List<dynamic>? _place;
  String? _error;

  @override
  void initState() {
    super.initState();
    userJourney.screen(
      widget.session.facts == null && widget.onCompleted != null
          ? 'onboarding'
          : 'birth_details',
    );
    _nickname.text =
        widget.initialDetails?['nickname'] as String? ??
        widget.session.nickname;
    _gender = widget.initialGender ?? widget.session.gender;
    _chatLanguage =
        widget.initialDetails?['preferredChatLanguage'] as String? ??
        widget.session.preferredChatLanguage;
    if (_chatLanguage == 'auto') {
      _chatLanguage = widget.session.preferences?.value ?? 'english';
    }
    if (!['english', 'tamil', 'tanglish'].contains(_chatLanguage)) {
      _chatLanguage = 'english';
    }
    _relationship =
        widget.initialDetails?['relationshipStatus'] as String? ??
        widget.session.relationshipStatus;
    _profession =
        widget.initialDetails?['profession'] as String? ??
        widget.session.profession;
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
    _placeQuery.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _pickPlace() async {
    FocusScope.of(context).unfocus();
    final row = await pickIndianLocation(
      context,
      widget.session,
      initialQuery: _placeQuery.text.split(',').first.trim(),
    );
    if (row == null || !mounted) return;
    setState(() {
      _place = row;
      _placeQuery.text = '${row[1]}, ${row[2]}';
      _error = null;
    });
  }

  void _clearPlace() => setState(() {
    _place = null;
    _placeQuery.clear();
    _error = null;
  });

  Future<void> _calculate() async {
    if (_busy) return;
    if (_gender == null) {
      setState(() => _error = 'Select your gender.');
      return;
    }
    if (!validFullName(_nickname.text)) {
      setState(() => _error = 'Please enter a valid name.');
      return;
    }
    final missing = <String>[
      if (_date == null) 'Choose your date of birth.',
      if (!_unknown && _time == null)
        'Choose your birth time or select unknown.',
      if (_place == null)
        'Select your birthplace from the search results below the field.',
      if (!_consent) 'Confirm consent to calculate this chart.',
    ];
    if (missing.isNotEmpty) {
      setState(() => _error = missing.first);
      return;
    }
    if (_date!.isAfter(latestEligibleBirthDate(DateTime.now()))) {
      setState(
        () => _error = 'Jyotara supports personal birth profiles for people aged 13 or older.',
      );
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
          'preferredChatLanguage': _chatLanguage,
          'relationshipStatus': _relationship,
          'profession': _profession,
          'birthplaceLabel': _place![1] as String,
        });
      } else {
        await widget.session.calculate(
          dateTime: stamp,
          latitude: (_place![6] as num).toDouble(),
          longitude: (_place![7] as num).toDouble(),
          exactTime: !_unknown,
          refreshAccess: false,
          nickname: _nickname.text,
          gender: _gender,
          birthplaceLabel: _place![0] == 'saved'
              ? widget.session.birthplaceLabel
              : '${_place![1]}, ${_place![2]}',
        );
      }
      if (widget.onSubmit == null) {
        await widget.session.saveProfilePreferences(
          language: _chatLanguage,
          relationship: _relationship,
          occupation: _profession,
        );
      }
      userJourney.event(
        widget.session.revision > 1 ? 'profile.update' : 'profile.create',
        metadata: {
          'feature': 'profile',
          'control': 'save',
          'outcome': 'success',
        },
      );
      if (mounted) {
        if (widget.onCompleted != null) {
          widget.onCompleted!();
        } else {
          Navigator.of(context).pop();
        }
      }
    } on JyotaraApiException catch (e) {
      userJourney.event(
        'profile.update',
        metadata: {
          'feature': 'profile',
          'control': 'save',
          'outcome': 'failed',
          'error': 'provider',
        },
      );
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

  Widget _preference(
    String label,
    String value,
    List<String> options,
    void Function(String) assign, {
    Map<String, String> labels = const {},
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownMenu<String>(
      key: ValueKey('$label:$value'),
      initialSelection: options.contains(value) ? value : options.first,
      expandedInsets: EdgeInsets.zero,
      enabled: !_busy,
      requestFocusOnTap: false,
      menuHeight: 240,
      menuStyle: const MenuStyle(alignment: Alignment.bottomLeft),
      alignmentOffset: const Offset(0, 4),
      label: Text(uiText(context, label)),
      dropdownMenuEntries: [
        for (final v in options)
          DropdownMenuEntry(
            value: v,
            label:
                labels[v] ?? uiText(context, v.isEmpty ? 'Not specified' : v),
          ),
      ],
      onSelected: (v) {
        if (v != null) setState(() => assign(v));
      },
    ),
  );

  Widget _requiredLabel(String label, {TextStyle? style}) => Text.rich(
    TextSpan(
      text: uiText(context, label),
      children: [
        TextSpan(
          text: ' *',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
    ),
    style: style,
  );

  @override
  Widget build(BuildContext context) {
    if (widget.onboarding) return _buildOnboarding(context);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const UiText('Your birth profile')),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                BronzePalette.raised,
                BronzePalette.background,
                BronzePalette.background,
              ],
            ),
          ),
          child: ListView(
            key: const ValueKey('birth-details-list'),
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              const UiText(
                'Birth details · India (IST)',
                style: TextStyle(color: BronzePalette.gold),
              ),
              if (widget.session.facts != null) ...[
                const SizedBox(height: 12),
                const UiText(
                  'Update your birth details to refresh your chart.',
                ),
              ],
              const SizedBox(height: 20),
              TextField(
                controller: _nickname,
                enabled: !_busy,
                maxLength: 60,
                decoration: InputDecoration(
                  label: _requiredLabel('Enter full name'),
                  hintText: uiText(context, 'Enter full name'),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  filled: true,
                  fillColor: BronzePalette.card,
                ),
              ),
              _requiredLabel(
                'Gender',
                style: const TextStyle(color: BronzePalette.gold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in ProfileGender.values)
                    ChoiceChip(
                      key: ValueKey('gender-${option.value}'),
                      label: UiText(option.label),
                      selected: _gender == option,
                      selectedColor: BronzePalette.gold,
                      backgroundColor: BronzePalette.card,
                      labelStyle: TextStyle(
                        color: _gender == option
                            ? BronzePalette.onAccent
                            : BronzePalette.ink,
                      ),
                      onSelected: _busy
                          ? null
                          : (_) => setState(() {
                              _gender = option;
                              _error = null;
                            }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: _requiredLabel('Date of birth'),
                subtitle: UiText(
                  _date == null
                      ? 'Select date'
                      : '${_date!.day}/${_date!.month}/${_date!.year}',
                ),
                trailing: const Icon(Icons.calendar_month),
                onTap: _busy
                    ? null
                    : () async {
                        FocusScope.of(context).unfocus();
                        final now = DateTime.now();
                        final latest = latestEligibleBirthDate(now);
                        final date = await showBirthDatePicker(
                          context: context,
                          initialDate: _date == null || _date!.isAfter(latest)
                              ? latest
                              : _date!.isBefore(DateTime(1900))
                              ? DateTime(1900)
                              : _date!,
                          firstDate: DateTime(1900),
                          lastDate: latest,
                        );
                        if (date != null && mounted) {
                          setState(() => _date = date);
                        }
                      },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const UiText('I don’t know my exact birth time'),
                value: _unknown,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _unknown = value),
              ),
              if (!_unknown)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: _requiredLabel('Exact birth time'),
                  subtitle: UiText(
                    _time?.format(context) ?? 'Select time (AM/PM)',
                  ),
                  trailing: const Icon(Icons.schedule),
                  onTap: _busy
                      ? null
                      : () async {
                          FocusScope.of(context).unfocus();
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
                  'General guidance only. You can add your birth time later.',
                ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('birthplaceField'),
                controller: _placeQuery,
                enabled: !_busy,
                readOnly: true,
                onTap: _busy ? null : _pickPlace,
                decoration: InputDecoration(
                  label: _requiredLabel('Birthplace'),
                  hintText: uiText(context, 'For example: Erode'),
                  helperText: uiText(
                    context,
                    _place == null
                        ? 'Choose a search result.'
                        : 'Birthplace selected',
                  ),
                  suffixIcon: _place == null
                      ? const Icon(Icons.search)
                      : IconButton(
                          tooltip: uiText(context, 'Clear birthplace'),
                          icon: const Icon(Icons.clear),
                          onPressed: _busy ? null : _clearPlace,
                        ),
                ),
              ),
              const UiText(
                'Location data: GeoNames (CC BY 4.0); OpenStreetMap contributors (ODbL) · openstreetmap.org/copyright',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 18),
              _preference(
                'Preferred chatting language',
                _chatLanguage,
                ['english', 'tamil', 'tanglish'],
                (v) => _chatLanguage = v,
                labels: {
                  'english': 'English',
                  'tamil': 'தமிழ்',
                  'tanglish': 'Tanglish',
                },
              ),
              _preference(
                'Relationship status (optional)',
                _relationship,
                ProfileSession.relationshipOptions,
                (v) => _relationship = v,
              ),
              _preference(
                'Profession (optional)',
                _profession,
                ProfileSession.professionOptions,
                (v) => _profession = v,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _consent,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _consent = value ?? false),
                title: const UiText(
                  'I am 13+ and agree to use my birth details for readings.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const UiText(
                  'Privacy details',
                  style: TextStyle(fontSize: 14),
                ),
                children: [
                  UiText(
                    'Full name, selected gender, birth details, your question and recent chat context go to our astrology service for chat readings. Its reading and your question go to our language service. Astrology conversations may remain with the service while requested deletion is pending. Your chart and chat history are saved in encrypted storage on this device. Delete them from the Chart tab. Creating a profile turns optional research sharing off; you can choose it separately in Account. For a connected profile, the Chart tab can also delete server chart and answer copies. Minimal usage records remain; backup copies expire within eight days.',
                  ),
                  const SizedBox(height: 12),
                  UiText(
                    'Retry recovery is separate from research: the server keeps an encrypted answer until this chart session expires (up to 24 hours). Expired copies are cleared when requests arrive, not on a guaranteed schedule. Request receipts remain to prevent duplicate usage.',
                  ),
                  const SizedBox(height: 12),
                  UiText(
                    'For same-day retry recovery, the server also keeps an encrypted chart response for up to 23 hours, separately from research consent. Expired copies are removed when chart requests arrive; scheduled deletion is not yet available.',
                  ),
                  const SizedBox(height: 12),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: UiText(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton(
                onPressed: _busy ? null : _calculate,
                child: UiText(
                  widget.onSubmit != null
                      ? (_busy ? 'Saving details…' : 'Use these birth details')
                      : (_busy ? 'Calculating your chart…' : 'Continue'),
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 12),
              const UiText('Readings offer guidance, not guaranteed outcomes.'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final latest = latestEligibleBirthDate(DateTime.now());
    final date = await showBirthDatePicker(
      context: context,
      initialDate: _date == null || _date!.isAfter(latest)
          ? latest
          : _date!.isBefore(DateTime(1900))
          ? DateTime(1900)
          : _date!,
      firstDate: DateTime(1900),
      lastDate: latest,
    );
    if (date != null && mounted) {
      setState(() {
        _date = date;
        _error = null;
      });
    }
  }

  Future<void> _pickTime() async {
    FocusScope.of(context).unfocus();
    final time = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 12, minute: 0),
    );
    if (time != null && mounted) {
      setState(() {
        _time = time;
        _error = null;
      });
    }
  }

  Widget _onboardingPicker(
    String label,
    String value,
    VoidCallback? onTap, {
    bool disabled = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      (disabled
          ? UiText(
              label,
              style: const TextStyle(fontSize: 13, color: onboardingInk),
            )
          : _requiredLabel(
              label,
              style: const TextStyle(
                fontFamily: 'JyotaraSans',
                fontSize: 13,
                color: onboardingInk,
              ),
            )),
      const SizedBox(height: 7),
      OnboardingGlass(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'JyotaraSans',
                  fontSize: 13,
                  color: disabled ? BronzePalette.muted : onboardingMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
  Widget _genderButton(ProfileGender option, IconData icon) => Expanded(
    child: OnboardingGlass(
      selected: _gender == option,
      child: InkWell(
        key: ValueKey('gender-${option.value}'),
        borderRadius: BorderRadius.circular(18),
        onTap: _busy
            ? null
            : () => setState(() {
                _gender = option;
                _error = null;
              }),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 21,
                color: _gender == option ? onboardingGold : onboardingInk,
              ),
              const SizedBox(width: 9),
              Flexible(
                child: UiText(
                  option.label,
                  style: const TextStyle(
                    fontFamily: 'JyotaraSans',
                    fontSize: 13,
                    color: onboardingInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _buildOnboarding(BuildContext context) => OnboardingTheme(
    child: PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: onboardingGreen,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: OnboardingBackdrop()),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ListView(
                    key: const ValueKey('birth-details-list'),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const OnboardingLogo(size: 34, sunOnly: true),
                          const SizedBox(width: 9),
                          Flexible(
                            child: Text(
                              'Jyotara',
                              style: onboardingHeading(32),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 34),
                      UiText('Made for you.', style: onboardingHeading(38)),
                      const SizedBox(height: 5),
                      const UiText(
                        'Start with your birth details.',
                        style: TextStyle(
                          fontFamily: 'JyotaraSans',
                          fontSize: 13,
                          letterSpacing: 0,
                          color: onboardingMuted,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _requiredLabel(
                        'Full name',
                        style: const TextStyle(
                          fontFamily: 'JyotaraSans',
                          fontSize: 13,
                          color: onboardingInk,
                        ),
                      ),
                      const SizedBox(height: 7),
                      OnboardingGlass(
                        child: TextField(
                          controller: _nickname,
                          enabled: !_busy,
                          maxLength: 60,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          decoration: onboardingInput(
                            hint: uiText(context, 'Enter full name'),
                          ),
                          style: const TextStyle(
                            fontFamily: 'JyotaraSans',
                            fontSize: 14,
                            color: onboardingInk,
                          ),
                        ),
                      ),
                      const SizedBox(height: 17),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _onboardingPicker(
                              'Birth date',
                              _date == null
                                  ? 'DD / MM / YYYY'
                                  : '${_date!.day.toString().padLeft(2, '0')} / ${_date!.month.toString().padLeft(2, '0')} / ${_date!.year}',
                              _busy ? null : _pickDate,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _onboardingPicker(
                              'Birth time',
                              _unknown
                                  ? uiText(context, 'Not known')
                                  : _time?.format(context) ?? 'HH : MM',
                              _busy || _unknown ? null : _pickTime,
                              disabled: _unknown,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: _unknown,
                            onChanged: _busy
                                ? null
                                : (v) => setState(() {
                                    _unknown = v ?? false;
                                    _error = null;
                                  }),
                          ),
                          const Expanded(
                            child: UiText(
                              'I don’t know my birth time',
                              style: TextStyle(
                                fontFamily: 'JyotaraSans',
                                fontSize: 12,
                                color: onboardingMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_unknown)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: UiText(
                            'General guidance only. You can add your birth time later.',
                            style: TextStyle(
                              fontSize: 12,
                              color: onboardingMuted,
                            ),
                          ),
                        ),
                      _requiredLabel(
                        'Gender',
                        style: const TextStyle(
                          fontFamily: 'JyotaraSans',
                          fontSize: 13,
                          color: onboardingInk,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          _genderButton(ProfileGender.male, Icons.male),
                          const SizedBox(width: 12),
                          _genderButton(ProfileGender.female, Icons.female),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: PopupMenuButton<ProfileGender>(
                          enabled: !_busy,
                          tooltip: uiText(context, 'More options'),
                          onSelected: (v) => setState(() {
                            _gender = v;
                            _error = null;
                          }),
                          itemBuilder: (context) => [
                            for (final option in [
                              ProfileGender.nonBinary,
                              ProfileGender.preferNotToSay,
                            ])
                              PopupMenuItem(
                                value: option,
                                child: UiText(option.label),
                              ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 4,
                            ),
                            child: UiText(
                              _gender == ProfileGender.nonBinary ||
                                      _gender == ProfileGender.preferNotToSay
                                  ? _gender!.label
                                  : 'More options',
                              style: const TextStyle(
                                fontFamily: 'JyotaraSans',
                                fontSize: 11,
                                color: onboardingGold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _requiredLabel(
                        'Birthplace',
                        style: const TextStyle(
                          fontFamily: 'JyotaraSans',
                          fontSize: 13,
                          color: onboardingInk,
                        ),
                      ),
                      const SizedBox(height: 7),
                      OnboardingGlass(
                        child: TextField(
                          key: const Key('birthplaceField'),
                          controller: _placeQuery,
                          enabled: !_busy,
                          readOnly: true,
                          onTap: _busy ? null : _pickPlace,
                          style: const TextStyle(
                            fontFamily: 'JyotaraSans',
                            fontSize: 14,
                            color: onboardingInk,
                          ),
                          decoration: onboardingInput(
                            hint: uiText(context, 'Search your town or city'),
                            prefix: const Icon(
                              Icons.search,
                              size: 22,
                              color: onboardingMuted,
                            ),
                            suffix: _place == null
                                ? null
                                : IconButton(
                                    tooltip: uiText(
                                      context,
                                      'Clear birthplace',
                                    ),
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: _busy ? null : _clearPlace,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Checkbox(
                            value: _consent,
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _consent = v ?? false),
                          ),
                          const Expanded(
                            child: UiText(
                              'I am 13+ and agree to use my birth details for readings.',
                              style: TextStyle(
                                fontFamily: 'JyotaraSans',
                                fontSize: 11,
                                color: onboardingMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: UiText(
                            _error!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFFFB4AB),
                            ),
                          ),
                        ),
                      OnboardingButton(
                        text: uiText(
                          context,
                          widget.onSubmit != null
                              ? (_busy
                                    ? 'Saving details…'
                                    : 'Use these birth details')
                              : (_busy
                                    ? 'Calculating your chart…'
                                    : 'Continue to Jyotara'),
                        ),
                        onPressed: _busy ? null : _calculate,
                        busy: _busy,
                      ),
                      const SizedBox(height: 12),
                      const UiText(
                        'You can edit these details later in Profile.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'JyotaraSans',
                          fontSize: 11,
                          color: onboardingMuted,
                        ),
                      ),
                      Center(
                        child: TextButton(
                          onPressed: () =>
                              PrivacyLinks.open(context, '/privacy'),
                          child: const UiText(
                            'Privacy & data use',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                      const UiText(
                        'Location data: GeoNames (CC BY 4.0); OpenStreetMap contributors (ODbL) · openstreetmap.org/copyright',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'JyotaraSans',
                          fontSize: 9,
                          color: onboardingMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
