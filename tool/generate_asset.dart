import 'dart:io';
import 'dart:convert';

void main() {
  final dir = Directory('assets');
  if (!dir.existsSync()) {
    dir.createSync();
  }
  
  // 1x1 Teal (#00A19B) PNG
  const base64Str = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNgWDgbAAHhAT349R39AAAAAElFTkSuQmCC';
  
  final file = File('assets/app_icon.png');
  file.writeAsBytesSync(base64Decode(base64Str));
  
  print('Generated assets/app_icon.png');
}
