#include <assert.h>
#include <stdio.h>
#include <stdbool.h>
#include <fat.h>

// asserts are removed in unsafe builds

int main() {
  fat_library_t* lib = NULL;
  fat_face_t* face = NULL;
  fat_font_iterator_t* collection = NULL;

  fat_error_e err;

  err = fat_init_library(&lib);
  if (err != fat_error_ok) {
    printf("fat_init_library failed: %s\n", fat_error_name(err));
    goto err;
  }

  fat_face_options_t options = {0};
  options.size = 32.0;
  options.face_index = 0;

  err = fat_open_face(lib, &face, "tests/arial.ttf", options);
  if (err != fat_error_ok) {
    printf("fat_open_face failed: %s\n", fat_error_name(err));
    goto err;
  }

  uint32_t idx;
  fat_face_glyph_index(face, 'A', &idx);

  printf("idx: %d\n", idx);

  // todo: change these names too
  fat_face_glyph_render_t glyph;
  err = fat_face_render_glyph(face, idx, &glyph);
  if (err != fat_error_ok) {
    printf("fat_face_glyph_bbox failed: %s\n", fat_error_name(err));
    goto err;
  }

  printf("bounds: w=%d h=%d\n", glyph.width, glyph.height);

  //FILE* out = fopen("out.ppm", "wb");
  //assert(out != NULL);

  //fprintf(out, "P5\n%d %d\n255\n", glyph.width, glyph.height);
  //fwrite(glyph.bitmap, 1, glyph.width * glyph.height, out);

  //fclose(out);

  fat_collection_descriptor_t descriptor = {0};
  descriptor.codepoint = 0x5B57;

  err = fat_open_collection(lib, descriptor, &collection);
  if (err != fat_error_ok) {
    printf("fat_font_collection failed: %s\n", fat_error_name(err));
    goto err;
  }

  while (true) {
    fat_deferred_face_t* deffered_face = NULL;
    err = fat_collection_next(collection, &deffered_face);
    if (err != fat_error_ok) {
      printf("fat_font_collection_next failed: %s\n", fat_error_name(err));
      goto err;
    }

    if (deffered_face == NULL) {
      break;
    }

    fat_face_info_t info = fat_deffered_face_query_info(deffered_face);
    printf("%s\n", info.family);

    fat_deffered_face_done(deffered_face);
  }

  fat_collection_done(collection);
  fat_face_glyph_render_done(glyph); // leaks on error
  fat_face_done(face);
  fat_library_done(lib);

  return 0;

err:
  fat_collection_done(collection);
  fat_face_done(face);
  fat_library_done(lib);

  return 1;
}
