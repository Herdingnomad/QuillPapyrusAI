import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:quill_papyrus_ai/models/file_node.dart';

/// Resolves asset paths (images, audio, attachments) against document location and workspace root.
class AssetResolverService {
  /// Resolves a given path string (e.g. `../Assets/Sketches/crop.png`, `Assets/VoiceNotes/note.m4a`, `file:///...`)
  /// to an absolute filesystem path that exists, or the best candidate path.
  static String? resolvePath({
    required String rawPath,
    String? currentDocUri,
    String? workspaceRoot,
    FileNode? workspaceTree,
  }) {
    var path = rawPath.trim();
    if (path.isEmpty) return null;

    // Strip leading file:// scheme if present
    if (path.startsWith('file://')) {
      path = Uri.parse(path).toFilePath();
    }

    // 1. Direct check: If absolute and exists
    if (p.isAbsolute(path)) {
      if (File(path).existsSync()) {
        return path;
      }
    }

    // 2. Relative to current document directory
    if (currentDocUri != null && currentDocUri.isNotEmpty) {
      final docDir = p.dirname(currentDocUri);
      final candidate = p.normalize(p.join(docDir, path));
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    // 3. Relative to workspace root
    if (workspaceRoot != null && workspaceRoot.isNotEmpty) {
      // Direct join
      final directCandidate = p.normalize(p.join(workspaceRoot, path));
      if (File(directCandidate).existsSync()) {
        return directCandidate;
      }

      // If path starts with ../ or ./, normalize from workspace root as well
      final cleanedRel = path.replaceFirst(RegExp(r'^\.\.[/\\]'), '').replaceFirst(RegExp(r'^\.[/\\]'), '');
      final altCandidate = p.normalize(p.join(workspaceRoot, cleanedRel));
      if (File(altCandidate).existsSync()) {
        return altCandidate;
      }

      // Check within standard asset folders
      final inSketches = p.join(workspaceRoot, 'Assets', 'Sketches', p.basename(path));
      if (File(inSketches).existsSync()) {
        return inSketches;
      }

      final inVoice = p.join(workspaceRoot, 'Assets', 'VoiceNotes', p.basename(path));
      if (File(inVoice).existsSync()) {
        return inVoice;
      }

      final inRaw = p.join(workspaceRoot, 'Assets', 'Raw-Exports', p.basename(path));
      if (File(inRaw).existsSync()) {
        return inRaw;
      }
    }

    // 4. Search in workspace tree by filename if tree is provided
    if (workspaceTree != null) {
      final base = p.basename(path).toLowerCase();
      FileNode? match = _findInTree(workspaceTree, base);
      if (match != null) {
        return match.uri;
      }
    }

    // 5. Fallback return normalized relative or absolute if currentDocUri is present
    if (currentDocUri != null) {
      return p.normalize(p.join(p.dirname(currentDocUri), path));
    }

    if (workspaceRoot != null) {
      return p.normalize(p.join(workspaceRoot, path));
    }

    return path;
  }

  static FileNode? _findInTree(FileNode node, String targetBaseName) {
    if (!node.isDirectory && node.name.toLowerCase() == targetBaseName) {
      return node;
    }
    for (final child in node.children) {
      final found = _findInTree(child, targetBaseName);
      if (found != null) return found;
    }
    return null;
  }

  /// Determines if a file extension represents an image
  static bool isImage(String path) {
    final ext = p.extension(path).toLowerCase();
    return ext == '.png' || ext == '.jpg' || ext == '.jpeg' || ext == '.webp' || ext == '.gif';
  }

  /// Determines if a file extension represents audio
  static bool isAudio(String path) {
    final ext = p.extension(path).toLowerCase();
    return ext == '.m4a' || ext == '.aac' || ext == '.wav' || ext == '.mp3' || ext == '.ogg' || ext == '.flac';
  }
}
