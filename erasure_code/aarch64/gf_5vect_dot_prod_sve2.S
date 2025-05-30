.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_5vect_dot_prod_sve2)
#ifndef __APPLE__
.type gf_5vect_dot_prod_sve2, %function
#endif
/* void gf_5vect_dot_prod_sve2(int len, int vlen, unsigned char *gftbls,
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
x_dest1		.req	x13
x_dest2		.req	x14
x_dest4		.req	x15
x_dest5		.req	x_dest	/* reused */

/* r16,r17,r18,r29,r30: special role registers, avoided */
/* r19..r29 and SP must be preserved */
x_dest3		.req	x19

/* vectors */
z_mask0f	.req	z0

z_src		.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z_src

z_dest1		.req	z3
z_dest2		.req	z27
z_dest3		.req	z28
z_dest4		.req	z29
z_dest5		.req	z30

/* Temporary vectors for parallel computation */
z_tmp1_lo	.req	z4
z_tmp1_hi	.req	z5
z_tmp2_lo	.req	z6
z_tmp2_hi	.req	z7
z_tmp3_lo	.req	z8
z_tmp3_hi	.req	z9
z_tmp4_lo	.req	z10
z_tmp4_hi	.req	z11
z_tmp5_lo	.req	z12
z_tmp5_hi	.req	z13

z_gft1_lo	.req	z14
z_gft1_hi	.req	z15
q_gft1_lo	.req	q14
q_gft1_hi	.req	q15

z_gft2_lo	.req	z17
z_gft2_hi	.req	z18
q_gft2_lo	.req	q17
q_gft2_hi	.req	q18

z_gft3_lo	.req	z19
z_gft3_hi	.req	z20
q_gft3_lo	.req	q19
q_gft3_hi	.req	q20

z_gft4_lo	.req	z21
z_gft4_hi	.req	z22
q_gft4_lo	.req	q21
q_gft4_hi	.req	q22

z_gft5_lo	.req	z23
z_gft5_hi	.req	z24
q_gft5_lo	.req	q23
q_gft5_hi	.req	q24

cdecl(gf_5vect_dot_prod_sve2):
	/* less than 16 bytes, return_fail */
	cmp	x_len, #16
	blt	.return_fail

	/* save r19..r29  */
	sub	sp, sp, #16			/* alignment */
	str	x19, [sp]

	mov	z_mask0f.b, #0x0f		/* z_mask0f = 0x0F0F...0F */
	mov	x_pos, #0
	lsl	x_vec, x_vec, #3
	ldp	x_dest1, x_dest2, [x_dest, #8*0]
	ldp	x_dest3, x_dest4, [x_dest, #8*2]
	ldr	x_dest5, [x_dest, #8*4]

/* Loop 1: x_len, vector length */
.Lloopsve2_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	mov	x_vec_i, #0			/* clear x_vec_i */
	ldr	x_ptr, [x_src, x_vec_i]		/* x_ptr: src base addr. */

	/* SVE2: Initialize destination vectors to zero using DUP */
	dup	z_dest1.b, #0
	dup	z_dest2.b, #0
	dup	z_dest3.b, #0
	dup	z_dest4.b, #0
	dup	z_dest5.b, #0

	/* gf_tbl base = (x_tbl + dest_idx * x_vec * 32) */
	mov	x_tbl1, x_tbl			/* reset x_tbl1 */
	add	x_tbl2, x_tbl1, x_vec, LSL #2	/* reset x_tbl2 */
	add	x_tbl3, x_tbl2, x_vec, LSL #2	/* reset x_tbl3 */
	add	x_tbl4, x_tbl3, x_vec, LSL #2	/* reset x_tbl4 */
	add	x_tbl5, x_tbl4, x_vec, LSL #2	/* reset x_tbl5 */

/* Loop 2: x_vec, number of source vectors (ie. data blocks) */
.Lloopsve2_vl_vects:
	/* load src data, governed by p0 */
	ld1b	z_src.b,  p0/z, [x_ptr, x_pos]	/* load from: src base + pos offset */
	
	/* SVE2: Use BEXT for efficient nibble extraction */
	bext	z_src_lo.b, z_src.b, z_mask0f.b
	lsr	z_src_hi.b, z_src.b, #4

	/* Load all GF tables in parallel */
	ldp	q_gft1_lo, q_gft1_hi, [x_tbl1], #32
	ldp	q_gft2_lo, q_gft2_hi, [x_tbl2], #32
	ldp	q_gft3_lo, q_gft3_hi, [x_tbl3], #32
	ldp	q_gft4_lo, q_gft4_hi, [x_tbl4], #32
	ldp	q_gft5_lo, q_gft5_hi, [x_tbl5], #32

	/* Prefetch next tables */
	prfb	pldl2keep, p0, [x_tbl1]
	prfb	pldl2keep, p0, [x_tbl2]
	prfb	pldl2keep, p0, [x_tbl3]
	prfb	pldl2keep, p0, [x_tbl4]
	prfb	pldl2keep, p0, [x_tbl5]

	/* calc for next iteration */
	add	x_vec_i, x_vec_i, #8		/* move x_vec_i to next */
	ldr	x_ptr, [x_src, x_vec_i]		/* x_ptr: src base addr. */

	/* SVE2: Parallel table lookups for all destinations */
	tbl	z_tmp1_lo.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_tmp1_hi.b, {z_gft1_hi.b}, z_src_hi.b
	tbl	z_tmp2_lo.b, {z_gft2_lo.b}, z_src_lo.b
	tbl	z_tmp2_hi.b, {z_gft2_hi.b}, z_src_hi.b
	tbl	z_tmp3_lo.b, {z_gft3_lo.b}, z_src_lo.b
	tbl	z_tmp3_hi.b, {z_gft3_hi.b}, z_src_hi.b
	tbl	z_tmp4_lo.b, {z_gft4_lo.b}, z_src_lo.b
	tbl	z_tmp4_hi.b, {z_gft4_hi.b}, z_src_hi.b
	tbl	z_tmp5_lo.b, {z_gft5_lo.b}, z_src_lo.b
	tbl	z_tmp5_hi.b, {z_gft5_hi.b}, z_src_hi.b

	/* SVE2: Use EOR3 for 3-way XOR operations */
	eor3	z_dest1.d, z_dest1.d, z_tmp1_lo.d, z_tmp1_hi.d
	eor3	z_dest2.d, z_dest2.d, z_tmp2_lo.d, z_tmp2_hi.d
	eor3	z_dest3.d, z_dest3.d, z_tmp3_lo.d, z_tmp3_hi.d
	eor3	z_dest4.d, z_dest4.d, z_tmp4_lo.d, z_tmp4_hi.d
	eor3	z_dest5.d, z_dest5.d, z_tmp5_lo.d, z_tmp5_hi.d

	cmp	x_vec_i, x_vec
	blt	.Lloopsve2_vl_vects
/* end of Loop 2 */

	/* SVE2: Parallel stores for all destinations */
	st1b	z_dest1.b, p0, [x_dest1, x_pos]
	st1b	z_dest2.b, p0, [x_dest2, x_pos]
	st1b	z_dest3.b, p0, [x_dest3, x_pos]
	st1b	z_dest4.b, p0, [x_dest4, x_pos]
	st1b	z_dest5.b, p0, [x_dest5, x_pos]

	/* increment one vector length */
	incb	x_pos
	b	.Lloopsve2_vl
/* end of Loop 1 */

.return_pass:
	/* restore r19..r29  */
	ldr	x19, [sp]
	add	sp, sp, #16

	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret