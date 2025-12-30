import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Element category enum matching C++ ElementCategory from anitomy library
enum ElementCategory {
  animeSeason,
  animeSeasonPrefix,
  animeTitle,
  animeType,
  animeYear,
  audioTerm,
  deviceCompatibility,
  episodeNumber,
  episodeNumberAlt,
  episodePrefix,
  episodeTitle,
  fileChecksum,
  fileExtension,
  fileName,
  language,
  other,
  releaseGroup,
  releaseInformation,
  releaseVersion,
  source,
  subtitles,
  videoResolution,
  videoTerm,
  volumeNumber,
  volumePrefix,
  unknown,
}

// FFI structure mapping for C AnitomyElementC struct
final class AnitomyElementC extends Struct {
  @Int32()
  external int category;
  // ignore: non_constant_identifier_names
  external Pointer<Char> value_ptr;
}

// FFI structure mapping for C AnitomyResultC struct
final class AnitomyResultC extends Struct {
  @Int64()
  external int count;
  // ignore: non_constant_identifier_names
  external Pointer<AnitomyElementC> elements_ptr;
}

DynamicLibrary loadAnitomyLibrary() {
  if (Platform.isMacOS || Platform.isIOS) {
    // For testing and development, load the explicit dylib
    // For production app, it will be bundled
    try {
      return DynamicLibrary.open('libanitomy_wrapper.dylib');
    } catch (e) {
      // Try from build directory
      return DynamicLibrary.open(
        'native/anitomy/wrapper/build/libanitomy_wrapper.dylib',
      );
    }
  }
  if (Platform.isWindows) return DynamicLibrary.open('anitomy_wrapper.dll');
  return DynamicLibrary.open('libanitomy_wrapper.so');
}

final DynamicLibrary _anitomyLib = loadAnitomyLibrary();

final _anitomyParse = _anitomyLib
    .lookupFunction<
      AnitomyResultC Function(Pointer<Char>),
      AnitomyResultC Function(Pointer<Char>)
    >('anitomy_parse');

final _anitomyFreeResult = _anitomyLib
    .lookupFunction<
      Void Function(AnitomyResultC),
      void Function(AnitomyResultC)
    >('anitomy_free_result');

// Dart representation of a parsed anime filename element
class AnitomyElement {
  final ElementCategory category;
  final String value;

  const AnitomyElement(this.category, this.value);

  @override
  String toString() => 'AnitomyElement(category: $category, value: $value)';
}

List<AnitomyElement> parseFilename(String filename) {
  final inputPtr = filename.toNativeUtf8().cast<Char>();
  final result = _anitomyParse(inputPtr);
  final output = <AnitomyElement>[];

  try {
    for (var i = 0; i < result.count; i++) {
      final element = (result.elements_ptr + i).ref;
      final categoryIndex = element.category;

      // Validate category index is within enum range
      if (categoryIndex >= 0 && categoryIndex < ElementCategory.values.length) {
        output.add(
          AnitomyElement(
            ElementCategory.values[categoryIndex],
            element.value_ptr.cast<Utf8>().toDartString(),
          ),
        );
      }
    }
  } finally {
    _anitomyFreeResult(result);
    malloc.free(inputPtr);
  }

  return output;
}
