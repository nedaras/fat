#ifndef FAT_H
#define FAT_H

#ifdef __cplusplus
extern "C" {
#endif

typedef void* library_t;
typedef void* face_t;

typedef enum {
  fat_error_ok = 0,
  fat_error_failed_to_open,
  fat_error_not_supported,
  fat_error_invalid_pointer,
  fat_error_out_of_memory,
  fat_error_unexpected,
} fat_error_e;

fat_error_e fat_init_library(library_t** library);

fat_error_e fat_library_done(library_t* library);

fat_error_e fat_open_face(library_t* library, face_t** face, const char* path);

fat_error_e fat_face_done(face_t* face);

#ifdef __cplusplus
}
#endif

#endif /* FAT_H */
