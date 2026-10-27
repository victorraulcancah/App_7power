import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/address_entity.dart';
import '../../../domain/usecases/addresses_usecases.dart';
import '../../components/components.dart';
import '../../providers/addresses_provider.dart';

/// Crea o edita una dirección. Departamento, provincia y distrito se eligen en
/// cascada: cada nivel se pide al servidor cuando se elige el anterior.
class AddressFormPage extends StatefulWidget {
  /// Dirección que se edita; null para crear una nueva.
  final AddressEntity? address;

  const AddressFormPage({super.key, this.address});

  static Future<void> open(BuildContext context, {AddressEntity? address}) =>
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AddressFormPage(address: address)),
      );

  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _address =
      TextEditingController(text: widget.address?.fullAddress);
  late final TextEditingController _reference =
      TextEditingController(text: widget.address?.reference);
  late bool _isDefault = widget.address?.isDefault ?? false;

  List<UbigeoOption> _departments = const [];
  List<UbigeoOption> _provinces = const [];
  List<UbigeoOption> _districts = const [];
  UbigeoOption? _department;
  UbigeoOption? _province;
  UbigeoOption? _district;

  bool _loadingUbigeo = true;
  bool _saving = false;
  String? _ubigeoError;

  bool get _editing => widget.address != null;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _address.dispose();
    _reference.dispose();
    super.dispose();
  }

  GetUbigeoUseCase get _ubigeo => context.read<AddressesProvider>().ubigeo;

  /// Carga los departamentos y, al editar, también provincias y distritos para
  /// dejar elegida la ubicación actual de la dirección.
  Future<void> _loadDepartments() async {
    final result = await _ubigeo.departments();
    if (!mounted) return;

    List<UbigeoOption>? departments;
    result.fold(
      (f) => _ubigeoError = f.message,
      (list) => departments = list,
    );
    if (departments == null) {
      setState(() => _loadingUbigeo = false);
      return;
    }
    _departments = departments!;

    final a = widget.address;
    if (a?.departmentCode != null && a?.provinceCode != null) {
      _department =
          _departments.where((d) => d.code == a!.departmentCode).firstOrNull;
      if (_department != null) {
        await _loadProvinces(_department!);
        _province =
            _provinces.where((p) => p.code == a!.provinceCode).firstOrNull;
        if (_province != null) {
          await _loadDistricts(_department!, _province!);
          _district =
              _districts.where((d) => d.code == a!.districtCode).firstOrNull;
        }
      }
    }

    if (mounted) setState(() => _loadingUbigeo = false);
  }

  Future<void> _loadProvinces(UbigeoOption department) async {
    final result = await _ubigeo.provinces(department.code);
    result.fold((f) => _ubigeoError = f.message, (l) => _provinces = l);
  }

  Future<void> _loadDistricts(
    UbigeoOption department,
    UbigeoOption province,
  ) async {
    final result = await _ubigeo.districts(department.code, province.code);
    result.fold((f) => _ubigeoError = f.message, (l) => _districts = l);
  }

  Future<void> _onDepartment(UbigeoOption? value) async {
    setState(() {
      _department = value;
      _province = null;
      _district = null;
      _provinces = const [];
      _districts = const [];
    });
    if (value == null) return;
    await _loadProvinces(value);
    if (mounted) setState(() {});
  }

  Future<void> _onProvince(UbigeoOption? value) async {
    setState(() {
      _province = value;
      _district = null;
      _districts = const [];
    });
    if (value == null || _department == null) return;
    await _loadDistricts(_department!, value);
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final addresses = context.read<AddressesProvider>();
    final navigator = Navigator.of(context);

    setState(() => _saving = true);
    final error = await addresses.save(
      AddressDraft(
        fullAddress: _address.text.trim(),
        reference: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        // El id que se guarda es el del distrito.
        ubigeoId: _district?.ubigeoId ?? '',
        isDefault: _isDefault,
      ),
      id: widget.address?.id,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      AppSnackbar.error(context, error);
    } else {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar dirección' : 'Nueva dirección'),
      ),
      body: _loadingUbigeo
          ? const LoadingIndicator()
          : _departments.isEmpty
              ? ErrorState(
                  message: _ubigeoError ?? 'No se pudieron cargar las ubicaciones',
                  onRetry: () {
                    setState(() => _loadingUbigeo = true);
                    _loadDepartments();
                  },
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(AppConstants.defaultPadding),
                    children: [
                      _Dropdown(
                        label: 'Departamento',
                        value: _department,
                        options: _departments,
                        onChanged: _onDepartment,
                      ),
                      const SizedBox(height: 16),
                      _Dropdown(
                        label: 'Provincia',
                        value: _province,
                        options: _provinces,
                        onChanged: _onProvince,
                      ),
                      const SizedBox(height: 16),
                      _Dropdown(
                        label: 'Distrito',
                        value: _district,
                        options: _districts,
                        onChanged: (v) => setState(() => _district = v),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Dirección',
                        controller: _address,
                        prefixIcon: Icons.home_outlined,
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Ingresa la dirección' : null,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Indicaciones (opcional)',
                        controller: _reference,
                        maxLines: 2,
                        validator: (v) => (v ?? '').length > 500
                            ? 'Máximo 500 caracteres'
                            : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Usar como dirección predeterminada'),
                        value: _isDefault,
                        onChanged: (v) => setState(() => _isDefault = v),
                      ),
                      const SizedBox(height: 8),
                      AppButton(
                        label: 'Guardar',
                        isLoading: _saving,
                        onPressed: _save,
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final UbigeoOption? value;
  final List<UbigeoOption> options;
  final ValueChanged<UbigeoOption?> onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<UbigeoOption>(
      // `initialValue` solo cuenta al crearse: al cambiar el nivel anterior hay
      // que reconstruir el campo para que se vacíe.
      key: ValueKey('$label-${value?.ubigeoId}-${options.length}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        ),
      ),
      items: [
        for (final o in options)
          DropdownMenuItem(value: o, child: Text(o.name)),
      ],
      onChanged: options.isEmpty ? null : onChanged,
      validator: (v) => v == null ? 'Elige ${label.toLowerCase()}' : null,
    );
  }
}
