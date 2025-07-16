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
  options.size = 128.0;
  options.face_index = 0;

  err = fat_open_face(lib, &face, "tests/arial.ttf", options);
  if (err != fat_error_ok) {
    printf("fat_open_face failed: %s\n", fat_error_name(err));
    goto err;
  }

  uint32_t idx;
  assert(fat_face_glyph_index(face, 'A', &idx) == fat_error_ok);

  printf("idx: %d\n", idx);

  ft_face_glyph_t glyph;
  err = fat_face_render_glyph(face, idx, &glyph);
  if (err != fat_error_ok) {
    printf("fat_face_glyph_bbox failed: %s\n", fat_error_name(err));
    goto err;
  }

  printf("bounds: w=%d h=%d\n", glyph.width, glyph.height);

  FILE* out = fopen("out.ppm", "wb");
  assert(out != NULL);

  fprintf(out, "P5\n%d %d\n255\n", glyph.width, glyph.height);
  fwrite(glyph.bitmap, 1, glyph.width * glyph.height, out);

  fclose(out);
  fat_face_glyph_done(glyph);

  assert(fat_face_done(face) == fat_error_ok);
  assert(fat_library_done(lib) == fat_error_ok);

  return 0;

err:
  if (face) assert(fat_face_done(face) == fat_error_ok);
  if (lib) assert(fat_library_done(lib) == fat_error_ok);

  return 1;
}
