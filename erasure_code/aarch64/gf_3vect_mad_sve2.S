.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_3vect_mad_sve2)
#ifndef __APPLE__
.type gf_3vect_mad_sve2, %function
#endif

/* Arguments */
x_len		.req	x0	/* vector length */
x_vec		.req	x1	/* number of source vectors */
x_vec_i		.req	x2	/* vector index */
x_tbl		.req	x3	/* GF table pointer */
x_src		.req	x4	/* source data pointer */
x_dest		.req	x5	/* destination pointers array */

/* Returns */
w_ret		.req	w0

/* Local variables */
x_pos		.req	x6	/* position in vector */
x_dest1		.req	x7	/* destination 1 pointer */
x_dest2		.req	x8	/* destination 2 pointer */
x_dest3		.req	x9	/* destination 3 pointer */
x_tbl1		.req	x10	/* table 1 pointer */
x_tbl2		.req	x11	/* table 2 pointer */
x_tbl3		.req	x12	/* table 3 pointer */

/* Vector registers */
z_mask0f	.req	z0	/* 0x0F mask */
z_src		.req	z1	/* source data */
z_src_lo	.req	z2	/* low nibbles */
z_src_hi	.req	z3	/* high nibbles */
z_dest1_v	.req	z4	/* destination 1 vector */
z_dest2_v	.req	z5	/* destination 2 vector */
z_dest3_v	.req	z6	/* destination 3 vector */
z_tmp_lo	.req	z16	/* temp low */
z_tmp_hi	.req	z17	/* temp high */
z_gft1_lo	.req	z18	/* GF table 1 low */
z_gft1_hi	.req	z19	/* GF table 1 high */
z_gft2_lo	.req	z20	/* GF table 2 low */
z_gft2_hi	.req	z21	/* GF table 2 high */
z_gft3_lo	.req	z22	/* GF table 3 low */
z_gft3_hi	.req	z23	/* GF table 3 high */

cdecl(gf_3vect_mad_sve2):
	/* Minimum vector length check */
	cmp	x_len, #16
	blt	.return_fail

	/* Initialize 0x0F mask */
	mov	z_mask0f.b, #0x0f

	/* Load destination pointers */
	ldr	x_dest1, [x_dest, #8*0]
	ldr	x_dest2, [x_dest, #8*1]
	ldr	x_dest3, [x_dest, #8*2]

	/* Setup table pointers */
	add	x_tbl1, x_tbl, x_vec_i, LSL #5		/* x_tbl1 = x_tbl + x_vec_i * 32 */
	add	x_tbl2, x_tbl1, x_vec, LSL #5		/* x_tbl2 = x_tbl1 + x_vec * 32 */
	add	x_tbl3, x_tbl2, x_vec, LSL #5		/* x_tbl3 = x_tbl2 + x_vec * 32 */

	/* Load GF tables */
	ldp	q_gft1_lo, q_gft1_hi, [x_tbl1]
	ldp	q_gft2_lo, q_gft2_hi, [x_tbl2]
	ldp	q_gft3_lo, q_gft3_hi, [x_tbl3]

	mov	x_pos, #0

	/* Main processing loop */
.Lloopsve_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	/* Prefetch destination data */
	prfb	pldl2strm, p0, [x_dest1, x_pos]
	prfb	pldl2strm, p0, [x_dest2, x_pos]
	prfb	pldl2strm, p0, [x_dest3, x_pos]

	/* Load source and split into nibbles */
	ld1b	z_src.b, p0/z, [x_src, x_pos]
	and	z_src_lo.d, z_src.d, z_mask0f.d
	lsr	z_src_hi.b, z_src.b, #4

	/* Load destination vectors */
	ld1b	z_dest1_v.b, p0/z, [x_dest1, x_pos]
	ld1b	z_dest2_v.b, p0/z, [x_dest2, x_pos]
	ld1b	z_dest3_v.b, p0/z, [x_dest3, x_pos]

	/* Process destination 1 */
	tbl	z_tmp_lo.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft1_hi.b}, z_src_hi.b
	eor	z_dest1_v.d, z_tmp_lo.d, z_dest1_v.d
	eor	z_dest1_v.d, z_tmp_hi.d, z_dest1_v.d

	/* Process destination 2 */
	tbl	z_tmp_lo.b, {z_gft2_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft2_hi.b}, z_src_hi.b
	eor	z_dest2_v.d, z_tmp_lo.d, z_dest2_v.d
	eor	z_dest2_v.d, z_tmp_hi.d, z_dest2_v.d

	/* Process destination 3 */
	tbl	z_tmp_lo.b, {z_gft3_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft3_hi.b}, z_src_hi.b
	eor	z_dest3_v.d, z_tmp_lo.d, z_dest3_v.d
	eor	z_dest3_v.d, z_tmp_hi.d, z_dest3_v.d

	/* Store results */
	st1b	z_dest1_v.b, p0, [x_dest1, x_pos]
	st1b	z_dest2_v.b, p0, [x_dest2, x_pos]
	st1b	z_dest3_v.b, p0, [x_dest3, x_pos]

	/* Next vector position */
	incb	x_pos
	b	.Lloopsve_vl

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret