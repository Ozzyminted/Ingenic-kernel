#include <asm/addrspace.h>
#include <asm/asm.h>
#include <asm/regdef.h>
#include <asm/mipsregs.h>
#include <asm/cacheops.h>

#define CFG_CACHELINE_SIZE 	32
#define CFG_DCACHE_SIZE		(32*1024)
#define CFG_ICACHE_SIZE		(32*1024)

	.macro	add_smp_flag val
	/* write SMP_FLAG (smp.c) */
1:	
	ll	v0, 0($26)
	addu	v0, \val
	sc	v0, 0($26)
	beqz	v0, 1b
	nop
	.endm

	.section	".text.jzsoc"
NESTED(__jzsoc_secondary_start, 16, sp)

	//.set	mips32
	.set	noreorder

	/* cause and status register */
#define STATUS_BITS (ST0_CU0)
	mtc0	zero, CP0_CAUSE
	li	v0, STATUS_BITS
	mtc0	v0, CP0_STATUS
	nop

	add_smp_flag 0x10

	/* Init cache */
	li	t0, KSEG0
	addu	t1, t0, CFG_DCACHE_SIZE
	mtc0	zero, $28, 0	// CP0_TAGLO
	mtc0	zero, $28, 1	// CP0_DATALO
1:
	/* cache_clear_a_line */
	cache	Index_Store_Tag_I, 0(t0)	// Index_Store_Tag_I
	cache	Index_Store_Tag_D, 0(t0)	// Index_Store_Tag_D
	bne	t0, t1, 1b
	addu	t0, t0, CFG_CACHELINE_SIZE

	add_smp_flag 0x100

	/* kseg0 cache attribute */
	mfc0	v0, $16, 0
	ori	v0, v0, 3
	mtc0	v0, $16, 0
	/* pagemask, will set in kernel */
	mtc0	zero, $5,0
	/* set MMU/tlb attribute (jz special) */
	li	v0, 0xa9000000
	mtc0	v0, $5, 4
	
	/* get cpu mask bit */
	mfc0	v0, $15, 1
	and	v0, v0, 0x3ff
	addu	v1, zero, 1
	sllv	v1, v1, v0

	/* set uncached cpu_ready bitmap */
	li	v0, 0x20000000
	addu	t8, t8, v0
1:	
	ll	v0, 0(t8)
	or	v0, v0, v1
	sc	v0, 0(t8)
	beqz	v0, 1b
	nop

	/* wait for set cpu_start. busy loop! */
2:
	lw	v0, 0(t7)
	and	v0, v0, v1
	beqz	v0, 2b
	nop
	/* read out sp,gp */
	lw	sp, 0(sp)
	lw	gp, 0(gp)

	/* set cpu_running bitmap */
3:
	ll	v0, 0(t9)
	or	v0, v0, v1
	sc	v0, 0(t9)
	beqz	v0, 3b
	nop
	
	.set	reorder

	j	smp_bootstrap
	END(__jzsoc_secondary_start)
