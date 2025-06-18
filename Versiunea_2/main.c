#include "conversion.h"

int main(int argc, char * argv[])
{
  if (argc < 6)
  {
    printf("Nu s-au furnizat toate argumentele!");  // INPUT, OUTPUT, WIDTH, HEIGHT, METHOD
    return 1;
  }

  const char *input_filename = argv[1];
  const char *output_filename = argv[2];
  const char *output_filename_cpu = argv[3];
  uint32_t WIDTH = atoi(argv[4]);
  uint32_t HEIGHT = atoi(argv[5]);
  ConversionMethod method;

  if (strcmp(argv[5], "cpu") == 0)
    method = CONVERSION_CPU;
  else if (strcmp(argv[5], "fpga") == 0)
    method = CONVERSION_FPGA;
  else if (strcmp(argv[5], "both") == 0)
    method = BOTH;
  else 
  {
    fprintf(stderr, "Metoda invalida: 'cpu' - 'fpga' - 'both'\n");
    return 1;
  }

  FILE *input_file = fopen(input_filename, "rb");
  if (!input_file) 
  {
   printf("Eroare: Nu se poate deschide fisierul de intrare: %s.\n", input_filename);
   return 1;
  }

  FILE *output_file = fopen(output_filename, "wb");
  if (!output_file) 
  {
    printf("Eroare: Nu se poate crea fisierul de iesire: %s.\n", output_filename);
    fclose(input_file);
    return 1;
  }

  FILE *output_file_cpu = fopen(output_filename_cpu, "wb");
  if (!output_file_cpu) 
  {
    printf("Eroare: Nu se poate crea fisierul de iesire: %s.\n", output_filename_cpu);
    fclose(input_file);
    return 1;
  }

  size_t yuv_size = WIDTH * HEIGHT * 2;  // dimensiunea buffer in care va fi incarcata imagiena .yuv
  size_t rgb_size = WIDTH * HEIGHT * 3;  // dimensiunea buffer in care va fi incarcata imagiena .rgb

  uint8_t *yuv_buffer_cpu = malloc(yuv_size);
  uint8_t *rgb_buffer_cpu = malloc(rgb_size);
  if (!yuv_buffer_cpu || !rgb_buffer_cpu) 
  {
    perror("Nu s-a putut aloca memorie!");
    return 1;
  }

  uint32_t *yuv_buffer = aligned_alloc(8, yuv_size);
  uint32_t *rgb_buffer = aligned_alloc(8, rgb_size);
  if (!yuv_buffer || !rgb_buffer) 
  {
    perror("Nu s-a putut aloca memorie!");
    return 1;
  }

  fread(yuv_buffer, 1, yuv_size, input_file);  // stocarea intregii imagini .yuv in buffer
  fread(yuv_buffer_cpu, 1, yuv_size, input_file); 

  struct timespec start, stop;
  long duration_conversion;
  
  switch (method)
  {
    case CONVERSION_CPU: {  clock_gettime(CLOCK_MONOTONIC_RAW, &start);           // se incepe cronometrarea 
                            convert_cpu(yuv_buffer_cpu, rgb_buffer_cpu, WIDTH, HEIGHT);   // conversia realizata de procesor 
                            clock_gettime(CLOCK_MONOTONIC_RAW, &stop);            // finalizarea cronometrarii
                            duration_conversion = time_diff_us(start, stop); 
                            printf("Timp total de conversie CPU:%ldm%ld.%06lds\n", duration_conversion / 60000000, (duration_conversion / 1000000) % 60, duration_conversion % 1000000);
                            fwrite(rgb_buffer, 1, rgb_size, output_file_cpu);
                            break;
                          }
    case CONVERSION_FPGA: { clock_gettime(CLOCK_MONOTONIC_RAW, &start);
                            convert_fpga(yuv_buffer, rgb_buffer, WIDTH, HEIGHT); // conversia realizata de FPGA
                            clock_gettime(CLOCK_MONOTONIC_RAW, &stop);
                            duration_conversion = time_diff_us(start, stop);
                            printf("Timp total de conversie FPGA:%ldm%ld.%06lds\n", duration_conversion / 60000000, (duration_conversion / 1000000) % 60, duration_conversion % 1000000);
                            fwrite(rgb_buffer_cpu, 1, rgb_size, output_file);
                            break;
                          }
    case BOTH : { clock_gettime(CLOCK_MONOTONIC_RAW, &start);
                  convert_fpga(yuv_buffer, rgb_buffer, WIDTH, HEIGHT); // conversia realizata de FPGA
                  clock_gettime(CLOCK_MONOTONIC_RAW, &stop);
                  duration_conversion = time_diff_us(start, stop);
                  printf("Timp total de conversie FPGA:%ldm%ld.%06lds\n", duration_conversion / 60000000, (duration_conversion / 1000000) % 60, duration_conversion % 1000000);
                  fwrite(rgb_buffer, 1, rgb_size, output_file);

                  clock_gettime(CLOCK_MONOTONIC_RAW, &start);
                  convert_cpu(yuv_buffer_cpu, rgb_buffer_cpu, WIDTH, HEIGHT); // conversia realizata de procesor 
                  clock_gettime(CLOCK_MONOTONIC_RAW, &stop);
                  duration_conversion = time_diff_us(start, stop);
                  printf("Timp total de conversie CPU:%ldm%ld.%06lds\n", duration_conversion / 60000000, (duration_conversion / 1000000) % 60, duration_conversion % 1000000);
                  fwrite(rgb_buffer_cpu, 1, rgb_size, output_file_cpu);

                  //compare_rgb(rgb_buffer, rgb_buffer_cpu, WIDTH, HEIGHT);  // compararea rezultatelor
                  break;
                }
  }

  free(yuv_buffer);
  free(rgb_buffer);
  free(yuv_buffer_cpu);
  free(rgb_buffer_cpu);
  fclose(input_file);
  fclose(output_file);

  return 0;

}