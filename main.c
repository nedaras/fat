#include <assert.h>
#include <stdio.h>
#include <fat.h>

int main() {
  library_t* lib;
  face_t* face;

  fat_error_e err;

  err = fat_init_library(&lib);
  if (err != fat_error_ok) {
    printf("fat_init_library failed: %s\n", fat_error_name(err));
    return 1;
  }

  err = fat_open_face(lib, &face, "C:\\Windows\\");
  if (err != fat_error_ok) {
    printf("fat_open_face failed: %s\n", fat_error_name(err));
    assert(fat_library_done(lib) == fat_error_ok);
    return 1;
  }



  assert(fat_face_done(face) == fat_error_ok);
  assert(fat_library_done(lib) == fat_error_ok);
}
