#include "anitomy_wrapper.h"
#include "../anitomy/anitomy/anitomy.h"
#include <cstdlib>
#include <cstring>
#include <string>

// Parse anime filename and return structured elements
AnitomyResultC anitomy_parse(const char *input) {
  if (!input)
    return {0, nullptr};

  anitomy::Anitomy anitomy;
  std::wstring input_wide(input, input + strlen(input));

  if (!anitomy.Parse(input_wide))
    return {0, nullptr};

  const auto &elements = anitomy.elements();

  if (elements.empty())
    return {0, nullptr};

  // Allocate C-compatible array for results
  auto *c_elements =
      (AnitomyElementC *)malloc(elements.size() * sizeof(AnitomyElementC));

  size_t i = 0;
  for (const auto &element : elements) {
    // element.first is ElementCategory, element.second is the value string
    c_elements[i].kind = static_cast<int32_t>(element.first);

    // Convert wide string to UTF-8
    std::wstring wvalue = element.second;
    std::string value(wvalue.begin(), wvalue.end());

    char *val = (char *)malloc(value.length() + 1);
    memcpy(val, value.c_str(), value.length());
    val[value.length()] = '\0';

    c_elements[i].value_ptr = val;
    i++;
  }

  return {(int64_t)elements.size(), c_elements};
}

// Free allocated memory from anitomy_parse result
void anitomy_free_result(AnitomyResultC result) {
  if (result.elements_ptr) {
    for (int64_t i = 0; i < result.count; ++i) {
      free((void *)result.elements_ptr[i].value_ptr);
    }
    free(result.elements_ptr);
  }
}