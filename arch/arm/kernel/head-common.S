/*
 *  linux/arch/arm/kernel/head-common.S
 *
 *  Copyright (C) 1994-2002 Russell King
 *  Copyright (c) 2003 ARM Limited
 *  All Rights Reserved
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 */

#define ATAG_CORE 0x54410001
#define ATAG_CORE_SIZE ((2*4 + 3*4) >> 2)
#define ATAG_CORE_SIZE_EMPTY ((2*4) >> 2)

#ifdef CONFIG_CPU_BIG_ENDIAN
#define OF_DT_MAGIC 0xd00dfeed
#else
#define OF_DT_MAGIC 0xedfe0dd0 /* 0xd00dfeed in big-endian */
#endif

/*
 * Exception handling.  Something went wrong and we can't proceed.  We
 * ought to tell the user, but since we don't have any guarantee that
 * we're even running on the right architecture, we do virtually nothing.
 *
 * If CONFIG_DEBUG_LL is set we try to print out something about the error
 * and hope for the best (useful if bootloader fails to pass a proper
 * machine ID for example).
 */
	__HEAD

/* Determine validity of the r2 atags pointer.  The heuristic requires
 * that the pointer be aligned, in the first 16k of physical RAM and
 * that the ATAG_CORE marker is first and present.  If CONFIG_OF_FLATTREE
 * is selected, then it will also accept a dtb pointer.  Future revisions
 * of this function may be more lenient with the physical address and
 * may also be able to move the ATAGS block if necessary.
 *
 * Returns:
 *  r2 either valid atags pointer, valid dtb pointer, or zero
 *  r5, r6 corrupted
 /*
  * r1 = machine no, r2 = atags or dtb,
  * r8 = phys_offset, r9 = cpuid, r10 = procinfo
  */
 
__vet_atags:
	tst	r2, #0x3			@ aligned?
        /*!
         * 하위 2비트가 0인지 확인 
         aligned되어있는지 확인 
         */
	bne	1f

	ldr	r5, [r2, #0]
	/*!
         * r2는 Atag 포인터 . 
	 * ATAGS 의 header 첫 파라미터는 size
	 */
#ifdef CONFIG_OF_FLATTREE
	ldr	r6, =OF_DT_MAGIC		@ is it a DTB?
	/*!
	 * OF_DT_MAGIC = 0xd00dfeed
	 */
	cmp	r5, r6
	beq	2f
        /*!
         * DTB면은 패스 
         */
#endif
        /*!
         * 
            #define ATAG_CORE 0x54410001
            #define ATAG_CORE_SIZE ((2*4 + 3*4) >> 2)
            #define ATAG_CORE_SIZE_EMPTY ((2*4) >> 2)
         */
	cmp	r5, #ATAG_CORE_SIZE		@ is first tag ATAG_CORE?
	cmpne	r5, #ATAG_CORE_SIZE_EMPTY
        /*!
         * atag 가 맞는지 확인.
         * 맨처음에 헤더에서 사이즈를 확인을 하는 것이다.
	 * #define ATAG_CORE_SIZE ((2*4 + 3*4) >> 2)
	 * #define ATAG_CORE_SIZE_EMPTY ((2*4) >> 2)
         */
	bne	1f
	ldr	r5, [r2, #4]
	ldr	r6, =ATAG_CORE
	/*!
	 * #define ATAG_CORE 0x54410001
	 */
	cmp	r5, r6
	bne	1f

2:	mov	pc, lr				@ atag/dtb pointer is ok

1:	mov	r2, #0
	mov	pc, lr
ENDPROC(__vet_atags)

/*
 * The following fragment of code is executed with the MMU on in MMU mode,
 * and uses absolute addresses; this is not position independent.
 *
 *  r0  = cp#15 control register
 *  r1  = machine ID
 *  r2  = atags/dtb pointer
 *  r9  = processor ID
 */
	__INIT
__mmap_switched:
	/*!
	 * arch/arm/kernel/head.S 에서 호출됨
	 */
	adr	r3, __mmap_switched_data

	ldmia	r3!, {r4, r5, r6, r7}
	/*!
	 * .long	__data_loc	현재 데이터가 있는 위치		@ r4
	 * .long	_sdata		데이터가 있어야 할 위치(링크가 부여한 주소)	@ r5
	 * .long	__bss_start			@ r6
	 * .long	_end				@ r7
	 */
	cmp	r4, r5				@ Copy data segment if needed
1:	cmpne	r5, r6
	ldrne	fp, [r4], #4
	strne	fp, [r5], #4
	bne	1b

	mov	fp, #0				@ Clear BSS (and zero fp)
1:	cmp	r6, r7
	strcc	fp, [r6],#4
	bcc	1b

 ARM(	ldmia	r3, {r4, r5, r6, r7, sp})
	/*!
	 * .long	processor_id			@ r4
	 * .long	__machine_arch_type		@ r5
	 * .long	__atags_pointer			@ r6
	 * .long	cr_alignment			@ r7
	 * .long	init_thread_union + THREAD_START_SP @ sp
	 */
 THUMB(	ldmia	r3, {r4, r5, r6, r7}	)
 THUMB(	ldr	sp, [r3, #16]		)
	str	r9, [r4]			@ Save processor ID
	str	r1, [r5]			@ Save machine type
	str	r2, [r6]			@ Save atags pointer
	cmp	r7, #0
	bicne	r4, r0, #CR_A			@ Clear 'A' bit
	/*!
	 * 다르면 첫번째 비트를 clear
	 */
	stmneia	r7, {r0, r4}			@ Save control register values
	/*!
	 * cr alignment 위치과 alignment  
	 */
	b	start_kernel
ENDPROC(__mmap_switched)

	.align	2
	.type	__mmap_switched_data, %object
__mmap_switched_data:
	.long	__data_loc			@ r4
	.long	_sdata				@ r5
	.long	__bss_start			@ r6
	.long	_end				@ r7
	.long	processor_id			@ r4
	.long	__machine_arch_type		@ r5
	.long	__atags_pointer			@ r6
#ifdef CONFIG_CPU_CP15
	.long	cr_alignment			@ r7
#else
	.long	0				@ r7
#endif
	.long	init_thread_union + THREAD_START_SP @ sp
	.size	__mmap_switched_data, . - __mmap_switched_data

/*
 * This provides a C-API version of __lookup_processor_type
 */
ENTRY(lookup_processor_type)
	stmfd	sp!, {r4 - r6, r9, lr}
	mov	r9, r0
	/*! 20130803
	 * r9: cpu id
	 */
	bl	__lookup_processor_type
	mov	r0, r5
	ldmfd	sp!, {r4 - r6, r9, pc}
ENDPROC(lookup_processor_type)

	__FINIT
	.text

/*
 * Read processor ID register (CP#15, CR0), and look up in the linker-built
 * supported processor list.  Note that we can't use the absolute addresses
 * for the __proc_info lists since we aren't running with the MMU on
 * (and therefore, we are not in the correct address space).  We have to
 * calculate the offset.
 *
 *	r9 = cpuid
 * Returns:
 *	r3, r4, r6 corrupted
 *	r5 = proc_info pointer in physical address space
 *	r9 = cpuid (preserved)
 */
__lookup_processor_type:
	adr	r3, __lookup_processor_type_data
        /*!
         * lookup_processor_type_data 의 주소를 r3에 넣는다.
	 */
	ldmia	r3, {r4 - r6}
        /*!
         * r4 = lookup_processor_type_data의 주소  
           r5 = __proc_info_begin
           r6 = __proc_info_end
         */
        /*!
         * mmu를 제거하여서 physical address에서 작동하게 된다.
           시작값을 링커가 할당할때 virtual address로 할당을 해주었을 것이다.
           그렇기 때문에 r3 자체가 look~~~가지고 있는데 r4의 값은 현재 주소르 
           가져오게 되며 주소값에 차이에 해당하는 offset을 찾게 되는것이다.

           예)
           c0008010 , 40008010 두개의 차이를 두면 8천만 정도의 차이를 알아낼수 있다.
           실제 현재 접근할수 있는 proc_info_begin의 값을 얻어오기 위해서.

           base주소 구해서 거기에 보정을 주는 것이다.
         */
	sub	r3, r3, r4			@ get offset between virt&phys
	/*!
	 * r4 = . 이고 r3는 virture address이므로 버추어 주소와 물리 주소의 차이를 구한다.
	 * 현재는 MMU를 껐기 때문에 phys 주소다.
	 */
	add	r5, r5, r3			@ convert virt addresses to
	add	r6, r6, r3			@ physical address space
 	 /*!
               __v7_ca7mp_proc_info:
         r3	.long	0x410fc070
	 r4     .long	0xff0ffff0
         r9 = MIDR  ( CPU ID )
         */
1:	ldmia	r5, {r3, r4}			@ value, mask
	/*!
	 * value = .long   0x410fc070
	 * mask =  .long   0xff0ffff0
	 */
	and	r4, r4, r9			@ mask wanted bits
        /*!
         * MIDR 과 mask 와 and연산 수행.
         */
	teq	r3, r4
        /*!
         * processor id와 동일한지 비교.
         */
	beq	2f
	add	r5, r5, #PROC_INFO_SZ		@ sizeof(proc_info_list)
	cmp	r5, r6
	blo	1b
        /*!
         * loop하면서 찾아내는 것.PROC_INFO_SZ만큼 더하면서.
         */
	mov	r5, #0				@ unknown processor
        /*!
         * processor id 를 찾지 못하면은 0값을 return 
         */
2:	mov	pc, lr
ENDPROC(__lookup_processor_type)

/*
 * Look in <asm/procinfo.h> for information about the __proc_info structure.
 */
	.align	2
	.type	__lookup_processor_type_data, %object
__lookup_processor_type_data:
	.long	.
	.long	__proc_info_begin
	.long	__proc_info_end
	.size	__lookup_processor_type_data, . - __lookup_processor_type_data

__error_p:
#ifdef CONFIG_DEBUG_LL
	adr	r0, str_p1
	bl	printascii
	mov	r0, r9
	bl	printhex8
	adr	r0, str_p2
	bl	printascii
	b	__error
str_p1:	.asciz	"\nError: unrecognized/unsupported processor variant (0x"
str_p2:	.asciz	").\n"
	.align
#endif
ENDPROC(__error_p)

__error:
#ifdef CONFIG_ARCH_RPC
/*
 * Turn the screen red on a error - RiscPC only.
 */
	mov	r0, #0x02000000
	mov	r3, #0x11
	orr	r3, r3, r3, lsl #8
	orr	r3, r3, r3, lsl #16
	str	r3, [r0], #4
	str	r3, [r0], #4
	str	r3, [r0], #4
	str	r3, [r0], #4
#endif
1:	mov	r0, r0
	b	1b
ENDPROC(__error)
