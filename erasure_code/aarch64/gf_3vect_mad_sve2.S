.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_3vect_mad_sve2)
#ifndef __APPLE__
.type gf_3vect_mad_sve2, %function
#endif

/* Arguments */
x_len		.req	x0
x_vec		.req	x1
x_vec_i		.req	x2
x_tbl		.req	x3
x_src		.req	x4
x_dest		.req	x5

/* Returns */
w_ret		.req	w0

/* Local variables */
x_pos		.req	x6
x_dest2		.req	x7
x_dest3		.req	x8
x_dest1		.req	x12

/* Vector registers */
z_mask0f	.req	z0
z_src		.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z1      /* Reuse z_src */
z_dest1		.req	z3
z_tmp_lo	.req	z4
z_tmp_hi	.req	z5
z_gft1_lo	.req	z6
z_gft1_hi	.req	z7
z_gft2_lo	.req	z17
z_gft2_hi	.req	z18
z_gft3_lo	.req	z19
z_gft3_hi	.req	z20
z_dest2		.req	z27
z_dest3		.req	z28

cdecl(gf_3vect_mad_sve2):
	/* Minimum vector length check */
	cmp	x_len, #16
	blt	.return_fail

	/* Initialize mask */
	mov	z_mask0f.b, #0x0f

	/* Load Galois field tables */
	add	x_tbl, x_tbl, x_vec_i, LSL #5	/* x_tbl += vec_i * 32 */
	ldp	q_gft1_lo, q_gft1_hi, [x_tbl]
	add	x_tbl, x_tbl, x_vec, LSL #5	/* x_tbl += vec * 32 */
	ldp	q_gft2_lo, q_gft2_hi, [x_tbl]
	add	x_tbl, x_tbl, x_vec, LSL #5	/* x_tbl += vec * 32 */
	ldp	q_gft3_lo, q_gft3_hi, [x_tbl]

	/* Load destination pointers */
	ldr	x_dest1, [x_dest, #8*0]
	ldr	x_dest2, [x_dest, #8*1]
	ldr	x_dest3, [x_dest, #8*2]

	mov	x_pos, #0

	/* Main processing loop */
.Lloopsve_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	/* Prefetch destination data (streaming for better cache utilization) */
	prfb	pldl2strm, p0, [x_dest1, x_pos]
	prfb	pldl2strm, p0, [x_dest2, x_pos]
	prfb	pldl2strm, p0, [x_dest3, x_pos]

	/* Load source and split into nibbles */
	ld1b	z_src.b, p0/z, [x_src, x_pos]
	and	z_src_lo.d, z_src.d, z_mask0f.d
	usra	z_src_hi.b, z_src.b, #4	/* SVE2: More efficient than lsr */

	/* Load destination vectors */
	ld1b	z_dest1.b, p0/z, [x_dest1, x_pos]
	ld1b	z_dest2.b, p0/z, [x_dest2, x_pos]
	ld1b	z_dest3.b, p0/z, [x_dest3, x_pos]

	/* GF(2^8) multiply-accumulate for dest1 */
	tbl	z_tmp_lo.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft1_hi.b}, z_src_hi.b
	eor3	z_dest1.d, z_tmp_lo.d, z_tmp_hi.d, z_dest1.d	/* SVE2: Single instruction for 3-way XOR */

	/* GF(2^8) multiply-accumulate for dest2 */
	tbl	z_tmp_lo.b, {z_gft2_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft2_hi.b}, z_src_hi.b
	eor3	z_dest2.d, z_tmp_lo.d, z_tmp_hi.d, z_dest2.d	/* SVE2: Single instruction for 3-way XOR */

	/* GF(2^8) multiply-accumulate for dest3 */
	tbl	z_tmp_lo.b, {z_gft3_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft3_hi.b}, z_src_hi.b
	eor3	z_dest3.d, z_tmp_lo.d, z_tmp_hi.d, z_dest3.d	/* SVE2: Single instruction for 3-way XOR */

	/* Store results */
	st1b	z_dest1.b, p0, [x_dest1, x_pos]
	st1b	z_dest2.b, p0, [x_dest2, x_pos]
	st1b	z_dest3.b, p0, [x_dest3, x_pos]

	/* Next vector position */
	incb	x_pos
	b	.Lloopsve_vl

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret