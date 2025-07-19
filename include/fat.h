#ifndef FAT_H
#define FAT_H

#include <stdint.h>

#if defined(__APPLE__) && defined(__MACH__)
    #define FAT_FACE_DEFAULT_DPI 72
#else
    #define FAT_FACE_DEFAULT_DPI 96
#endif

#ifdef __cplusplus
extern "C" {
#endif

// now we're allocating these structs cuz im lazy to handle diffrent backends in c
// as these structs change based on that
typedef struct fat_face_s fat_face_t;
typedef struct fat_library_s fat_library_t;
typedef struct fat_deferred_face_s fat_deferred_face_t;
typedef struct fat_font_iterator_s fat_font_iterator_t;

typedef enum {
  fat_error_ok,
  fat_error_failed_to_open,
  fat_error_not_supported,
  fat_error_invalid_wtf_8,
  fat_error_invalid_pointer,
  fat_error_out_of_memory,
  fat_error_unexpected,
} fat_error_e;

typedef enum {
  fat_font_weight_thin,
  fat_font_weight_extralight,
  fat_font_weight_light,
  fat_font_weight_semilight,
  fat_font_weight_book, // mb just make this one regular
  fat_font_weight_regular,
  fat_font_weight_medium,
  fat_font_weight_demibold,
  fat_font_weight_bold,
  fat_font_weight_extrabold,
  fat_font_weight_black,
  fat_font_weight_extrablack,
} fat_font_weight_e;

typedef enum {
  fat_font_slant_roman,
  fat_font_slant_italic,
  fat_font_slant_oblique,
} fat_font_slant_e;

typedef uint8_t fat_font_weight_t;
typedef uint8_t fat_font_slant_t;

struct fat_face_options_s {
  float size;
  uint32_t face_index;
} typedef fat_face_options_t;

struct fat_face_bbox_s {
  uint32_t width;
  uint32_t height;
} typedef fat_face_bbox_t;

struct fat_face_glyph_render_s {
  uint32_t width;
  uint32_t height;

  uint8_t* bitmap;
} typedef fat_face_glyph_render_t;

struct fat_face_info_s {
  const char* family;
  float size;
  fat_font_weight_t weight;
  fat_font_slant_t slant;
} typedef fat_face_info_t;

struct fat_collection_descriptor_s {
  const char* family;
  const char* style;
  uint32_t codepoint;
  float size;
} typedef fat_collection_descriptor_t;

const char* fat_error_name(fat_error_e err);

fat_error_e fat_init_library(fat_library_t** library);

void fat_library_done(fat_library_t* library);

// Open a new font face with the given file path.
fat_error_e fat_open_face(fat_library_t* library, fat_face_t** face, const char* sub_path, fat_face_options_t options);

void fat_face_done(fat_face_t* face);

fat_error_e fat_face_glyph_index(fat_face_t* face, uint32_t codepoint, uint32_t* glyph_idex);

fat_error_e fat_face_glyph_bbox(fat_face_t* face, uint32_t glyph_index, fat_face_bbox_t* bbox);

fat_error_e fat_face_render_glyph(fat_face_t* face, uint32_t glyph_index, fat_face_glyph_render_t* glyph);

void fat_face_glyph_render_done(fat_face_glyph_render_t glyph);

fat_error_e fat_font_collection(fat_library_t* library, fat_collection_descriptor_t descriptor, fat_font_iterator_t** font_iterator);

void fat_font_collection_done(fat_font_iterator_t* font_iterator);

fat_error_e fat_font_collection_next(fat_font_iterator_t* font_iterator, fat_deferred_face_t** deffered_face);

void fat_deffered_face_done(fat_deferred_face_t* deffered_face);

fat_face_info_t fat_deffered_face_query_info(fat_deferred_face_t* deffered_face);

#ifdef __cplusplus
}
#endif

#endif /* FAT_H */
