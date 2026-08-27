import 'package:equatable/equatable.dart';

enum GemmaModelType {
  gemma4E4B,
  gemma4E2B,
  customGGUF,
}

extension GemmaModelTypeExtension on GemmaModelType {
  String get displayName {
    switch (this) {
      case GemmaModelType.gemma4E4B:
        return 'Gemma 4 E4B (Balanced)';
      case GemmaModelType.gemma4E2B:
        return 'Gemma 4 E2B (Fast / Low-Power)';
      case GemmaModelType.customGGUF:
        return 'Custom Local Model (.gguf)';
    }
  }

  String get shortName {
    switch (this) {
      case GemmaModelType.gemma4E4B:
        return 'Gemma 4 E4B';
      case GemmaModelType.gemma4E2B:
        return 'Gemma 4 E2B';
      case GemmaModelType.customGGUF:
        return 'Custom GGUF';
    }
  }
}

class AiModelConfig with Equatable {
  final GemmaModelType modelType;
  final double temperature;
  final double topP;
  final int maxTokens;
  final String? customModelPath;

  const AiModelConfig({
    this.modelType = GemmaModelType.gemma4E4B,
    this.temperature = 0.7,
    this.topP = 0.9,
    this.maxTokens = 1024,
    this.customModelPath,
  });

  AiModelConfig copyWith({
    GemmaModelType? modelType,
    double? temperature,
    double? topP,
    int? maxTokens,
    String? customModelPath,
  }) {
    return AiModelConfig(
      modelType: modelType ?? this.modelType,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      maxTokens: maxTokens ?? this.maxTokens,
      customModelPath: customModelPath ?? this.customModelPath,
    );
  }

  @override
  List<Object?> get props => [modelType, temperature, topP, maxTokens, customModelPath];
}
