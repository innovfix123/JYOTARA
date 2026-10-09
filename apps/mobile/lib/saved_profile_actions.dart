import 'package:flutter/material.dart';

import 'services/ui_language.dart';

String savedProfileText(BuildContext context, String english, String tamil) =>
    context
            .dependOnInheritedWidgetOfExactType<UiLanguageScope>()
            ?.notifier
            ?.value ==
        'ta'
    ? tamil
    : english;

/// Confirms deletion of one saved person, independently of account deletion.
Future<bool> confirmSavedProfileDeletion(
  BuildContext context, {
  required String name,
  bool? tamil,
  bool includesServer = true,
}) async {
  final inTamil =
      tamil ??
      context
              .dependOnInheritedWidgetOfExactType<UiLanguageScope>()
              ?.notifier
              ?.value ==
          'ta';
  final displayName = name.trim().isEmpty
      ? (inTamil ? 'இந்த நபர்' : 'this person')
      : name;
  return await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          scrollable: true,
          title: Text(
            inTamil
                ? '$displayName விவரங்களை நீக்கவா?'
                : 'Delete $displayName?',
          ),
          content: Text(
            includesServer
                ? (inTamil
                      ? 'இந்த நபரின் சேமித்த பிறப்பு விவரங்கள், ஜாதகம் மற்றும் உரையாடல்கள் நீக்கப்படும். உங்கள் சுயவிவரமும் மற்ற நபர்களின் விவரங்களும் சேமிக்கப்பட்டிருக்கும்.'
                      : 'This deletes this person’s saved birth details, chart and chats. Your own profile and other people stay saved.')
                : (inTamil
                      ? 'பொருத்தப் பகுதியில் சேமித்த இந்த நபரின் பிறப்பு விவரங்கள் நீக்கப்படும். உங்கள் சுயவிவரமும் மற்ற நபர்களின் விவரங்களும் சேமிக்கப்பட்டிருக்கும்.'
                      : 'This deletes this person’s saved birth details from Matching. Your own profile and other people stay saved.'),
          ),
          actions: [
            TextButton(
              key: const Key('cancel-saved-profile-delete'),
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(inTamil ? 'ரத்து' : 'Cancel'),
            ),
            FilledButton(
              key: const Key('confirm-saved-profile-delete'),
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(inTamil ? 'நபரை நீக்கு' : 'Delete person'),
            ),
          ],
        ),
      ) ??
      false;
}

class SavedProfileDeleteButton extends StatelessWidget {
  const SavedProfileDeleteButton({
    super.key,
    required this.onPressed,
    required this.name,
  });
  final VoidCallback? onPressed;
  final String name;

  @override
  Widget build(BuildContext context) => Semantics(
    label: savedProfileText(
      context,
      'Delete saved person $name',
      '$name விவரங்களை நீக்கு',
    ),
    child: TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.delete_outline, size: 18),
      label: Text(savedProfileText(context, 'Delete person', 'நபரை நீக்கு')),
    ),
  );
}
