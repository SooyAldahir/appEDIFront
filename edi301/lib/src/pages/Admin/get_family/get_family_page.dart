import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:edi301/src/pages/Admin/get_family/get_family_controller.dart';
import 'package:edi301/models/family_model.dart' as fm;

class GetFamilyPage extends StatefulWidget {
  const GetFamilyPage({super.key});

  @override
  State<GetFamilyPage> createState() => _GetFamiliyPageState();
}

class _GetFamiliyPageState extends State<GetFamilyPage> {
  final GetFamilyController _controller = GetFamilyController();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await _controller.init(context);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regresar'),
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _textFieldSearch(),
            const SizedBox(height: 10),
            // 👇 results ahora es List<fm.Family>
            ValueListenableBuilder<List<fm.Family>>(
              valueListenable: _controller.results,
              builder: (_, families, __) {
                if (families.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No se encontraron familias.'),
                  );
                }
                return _buildFamilyCards(families);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _textFieldSearch() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 25),
      child: TextField(
        controller: _controller.searchCtrl,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _controller.searchNow(),
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
            onPressed: _controller.searchNow,
          ),
        ),
      ),
    );
  }

  Widget _buildFamilyCards(List<fm.Family> families) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: families.length,
      itemBuilder: (context, index) {
        final f = families[index];
        return Card(
          color: const Color.fromARGB(255, 255, 205, 40),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () {
              Navigator.pushNamed(context, 'family_detail', arguments: f);
            },
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.familyName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Padre: ${f.fatherName}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Madre: ${f.motherName}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Residencia: ${f.residence}',
                    style: TextStyle(
                      color: f.residence == 'Interna'
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
