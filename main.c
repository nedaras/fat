#include <stdio.h>
#include <fat.h>

int main() {
  library_t* lib;
  if (fat_init_library(&lib) != 0) {
    printf("fat_init_library failed\n");
    return 1;
  }

  printf("fat_init_library succedded\n");

  fat_library_done(lib);
}
