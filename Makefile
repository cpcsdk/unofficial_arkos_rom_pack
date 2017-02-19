##
# Launch ./bootstrap.sh before using the Makefile (or install vasmz80_oldstyle on your path)
#



##
# Possible FLAVORS:
# CPCBOOSTER for the CPCbooster ROM
# CPCWIFI for the M4 card (TODO)
#FLAVOR?=CPCBOOSTER
FLAVOR?=CPCWIFI

OUT:=$(shell mkdir -p out/$(FLAVOR) && echo out/$(FLAVOR))

ASMFLAGS="-DFLAVOR_$(FLAVOR)"

build: $(OUT)/AksROM.rom $(OUT)/SNA_ROM.rom

# Overwrite the default assembling routine in order to select the output folder on fly
$(OUT)/%.o: src/%.asm
	cd src ; \
	vasmz80_oldstyle $(ASMFLAGS) -L ../$(@:.o=.lst)  -Fbin -o ../$@ $(notdir $<)




%.rom:%.o
	cp $^ $@
