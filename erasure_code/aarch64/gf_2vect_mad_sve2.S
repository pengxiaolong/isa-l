.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_vect_mad_sve2)
#ifndef __APPLE__
.type gf_vect_mad_sve2, %function
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
x_dest_ptr	.req	x7
x_tbl_ptr	.req	x8

/* Vector registers */
z_mask0f	.req	z0
z_src		.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z3
z_dest		.req	z4
z_tmp_lo	.req	z5
z_tmp_hi	.req	z6
z_gft_lo	.req	z16
z_gft_hi	.req	z17

cdecl(gf_vect_mad_sve2):
	/* Minimum vector length check */
	cmp	x_len, #16
	blt	.return_fail

	/* Initialize mask */
	mov	z_mask0f.b, #0x0f		/* z_mask0f = 0x0F0F...0F */

	/* Load destination pointer */
	ldr	x_dest_ptr, [x_dest]

	/* Load Galois field table */
	add	x_tbl_ptr, x_tbl, x_vec_i, LSL #5	/* x_tbl += vec_i * 32 */
	ldp	q_gft_lo, q_gft_hi, [x_tbl_ptr]

	mov	x_pos, #0

	/* Main processing loop */
.Lloopsve_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	/* Prefetch destination data */
	prfb	pldl2strm, p0, [x_dest_ptr, x_pos]

	/* Load source and split into nibbles */
	ld1b	z_src.b, p0/z, [x_src, x_pos]
	and	z_src_lo.d, z_src.d, z_mask0f.d
	lsr	z_src_hi.b, z_src.b, #4		/* Split into hi nibbles */

	/* Load destination vector */
	ld1b	z_dest.b, p0/z, [x_dest_ptr, x_pos]

	/* GF(2^8) multiply-accumulate */
	tbl	z_tmp_lo.b, {z_gft_lo.b}, z_src_lo.b
	tbl	z_tmp_hi.b, {z_gft_hi.b}, z_src_hi.b
	eor	z_dest.d, z_tmp_lo.d, z_dest.d
	eor	z_dest.d, z_tmp_hi.d, z_dest.d

	/* Store result */
	st1b	z_dest.b, p0, [x_dest_ptr, x_pos]

	/* Next vector position */
	incb	x_pos
	b	.Lloopsve_vl

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret