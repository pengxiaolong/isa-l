.text
.align		6
.arch		armv9-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_2vect_mad_sve2)
#ifndef __APPLE__
.type gf_2vect_mad_sve2, %function
#endif

/* Arguments */
x_len		.req	x0
x_vec		.req	x1
x_vec_i		.req	x2
x_tbl		.req	x3
x_src		.req	x4
x_dest		.req	x5

/* Vectors */
z_mask0f	.req	z0
z_src		.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z1      /* Reuse z_src */
z_dest1		.req	z3
z_dest2		.req	z4
z_tmp_lo	.req	z5
z_tmp_hi	.req	z6
z_gft1_lo	.req	z7
z_gft1_hi	.req	z16     /* Use call-clobbered register */
z_gft2_lo	.req	z17
z_gft2_hi	.req	z18

cdecl(gf_2vect_mad_sve2):
	cmp	x_len, #16
	blt	.return_fail

	mov	z_mask0f.b, #0x0f        /* 0x0F mask */
	index	z_pos.b, #0, #1          /* Create position vector */
	
	/* Load tables using SVE2 */
	add	x_tbl, x_tbl, x_vec_i, LSL #5
	ld2b	{z_gft1_lo.b, z_gft1_hi.b}, p0/z, [x_tbl]
	add	x_tbl, x_tbl, x_vec, LSL #5
	ld2b	{z_gft2_lo.b, z_gft2_hi.b}, p0/z, [x_tbl]

	ldp	x_dest1, x_dest2, [x_dest]       /* Load both dest pointers */
	mov	x_pos, #0

.Lloopsve_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	/* SVE2 optimized prefetch */
	prfb	pldl2keep, p0, [x_dest1, x_pos]
	prfb	pldl2keep, p0, [x_dest2, x_pos]

	/* Load source and split nibbles */
	ld1b	z_src.b, p0/z, [x_src, x_pos]
	lsr	z_src_hi.b, z_src.b, #4          /* High nibbles */
	and	z_src_lo.d, z_src.d, z_mask0f.d  /* Low nibbles */

	/* Load destinations */
	ld1b	z_dest1.b, p0/z, [x_dest1, x_pos]
	ld1b	z_dest2.b, p0/z, [x_dest2, x_pos]

	/* GF multiply-accumulate for dest1 */
	tbl	z_tmp_lo.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft1_hi.b}, z_src_hi.b
	eor	z_dest1.d, z_dest1.d, z_tmp_lo.d
	eor	z_dest1.d, z_dest1.d, z_tmp_hi.d

	/* GF multiply-accumulate for dest2 */
	tbl	z_tmp_lo.b, {z_gft2_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft2_hi.b}, z_src_hi.b
	eor	z_dest2.d, z_dest2.d, z_tmp_lo.d
	eor	z_dest2.d, z_dest2.d, z_tmp_hi.d

	/* Non-temporal store for better cache behavior */
	stnt1b	z_dest1.b, p0, [x_dest1, x_pos]
	stnt1b	z_dest2.b, p0, [x_dest2, x_pos]

	/* Increment with SVE2 syntax */
	incb	x_pos, ALL, MUL #1
	b	.Lloopsve_vl

.return_pass:
	mov	w0, #0
	ret

.return_fail:
	mov	w0, #1
	ret