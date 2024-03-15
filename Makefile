PROGRAM := tc
OUTPUT := ./.output

INCLUDES_DIR := ./includes
INCLUDES := -I$(INCLUDES_DIR)

# Get Clang's default includes on this system. We'll explicitly add these dirs
# to the includes list when compiling with `-target bpf` because otherwise some
# architecture-specific dirs will be "missing" on some architectures/distros -
# headers such as asm/types.h, asm/byteorder.h, asm/socket.h, asm/sockios.h,
# sys/cdefs.h e$(PROGRAM). might be missing.
#
# Use '-idirafter': Don't interfere with include mechanics except where the
# build would have failed anyways.
CLANG_BPF_SYS_INCLUDES := $(shell clang -v -E - </dev/null 2>&1 \
	| sed -n '/<...> search starts here:/,/End of search list./{ s| \(/.*\)|-idirafter \1|p }')

all: $(PROGRAM)

$(OUTPUT) $(INCLUDES_DIR):
	mkdir -p $@

$(INCLUDES_DIR)/vmlinux.h: | $(INCLUDES_DIR)
	bpftool btf dump file /sys/kernel/btf/vmlinux format c > $@

$(OUTPUT)/$(PROGRAM).bpf.o: $(PROGRAM).bpf.c $(INCLUDES_DIR)/vmlinux.h | $(OUTPUT)
	clang -g -O2 -target bpf $(INCLUDES) $(CLANG_BPF_SYS_INCLUDES) -c $< -o $(OUTPUT)/$(PROGRAM).tmp.bpf.o
	bpftool gen object $@ $(OUTPUT)/$(PROGRAM).tmp.bpf.o

$(INCLUDES_DIR)/$(PROGRAM).skel.h: $(OUTPUT)/$(PROGRAM).bpf.o
	bpftool gen skeleton $< > $@

$(PROGRAM): $(PROGRAM).c $(INCLUDES_DIR)/$(PROGRAM).skel.h
	cc -g $(INCLUDES) -c $< -o $(OUTPUT)/$(PROGRAM).o
	cc -g $(OUTPUT)/$(PROGRAM).o -lbpf -o $@

clean:
	rm -rf $(OUTPUT) $(INCLUDES_DIR) $(PROGRAM)