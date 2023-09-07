import 'dart:async';

import 'package:analyzer/dart/element/type.dart';
import 'package:auto_mappr/src/extensions/dart_type_extension.dart';
import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as p;

/// Helper class for emitting and package import uri resolution.
class EmitterHelper {
  /// Global emitter so we can emit on the fly and all imports are preserved.
  final DartEmitter emitter = DartEmitter(
    allocator: Allocator.simplePrefixing(),
    orderDirectives: true,
    useNullSafetySyntax: true,
  );

  final Uri fileWithAnnotation;

  static Symbol get zoneSymbol => #autoMapprEmitter;
  static EmitterHelper get current => Zone.current[zoneSymbol] as EmitterHelper;

  EmitterHelper({required this.fileWithAnnotation});

  /// `refer` that is emitted to String using [emitter].
  String referEmitted(String symbol, [String? url]) {
    return refer(symbol, url).accept(emitter).toString();
  }

  /// [typeRefer] that is also emitted to String using [emitter].
  String typeReferEmitted({
    required DartType type,
    // Uri? targetFile,
    bool withNullabilitySuffix = true,
  }) {
    return '${typeRefer(type: type, withNullabilitySuffix: withNullabilitySuffix).accept(emitter)}';
  }

  /// Produces a reference to [type] with an import alias prefix.
  /// When [fileWithAnnotation] is also set, import is relative.
  ///
  /// Inspired by injectable.
  Reference typeRefer({
    required DartType type,
    bool withNullabilitySuffix = true,
  }) {
    final libraryPath = type.element?.library?.identifier;
    final importUrl = type.isPrimitiveType || type.isDartCoreObject
        ? _resolveAssetImport(libraryPath)
        : _relative(libraryPath, fileWithAnnotation);

    return TypeReference((reference) {
      reference
        ..symbol = type.element?.name
        ..url = importUrl
        ..isNullable = withNullabilitySuffix && type.isNullable;

      if (type is ParameterizedType && type.typeArguments.isNotEmpty) {
        reference.types.addAll(
          type.typeArguments.map((e) => typeRefer(type: e)),
        );
      }
    });
  }

  String? _relative(String? path, Uri? to) {
    if (path == null || to == null) {
      return null;
    }

    final fileUri = Uri.parse(path);
    final libName = to.pathSegments.firstOrNull;

    if ((to.scheme == 'package' && fileUri.scheme == 'package' && fileUri.pathSegments.firstOrNull == libName) ||
        (to.scheme == 'asset' && fileUri.scheme != 'package')) {
      if (fileUri.path == to.path) {
        return fileUri.pathSegments.lastOrNull;
      }

      return p.posix.relative(fileUri.path, from: to.path).replaceFirst('../', '');
    }

    return path;
  }

  String? _resolveAssetImport(String? path) {
    if (path == null) {
      return null;
    }

    final fileUri = Uri.parse(path);
    if (fileUri.scheme == 'asset') {
      return '/${fileUri.path}';
    }

    return path;
  }
}
