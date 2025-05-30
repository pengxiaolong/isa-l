.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_2vect_dot_prod_sve2)
#ifndef __APPLE__
.type gf_2vect_dot_prod_sve2, %function
#endif

/* Arguments */
x_len		.req	x0	/* vector length */
x_vec		.req	x1	/* number of source vectors */
x_tbl		.req	x2
x_src		.req	x3
x_dest		.req	x4

/* Returns */
w_ret		.req	w0

/* Local variables */
x_vec_i		.req	x5
x_ptr		.req	x6
x_pos		.req	x7
x_tbl1		.req	x8
x_tbl2		.req	x9
x_dest1		.req	x10
x_dest2		.req	x4	/* Reuse x_dest */

/* Vector registers */
z_mask0f	.req	z0
z_src		.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z1	/* Reuse z_src */
z_dest1		.req	z3
z_gft1_lo	.req	z4
z_gft1_hi	.req	z5
z_gft2_lo	.req	z17
z_gft2_hi	.req	z18
z_dest2		.req	z27

cdecl(gf_2vect_dot_prod_sve2):
	/* Minimum vector length check */
	cmp	x_len, #16
	blt	.return_fail

	/* Initial setup */
	mov	z_mask0f.b, #0x0f		/* z_mask0f = 0x0F0F...0F */
	mov	x_pos, #0
	lsl	x_vec, x_vec, #3		/* x_vec *= 8 (for pointer arithmetic) */
	ldp	x_dest1, x_dest2, [x_dest, #8*0]

	/* Main vector length loop */
.Lloopsve_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	mov	x_vec_i, #0			/* Clear vector index */
	ldr	x_ptr, [x_src, x_vec_i]		/* Load first source pointer */

	/* Clear accumulation registers */
	eor	z_dest1.d, z_dest1.d, z_dest1.d
	eor	z_dest2.d, z_dest2.d, z_dest2.d

	/* Set up table pointers */
	mov	x_tbl1, x_tbl			/* First table */
	add	x_tbl2, x_tbl1, x_vec, LSL #2	/* Second table (x_vec * 4) */

	/* Inner loop over source vectors */
.Lloopsve_vl_vects:
	/* Load source data and split nibbles */
	ld1b	z_src.b, p0/z, [x_ptr, x_pos]
	and	z_src_lo.d, z_src.d, z_mask0f.d
	usra	z_src_hi.b, z_src.b, #4	/* SVE2: usra is faster than lsr+mov */

	/* Load Galois field tables */
	ldp	q_gft1_lo, q_gft1_hi, [x_tbl1], #32
	ldp	q_gft2_lo, q_gft2_hi, [x_tbl2], #32

	/* Prefetch next table entries */
	prfb	pldl2keep, p0, [x_tbl1]
	prfb	pldl2keep, p0, [x_tbl2]

	/* Prepare for next iteration */
	add	x_vec_i, x_vec_i, #8
	ldr	x_ptr, [x_src, x_vec_i]

	/* GF(2^8) multiply-accumulate for dest1 */
	tbl	z_gft1_lo.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_gft1_hi.b, {z_gft1_hi.b}, z_src_hi.b
	eor3	z_dest1.d, z_gft1_lo.d, z_gft1_hi.d, z_dest1.d	/* SVE2: eor3 is faster */

	/* GF(2^8) multiply-accumulate for dest2 */
	tbl	z_gft2_lo.b, {z_gft2_lo.b}, z_src_lo.b
	tbl	z_gft2_hi.b, {z_gft2_hi.b}, z_src_hi.b
	eor3	z_dest2.d, z_gft2_lo.d, z_gft2_hi.d, z_dest2.d	/* SVE2: eor3 is faster */

	cmp	x_vec_i, x_vec
	blt	.Lloopsve_vl_vects

	/* Store results */
	st1b	z_dest1.b, p0, [x_dest1, x_pos]
	st1b	z_dest2.b, p0, [x_dest2, x_pos]

	/* Next vector position */
	incb	x_pos
	b	.Lloopsve_vl

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret