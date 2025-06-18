CC = gcc
CFLAGS = -fopenmp
TARGET = conversion_yuv_rgb
SRC = main.c conversion.c

# Input image and parameters, overwritten in terminal
INPUT ?= tulips_yuyv422_prog_packed_qcif.yuv
WIDTH ?= 176
HEIGHT ?= 144
METHOD ?= cpu  # values: cpu / fpga

# Derived variables
BASENAME := $(basename $(notdir $(INPUT)))
TIMESTAMP := $(shell date +%Y%m%d_%H%M%S)
OUT_DIR := output/$(BASENAME)

ifeq ($(METHOD),cpu)
  SUFFIX := _cpu
else ifeq ($(METHOD),fpga)
  SUFFIX := _fpga
else ifeq ($(METHOD),both)
  SUFFIX := _fpga
else
  $(error Metoda invalida. Optiuni METHOD=cpu, METHOD=fpga, METHOD=both)
endif

OUTPUT := $(OUT_DIR)/$(BASENAME)$(SUFFIX)_$(TIMESTAMP).rgb

build:
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC)

build_and_run: build
	mkdir -p $(OUT_DIR)
	./$(TARGET) $(INPUT) $(OUTPUT) $(WIDTH) $(HEIGHT) $(METHOD)

run:
	mkdir -p $(OUT_DIR)
	./$(TARGET) $(INPUT) $(OUTPUT) $(WIDTH) $(HEIGHT) $(METHOD)

clean:
	rm -f $(TARGET)