#include <assert.h>
#include <stdio.h>
#include <fat.h>

int main() {
  library_t* lib = NULL;
  face_t* face = NULL;

  fat_error_e err;

  err = fat_init_library(&lib);
  if (err != fat_error_ok) {
    printf("fat_init_library failed: %s\n", fat_error_name(err));
    goto err;
  }

  ft_face_options_t options = {0};
  options.size = 32.0;
  options.face_index = 0;

  err = fat_open_face(lib, &face, "C:\\Windows\\Fonts\\arial.ttf", options);
  if (err != fat_error_ok) {
    printf("fat_open_face failed: %s\n", fat_error_name(err));
    goto err;
  }

  uint32_t idx;
  assert(fat_face_glyph_index(face, 'A', &idx) == fat_error_ok);

  printf("idx: %d\n", idx);

  ft_face_bbox_t bbox;
  err = fat_face_glyph_bbox(face, idx, &bbox);
  if (err != fat_error_ok) {
    printf("fat_face_glyph_bbox failed: %s\n", fat_error_name(err));
    goto err;
  }

  printf("bbox: w=%d h=%d\n", bbox.width, bbox.width);

  assert(fat_face_done(face) == fat_error_ok);
  assert(fat_library_done(lib) == fat_error_ok);

  return 0;

err:
  if (face) assert(fat_face_done(face) == fat_error_ok);
  if (lib) assert(fat_library_done(lib) == fat_error_ok);

  return 1;
}
