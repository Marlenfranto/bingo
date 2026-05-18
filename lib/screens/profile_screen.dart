// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../providers/app_providers.dart';
// import '../models/user.dart';
// import 'package:url_launcher/url_launcher.dart';

// class ProfileScreen extends ConsumerStatefulWidget {
//   const ProfileScreen({super.key});

//   @override
//   ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
// }

// class _ProfileScreenState extends ConsumerState<ProfileScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _nameController = TextEditingController();
//   final _linkedinController = TextEditingController();
//   final _profilePictureController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       final currentUser = ref.read(currentUserProvider);
//       if (currentUser != null) {
//         _nameController.text = currentUser.name;
//         _linkedinController.text = currentUser.linkedinUrl;
//         _profilePictureController.text = currentUser.profilePictureUrl ?? '';
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _linkedinController.dispose();
//     _profilePictureController.dispose();
//     super.dispose();
//   }

//   String? _validateLinkedInUrl(String? value) {
//     if (value == null || value.isEmpty) {
//       return 'Please enter your LinkedIn URL';
//     }
    
//     // Basic LinkedIn URL validation
//     final linkedinPattern = RegExp(
//       r'^https:\/\/(www\.)?linkedin\.com\/in\/[a-zA-Z0-9\-]+\/?$',
//       caseSensitive: false,
//     );
    
//     if (!linkedinPattern.hasMatch(value)) {
//       return 'Please enter a valid LinkedIn profile URL\n(e.g., https://linkedin.com/in/yourprofile)';
//     }
    
//     return null;
//   }

//   Future<void> _saveProfile() async {
//     if (_formKey.currentState!.validate()) {
//       final currentUser = ref.read(currentUserProvider);
//       final newUser = User(
//         id: currentUser?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
//         name: _nameController.text.trim(),
//         linkedinUrl: _linkedinController.text.trim(),
//         profilePictureUrl: _profilePictureController.text.trim().isEmpty 
//           ? null 
//           : _profilePictureController.text.trim(),
//         scannedBoxes: currentUser?.scannedBoxes ?? {},
//       );

//       await ref.read(currentUserProvider.notifier).updateUser(newUser);
      
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Profile saved successfully!'),
//             backgroundColor: Colors.green,
//           ),
//         );
//         Navigator.pop(context);
//       }
//     }
//   }

//   Future<void> _openLinkedInHelp() async {
//     const url = 'https://linkedin.com/help/linkedin/answer/a542685';
//     if (await canLaunchUrl(Uri.parse(url))) {
//       await launchUrl(Uri.parse(url));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final currentUser = ref.watch(currentUserProvider);

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Profile'),
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//         actions: [
//           IconButton(
//             onPressed: _openLinkedInHelp,
//             icon: const Icon(Icons.help_outline),
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               // Profile info card
//               Card(
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Icon(
//                             Icons.person,
//                             size: 32,
//                             color: Theme.of(context).primaryColor,
//                           ),
//                           const SizedBox(width: 12),
//                           Text(
//                             'Your Profile',
//                             style: Theme.of(context).textTheme.headlineSmall,
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 8),
//                       const Text(
//                         'This information will be used when sending LinkedIn connection requests.',
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
              
//               const SizedBox(height: 24),
              
//               // Name field
//               TextFormField(
//                 controller: _nameController,
//                 decoration: const InputDecoration(
//                   labelText: 'Full Name',
//                   prefixIcon: Icon(Icons.person_outline),
//                   border: OutlineInputBorder(),
//                   hintText: 'Enter your full name',
//                 ),
//                 validator: (value) {
//                   if (value == null || value.trim().isEmpty) {
//                     return 'Please enter your name';
//                   }
//                   return null;
//                 },
//               ),
              
//               const SizedBox(height: 16),
              
//               // LinkedIn URL field
//               TextFormField(
//                 controller: _linkedinController,
//                 decoration: InputDecoration(
//                   labelText: 'LinkedIn Profile URL',
//                   prefixIcon: const Icon(Icons.link),
//                   border: const OutlineInputBorder(),
//                   hintText: 'https://linkedin.com/in/yourprofile',
//                   suffixIcon: IconButton(
//                     onPressed: _openLinkedInHelp,
//                     icon: const Icon(Icons.help_outline),
//                   ),
//                 ),
//                 validator: _validateLinkedInUrl,
//                 keyboardType: TextInputType.url,
//               ),
              
//               const SizedBox(height: 8),
              
//               // LinkedIn help text
//               Card(
//                 color: Colors.blue.shade50,
//                 child: Padding(
//                   padding: const EdgeInsets.all(12.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Icon(Icons.info_outline, 
//                                color: Colors.blue, size: 16),
//                           const SizedBox(width: 8),
//                           const Text(
//                             'How to find your LinkedIn URL:',
//                             style: TextStyle(fontWeight: FontWeight.bold),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 8),
//                       const Text(
//                         '1. Go to your LinkedIn profile\n'
//                         '2. Click "Public profile & URL" in the right sidebar\n'
//                         '3. Copy the URL from "Your public profile URL"',
//                         style: TextStyle(fontSize: 12),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
              
//               const SizedBox(height: 24),
              
//               // Statistics (if user exists)
//               if (currentUser != null)
//                 Card(
//                   color: Colors.green.shade50,
//                   child: Padding(
//                     padding: const EdgeInsets.all(16.0),
//                     child: Column(
//                       children: [
//                         Row(
//                           children: [
//                             Icon(Icons.analytics, color: Colors.green.shade700),
//                             const SizedBox(width: 8),
//                             Text(
//                               'Your Statistics',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.green.shade700,
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 12),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceAround,
//                           children: [
//                             Column(
//                               children: [
//                                 Text(
//                                   '${currentUser.scannedBoxes.length}',
//                                   style: Theme.of(context).textTheme.headlineMedium?.copyWith(
//                                     color: Colors.green.shade700,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                                 const Text('Scanned'),
//                               ],
//                             ),
//                             Column(
//                               children: [
//                                 Text(
//                                   '${25 - currentUser.scannedBoxes.length}',
//                                   style: Theme.of(context).textTheme.headlineMedium?.copyWith(
//                                     color: Colors.orange.shade700,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                                 const Text('Remaining'),
//                               ],
//                             ),
//                             Column(
//                               children: [
//                                 Text(
//                                   '${(currentUser.scannedBoxes.length / 25 * 100).toInt()}%',
//                                   style: Theme.of(context).textTheme.headlineMedium?.copyWith(
//                                     color: Colors.blue.shade700,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                                 const Text('Complete'),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
              
//               const Spacer(),
              
//               // Save button
//               ElevatedButton.icon(
//                 onPressed: _saveProfile,
//                 icon: const Icon(Icons.save),
//                 label: const Text('Save Profile'),
//                 style: ElevatedButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(vertical: 16),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }