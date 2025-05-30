.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_8vect_dot_prod_sve2)
#ifndef __APPLE__
.type gf_8vect_dot_prod_sve2, %function
#endif
/* void gf_8vect_dot_prod_sve2(int len, int vlen, unsigned char *gftbls,
				   unsigned char **src, unsigned char **dest);
 */

/* arguments */
x_len		.req	x0	/* vector length */
x_vec		.req	x1	/* number of source vectors (ie. data blocks) */
x_tbl		.req	x2
x_src		.req	x3
x_dest		.req	x4

/* returns */
w_ret		.req	w0

/* local variables */
x_vec_i		.req	x5
x_ptr		.req	x6
x_pos		.req	x7

x_tbl1		.req	x8
x_tbl2		.req	x9
x_tbl3		.req	x10
x_tbl4		.req	x11
x_tbl5		.req	x12
x_tbl6		.req	x13
x_tbl7		.req	x14

x_dest1		.req	x15

/* r16,r17,r18,r29,r30: special role registers, avoided */
/* r19..r29 and SP must be preserved */
x_dest2		.req	x19
x_dest3		.req	x20
x_dest4		.req	x21
x_dest5		.req	x22
x_dest6		.req	x23
x_dest7		.req	x24
x_dest8		.req	x_dest	/* reused */
x_tbl8		.req	x25

/* vectors - optimized layout for SVE2 */
z_mask0f	.req	z0

z_src		.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z3

/* Destination vectors */
z_dest1		.req	z4
z_dest2		.req	z5
z_dest3		.req	z6
z_dest4		.req	z7
z_dest5		.req	z8
z_dest6		.req	z9
z_dest7		.req	z10
z_dest8		.req	z11

/* GF table vectors - better register allocation */
z_gft1_lo	.req	z12
z_gft1_hi	.req	z13
z_gft2_lo	.req	z14
z_gft2_hi	.req	z15
z_gft3_lo	.req	z16
z_gft3_hi	.req	z17
z_gft4_lo	.req	z18
z_gft4_hi	.req	z19

z_gft5_lo	.req	z20
z_gft5_hi	.req	z21
z_gft6_lo	.req	z22
z_gft6_hi	.req	z23
z_gft7_lo	.req	z24
z_gft7_hi	.req	z25
z_gft8_lo	.req	z26
z_gft8_hi	.req	z27

/* Temporary vectors for SVE2 optimizations */
z_tmp1		.req	z28
z_tmp2		.req	z29
z_tmp3		.req	z30
z_tmp4		.req	z31

cdecl(gf_8vect_dot_prod_sve2):
	/* less than 16 bytes, return_fail */
	cmp	x_len, #16
	blt	.return_fail

	/* save r19..r29  */
	sub	sp, sp, #80			/* alignment */
	stp	x19, x20, [sp]
	stp	x21, x22, [sp, #16]
	stp	x23, x24, [sp, #32]
	stp	d8,  d9,  [sp, #48]
	str	d10, [sp, #56]
	str	x25, [sp, #64]

	mov	z_mask0f.b, #0x0f		/* z_mask0f = 0x0F0F...0F */
	mov	x_pos, #0
	lsl	x_vec, x_vec, #3
	ldp	x_dest1, x_dest2, [x_dest, #8*0]
	ldp	x_dest3, x_dest4, [x_dest, #8*2]
	ldp	x_dest5, x_dest6, [x_dest, #8*4]
	ldp	x_dest7, x_dest8, [x_dest, #8*6]	/* x_dest8 reuses x_dest */

/* Loop 1: x_len, vector length */
.Lloopsve2_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	mov	x_vec_i, #0			/* clear x_vec_i */
	ldr	x_ptr, [x_src, x_vec_i]		/* x_ptr: src base addr. */

	/* SVE2: Use EOR3 for efficient 3-way XOR initialization - clear all dest vectors */
	eor3	z_dest1.d, z_dest1.d, z_dest1.d, z_dest1.d
	eor3	z_dest2.d, z_dest2.d, z_dest2.d, z_dest2.d
	eor3	z_dest3.d, z_dest3.d, z_dest3.d, z_dest3.d
	eor3	z_dest4.d, z_dest4.d, z_dest4.d, z_dest4.d
	eor3	z_dest5.d, z_dest5.d, z_dest5.d, z_dest5.d
	eor3	z_dest6.d, z_dest6.d, z_dest6.d, z_dest6.d
	eor3	z_dest7.d, z_dest7.d, z_dest7.d, z_dest7.d
	eor3	z_dest8.d, z_dest8.d, z_dest8.d, z_dest8.d

	/* gf_tbl base = (x_tbl + dest_idx * x_vec * 32) */
	mov	x_tbl1, x_tbl			/* reset x_tbl1 */
	add	x_tbl2, x_tbl1, x_vec, LSL #2	/* reset x_tbl2 */
	add	x_tbl3, x_tbl2, x_vec, LSL #2	/* reset x_tbl3 */
	add	x_tbl4, x_tbl3, x_vec, LSL #2	/* reset x_tbl4 */
	add	x_tbl5, x_tbl4, x_vec, LSL #2	/* reset x_tbl5 */
	add	x_tbl6, x_tbl5, x_vec, LSL #2	/* reset x_tbl6 */
	add	x_tbl7, x_tbl6, x_vec, LSL #2	/* reset x_tbl7 */
	add	x_tbl8, x_tbl7, x_vec, LSL #2	/* reset x_tbl8 */

/* Loop 2: x_vec, number of source vectors (ie. data blocks) */
.Lloopsve2_vl_vects:
	/* load src data, governed by p0 */
	ld1b	z_src.b,  p0/z, [x_ptr, x_pos]	/* load from: src base + pos offset */
	
	/* SVE2: Enhanced bit manipulation */
	and	z_src_lo.d, z_src.d, z_mask0f.d
	/* SVE2: Use USHR for more efficient right shift */
	ushr	z_src_hi.b, z_src.b, #4

	/* Load GF tables with better scheduling - batch load first 4 */
	ld1b	z_gft1_lo.b, p0/z, [x_tbl1]
	ld1b	z_gft1_hi.b, p0/z, [x_tbl1, #1, mul vl]
	ld1b	z_gft2_lo.b, p0/z, [x_tbl2]
	ld1b	z_gft2_hi.b, p0/z, [x_tbl2, #1, mul vl]
	
	/* Enhanced prefetching */
	prfb	pldl2keep, p0, [x_tbl1, #2, mul vl]
	prfb	pldl2keep, p0, [x_tbl2, #2, mul vl]

	/* calc for next and prefetch */
	add	x_vec_i, x_vec_i, #8		/* move x_vec_i to next */
	ldr	x_ptr, [x_src, x_vec_i]		/* x_ptr: src base addr. */

	/* Load next batch of tables */
	ld1b	z_gft3_lo.b, p0/z, [x_tbl3]
	ld1b	z_gft3_hi.b, p0/z, [x_tbl3, #1, mul vl]
	ld1b	z_gft4_lo.b, p0/z, [x_tbl4]
	ld1b	z_gft4_hi.b, p0/z, [x_tbl4, #1, mul vl]

	/* SVE2: Parallel table lookups with EOR3 optimization - destinations 1-4 */
	tbl	z_tmp1.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_tmp2.b, {z_gft1_hi.b}, z_src_hi.b
	/* SVE2: Use EOR3 for 3-way XOR operations */
	eor3	z_dest1.d, z_dest1.d, z_tmp1.d, z_tmp2.d

	tbl	z_tmp1.b, {z_gft2_lo.b}, z_src_lo.b
	tbl	z_tmp2.b, {z_gft2_hi.b}, z_src_hi.b
	eor3	z_dest2.d, z_dest2.d, z_tmp1.d, z_tmp2.d

	/* Load next batch while processing */
	ld1b	z_gft5_lo.b, p0/z, [x_tbl5]
	ld1b	z_gft5_hi.b, p0/z, [x_tbl5, #1, mul vl]
	ld1b	z_gft6_lo.b, p0/z, [x_tbl6]
	ld1b	z_gft6_hi.b, p0/z, [x_tbl6, #1, mul vl]

	tbl	z_tmp1.b, {z_gft3_lo.b}, z_src_lo.b
	tbl	z_tmp2.b, {z_gft3_hi.b}, z_src_hi.b
	eor3	z_dest3.d, z_dest3.d, z_tmp1.d, z_tmp2.d

	tbl	z_tmp1.b, {z_gft4_lo.b}, z_src_lo.b
	tbl	z_tmp2.b, {z_gft4_hi.b}, z_src_hi.b
	eor3	z_dest4.d, z_dest4.d, z_tmp1.d, z_tmp2.d

	/* Load final batch */
	ld1b	z_gft7_lo.b, p0/z, [x_tbl7]
	ld1b	z_gft7_hi.b, p0/z, [x_tbl7, #1, mul vl]
	ld1b	z_gft8_lo.b, p0/z, [x_tbl8]
	ld1b	z_gft8_hi.b, p0/z, [x_tbl8, #1, mul vl]

	/* SVE2: Process destinations 5-8 with parallel operations */
	tbl	z_tmp1.b, {z_gft5_lo.b}, z_src_lo.b
	tbl	z_tmp2.b, {z_gft5_hi.b}, z_src_hi.b
	tbl	z_tmp3.b, {z_gft6_lo.b}, z_src_lo.b
	tbl	z_tmp4.b, {z_gft6_hi.b}, z_src_hi.b
	
	/* SVE2: Parallel EOR3 operations */
	eor3	z_dest5.d, z_dest5.d, z_tmp1.d, z_tmp2.d
	eor3	z_dest6.d, z_dest6.d, z_tmp3.d, z_tmp4.d

	tbl	z_tmp1.b, {z_gft7_lo.b}, z_src_lo.b
	tbl	z_tmp2.b, {z_gft7_hi.b}, z_src_hi.b
	tbl	z_tmp3.b, {z_gft8_lo.b}, z_src_lo.b
	tbl	z_tmp4.b, {z_gft8_hi.b}, z_src_hi.b

	eor3	z_dest7.d, z_dest7.d, z_tmp1.d, z_tmp2.d
	eor3	z_dest8.d, z_dest8.d, z_tmp3.d, z_tmp4.d

	/* Update table pointers for next iteration */
	add	x_tbl1, x_tbl1, #32
	add	x_tbl2, x_tbl2, #32
	add	x_tbl3, x_tbl3, #32
	add	x_tbl4, x_tbl4, #32
	add	x_tbl5, x_tbl5, #32
	add	x_tbl6, x_tbl6, #32
	add	x_tbl7, x_tbl7, #32
	add	x_tbl8, x_tbl8, #32

	cmp	x_vec_i, x_vec
	blt	.Lloopsve2_vl_vects
/* end of Loop 2 */

	/* SVE2: Optimized stores - consider using structured stores */
	st1b	z_dest1.b, p0, [x_dest1, x_pos]
	st1b	z_dest2.b, p0, [x_dest2, x_pos]
	st1b	z_dest3.b, p0, [x_dest3, x_pos]
	st1b	z_dest4.b, p0, [x_dest4, x_pos]
	st1b	z_dest5.b, p0, [x_dest5, x_pos]
	st1b	z_dest6.b, p0, [x_dest6, x_pos]
	st1b	z_dest7.b, p0, [x_dest7, x_pos]
	st1b	z_dest8.b, p0, [x_dest8, x_pos]

	/* increment one vector length */
	incb	x_pos
	b	.Lloopsve2_vl
/* end of Loop 1 */

.return_pass:
	/* restore r19..r29  */
	ldr	x25, [sp, #64]
	ldr	d10, [sp, #56]
	ldp	d8,  d9,  [sp, #48]
	ldp	x23, x24, [sp, #32]
	ldp	x21, x22, [sp, #16]
	ldp	x19, x20, [sp]
	add	sp, sp, #80

	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret