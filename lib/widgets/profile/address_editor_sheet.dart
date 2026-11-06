import '../../theme/gabay_typography.dart';
import '../shared/gabay_accent_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/profile_address.dart';
import '../../services/philippine_address_service.dart';
import '../../theme/gabay_theme.dart';
import '../shared/gabay_selection_dialog.dart';

class AddressEditorSheet extends StatefulWidget {
  const AddressEditorSheet({
    super.key,
    required this.initialAddress,
    this.service,
  });
  final String initialAddress;
  final PhilippineAddressService? service;
  @override
  State<AddressEditorSheet> createState() => _AddressEditorSheetState();
}

class _AddressEditorSheetState extends State<AddressEditorSheet> {
  final _form = GlobalKey<FormState>();
  final _postal = TextEditingController(), _street = TextEditingController();
  late final PhilippineAddressService _service;
  List<AddressPlace> _regions = [],
      _provinces = [],
      _cities = [],
      _barangays = [];
  AddressPlace? _region, _province, _city, _barangay;
  bool _loading = true;
  String? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PhilippineAddressService();
    final initial = ProfileAddress.tryParse(widget.initialAddress);
    _postal.text = initial?.postalCode ?? '';
    _street.text = initial?.street ?? '';
    _initialize(initial);
  }

  AddressPlace? _match(List<AddressPlace> places, String? name) =>
      places.where((place) => place.name == name).firstOrNull;
  Future<void> _initialize(ProfileAddress? initial) async {
    await _run(() async {
      _regions = await _service.regions();
      _region = _match(_regions, initial?.region);
      if (_region == null) return;
      _provinces = [
        ...await _service.provinces(_region!.code),
        const AddressPlace('', 'Not applicable'),
      ];
      _province = _match(_provinces, initial?.province);
      if (_provinces.length == 1) _province = _provinces.first;
      if (_province == null) return;
      _cities = await _service.cities(
        _region!.code,
        _province!.code.isEmpty ? null : _province!.code,
      );
      _city = _match(_cities, initial?.city);
      if (_city == null) return;
      _barangays = await _service.barangays(_city!.code);
      _barangay = _match(_barangays, initial?.barangay);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    final version = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted && version == _request) {
        _error =
            'Could not load address choices. Check your internet connection and retry.';
      }
    } finally {
      if (mounted && version == _request) setState(() => _loading = false);
    }
  }

  Future<void> _selectRegion(AddressPlace place) => _run(() async {
    _region = place;
    _province = _city = _barangay = null;
    _provinces = [];
    _cities = [];
    _barangays = [];
    _provinces = [
      ...await _service.provinces(place.code),
      const AddressPlace('', 'Not applicable'),
    ];
    if (_provinces.length == 1) {
      _province = const AddressPlace('', 'Not applicable');
      _cities = await _service.cities(place.code, null);
    }
  });
  Future<void> _selectProvince(AddressPlace place) => _run(() async {
    _province = place;
    _city = _barangay = null;
    _cities = [];
    _barangays = [];
    _cities = await _service.cities(
      _region!.code,
      place.code.isEmpty ? null : place.code,
    );
  });
  Future<void> _selectCity(AddressPlace place) => _run(() async {
    _city = place;
    _barangay = null;
    _barangays = [];
    _barangays = await _service.barangays(place.code);
  });
  Future<void> _choose(
    String title,
    List<AddressPlace> options,
    void Function(AddressPlace) select,
    AddressPlace? selected,
  ) async {
    final choice = await showGabaySelectionDialog<AddressPlace>(
      context,
      title: 'Select $title',
      searchable: true,
      selectedValue: options
          .where((place) => place.code == selected?.code)
          .firstOrNull,
      options: [
        for (final place in options)
          GabaySelectionOption(
            value: place,
            child: Text(place.name),
            searchText: place.name,
          ),
      ],
    );
    if (choice != null && mounted) select(choice);
  }

  @override
  void dispose() {
    _request++;
    _postal.dispose();
    _street.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Widget _choice(
    String label,
    AddressPlace? selected,
    List<AddressPlace> options,
    void Function(AddressPlace) select,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: FormField<AddressPlace>(
      key: ValueKey('$label:${selected?.code}'),
      initialValue: selected,
      validator: (_) => selected == null ? 'Select $label' : null,
      builder: (field) => InkWell(
        onTap: _loading || options.isEmpty
            ? null
            : () => _choose(label, options, select, selected),
        borderRadius: BorderRadius.circular(16),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            errorText: field.errorText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            suffixIcon: const GabayAccentIcon(
              Icons.keyboard_arrow_down_rounded,
            ),
          ),
          child: Text(
            selected?.name ?? 'Select $label',
            style: TextStyle(
              color: context.gabay.textPrimary,
              fontSize: GabayTypography.body,
              fontWeight: GabayTypography.regular,
            ),
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .86,
          ),
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      GabayAccentIcon(
                        Icons.location_on_outlined,
                        color: g.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Address details',
                          style: TextStyle(
                            color: g.textPrimary,
                            fontSize: GabayTypography.pageTitle,
                            fontWeight: GabayTypography.regular,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.initialAddress.isNotEmpty &&
                      ProfileAddress.tryParse(widget.initialAddress) ==
                          null) ...[
                    Text(
                      'Existing address: ${widget.initialAddress}',
                      style: TextStyle(
                        color: g.textSecondary,
                        fontSize: GabayTypography.supporting,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_loading)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Loading address choices',
                    ),
                  if (_error != null) ...[
                    Text(_error!, style: TextStyle(color: g.danger)),
                    TextButton(
                      onPressed: () {
                        if (_city != null) {
                          _selectCity(_city!);
                        } else if (_province != null) {
                          _selectProvince(_province!);
                        } else if (_region != null) {
                          _selectRegion(_region!);
                        } else {
                          _initialize(
                            ProfileAddress.tryParse(widget.initialAddress),
                          );
                        }
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _choice('Region', _region, _regions, _selectRegion),
                  _choice('Province', _province, _provinces, _selectProvince),
                  _choice('City / Municipality', _city, _cities, _selectCity),
                  _choice(
                    'Barangay',
                    _barangay,
                    _barangays,
                    (place) => setState(() => _barangay = place),
                  ),
                  TextFormField(
                    controller: _postal,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: const InputDecoration(labelText: 'Postal Code'),
                    validator: (value) => value?.length == 4
                        ? null
                        : 'Enter a 4-digit postal code',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _street,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Street Name, Building, House No.',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter street or building details'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      textStyle: const TextStyle(
                        fontSize: GabayTypography.body,
                        fontWeight: GabayTypography.regular,
                      ),
                    ),
                    onPressed: _loading || _error != null
                        ? null
                        : () {
                            if (!_form.currentState!.validate()) return;
                            Navigator.pop(
                              context,
                              ProfileAddress(
                                region: _region!.name,
                                province: _province!.name,
                                city: _city!.name,
                                barangay: _barangay!.name,
                                postalCode: _postal.text,
                                street: _street.text.trim(),
                              ),
                            );
                          },
                    child: const Text('Use this address'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
