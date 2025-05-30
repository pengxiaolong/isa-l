.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_6vect_mad_sve2)
#ifndef __APPLE__
.type gf_6vect_mad_sve2, %function
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
z_dest3		.req	z5
z_dest4		.req	z6
z_dest5		.req	z7
z_dest6		.req	z16     /* Use call-clobbered registers */
z_tmp_lo	.req	z17
z_tmp_hi	.req	z18
z_gft1_lo	.req	z19
z_gft1_hi	.req	z20
z_gft2_lo	.req	z21
z_gft2_hi	.req	z22
z_gft3_lo	.req	z23
z_gft3_hi	.req	z24
z_gft4_lo	.req	z25
z_gft4_hi	.req	z26
z_gft5_lo	.req	z27
z_gft5_hi	.req	z28
z_gft6_lo	.req	z29
z_gft6_hi	.req	z30

cdecl(gf_6vect_mad_sve2):
	cmp	x_len, #16
	blt	.return_fail

	mov	z_mask0f.b, #0x0f        /* 0x0F mask */
	index	z_pos.b, #0, #1          /* Create position vector */
	
	/* Load tables using SVE2 */
	add	x_tbl, x_tbl, x_vec_i, LSL #5
	/* Load first 4 tables */
	ld4b	{z_gft1_lo.b, z_gft2_lo.b, z_gft3_lo.b, z_gft4_lo.b}, p0/z, [x_tbl]
	ld4b	{z_gft1_hi.b, z_gft2_hi.b, z_gft3_hi.b, z_gft4_hi.b}, p0/z, [x_tbl, #4, mul vl]
	/* Load last 2 tables */
	add	x_tbl, x_tbl, x_vec, LSL #5
	ld2b	{z_gft5_lo.b, z_gft6_lo.b}, p0/z, [x_tbl]
	ld2b	{z_gft5_hi.b, z_gft6_hi.b}, p0/z, [x_tbl, #2, mul vl]

	/* Load all destination pointers */
	ldp	x_dest1, x_dest2, [x_dest]
	ldp	x_dest3, x_dest4, [x_dest, #16]
	ldp	x_dest5, x_dest6, [x_dest, #32]
	mov	x_pos, #0

.Lloopsve_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	/* SVE2 optimized prefetch */
	prfb	pldl2keep, p0, [x_dest1, x_pos]
	prfb	pldl2keep, p0, [x_dest2, x_pos]
	prfb	pldl2keep, p0, [x_dest3, x_pos]
	prfb	pldl2keep, p0, [x_dest4, x_pos]
	prfb	pldl2keep, p0, [x_dest5, x_pos]
	prfb	pldl2keep, p0, [x_dest6, x_pos]

	/* Load source and split nibbles */
	ld1b	z_src.b, p0/z, [x_src, x_pos]
	lsr	z_src_hi.b, z_src.b, #4          /* High nibbles */
	and	z_src_lo.d, z_src.d, z_mask0f.d  /* Low nibbles */

	/* Load destinations */
	ld1b	z_dest1.b, p0/z, [x_dest1, x_pos]
	ld1b	z_dest2.b, p0/z, [x_dest2, x_pos]
	ld1b	z_dest3.b, p0/z, [x_dest3, x_pos]
	ld1b	z_dest4.b, p0/z, [x_dest4, x_pos]
	ld1b	z_dest5.b, p0/z, [x_dest5, x_pos]
	ld1b	z_dest6.b, p0/z, [x_dest6, x_pos]

	/* GF multiply-accumulate for all 6 destinations */
	tbl	z_tmp_lo.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft1_hi.b}, z_src_hi.b
	eor	z_dest1.d, z_dest1.d, z_tmp_lo.d
	eor	z_dest1.d, z_dest1.d, z_tmp_hi.d

	tbl	z_tmp_lo.b, {z_gft2_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft2_hi.b}, z_src_hi.b
	eor	z_dest2.d, z_dest2.d, z_tmp_lo.d
	eor	z_dest2.d, z_dest2.d, z_tmp_hi.d

	tbl	z_tmp_lo.b, {z_gft3_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft3_hi.b}, z_src_hi.b
	eor	z_dest3.d, z_dest3.d, z_tmp_lo.d
	eor	z_dest3.d, z_dest3.d, z_tmp_hi.d

	tbl	z_tmp_lo.b, {z_gft4_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft4_hi.b}, z_src_hi.b
	eor	z_dest4.d, z_dest4.d, z_tmp_lo.d
	eor	z_dest4.d, z_dest4.d, z_tmp_hi.d

	tbl	z_tmp_lo.b, {z_gft5_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft5_hi.b}, z_src_hi.b
	eor	z_dest5.d, z_dest5.d, z_tmp_lo.d
	eor	z_dest5.d, z_dest5.d, z_tmp_hi.d

	tbl	z_tmp_lo.b, {z_gft6_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft6_hi.b}, z_src_hi.b
	eor	z_dest6.d, z_dest6.d, z_tmp_lo.d
	eor	z_dest6.d, z_dest6.d, z_tmp_hi.d

	/* Non-temporal stores for better cache behavior */
	stnt1b	z_dest1.b, p0, [x_dest1, x_pos]
	stnt1b	z_dest2.b, p0, [x_dest2, x_pos]
	stnt1b	z_dest3.b, p0, [x_dest3, x_pos]
	stnt1b	z_dest4.b, p0, [x_dest4, x_pos]
	stnt1b	z_dest5.b, p0, [x_dest5, x_pos]
	stnt1b	z_dest6.b, p0, [x_dest6, x_pos]

	/* Increment with SVE2 syntax */
	incb	x_pos, ALL, MUL #1
	b	.Lloopsve_vl

.return_pass:
	mov	w0, #0
	ret

.return_fail:
	mov	w0, #1
	ret