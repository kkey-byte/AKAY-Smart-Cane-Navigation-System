import 'package:flutter/material.dart';
import '../../models/patient_profile.dart';
import '../../services/app_session_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/shared/gabay_detail_page_scaffold.dart';

/// Only the signed-in user's supported profile fields are fetched.
class InformationHealthStatusPage extends StatefulWidget {
  const InformationHealthStatusPage({super.key});
  @override
  State<InformationHealthStatusPage> createState() =>
      _InformationHealthStatusPageState();
}

class _InformationHealthStatusPageState
    extends State<InformationHealthStatusPage> {
  late Future<ProfileBundle> _profile;
  late int _revision;
  @override
  void initState() {
    super.initState();
    _revision = AppSessionService.instance.identityRevision;
    _profile = ProfileService.instance.fetchProfile();
    AppSessionService.instance.addListener(_onSession);
  }

  void _onSession() {
    final revision = AppSessionService.instance.identityRevision;
    if (_revision == revision) return;
    _revision = revision;
    if (mounted) {
      setState(() {
        _profile = ProfileService.instance.fetchProfile();
      });
    }
  }

  @override
  void dispose() {
    AppSessionService.instance.removeListener(_onSession);
    super.dispose();
  }

  String _value(String? value) =>
      value == null || value.trim().isEmpty ? 'Not provided' : value;
  @override
  Widget build(BuildContext context) => GabayDetailPageScaffold(
    title: 'Information & Health Status',
    subtitle: 'Your saved profile information',
    body: FutureBuilder<ProfileBundle>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(semanticsLabel: 'Loading profile'),
          );
        }
        if (snapshot.hasError || !AppSessionService.instance.isLoggedIn) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Unable to load profile. Check your connection and sign-in.',
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _profile = ProfileService.instance.fetchProfile();
                  }),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        final bundle = snapshot.data!;
        final patient = bundle.patientProfile;
        final fields = <String, String>{
          'Name': _value(bundle.name),
          'Age': patient.age?.toString() ?? 'Not provided',
          'Gender': _value(patient.gender),
          'Blood Type': _value(patient.bloodType),
          'Medical Conditions': _value(patient.medicalConditions),
          'Allergies': _value(patient.allergies),
          'Emergency Contact': _value(patient.emergencyContact),
          'Address': _value(patient.address),
        };
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final field in fields.entries)
              ListTile(title: Text(field.key), subtitle: Text(field.value)),
          ],
        );
      },
    ),
  );
}
