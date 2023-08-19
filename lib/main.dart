import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lazawebadder/products.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBhVLrOuL5EMg_GQzaoSpcN-KnxHbaQtAE",
      projectId: "laza-43014",
      messagingSenderId: "820533389903",
      appId: "1:820533389903:web:e2390cc5209d616f9c983a",
      storageBucket: "laza-43014.appspot.com",
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Laza Web Adder',
      theme: ThemeData(
        primarySwatch: Colors.grey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MyHomePage(title: 'Laza Web Adder'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Color> _selectedColors = [];
  List<Uint8List>? _selectedImages; // Update this line
  bool _uploadInProgress = false;


  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _offerPercentageController = TextEditingController();
  final TextEditingController _sizesController = TextEditingController();

  @override
  void initState() {
    super.initState();
   // fetchData();
  }

  Future<String?> uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(withReadStream: true);

    if (result != null) {
      PlatformFile file = result.files.first;

      Uint8List? fileBytes;
      if (file.readStream != null) {
        fileBytes = await file.readStream!.first as Uint8List?;
      } else {
        print("Error: Unable to read file bytes.");
        return null;
      }

      FirebaseStorage storage = FirebaseStorage.instance;
      Reference ref = storage.ref().child('english/photos/${file.name.split('.').first}');

      final mimeType = lookupMimeType(file.name);

      SettableMetadata metadata = SettableMetadata(contentType: mimeType);

      UploadTask uploadTask = ref.putData(fileBytes!, metadata);

      TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => {});
      String downloadURL = await taskSnapshot.ref.getDownloadURL();

      return downloadURL;
    } else {
      return null;
    }
  }

  void _showColorPickerDialog() {
    Color currentColor = Colors.black;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Product Color"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                ColorPicker(
                  pickerColor: currentColor,
                  onColorChanged: (Color newColor) {
                    setState(() {
                      currentColor = newColor;
                    });
                  },
                  pickerAreaHeightPercent: 0.8,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Selected Color:',
                  style: TextStyle(fontSize: 16),
                ),
                Container(
                  width: 40,
                  height: 40,
                  color: currentColor,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Select"),
              onPressed: () {
                setState(() {
                  _selectedColors.add(currentColor);
                });
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> uploadProduct() async {
    setState(() {
      _uploadInProgress = true;
    });
    if (validateInformation()) {
      List<String> images = await uploadImages();
      Product product = Product(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        lowercaseName: _nameController.text.trim().toLowerCase(),
        brand: _brandController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        offerPercentage: _offerPercentageController.text.trim().isEmpty
            ? null
            : double.parse(_offerPercentageController.text.trim()),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        colors: _selectedColors.isEmpty ? null : _selectedColors.map((color) => color.value).toList(),
        sizes: _sizesController.text.trim().isEmpty ? null : _sizesController.text.trim().split(','),
        images: images, // Use the image URLs here
      );

      await FirebaseFirestore.instance.collection('products').doc(product.id).set(product.toMap());
      resetFields();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product uploaded successfully.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check the required fields')),
      );
    }
    setState(() {
      _uploadInProgress = false;
    });
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      List<PlatformFile> files = result.files;

      List<Uint8List> fileBytesList = [];

      for (PlatformFile file in files) {
        try {
          Uint8List fileBytes = file.bytes!;
          fileBytesList.add(fileBytes);
        } catch (e) {
          print("Error reading file bytes: $e");
          return;
        }
      }

      setState(() {
        _selectedImages = fileBytesList;
        // You can also store the Uint8List fileBytesList if needed.
      });
    } else {
      return;
    }
  }

  Future<List<String>> uploadImages() async {
    List<String> downloadUrls = [];

    for (Uint8List imageBytes in _selectedImages!) {
      String imageName = const Uuid().v4();
      Reference storageRef = FirebaseStorage.instance.ref().child('products/images/$imageName');
      UploadTask uploadTask = storageRef.putData(imageBytes);
      TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => {});
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      downloadUrls.add(downloadUrl);
    }

    return downloadUrls;
  }

  void resetFields() {
    setState(() {
      _selectedImages = [];
      _selectedColors = [];
    });

    _nameController.clear();
    _brandController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _offerPercentageController.clear();
    _sizesController.clear();
  }

  bool validateInformation() {
    if (_priceController.text.trim().isEmpty) return false;
    if (_nameController.text.trim().isEmpty) return false;
    if (_brandController.text.trim().isEmpty) return false;
    if (_selectedImages!.isEmpty) return false;

    return true;
  }



  // CollectionReference dataList = FirebaseFirestore.instance.collection('products');
  // Future<void> fetchData() async {
  // //  QuerySnapshot querySnapshot = await dataList.get();
  //
  //   //List<DocumentSnapshot> allData = querySnapshot.docs;
  //
  //   // for (DocumentSnapshot doc in allData) {
  //   //   // print(doc.data());
  //   // }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black, // Change this to your desired color
        foregroundColor: Colors.white, // Change this to your desired color
      ),
      body: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Product general information:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'Name'),
              ),
              TextField(
                controller: _brandController,
                decoration: const InputDecoration(hintText: 'Brand'),
              ),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(hintText: 'Product description (Optional)'),
              ),
              TextField(
                controller: _priceController,
                decoration: const InputDecoration(hintText: 'Price', suffixText: '\$'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _offerPercentageController,
                decoration: const InputDecoration(hintText: 'Offer Percentage (Optional)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              const Text(
                'Product details:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _sizesController,
                decoration: const InputDecoration(hintText: 'Sizes (Optional) | use , between each new size'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _showColorPickerDialog,
                    child: const Text('Colors'),
                    // give color to the button
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, backgroundColor: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Text('Selected Colors'),
                  const SizedBox(width: 20),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: _selectedColors.map((color) => Container(
                      width: 40,
                      height: 40,
                      color: color,
                    )).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _pickFiles,
                    child: const Text('Images'),
                    // give color to the button
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white, backgroundColor: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 20),

                  Text('Selected Images: ${_selectedImages?.length}'),
                ],
              ),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: _selectedImages?.map((imageBytes) => Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: MemoryImage(imageBytes),
                      fit: BoxFit.cover,
                    ),
                  ),
                )).toList() ?? [],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      floatingActionButton: !_uploadInProgress
          ? FloatingActionButton(
        onPressed: uploadProduct,
        tooltip: 'Upload Product',
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      )
          : const CircularProgressIndicator(), // Show progress bar when upload is in progress
    );
  }
}
