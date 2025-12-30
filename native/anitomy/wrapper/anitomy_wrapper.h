#ifndef ANITOMY_WRAPPER_H
#define ANITOMY_WRAPPER_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// C-compatible struct representing a parsed element
// Maps to ElementCategory enum from anitomy
typedef struct {
  int32_t kind;          // ElementCategory value
  const char *value_ptr; // UTF-8 encoded string value
} AnitomyElementC;

// C-compatible struct for parsing results
typedef struct {
  int64_t count;                 // Number of elements
  AnitomyElementC *elements_ptr; // Array of elements
} AnitomyResultC;

// Parse anime filename and return structured results
// Caller must call anitomy_free_result() to free memory
AnitomyResultC anitomy_parse(const char *input);

// Free memory allocated by anitomy_parse()
void anitomy_free_result(AnitomyResultC result);

#ifdef __cplusplus
}
#endif

#endif