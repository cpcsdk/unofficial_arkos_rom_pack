##
# Launch ./bootstrap.sh before using the Makefile (or install vasmz80_oldstyle on your path)
#



##
# Possible FLAVORS:
# CPCBOOSTER for the CPCbooster ROM
# CPCWIFI for the M4 card (TODO)
# ALBIREO for the Albireo v1.1
#FLAVOR?=CPCBOOSTER
#FLAVOR?=CPCWIFI
FLAVOR?=ALBIREO

OUT:=$(shell mkdir -p out/$(FLAVOR) && echo out/$(FLAVOR))

ASMFLAGS="-DFLAVOR_$(FLAVOR)"

build: $(OUT)/AksROM.rom $(OUT)/SNAROM.rom

# Overwrite the default assembling routine in order to select the output folder on fly
$(OUT)/%.o: src/%.asm
	cd src ; \
	vasmz80_oldstyle $(ASMFLAGS) -L ../$(@:.o=.lst)  -Fbin -o ../$@ $(notdir $<)




%.rom:%.o
	cp $^ $@
