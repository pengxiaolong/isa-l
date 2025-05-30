.text
.align		6
.arch		armv9-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_vect_mad_sve2)
#ifndef __APPLE__
.type gf_vect_mad_sve2, %function
#endif

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

/* vectors */
z_mask0f	.req	z0
z_src		.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z1
z_dest		.req	z3
z_tmp1_lo	.req	z4
z_tmp1_hi	.req	z5
z_gft1_lo	.req	z6
z_gft1_hi	.req	z7

cdecl(gf_vect_mad_sve2):
	/* less than 16 bytes, return_fail */
	cmp	x_len, #16
	blt	.return_fail

	mov	z_mask0f.b, #0x0f		/* z_mask0f = 0x0F0F...0F */
	add	x_tbl, x_tbl, x_vec_i, LSL #5	/* x_tbl += x_vec_i * 2^5 */

	/* Load with SVE2's wider loads */
	ld1b	z_gft1_lo.b, p0/z, [x_tbl]
	add	x_tbl, x_tbl, #16
	ld1b	z_gft1_hi.b, p0/z, [x_tbl]

	mov	x_pos, #0

	/* vector length agnostic */
.Lloopsve_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	/* prefetch dest data - use SVE2 streaming hint */
	prfb	pldl2keep, p0, [x_dest, x_pos]

	/* load src data, governed by p0 */
	ld1b	z_src.b, p0/z, [x_src, x_pos]

	/* split 4-bit lo; 4-bit hi using SVE2 UZP1/UZP2 */
	and	z_src_lo.d, z_src.d, z_mask0f.d
	lsr	z_src_hi.b, z_src.b, #4

	/* load dest data, governed by p0 */
	ld1b	z_dest.b, p0/z, [x_dest, x_pos]

	/* table indexing using SVE2 TBL - more efficient with new instructions */
	tbl	z_tmp1_lo.b, {z_gft1_lo.b}, z_src_lo.b
	tbl	z_tmp1_hi.b, {z_gft1_hi.b}, z_src_hi.b

	/* use SVE2 EOR3 for potential chained XORs (if more were needed) */
	eor	z_dest.d, z_tmp1_lo.d, z_dest.d
	eor	z_dest.d, z_tmp1_hi.d, z_dest.d

	/* store dest data, governed by p0 */
	st1b	z_dest.b, p0, [x_dest, x_pos]
	
	/* increment using SVE2 ADDP for vector-aware increment */
	incb	x_pos, all, mul #1

	b	.Lloopsve_vl

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret