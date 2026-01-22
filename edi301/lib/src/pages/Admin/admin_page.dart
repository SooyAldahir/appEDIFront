import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:edi301/src/pages/Admin/reportes/reporte_familias_service.dart';
import 'package:flutter/scheduler.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
        elevation: 0,
      ),
      body: ResponsiveContent(
        child: Column(
          children: [
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: CustomButton(
                label: 'Agregar Familia',
                onPressed: () => Navigator.pushNamed(context, 'add_family'),
                icon: const Icon(Icons.add_home, color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(height: 15),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: CustomButton(
                  label: 'Asignar Alumnos',
                  onPressed: () => Navigator.pushNamed(context, 'add_alumns'),
                  icon: const Icon(
                    Icons.person_add,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: CustomButton(
                label: 'Consultar Familias',
                onPressed: () => Navigator.pushNamed(context, 'get_family'),
                icon: const Icon(
                  Icons.visibility,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: CustomButton(
                label: 'Mi Agenda',
                onPressed: () => Navigator.pushNamed(context, 'agenda'),
                icon: const Icon(
                  Icons.calendar_month,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: CustomButton(
                label: 'Reportes PDF',
                onPressed: () => Navigator.pushNamed(context, 'reportes'),
                icon: const Icon(
                  Icons.picture_as_pdf,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: CustomButton(
                label: 'Cumpleaños',
                onPressed: () => Navigator.pushNamed(context, 'cumpleaños'),
                icon: const Icon(Icons.cake, color: Colors.white, size: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Widget icon;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromRGBO(245, 188, 6, 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          icon,
        ],
      ),
    );
  }
}
