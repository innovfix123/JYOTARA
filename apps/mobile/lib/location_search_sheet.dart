import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'services/profile_session.dart';
import 'services/ui_language.dart';

Future<List<dynamic>?> pickIndianLocation(
  BuildContext context,
  ProfileSession session, {
  String initialQuery = '',
  String title = 'Birthplace',
}) => showModalBottomSheet<List<dynamic>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => LocationSearchSheet(
    session: session,
    initialQuery: initialQuery,
    title: title,
  ),
);

/// Shared by profile setup/edit, Matching, Daily city and Panchang location.
/// The results occupy their own viewport above the keyboard, never behind it.
class LocationSearchSheet extends StatefulWidget {
  const LocationSearchSheet({
    super.key,
    required this.session,
    this.initialQuery = '',
    this.title = 'Birthplace',
  });
  final ProfileSession session;
  final String initialQuery, title;
  @override
  State<LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<LocationSearchSheet> {
  late final query = TextEditingController(text: widget.initialQuery);
  Timer? debounce;
  int revision = 0;
  bool busy = false;
  String? error;
  List<List<dynamic>> rows = [];
  @override
  void initState() {
    super.initState();
    changed();
  }

  @override
  void dispose() {
    revision++;
    debounce?.cancel();
    query.dispose();
    super.dispose();
  }

  void changed() {
    debounce?.cancel();
    revision++;
    setState(() {
      rows = [];
      error = null;
      busy = false;
    });
    if (query.text.trim().length >= 3) {
      debounce = Timer(const Duration(milliseconds: 350), search);
    }
  }

  Future<void> search() async {
    debounce?.cancel();
    final text = query.text.trim();
    if (text.length < 3) return;
    final request = ++revision;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.session.searchLocations(text);
      if (!mounted || request != revision) return;
      setState(() {
        rows = result;
        error = rows.isEmpty
            ? 'No Indian birthplace found. Try the nearest town name in English.'
            : null;
      });
    } catch (_) {
      if (mounted && request == revision) {
        setState(() => error = 'Location search unavailable. Please retry.');
      }
    } finally {
      if (mounted && request == revision) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: math.max(
          180,
          size.height * .9 - keyboard - MediaQuery.viewPaddingOf(context).top,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: UiText(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: uiText(context, 'Close'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              TextField(
                key: const Key('location-search-query'),
                controller: query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: uiText(context, 'Town or city'),
                  hintText: uiText(context, 'For example: Erode'),
                  suffixIcon: IconButton(
                    tooltip: uiText(context, 'Clear search'),
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      query.clear();
                      changed();
                    },
                  ),
                ),
                onChanged: (_) => changed(),
                onSubmitted: (_) => search(),
              ),
              const SizedBox(height: 8),
              if (busy) const LinearProgressIndicator(),
              Expanded(
                child: ListView(
                  key: const Key('location-search-results'),
                  children: [
                    if (error != null) ...[
                      UiText(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      if (error == 'Location search unavailable. Please retry.')
                        TextButton(
                          onPressed: search,
                          child: const UiText('Retry'),
                        ),
                    ],
                    if (query.text.trim().length < 3)
                      const UiText('Type at least 3 characters.'),
                    for (final row in rows)
                      ListTile(
                        title: Text('${row[1]}, ${row[2]}'),
                        subtitle: const UiText('India · IST'),
                        onTap: () => Navigator.pop(context, row),
                      ),
                  ],
                ),
              ),
              const Text(
                'GeoNames · CC BY 4.0; OpenStreetMap · ODbL',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
