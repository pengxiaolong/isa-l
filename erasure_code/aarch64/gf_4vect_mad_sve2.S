.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_4vect_mad_sve2)
#ifndef __APPLE__
.type gf_4vect_mad_sve2, %function
#endif

/* gf_4vect_mad_sve2(int len, int vec, int vec_i, unsigned char *gftbls,
			      unsigned char *src, unsigned char **dest);
 */
/* arguments */
x_len		.req	x0
x_vec		.req	x1
x_vec_i		.req	x2
x_tbl		.req	x3
x_src		.req	x4
x_dest		.req	x5

/* returns */
w_ret		.req	w0

/* local variables */
x_pos		.req	x6
x_dest2		.req	x7
x_dest3		.req	x8
x_dest4		.req	x9
x_dest1		.req	x12

/* vectors */
z_mask0f	.req	z0

z_src		.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z_src

z_dest1		.req	z3
z_dest2		.req	z27
z_dest3		.req	z28
z_dest4		.req	z29

z_tmp1_lo	.req	z4
z_tmp1_hi	.req	z5
z_tmp2_lo	.req	z10
z_tmp2_hi	.req	z11
z_tmp3_lo	.req	z14
z_tmp3_hi	.req	z15
z_tmp4_lo	.req	z16
z_tmp4_hi	.req	z23

z_gft1_lo	.req	z6
z_gft1_hi	.req	z7
q_gft1_lo	.req	q6
q_gft1_hi	.req	q7

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

cdecl(gf_4vect_mad_sve2):
	/* less than 16 bytes, return_fail */
	cmp	x_len, #16
	blt	.return_fail

	mov	z_mask0f.b, #0x0f		/* z_mask0f = 0x0F0F...0F */
	
	/* load table 1 */
	add	x_tbl, x_tbl, x_vec_i, LSL #5	/* x_tbl += x_vec_i * 2^5 */
	ldp	q_gft1_lo, q_gft1_hi, [x_tbl]
	
	/* load table 2 */
	add	x_tbl, x_tbl, x_vec, LSL #5	/* x_tbl += x_vec * 2^5 */
	ldp	q_gft2_lo, q_gft2_hi, [x_tbl]
	
	/* load table 3 */
	add	x_tbl, x_tbl, x_vec, LSL #5	/* x_tbl += x_vec * 2^5 */
	ldp	q_gft3_lo, q_gft3_hi, [x_tbl]
	
	/* load table 4 */
	add	x_tbl, x_tbl, x_vec, LSL #5	/* x_tbl += x_vec * 2^5 */
	ldp	q_gft4_lo, q_gft4_hi, [x_tbl]

	ldr	x_dest1, [x_dest, #8*0]		/* pointer to dest1 */
	ldr	x_dest2, [x_dest, #8*1]		/* pointer to dest2 */
	ldr	x_dest3, [x_dest, #8*2]		/* pointer to dest3 */
	ldr	x_dest4, [x_dest, #8*3]		/* pointer to dest4 */

	mov	x_pos, #0

	/* vector length agnostic */
.Lloopsve2_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	/* Prefetch all destinations early */
	prfb	pldl2strm, p0, [x_dest1, x_pos]
	prfb	pldl2strm, p0, [x_dest2, x_pos]
	prfb	pldl2strm, p0, [x_dest3, x_pos]
	prfb	pldl2strm, p0, [x_dest4, x_pos]

	/* load src data, governed by p0 */
	ld1b	z_src.b,  p0/z, [x_src, x_pos]

	/* SVE2: Use BEXT to split nibbles more efficiently */
	bext	z_src_lo.b, z_src.b, z_mask0f.b
	lsr	z_src_hi.b, z_src.b, #4

	/* Load all dest data in parallel */
	ld1b	z_dest1.b, p0/z, [x_dest1, x_pos]
	ld1b	z_dest2.b, p0/z, [x_dest2, x_pos]
	ld1b	z_dest3.b, p0/z, [x_dest3, x_pos]
	ld1b	z_dest4.b, p0/z, [x_dest4, x_pos]

	/* SVE2: Parallel table lookups for all destinations */
	tbl	z_tmp1_lo.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_tmp1_hi.b, {z_gft1_hi.b}, z_src_hi.b
	tbl	z_tmp2_lo.b, {z_gft2_lo.b}, z_src_lo.b
	tbl	z_tmp2_hi.b, {z_gft2_hi.b}, z_src_hi.b
	tbl	z_tmp3_lo.b, {z_gft3_lo.b}, z_src_lo.b
	tbl	z_tmp3_hi.b, {z_gft3_hi.b}, z_src_hi.b
	tbl	z_tmp4_lo.b, {z_gft4_lo.b}, z_src_lo.b
	tbl	z_tmp4_hi.b, {z_gft4_hi.b}, z_src_hi.b

	/* SVE2: Use EOR3 for 3-way XOR operations */
	eor3	z_dest1.d, z_dest1.d, z_tmp1_lo.d, z_tmp1_hi.d
	eor3	z_dest2.d, z_dest2.d, z_tmp2_lo.d, z_tmp2_hi.d
	eor3	z_dest3.d, z_dest3.d, z_tmp3_lo.d, z_tmp3_hi.d
	eor3	z_dest4.d, z_dest4.d, z_tmp4_lo.d, z_tmp4_hi.d

	/* Store all dest data in parallel */
	st1b	z_dest1.b, p0, [x_dest1, x_pos]
	st1b	z_dest2.b, p0, [x_dest2, x_pos]
	st1b	z_dest3.b, p0, [x_dest3, x_pos]
	st1b	z_dest4.b, p0, [x_dest4, x_pos]

	/* increment one vector length */
	incb	x_pos

	b	.Lloopsve2_vl

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret