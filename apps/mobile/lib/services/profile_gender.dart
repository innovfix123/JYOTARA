/// User-supplied profile information, not an inferred chart attribute.
enum ProfileGender {
  male('male', 'Male'),
  female('female', 'Female'),
  nonBinary('non_binary', 'Non-binary'),
  preferNotToSay('prefer_not_to_say', 'Prefer not to say');

  const ProfileGender(this.value, this.label);
  final String value;
  final String label;

  static ProfileGender? fromStored(Object? value) {
    for (final gender in values) {
      if (gender.value == value) return gender;
    }
    // Missing/unknown metadata never invalidates an otherwise valid old chart.
    return null;
  }
}
