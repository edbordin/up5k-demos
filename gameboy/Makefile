PROJ = gb_mist

TOP = gb_mist
PIN_DEF = up5k.pcf
DEVICE = up5k
ADD_SRC = $(wildcard *.v) $(wildcard t80_vl/*.v)
FREQ = 12
# USE_ARACHNEPNR = Y

include main.mk

GAMES = $(sort $(wildcard rom/game*.nes))
IMAGES = $(GAMES:.nes=.bin)

rom/games.bin: $(IMAGES)
	cat $^ > $@

up5kprog_game: rom/games.bin
	iceprog -o 1024k rom/games.bin
