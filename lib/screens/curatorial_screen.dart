import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class CuratorialScreen extends StatefulWidget {
  final bool isAdmin; // Pass this from your user state if they are an admin

  const CuratorialScreen({Key? key, this.isAdmin = false}) : super(key: key);

  @override
  _CuratorialScreenState createState() => _CuratorialScreenState();
}

class _CuratorialScreenState extends State<CuratorialScreen> {
  // Using a stream to listen to approved posts
  Stream<QuerySnapshot> _getPosts() {
    Query query = FirebaseFirestore.instance
        .collection('curatorial_posts')
        .orderBy('timestamp', descending: true)
        .limit(20); // Basic pagination/limit

    if (!widget.isAdmin) {
      query = query.where('approved', isEqualTo: true);
    }

    return query.snapshots();
  }

  void _approvePost(String docId) {
    FirebaseFirestore.instance
        .collection('curatorial_posts')
        .doc(docId)
        .update({'approved': true});
  }

  void _deletePost(String docId) {
    FirebaseFirestore.instance.collection('curatorial_posts').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Curatorial', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_rounded, color: Colors.blueAccent),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SubmitWorkScreen(isAdmin: widget.isAdmin)),
              );
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getPosts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Something went wrong'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data!.docs;

          if (posts.isEmpty) {
            return const Center(
              child: Text('No works submitted yet.', style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              var post = posts[index].data() as Map<String, dynamic>;
              String docId = posts[index].id;
              bool isApproved = post['approved'] ?? false;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        child: const Icon(Icons.person, color: Colors.grey),
                      ),
                      title: const Text('Anonymous Student', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        post['timestamp'] != null 
                            ? DateTime.fromMillisecondsSinceEpoch(post['timestamp']).toString().split(' ')[0]
                            : 'Unknown date',
                      ),
                      trailing: !isApproved
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('Pending', style: TextStyle(color: Colors.orange, fontSize: 12)),
                            )
                          : null,
                    ),
                    // Image (Cached & Preserves Aspect Ratio)
                    if (post['imageUrl'] != null && post['imageUrl'].toString().isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: post['imageUrl'],
                        width: double.infinity,
                        fit: BoxFit.contain, // Prevents cropping
                        placeholder: (context, url) => Container(
                          height: 300,
                          color: Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                      ),
                    // Title and Description
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(post['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(post['description'] ?? '', style: TextStyle(color: Colors.grey[700])),
                        ],
                      ),
                    ),
                    // Admin Controls
                    if (widget.isAdmin)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (!isApproved)
                              TextButton(
                                onPressed: () => _approvePost(docId),
                                child: const Text('Approve', style: TextStyle(color: Colors.green)),
                              ),
                            TextButton(
                              onPressed: () => _deletePost(docId),
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------
// SUBMIT SCREEN (Handles Image Picking & Compression)
// ---------------------------------------------------------
class SubmitWorkScreen extends StatefulWidget {
  final bool isAdmin;
  const SubmitWorkScreen({Key? key, required this.isAdmin}) : super(key: key);

  @override
  _SubmitWorkScreenState createState() => _SubmitWorkScreenState();
}

class _SubmitWorkScreenState extends State<SubmitWorkScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  
  File? _imageFile;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndCompressImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    File rawFile = File(pickedFile.path);
    
    // Compress Image
    final dir = await getTemporaryDirectory();
    final targetPath = '${dir.absolute.path}/temp_${const Uuid().v4()}.jpg';
    
    var result = await FlutterImageCompress.compressAndGetFile(
      rawFile.absolute.path, 
      targetPath,
      quality: 85, // High quality, small file size
      minWidth: 1920,
      minHeight: 1080,
    );

    if (result != null) {
      setState(() {
        _imageFile = File(result.path);
      });
    }
  }

  Future<void> _submitPost() async {
    if (_titleController.text.isEmpty || _descController.text.isEmpty || _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields and select an image')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1. Upload to Firebase Storage
      String fileName = 'curatorial/${const Uuid().v4()}.jpg';
      Reference ref = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = ref.putFile(_imageFile!);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // 2. Save to Firestore
      await FirebaseFirestore.instance.collection('curatorial_posts').add({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'imageUrl': downloadUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'approved': widget.isAdmin, // Admins auto-approve
      });

      if (mounted) {
        Navigator.pop(context); // Go back to feed
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work submitted!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Work', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _pickAndCompressImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(_imageFile!, fit: BoxFit.contain),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload, size: 50, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Tap to select photo', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isUploading ? null : _submitPost,
              child: _isUploading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Submit', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
