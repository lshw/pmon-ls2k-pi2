/*whd : loongson3_clksetting.S
	change the PLL settings of each core

ATTENTION:

         Using S1 for passing the NODE ID
*/
#define SOFT_CLKSEL
#define BBGEN

#ifdef  BBGEN
#define VBBn_VAL 0x8
#define VBBp_VAL 0x4
#define FEEDBACK 0x3
#endif

#ifdef SOFT_CLKSEL

#define USE_LS_PLL 1
#define DDR_SEL_ST 0

#ifndef CORE_FREQ
#ifdef  MULTI_CHIP
#define CORE_FREQ   1200
#define DDR_FREQ    660
#else
#define CORE_FREQ   1400
#define DDR_FREQ    600
#endif
#endif

#define DDR_REFC    1   //do not modify
#if (DDR_FREQ < 400)
#define DDR_DIV     8
#else
#define DDR_DIV     4
#endif
//#define DDR_LOOPC  (DDR_FREQ*DDR_DIV/33)   //72 //600MHz
#define DDRPLL_IN 33 
#define DDR_LOOPC  DDR_FREQ*DDR_DIV*DDR_REFC/DDRPLL_IN

// L1_* define core frequency
#define LS_PLL  USE_LS_PLL
#define ST_PLL  (1 - USE_LS_PLL)

#define L1_REFC     1   //do not modify
#define L1_DIV      2
//#define L1_LOOPC    (CORE_FREQ*L1_DIV/25)

#ifdef REF_33M
#define CPUPLL_IN 33
#elif defined(REF_100M)
#define CPUPLL_IN 100
#elif defined(REF_25M)
#define CPUPLL_IN 25
#else
#define CPUPLL_IN 25
#endif

#define L1_LOOPC CORE_FREQ*L1_DIV*L1_REFC/CPUPLL_IN

#define BYPASS_CORE 0x0
#define BYPASS_NODE 0x0
#define BYPASS_L1   0x0

#define SYS_PD	(((1 - ST_PLL) << 1) | (1 - LS_PLL))
#define PLL_L1_LOCKED ((ST_PLL << 17) | (LS_PLL << 16))
#define PLL_CHANG_COMMIT 0x1

#define BYPASS_REFIN 		(0x1 << 0)
#define CORE_CLKSEL		0x1c
#define CORE_HSEL		0x0c
#define PLL_L1_ENA		(0x1 << 2)

#define MEM_CLKSEL 		(0x01f << 5)
#define MEM_HSEL		(0x0f << 5)
#define PLL_MEM_ENA		(0x1 << 1)
#define PLL_MEM_LOCKED 		(01 << 16)

#define HT_HSEL			(0x1 << 15)

	TTYDBG ("Soft CLK SEL adjust begin\r\n")

	dli     t0, 0x900000001fe00194
	or	t0, t0, s1
	lw      a0, 0x0(t0)
	li      a1, CORE_CLKSEL
	and     a0, a0, a1
	li	a1, CORE_HSEL
	bne	a0, a1, 20f //soft_mem
	nop

//soft_sys:
	TTYDBG ("CORE & NODE:")

	dli     t0, 0x900000001fe001b0
	or	t0, t0, s1
	li	t1, (0x7 << 19) 	//power down pll L1 first
	sd	t1, 0x0(t0)
	dli	t1, (L1_DIV << 0)
	sd	t1, 0x8(t0)
	dli	t1, (L1_LOOPC << 54) | (L1_REFC  << 48) | \
                    (L1_DIV   << 42) | (L1_LOOPC << 32) | (L1_REFC << 26) | \
                    (SYS_PD   << 19) | (ST_PLL   << 22) | (0x3 << 10) | (0x1 << 7)
	sd	t1, 0(t0)
	ori	t1, PLL_L1_ENA
	sd      t1, 0x0(t0)

11: //wait_locked_sys:
	ld      a0, 0x0(t0)
	li      a1, PLL_L1_LOCKED
	and     a0, a1, a0
	beqz    a0, 11b //wait_locked_sys
	nop

	ld      a0, 0x0(t0)
	ori     a0, a0, PLL_CHANG_COMMIT
	sd      a0, 0x0(t0)

	bal     hexserial
	nop

20: //soft_mem:
#if DDR_SEL_ST
	dli     t0, 0x900000001fe001c0
	or	    t0, t0, s1
    dli     a0, (DDR_DIV << 24) | (DDR_LOOPC << 14) | (DDR_REFC << 8) | (DDR_SEL_ST << 30) | (0x3 << 4) | (0x1 << 3) | PLL_MEM_ENA | 0x1
    sw      a0, 0x0(t0)

#else

	dli     t0, 0x900000001fe001c0
	or	    t0, t0, s1
	li	    t1, (0x1 << 7) 	//power down all pll first
	sw	    t1, 0x0(t0)


	dli     t0, 0x900000001fe00194
	or	    t0, t0, s1
	lw      a0, 0x0(t0)
	li      a1, MEM_CLKSEL
	and     a0, a0, a1
	li	    a1, MEM_HSEL
	bne	    a0, a1, 30f
	nop

	TTYDBG ("\r\nMEM        :")

	dli     t0, 0x900000001fe001c0
	or	    t0, t0, s1
	dli     a0, (DDR_DIV << 24) | (DDR_LOOPC << 14) | (DDR_REFC << 8) | (0x3 << 4) | (0x1 << 3) | PLL_MEM_ENA
	sw	    a0, 0x0(t0)
21:
	lw      a0, 0x0(t0)
	li      a1, 0x00000040
	and     a0, a0, a1
	beqz    a0, 21b
	nop

	lw      a0, 0x0(t0)
	ori     a0, a0, 0x1
	sw      a0, 0x0(t0)

	bal     hexserial
	nop

	TTYDBG ("\r\nfdcoefficient  :")
	dli     t0, 0x900000001fe001c0
	or	    t0, t0, s1
	ld      t1,0x0(t0)
	dsrl    a0,t1,8
	and     a0,a0,63

	dsrl    a1,t1,14
	and     a1,a1,1023

	dmul    a0,a0,a1
	dsrl    a1,t1,24
	and     a1,a1,63

	ddiv    a0,a0,a1
	bal     hexserial
	nop

#endif


30: //soft_ht:
	TTYDBG ("\r\nHT         :")

	dli     t0, 0x900000001fe001b0
	or	t0, t0, s1
	lw      a0, 0x14(t0)
	bal     hexserial
	nop


//soft_out:

	TTYDBG ("\r\n")
	TTYDBG ("L1_DIV:")
    	li      a0, L1_DIV
	bal     hexserial
	nop
	TTYDBG ("\r\n")

	TTYDBG ("\r\n")
	TTYDBG ("DDR_REFC:")
    	li      a0, DDR_REFC
	bal     hexserial
	nop
	TTYDBG ("\r\n")

#endif


#ifdef BBGEN
	TTYDBG ("\r\nBBGEN start  :")
	dli     t0, 0x900000001fe001b0
	or	t0, t0, s1
	li	t1, (0x3f << 26) | (VBBn_VAL << 12) | (VBBp_VAL << 8) | (FEEDBACK << 4) | (0x3 << 2) | (0x0 << 1) | 0x1
	sw      t1, 0xc(t0)

	TTYDBG ("\r\nBBGEN config value  :")
	dli     t0, 0x900000001fe001b0
	or	t0, t0, s1
	lw      a0, 0xc(t0)

	bal     hexserial
	nop
	TTYDBG ("\r\n")
#endif
