import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:senpwai/shared/log.dart';
import 'package:senpwai/shared/shared.dart';

Logger log = Logger("senpwai.sources.shared.anitomy.ffi");

// Element category enum matching C++ ElementCategory from anitomy library
enum ElementCategory {
  kElementAnimeSeason,
  kElementAnimeSeasonPrefix,
  kElementAnimeTitle,
  kElementAnimeType,
  kElementAnimeYear,
  kElementAudioTerm,
  kElementDeviceCompatibility,
  kElementEpisodeNumber,
  kElementEpisodeNumberAlt,
  kElementEpisodePrefix,
  kElementEpisodeTitle,
  kElementFileChecksum,
  kElementFileExtension,
  kElementFileName,
  kElementLanguage,
  kElementOther,
  kElementReleaseGroup,
  kElementReleaseInformation,
  kElementReleaseVersion,
  kElementSource,
  kElementSubtitles,
  kElementVideoResolution,
  kElementVideoTerm,
  kElementVolumeNumber,
  kElementVolumePrefix,
  kElementUnknown,
}

class _Constants {
  static const devLibDir = "native/anitomy/wrapper/build";
  static const libName = "anitomy_wrapper";
  static const iosAndMacLibFilename = "lib$libName.dylib";
  static const androidAndLinuxLibFilename = "lib$libName.so";
  static const windowsLibFilename = "$libName.dll";
}

// FFI structure mapping for C AnitomyElementC struct
final class _AnitomyElementC extends Struct {
  @Int32()
  external int category;
  // ignore: non_constant_identifier_names
  external Pointer<Char> value_ptr;

  @override
  String toString() =>
      'AnitomyElementC(category: $category, value_ptr: $value_ptr)';
}

// FFI structure mapping for C AnitomyResultC struct
final class _AnitomyResultC extends Struct {
  @Int64()
  external int count;
  // ignore: non_constant_identifier_names
  external Pointer<_AnitomyElementC> elements_ptr;

  @override
  String toString() =>
      'AnitomyResultC(count: $count, elements_ptr: $elements_ptr)';
}

// Dart representation of a parsed anime filename element
class AnitomyElement {
  final ElementCategory category;
  final String value;

  const AnitomyElement(this.category, this.value);

  @override
  String toString() => 'AnitomyElement(category: $category, value: $value)';
}

class AnitomyFFI {
  final _AnitomyResultC Function(Pointer<Char>) _anitomyParse;
  final void Function(_AnitomyResultC) _anitomyFreeResult;
  // Primary constructor
  AnitomyFFI() : this._internal(_loadLibrary());

  AnitomyFFI._internal(DynamicLibrary lib)
    : _anitomyParse = lib
          .lookupFunction<
            _AnitomyResultC Function(Pointer<Char>),
            _AnitomyResultC Function(Pointer<Char>)
          >('anitomy_parse'),
      _anitomyFreeResult = lib
          .lookupFunction<
            Void Function(_AnitomyResultC),
            void Function(_AnitomyResultC)
          >('anitomy_free_result');

  static DynamicLibrary _loadLibrary() {
    log.info("Loading anitomy library");
    DynamicLibrary loadProdThenDev(String libFilename) {
      try {
        return DynamicLibrary.open(libFilename);
      } catch (e) {
        if (!kDebugMode) {
          rethrow;
        }
        final devLibPath = "${_Constants.devLibDir}/$libFilename";
        return DynamicLibrary.open(devLibPath);
      }
    }

    DynamicLibrary lib;

    if (Platform.isIOS || Platform.isMacOS) {
      lib = loadProdThenDev(_Constants.iosAndMacLibFilename);
    } else if (Platform.isAndroid || Platform.isLinux) {
      lib = loadProdThenDev(_Constants.androidAndLinuxLibFilename);
    } else if (Platform.isWindows) {
      lib = loadProdThenDev(_Constants.windowsLibFilename);
    } else {
      throw UnsupportedPlatformException();
    }

    log.fineWithMetadata("Successfully loaded anitomy library");
    return lib;
  }

  List<AnitomyElement> parse(String filename) {
    log.infoWithMetadata("Parsing filename", metadata: {"filename": filename});
    final inputPtr = filename.toNativeUtf8().cast<Char>();
    final result = _anitomyParse(inputPtr);
    log.infoWithMetadata("Raw parse result", metadata: {"result": result});
    final output = <AnitomyElement>[];

    try {
      for (var i = 0; i < result.count; i++) {
        final element = (result.elements_ptr + i).ref;
        final categoryIndex = element.category;

        // Validate category index is within enum range
        if (categoryIndex >= 0 &&
            categoryIndex < ElementCategory.values.length) {
          output.add(
            AnitomyElement(
              ElementCategory.values[categoryIndex],
              element.value_ptr.cast<Utf8>().toDartString(),
            ),
          );
        }
      }
    } finally {
      log.info("Freeing memory post-parse");
      _anitomyFreeResult(result);
      malloc.free(inputPtr);
      log.fine("Successfully freed memory post-parse");
    }

    log.fineWithMetadata(
      "Successfully parsed filename",
      metadata: {"filename": filename, "output": output},
    );

    return output;
  }
}
