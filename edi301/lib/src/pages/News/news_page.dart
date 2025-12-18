import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
        title: const Text(
          'Bienvenido, Aldahir Ballina',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {
              _showNotificationsDialog(context);
            },
          ),
        ],
      ),
      body: ResponsiveContent(
        child: ListView(
          children: const [
            CustomPostWidget(
              familyName: 'Familia Ballina Nuñez',
              authorName: 'Aldahir Ballina',
              imageUrl:
                  'https://mott.pe/noticias/wp-content/uploads/2019/03/los-50-paisajes-maravillosos-del-mundo-para-tomar-fotos.jpg',
            ),
            CustomPostWidget(
              familyName: 'Familia Ballina Nuñez',
              authorName: 'Aldahir Ballina',
              imageUrl:
                  'https://mott.pe/noticias/wp-content/uploads/2019/03/la-isla-bora-bora-en-la-polinesia-francesa.jpg',
            ),
          ],
        ),
      ),
    );
  }
}

void _showNotificationsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text('Notificaciones'),
      content: SizedBox(
        width: 600,
        child: ListView(
          shrinkWrap: true,
          children: [
            _buildNotificationItem(
              icon: Icons.cake_outlined,
              color: Colors.pink,
              text: 'Hoy es el cumpleaños de Juan Pérez.',
            ),
            _buildNotificationItem(
              icon: Icons.event,
              color: Colors.blue,
              text: 'Reunión familiar programada para mañana a las 6 PM.',
            ),
            _buildNotificationItem(
              icon: Icons.post_add,
              color: Colors.green,
              text: 'La familia López ha publicado nuevas fotos.',
            ),
            _buildNotificationItem(
              icon: Icons.star_border,
              color: Colors.amber,
              text: 'No olvides calificar tu experiencia reciente.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

Widget _buildNotificationItem({
  required IconData icon,
  required Color color,
  required String text,
}) {
  return ResponsiveContent(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    ),
  );
}

class CustomPostWidget extends StatefulWidget {
  final String familyName;
  final String authorName;
  final String imageUrl;
  final double width;

  const CustomPostWidget({
    super.key,
    required this.familyName,
    required this.authorName,
    required this.imageUrl,
    this.width = 300.0,
  });

  @override
  State<CustomPostWidget> createState() => _CustomPostWidgetState();
}

class _CustomPostWidgetState extends State<CustomPostWidget> {
  bool isLiked = false; // Estado para el botón de "me gusta"
  List<String> comments = [
    "¡Hermosa vista!",
    "Me encanta esta foto",
  ]; // Comentarios iniciales

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[400],
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.familyName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'By ${widget.authorName}',
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 1.0,
            child: Image.network(
              widget.imageUrl,
              fit: BoxFit.cover,
              // loader
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              // en errores
              errorBuilder: (context, error, stack) {
                return const Center(child: Icon(Icons.broken_image, size: 64));
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.black,
                  ),
                  onPressed: () {
                    setState(() {
                      isLiked = !isLiked; // Alternar el estado de "me gusta"
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () {
                    _showCommentsDialog(
                      context,
                    ); // Mostrar cuadro de comentarios
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCommentsDialog(BuildContext context) {
    TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permitir que el cuadro ocupe más espacio
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets, // Ajustar para el teclado
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              const Text(
                'Comentarios',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const Divider(),
              ListView.builder(
                shrinkWrap: true,
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  return ListTile(title: Text(comments[index]));
                },
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: TextField(
                  controller: commentController,
                  decoration: InputDecoration(
                    hintText: 'Agregar un comentario...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (commentController.text.isNotEmpty) {
                    setState(() {
                      comments.add(commentController.text);
                    });
                  }
                  commentController.clear();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
                ),
                child: const Text(
                  'Agregar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
