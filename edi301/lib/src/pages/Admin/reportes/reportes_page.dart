// lib/src/pages/Admin/reportes/reportes_page.dart
import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:edi301/src/pages/Admin/get_family/get_family_controller.dart';
import 'package:edi301/models/family_model.dart' as fm;
import 'package:edi301/src/pages/Admin/reportes/reporte_familias_service.dart';

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  final GetFamilyController _searchController = GetFamilyController();
  final ReporteFamiliasService _reportService = ReporteFamiliasService();
  bool _isLoadingGeneral = false;
  final Map<int, bool> _loadingIndividual = {};

  @override
  void initState() {
    super.initState();
    _searchController.init(context);
    _searchController.searchNow();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _generarReporteGeneral() async {
    setState(() => _isLoadingGeneral = true);
    try {
      final path = await _reportService.generarReporteGeneral();
      if (mounted) {
        _snack('Reporte general guardado y abierto.', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _snack('Error al generar reporte general: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingGeneral = false);
      }
    }
  }

  Future<void> _generarReporteIndividual(int familiaId) async {
    setState(() => _loadingIndividual[familiaId] = true);
    try {
      final path = await _reportService.generarReporteIndividual(familiaId);
      if (mounted) {
        _snack('Reporte individual guardado y abierto.', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _snack('Error al generar reporte individual: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingIndividual[familiaId] = false);
      }
    }
  }

  void _snack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color.fromRGBO(19, 67, 107, 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generar Reportes PDF'),
        backgroundColor: primary,
      ),
      body: ResponsiveContent(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                icon: _isLoadingGeneral
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Icon(Icons.download_for_offline),
                label: Text(
                  _isLoadingGeneral
                      ? 'GENERANDO...'
                      : 'GENERAR REPORTE GENERAL',
                ),
                onPressed: _isLoadingGeneral ? null : _generarReporteGeneral,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),

            const Divider(thickness: 2),
            _textFieldSearch(),
            Expanded(
              child: ValueListenableBuilder<List<fm.Family>>(
                valueListenable: _searchController.results,
                builder: (_, families, __) {
                  if (families.isEmpty) {
                    return const Center(
                      child: Text('No se encontraron familias.'),
                    );
                  }
                  return _buildFamilyCards(families);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textFieldSearch() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 20),
      child: TextField(
        controller: _searchController.searchCtrl,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _searchController.searchNow(),
        decoration: InputDecoration(
          hintText: 'Buscar familia por nombre...',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color.fromRGBO(245, 188, 6, 1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(
              color: Color.fromRGBO(245, 188, 6, 1),
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.all(15),
          suffixIcon: IconButton(
            icon: const Icon(
              Icons.search,
              color: Color.fromRGBO(19, 67, 107, 1),
            ),
            onPressed: _searchController.searchNow,
          ),
        ),
      ),
    );
  }

  Widget _buildFamilyCards(List<fm.Family> families) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: families.length,
      itemBuilder: (context, index) {
        final f = families[index];
        final bool isLoading = _loadingIndividual[f.id ?? 0] ?? false;

        return Card(
          color: const Color.fromARGB(255, 255, 205, 40),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            title: Text(
              f.familyName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Padre: ${f.fatherName ?? 'N/A'}\nMadre: ${f.motherName ?? 'N/A'}',
            ),
            isThreeLine: true,
            trailing: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  )
                : IconButton(
                    icon: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.black54,
                      size: 30,
                    ),
                    tooltip: 'Generar PDF Individual',
                    onPressed: () {
                      if (f.id != null) {
                        _generarReporteIndividual(f.id!);
                      } else {
                        _snack('Error: Esta familia no tiene un ID.');
                      }
                    },
                  ),
          ),
        );
      },
    );
  }
}
