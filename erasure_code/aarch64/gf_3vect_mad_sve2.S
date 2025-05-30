.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_3vect_mad_sve2)
#ifndef __APPLE__
.type gf_3vect_mad_sve2, %function
#endif

/* gf_3vect_mad_sve2(int len, int vec, int vec_i, unsigned char *gftbls,
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
x_dest1		.req	x12

/* vectors */
z_mask0f	.req	z0

z_src		.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z_src

z_dest1		.req	z3
z_dest2		.req	z4
z_dest3		.req	z5

z_tmp1_lo	.req	z6
z_tmp1_hi	.req	z7
z_tmp2_lo	.req	z8
z_tmp2_hi	.req	z9
z_tmp3_lo	.req	z10
z_tmp3_hi	.req	z11

z_gft1_lo	.req	z16
z_gft1_hi	.req	z17
q_gft1_lo	.req	q16
q_gft1_hi	.req	q17

/* bottom 64-bit of v8..v15 must be preserved if used */
z_gft2_lo	.req	z18
z_gft2_hi	.req	z19
q_gft2_lo	.req	q18
q_gft2_hi	.req	q19

z_gft3_lo	.req	z20
z_gft3_hi	.req	z21
q_gft3_lo	.req	q20
q_gft3_hi	.req	q21

cdecl(gf_3vect_mad_sve2):
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

	ldr	x_dest1, [x_dest, #8*0]		/* pointer to dest1 */
	ldr	x_dest2, [x_dest, #8*1]		/* pointer to dest2 */
	ldr	x_dest3, [x_dest, #8*2]		/* pointer to dest3 */

	mov	x_pos, #0

	/* vector length agnostic */
.Lloopsve2_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	/* dest data prefetch - all three streams */
	prfb	pldl2strm, p0, [x_dest1, x_pos]
	prfb	pldl2strm, p0, [x_dest2, x_pos]
	prfb	pldl2strm, p0, [x_dest3, x_pos]

	/* load src data, governed by p0 */
	ld1b	z_src.b, p0/z, [x_src, x_pos]

	/* split 4-bit lo; 4-bit hi */
	and	z_src_lo.d, z_src.d, z_mask0f.d
	lsr	z_src_hi.b, z_src.b, #4

	/* load all dest data in parallel, governed by p0 */
	ld1b	z_dest1.b, p0/z, [x_dest1, x_pos]
	ld1b	z_dest2.b, p0/z, [x_dest2, x_pos]
	ld1b	z_dest3.b, p0/z, [x_dest3, x_pos]

	/* All table lookups in parallel - GF(2^8) multiplication */
	tbl	z_tmp1_lo.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_tmp1_hi.b, {z_gft1_hi.b}, z_src_hi.b
	tbl	z_tmp2_lo.b, {z_gft2_lo.b}, z_src_lo.b
	tbl	z_tmp2_hi.b, {z_gft2_hi.b}, z_src_hi.b
	tbl	z_tmp3_lo.b, {z_gft3_lo.b}, z_src_lo.b
	tbl	z_tmp3_hi.b, {z_gft3_hi.b}, z_src_hi.b

	/* SVE2: Use EOR3 for three-way XOR (GF addition) */
	eor3	z_dest1.d, z_dest1.d, z_tmp1_lo.d, z_tmp1_hi.d
	eor3	z_dest2.d, z_dest2.d, z_tmp2_lo.d, z_tmp2_hi.d
	eor3	z_dest3.d, z_dest3.d, z_tmp3_lo.d, z_tmp3_hi.d

	/* store all dest data in parallel, governed by p0 */
	st1b	z_dest1.b, p0, [x_dest1, x_pos]
	st1b	z_dest2.b, p0, [x_dest2, x_pos]
	st1b	z_dest3.b, p0, [x_dest3, x_pos]

	/* increment one vector length */
	incb	x_pos

	b	.Lloopsve2_vl

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret