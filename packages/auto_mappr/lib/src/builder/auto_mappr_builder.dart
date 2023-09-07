// ignore_for_file: public_member_api_docs

import 'package:analyzer/dart/element/element.dart';
import 'package:auto_mappr/src/builder/map_model_body_method_builder.dart';
import 'package:auto_mappr/src/builder/methods/methods.dart';
import 'package:auto_mappr/src/extensions/dart_type_extension.dart';
import 'package:auto_mappr/src/helpers/emitter_helper.dart';
import 'package:auto_mappr/src/helpers/urls.dart';
import 'package:auto_mappr/src/models/auto_mappr_config.dart';
import 'package:auto_mappr/src/models/type_mapping.dart';
import 'package:built_collection/built_collection.dart';
import 'package:code_builder/code_builder.dart';

/// Entrypoint for mappr class generation.
class AutoMapprBuilder {
  final AutoMapprConfig config;
  final ClassElement mapperClassElement;

  static const List<String> fileIgnores = [
    'unnecessary_parenthesis',
    'non_constant_identifier_names',
    'unnecessary_const',
    'require_trailing_commas',
    'unnecessary_raw_strings',
    'unnecessary_lambdas',

    // Can we fix this somehow? (const defaults, const customs).
    'prefer_const_constructors',
    'prefer_const_literals_to_create_immutables',
  ];

  const AutoMapprBuilder({
    required this.config,
    required this.mapperClassElement,
  });

  Library build() {
    // TODO(modules): first process class and then generate library and its imports

    final generatedClass = Class(
      (cb) => cb
        ..name = '\$${mapperClassElement.displayName}'
        ..implements = ListBuilder([refer('AutoMapprInterface', Urls.annotationPackageUrl)])
        ..methods.addAll(_buildMethods())
        ..constructors.addAll(_buildConstructors())
        ..docs = ListBuilder(config.getAvailableMappingsDocComment()),
    );

    return Library(
      (b) => b
        ..ignoreForFile = ListBuilder(fileIgnores)
        ..body.addAll([generatedClass]),
    );
  }

  /// Generates all constructors within mapper.
  List<Constructor> _buildConstructors() {
    return [
      // Constant constructor to allow usage of modules.
      Constructor((builder) => builder..constant = true),
    ];
  }

  /// Generates all methods within mapper.
  List<Method> _buildMethods() {
    final nullableMappings = <TypeMapping>{};

    void usedNullableMappingMethod(TypeMapping? mapping) {
      if (mapping == null) return;

      final _ = nullableMappings.add(mapping);
    }

    // Generates non nullable mapping method.
    return [
      // Helper method for typeOf.
      TypeOfMethodBuilder(config).buildMethod(),

      // Getter method for modules from the annotation.
      PrivateModulesMethodBuilder(config).buildMethod(),

      // Public canConvert method.
      CanConvertMethodBuilder(config).buildMethod(),
      // Public convert method.
      ConvertMethodBuilder(config).buildMethod(),
      // Public tryConvert method.
      TryConvertMethodBuilder(config).buildMethod(),

      // Public convertIterable and tryConvertIterable methods.
      ConvertIterableMethodBuilder(config, wrapper: 'Iterable').buildMethod(),
      TryConvertIterableMethodBuilder(config, wrapper: 'Iterable').buildMethod(),

      // Public convertList and tryConvertList methods.
      ConvertIterableMethodBuilder(
        config,
        wrapper: 'List',
        iterableTransformer: 'toList',
      ).buildMethod(),
      TryConvertIterableMethodBuilder(
        config,
        wrapper: 'List',
        iterableTransformer: 'toList',
      ).buildMethod(),

      // Public convertSet and tryConvertSet methods.
      ConvertIterableMethodBuilder(
        config,
        wrapper: 'Set',
        iterableTransformer: 'toSet',
      ).buildMethod(),
      TryConvertIterableMethodBuilder(
        config,
        wrapper: 'Set',
        iterableTransformer: 'toSet',
      ).buildMethod(),

      // Internal convert method.
      PrivateConvertMethodBuilder(config).buildMethod(),

      // Generate non-nullable mapping method.
      // TODO(later): switch to MappingMethodBuilder.
      for (final mapping in config.mappers)
        Method(
          (b) => b
            ..name = mapping.mappingMethodName(config: config)
            ..requiredParameters.addAll([
              Parameter(
                (p) => p
                  ..name = 'input'
                  ..type = refer('${mapping.source.getDisplayStringWithLibraryAlias(config: config)}?'),
              ),
            ])
            ..returns = refer(
              mapping.target.getDisplayStringWithLibraryAlias(config: config),
            )
            ..body = MapModelBodyMethodBuilder(
              mapping: mapping,
              mapperConfig: config,
              usedNullableMethodCallback: usedNullableMappingMethod,
            ).build(),
        ),

      // Generates nullable mapping method only when nullable method is used.
      // TODO(later): switch to MappingMethodBuilder.
      for (final mapping in config.mappers.where(nullableMappings.contains))
        Method(
          (b) => b
            ..name = mapping.nullableMappingMethodName(config: config)
            ..requiredParameters.addAll([
              Parameter(
                (p) => p
                  ..name = 'input'
                  ..type = refer('${mapping.source.getDisplayStringWithLibraryAlias(config: config)}?'),
              ),
            ])
            ..returns = refer('${mapping.target.getDisplayStringWithLibraryAlias(
              withNullability: true,
              config: config,
            )}?')
            ..body = MapModelBodyMethodBuilder(
              mapping: mapping,
              mapperConfig: config,
              nullable: true,
            ).build(),
        ),
    ];
  }
}
