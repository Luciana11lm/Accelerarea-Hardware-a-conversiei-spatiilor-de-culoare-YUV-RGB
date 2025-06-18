CC = gcc
CFLAGS = -fopenmp
TARGET = conversion_yuv_rgb
SRC = main.c conversion.c

INPUT ?= tulips_yuyv422_prog_packed_qcif.yuv
WIDTH ?= 176
HEIGHT ?= 144
METHOD ?= cpu # cpu / fpga / both

BASENAME := $(basename $(notdir $(INPUT)))
TIMESTAMP := $(shell date +%Y%m%d_%H%M%S)
OUT_DIR := output/$(BASENAME)
EXT := .rgb

SUFFIX_CPU := _cpu
SUFFIX_FPGA := _fpga

ifeq ($(METHOD),cpu)
  OUTPUT_CPU := $(OUT_DIR)/$(BASENAME)$(SUFFIX_CPU)_$(TIMESTAMP)$(EXT)
  OUTPUT_FPGA := /dev/null
else ifeq ($(METHOD),fpga)
  OUTPUT_CPU := /dev/null
  OUTPUT_FPGA := $(OUT_DIR)/$(BASENAME)$(SUFFIX_FPGA)_$(TIMESTAMP)$(EXT)
else ifeq ($(METHOD),both)
  OUTPUT_CPU := $(OUT_DIR)/$(BASENAME)$(SUFFIX_CPU)_$(TIMESTAMP)$(EXT)
  OUTPUT_FPGA := $(OUT_DIR)/$(BASENAME)$(SUFFIX_FPGA)_$(TIMESTAMP)$(EXT)
else
  $(error Metoda invalida. Optiuni METHOD=cpu, METHOD=fpga, METHOD=both)
endif

build:
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC)

build_and_run: build
	mkdir -p $(OUT_DIR)
	./$(TARGET) $(INPUT) $(OUTPUT_FPGA) $(OUTPUT_CPU) $(WIDTH) $(HEIGHT) $(METHOD)
ifeq ($(METHOD),both)
	cmp -l $(OUTPUT_FPGA) $(OUTPUT_CPU)
endif

run:
	mkdir -p $(OUT_DIR)
	./$(TARGET) $(INPUT) $(OUTPUT_FPGA) $(OUTPUT_CPU) $(WIDTH) $(HEIGHT) $(METHOD)
ifeq ($(METHOD),both)
	cmp -l $(OUTPUT_FPGA) $(OUTPUT_CPU)
endif

clean:
	rm -f $(TARGET)
