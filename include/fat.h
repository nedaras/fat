#ifndef FAT_H
#define FAT_H

#include <stdint.h>

#if defined(__APPLE__) && defined(__MACH__)
    #define FT_FACE_DEFAULT_DPI 72
#else
    #define FT_FACE_DEFAULT_DPI 96
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef void* library_t;
typedef void* face_t;

typedef enum {
  fat_error_ok = 0,
  fat_error_failed_to_open,
  fat_error_not_supported,
  fat_error_invalid_wtf_8,
  fat_error_invalid_pointer,
  fat_error_out_of_memory,
  fat_error_unexpected,
} fat_error_e;

struct ft_face_options_s {
  float size;
  uint32_t face_index;
} typedef ft_face_options_t;

struct ft_face_bbox_s {
  uint32_t width;
  uint32_t height;
} typedef ft_face_bbox_t;

struct ft_face_glyph_s {
  uint32_t width;
  uint32_t height;

  uint8_t* bitmap;
} typedef ft_face_glyph_t;

const char* fat_error_name(fat_error_e err);

fat_error_e fat_init_library(library_t** library);

fat_error_e fat_library_done(library_t* library);

// Open a new font face with the given file path.
fat_error_e fat_open_face(library_t* library, face_t** face, const char* sub_path, ft_face_options_t options);

fat_error_e fat_face_done(face_t* face);

fat_error_e fat_face_glyph_index(face_t* face, uint32_t codepoint, uint32_t* glyph_idex);

fat_error_e fat_face_glyph_bbox(face_t* face, uint32_t glyph_index, ft_face_bbox_t* bbox);

fat_error_e fat_face_render_glyph(face_t* face, uint32_t glyph_index, ft_face_glyph_t* glyph);

void fat_face_glyph_done(ft_face_glyph_t glyph);

#ifdef __cplusplus
}
#endif

#endif /* FAT_H */
