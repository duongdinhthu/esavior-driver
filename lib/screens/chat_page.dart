import 'package:flutter/material.dart';

class ChatMessage {
  final String message;
  ChatMessage({required this.message});
}

class ChatPage extends StatefulWidget {
  final List<ChatMessage> messages;
  final Function(String) sendMessage;

  ChatPage({required this.messages, required this.sendMessage});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  TextEditingController messageController = TextEditingController();

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nhắn tin cho khách hàng'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: widget.messages.length,
                itemBuilder: (context, index) {
                  ChatMessage chatMessage = widget.messages[index];
                  return ListTile(
                    title: Text(chatMessage.message),
                  );
                },
              ),
            ),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                hintText: 'Nhập tin nhắn...',
              ),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () {
                    final message = messageController.text;
                    if (message.isNotEmpty) {
                      widget.sendMessage(message);
                      messageController.clear();
                    }
                  },
                  child: const Text('Gửi'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
