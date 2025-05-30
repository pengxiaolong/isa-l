.text
.align		6
.arch		armv8-a+sve2

#include "../include/aarch64_label.h"

.global cdecl(gf_vect_mad_sve2)
#ifndef __APPLE__
.type gf_vect_mad_sve2, %function
#endif

/* gf_vect_mad_sve2(int len, int vec, int vec_i, unsigned char *gftbls,
			     unsigned char *src, unsigned char *dest);
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

/* vectors */
z_mask0f	.req	z0

z_src		.req	z1
z_src_lo	.req	z2
z_src_hi	.req	z3

z_dest		.req	z4

z_tmp1_lo	.req	z5
z_tmp1_hi	.req	z6

z_gft1_lo	.req	z7
z_gft1_hi	.req	z8
q_gft1_lo	.req	q7
q_gft1_hi	.req	q8

cdecl(gf_vect_mad_sve2):
	/* less than 16 bytes, return_fail */
	cmp	x_len, #16
	blt	.return_fail

	/* SVE2 OPTIMIZATION: Use DUPQ for more efficient mask loading */
	mov	w7, #0x0f0f0f0f
	dupq	z_mask0f.s, w7, w7		/* More efficient than mov z_mask0f.b, #0x0f */
	
	add	x_tbl, x_tbl, x_vec_i, LSL #5	/* x_tbl += x_vec_i * 2^5 */

	/* Load with NEON instruction ldp */
	ldp	q_gft1_lo, q_gft1_hi, [x_tbl]

	mov	x_pos, #0

	/* vector length agnostic */
.Lloopsve2_vl:
	whilelo	p0.b, x_pos, x_len
	b.none	.return_pass

	/* SVE2 OPTIMIZATION: Enhanced prefetching with multiple cache levels */
	prfb	pldl2strm, p0, [x_dest, x_pos]
	prfb	pldl1keep, p0, [x_src, x_pos]	/* Prefetch src data too */

	/* load src and dest data in parallel, governed by p0 */
	ld1b	z_src.b,  p0/z, [x_src, x_pos]
	ld1b	z_dest.b, p0/z, [x_dest, x_pos]

	/* SVE2 OPTIMIZATION: Use more efficient nibble extraction */
	/* Extract low nibbles */
	and	z_src_lo.d, z_src.d, z_mask0f.d
	
	/* SVE2: Use USHR for consistent high nibble extraction */
	ushr	z_src_hi.b, z_src.b, #4
	and	z_src_hi.d, z_src_hi.d, z_mask0f.d

	/* SVE2 OPTIMIZATION: Use TBX for more robust table lookup */
	tbx	z_tmp1_lo.b, z_src_lo.b, {z_gft1_lo.b}
	tbx	z_tmp1_hi.b, z_src_hi.b, {z_gft1_hi.b}

	/* SVE2 OPTIMIZATION: Use EOR3 for three-way XOR in single instruction */
	eor3	z_dest.d, z_dest.d, z_tmp1_lo.d, z_tmp1_hi.d

	/* store dest data, governed by p0 */
	st1b	z_dest.b, p0, [x_dest, x_pos]
	/* increment one vector length */
	incb	x_pos

	b	.Lloopsve2_vl

.return_pass:
	mov	w_ret, #0
	ret

.return_fail:
	mov	w_ret, #1
	ret
