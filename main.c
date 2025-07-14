#include <assert.h>
#include <stdio.h>
#include <fat.h>

int main() {
  library_t* lib;
  face_t* face;

  if (fat_init_library(&lib) != fat_error_ok) {
    printf("fat_init_library failed\n");
    return 1;
  }

  if (fat_open_face(lib, &face, "") != fat_error_ok) {
    printf("fat_open_face failed\n");
    assert(fat_library_done(lib) == fat_error_ok);
    return 1;
  }

  printf("fat_init_library succeeded\n");

  assert(fat_face_done(face) == fat_error_ok);
  assert(fat_library_done(lib) == fat_error_ok);
}
