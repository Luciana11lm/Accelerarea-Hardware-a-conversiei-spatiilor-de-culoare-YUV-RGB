#include "conversion.h"

#define APB_BASE_ADDR 0x41100000
#define MAP_SIZE       4096           // 4K mapati - o pagina de mem

long time_diff_us(struct timespec start, struct timespec end) 
{
  return (end.tv_sec - start.tv_sec) * 1000000L + (end.tv_nsec - start.tv_nsec) / 1000L;
}

long sum_conversion_times(const long *durations, size_t count)
{
  long total = 0;
  for (size_t i = 0; i < count; i++)
  {
    total += durations[i];
  }
  return total;
}

uint8_t clip(uint16_t value) 
{
  if (value < 0) 
    return 0;
  if (value > 255) 
    return 255;
  return (uint8_t)value;
}

void yuv422_to_rgb(uint8_t y0, uint8_t u, uint8_t y1, uint8_t v, RGB* pixel0, RGB* pixel1) 
{
  int32_t r_temp, g_temp, b_temp;
  int16_t r0, g0, b0;
  int16_t r1, g1, b1;

  r_temp = (1436 * (v - 128)) >> 10;                                // R = Y + 1.402 * (V - 128)
  g_temp = ((352 * (u - 128)) >> 10) + ((731 * (v - 128)) >> 10);   // G = Y - 0.344 * (U - 128) - 0.714 * (V - 128)
  b_temp = (1814 * (u - 128)) >> 10;                                // B = Y + 1.772 * (U - 128)

  r0 = y0 + r_temp;
  g0 = y0 - g_temp;
  b0 = y0 + b_temp;

  r1 = y1 + r_temp;
  g1 = y1 - g_temp;
  b1 = y1 + b_temp;
  
  pixel0->r = clip(r0);
  pixel0->g = clip(g0);
  pixel0->b = clip(b0);

  pixel1->r = clip(r1);
  pixel1->g = clip(g1);
  pixel1->b = clip(b1);
}

void convert_cpu(uint32_t *yuv_buffer, uint32_t *rgb_buffer, uint32_t WIDTH, uint32_t HEIGHT)
{
  uint32_t i; 

  #pragma omp parallel for 
  for( i = 0; i < WIDTH * HEIGHT * 2; i += 8)
  {
    uint32_t pixel_index = 0;
    uint32_t rgb_index = (i/2) * 3;
    RGB pixels[4];

    yuv422_to_rgb(yuv_buffer[i], yuv_buffer[i+1], yuv_buffer[i+2], yuv_buffer[i+3], &pixels[pixel_index++], &pixels[pixel_index++]); // Pixel 0 + 1: Y0, U0, Y1, V0
  
    yuv422_to_rgb(yuv_buffer[i+4], yuv_buffer[i+5], yuv_buffer[i+6], yuv_buffer[i+7], &pixels[pixel_index++], &pixels[pixel_index++]); // Pixel 2 + 3: Y2, U1, Y3, V1
    
    pixel_index = 0;

    for(int j = 0; j < 4; j++)
    {
      rgb_buffer[rgb_index++] = pixels[j].r;
      rgb_buffer[rgb_index++] = pixels[j].g;
      rgb_buffer[rgb_index++] = pixels[j].b;
    }
  }
}

int convert_fpga(uint32_t *yuv_buffer, uint32_t *rgb_buffer, uint32_t WIDTH, uint32_t HEIGHT)
{
  int mem_fd = open("/dev/mem", O_RDWR | O_SYNC); // O_SYNC - scrieri directe, fara buffer/ cache
  printf("Mme_fd = %u\n", mem_fd);
  if (mem_fd < 0) {
    perror("open");
    return -1;
  }

  void *map_base = mmap(NULL, MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, APB_BASE_ADDR); // MAP_SHARED - modificarile afecteaza si memoria fizica
  if (map_base == MAP_FAILED) 
  {
    perror("mmap");
	  close(mem_fd);
    return -1;
  }
 
  // se poate realiza scrierea la aceeasi adresa si imediat ce ajung la fpga, 
  //datele sunt stocate intr-un buffer si convertite si puse in alt buffer de iesre
  volatile uint32_t *y0u0y1v0 = (volatile uint32_t *)(map_base + 0x00000010); 
  volatile uint32_t *transfer_len = (volatile uint32_t *)(map_base + 0x00000014); // cate transferuri de scriere se por executa 
  volatile uint32_t *rgb0 = (volatile uint32_t *)(map_base + 0x00000030);
  volatile uint32_t *status = (volatile uint32_t *) (map_base + 0x00000020);

  uint64_t total_uint32_yuv = (WIDTH * HEIGHT * 2) / 4; // numar total de valori de 32 de biti ramase pentru a fi transmise
  uint64_t total_uint32_rgb = (WIDTH * HEIGHT * 3) / 4; // numar total de valori de 32 de biti ramase pentru a fi citite
  uint64_t waiting_loop = 0; // de cate ori se realizeaza usleep pentru intreaga imagine

  for(uint64_t i = 0; i < total_uint32_yuv; i += 16)
  {
    size_t remaining_yuv = total_uint32_yuv - i;
    uint32_t to_send = (remaining_yuv < 16) ? remaining_yuv : 16;

    *transfer_len = to_send;
    // se fac 16 (sau cate mai raman) scrieri de 32 de biti catre FPGA
    for(size_t j = 0; j < to_send; j++)
      *y0u0y1v0 = yuv_buffer[i + j];

    int64_t tries = 100;
    size_t rgb_index_offset = (i / 16) * 24; // avansare cu 24 pentru un pachet RGB
    size_t remaining_rgb = total_uint32_rgb - rgb_index_offset;
    size_t to_read = (remaining_rgb < 24) ? remaining_rgb : 24;
    while (tries--) 
    {
      if (*status == 0xFFFFFFFF)
      {
      	// 24 citiri (sau cate mai raman) de 32 de biti RGB de la FPGA
        for (size_t j = 0; j < to_read; j++)
        {
          rgb_buffer[rgb_index_offset + j] = *rgb0;
        }
        break; 
      }
      //usleep(100);
      waiting_loop++;
    }
    
    if (tries == -1)
    { 
      printf("Nu s-a primit intreruperea!\n");
      munmap(map_base, MAP_SIZE);
      close(mem_fd);
      return -1;
    }
  }

  printf("Numar teoretic de usleep : %d\n", waiting_loop);

  munmap(map_base, MAP_SIZE);
  close(mem_fd);
  return 0;
}

// nu se mai foloseste, se face compararea la nivel de fisier 
void compare_rgb(uint32_t *rgb_buffer_fpga, uint8_t *rgb_buffer_cpu, uint32_t WIDTH, uint32_t HEIGHT) 
{

  size_t differences = 0;

  for (uint32_t i = 0; i < WIDTH * HEIGHT * 3; i++) 
  {
    if (rgb_buffer_cpu[i] != rgb_buffer_fpga[i]) 
    {
      differences++;
      printf("Diferenta %d la pozitia %u: %x - %x\n", differences, i, rgb_buffer_cpu[i], rgb_buffer_fpga[i]);
    }
  }
  if (!differences)
    printf("Fisierele generate sunt identice!");
}