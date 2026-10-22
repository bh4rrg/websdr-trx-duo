obj-m := sdrdma.o
sdrdma-objs := sdrdma_main.o sfifo.o

MY_CFLAGS += -g -DDEBUG -I $(shell pwd)
# Force ARM state: this kernel is built without CONFIG_THUMB2_KERNEL and its
# module loader rejects R_ARM_THM_CALL (unknown relocation: 10).
# The ARM official toolchain defaults to Thumb, so override explicitly.
ccflags-y += ${MY_CFLAGS} -marm

SRC := $(shell pwd)

all:
	$(info    MY_CFLAGS is $(MY_CFLAGS))
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC)

modules_install:
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC) modules_install

clean:
	rm -f *.o *~ core .depend .*.cmd *.ko *.mod.c
	rm -f Module.markers Module.symvers modules.order
	rm -rf .tmp_versions Modules.symvers
